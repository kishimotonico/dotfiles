#!/usr/bin/env bash
# Claude Code statusline script
# Line 1: OS | Model | Context bar | Dir | DateTime
# Line 2: 5h usage bar + reset time
# Line 3: 7d usage bar + reset time

set -euo pipefail

CACHE_FILE="/tmp/claude-usage-cache.json"
CACHE_TTL=360

# ── Colors ──
GREEN="\033[38;2;151;201;195m"
YELLOW="\033[38;2;229;192;123m"
RED="\033[38;2;224;108;117m"
GRAY="\033[38;2;92;99;112m"
RESET="\033[0m"

color_for_pct() {
  local pct=$1
  if (( pct >= 80 )); then printf '%s' "$RED"
  elif (( pct >= 50 )); then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"
  fi
}

progress_bar() {
  local pct=$1
  local filled=$(( pct / 10 ))
  (( filled > 10 )) && filled=10
  local empty=$(( 10 - filled ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar+="█"; done
  for ((i=0; i<empty; i++)); do bar+="░"; done
  echo -n "$bar"
}

fmt_k() {
  local n=$1
  if (( n >= 1000000 )); then
    awk "BEGIN {printf \"%.1fM\", $n/1000000}"
  elif (( n >= 1000 )); then
    echo "$(( (n + 500) / 1000 ))K"
  else
    echo "${n}"
  fi
}

input=$(cat)

# ── Model ──
model=$(echo "$input" | jq -r '.model // empty')
ver=$(echo "$model" | grep -oP '\d+[-.]\d+' | head -1 | tr '-' '.')
case "$model" in
  *opus*)   model_label="🤖 Opus${ver:+ $ver}" ;;
  *sonnet*) model_label="🤖 Sonnet${ver:+ $ver}" ;;
  *haiku*)  model_label="🤖 Haiku${ver:+ $ver}" ;;
  *)        model_label="🤖 ${model:-?}" ;;
esac

# ── Context Window ──
ctx_bar=""
usage=$(echo "$input" | jq '.context_window.current_usage // empty')
if [ -n "$usage" ] && [ "$usage" != "null" ]; then
  input_tokens=$(echo "$usage" | jq '.input_tokens // 0')
  cache_create=$(echo "$usage" | jq '.cache_creation_input_tokens // 0')
  cache_read=$(echo "$usage" | jq '.cache_read_input_tokens // 0')
  output_tokens=$(echo "$usage" | jq '.output_tokens // 0')
  current=$((input_tokens + cache_create + cache_read))
  total_tokens=$((current + output_tokens))
  size=$(echo "$input" | jq '.context_window.context_window_size // 200000')
  pct=$((total_tokens * 100 / size))
  (( pct > 100 )) && pct=100

  bar=$(progress_bar "$pct")
  color=$(color_for_pct "$pct")
  used_k=$(fmt_k $total_tokens)
  size_k=$(fmt_k $size)

  ctx_bar="${color}${used_k}/${size_k} ${bar} ${pct}%${RESET}"
fi

# ── CWD ──
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
if [ -n "$cwd" ]; then
  dir=$(echo "$cwd" | sed "s|^$HOME|~|" | awk -F/ '{n=NF; if(n<=3) print $0; else printf "…/%s/%s/%s",$(n-2),$(n-1),$n}')
else
  dir="~"
fi


# ── API Usage (5h / 7d) ──
fetch_usage() {
  local cred_file="$HOME/.config/claude/.credentials.json"
  [ ! -f "$cred_file" ] && return 1
  local token
  token=$(jq -r '.claudeAiOauth.accessToken // empty' "$cred_file" 2>/dev/null)
  [ -z "$token" ] && return 1

  # Check cache
  if [ -f "$CACHE_FILE" ]; then
    local age
    age=$(( $(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0) ))
    if (( age < CACHE_TTL )); then
      cat "$CACHE_FILE"
      return 0
    fi
  fi

  # Fetch from API
  local resp
  resp=$(curl -sf --max-time 5 \
    -H "Authorization: Bearer ${token}" \
    -H "anthropic-beta: oauth-2025-04-20" \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null) || return 1

  echo "$resp" > "$CACHE_FILE"
  echo "$resp"
}

# Format ISO 8601 reset time for Linux
# 5h: remaining time only (no reset clock)
# 7d: reset time HH:mm only (no remaining time)
format_reset_time() {
  local iso_time=$1 label=$2
  [ -z "$iso_time" ] && return
  local epoch
  epoch=$(date -d "$iso_time" +%s 2>/dev/null) || return
  local now diff
  now=$(date +%s)
  diff=$(( epoch - now ))

  local reset_str
  if [ "$label" = "5h" ]; then
    # 5h: "Reset HH:mm (~Xh Ym)"
    reset_str=$(TZ="Asia/Tokyo" date -d "@${epoch}" +"%-H:%M" 2>/dev/null)
    if [ -n "$reset_str" ]; then
      local remaining=""
      if (( diff > 0 )); then
        local hours=$(( diff / 3600 ))
        local mins=$(( (diff % 3600) / 60 ))
        if (( hours > 0 )); then
          remaining="~${hours}h${mins}m"
        else
          remaining="~${mins}m"
        fi
      fi
      echo -n "Reset ${reset_str}${remaining:+ ($remaining)}"
    fi
  else
    # 7d: MM/DD HH:mm
    reset_str=$(TZ="Asia/Tokyo" date -d "@${epoch}" +"%-m/%-d %-H:%M" 2>/dev/null)
    [ -n "$reset_str" ] && echo -n "Reset ${reset_str}"
  fi
}

line2=""
line3=""
usage_json=$(fetch_usage 2>/dev/null || true)

if [ -n "$usage_json" ]; then
  # 5-hour limit
  five_util=$(echo "$usage_json" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
  five_reset=$(echo "$usage_json" | jq -r '.five_hour.resets_at // empty' 2>/dev/null)

  if [ -n "$five_util" ]; then
    five_int=${five_util%.*}
    [ -z "$five_int" ] && five_int=0
    five_color=$(color_for_pct "$five_int")
    five_bar=$(progress_bar "$five_int")
    five_reset_str=$(format_reset_time "$five_reset" "5h")
    line2="${five_color}⏱  5h ${five_bar} ${five_int}%${RESET}"
    [ -n "$five_reset_str" ] && line2+="  ${GRAY}${five_reset_str}${RESET}"
  fi

  # 7-day limit
  seven_util=$(echo "$usage_json" | jq -r '.seven_day.utilization // empty' 2>/dev/null)
  seven_reset=$(echo "$usage_json" | jq -r '.seven_day.resets_at // empty' 2>/dev/null)

  if [ -n "$seven_util" ]; then
    seven_int=${seven_util%.*}
    [ -z "$seven_int" ] && seven_int=0
    seven_color=$(color_for_pct "$seven_int")
    seven_bar=$(progress_bar "$seven_int")
    seven_reset_str=$(format_reset_time "$seven_reset" "7d")
    line3="${seven_color}📅 7d ${seven_bar} ${seven_int}%${RESET}"
    [ -n "$seven_reset_str" ] && line3+="  ${GRAY}${seven_reset_str}${RESET}"
  fi
fi

# ── Output ──
# Line 1: Model | Context bar | Dir
line1="${model_label}"
[ -n "$ctx_bar" ] && line1+=" │ ${ctx_bar}"
line1+=" │ 📁 ${dir}"

printf "%b" "$line1"
[ -n "$line2" ] && printf "\n%b" "$line2"
[ -n "$line3" ] && printf "\n%b" "$line3"
exit 0
