## ファイルパスの取扱い

- ここはWSL環境です
- Windowsのパスが指定されることがあります。その場合、WSLのパスに変換してからファイル読み込みしてください (e.g: `C:\Users\koni5\Pictures\image.png` -> `/mnt/c/Users/koni5/Pictures/image.png`)

## Git Rule

- Gitを使う際、特に理由がなければ `-C` オプションは指定しないこと

## Clipboard

- クリップボードにコピーする場合は、`echo "hello" | clip` のように `clip` コマンドを使用すること (Don't use `clip.exe` directly)
