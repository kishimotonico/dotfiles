---
name: consult-claude
description: herdrセッション内の別paneで動いているClaude Code (Fable) に相談・レビュー依頼を送る。実装方針を相談したいとき、セカンドオピニオンやレビューが欲しいとき、ユーザーに「Fableに聞いて」「Claudeに相談して」と言われたときに使う。HERDR_ENV=1 のときのみ有効。
---

# consult-claude — 別paneのClaudeに相談する

herdr上では各paneが独立したエージェントとして動いている。pane間メッセージングは `herdr-msg`（`~/.local/bin/herdr-msg`）に集約されており、pane探索・メッセージ整形・確実な送信はスクリプト側がやる。

## 前提チェック

`HERDR_ENV` が `1` でなければ、herdr外で動いているためこのスキルは使えない。その旨を伝えて終了する。

## 相談する

```bash
herdr-msg consult claude '<質問・依頼を1行で>'
```

- **同一タブ > 同一cwd** の優先順でClaude paneを自動選択し、`[consult from=自分のpane ID]` と返信手順を自動で付与して送信する
- 候補が複数で決めきれない場合は候補一覧（jsonl。`title` に相手の作業内容が出る）を出して exit 2 になる。ユーザーに確認するか、pane IDを指定して再実行する: `herdr-msg consult <pane_id> '<本文>'`。送信前に選択先だけ確かめたいときは `herdr-msg pick claude`
- Claude paneが1つも見つからない場合は exit 1 になる。その旨をユーザーに伝えて終了する
- 相手が `working` でも送ってよい（入力はキューされ、相手のターンが終わり次第処理される）

本文が長い場合（diffやコード、詳細な背景説明など）は一時ファイルに書き出し、本文には要約とファイルパスだけを書く:

```bash
cat > /tmp/consult-$$.md <<'EOF'
（相談の詳細・コード・diffなど）
EOF
herdr-msg consult claude '<要約> 詳細は /tmp/consult-XXXX.md を読んで'
```

## ターンを終えて返事を待つ

送信したら**ポーリングせずにターンを終了する**。ユーザーには「Fableに相談を送った。返事は次のメッセージとして届く」と伝える。

返事は `[reply from=<pane_id>] ...` という形式の入力メッセージとして届く。届いたらその内容を踏まえて作業を続ける。追加で聞きたいことがあれば同じ手順で送る。

## 注意

- メッセージは必ず1行。改行を含むと `herdr-msg` がエラーで拒否する（長い内容はファイル経由）
- 本文にシングルクォートを含めない。言い回しを変えるかファイル経由にする
- pane IDは永続的ではない。`herdr-msg` が毎回探し直すので、pane IDを覚えて使い回さないこと
- 相手のpaneの画面を `herdr pane read` でスクレイピングして返事を探さないこと。返事は必ず自paneへの入力として届く
- エージェントTUI宛に `herdr pane run` を使わないこと。herdrのバージョンによってはEnterが取りこぼされ、入力欄にテキストが残る。`herdr-msg` は分割送信でこれを回避している
- ユーザーの許可なく相談以外の操作（相手paneへのコマンド実行指示など）をしないこと
