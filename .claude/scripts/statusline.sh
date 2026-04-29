#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract information from JSON
model_name=$(echo "$input" | jq -r '.model.display_name')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')

# Shorten model name: "Opus 4.7 (1M context)" -> "Opus[1M]", "Sonnet 4.6" -> "Sonnet"
short_model="${model_name%% *}"
[[ "$model_name" == *"(1M context)"* ]] && short_model="${short_model}[1M]"

# Extract context window information
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
current_usage=$(echo "$input" | jq '.context_window.current_usage')

# Calculate context percentage
if [ "$current_usage" != "null" ]; then
    current_tokens=$(echo "$current_usage" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    context_percent=$((current_tokens * 100 / context_size))
else
    context_percent=0
fi

# Build context progress bar
bar_width=10
filled=$((context_percent * bar_width / 100))
empty=$((bar_width - filled))
bar=""
for ((i=0; i<filled; i++)); do bar+="█"; done
for ((i=0; i<empty; i++)); do bar+="░"; done

# Get directory name (basename)
dir_name=$(basename "$current_dir")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
GRAY='\033[0;96m'
NC='\033[0m' # No Color

# Build context bar display
context_info="${GRAY}${bar}${NC} ${context_percent}%"

# Ring meter for rate limits (5h / 7d)
# Pattern 3 from https://nyosegawa.com/posts/claude-code-statusline-rate-limits/
RINGS=('○' '◔' '◑' '◕' '●')

build_ring_segment() {
    local label="$1"
    local pct="$2"
    local extra="$3"  # optional suffix, e.g. " (4h12m)"
    # Clamp pct: bash 3.2 (macOS) returns "" for negative array index, bash 4+ wraps.
    # Also guards display width when API returns >100 in quota-over edge cases.
    [ "$pct" -lt 0 ] && pct=0
    [ "$pct" -gt 100 ] && pct=100

    # 0-24%=○, 25-49%=◔, 50-74%=◑, 75-99%=◕, 100%=●
    local idx=$((pct / 25))
    [ "$idx" -gt 4 ] && idx=4
    local ring="${RINGS[$idx]}"

    # Truecolor gradient: 0%=green(0,200,80) -> 50%=yellow(255,200,60) -> 100%=red(255,0,60)
    local color
    if [ "$pct" -lt 50 ]; then
        local r=$((pct * 51 / 10))
        [ "$r" -gt 255 ] && r=255
        color="\033[38;2;${r};200;80m"
    else
        local g=$((200 - (pct - 50) * 4))
        [ "$g" -lt 0 ] && g=0
        color="\033[38;2;255;${g};60m"
    fi

    echo -n "${label} ${color}${ring}${NC} ${pct}%${extra}"
}

# Format remaining seconds as " (5d3h)", " (4h12m)" or " (42m)"; empty if non-positive
format_remaining() {
    local resets_at="$1"
    [ -z "$resets_at" ] && return
    local remaining=$((resets_at - $(date +%s)))
    [ "$remaining" -le 0 ] && return
    local d=$((remaining / 86400))
    local h=$((remaining / 3600))
    local m=$(((remaining % 3600) / 60))
    if [ "$d" -gt 0 ]; then
        printf ' (%dd%dh)' "$d" "$((h % 24))"
    elif [ "$h" -gt 0 ]; then
        printf ' (%dh%dm)' "$h" "$m"
    else
        printf ' (%dm)' "$m"
    fi
}

# rate_limits is absent for non-Pro/Max users or before the first API response
five_h_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty | floor')
five_h_resets_at=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_d_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty | floor')
seven_d_resets_at=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

five_h_segment=""
seven_d_segment=""
[ -n "$five_h_pct" ] && five_h_segment=$(build_ring_segment "5h" "$five_h_pct" "$(format_remaining "$five_h_resets_at")")
[ -n "$seven_d_pct" ] && seven_d_segment=$(build_ring_segment "7d" "$seven_d_pct" "$(format_remaining "$seven_d_resets_at")")

# Output the status line
output="${BLUE}${dir_name}${NC} ${GRAY}|${NC} ${CYAN}${short_model}${NC} ${GRAY}|${NC} ${context_info}"
[ -n "$five_h_segment" ] && output="${output} ${GRAY}|${NC} ${five_h_segment}"
[ -n "$seven_d_segment" ] && output="${output} ${GRAY}|${NC} ${seven_d_segment}"
echo -e "$output"
