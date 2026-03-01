#!/bin/bash
set -e

echo "🏠 Testing dotfiles setup..."

# gpgのエラー対策
mkdir -p ~/.local/state/gnupg
mkdir -p ~/.local/share/gnupg
chmod 700 ~/.local/share/gnupg

# 実際の使用方法と同じようにchezmoiでセットアップ
# --override-data でテンプレートデータを事前設定し、promptStringOnce のプロンプトをスキップ
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply \
  --override-data '{"gitName":"sakurai-miyo","gitEmail":"sakurai-miyo@example.com"}' \
  ~/dotfiles

echo "✅ Setup completed successfully!"
