{ ... }:

{
  programs.nixvim.keymaps = [
    # Clear search highlight
    { mode = "n"; key = "<Esc>"; action = "<cmd>nohlsearch<CR>"; options.desc = "Clear search highlight"; }

    # Window navigation
    { mode = "n"; key = "<C-h>"; action = "<C-w>h"; options.desc = "Move to left window"; }
    { mode = "n"; key = "<C-j>"; action = "<C-w>j"; options.desc = "Move to lower window"; }
    { mode = "n"; key = "<C-k>"; action = "<C-w>k"; options.desc = "Move to upper window"; }
    { mode = "n"; key = "<C-l>"; action = "<C-w>l"; options.desc = "Move to right window"; }

    # Buffer management
    { mode = "n"; key = "<leader><leader>"; action = "<cmd>b#<CR>"; options.desc = "Toggle previous buffer"; }
    {
      mode = "n"; key = "<leader>q"; options.desc = "Close buffer";
      action.__raw = ''
        function()
          require("mini.bufremove").delete(0, false)
        end
      '';
    }
    { mode = "n"; key = "<leader>w"; action = "<cmd>w<CR>"; options.desc = "Save"; }

    # Delete without yanking (black hole register)
    { mode = ["n" "v"]; key = "x"; action = "\"_x"; options.desc = "Delete char (no yank)"; }
    { mode = ["n" "v"]; key = "X"; action = "\"_X"; options.desc = "Delete char backward (no yank)"; }

    # Exit terminal mode
    { mode = "t"; key = "<Esc><Esc>"; action = "<C-\\><C-n>"; options.desc = "Exit terminal mode"; }
  ];
}
