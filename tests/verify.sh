#!/bin/bash

echo "🔍 Verifying installed applications and their versions..."

# miseをactivate（非インタラクティブシェル用）
export PATH="$HOME/.local/bin:$PATH"
eval "$($HOME/.local/bin/mise activate bash)"

# Initialize failure flag
failed=0

# Function to check version with fallback
check_version() {
  local tool=$1
  local version_cmd=$2
  echo -n "Checking $tool: "
  if command -v $tool >/dev/null 2>&1; then
    eval $version_cmd 2>/dev/null || echo "installed (version check failed)"
  else
    echo "❌ NOT FOUND"
    failed=1
  fi
}

# Check APT installed packages
echo "📦 APT packages:"
check_version "rename" "rename --version | head -1"
check_version "zip" "zip --version | head -1"
check_version "unzip" "unzip -v | head -1"
check_version "whois" "whois --version"
check_version "nmap" "nmap --version | head -1"
check_version "gcc" "gcc --version | head -1"

echo ""
echo "🛠️  mise-managed tools:"
echo "mise: $(mise --version)"
echo "mise installed tools:"
mise list 2>/dev/null || echo "No tools listed (may still be installing)"
echo ""

# Check specific tools from config.toml
check_version "aws" "aws --version"
check_version "fzf" "fzf --version"
check_version "jq" "jq --version"
check_version "uv" "uv --version"
check_version "node" "node --version"
check_version "pnpm" "pnpm --version"
check_version "gh" "gh --version | head -1"
check_version "hadolint" "hadolint --version"

# Check npm packages
echo ""
echo "📦 NPM global packages:"
npm list -g --depth=0 2>/dev/null | grep -E "(claude-code|biome|devcontainers|aws-cdk|http-server|npm-check-updates|wscat)" || echo "Some npm packages may not be fully installed"

echo ""
echo "📂 Configuration files:"
echo "~/.bashrc exists: $(test -f ~/.bashrc && echo "✅" || echo "❌")"
echo "~/.config/mise/config.toml exists: $(test -f ~/.config/mise/config.toml && echo "✅" || echo "❌")"

echo ""

# Check if any verification failed and exit accordingly
if [ "$failed" -eq 1 ]; then
  echo "🚫 One or more verification checks failed."
  exit 1
fi

echo "✅ Verification completed successfully!"