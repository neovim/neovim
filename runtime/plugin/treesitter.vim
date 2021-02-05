" Last Change: 2020 Nov 26

augroup Treesitter
  au!

  autocmd BufEnter * call luaeval("vim.treesitter.au_dispatch(...)", str2nr("<abuf>"))
augroup END
