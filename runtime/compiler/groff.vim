" Vim compiler file
" Compiler:     Groff
" Maintainer:   Konfekt
" Last Change:	2024 Sep 8
"
" Expects output file extension, say `:make html` or `:make pdf`.
" Supported devices as of Sept 2024 are: (x)html, pdf, ps, dvi, lj4, lbp ...
" Adjust command-line flags, language, encoding by buffer-local/global variables
" groff_compiler_args, groff_compiler_lang, and groff_compiler_encoding,
" which default to '', &spelllang and 'utf8'.

if exists("current_compiler")
  finish
endif

let s:keepcpo = &cpo
set cpo&vim

let current_compiler = 'groff'

silent! function s:groff_compiler_lang()
  let lang = get(b:, 'groff_compiler_lang',
      \ &spell ? matchstr(&spelllang, '^\a\a') : '')
  if lang ==# 'en' | let lang = '' | endif
  return empty(lang) ? '' : '-m'..lang
endfunction

" Requires output format (= device) to be set by user after :make.
execute 'CompilerSet makeprg=groff'..escape(
    \ ' '..s:groff_compiler_lang()..
    \ ' -K'..get(b:, 'groff_compiler_encoding', get(g:, 'groff_compiler_encoding', 'utf8'))..
    \ ' '..get(b:, 'groff_compiler_args', get(g:, 'groff_compiler_args', ''))..
    \ ' -mom -T$* -- %:S > %:r:S.$*', ' ')
" From Gavin Freeborn's https://github.com/Gavinok/vim-troff under Vim License
" https://github.com/Gavinok/vim-troff/blob/91017b1423caa80aba541c997909a4f810edd275/compiler/troff.vim#L39
CompilerSet errorformat=%o:<standard\ input>\ (%f):%l:%m,
			\%o:\ <standard\ input>\ (%f):%l:%m,
			\%o:%f:%l:%m,
			\%o:\ %f:%l:%m,
			\%f:%l:\ macro\ %trror:%m,
			\%f:%l:%m,
			\%W%tarning:\ file\ '%f'\\,\ around\ line\ %l:,%Z%m

let &cpo = s:keepcpo
unlet s:keepcpo
