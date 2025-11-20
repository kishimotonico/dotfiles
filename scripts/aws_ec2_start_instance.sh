#!/bin/bash

function aws_ec2_start_instance() {
    # 停止中のEC2インスタンスのInstanceId、Nameタグ、Public IPを取得
    instances=$(aws ec2 describe-instances \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value | [0],PublicIpAddress,State.Name]' \
        --filters 'Name=instance-state-name,Values=stopped' \
        --output text)

    # fzf用リストを作成: InstanceId\tName
    fzf_list=$(echo "$instances" | awk -v OFS='\t' '{print $1, $2}')

    # fzfでインスタンスを選択（InstanceIdとNameのみ表示）
    selected=$(echo "$fzf_list" | fzf \
        --header="InstanceId / Name" \
        --prompt="起動するEC2インスタンスを選択してください。 > " \
        --height=50% --layout=reverse --border --preview-window 'right:50%' \
        --with-nth=1,2)

    # 選択されなかった場合は終了
    [ -z "$selected" ] && echo "インスタンスが選択されませんでした。" && return

    # InstanceIdを抽出
    instance_id=$(echo "$selected" | awk '{print $1}')

    echo "$instance_id を起動中..."
    echo ""

    # インスタンスを起動し、起動完了まで待機、その後情報を表示
    aws ec2 start-instances --instance-ids "$instance_id" \
        && aws ec2 wait instance-running --instance-ids "$instance_id" \
        && aws ec2 describe-instances --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].[InstanceId,Tags[?Key==`Name`].Value | [0],State.Name,PrivateIpAddress,PublicIpAddress]' \
        --output json | jq -r '[.[]] | ["InstanceId", "Name", "State", "PrivateIp", "PublicIp"], ["----------", "----", "-----", "---------", "--------"], .[] | @tsv' | column -t
}

