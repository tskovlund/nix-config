{
  programs.tmux = {
    enable = true;
    prefix = "C-Space";
    keyMode = "vi";
    mouse = true;
    escapeTime = 0; # no delay after Escape (critical for vi-mode)
    historyLimit = 50000;
    terminal = "tmux-256color";
    baseIndex = 1; # 1-indexed windows/panes (matches keyboard layout)
    extraConfig = ''
      # vi-style pane navigation
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # vi-style pane resizing
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # intuitive splits (| for vertical, - for horizontal)
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"

      # new windows inherit current path
      bind c new-window -c "#{pane_current_path}"

      # extended keys for shift+enter passthrough (Claude Code in tmux -CC)
      set -s extended-keys on
      set -as terminal-features ',xterm*:extkeys'
    '';
  };
}
