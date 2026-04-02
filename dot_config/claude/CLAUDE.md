## ファイルパスの取扱い

- ここはWSL環境です
- Windowsのパスが指定されることがあります。その場合、WSLのパスに変換してからファイル読み込みしてください (e.g: `C:\Users\koni5\Pictures\image.png` -> `/mnt/c/Users/koni5/Pictures/image.png`)

## Git Rule

- Gitを使う際、`-C` オプションは利用禁止

## Tools

- Clipboard: クリップボードにコピーする場合、`clip` コマンド(e.g: `echo "hello" | clip`) を使用すること。`clip.exe`の直接利用は禁止
- jq: JSONの解析は必ず`jq`を使うこと。Pythonの`json`モジュールや`python3 -c`でのJSON処理は使用禁止
- rg: grepやfindの代わりに`rg`を推奨
