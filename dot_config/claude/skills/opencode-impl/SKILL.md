---
name: opencode-impl
description: OpenCode CLI (opencode run) に実装・修正タスクを委譲する。「OpenCodeに実装させて」「Kimiにやらせて」「OpenCodeで直して」などの場面で使用。Codexに依頼する場合は codex-impl を使う。
---

# OpenCode Implementation

OpenCode CLI に実装・修正タスクを委譲し、結果をレビューして報告する。やることは codex-impl と同じで、依頼先が OpenCode という違いだけ。

実装は `implement` エージェント(`~/.config/opencode/agent/implement.md`、`mode: all`)経由で行う。**利用モデルはこのエージェント定義に一元管理されており、変わりうる**。スキル側でモデル名をハードコードしない(`-m` は使わない)。

## 手順

### 1. 依頼内容の整理

OpenCodeはこの会話の文脈を知らない前提で、自己完結したプロンプトにまとめる。含める項目:

- 背景 / 対象ファイル / 期待する結果 / 制約
- 検証分担: OpenCode側で回すコマンドと、委譲元側でやる検証(ブラウザ実機確認・画像生成)を明示
- **「git commit・git add はしないこと」を明記**(コミットは委譲元側で行う)
- レンダリング依存・バイナリ成果物(スクリーンショット等)は生成させない

worktree隔離は、複数エージェントを並行で走らせるなら必須。単独なら不要。

### 2. 実行(background Bash)

実装は数分かかるので、必ず `run_in_background: true` で実行する。プロジェクトディレクトリから実行する(セッションはディレクトリ単位で管理されるため)。

```bash
out=$(mktemp /tmp/oc-impl.XXXXXX.log)
err=$(mktemp /tmp/oc-impl.XXXXXX.err)
title="oc-impl-$(date +%s)"
echo "output: $out / stderr: $err / title: $title"
opencode run --agent implement --title "$title" "<指示>" > "$out" 2>"$err" </dev/null
```

重要:

- `--title` に一意な名前を付ける。後でセッションIDを引くための鍵になる
- **`--format json` は使わない**(1.18.3で無出力のままハングする事象を確認。通常出力で十分抽出できる)
- **`--auto` は原則使わない**。既定権限で workspace 内の編集・bashは許可済み。`--auto` は明示deny以外を全許可する危険なフラグなので、権限待ちで停止する場合だけ検討する
- 実行中はClaudeは working tree を変更しない(並行編集事故の防止。読み取りはOK)
- **レートリミット(5時間上限)に達すると、エラーがstderrに出ず無出力のままハングする**(1.18.3で確認)。長時間(5分以上)無出力なら `~/.local/share/opencode/log/opencode.log` の末尾を確認し、`usage limit reached` があれば TaskStop で止めてリセット時刻をユーザーに報告する

### 3. 結果確認

完了通知が来たら確認する:

```bash
cat "$out"                                      # 最終報告(末尾にエージェントの報告が出る)
opencode session list | rg "$title"             # セッションID(反復用に控える。1列目が ses_... のID)
git status --short && git diff                  # 実際の変更
```

OpenCodeの自己申告を鵜呑みにせず、差分を自分でレビューする。ビルド・テスト・lintがあれば回す。

`implement` エージェントは、UI・公開インターフェース・互換性・データ形式・スコープ等の製品判断が発生すると作業を止めて差し戻してくる。差し戻された論点は自分で決めず、ユーザーと相談してから手順4で続きを依頼する。

### 4. 反復(必要な場合)

修正を差し戻すときは、手順3で取ったセッションIDを明示して継続する:

```bash
opencode run -s <session_id> --agent implement "<修正指示>" > "$out2" 2>"$err2" </dev/null
```

`-c`(直前セッションの継続)は使用禁止。並行で別セッションが動いていると無関係なセッションを掴むため、必ずIDを明示する。

### 5. 報告

- 何が変わったか(`file:line` 参照付き)、自分のレビュー所見、テスト結果を日本語で報告
- コミットはユーザーの指示があるまでしない

## ユーザーが進捗を見たい場合

「観戦したい」「ペインで見たい」と言われたら、background Bash の代わりに herdr のペインで実行する。`HERDR_ENV` が `1` でなければ herdr 管理下にないので、その旨を伝えて通常の background Bash で実行する。

```bash
out=$(mktemp /tmp/oc-impl.XXXXXX.log)
title="oc-impl-$(date +%s)"
self=$(herdr pane list | jq -r --arg cwd "$PWD" '[.result.panes[] | select(.agent=="claude" and .cwd==$cwd)][0].pane_id')
pane=$(herdr pane split "$self" --direction down --no-focus | jq -r '.result.pane.pane_id')
herdr pane run "$pane" "opencode run --agent implement --title '$title' '<指示>' 2>&1 | tee $out"'; echo "OC""_DONE:$?"'
herdr wait output "$pane" --match 'OC_DONE:' --timeout 1800000
cat "$out"
```

- マーカーを `"OC""_DONE"` と分割するのは、入力エコー行への誤マッチ防止(出力の `OC_DONE:<exit code>` だけがマッチする)
- タイムアウト時は `herdr pane read "$pane" --source recent-unwrapped --lines 50` で画面を確認して状況を報告する
- 反復が必要なら、控えたセッションIDで同じペインに `opencode run -s <id> ...` を流用できる
- 報告が終わったら `herdr pane close "$pane"` で後始末する(ユーザーが見終わったことを確認してから)
