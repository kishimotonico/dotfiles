## ファイルパスの取扱い

- ここはWSL環境です
- Windowsのパスが指定されることがあります。その場合、WSLのパスに変換してからファイル読み込みしてください (e.g: `C:\Users\nico\Pictures\image.png` -> `/mnt/c/Users/nico/Pictures/image.png`)

## Git Rule

- Gitを使う際、`-C` オプションは利用禁止

## Tools

- Clipboard: クリップボードにコピーする場合、`clip` コマンド(e.g: `echo "hello" | clip`) を使用すること。`clip.exe`の直接利用は禁止
- jq: JSONの解析は必ず`jq`を使うこと。Pythonの`json`モジュールや`python3 -c`でのJSON処理は使用禁止
- rg: grepやfindの代わりに`rg`を推奨

## ファイル編集のルール

- ファイルの作成・書き換えは必ずEdit/Writeツールを使うこと。Bash経由のスクリプト編集(`python3` heredocでの `open(p,'w')`、`sed -i`、`perl -i`、`cat > file <<EOF` など)は原則禁止
    - 理由: diffがユーザーに見えない、チェックポイントで巻き戻せない、`str.replace`の不一致がサイレントに握り潰される
- 例外: 数十ファイル規模の機械的一括置換のみスクリプト可。その場合も実行前に対象と置換内容を説明し、実行後に `git diff` で結果を確認すること
- ファイルを読むときも `cat` ではなくReadツールを使うこと
