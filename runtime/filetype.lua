if vim.g.did_load_filetypes and vim.g.did_load_filetypes ~= 0 then
  return
end

-- For now, make this opt-in with a global variable
if vim.g.do_filetype_lua ~= 1 then
  return
end

-- TODO: Remove vim.cmd once Lua autocommands land
vim.cmd [[
augroup filetypedetect
au BufRead,BufNewFile * call v:lua.vim.filetype.match(expand('<afile>'))

" These *must* be sourced after the autocommand above is created
runtime! ftdetect/*.vim
runtime! ftdetect/*.lua

" Set a marker so that the ftdetect scripts are not sourced a second time by filetype.vim
let g:did_load_ftdetect = 1

" If filetype.vim is disabled, set up the autocmd to use scripts.vim
if exists('did_load_filetypes')
  au BufRead,BufNewFile * if !did_filetype() && expand('<amatch>') !~ g:ft_ignore_pat | runtime! scripts.vim | endif
  au StdinReadPost * if !did_filetype() | runtime! scripts.vim | endif
endif

augroup END
]]

if not vim.g.ft_ignore_pat then
  vim.g.ft_ignore_pat = "\\.\\(Z\\|gz\\|bz2\\|zip\\|tgz\\)$"
end
