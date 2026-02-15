"""
Generate Ansible vault.yml from GitHub Secrets (JSON format).

This script safely processes secrets without shell injection risks.
It uses PyYAML for proper YAML escaping of special characters.

Usage:
    SECRETS_JSON='{"KEY":"value"}' python3 generate-vault.py <output_file>
"""

import os
import sys
import json
import yaml
from typing import Dict, Any


def parse_multiline_env(content: str) -> Dict[str, str]:
    """Parse KEY=VALUE format from multiline string."""
    result = {}
    for line in content.splitlines():
        line = line.strip()
        if line and '=' in line:
            key, value = line.split('=', 1)
            result[key.strip()] = value.strip()
    return result


def generate_vault_yaml(secrets: Dict[str, Any], output_file: str) -> None:
    """Generate vault.yml from secrets dictionary using PyYAML for safe serialization."""

    vault_data = {}

    # Infrastructure secrets
    if 'INFRA_ENV' in secrets and secrets['INFRA_ENV']:
        infra_vars = parse_multiline_env(secrets['INFRA_ENV'])
        for key, value in infra_vars.items():
            vault_key = f'vault_{key.lower()}'
            vault_data[vault_key] = value

    # Consolidated service secrets
    if 'SERVICES_ENV' in secrets and secrets['SERVICES_ENV']:
        vault_data['vault_services_env'] = secrets['SERVICES_ENV']

    # Per-service secrets (auto-detected)
    per_service_secrets = {
        k: v for k, v in secrets.items()
        if k.endswith('_ENV') and k not in ['INFRA_ENV', 'SERVICES_ENV'] and v
    }

    for secret_name in sorted(per_service_secrets.keys()):
        vault_var_name = f'vault_{secret_name.lower()}'
        vault_data[vault_var_name] = per_service_secrets[secret_name]

    # Registry credentials
    if 'YC_REGISTRY_USERNAME' in secrets and secrets['YC_REGISTRY_USERNAME']:
        vault_data['vault_yc_registry_username'] = secrets['YC_REGISTRY_USERNAME']

    if 'YC_REGISTRY_PASSWORD' in secrets and secrets['YC_REGISTRY_PASSWORD']:
        vault_data['vault_yc_registry_password'] = secrets['YC_REGISTRY_PASSWORD']

    with open(output_file, 'w') as f:
        f.write('---\n')
        f.write('# ' + '=' * 72 + '\n')
        f.write('# Generated dynamically by CI/CD from GitHub Secrets\n')
        f.write('# DO NOT EDIT MANUALLY - this file is recreated on each deployment\n')
        f.write('# ' + '=' * 72 + '\n')
        f.write('\n')

        yaml.dump(vault_data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <output_file>", file=sys.stderr)
        sys.exit(1)

    output_file = sys.argv[1]
    secrets_json = os.environ.get('SECRETS_JSON', '{}')

    try:
        secrets = json.loads(secrets_json)
    except json.JSONDecodeError as e:
        print(f"Error parsing SECRETS_JSON: {e}", file=sys.stderr)
        sys.exit(1)

    try:
        generate_vault_yaml(secrets, output_file)
        print(f"✓ Generated {output_file}", file=sys.stderr)
    except Exception as e:
        print(f"Error generating vault file: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
