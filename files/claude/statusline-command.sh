#!/bin/bash

# Claude Code statusline — workspace context and session info.
# Symbols and style aligned with starship prompt configuration.
#
# Sections, pipe-separated:
#   workspace  — directory and git state
#   session    — model, effort, fast mode, context, cost, lines, version
#   limits     — 5-hour and 7-day rate-limit windows (subscription only)
#   trailer    — session name and clock
#
# Defaults inside the jq object constructor are parenthesised on purpose:
# jq 1.7 (Apple's /usr/bin/jq) rejects a bare `key: .x // ""` there.

input=$(cat)

# Extract values from JSON with a single jq invocation
eval "$(
  jq -r '
    {
      cwd: .workspace.current_dir,
      model: (.model.display_name // ""),
      effort: (.effort.level // ""),
      fast: (.fast_mode // false),
      used_pct: (.context_window.used_percentage // ""),
      cost: (.cost.total_cost_usd // ""),
      lines_add: (.cost.total_lines_added // ""),
      lines_del: (.cost.total_lines_removed // ""),
      version: (.version // ""),
      rl_5h: (.rate_limits.five_hour.used_percentage // ""),
      rl_5h_reset: (.rate_limits.five_hour.resets_at // ""),
      rl_7d: (.rate_limits.seven_day.used_percentage // ""),
      session: (.session_name // "")
    }
    | to_entries[]
    | "\(.key)=\(.value | @sh)"
  ' <<< "$input"
)"

# Colors — standard ANSI, muted palette
c_dir=$'\033[36m'        # directory (cyan)
c_dir_b=$'\033[1;36m'    # directory last segment (bold cyan)
c_green=$'\033[32m'      # git branch / staged / lines added / limits ok
c_yellow=$'\033[33m'     # git modified / cost / fast mode / limits warning
c_blue=$'\033[34m'       # git untracked
c_red=$'\033[31m'        # git conflict state / lines removed / limits critical
c_dim=$'\033[2m'         # separators, version, timestamp, effort, session name
c_magenta=$'\033[35m'    # model name
c_cyan=$'\033[36m'       # context usage
c_reset=$'\033[0m'

# --- Directory (…/ truncation, matching starship truncation_length=3) ---
# The replacement goes through a variable: bash 5.2+ tilde-expands a bare ~
# in the replacement, which left the full $HOME prefix in place.
tilde="~"
short_dir="${cwd/#$HOME/$tilde}"
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
if [ -n "$model" ]; then
    claude_parts+="${c_magenta}${model}"
    # Effort and fast mode sit next to the model: both change mid-session
    # via /effort and /fast and are otherwise invisible.
    [ -n "$effort" ] && claude_parts+=" ${c_dim}${effort}${c_reset}"
    [ "$fast" = "true" ] && claude_parts+=" ${c_yellow}fast${c_reset}"
fi
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

# --- Rate limits (subscription windows; absent until the first API response) ---
# Colour by how much of the window is gone: green < 60, yellow < 85, red above.
limit_color() {
    awk -v p="$1" -v g="$c_green" -v y="$c_yellow" -v r="$c_red" \
        'BEGIN { if (p >= 85) printf "%s", r; else if (p >= 60) printf "%s", y; else printf "%s", g }'
}

limits=""
if [ -n "$rl_5h" ]; then
    limits+="$(limit_color "$rl_5h")5h $(printf '%.0f' "$rl_5h")%"
    # Local wall-clock time the 5-hour window resets; the 7-day reset is days
    # away and not worth the width.
    if [ -n "$rl_5h_reset" ]; then
        reset_hm=$(date -r "$rl_5h_reset" +%H:%M 2>/dev/null || date -d "@$rl_5h_reset" +%H:%M 2>/dev/null)
        [ -n "$reset_hm" ] && limits+=" ${c_dim}${reset_hm}${c_reset}"
    fi
fi
if [ -n "$rl_7d" ]; then
    limits+="${limits:+${sep}}$(limit_color "$rl_7d")7d $(printf '%.0f' "$rl_7d")%"
fi

# --- Trailer: session name and clock ---
# The session name distinguishes parallel sessions; an AI-generated title can
# be long, so cap it.
trailer=""
if [ -n "$session" ]; then
    [ ${#session} -gt 28 ] && session="${session:0:27}…"
    trailer+="${c_dim}${session}${c_reset}"
fi
trailer+="${trailer:+${sep}}${c_dim}$(date +%H:%M:%S)${c_reset}"

# --- Build output (pipe-separated sections) ---
pipe="${c_dim} | ${c_reset}"
output="${c_dir}${dir_parent}${c_dir_b}${dir_last}${c_reset}"
[ -n "$git_info" ] && output+=" ${git_info}${c_reset}"
[ -n "$claude_parts" ] && output+="${pipe}${claude_parts}${c_reset}"
[ -n "$limits" ] && output+="${pipe}${limits}${c_reset}"
output+="${pipe}${trailer}"

printf '%b' "$output"
