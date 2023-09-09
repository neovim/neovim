" Vim filetype plugin file
" Language:	C++
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Behaves mostly just like C
runtime! ftplugin/c.vim ftplugin/c_*.vim ftplugin/c/*.vim
runtime! ftplugin/c.lua ftplugin/c_*.lua ftplugin/c/*.lua

" C++ uses templates with <things>
" Disabled, because it gives an error for typing an unmatched ">".
" set matchpairs+=<:>
" let b:undo_ftplugin ..= ' | setl matchpairs<'
