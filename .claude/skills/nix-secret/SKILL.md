---
name: nix-secret
description: >
  Guide for adding a new agenix-encrypted secret to the nix-config setup.
  Use when adding SSH keys, API tokens, encrypted config files, or any
  secret that should be age-encrypted. Covers the two-repo workflow between
  nix-config and nix-config-personal.
allowed-tools: Read, Glob, Grep, Edit, Write, Bash(age *), Bash(agenix *), Bash(make check), Bash(make switch *), Bash(nix flake check)
---

# Adding a new agenix secret

This is a two-repo workflow: nix-config-personal holds the encrypted secrets, nix-config wires them into the system.

## Steps

### 1. Register the secret (nix-config-personal)

Add an entry to `secrets/secrets.nix`:

```nix
"<name>.age".publicKeys = [ thomas ];
```

The `thomas` variable holds the age public key: `age15j2yd89h8ahm93g2um8206atnfcl90hk7q062nt63xqrz57lspmsvmyzle`

### 2. Encrypt the secret

**Option A — agenix CLI** (recommended, reads recipients from `secrets/secrets.nix`):
```sh
agenix -e secrets/<name>.age
```

**Option B — age CLI** (non-interactive, useful for piping):
```sh
age -r "age15j2yd89h8ahm93g2um8206atnfcl90hk7q062nt63xqrz57lspmsvmyzle" \
  -o secrets/<name>.age <plaintext-file>
```

### 3. Declare the secret in a home-manager module (nix-config-personal)

Create or update a module under `home/`:

```nix
{ config, ... }:

let
  homeDir = config.home.homeDirectory;
in
{
  age.secrets.<name> = {
    file = ../secrets/<name>.age;
    path = "${homeDir}/<target-path>";
    mode = "0600";  # 0600 for keys, 0644 for config
  };
}
```

### 4. Reference the decrypted path

Use `config.age.secrets.<name>.path` in other modules to reference the decrypted file location.

### 5. Gitignore plaintext sources

If you have a plaintext working copy in `files/`, ensure it's gitignored in nix-config-personal's `.gitignore`.

### 6. Test

```sh
# In nix-config-personal
nix flake check

# In nix-config
make switch PERSONAL_INPUT=path:$HOME/repos/nix-config-personal
```

## Conventions

- **SSH key naming:** `id_ed25519_<purpose>` (e.g., `id_ed25519_github`, `id_ed25519_server`)
- **Mode:** `0600` for private keys, `0644` for config/public content
- **Never commit plaintext** secrets, API keys, or private keys to either repo
- The `.age` files are safe to commit — they're encrypted
- A single portable age key (`~/.config/agenix/age-key.txt`) decrypts everything
