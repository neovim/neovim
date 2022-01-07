if vim.g.did_load_filetypes and vim.g.did_load_filetypes ~= 0 then
  return
end

-- For now, make this opt-in with a global variable
if vim.g.do_filetype_lua ~= 1 then
  return
end

vim.cmd [[
augroup filetypedetect
" Explicitly pass <afile> rather than getting name from the current buffer. cf. https://github.com/neovim/neovim/issues/16939
au BufRead,BufNewFile * call v:lua.vim.filetype.set_filetype_for_current_buffer(expand('<afile>'))

" These *must* be sourced after the autocommand above is created
runtime! ftdetect/*.vim
runtime! ftdetect/*.lua

" Set a marker so that the ftdetect scripts are not sourced a second time by filetype.vim
let g:did_load_ftdetect = 1

augroup END
]]

if not vim.g.ft_ignore_pat then
  vim.g.ft_ignore_pat = "\\.\\(Z\\|gz\\|bz2\\|zip\\|tgz\\)$"
end
