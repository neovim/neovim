{
  description = "Neovim flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    {
      overlay = final: prev:
        let
          pkgs = nixpkgs.legacyPackages.${prev.system};
        in
        rec {
          neovim = pkgs.neovim-unwrapped.overrideAttrs (oa: {
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
            stdenv = if pkgs.stdenv.isLinux then pkgs.llvmPackages_latest.stdenv else pkgs.stdenv;
            lua = pkgs.enableDebugging pkgs.luajit;
          }).overrideAttrs (oa: {
            cmakeBuildType = "Debug";
            cmakeFlags = oa.cmakeFlags ++ [
              "-DMIN_LOG_LEVEL=0"
            ];
          });

          # for neovim developers, very slow
          # brings development tools as well
          neovim-developer =
            let
              lib = nixpkgs.lib;
              pythonEnv = pkgs.python3;
              luacheck = pkgs.luaPackages.luacheck;
            in
            (neovim-debug.override ({ doCheck = pkgs.stdenv.isLinux; })).overrideAttrs (oa: {
              cmakeFlags = oa.cmakeFlags ++ [
                "-DLUACHECK_PRG=${luacheck}/bin/luacheck"
                "-DMIN_LOG_LEVEL=0"
                "-DENABLE_LTO=OFF"
                "-DUSE_BUNDLED=OFF"
              ] ++ pkgs.stdenv.lib.optionals pkgs.stdenv.isLinux [
                # https://github.com/google/sanitizers/wiki/AddressSanitizerFlags
                # https://clang.llvm.org/docs/AddressSanitizer.html#symbolizing-the-reports
                "-DCLANG_ASAN_UBSAN=ON"
              ];

              nativeBuildInputs = oa.nativeBuildInputs ++ (with pkgs; [
                pythonEnv
                include-what-you-use # for scripts/check-includes.py
                jq # jq for scripts/vim-patch.sh -r
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
    } //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          overlays = [ self.overlay ];
          inherit system;
        };
      in
      rec {

        packages = with pkgs; {
          inherit neovim neovim-debug neovim-developer;
        };

        defaultPackage = pkgs.neovim;

        apps = {
          nvim = flake-utils.lib.mkApp { drv = pkgs.neovim; name = "nvim"; };
          nvim-debug = flake-utils.lib.mkApp { drv = pkgs.neovim-debug; name = "nvim"; };
        };

        defaultApp = apps.nvim;

        devShell = pkgs.neovim-developer;
      }
    );
}
