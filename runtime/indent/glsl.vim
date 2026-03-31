" Language: OpenGL Shading Language
" Maintainer: Gregory Anders <greg@gpanders.com>
" Last Modified: 2024 Jul 21
" Upstream: https://github.com/tikhomirov/vim-glsl

if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

setlocal autoindent cindent
setlocal cinoptions&

let b:undo_indent = 'setl ai< ci< cino<'
