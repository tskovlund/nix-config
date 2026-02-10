{ pkgs, ... }:

{
  programs.nixvim = {
    # Formatter and linter binaries (LSP servers are installed by nixvim automatically)
    extraPackages = with pkgs; [
      nixfmt
      prettierd
      stylua
      statix
      deadnix
    ];

    plugins = {
      # LSP
      lsp = {
        enable = true;
        keymaps = {
          lspBuf = {
            gd = { action = "definition"; desc = "Go to definition"; };
            gD = { action = "declaration"; desc = "Go to declaration"; };
            gr = { action = "references"; desc = "Show references"; };
            K = { action = "hover"; desc = "Hover docs"; };
            "<leader>rn" = { action = "rename"; desc = "Rename symbol"; };
            "<leader>." = { action = "code_action"; desc = "Code action"; };
          };
          diagnostic = {
            "<leader>dj" = { action = "goto_next"; desc = "Next diagnostic"; };
            "<leader>dk" = { action = "goto_prev"; desc = "Previous diagnostic"; };
            "]d" = { action = "goto_next"; desc = "Next diagnostic"; };
            "[d" = { action = "goto_prev"; desc = "Previous diagnostic"; };
          };
        };
        servers = {
          # Nix
          nixd.enable = true;

          # Python
          pyright.enable = true;
          ruff.enable = true;

          # TypeScript / JavaScript
          ts_ls.enable = true;

          # Rust
          rust_analyzer = {
            enable = true;
            installCargo = false;
            installRustc = false;
          };

          # C / C++
          clangd.enable = true;

          # C#
          omnisharp.enable = true;

          # F#
          fsautocomplete.enable = true;

          # Java
          jdtls.enable = true;

          # Lua
          lua_ls.enable = true;
        };
      };

      # Formatting
      conform-nvim = {
        enable = true;
        settings = {
          format_on_save = {
            timeout_ms = 2000;
            lsp_format = "fallback";
          };
          formatters_by_ft = {
            nix = [ "nixfmt" ];
            python = [ "ruff_format" ];
            javascript = [ "prettierd" ];
            typescript = [ "prettierd" ];
            javascriptreact = [ "prettierd" ];
            typescriptreact = [ "prettierd" ];
            json = [ "prettierd" ];
            yaml = [ "prettierd" ];
            markdown = [ "prettierd" ];
            html = [ "prettierd" ];
            css = [ "prettierd" ];
            rust = [ "rustfmt" ];
            lua = [ "stylua" ];
          };
        };
      };

      # Linting
      lint = {
        enable = true;
        lintersByFt = {
          nix = [ "statix" "deadnix" ];
        };
      };

      # Diagnostics panel
      trouble = {
        enable = true;
      };
    };

    # Format keymap
    keymaps = [
      {
        mode = "n";
        key = "<leader>ff";
        options.desc = "Format file";
        action.__raw = ''
          function()
            require("conform").format({ async = true, lsp_format = "fallback" })
          end
        '';
      }
    ];
  };
}
