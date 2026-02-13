#!/usr/bin/env bash
# post-bootstrap.sh — post-switch initialization
#
# Run via: make bootstrap
# Requires: make switch (or bootstrap.sh) to have completed first.

set -euo pipefail

# --- Helpers ------------------------------------------------------------------

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { printf "${BLUE}==>${RESET} ${BOLD}%s${RESET}\n" "$*"; }
ok()    { printf "${GREEN}==>${RESET} ${BOLD}%s${RESET}\n" "$*"; }
warn()  { printf "${YELLOW}==> WARNING:${RESET} %s\n" "$*"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }
is_macos() { [ "$(uname -s)" = "Darwin" ]; }
is_linux() { [ "$(uname -s)" = "Linux" ]; }

echo ""
info "Post-deploy initialization"
echo ""

# --- Step 1: GitHub CLI authentication ----------------------------------------

if command_exists gh; then
  if gh auth status >/dev/null 2>&1; then
    gh_user="$(gh api user -q .login 2>/dev/null || echo "unknown")"
    ok "GitHub CLI: authenticated as $gh_user"
  else
    info "GitHub CLI is not authenticated."
    echo "  This is needed for git operations, creating PRs, etc."
    echo ""
    gh auth login
  fi
else
  warn "GitHub CLI (gh) not found — skipping auth setup."
fi

# --- Step 2: Upload SSH public keys to GitHub ---------------------------------

if command_exists gh && gh auth status >/dev/null 2>&1; then
  # Find SSH public keys deployed by agenix (named id_ed25519_*)
  ssh_pub_keys=()
  for pub in "$HOME"/.ssh/id_ed25519_*.pub; do
    [ -f "$pub" ] && ssh_pub_keys+=("$pub")
  done

  if [ ${#ssh_pub_keys[@]} -gt 0 ]; then
    existing_keys="$(gh ssh-key list 2>/dev/null || true)"
    for pub in "${ssh_pub_keys[@]}"; do
      key_name="$(basename "$pub" .pub)"
      key_fingerprint="$(ssh-keygen -lf "$pub" 2>/dev/null | awk '{print $2}')"
      if echo "$existing_keys" | grep -q "$key_fingerprint" 2>/dev/null; then
        ok "SSH key already on GitHub: $key_name"
      else
        info "Uploading SSH key to GitHub: $key_name"
        if gh ssh-key add "$pub" --title "$key_name" --type authentication; then
          ok "SSH authentication key uploaded: $key_name"
        else
          warn "Failed to upload authentication key: $key_name (add manually with: gh ssh-key add $pub --type authentication)"
        fi
        # Also add as signing key for verified commits
        if gh ssh-key add "$pub" --title "$key_name" --type signing; then
          ok "SSH signing key uploaded: $key_name"
        else
          warn "Failed to upload signing key: $key_name (add manually with: gh ssh-key add $pub --type signing)"
        fi
      fi
    done
  fi
fi

# --- Step 3: Claude Code settings ---------------------------------------------

CLAUDE_SETTINGS="$HOME/.claude/settings.json"

if [ -f "$CLAUDE_SETTINGS" ]; then
  ok "Claude Code settings: already configured ($CLAUDE_SETTINGS)"
else
  info "Writing default Claude Code settings..."
  mkdir -p "$HOME/.claude"
  cat > "$CLAUDE_SETTINGS" << 'JSON'
{
  "enabledPlugins": {
    "Notion@claude-plugins-official": true,
    "linear@claude-plugins-official": true
  },
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  },
  "permissions": {
    "defaultMode": "acceptEdits",
    "allow": [
      "Bash(nix *)",
      "Bash(make *)",
      "Bash(home-manager *)",
      "Bash(darwin-rebuild *)",
      "Bash(nixos-rebuild *)",
      "Bash(git *)",
      "Bash(gh *)",
      "Bash(ls *)",
      "Bash(which *)",
      "Bash(* --version)",
      "Bash(* --help)",
      "Read",
      "mcp__memory__*",
      "mcp__plugin_linear_linear__*",
      "mcp__plugin_Notion_notion__*"
    ],
    "deny": [
      "Bash(curl *)",
      "Bash(wget *)",
      "Read(./.env)",
      "Read(./.env.*)",
      "Read(~/.aws/**)",
      "Read(~/.ssh/id_*)"
    ]
  }
}
JSON
  ok "Claude Code settings written to $CLAUDE_SETTINGS"
fi

# --- Step 4: home-manager backup cleanup --------------------------------------

hm_backups="$(find "$HOME" -maxdepth 3 -name "*.hm-backup" 2>/dev/null || true)"

if [ -n "$hm_backups" ]; then
  echo ""
  info "Found home-manager backup files:"
  echo "$hm_backups" | while read -r f; do echo "  $f"; done
  echo ""
  echo "  These are backups of files that home-manager now manages."
  echo "  They're safe to delete after verifying everything works."
  echo ""
  printf "Delete them? [y/N]: "
  read -r answer || true
  if [[ "${answer:-n}" =~ ^[Yy] ]]; then
    echo "$hm_backups" | while read -r f; do rm -v "$f"; done
    ok "Backup files cleaned up"
  else
    ok "Backup files kept"
  fi
else
  ok "No home-manager backup files found"
fi

# --- Step 5: Stale dotfile cleanup --------------------------------------------

stale_files=(
  "$HOME/.zshrc.old"
  "$HOME/.zshenv.old"
  "$HOME/.zprofile.old"
  "$HOME/.p10k.zsh.old"
  "$HOME/.zshrc-e"
  "$HOME/.profile"
)
stale_dirs=(
  "$HOME/.oh-my-zsh"
  "$HOME/.ppd"
)

found_stale=()
for f in "${stale_files[@]}"; do
  [ -f "$f" ] && found_stale+=("$f")
done
for d in "${stale_dirs[@]}"; do
  [ -d "$d" ] && found_stale+=("$d/")
done

if [ ${#found_stale[@]} -gt 0 ]; then
  echo ""
  info "Found stale dotfiles from previous config:"
  for f in "${found_stale[@]}"; do echo "  $f"; done
  echo ""
  echo "  These are leftovers from a previous shell/editor setup."
  echo "  Nix and home-manager now manage these — the old files are unused."
  echo ""
  printf "Delete them? [y/N]: "
  read -r answer || true
  if [[ "${answer:-n}" =~ ^[Yy] ]]; then
    for f in "${found_stale[@]}"; do rm -rfv "$f"; done
    ok "Stale dotfiles cleaned up"
  else
    ok "Stale dotfiles kept"
  fi
else
  ok "No stale dotfiles found"
fi

# --- Step 6: Manual steps checklist -------------------------------------------

echo ""
printf '%sManual steps remaining%s\n' "${BOLD}" "${RESET}"
echo ""
echo "  These still require manual intervention:"
echo ""

if is_macos; then
  echo "  macOS:"
  echo "    [ ] iTerm2: Preferences > Profiles > Text > Font > select \"FiraCode Nerd Font\""
  echo "    [ ] fn-toggle: System Settings > Privacy & Security > Accessibility > fn-toggle.app"
  echo ""
fi

if is_linux; then
  echo "  Linux/WSL:"
  echo "    [ ] Install a Nerd Font (e.g. FiraCode) in your terminal emulator"
  echo ""
fi

echo "  All platforms:"
echo "    [ ] Open a new terminal and verify the prompt looks correct"
echo ""
