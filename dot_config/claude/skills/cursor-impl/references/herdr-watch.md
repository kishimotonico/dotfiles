# herdr ペインでの観戦実行

「観戦したい」「ペインで見たい」と言われたときの実行方法。`HERDR_ENV` が `1` でなければ herdr 管理下にないので、その旨を伝えて通常の background Bash で実行する。

```bash
out=$(mktemp /tmp/cursor-impl.XXXXXX.log)
self=$(herdr pane list | jq -r --arg cwd "$PWD" '[.result.panes[] | select(.agent=="claude" and .cwd==$cwd)][0].pane_id')
pane=$(herdr pane split "$self" --direction down --no-focus | jq -r '.result.pane.pane_id')
herdr pane run "$pane" "cursor-agent -p --trust --auto-review --model composer-2.5 '<指示>' 2>&1 | tee $out"'; echo "CURSOR""_DONE:$?"'
herdr wait output "$pane" --match 'CURSOR_DONE:' --timeout 1800000
cat "$out"
```

- ペインで見せるときは `--output-format` を外してテキスト出力にする。この場合セッションIDは出力に出ないので、反復が必要なら transcript のディレクトリ名から拾う

    ```bash
    basename "$(ls -1td ~/.cursor/projects/*/agent-transcripts/*/ | head -1)"
    ```

    最終更新が最新のものを採るだけなので、並行して別セッションを走らせているときは当てにならない

- マーカーを `"CURSOR""_DONE"` と分割するのは、入力エコー行への誤マッチ防止(出力の `CURSOR_DONE:<exit code>` だけがマッチする)
- タイムアウト時は `herdr pane read "$pane" --source recent-unwrapped --lines 50` で画面を確認して状況を報告する
- 報告が終わったら `herdr pane close "$pane"` で後始末する(ユーザーが見終わったことを確認してから)
