" Vim plugin for downloading spell files
" Maintainer:  Bram Moolenaar <Bram@vim.org>
" Last Change: 2006 Feb 01

" Exit quickly when:
" - this plugin was already loaded
" - when 'compatible' is set
" - some autocommands are already taking care of spell files
if exists("loaded_spellfile_plugin") || &cp || exists("#SpellFileMissing")
  finish
endif
let loaded_spellfile_plugin = 1

" The function is in the autoload directory.
autocmd SpellFileMissing * call spellfile#LoadFile(expand('<amatch>'))
