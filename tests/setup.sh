#!/bin/bash
set -e

echo "🏠 Testing dotfiles setup..."

# gpgのエラー対策
mkdir -p ~/.local/state/gnupg
mkdir -p ~/.local/share/gnupg
chmod 700 ~/.local/share/gnupg

# 実際の使用方法と同じようにchezmoiでセットアップ
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply \
  --promptString "gitName=sakurai-miyo" \
  --promptString "gitEmail=sakurai-miyo@example.com" \
  ~/dotfiles

echo "✅ Setup completed successfully!"
