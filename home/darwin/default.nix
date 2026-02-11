{ ... }:

{
  # Homebrew is installed separately (not managed by Nix) but nix-darwin's
  # homebrew module uses it to manage casks/formulae declaratively.
  # Add to PATH so brew is also available for manual use.
  home.sessionPath = [ "/opt/homebrew/bin" ];
}
