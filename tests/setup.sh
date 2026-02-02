#!/bin/bash
set -e

echo "🏠 Testing dotfiles setup..."

# 実際の使用方法と同じようにchezmoiでセットアップ
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply ~/dotfiles

echo "✅ Setup completed successfully!"
