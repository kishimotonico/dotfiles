#!/usr/bin/env bash
# Claude Code statusline script
# Line 1: OS | Model | Context bar | Dir | DateTime
# Line 2: 5h usage bar + reset time
# Line 3: 7d usage bar + reset time

set -euo pipefail

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

# Braille Dots gauge (8 cells, 8 levels each)
BRAILLE=(" " "⣀" "⣄" "⣤" "⣦" "⣶" "⣷" "⣿")

braille_bar() {
  local pct=$1
  local width=${2:-8}
  (( pct > 100 )) && pct=100
  (( pct < 0 )) && pct=0
  local bar=""
  for ((i=0; i<width; i++)); do
    local seg_start=$(( i * 100 / width ))
    local seg_end=$(( (i + 1) * 100 / width ))
    if (( pct >= seg_end )); then
      bar+="${BRAILLE[7]}"
    elif (( pct <= seg_start )); then
      bar+="${BRAILLE[0]}"
    else
      local frac=$(( (pct - seg_start) * 7 / (seg_end - seg_start) ))
      (( frac > 7 )) && frac=7
      bar+="${BRAILLE[$frac]}"
    fi
  done
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
  *opus*)   model_name="Opus${ver:+ $ver}" ;;
  *sonnet*) model_name="Sonnet${ver:+ $ver}" ;;
  *haiku*)  model_name="Haiku${ver:+ $ver}" ;;
  *)        model_name="${model:-?}" ;;
esac
# モデル名を11文字にパディングして縦棒位置を固定
model_label="🤖 $(printf '%-10s' "$model_name")"

# ── Context Window ──
size=$(echo "$input" | jq '.context_window.context_window_size // 200000')
size_k=$(fmt_k $size)
ctx_bar=""
usage=$(echo "$input" | jq '.context_window.current_usage // empty')
if [ -n "$usage" ] && [ "$usage" != "null" ]; then
  input_tokens=$(echo "$usage" | jq '.input_tokens // 0')
  cache_create=$(echo "$usage" | jq '.cache_creation_input_tokens // 0')
  cache_read=$(echo "$usage" | jq '.cache_read_input_tokens // 0')
  output_tokens=$(echo "$usage" | jq '.output_tokens // 0')
  current=$((input_tokens + cache_create + cache_read))
  total_tokens=$((current + output_tokens))
  pct=$((total_tokens * 100 / size))
  (( pct > 100 )) && pct=100

  bar=$(braille_bar "$pct")
  color=$(color_for_pct "$pct")
  used_k=$(fmt_k $total_tokens)

  ctx_bar="${color}📊 $(printf '%4s' "$used_k")/${size_k} ${bar} $(printf '%3d' $pct)%${RESET}"
else
  ctx_bar="${GRAY}📊 $(printf '%4s' "--")/${size_k} $(braille_bar 0) $(printf '%3s' "--")%${RESET}"
fi

# ── CWD ──
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
if [ -n "$cwd" ]; then
  dir=$(echo "$cwd" | sed "s|^$HOME|~|" | awk -F/ '{n=NF; if(n<=3) print $0; else printf "…/%s/%s/%s",$(n-2),$(n-1),$n}')
else
  dir="~"
fi

# Format ISO 8601 reset time for Linux
# 5h: remaining time only (no reset clock)
# 7d: reset time HH:mm only (no remaining time)
format_reset_time() {
  local reset_val=$1 label=$2
  [ -z "$reset_val" ] && return
  local epoch now diff
  # resets_at はUnixタイムスタンプ（整数）またはISO 8601文字列
  if [[ "$reset_val" =~ ^[0-9]+$ ]]; then
    epoch=$reset_val
  else
    epoch=$(date -d "$reset_val" +%s 2>/dev/null) || return
  fi
  now=$(date +%s)
  diff=$(( epoch - now ))

  local reset_str
  if [ "$label" = "5h" ]; then
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
    reset_str=$(TZ="Asia/Tokyo" date -d "@${epoch}" +"%-m/%-d %-H:%M" 2>/dev/null)
    [ -n "$reset_str" ] && echo -n "Reset ${reset_str}"
  fi
}

# ── Rate Limits (from input JSON) ──
line2=""

five_util=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' 2>/dev/null)
seven_util=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)
seven_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty' 2>/dev/null)

if [ -n "$five_util" ]; then
  five_int=${five_util%.*}
  [ -z "$five_int" ] && five_int=0
  five_color=$(color_for_pct "$five_int")
  five_bar=$(braille_bar "$five_int")
  five_reset_str=$(format_reset_time "$five_reset" "5h")
  line2="${five_color}⏱  5h ${five_bar} $(printf "%3d" $five_int)%${RESET}"
  [ -n "$five_reset_str" ] && line2+="  ${GRAY}${five_reset_str}${RESET}"
fi

if [ -n "$seven_util" ]; then
  seven_int=${seven_util%.*}
  [ -z "$seven_int" ] && seven_int=0
  seven_color=$(color_for_pct "$seven_int")
  seven_bar=$(braille_bar "$seven_int")
  seven_reset_str=$(format_reset_time "$seven_reset" "7d")
  seven_part="${seven_color}📅 7d ${seven_bar} $(printf "%3d" $seven_int)%${RESET}"
  [ -n "$seven_reset_str" ] && seven_part+="  ${GRAY}${seven_reset_str}${RESET}"
  if [ -n "$line2" ]; then
    line2+="  │ ${seven_part}"
  else
    line2="$seven_part"
  fi
fi

# ── Output ──
# Line 1: Model | Context bar | Dir
line1="${model_label}"
[ -n "$ctx_bar" ] && line1+=" │ ${ctx_bar}"
line1+=" │ 📁 ${dir}"

printf "%b" "$line1"
[ -n "$line2" ] && printf "\n%b" "$line2"
exit 0
