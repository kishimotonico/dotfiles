---
name: pane-consult
description: herdr pane間のエージェント相談プロトコル。「[consult from=<pane_id>] …」形式のメッセージを受け取ったとき、または別paneのエージェント(Codexなど)に相談・返信したいときに使う。HERDR_ENV=1 のときのみ有効。
---

# pane-consult — pane間の相談プロトコル

herdr上のpane間メッセージングは `herdr-msg`（`~/.local/bin/herdr-msg`）に集約されている。pane探索・メッセージ整形・確実な送信（send-textとEnterの分割送信）はスクリプト側がやるので、以下のコマンドをそのまま使えばよい。

```bash
herdr-msg list [agent]                  # 自分以外のエージェントpane一覧 (jsonl)
herdr-msg consult <agent|pane_id> <本文>  # 相談を送る ([consult from=...] と返信手順を自動付与)
herdr-msg pick <agent>                   # consultの自動選択結果のpane_idだけ表示 (送信しない)
herdr-msg reply <pane_id> <本文>         # 相談への返信 ([reply from=...] を自動付与)
herdr-msg send <pane_id> <text>          # 整形なしの1行送信
```

## 相談を受け取ったとき

`[consult from=<pane_id>] <質問・依頼>` 形式のメッセージが届いたら:

1. 通常のツールで質問に答える。ユーザーへの報告はいつもどおり行う
2. 送信元paneに返信する: `herdr-msg reply <pane_id> '<返事を1行で>'`
3. 返事が長くなる場合（レビュー結果・コード・diffなど）は一時ファイルに書き出し、1行の要約とファイルパスだけを送る

## こちらから相談するとき

```bash
herdr-msg consult codex '<相談内容を1行で>'
```

- agent名（`claude` / `codex` など）を渡すと **同一タブ > 同一cwd** の優先順でpaneを自動選択する。それでも決めきれない場合は候補一覧（`title` に相手の作業内容が出る）を出して exit 2 になるので、候補から選んでpane IDを指定して再実行する: `herdr-msg consult <pane_id> '<本文>'`。送信前に選択先だけ確かめたいときは `herdr-msg pick <agent>`
- 送信したら**ポーリングせずターンを終了する**。返事は `[reply from=…]` 形式の入力メッセージとして届く
- 相談内容が長い場合は一時ファイルに書き出し、本文には要約とファイルパスだけを書く

## 注意

- メッセージは必ず1行。改行を含むと `herdr-msg` がエラーで拒否する（長い内容はファイル経由）
- 本文にシングルクォートを含めない。言い回しを変えるかファイル経由にする
- 相手が読んだか確認するために相手のpaneを `herdr pane read` しないこと。送った入力はキューされ、相手のターンが終わり次第処理される
- 相手が `working` でも送ってよい（キューされる）
- pane IDは永続的でない。毎回 `herdr-msg list` で探し直す
- エージェントTUI宛に `herdr pane run` を使わないこと。herdrのバージョンによってはEnterが取りこぼされ、入力欄にテキストが残る。`herdr-msg` は分割送信でこれを回避している（シェル宛は `pane run` でよい）

対になるCodex側の手順は `~/.config/codex/skills/consult-claude/SKILL.md` にある。
