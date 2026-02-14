#!/usr/bin/env bash
# bootstrap.sh — take a fresh machine from zero to fully configured
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/tskovlund/nix-config/main/bootstrap.sh | bash
#   # or clone first, then:
#   ./bootstrap.sh
#
# Idempotent: safe to run multiple times — skips completed steps.

set -euo pipefail

# --- Configuration -----------------------------------------------------------

NIX_CONFIG_REPO="https://github.com/tskovlund/nix-config.git"
DEFAULT_NIX_CONFIG_DIR="$HOME/repos/nix-config"
PERSONAL_INPUT_FILE="$HOME/.config/nix-config/personal-input"
PERSONAL_LOCAL_DIR="$HOME/.config/nix-config/personal-local"

# --- Helpers ------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

info()  { printf "${BLUE}==>${RESET} ${BOLD}%s${RESET}\n" "$*"; }
ok()    { printf "${GREEN}==>${RESET} ${BOLD}%s${RESET}\n" "$*"; }
warn()  { printf "${YELLOW}==> WARNING:${RESET} %s\n" "$*"; }
error() { printf "${RED}==> ERROR:${RESET} %s\n" "$*" >&2; exit 1; }

# Read from /dev/tty so prompts work when script is piped via curl|bash
prompt() {
  local var="$1" message="$2" default="${3:-}"
  if [ -n "$default" ]; then
    printf "%s [%s]: " "$message" "$default" > /dev/tty
  else
    printf "%s: " "$message" > /dev/tty
  fi
  local _reply
  read -r _reply < /dev/tty || true
  if [ -z "$_reply" ] && [ -n "$default" ]; then
    _reply="$default"
  fi
  printf -v "$var" '%s' "$_reply"
}

prompt_yes_no() {
  local message="$1" default="${2:-n}"
  local answer
  if [ "$default" = "y" ]; then
    printf "%s [Y/n]: " "$message" > /dev/tty
  else
    printf "%s [y/N]: " "$message" > /dev/tty
  fi
  read -r answer < /dev/tty || true
  answer="${answer:-$default}"
  case "$answer" in
    [Yy]*) return 0 ;;
    *) return 1 ;;
  esac
}

command_exists() { command -v "$1" >/dev/null 2>&1; }
is_macos() { [ "$(uname -s)" = "Darwin" ]; }
is_linux() { [ "$(uname -s)" = "Linux" ]; }
is_nixos() { [ -e /etc/NIXOS ]; }
is_wsl() { [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; }

# --- Pre-flight checks --------------------------------------------------------

if [ "$(id -u)" -eq 0 ]; then
  error "Do not run this script as root. It uses sudo where needed."
fi

PLATFORM="$(uname -s)"
if is_nixos && is_wsl; then
  info "Detected platform: NixOS-WSL"
elif is_nixos; then
  info "Detected platform: NixOS"
else
  info "Detected platform: $PLATFORM"
fi

# Check required commands
missing=()
for cmd in curl git; do
  command_exists "$cmd" || missing+=("$cmd")
done
if [ ${#missing[@]} -gt 0 ]; then
  if is_macos; then
    error "Missing required commands: ${missing[*]}. Install Xcode CLT: xcode-select --install"
  else
    error "Missing required commands: ${missing[*]}. Install them with your package manager."
  fi
fi

echo ""

# --- Step 1: Install Determinate Nix -----------------------------------------

if command_exists nix; then
  ok "Nix already installed ($(nix --version))"
else
  info "Installing Determinate Nix..."
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install

  # Source nix-daemon so 'nix' is available for the rest of this script
  if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    # shellcheck disable=SC1091
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
  fi

  command_exists nix || error "Nix installation succeeded but 'nix' not found on PATH. Open a new terminal and re-run."
  ok "Nix installed ($(nix --version))"
fi

# --- Step 2: Install Homebrew (macOS only) ------------------------------------

if is_macos; then
  if command_exists brew; then
    ok "Homebrew already installed"
  else
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/tty

    # Add Homebrew to PATH for the rest of this script
    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi

    command_exists brew || error "Homebrew installation succeeded but 'brew' not found on PATH."
    ok "Homebrew installed"
  fi
fi

# --- Step 3: Choose profile ---------------------------------------------------

echo ""
info "Choose a profile:"
echo "  1) personal — full config: base dev environment + personal apps/settings (default)"
echo "  2) base     — dev environment only: shell, editor, git, CLI tools"
echo ""
prompt PROFILE_CHOICE "Profile [1/2]" "1"

case "$PROFILE_CHOICE" in
  2|base)
    PROFILE="base"
    if is_macos; then
      FLAKE_TARGET="darwin-base"
    elif is_nixos && is_wsl; then
      FLAKE_TARGET="nixos-wsl-base"
    elif is_nixos; then
      error "Generic NixOS bootstrap not yet supported. Use NixOS-WSL or add a target for your host."
    else
      FLAKE_TARGET="linux-base"
    fi
    ok "Selected profile: base"
    ;;
  *)
    PROFILE="personal"
    if is_macos; then
      FLAKE_TARGET="darwin"
    elif is_nixos && is_wsl; then
      FLAKE_TARGET="nixos-wsl"
    elif is_nixos; then
      error "Generic NixOS bootstrap not yet supported. Use NixOS-WSL or add a target for your host."
    else
      FLAKE_TARGET="linux"
    fi
    ok "Selected profile: personal"
    ;;
esac

# --- Step 4: Mac App Store sign-in (macOS + personal only) --------------------

if is_macos && [ "$PROFILE" = "personal" ]; then
  echo ""
  warn "Sign into the Mac App Store before continuing."
  echo "  The personal profile includes Mac App Store apps (Amphetamine, iWork,"
  echo "  Final Cut Pro, etc.) and the build will fail if you're not signed in."
  echo ""
  echo "  If you don't want Mac App Store apps, restart with the base profile."
  echo ""
  printf "Press Enter when signed in, or Ctrl+C to abort... " > /dev/tty
  read -r < /dev/tty || true
  echo ""
fi

# --- Step 5: Handle /etc/zshenv conflict (macOS only) ------------------------

if is_macos; then
  if [ -f /etc/zshenv ] && [ ! -L /etc/zshenv ]; then
    ZSHENV_BACKUP="/etc/zshenv.before-nix-darwin"
    if [ -e "$ZSHENV_BACKUP" ]; then
      warn "/etc/zshenv exists but $ZSHENV_BACKUP already exists — skipping."
      echo "  Resolve manually: compare both files and remove the conflicting one."
    else
      info "Moving /etc/zshenv to $ZSHENV_BACKUP (avoids Determinate Nix conflict)"
      sudo mv /etc/zshenv "$ZSHENV_BACKUP"
      ok "/etc/zshenv moved"
    fi
  fi
fi

# --- Step 6: Clone nix-config ------------------------------------------------

# Priority: NIX_CONFIG_DIR env var > running from inside repo > interactive prompt
if [ -n "${NIX_CONFIG_DIR:-}" ]; then
  : # env var already set — use silently (automation mode)
elif [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ] && \
     git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel >/dev/null 2>&1 && \
     [ -f "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)/flake.nix" ]; then
  # Running as ./bootstrap.sh from inside the repo
  NIX_CONFIG_DIR="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
  ok "Running from existing clone: $NIX_CONFIG_DIR"
else
  prompt NIX_CONFIG_DIR "Clone location" "$DEFAULT_NIX_CONFIG_DIR"
fi

if [ -d "$NIX_CONFIG_DIR/.git" ]; then
  ok "nix-config already cloned at $NIX_CONFIG_DIR"
elif [ -d "$NIX_CONFIG_DIR" ] && [ -n "$(ls -A "$NIX_CONFIG_DIR" 2>/dev/null)" ]; then
  error "$NIX_CONFIG_DIR exists and is not empty (and not a git repo). Remove it or choose a different location."
else
  info "Cloning nix-config to $NIX_CONFIG_DIR..."
  mkdir -p "$(dirname "$NIX_CONFIG_DIR")"
  git clone "$NIX_CONFIG_REPO" "$NIX_CONFIG_DIR"
  ok "nix-config cloned"
fi

# --- Step 7: Set up personal identity ----------------------------------------

personal_url=""
if [ -f "$PERSONAL_INPUT_FILE" ]; then
  personal_url="$(tr -d '[:space:]' < "$PERSONAL_INPUT_FILE")"
  if [ -n "$personal_url" ]; then
    ok "Personal identity already configured: $personal_url"
  fi
fi

if [ -z "$personal_url" ]; then
  echo ""
  info "Personal identity not configured."
  echo ""
  echo "  Your personal flake provides username, name, and email."
  echo "  If you have a nix-config-personal repo, enter its flake URL."
  echo "  Example: git+ssh://git@github.com/USER/nix-config-personal"
  echo ""

  prompt personal_url "Personal flake URL (Enter to create a local identity instead)" ""

  if [ -n "$personal_url" ]; then
    # Remote URL provided
    mkdir -p "$(dirname "$PERSONAL_INPUT_FILE")"
    echo "$personal_url" > "$PERSONAL_INPUT_FILE"
    ok "Personal identity saved to $PERSONAL_INPUT_FILE"
  else
    # Create a local identity flake
    echo ""
    info "Creating a local identity flake..."
    echo "  Stored at $PERSONAL_LOCAL_DIR — replace with a remote repo later."
    echo ""

    current_user="$(whoami)"
    prompt local_username "Username (must match your system user)" "$current_user"
    prompt local_fullname "Full name (for git commits)" ""
    prompt local_email "Email (for git commits)" ""

    [ -z "$local_username" ] && error "Username is required."
    [ -z "$local_fullname" ] && error "Full name is required."
    [ -z "$local_email" ] && error "Email is required."

    # Sanitize inputs for Nix string interpolation — escape backslashes,
    # double quotes, ${ sequences, and newlines.
    nix_escape() {
      local s="$1"
      s="${s//\\/\\\\}"       # \ → \\
      s="${s//\"/\\\"}"       # " → \"
      s="${s//\$\{/\\\$\{}"   # ${ → \${
      s="${s//$'\n'/\\n}"     # newline → \n
      printf '%s' "$s"
    }

    safe_username="$(nix_escape "$local_username")"
    safe_fullname="$(nix_escape "$local_fullname")"
    safe_email="$(nix_escape "$local_email")"

    mkdir -p "$PERSONAL_LOCAL_DIR"
    cat > "$PERSONAL_LOCAL_DIR/flake.nix" << FLAKE
{
  description = "Local personal identity for nix-config";

  outputs = { ... }: {
    identity = {
      isStub = false;
      username = "$safe_username";
      fullName = "$safe_fullname";
      email = "$safe_email";
    };
  };
}
FLAKE

    personal_url="path:$PERSONAL_LOCAL_DIR"
    mkdir -p "$(dirname "$PERSONAL_INPUT_FILE")"
    echo "$personal_url" > "$PERSONAL_INPUT_FILE"
    ok "Local identity created at $PERSONAL_LOCAL_DIR"
  fi
fi

# --- Step 8: Age key for secrets decryption -----------------------------------

AGE_KEY_PATH="$HOME/.config/agenix/age-key.txt"

if [ -f "$AGE_KEY_PATH" ]; then
  ok "Age key already exists at $AGE_KEY_PATH"
elif [ "$PROFILE" = "personal" ]; then
  echo ""
  info "Generating age key for agenix secrets decryption..."
  echo "  This key lets make switch decrypt your SSH keys, API tokens, etc."
  echo "  It has no passphrase — security comes from file permissions + disk encryption."
  echo "  The same key is used on all your machines — copy it from an existing one"
  echo "  instead of generating a new one if you've already set up another machine."
  echo ""

  mkdir -p "$(dirname "$AGE_KEY_PATH")"
  chmod 700 "$(dirname "$AGE_KEY_PATH")"

  nix run nixpkgs#age-keygen -- -o "$AGE_KEY_PATH" 2>/dev/null \
    || nix shell nixpkgs#age -c age-keygen -o "$AGE_KEY_PATH"
  chmod 600 "$AGE_KEY_PATH"

  AGE_PUB_KEY="$(nix run nixpkgs#age-keygen -- -y "$AGE_KEY_PATH" 2>/dev/null \
    || nix shell nixpkgs#age -c age-keygen -y "$AGE_KEY_PATH")"
  ok "Age key generated"
  echo ""
  echo "  Public key (add to secrets.nix in your personal flake):"
  echo "  $AGE_PUB_KEY"
  echo ""
fi

# --- Step 9: Create ~/Screenshots (macOS only) -------------------------------

if is_macos; then
  mkdir -p "$HOME/Screenshots"
fi

# --- Step 10: First-time build ------------------------------------------------

cd "$NIX_CONFIG_DIR"

# Build override flags (same logic as Makefile)
# During bootstrap, SSH keys may not exist yet. Convert GitHub SSH/HTTPS URLs
# to the github: shorthand (uses unauthenticated tarball download for public repos).
# The SSH URL stays in personal-input for future make switch runs.
github_shorthand() {
  local url="$1"
  local owner_repo
  # git+ssh://git@github.com/OWNER/REPO → github:OWNER/REPO
  owner_repo="${url#git+ssh://git@github.com/}"
  if [ "$owner_repo" != "$url" ]; then
    printf 'github:%s' "$owner_repo"
    return
  fi
  # git+https://github.com/OWNER/REPO → github:OWNER/REPO
  owner_repo="${url#git+https://github.com/}"
  if [ "$owner_repo" != "$url" ]; then
    printf 'github:%s' "$owner_repo"
    return
  fi
  # Already github: or non-GitHub URL — use as-is
  printf '%s' "$url"
}

OVERRIDE_FLAGS=""
if [ -f "$PERSONAL_INPUT_FILE" ]; then
  override_url="$(tr -d '[:space:]' < "$PERSONAL_INPUT_FILE")"
  if [ -n "$override_url" ]; then
    bootstrap_url="$(github_shorthand "$override_url")"
    if [ "$bootstrap_url" != "$override_url" ]; then
      info "Using $bootstrap_url for bootstrap (SSH not available yet)"
    fi
    OVERRIDE_FLAGS="--override-input personal $bootstrap_url"
  fi
fi

echo ""
info "Running first-time build (target: $FLAKE_TARGET)..."
echo "  This may take a while on the first run — downloading and building packages."
echo ""

if is_macos; then
  # macOS: nix-darwin bootstrap — darwin-rebuild isn't on PATH yet
  info "Building nix-darwin system..."
  # shellcheck disable=SC2086
  nix build ".#darwinConfigurations.${FLAKE_TARGET}.system" $OVERRIDE_FLAGS

  info "Activating nix-darwin (requires sudo)..."
  # shellcheck disable=SC2086
  sudo ./result/sw/bin/darwin-rebuild switch --flake ".#${FLAKE_TARGET}" $OVERRIDE_FLAGS

elif is_nixos; then
  # NixOS: nixos-rebuild is already on PATH.
  # The identity flake may define a different username than the current bootstrap
  # user (e.g. bootstrapping as "nixos" but the config creates "thomas"). When
  # that happens we need a two-phase build:
  #   1. Base build — creates the target user, deploys base config (no secrets)
  #   2. Migrate age key + config to the target user's home
  #   3. Full build — secrets can now decrypt against the migrated age key

  # Resolve the target username from the personal identity flake
  TARGET_USER=""
  if [ -n "${override_url:-}" ]; then
    TARGET_USER=$(nix eval --raw "${bootstrap_url:-$override_url}#identity.username" 2>/dev/null || echo "")
  fi

  CURRENT_USER="$(whoami)"
  NEEDS_MIGRATION=false
  if [ -n "$TARGET_USER" ] && [ "$TARGET_USER" != "$CURRENT_USER" ]; then
    NEEDS_MIGRATION=true
    info "Target user '$TARGET_USER' differs from bootstrap user '$CURRENT_USER' — will migrate files after initial build"
  fi

  if [ "$NEEDS_MIGRATION" = true ] && [ "$PROFILE" = "personal" ]; then
    # Phase 1: base build to create the target user (no secrets to decrypt)
    BASE_FLAKE_TARGET="${FLAKE_TARGET}-base"
    info "Phase 1: Building base NixOS system (creating user $TARGET_USER)..."
    # shellcheck disable=SC2086
    sudo nixos-rebuild switch --flake ".#${BASE_FLAKE_TARGET}" $OVERRIDE_FLAGS

    # Phase 2: migrate bootstrap files to the target user's home
    TARGET_HOME="/home/$TARGET_USER"
    info "Migrating bootstrap files to $TARGET_USER..."

    # Age key
    if [ -f "$AGE_KEY_PATH" ]; then
      sudo mkdir -p "$TARGET_HOME/.config/agenix"
      sudo cp "$AGE_KEY_PATH" "$TARGET_HOME/.config/agenix/age-key.txt"
      sudo chmod 700 "$TARGET_HOME/.config/agenix"
      sudo chmod 600 "$TARGET_HOME/.config/agenix/age-key.txt"
    fi

    # Personal input config
    if [ -f "$PERSONAL_INPUT_FILE" ]; then
      sudo mkdir -p "$TARGET_HOME/.config/nix-config"
      sudo cp "$PERSONAL_INPUT_FILE" "$TARGET_HOME/.config/nix-config/personal-input"
    fi

    # Clone nix-config into target user's home
    if [ ! -d "$TARGET_HOME/repos/nix-config" ]; then
      sudo mkdir -p "$TARGET_HOME/repos"
      sudo git clone "$NIX_CONFIG_REPO" "$TARGET_HOME/repos/nix-config"
    fi

    # Fix ownership of all migrated files
    sudo chown -R "${TARGET_USER}:users" "$TARGET_HOME/.config" "$TARGET_HOME/repos"

    ok "Files migrated to $TARGET_HOME"

    # Phase 3: full personal build — secrets can now decrypt
    NIX_CONFIG_DIR="$TARGET_HOME/repos/nix-config"
    info "Phase 3: Building personal NixOS system (with secrets)..."
    # shellcheck disable=SC2086
    sudo nixos-rebuild switch --flake "${NIX_CONFIG_DIR}#${FLAKE_TARGET}" $OVERRIDE_FLAGS

  elif [ "$NEEDS_MIGRATION" = true ]; then
    # Base profile with different user — single build (no secrets), then migrate config
    info "Building base NixOS system..."
    # shellcheck disable=SC2086
    sudo nixos-rebuild switch --flake ".#${FLAKE_TARGET}" $OVERRIDE_FLAGS

    TARGET_HOME="/home/$TARGET_USER"
    info "Migrating bootstrap files to $TARGET_USER..."

    if [ -f "$PERSONAL_INPUT_FILE" ]; then
      sudo mkdir -p "$TARGET_HOME/.config/nix-config"
      sudo cp "$PERSONAL_INPUT_FILE" "$TARGET_HOME/.config/nix-config/personal-input"
    fi

    if [ ! -d "$TARGET_HOME/repos/nix-config" ]; then
      sudo mkdir -p "$TARGET_HOME/repos"
      sudo git clone "$NIX_CONFIG_REPO" "$TARGET_HOME/repos/nix-config"
    fi

    sudo chown -R "${TARGET_USER}:users" "$TARGET_HOME/.config" "$TARGET_HOME/repos"

    ok "Files migrated to $TARGET_HOME"
    NIX_CONFIG_DIR="$TARGET_HOME/repos/nix-config"

  else
    # No migration needed — current user matches target user
    info "Building NixOS system..."
    # shellcheck disable=SC2086
    sudo nixos-rebuild switch --flake ".#${FLAKE_TARGET}" $OVERRIDE_FLAGS
  fi

elif is_linux; then
  # Generic Linux: home-manager bootstrap — home-manager isn't on PATH yet
  info "Building and activating home-manager..."
  # shellcheck disable=SC2086
  nix run home-manager -- switch --flake ".#${FLAKE_TARGET}" $OVERRIDE_FLAGS

else
  error "Unsupported platform: $PLATFORM"
fi

ok "Build complete!"

# --- Done ---------------------------------------------------------------------

echo ""
printf "${GREEN}${BOLD}Bootstrap complete!${RESET}\n"
echo ""

if [ "${NEEDS_MIGRATION:-false}" = true ]; then
  echo "  Your config created user '$TARGET_USER'. Restart your shell to switch:"
  if is_wsl; then
    echo "    Exit WSL, then re-open it — you'll land as $TARGET_USER automatically."
  else
    echo "    Log out and log back in as $TARGET_USER."
  fi
  echo ""
  echo "  Then finish setup:"
  echo "    cd ~/repos/nix-config"
  echo "    make bootstrap    # Post-deploy setup (gh auth, Claude settings, etc.)"
else
  echo "  Next steps:"
  echo "    cd $NIX_CONFIG_DIR"
  echo "    make bootstrap    # Post-deploy setup (gh auth, Claude settings, etc.)"
fi
echo ""
echo "  For subsequent config changes:"
echo "    make switch            # Apply config"
echo "    make switch IMPURE=1   # Apply with machine-local config"
echo "    make switch REFRESH=1  # Force re-fetch of all inputs (after pushing to personal flake)"
echo ""
