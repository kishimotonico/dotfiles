# https://tech.innovator.jp.net/entry/2023/06/07/150346

# Set AWS PROFILE using fzf.
function set_aws_profile() {
  # Select AWS PROFILE
  local selected_profile=$(aws configure list-profiles |
    grep -v "default" |
    sort |
    fzf --prompt "Select PROFILE. If press Ctrl-C, unset PROFILE. > " \
        --height 50% --layout=reverse --border --preview-window 'right:50%' \
        --preview "grep {} -A5 ~/.aws/config")

  # If the profile is not selected, unset the environment variable 'AWS_PROFILE', etc.
  if [ -z "$selected_profile" ]; then
    echo "Unset env 'AWS_PROFILE'!"
    unset AWS_PROFILE
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    return
  fi

  # If a profile is selected, set the environment variable 'AWS_PROFILE'.
  echo "Set the environment variable 'AWS_PROFILE' to '${selected_profile}'!"
  export AWS_PROFILE="$selected_profile"
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  
  # Check sso-session 
  local AWS_SSO_SESSION_NAME="your 'sso-session' name"  # sso-sessionの名称に変更

  check_sso_session=$(aws sts get-caller-identity 2>&1)
  if [[ "$check_sso_session" == *"Token has expired"* ]]; then
    # If the session has expired, log in again.
    echo -e "\n----------------------------\nYour Session has expired! Please login...\n----------------------------\n"
    aws sso login --sso-session "${AWS_SSO_SESSION_NAME}"
    aws sts get-caller-identity
  else
    # Display account information upon successful login, and show an error message upon login failure.
    echo ${check_sso_session}
  fi
}
