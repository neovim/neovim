" Vim plugin for downloading spell files

if exists("loaded_spellfile_plugin") || &cp || exists("#SpellFileMissing")
  finish
endif
let loaded_spellfile_plugin = 1

autocmd SpellFileMissing * call spellfile#LoadFile(expand('<amatch>'))
