" Vim filetype plugin file
" Language:		Solidity
" Maintainer:		Cothi (jiungdev@gmail.com)
" Original Author:	tomlion (https://github.com/tomlion/vim-solidity)
" Last Change:		2022 Sep 27
" 			2023 Aug 22 Vim Project (did_ftplugin, undo_ftplugin)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=//\ %s

let b:undo_ftplugin = "setlocal commentstring<"
