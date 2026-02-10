{ ... }:

{
  programs.nixvim.plugins = {
    # Completion engine
    cmp = {
      enable = true;
      settings = {
        sources = [
          { name = "nvim_lsp"; }
          { name = "luasnip"; }
          { name = "buffer"; }
          { name = "path"; }
        ];
        mapping = {
          "<Tab>" = "cmp.mapping.select_next_item()";
          "<S-Tab>" = "cmp.mapping.select_prev_item()";
          "<CR>" = "cmp.mapping.confirm({ select = true })";
          "<C-Space>" = "cmp.mapping.complete()";
          "<C-e>" = "cmp.mapping.close()";
        };
        snippet.expand = ''
          function(args)
            require("luasnip").lsp_expand(args.body)
          end
        '';
      };
    };

    # Snippets
    luasnip.enable = true;
    friendly-snippets.enable = true;

    # Completion icons
    lspkind = {
      enable = true;
      cmp.enable = true;
      settings.cmp.menu = {
        nvim_lsp = "[LSP]";
        luasnip = "[Snip]";
        buffer = "[Buf]";
        path = "[Path]";
      };
    };

    # Auto-closing pairs (treesitter-aware)
    nvim-autopairs.enable = true;

    # Surround motions (cs"', ds(, ysiw")
    nvim-surround.enable = true;

    # Comment toggling (gcc / gbc)
    comment.enable = true;
  };
}
