{ pkgs, ... }:

{
  programs.git = {
    enable = true;

    settings = {
      user.name = "Thomas Skovlund Hansen";
      user.email = "thomas@skovlund.dev";

      core.editor = "nvim";

      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      rerere.enabled = true;

      alias = {
        flog = "log --graph --oneline --decorate";
        st = "status";
        co = "checkout";
        sw = "switch";
        br = "branch";
        ci = "commit";
        ca = "commit --amend";
        di = "diff";
        ds = "diff --staged";
        unstage = "reset HEAD --";
        last = "log -1 HEAD";
      };
    };

    ignores = [
      # macOS
      ".DS_Store"
      ".AppleDouble"
      "._*"
      ".Spotlight-V100"
      ".Trashes"

      # Windows
      "Thumbs.db"

      # Vim
      "[._]*.s[a-v][a-z]"
      "!*.svg"
      "[._]*.sw[a-p]"
      "[._]s[a-rt-v][a-z]"
      "[._]ss[a-gi-z]"
      "[._]sw[a-p]"
      "Session.vim"
      "Sessionx.vim"
      ".netrwhist"
      "*~"
      "[._]*.un~"
      "tags"

      # VS Code
      ".vscode/*"
      "!.vscode/settings.json"
      "!.vscode/tasks.json"
      "!.vscode/launch.json"
      "!.vscode/extensions.json"
      "*.code-workspace"
      ".history/"

      # JetBrains
      ".idea/"
      "*.iml"

      # Environment files
      ".env"
      ".env.local"

      # Nix / direnv
      ".direnv/"

      # Python
      "*.pyc"
      "__pycache__/"

      # AI tools
      ".claude/"
      ".copilot/"
      ".cursor/"
    ];
  };

  # delta: syntax-highlighted diffs
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
      syntax-theme = "ansi";
    };
  };

  # GitHub CLI (credential helper enabled by default)
  programs.gh = {
    enable = true;
    settings.git_protocol = "https";
  };
}
