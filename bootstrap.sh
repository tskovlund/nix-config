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

# --- Pre-flight checks --------------------------------------------------------

if [ "$(id -u)" -eq 0 ]; then
  error "Do not run this script as root. It uses sudo where needed."
fi

PLATFORM="$(uname -s)"
info "Detected platform: $PLATFORM"

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
    else
      FLAKE_TARGET="linux-base"
    fi
    ok "Selected profile: base"
    ;;
  *)
    PROFILE="personal"
    if is_macos; then
      FLAKE_TARGET="darwin"
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
    # double quotes, and ${ sequences that would break or inject into Nix strings.
    nix_escape() {
      local s="$1"
      s="${s//\\/\\\\}"       # \ → \\
      s="${s//\"/\\\"}"       # " → \"
      s="${s//\$\{/\\\$\{}"   # ${ → \${
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

# --- Step 8: Age key check (forward-compatible) ------------------------------

AGE_KEY_PATH="$HOME/.config/agenix/age-key.txt"

if [ ! -f "$AGE_KEY_PATH" ]; then
  if [ -d "$NIX_CONFIG_DIR/secrets" ] && \
     compgen -G "$NIX_CONFIG_DIR/secrets/*.age" >/dev/null 2>&1; then
    echo ""
    warn "Agenix secrets found but no age key at $AGE_KEY_PATH"
    echo "  Generate one:  age-keygen -o $AGE_KEY_PATH"
    echo "  Then add the public key to secrets.nix and re-encrypt."
    echo ""
  fi
fi

# --- Step 9: Create ~/Screenshots (macOS only) -------------------------------

if is_macos; then
  mkdir -p "$HOME/Screenshots"
fi

# --- Step 10: First-time build ------------------------------------------------

cd "$NIX_CONFIG_DIR"

# Build override flags (same logic as Makefile)
OVERRIDE_FLAGS=""
if [ -f "$PERSONAL_INPUT_FILE" ]; then
  override_url="$(tr -d '[:space:]' < "$PERSONAL_INPUT_FILE")"
  if [ -n "$override_url" ]; then
    OVERRIDE_FLAGS="--override-input personal $override_url"
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

elif is_linux; then
  # Linux: home-manager bootstrap — home-manager isn't on PATH yet
  info "Building and activating home-manager..."
  # shellcheck disable=SC2086
  nix run home-manager -- switch --flake ".#${FLAKE_TARGET}" $OVERRIDE_FLAGS

else
  error "Unsupported platform: $PLATFORM"
fi

ok "Build complete!"

# --- Done ---------------------------------------------------------------------

echo ""
printf '%s%sBootstrap complete!%s\n' "${GREEN}" "${BOLD}" "${RESET}"
echo ""
echo "  Next steps:"
echo "    cd $NIX_CONFIG_DIR"
echo "    make bootstrap    # Post-deploy setup (gh auth, Claude settings, etc.)"
echo ""
echo "  For subsequent config changes:"
echo "    make switch            # Apply config"
echo "    make switch IMPURE=1   # Apply with machine-local config"
echo ""
