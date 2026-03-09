{ pkgs, ... }:

{
  programs.nixvim = {
    extraPlugins = [ pkgs.vimPlugins.lean-nvim ];

    extraConfigLua = ''
      require("lean").setup({
        lsp = {},
        mappings = true,
      })
    '';
  };
}
