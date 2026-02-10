{ ... }:

{
  programs.nixvim = {
    globals = {
      mapleader = " ";
      maplocalleader = ",";
    };

    opts = {
      # Line numbers — hybrid: relative for motions, absolute on cursor line
      number = true;
      relativenumber = true;

      # Indentation — 2 spaces by default (treesitter handles per-language overrides)
      expandtab = true;
      tabstop = 2;
      shiftwidth = 2;

      # System clipboard integration
      clipboard = "unnamedplus";

      # Persistent undo across sessions
      undofile = true;

      # Search — case-insensitive unless uppercase letter used
      ignorecase = true;
      smartcase = true;

      # Keep 5 lines visible above/below cursor
      scrolloff = 5;

      # True color support (required for modern colorschemes)
      termguicolors = true;

      # Mouse support (use Option+click for terminal selection on macOS)
      mouse = "a";

      # Always show sign column (prevents layout shift from git/diagnostic signs)
      signcolumn = "yes";

      # Highlight current line
      cursorline = true;

      # Hide mode indicator (lualine shows it)
      showmode = false;

      # Natural split directions
      splitright = true;
      splitbelow = true;

      # Faster CursorHold events (used by gitsigns, hover, etc.)
      updatetime = 250;

      # Faster key sequence timeout (snappier which-key)
      timeoutlen = 300;
    };
  };
}
