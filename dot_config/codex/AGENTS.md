# Global AGENTS.md

## ファイルパスの取扱い

- ここはWSL環境です
- Windowsのパスが指定されることがあります。その場合、WSLのパスに変換してからファイル読み込みしてください (e.g: `C:\Users\nico\Pictures\image.png` -> `/mnt/c/Users/nico/Pictures/image.png`)

## Git Rule

- Gitを使う際、`-C` オプションは利用禁止

## Tools

- Clipboard: クリップボードにコピーする場合、`clip` コマンド(e.g: `echo "hello" | clip`) を使用すること。`clip.exe`の直接利用は禁止
- jq: JSONの解析は必ず`jq`を使うこと。Pythonの`json`モジュールや`python3 -c`でのJSON処理は使用禁止
- rg: grepやfindの代わりに`rg`を推奨

## Markdown形式のルール

- 水平線 `---` の多用は禁止。セクションは原則として見出しで区切ること。長文で1～2回使用するのはOK
- 見出しを過度に構造化しすぎると読みにくくなるので、原則として3階層以内の見出しが推奨
- 見出しを太字にするのは禁止
