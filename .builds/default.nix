with import <nixpkgs> {};

let
  # TODO override to run functionaltests too
  neovim-pr = neovim-unwrapped.overrideAttrs (oldAttrs: {
      name = "neovim";
      version = "test-pr";
      src = builtins.fetchGit {
        url = https://github.com/neovim/neovim.git;
        # ref = "master";
      };

  });
in
  neovim-pr
