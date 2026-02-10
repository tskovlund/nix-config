{ ... }:

{
  programs.nixvim = {
    plugins = {
      # Syntax highlighting and smart indentation
      treesitter = {
        enable = true;
        settings = {
          highlight.enable = true;
          indent.enable = true;
        };
      };

      # Highlight TODO/FIXME/HACK/NOTE/WARN
      todo-comments.enable = true;

      # Floating terminal
      toggleterm = {
        enable = true;
        settings = {
          direction = "float";
          open_mapping = "[[<C-\\>]]";
          float_opts = {
            border = "rounded";
          };
        };
      };

      # Mini modules
      mini = {
        enable = true;
        modules = {
          # Better around/inside text objects
          ai = {};
          # Close buffer without destroying window layout
          bufremove = {};
          # Icon provider
          icons = {};
          # Toggle single/multi-line (gS)
          splitjoin = {};
        };
      };
    };
  };
}
