---
name: consult-claude
description: herdrセッション内の別paneで動いているClaude Code (Fable) に相談・レビュー依頼を送る。実装方針を相談したいとき、セカンドオピニオンやレビューが欲しいとき、ユーザーに「Fableに聞いて」「Claudeに相談して」と言われたときに使う。HERDR_ENV=1 のときのみ有効。
---

# consult-claude — 別paneのClaudeに相談する

herdr内のClaude（Fable）への相談には `herdr-msg` を使う。`HERDR_ENV=1` でなければ利用できない。

## 相談する

```bash
herdr-msg consult claude '<質問・依頼を1行で>'
```

- 同一タブ、同一cwdの順でClaudeを選ぶ。exit 2なら候補をユーザーに確認するか、`herdr-msg consult <terminal_id> '<質問>'` で指定する
- 長い背景、コード、diffは貼らない。Claudeが参照できるファイルや確認コマンドを伝える
- 相手がworkingでも送信できる
- 送信後はポーリングや `pane read` をせず、「Fableに送信した。返事は次のメッセージとして届く」と報告してターンを終える
- `[reply from=…]` が届いたら内容を踏まえて作業を続ける。質問や追加依頼がなければ受領確認だけの返信は送らない
- ユーザーの許可なく、相談以外の操作を相手paneへ指示しない
