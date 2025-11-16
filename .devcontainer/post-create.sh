#!/bin/bash
# DevContainer post-creation setup for OpenMeal development environment
set -e

# Get workspace folder (usually /workspace)
WORKSPACE_FOLDER="${WORKSPACE_FOLDER:-/workspace}"

echo "========================================="
echo "OpenMeal DevContainer Post-Create Setup"
echo "========================================="

# Fix permissions for devuser home directory and mounted volumes
echo ""
echo "[0/5] Configuring user permissions..."
sudo chown -R devuser:devuser /home/devuser

# Configure APT repositories for additional packages
echo ""
echo "[1/5] Setting up package repositories..."
if [ -f "${WORKSPACE_FOLDER}/.devcontainer/setup-apt-repositories.sh" ]; then
  sudo chmod +x "${WORKSPACE_FOLDER}/.devcontainer/setup-apt-repositories.sh"
  sudo "${WORKSPACE_FOLDER}/.devcontainer/setup-apt-repositories.sh"
else
  echo "Warning: setup-apt-repositories.sh not found, skipping..."
fi

# Configure persistent bash history across container restarts
echo ""
echo "[2/5] Setting up persistent bash history..."
mkdir -p /home/devuser/.bash_history_mount
touch /home/devuser/.bash_history_mount/.bash_history
ln -sf /home/devuser/.bash_history_mount/.bash_history /home/devuser/.bash_history || true

# Install essential dev tools
echo ""
echo "[3/5] Installing development tools..."
# Retry apt operations with better error handling
for i in {1..3}; do
  if sudo apt-get update -qq 2>/dev/null; then
    break
  else
    echo "Attempt $i failed, retrying..."
    sleep 2
  fi
done

sudo apt-get install -y --no-install-recommends \
  git \
  curl \
  wget \
  nano \
  jq \
  make \
  htop \
  tree \
  ca-certificates \
  && sudo apt-get clean \
  && sudo rm -rf /var/lib/apt/lists/*

# Configure Git
echo ""
echo "[4/5] Configuring Git..."
git config --global --add safe.directory "${WORKSPACE_FOLDER}"
git config --global pull.rebase false
git config --global init.defaultBranch main

# Install Ansible and testing tools via pipx
echo ""
echo "[5/5] Installing Ansible and testing tools via pipx..."
if [ -f "${WORKSPACE_FOLDER}/infrastructure/ansible/requirements-pip.txt" ]; then
  cd "${WORKSPACE_FOLDER}"
  
  # Install pipx if not present
  if ! command -v pipx &> /dev/null; then
    echo "Installing pipx..."
    sudo apt install pipx
    pipx ensurepath
  fi
  
  # Ensure PATH includes pipx binaries for current session and future shells
  export PIPX_HOME="/home/devuser/.local/share/pipx"
  export PIPX_BIN_DIR="/home/devuser/.local/bin"
  export PATH="$PIPX_BIN_DIR:$PATH"

  echo 'export PIPX_HOME="$HOME/.local/share/pipx"' >> /home/devuser/.bashrc
  echo 'export PIPX_BIN_DIR="$HOME/.local/bin"' >> /home/devuser/.bashrc
  echo 'export PATH="$PIPX_BIN_DIR:$PATH"' >> /home/devuser/.bashrc
  mkdir -p "$PIPX_BIN_DIR"
  
  # Remove any existing ansible installations to avoid conflicts
  pipx uninstall-all || true
  
  # Install Ansible via pipx (isolated environment)
  echo "Installing Ansible 13.0.0 via pipx..."
  pipx install ansible==13.0.0
  
  # Inject additional tools into ansible environment
  echo "Injecting Molecule and testing tools into Ansible environment..."
  pipx inject ansible molecule==25.11.1
  pipx inject ansible molecule-plugins[docker]==25.8.12
  pipx inject ansible ansible-lint==25.11.1
  pipx inject ansible yamllint==1.37.1
  pipx inject ansible docker==7.1.0
  pipx inject ansible jmespath==1.0.1
  pipx inject ansible netaddr==1.3.0
  
  # Create symlinks for all Ansible tools (pipx doesn't do this automatically for injected packages)
  echo "Creating symlinks for Ansible toolchain..."
  ANSIBLE_VENV_BIN="$PIPX_HOME/venvs/ansible/bin"
  for tool in ansible ansible-playbook ansible-galaxy ansible-vault ansible-config ansible-inventory ansible-lint molecule yamllint; do
    ln -sf "$ANSIBLE_VENV_BIN/$tool" "$PIPX_BIN_DIR/$tool"
  done
  
  # Verify installation
  echo "Verifying Ansible toolchain..."
  $HOME/.local/bin/ansible --version
  $HOME/.local/bin/ansible-playbook --version
  $HOME/.local/bin/ansible-galaxy --version
  $HOME/.local/bin/molecule --version
  $HOME/.local/bin/ansible-lint --version
  
  # Install Ansible Galaxy collections
  if [ -f "${WORKSPACE_FOLDER}/infrastructure/ansible/requirements.yml" ]; then
    echo "Installing Ansible Galaxy collections..."
    export ANSIBLE_GALAXY_SERVER_TIMEOUT=60
    timeout 300 ansible-galaxy collection install -r infrastructure/ansible/requirements.yml --timeout 60 || {
      echo "Warning: Ansible collection installation timed out or failed"
      echo "You can manually install later with: ansible-galaxy collection install -r infrastructure/ansible/requirements.yml"
    }
  fi
  
  echo "✓ Ansible toolchain installed successfully"
else
  echo "No requirements-pip.txt found, skipping Ansible installation..."
fi

echo ""
echo "========================================="
echo "✓ Setup Complete!"
echo "========================================="
echo ""
echo "Available commands:"
echo "  - make up, make down, make restart, make build"
echo "  - make test (run Ansible tests)"
echo "  - ansible --version"
echo "  - molecule --version"
echo "  - java -version"
echo "  - mvn -version"
echo "  - docker --version"
echo ""

