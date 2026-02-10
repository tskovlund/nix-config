#!/bin/bash

# Claude Code statusline — workspace context and session info.
# Symbols and style aligned with starship prompt configuration.

input=$(cat)

# Extract values from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
lines_add=$(echo "$input" | jq -r '.cost.total_lines_added // empty')
lines_del=$(echo "$input" | jq -r '.cost.total_lines_removed // empty')
version=$(echo "$input" | jq -r '.version // empty')

# Colors — standard ANSI, muted palette
c_dir=$'\033[36m'        # directory (cyan)
c_dir_b=$'\033[1;36m'    # directory last segment (bold cyan)
c_green=$'\033[32m'      # git branch / staged / lines added
c_yellow=$'\033[33m'     # git modified / cost
c_blue=$'\033[34m'       # git untracked
c_red=$'\033[31m'        # git conflict state / lines removed
c_dim=$'\033[2m'         # separators, version, timestamp
c_magenta=$'\033[35m'    # model name
c_cyan=$'\033[36m'       # context usage
c_reset=$'\033[0m'

# --- Directory (…/ truncation, matching starship truncation_length=3) ---
short_dir="${cwd/#$HOME/~}"
if [[ "$short_dir" == ~/* ]]; then
    IFS='/' read -ra parts <<< "${short_dir#\~/}"
    if [ ${#parts[@]} -gt 3 ]; then
        last3=("${parts[@]: -3}")
        short_dir="…/$(IFS='/'; echo "${last3[*]}")"
    fi
fi

# Bold the last path segment for quick identification
dir_parent="${short_dir%/*}/"
dir_last="${short_dir##*/}"
[ "$dir_parent" = "${short_dir}/" ] && dir_parent="" && dir_last="$short_dir"

# --- Git status (starship-aligned: ↑↓ +!?$) ---
git_info=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
    if [ -z "$branch" ]; then
        commit=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
        git_info="${c_green}@${commit}"
    else
        if [ ${#branch} -gt 32 ]; then
            branch="${branch:0:12}…${branch: -12}"
        fi
        git_info="${c_green}${branch}"
    fi

    behind=$(git -C "$cwd" rev-list --count HEAD..@{upstream} 2>/dev/null || echo 0)
    ahead=$(git -C "$cwd" rev-list --count @{upstream}..HEAD 2>/dev/null || echo 0)
    if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
        git_info+=" ${c_green}↑${ahead}↓${behind}"
    elif [ "$ahead" -gt 0 ]; then
        git_info+=" ${c_green}↑${ahead}"
    elif [ "$behind" -gt 0 ]; then
        git_info+=" ${c_green}↓${behind}"
    fi

    stash_count=$(git -C "$cwd" stash list 2>/dev/null | wc -l | tr -d ' ')
    [ "$stash_count" -gt 0 ] && git_info+=" ${c_green}\$${stash_count}"

    git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
    [ -f "$git_dir/MERGE_HEAD" ] && git_info+=" ${c_red}merge"
    { [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; } && git_info+=" ${c_red}rebase"

    staged=$(git -C "$cwd" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
    [ "$staged" -gt 0 ] && git_info+=" ${c_green}+${staged}"

    unstaged=$(git -C "$cwd" diff --name-only 2>/dev/null | wc -l | tr -d ' ')
    [ "$unstaged" -gt 0 ] && git_info+=" ${c_yellow}!${unstaged}"

    untracked=$(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
    [ "$untracked" -gt 0 ] && git_info+=" ${c_blue}?${untracked}"
fi

# --- Claude session info (· separated) ---
sep="${c_dim} · ${c_reset}"
claude_parts=""
[ -n "$model" ] && claude_parts+="${c_magenta}${model}"
[ -n "$used_pct" ] && claude_parts+="${claude_parts:+${sep}}${c_cyan}ctx ${used_pct}%"

if [ -n "$cost" ] && [ "$cost" != "0" ]; then
    cost_fmt=$(printf '$%.2f' "$cost")
    claude_parts+="${claude_parts:+${sep}}${c_yellow}${cost_fmt}"
fi

if [ -n "$lines_add" ] || [ -n "$lines_del" ]; then
    lines=""
    [ -n "$lines_add" ] && [ "$lines_add" != "0" ] && lines+="${c_green}+${lines_add}"
    [ -n "$lines_del" ] && [ "$lines_del" != "0" ] && lines+="${lines:+ }${c_red}-${lines_del}"
    [ -n "$lines" ] && claude_parts+="${claude_parts:+${sep}}${lines}"
fi

[ -n "$version" ] && claude_parts+="${claude_parts:+${sep}}${c_dim}v${version}"

# --- Timestamp ---
current_time=$(date +%H:%M:%S)

# --- Build output ---
output="${c_dir}${dir_parent}${c_dir_b}${dir_last}${c_reset}"
[ -n "$git_info" ] && output+=" ${git_info}${c_reset}"
[ -n "$claude_parts" ] && output+=" ${c_dim}·${c_reset} ${claude_parts}${c_reset}"
output+=" ${c_dim}· ${current_time}${c_reset}"

printf '%b' "$output"
