Dependencies:

- [x] libuv
- [-] lua
- [ ] luajit
- [x] UNIBILIUM_URL https://github.com/neovim/unibilium/archive/d72c3598e7ac5d1ebf86ee268b8b4ed95c0fa628.tar.gz
- [-] luv
- [-] lpeg
- [x] utf8proc
- [x] compat53 (c api part only - but likely enough)
- [x] TREESITTER_URL https://github.com/tree-sitter/tree-sitter/archive/v0.22.5.tar.gz

non-glibc:
- [ ] GETTEXT_URL https://github.com/neovim/deps/raw/b9bf36eb31f27e8136d907da38fa23518927737e/opt/gettext-0.20.1.tar.gz
- [ ] LIBICONV_URL https://github.com/neovim/deps/raw/b9bf36eb31f27e8136d907da38fa23518927737e/opt/libiconv-1.17.tar.gz

Runtime dependencies:

- [ ] treesitter parsers
- [ ] cat/tee/xxd.exe
- [ ] WIN32YANK_X86_64_URL https://github.com/equalsraf/win32yank/releases/download/v0.1.1/win32yank-x64.zip

Generators (nvim binary):

 - [x] gen_api_dispatch.lua
 - [x] gen_api_ui_events.lua
 - [x] gen_char_blob.lua (partial - LUAC_PRG not supported)
 - [x] gen_declarations.lua (partial - some generators generate input for this!)
 - [x] gen_eval.lua
 - [x] gen_events.lua
 - [x] gen_ex_cmds.lua
 - [x] gen_options_enum.lua
 - [x] gen_options.lua

Configuration:

 - [x] nvim_version.lua
 - [x] versiondef.h
   - [ ] src/versiondef.h is a copy where $<CONFIG> has been changed to ${CONFIG}. upstream support for $<foo> ???
 - [ ] versiondef_git.h
 - [ ] config.h
 - [ ] pathdef.h

Generators (Runtime and documentation):

- [ ] gen_vimvim.lua
- [ ] gen_eval_files.lua
- [ ] gen_vimdoc.lua*
- [ ] gen_filetype.lua
- [ ] gen_help_html.lua
- [ ] gen_lsp.lua
