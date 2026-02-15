"""
Yandex Container Registry Cleanup Script

Strategy:
- Delete staging images (sha-*) older than 14 days WITHOUT 'latest' tag
- Keep all production images (v*.*.* tags)
- Keep all images with 'latest' tag
"""

import argparse
import json
import sys
import subprocess
from datetime import datetime, timedelta, timezone
from typing import List, Dict
import re


def run_yc_command(cmd: List[str]) -> Dict:
    """Execute yc CLI command and return JSON result."""
    full_cmd = ["yc"] + cmd + ["--format", "json"]
    try:
        result = subprocess.run(
            full_cmd,
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout) if result.stdout else {}
    except subprocess.CalledProcessError as e:
        print(f"Error running yc command: {e.stderr}", file=sys.stderr)
        return {}
    except json.JSONDecodeError as e:
        print(f"Error parsing yc output: {e}", file=sys.stderr)
        return {}


def get_registry_images(registry_id: str) -> List[Dict]:
    """Get all images from registry using yc CLI."""
    print(f"Fetching images from registry {registry_id}...")

    # List all repositories
    repos = run_yc_command([
        "container", "repository", "list",
        "--registry-id", registry_id
    ])

    if not repos:
        return []

    all_images = []

    for repo in repos:
        repo_name = repo.get('name', '')
        print(f"  Scanning repository: {repo_name}")

        # List images in repository
        images = run_yc_command([
            "container", "image", "list",
            "--repository-name", repo_name
        ])

        for img in images:
            all_images.append({
                'id': img.get('id'),
                'repository': repo_name.split('/')[-1],
                'tags': img.get('tags', []),
                'created_at': img.get('created_at'),
                'size': img.get('compressed_size', 0),
                'digest': img.get('digest', '')
            })

    return all_images


def is_production_tag(tag: str) -> bool:
    """Check if tag is a production tag."""
    if tag == 'latest':
        return True
    if re.match(r'^v\d+\.\d+\.\d+', tag):
        return True
    return False


def is_staging_tag(tag: str) -> bool:
    """Check if tag is a staging tag."""
    return tag.startswith('sha-')


def parse_iso_date(date_str: str) -> datetime:
    """Parse ISO 8601 date string."""
    try:
        # Remove microseconds if present
        if '.' in date_str:
            date_str = date_str.split('.')[0] + 'Z'
        return datetime.fromisoformat(date_str.replace('Z', '+00:00'))
    except Exception as e:
        print(f"Warning: Could not parse date '{date_str}': {e}", file=sys.stderr)
        return datetime(2020, 1, 1, tzinfo=timezone.utc)


def cleanup_registry(
    registry_id: str,
    keep_days: int = 14,
    dry_run: bool = True
):
    """Clean up old staging images from registry."""
    cutoff_date = datetime.now(timezone.utc) - timedelta(days=keep_days)

    print(f"Registry ID: {registry_id}")
    print(f"Delete staging images older than: {cutoff_date.isoformat()}")
    print(f"Dry run: {dry_run}")
    print()

    images = get_registry_images(registry_id)

    if not images:
        print("No images found in registry")
        return

    print(f"Found {len(images)} images")
    print()

    to_delete = []
    to_keep = []
    total_size_freed = 0

    for img in images:
        tags = img.get('tags', [])
        img_id = img['id']
        repo = img['repository']
        created = parse_iso_date(img['created_at'])
        age_days = (datetime.now(timezone.utc) - created).days
        size_mb = img.get('size', 0) / (1024 * 1024)

        display_tags = ', '.join(tags) if tags else '<untagged>'
        full_name = f"{repo}:{display_tags}"

        # Keep all production images (v*.*.*)
        has_production_tag = any(is_production_tag(tag) for tag in tags)
        if has_production_tag:
            to_keep.append(full_name)
            print(f"KEEP (production): {full_name}")
            continue

        # Keep all images with 'latest' tag
        if 'latest' in tags:
            to_keep.append(full_name)
            print(f"KEEP (latest): {full_name}")
            continue

        # Delete old staging images (sha-*) older than 14 days
        has_staging_tag = any(is_staging_tag(tag) for tag in tags)
        if has_staging_tag and created <= cutoff_date:
            to_delete.append({
                'id': img_id,
                'name': full_name,
                'size_mb': size_mb
            })
            total_size_freed += size_mb
            print(f"DELETE (old staging, {age_days}d): {full_name}")
        else:
            to_keep.append(full_name)
            print(f"KEEP (recent or other): {full_name}")

    print()
    print(f"Summary: {len(to_keep)} to keep, {len(to_delete)} to delete")
    print(f"Space to free: {total_size_freed:.1f} MB")
    print()

    deleted_count = 0
    if not dry_run and to_delete:
        print("Deleting images...")
        for img in to_delete:
            print(f"  Deleting {img['name']}...")
            try:
                subprocess.run(
                    ["yc", "container", "image", "delete", "--id", img['id']],
                    check=True,
                    capture_output=True
                )
                deleted_count += 1
            except subprocess.CalledProcessError as e:
                print(f"  Failed to delete {img['name']}: {e.stderr.decode()}", file=sys.stderr)

    print()
    if dry_run:
        print("DRY RUN - No images were actually deleted")
        print(f"Would delete {len(to_delete)} images ({total_size_freed:.1f} MB)")
    else:
        print(f"Deleted {deleted_count}/{len(to_delete)} images ({total_size_freed:.1f} MB)")


def main():
    parser = argparse.ArgumentParser(
        description='Clean up old staging images from Yandex Container Registry'
    )
    parser.add_argument(
        '--registry-id',
        required=True,
        help='Yandex Container Registry ID'
    )
    parser.add_argument(
        '--keep-days',
        type=int,
        default=14,
        help='Keep staging images newer than N days (default: 14)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview deletions without executing'
    )

    args = parser.parse_args()

    try:
        cleanup_registry(
            registry_id=args.registry_id,
            keep_days=args.keep_days,
            dry_run=args.dry_run
        )

        print()
        print("Cleanup completed successfully")
        sys.exit(0)

    except Exception as e:
        print(f"Error during cleanup: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
