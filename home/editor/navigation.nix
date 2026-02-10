{ ... }:

{
  programs.nixvim = {
    plugins = {
      # Fuzzy finder
      telescope = {
        enable = true;
        keymaps = {
          "<leader>sf" = { action = "find_files"; options.desc = "Find files"; };
          "<leader>sg" = { action = "live_grep"; options.desc = "Live grep"; };
          "<leader>sb" = { action = "buffers"; options.desc = "Buffers"; };
          "<leader>sh" = { action = "help_tags"; options.desc = "Help tags"; };
          "<leader>sr" = { action = "oldfiles"; options.desc = "Recent files"; };
          "<leader>sw" = { action = "grep_string"; options.desc = "Grep current word"; };
          "<leader>s/" = { action = "current_buffer_fuzzy_find"; options.desc = "Fuzzy find in buffer"; };
        };
        settings.defaults = {
          file_ignore_patterns = [ "node_modules" "\\.git/" "result/" "\\.direnv/" ];
        };
      };

      # File explorer (buffer-based, opens parent directory)
      oil = {
        enable = true;
        settings = {
          view_options.show_hidden = true;
          skip_confirm_for_simple_edits = true;
        };
      };

      # Enhanced motion / jump
      flash = {
        enable = true;
        settings.modes.search.enabled = false;
      };
    };

    # Navigation keymaps
    keymaps = [
      # Oil — open parent directory
      { mode = "n"; key = "-"; action = "<cmd>Oil<CR>"; options.desc = "Open file explorer"; }

      # Flash — jump forward/backward
      {
        mode = ["n" "x" "o"]; key = "s"; options.desc = "Flash jump";
        action.__raw = ''
          function()
            require("flash").jump()
          end
        '';
      }
      {
        mode = ["n" "x" "o"]; key = "S"; options.desc = "Flash treesitter";
        action.__raw = ''
          function()
            require("flash").treesitter()
          end
        '';
      }

      # Telescope: search TODOs
      { mode = "n"; key = "<leader>sT"; action = "<cmd>TodoTelescope<CR>"; options.desc = "Search TODOs"; }

      # Colorscheme picker with live preview
      {
        mode = "n"; key = "<leader>cs"; options.desc = "Colorscheme picker";
        action.__raw = ''
          function()
            require("telescope.builtin").colorscheme({ enable_preview = true })
          end
        '';
      }
    ];
  };
}
