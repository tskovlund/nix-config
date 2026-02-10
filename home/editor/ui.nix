{ pkgs, ... }:

{
  programs.nixvim = {
    # Default colorscheme
    colorschemes.tokyonight = {
      enable = true;
      settings.style = "night";
    };

    # Extra themes available via :colorscheme and <leader>cs picker
    extraPlugins = with pkgs.vimPlugins; [
      gruvbox-nvim
      catppuccin-nvim
      kanagawa-nvim
      rose-pine
      nightfox-nvim
    ];

    plugins = {
      # Statusline
      lualine = {
        enable = true;
        settings = {
          options = {
            theme = "auto";
            component_separators = {
              left = "|";
              right = "|";
            };
            section_separators = {
              left = "";
              right = "";
            };
            globalstatus = true;
          };
          sections = {
            lualine_a = [ "mode" ];
            lualine_b = [ "branch" ];
            lualine_c = [
              {
                __unkeyed-1 = "filename";
                path = 1; # Relative path
              }
              "diagnostics"
            ];
            lualine_x = [
              {
                __unkeyed-1.__raw = ''
                  function()
                    local reg = vim.fn.reg_recording()
                    if reg ~= "" then return "recording @" .. reg end
                    return ""
                  end
                '';
              }
              {
                __unkeyed-1.__raw = ''
                  function()
                    local result = vim.fn.searchcount({ maxcount = 999, timeout = 500 })
                    if result.total and result.total > 0 then
                      return string.format("[%d/%d]", result.current, result.total)
                    end
                    return ""
                  end
                '';
              }
              "filetype"
            ];
            lualine_y = [ "location" ];
            lualine_z = [
              {
                __unkeyed-1.__raw = ''
                  function()
                    return os.date("%H:%M")
                  end
                '';
              }
            ];
          };
        };
      };

      # Indent guides
      indent-blankline = {
        enable = true;
        settings.indent.char = "│";
      };

      # Keybind discovery
      which-key = {
        enable = true;
        settings.spec = [
          {
            __unkeyed-1 = "<leader>s";
            group = "Search";
          }
          {
            __unkeyed-1 = "<leader>d";
            group = "Diagnostics";
          }
          {
            __unkeyed-1 = "<leader>f";
            group = "Format";
          }
          {
            __unkeyed-1 = "<leader>r";
            group = "Refactor";
          }
          {
            __unkeyed-1 = "<leader>c";
            group = "Color";
          }
        ];
      };

      # File type icons
      web-devicons.enable = true;
    };
  };
}
