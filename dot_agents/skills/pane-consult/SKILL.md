---
name: pane-consult
description: herdr pane間のエージェント相談プロトコル。「[consult from=<pane_id>] …」形式のメッセージを受け取ったとき、または別paneのエージェント(Codexなど)に相談・返信したいときに使う。HERDR_ENV=1 のときのみ有効。
---

# pane-consult — pane間の相談プロトコル

herdr上のpane間メッセージングは `herdr-msg`（`~/.local/bin/herdr-msg`）に集約されている。pane探索・メッセージ整形・Enter取りこぼしを避ける分割送信はスクリプト側がやるので、以下のコマンドをそのまま使えばよい。

```bash
herdr-msg list [agent]                  # 自分以外のエージェントpane一覧 (jsonl)
herdr-msg consult <agent|pane_id> <本文>  # 相談を送る ([consult from=...] と返信手順を自動付与)
herdr-msg pick <agent>                   # consultの自動選択結果のpane_idだけ表示 (送信しない)
herdr-msg reply <pane_id[@terminal_id]> <本文>  # 相談への返信 ([reply from=...] を自動付与)
herdr-msg send <pane_id> <text>          # 整形なしの1行送信
```

## 相談を受け取ったとき

`[consult from=<返信先アドレス>] <質問・依頼>` 形式のメッセージが届いたら:

1. 通常のツールで質問に答える。ユーザーへの報告はいつもどおり行う
2. 送信元に返信する: `from=` の値（`w1:pJ` のような単純なpane_idのこともあれば、`w1:pJ@term_...` のようにterminal_id付きのこともある）を**そのままコピーして** `herdr-msg reply <そのアドレス> '<返事を1行で>'` とする
3. 返事が長くなる場合（レビュー結果・コード・diffなど）は一時ファイルに書き出し、1行の要約とファイルパスだけを送る

## こちらから相談するとき

```bash
herdr-msg consult codex '<相談内容を1行で>'
```

- agent名（`claude` / `codex` など）を渡すと **同一タブ > 同一cwd** の優先順でpaneを自動選択する。**同一タブ・同一cwdのどちらにも一致する候補がない場合は、候補が1つでも自動選択せず** 候補一覧（`title` に相手の作業内容が出る）を出して exit 2 になる。絞り込み後も複数残って決めきれない場合も同様に exit 2 になる。いずれの場合も候補から選んでpane IDを指定して再実行する: `herdr-msg consult <pane_id> '<本文>'`。送信前に選択先だけ確かめたいときは `herdr-msg pick <agent>`
- 送信したら**ポーリングせずターンを終了する**。返事は `[reply from=…]` 形式の入力メッセージとして届く
- 相談内容が長い場合は一時ファイルに書き出し、本文には要約とファイルパスだけを書く

## 注意

- メッセージは必ず1行。改行を含むと `herdr-msg` がエラーで拒否する（長い内容はファイル経由）
- シェル上で適切にクォートする（本文にシングルクォートを含む場合はダブルクォートで囲むなど）。複雑ならファイル経由にする
- 相手が読んだか確認するために相手のpaneを `herdr pane read` しないこと。送った入力はキューされ、相手のターンが終わり次第処理される
- 相手が `working` でも送ってよい（キューされる）
- pane IDは永続的でない。毎回 `herdr-msg list` で探し直す
- `herdr-msg reply` は送信前に宛先paneを検証する。宛先が存在しない、またはagent paneでない（閉じられて再利用された等）場合は送信せずエラーになるので、`herdr-msg list` で送信元を探し直す
- `@terminal_id` 付きアドレスへの返信は、terminal_idからその時点の現在のpane_idを引き直してから送る。相談から返信までの間にpane IDが再割当されていても、terminal_idは永続的なので正しいpaneに届く（一致するterminal_idが見つからない場合は送信元paneが閉じられた可能性がありエラーになる）
- エージェントTUI宛に `herdr pane run` を使わないこと。herdrのバージョンによってはEnterが取りこぼされ、入力欄にテキストが残る。`herdr-msg` は分割送信でこれを回避している（シェル宛は `pane run` でよい）

対になるCodex側の手順は `~/.config/codex/skills/consult-claude/SKILL.md` にある。
