#!/bin/bash

# Claude Code statusline — workspace context and session info.
# Symbols and style aligned with starship prompt configuration.

input=$(cat)

# Extract values from JSON with a single jq invocation
eval "$(
  jq -r '
    {
      cwd: .workspace.current_dir,
      model: .model.display_name // "",
      used_pct: .context_window.used_percentage // "",
      cost: .cost.total_cost_usd // "",
      lines_add: .cost.total_lines_added // "",
      lines_del: .cost.total_lines_removed // "",
      version: .version // ""
    }
    | to_entries[]
    | "\(.key)=\(.value | @sh)"
  ' <<< "$input"
)"

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
# Uses git status --porcelain=v2 --branch to minimize subprocess overhead
git_info=""
if git_status=$(git -C "$cwd" status --porcelain=v2 --branch 2>/dev/null); then
    # Parse branch name and ahead/behind from header lines
    branch=$(echo "$git_status" | sed -n 's/^# branch\.head //p')
    if [ "$branch" = "(detached)" ]; then
        commit=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
        git_info="${c_green}@${commit}"
    else
        if [ ${#branch} -gt 32 ]; then
            branch="${branch:0:12}…${branch: -12}"
        fi
        git_info="${c_green}${branch}"
    fi

    # ahead/behind: "# branch.ab +<ahead> -<behind>"
    ab_line=$(echo "$git_status" | grep '^# branch\.ab ')
    if [ -n "$ab_line" ]; then
        ahead=$(echo "$ab_line" | sed 's/.*+\([0-9]*\).*/\1/')
        behind=$(echo "$ab_line" | sed 's/.*-\([0-9]*\).*/\1/')
        if [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
            git_info+=" ${c_green}↑${ahead}↓${behind}"
        elif [ "$ahead" -gt 0 ]; then
            git_info+=" ${c_green}↑${ahead}"
        elif [ "$behind" -gt 0 ]; then
            git_info+=" ${c_green}↓${behind}"
        fi
    fi

    # Stash count (no porcelain equivalent)
    stash_count=$(git -C "$cwd" stash list 2>/dev/null | wc -l | tr -d ' ')
    [ "$stash_count" -gt 0 ] && git_info+=" ${c_green}\$${stash_count}"

    # Merge/rebase state from git dir
    git_dir=$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null)
    [ -f "$git_dir/MERGE_HEAD" ] && git_info+=" ${c_red}merge"
    { [ -d "$git_dir/rebase-merge" ] || [ -d "$git_dir/rebase-apply" ]; } && git_info+=" ${c_red}rebase"

    # Count staged/unstaged/untracked from porcelain output
    # Ordinary entries: "1 XY ..." where X=staged status, Y=unstaged status
    # Untracked: "? path"
    staged=0 unstaged=0 untracked=0
    while IFS= read -r line; do
        case "$line" in
            "1 "?[!.]*)  ((staged++)) ;;   # X is not '.'
            "2 "?[!.]*)  ((staged++)) ;;   # renamed with staged changes
        esac
        case "$line" in
            "1 ".[!.]*)  ((unstaged++)) ;; # Y is not '.'
            "2 ".[!.]*)  ((unstaged++)) ;; # renamed with unstaged changes
        esac
        [[ "$line" == "? "* ]] && ((untracked++))
    done <<< "$git_status"

    [ "$staged" -gt 0 ] && git_info+=" ${c_green}+${staged}"
    [ "$unstaged" -gt 0 ] && git_info+=" ${c_yellow}!${unstaged}"
    [ "$untracked" -gt 0 ] && git_info+=" ${c_blue}?${untracked}"
fi

# --- Claude session info (· separated) ---
sep="${c_dim} · ${c_reset}"
claude_parts=""
[ -n "$model" ] && claude_parts+="${c_magenta}${model}"
[ -n "$used_pct" ] && claude_parts+="${claude_parts:+${sep}}${c_cyan}ctx ${used_pct}%"

if [ -n "$cost" ] && awk -v c="$cost" 'BEGIN { exit !(c > 0) }'; then
    cost_fmt=$(printf '$%.2f' "$cost")
    claude_parts+="${claude_parts:+${sep}}${c_yellow}${cost_fmt}"
fi

if [ -n "$lines_add" ] || [ -n "$lines_del" ]; then
    lines=""
    [ -n "$lines_add" ] && awk -v n="$lines_add" 'BEGIN { exit !(n > 0) }' && lines+="${c_green}+${lines_add}"
    [ -n "$lines_del" ] && awk -v n="$lines_del" 'BEGIN { exit !(n > 0) }' && lines+="${lines:+ }${c_red}-${lines_del}"
    [ -n "$lines" ] && claude_parts+="${claude_parts:+${sep}}${lines}"
fi

[ -n "$version" ] && claude_parts+="${claude_parts:+${sep}}${c_dim}v${version}"

# --- Timestamp ---
current_time=$(date +%H:%M:%S)

# --- Build output (pipe-separated sections) ---
pipe="${c_dim} | ${c_reset}"
output="${c_dir}${dir_parent}${c_dir_b}${dir_last}${c_reset}"
[ -n "$git_info" ] && output+=" ${git_info}${c_reset}"
[ -n "$claude_parts" ] && output+="${pipe}${claude_parts}${c_reset}"
output+="${pipe}${c_dim}${current_time}${c_reset}"

printf '%b' "$output"
