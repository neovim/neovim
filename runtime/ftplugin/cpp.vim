" Vim filetype plugin file
" Language:	C++
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2024 Jun 06
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Behaves mostly just like C
" XXX: "[.]" in the first pattern makes it a wildcard on Windows
runtime! ftplugin/c[.]{vim,lua} ftplugin/c_*.{vim,lua} ftplugin/c/*.{vim,lua}

" Change 'commentstring' to "C++ style"/"mono-line" comments
setlocal commentstring=//\ %s
let b:undo_ftplugin ..= ' | setl commentstring<'

" C++ uses templates with <things>
" Disabled, because it gives an error for typing an unmatched ">".
" set matchpairs+=<:>
" let b:undo_ftplugin ..= ' | setl matchpairs<'
