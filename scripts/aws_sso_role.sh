# 今の SSO ログインのまま、同じアカウントの別ロールのキーを今のシェルに入れる
#   aws_sso_role [ROLE]   ROLE の既定は AWSAdministratorAccess。戻すときは awsp でプロファイルを選び直す
# 対象は今の AWS_PROFILE(SSO のプロファイル)のアカウント
function aws_sso_role() {
  local role="${1:-AWSAdministratorAccess}" account cache token sso_region creds account_name expires
  # get-role-credentials にはアクセストークンを直接渡す必要があり、CLI にはそれを出すコマンドがないのでキャッシュから読む
  local valid_token='map(select(.accessToken and (.expiresAt | fromdateiso8601) > now)) | sort_by(.expiresAt) | last // empty | "\(.accessToken)\t\(.region)"'

  if [ -z "${AWS_PROFILE:-}" ]; then
    echo "AWS_PROFILE が空だよ。awsp で SSO のプロファイルを選んでから呼んでね" >&2
    return 1
  fi

  account=$(aws sts get-caller-identity --query Account --output text) || return

  cache=$(jq -rs "$valid_token" ~/.aws/sso/cache/*.json)
  if [ -z "$cache" ]; then
    echo "SSO のトークンが切れてるよ。aws sso login してからもう一回呼んでね" >&2
    return 1
  fi
  IFS=$'\t' read -r token sso_region <<< "$cache"

  creds=$(
    aws sso get-role-credentials --role-name "$role" --account-id "$account" \
      --access-token "$token" --region "$sso_region"
  ) || return

  # プロファイルが残っているとキーの環境変数と混ざるので外す
  unset AWS_PROFILE
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
  AWS_ACCESS_KEY_ID=$(jq -r '.roleCredentials.accessKeyId' <<< "$creds")
  AWS_SECRET_ACCESS_KEY=$(jq -r '.roleCredentials.secretAccessKey' <<< "$creds")
  AWS_SESSION_TOKEN=$(jq -r '.roleCredentials.sessionToken' <<< "$creds")

  account_name=$(aws account get-account-information --query AccountName --output text 2> /dev/null)
  expires=$(jq -r '.roleCredentials.expiration / 1000 | strflocaltime("%H:%M")' <<< "$creds")
  echo "$role @ ${account_name:-?} ($account) に切り替えたよ(期限 $expires)"
}
