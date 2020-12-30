{
  description = "Neovim flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    legacyPkgs = nixpkgs.legacyPackages."${system}".pkgs;
    pkgs = legacyPkgs;
  in {

    packages."${system}" = rec {

      neovim = legacyPkgs.neovim-unwrapped.overrideAttrs(oa: {
        version = "master";
        src = ../.;

        buildInputs = oa.buildInputs ++ ([
          pkgs.tree-sitter
        ]);

        cmakeFlags = oa.cmakeFlags ++ [
          "-DUSE_BUNDLED=OFF"
        ];
      });

      # a development binary to help debug issues
      neovim-debug = (neovim.override {
          stdenv = pkgs.llvmPackages_latest.stdenv;
          lua = pkgs.enableDebugging legacyPkgs.luajit;
        }).overrideAttrs(oa:{
          cmakeBuildType="Debug";
          cmakeFlags = oa.cmakeFlags ++ [
            "-DMIN_LOG_LEVEL=0"
          ];
      });

      # for neovim developers, very slow
      # brings development tools as well
      neovim-developer = let
        lib = nixpkgs.lib;
        pythonEnv = legacyPkgs.python3;
        luacheck = legacyPkgs.luaPackages.luacheck;
      in
        (neovim-debug.override({doCheck = true;})).overrideAttrs(oa: {
          cmakeFlags = oa.cmakeFlags ++ [
            "-DLUACHECK_PRG=${luacheck}/bin/luacheck"
            "-DMIN_LOG_LEVEL=0"
            "-DENABLE_LTO=OFF"
            "-DUSE_BUNDLED=OFF"
            # https://github.com/google/sanitizers/wiki/AddressSanitizerFlags
            # https://clang.llvm.org/docs/AddressSanitizer.html#symbolizing-the-reports
            "-DCLANG_ASAN_UBSAN=ON"
          ];

        nativeBuildInputs = oa.nativeBuildInputs ++ (with pkgs; [
            pythonEnv
            include-what-you-use  # for scripts/check-includes.py
            jq                    # jq for scripts/vim-patch.sh -r
            doxygen
        ]);

        shellHook = oa.shellHook + ''
          export NVIM_PYTHON_LOG_LEVEL=DEBUG
          export NVIM_LOG_FILE=/tmp/nvim.log

          export ASAN_OPTIONS="log_path=./test.log:abort_on_error=1"
          export UBSAN_OPTIONS=print_stacktrace=1
        '';
      });
    };

    defaultPackage."${system}" = self.packages."${system}".neovim;

    overlay = final: prev: {
      inherit (self.packages."${system}") neovim neovim-debug;
    };

    apps."${system}" = let
      mkApp = pkg: {
        type = "app";
        program = pkg + "/bin/nvim";
      };
    in {
      nvim = mkApp self.packages."${system}".neovim;
      nvim-debug = mkApp self.packages."${system}".neovim-debug;
    };

    defaultApp."${system}" = self.apps."${system}".nvim;

    devShell."${system}" = self.packages."${system}".neovim-developer;
  };
}
