{
  description = "Neovim flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    {
      overlay = final: prev: {

        neovim = final.neovim-unwrapped.overrideAttrs (oa: {
          version = "master";
          src = ../.;
        });

        # a development binary to help debug issues
        neovim-debug = let
          stdenv = if final.stdenv.isLinux then
            final.llvmPackages_latest.stdenv
          else
            final.stdenv;
        in (final.neovim.override {
          lua = final.luajit;
          inherit stdenv;
        }).overrideAttrs (oa: {

          dontStrip = true;
          NIX_CFLAGS_COMPILE = " -ggdb -Og";

          cmakeBuildType = "Debug";
          cmakeFlags = oa.cmakeFlags ++ [ "-DMIN_LOG_LEVEL=0" ];

          disallowedReferences = [ ];
        });

        # for neovim developers, beware of the slow binary
        neovim-developer = let inherit (final.luaPackages) luacheck;
        in (final.neovim-debug.override {
          doCheck = final.stdenv.isLinux;
        }).overrideAttrs (oa: {
          cmakeFlags = oa.cmakeFlags ++ [
            "-DLUACHECK_PRG=${luacheck}/bin/luacheck"
            "-DMIN_LOG_LEVEL=0"
            "-DENABLE_LTO=OFF"
          ] ++ final.lib.optionals final.stdenv.isLinux [
            # https://github.com/google/sanitizers/wiki/AddressSanitizerFlags
            # https://clang.llvm.org/docs/AddressSanitizer.html#symbolizing-the-reports
            "-DCLANG_ASAN_UBSAN=ON"
          ];
        });
      };
    } // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          overlays = [ self.overlay ];
          inherit system;
        };

        lua = pkgs.lua5_1;

        pythonEnv = pkgs.python3.withPackages (ps: [
          ps.msgpack
          ps.flake8 # for 'make pylint'
        ]);
      in {
        packages = with pkgs; {
          default = neovim;
          inherit neovim neovim-debug neovim-developer;
        };

        checks = {
          pylint = pkgs.runCommand "pylint" {
            nativeBuildInputs = [ pythonEnv ];
            preferLocalBuild = true;
          } "make -C ${./..} pylint > $out";

          shlint = pkgs.runCommand "shlint" {
            nativeBuildInputs = [ pkgs.shellcheck ];
            preferLocalBuild = true;
          } "make -C ${./..} shlint > $out";
        };

        # kept for backwards-compatibility
        defaultPackage = pkgs.neovim;

        devShells = {
          default = pkgs.neovim-developer.overrideAttrs (oa: {

            buildInputs = with pkgs;
              oa.buildInputs ++ [
                cmake
                lua.pkgs.luacheck
                sumneko-lua-language-server
                pythonEnv
                include-what-you-use # for scripts/check-includes.py
                jq # jq for scripts/vim-patch.sh -r
                shellcheck # for `make shlint`
                doxygen # for script/gen_vimdoc.py
                clang-tools # for clangd to find the correct headers
              ];

            shellHook = oa.shellHook + ''
              export NVIM_PYTHON_LOG_LEVEL=DEBUG
              export NVIM_LOG_FILE=/tmp/nvim.log
              export ASAN_SYMBOLIZER_PATH=${pkgs.llvm_11}/bin/llvm-symbolizer

              # ASAN_OPTIONS=detect_leaks=1
              export ASAN_OPTIONS="log_path=./test.log:abort_on_error=1"
              export UBSAN_OPTIONS=print_stacktrace=1

              # for treesitter functionaltests
              mkdir -p runtime/parser
              cp -f ${pkgs.vimPlugins.nvim-treesitter.builtGrammars.c}/parser runtime/parser/c.so
            '';
          });
        };
      });
}
