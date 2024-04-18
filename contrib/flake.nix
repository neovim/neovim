{
  description = "Neovim flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      inherit (builtins)
        elemAt
        foldl'
        mapAttrs
        match
        readFile
        ;
      inherit (nixpkgs.lib)
        const
        flip
        pipe
        remove
        splitString
        toLower
        ;
    in
    {
      overlay = final: prev: {

        neovim = (final.neovim-unwrapped.override {
          treesitter-parsers = pipe ../cmake.deps/deps.txt [
            readFile
            (splitString "\n")
            (map (match "TREESITTER_([A-Z_]+)_(URL|SHA256)[[:space:]]+([^[:space:]]+)[[:space:]]*"))
            (remove null)
            (flip foldl' { }
              (acc: matches:
                let
                  lang = toLower (elemAt matches 0);
                  type = toLower (elemAt matches 1);
                  value = elemAt matches 2;
                in
                acc // {
                  ${lang} = acc.${lang} or { } // {
                    ${type} = value;
                  };
                }))
            (mapAttrs (const final.fetchurl))
            (self: self // {
              markdown = final.stdenv.mkDerivation {
                inherit (self.markdown) name;
                src = self.markdown;
                installPhase = ''
                  mv tree-sitter-markdown $out
                '';
              };
            })
          ];
        }).overrideAttrs (oa: rec {
          version = self.shortRev or "dirty";
          src = ../.;
          preConfigure = oa.preConfigure or "" + ''
            sed -i cmake.config/versiondef.h.in -e 's/@NVIM_VERSION_PRERELEASE@/-dev-${version}/'
          '';
          nativeBuildInputs = oa.nativeBuildInputs ++ [
            final.libiconv
          ];
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

          disallowedReferences = [ ];
        });

        # for neovim developers, beware of the slow binary
        neovim-developer = let inherit (final.luaPackages) luacheck;
        in final.neovim-debug.overrideAttrs (oa: {
          cmakeFlags = oa.cmakeFlags ++ [
            "-DLUACHECK_PRG=${luacheck}/bin/luacheck"
            "-DENABLE_LTO=OFF"
          ] ++ final.lib.optionals final.stdenv.isLinux [
            # https://github.com/google/sanitizers/wiki/AddressSanitizerFlags
            # https://clang.llvm.org/docs/AddressSanitizer.html#symbolizing-the-reports
            "-DENABLE_ASAN_UBSAN=ON"
          ];
          doCheck = final.stdenv.isLinux;
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
        ]);
      in {
        packages = with pkgs; {
          default = neovim;
          inherit neovim neovim-debug neovim-developer;
        };

        checks = {
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
                lua.pkgs.luacheck
                sumneko-lua-language-server
                pythonEnv
                include-what-you-use # for scripts/check-includes.py
                jq # jq for scripts/vim-patch.sh -r
                shellcheck # for `make shlint`
              ];

            nativeBuildInputs = with pkgs;
              oa.nativeBuildInputs ++ [
                clang-tools # for clangd to find the correct headers
              ];

            shellHook = oa.shellHook + ''
              export NVIM_PYTHON_LOG_LEVEL=DEBUG
              export NVIM_LOG_FILE=/tmp/nvim.log
              export ASAN_SYMBOLIZER_PATH=${pkgs.llvm_18}/bin/llvm-symbolizer

              # ASAN_OPTIONS=detect_leaks=1
              export ASAN_OPTIONS="log_path=./test.log:abort_on_error=1"

              # for treesitter functionaltests
              mkdir -p runtime/parser
              cp -f ${pkgs.vimPlugins.nvim-treesitter.builtGrammars.c}/parser runtime/parser/c.so
            '';
          });
        };
      });
}
