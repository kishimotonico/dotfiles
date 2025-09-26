# saml2awsの設定ファイルからプロファイルをfzfで選択してログインするスクリプトです
# 
# bashrcに適当なエイリアスを定義して使います。デフォルトではWSLからWindows側のsaml2aws.exeを呼び出す想定です。
#
# ```
# alias aws-saml-login=set_aws_saml_login
# ```

function set_aws_saml_login() {
  local SAML2AWS="saml2aws.exe"
  local CONFIG_FILE="$WIN_HOME/.saml2aws"
  
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "saml2awsの設定ファイルが見つかりませんでした: $CONFIG_FILE"
    return 1
  fi

  if ! type $SAML2AWS > /dev/null 2>&1; then
    echo "saml2awsが見つかりません。インストールされていることを確認してください。"
    return 1
  fi

  # INI形式の設定ファイルからプロファイル名を抽出
  local selected_profiles=$(awk -F'[][]' '/^\[/ {print $2}' $CONFIG_FILE |
    grep -v '^default$' |
    sort |
    fzf \
      --prompt "saml2awsのプロファイルを選んでください。 >" \
      --height 50% --layout=reverse --border \
      --preview-window 'right:50%' \
      --preview "awk -v section={} 'BEGIN{RS=\"\n\\\[\"} \$0 ~ \"^\"section\"]\" {print \"[\"\$0}' $CONFIG_FILE"
  )

  if [ -z "$selected_profiles" ]; then
    return
  fi

  echo "> $selected_profiles"

  # 選択されたプロファイルでログイン
  $SAML2AWS login --skip-prompt -a "$selected_profiles"


  # $CONFIG_FILE から `ws_profile   = <aws_profile_name>` を抽出して AWS_PROFILE に設定
  if [ $? -eq 0 ]; then
    echo "ログインに成功しました。"

    local aws_profile=$(awk -v profile="$selected_profiles" '
      # Windowsの改行コード(CR)を各行の末尾から削除
      { sub(/\r$/, "") }
      # 目的のセクション名に一致したら、フラグを立てて次の行へ
      $0 == "[" profile "]" { in_section=1; next }
      # 他のセクションが始まったら、フラグを下ろす
      /^\s*\[/ { in_section=0 }
      # フラグが立っており、かつaws_profileの行を見つけたら
      (in_section && /^\s*aws_profile\s*=/) {
        split($0, parts, "=")
        gsub(/^[ \t]+|[ \t]+$/, "", parts[2])
        print parts[2]
        exit
      }' "$CONFIG_FILE")

    if [ -n "$aws_profile" ]; then
      export AWS_PROFILE="$aws_profile"
      echo "AWS_PROFILEを '$aws_profile' に設定しました。"
    else
      echo "warning: '$selected_profiles' セクションから 'aws_profile' の項目を取得できませんでした。"
    fi
  fi
}
