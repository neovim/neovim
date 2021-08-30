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
          });

          # a development binary to help debug issues
          neovim-debug = let
            stdenv = if pkgs.stdenv.isLinux then pkgs.llvmPackages_latest.stdenv else pkgs.stdenv;
          in
            ((neovim.override {
            lua = pkgs.luajit;
            inherit stdenv;
          }).overrideAttrs (oa: {

            dontStrip = true;
            NIX_CFLAGS_COMPILE = " -ggdb -Og";

            cmakeBuildType = "Debug";
            cmakeFlags = oa.cmakeFlags ++ [
              "-DMIN_LOG_LEVEL=0"
            ];

            disallowedReferences = [];
          }));

          # for neovim developers, beware of the slow binary
          neovim-developer =
            let
              lib = nixpkgs.lib;
              luacheck = pkgs.luaPackages.luacheck;
            in
            (neovim-debug.override ({ doCheck = pkgs.stdenv.isLinux; })).overrideAttrs (oa: {
              cmakeFlags = oa.cmakeFlags ++ [
                "-DLUACHECK_PRG=${luacheck}/bin/luacheck"
                "-DMIN_LOG_LEVEL=0"
                "-DENABLE_LTO=OFF"
              ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
                # https://github.com/google/sanitizers/wiki/AddressSanitizerFlags
                # https://clang.llvm.org/docs/AddressSanitizer.html#symbolizing-the-reports
                "-DCLANG_ASAN_UBSAN=ON"
              ];
            });
        };
    } //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          overlays = [ self.overlay ];
          inherit system;
        };

        pythonEnv = pkgs.python3.withPackages(ps: [
          ps.msgpack
          ps.flake8  # for 'make pylint'
        ]);
      in
      rec {

        packages = with pkgs; {
          inherit neovim neovim-debug neovim-developer;
        };

        checks = {
          pylint = pkgs.runCommandNoCC "pylint" {
            nativeBuildInputs = [ pythonEnv ];
            preferLocalBuild = true;
            } "make -C ${./..} pylint > $out";

          shlint = pkgs.runCommandNoCC "shlint" {
            nativeBuildInputs = [ pkgs.shellcheck ];
            preferLocalBuild = true;
            } "make -C ${./..} shlint > $out";
        };

        defaultPackage = pkgs.neovim;

        apps = {
          nvim = flake-utils.lib.mkApp { drv = pkgs.neovim; name = "nvim"; };
          nvim-debug = flake-utils.lib.mkApp { drv = pkgs.neovim-debug; name = "nvim"; };
        };

        defaultApp = apps.nvim;

        devShell = let
          in
            pkgs.neovim-developer.overrideAttrs(oa: {

              buildInputs = with pkgs; oa.buildInputs ++ [
                cmake
                pythonEnv
                include-what-you-use # for scripts/check-includes.py
                jq # jq for scripts/vim-patch.sh -r
                shellcheck # for `make shlint`
                doxygen    # for script/gen_vimdoc.py
                clang-tools # for clangd to find the correct headers
              ];

              shellHook = oa.shellHook + ''
                export NVIM_PYTHON_LOG_LEVEL=DEBUG
                export NVIM_LOG_FILE=/tmp/nvim.log
                export ASAN_SYMBOLIZER_PATH=${pkgs.llvm_11}/bin/llvm-symbolizer

                # ASAN_OPTIONS=detect_leaks=1
                export ASAN_OPTIONS="log_path=./test.log:abort_on_error=1"
                export UBSAN_OPTIONS=print_stacktrace=1
                mkdir -p build/runtime/parser
                # nvim looks into CMAKE_INSTALL_DIR. Hack to avoid errors
                # when running the functionaltests
                mkdir -p outputs/out/share/nvim/syntax
                touch outputs/out/share/nvim/syntax/syntax.vim

                # for treesitter functionaltests
                mkdir -p runtime/parser
                cp -f ${pkgs.tree-sitter.builtGrammars.tree-sitter-c}/parser runtime/parser/c.so
              '';
            });
    });
}
