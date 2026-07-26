---
name: cursor-impl
description: Cursor Agent CLI (cursor-agent -p) に実装・修正・調査タスクを委譲する。「Cursorに実装させて」「Composerにやらせて」「Cursorで直して」などの場面で使用。Codexに依頼する場合は codex-impl、OpenCodeなら opencode-impl を使う。
---

# Cursor Agent Implementation

Cursor Agent CLI に実装・修正タスクを委譲し、結果をレビューして報告する。やることは codex-impl / opencode-impl と同じで、依頼先が Cursor Agent という違いだけ。

モデルは `--model composer-2.5` を既定にする。他のモデルを使うのはユーザーが指定したときだけ(`cursor-agent --list-models` で一覧が出る)。

## 権限フラグ(先に読む)

ここを間違えると静かに失敗するので、フラグの意味を把握してから実行する。2026.07.23-e383d2b で実測した挙動:

- `--trust` は必須。付けないと "Workspace Trust Required" を表示して**何もせず正常終了(exit 0)**する。空振りに気付きにくい
- 権限フラグなしの `-p` では、ファイル編集は通るが **Shell がすべて拒否される**。「テストは実行できませんでした」と報告してくるので、検証させたいなら `--auto-review` を付ける
- `--auto-review` はサーバ側分類器が安全な操作を自動実行する。ただし `sudo rm -rf <path>` すら承認を挟まず実行に回した。**安全弁として当てにしない**
- `--force` / `--yolo` は全許可。`--auto-review` で足りるので原則使わない
- `--sandbox enabled` は WSL では効かなかった。ワークスペース外(`/home/nico` 直下)への書き込みが素通りする。**隔離を期待しない**
- `-p` では承認待ちでハングしない。実行できない操作は失敗としてモデルに返り、代替を試すか報告してくる

隔離が要る作業(ワークスペース外に触れる、複数エージェントの並行実行)は `-w, --worktree <name>` を使う。`~/.cursor/worktrees/<repo>/<name>` に git worktree を作る。

## 手順

### 1. 依頼内容の整理

Cursorはこの会話の文脈を知らない前提で、自己完結したプロンプトにまとめる。含める項目:

- 背景 / 対象ファイル / 期待する結果 / 制約
- 検証分担: Cursor側で回すコマンドと、委譲元側でやる検証(ブラウザ実機確認・画像生成)を明示
- **「git commit・git add はしないこと」を明記**(コミットは委譲元側で行う)
- レンダリング依存・バイナリ成果物(スクリーンショット等)は生成させない

調査だけを頼むなら `--mode plan`(分析と計画の提案)か `--mode ask`(Q&A)を付ける。どちらも読み取り専用なので、書き換えられる心配なく投げられる。

### 2. 実行(background Bash)

実装は数分かかるので、必ず `run_in_background: true` で実行する。プロジェクトディレクトリから実行する。

```bash
out=$(mktemp /tmp/cursor-impl.XXXXXX.json)
err=$(mktemp /tmp/cursor-impl.XXXXXX.err)
echo "output: $out / stderr: $err"
cursor-agent -p --trust --auto-review --model composer-2.5 --output-format json "<指示>" > "$out" 2>"$err" </dev/null
```

- 実行中はClaudeは working tree を変更しない(並行編集事故の防止。読み取りはOK)
- `--output-format json` は**全部終わってから単一オブジェクトを一度に吐く**。途中経過は見えないので、進捗を追いたいときは `--output-format stream-json --stream-partial-output` にする
- 長時間(10分以上)出力ファイルが空のままならフリーズの可能性。TaskStop で止めて報告する

### 3. 結果確認

出力は1行のJSONオブジェクト。`jq` でそのまま読める:

```bash
jq -r '.result' "$out"                     # 最終報告
jq -r '.session_id' "$out"                 # セッションID(反復用に控える)
jq -r '.is_error, .subtype, .usage' "$out" # 失敗判定とトークン消費
git status --short && git diff             # 実際の変更
```

`is_error` が false でも、Shell拒否で検証を飛ばしていることがある。Cursorの自己申告を鵜呑みにせず、差分を自分でレビューし、ビルド・テスト・lintは自分でも回す。

作業ログの全文が要るときは `~/.cursor/projects/<パスをスラグ化したもの>/agent-transcripts/<session_id>/<session_id>.jsonl` に残っている。ツール呼び出し単位で追える。

### 4. 反復(必要な場合)

修正を差し戻すときは、手順3で取ったセッションIDを明示して継続する:

```bash
cursor-agent -p --resume <session_id> --trust --auto-review --model composer-2.5 --output-format json "<修正指示>" > "$out2" 2>"$err2" </dev/null
```

`--continue`(直前セッションの継続)は使用禁止。並行で別セッションが動いていると無関係なセッションを掴むため、必ずIDを明示する。継続時も `session_id` は同じ値が返る。

### 5. 報告

- 何が変わったか(`file:line` 参照付き)、自分のレビュー所見、テスト結果を日本語で報告
- コミットはユーザーの指示があるまでしない

## ユーザーが進捗を見たい場合

「観戦したい」「ペインで見たい」と言われたら、background Bash の代わりに herdr のペインで実行する。`HERDR_ENV` が `1` でなければ herdr 管理下にないので、その旨を伝えて通常の background Bash で実行する。

```bash
out=$(mktemp /tmp/cursor-impl.XXXXXX.log)
self=$(herdr pane list | jq -r --arg cwd "$PWD" '[.result.panes[] | select(.agent=="claude" and .cwd==$cwd)][0].pane_id')
pane=$(herdr pane split "$self" --direction down --no-focus | jq -r '.result.pane.pane_id')
herdr pane run "$pane" "cursor-agent -p --trust --auto-review --model composer-2.5 '<指示>' 2>&1 | tee $out"'; echo "CURSOR""_DONE:$?"'
herdr wait output "$pane" --match 'CURSOR_DONE:' --timeout 1800000
cat "$out"
```

- ペインで見せるときは `--output-format` を外してテキスト出力にする。この場合セッションIDは出力に出ないので、反復が必要なら transcript のディレクトリ名から拾う(更新順に並ぶので先頭が最新)

    ```bash
    slug=$(echo "$PWD" | sed 's#^/##; s#[/_.]#-#g; s#-\+#-#g')
    ls -1t ~/.cursor/projects/"$slug"/agent-transcripts/ | head -1
    ```

    スラグ化の規則は推測なので、当たらなければ `ls -1t ~/.cursor/projects/` から目視で探す

- マーカーを `"CURSOR""_DONE"` と分割するのは、入力エコー行への誤マッチ防止(出力の `CURSOR_DONE:<exit code>` だけがマッチする)
- タイムアウト時は `herdr pane read "$pane" --source recent-unwrapped --lines 50` で画面を確認して状況を報告する
- 報告が終わったら `herdr pane close "$pane"` で後始末する(ユーザーが見終わったことを確認してから)
