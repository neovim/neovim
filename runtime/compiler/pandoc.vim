" Vim compiler file
" Compiler:     Pandoc
" Maintainer:   Konfekt
" Last Change:	2024 Aug 20
"
" Expects output file extension, say `:make html` or `:make pdf`.
" Passes additional arguments to pandoc, say `:make html --self-contained`.

if exists("current_compiler")
  finish
endif

let s:keepcpo = &cpo
set cpo&vim

let current_compiler = 'pandoc'

" As of 2024-04-08 pandoc supports the following text input formats with
" an ftplugin on Github:
let s:supported_filetypes =
      \ [ 'bibtex', 'markdown', 'creole', 'json', 'csv', 'tsv', 'docbook',
      \   'xml', 'fb2', 'html', 'jira', 'tex', 'mediawiki', 'nroff', 'org',
      \   'rtf', 'rst', 't2t', 'textile', 'twiki', 'typst', 'vimwiki' ]
" .. and out of those the following are included in Vim's runtime:
" 'xml', 'tex', 'html', 'rst', 'json', 'nroff', 'markdown'

silent! function s:PandocFiletype(filetype) abort
  let ft = a:filetype

  if     ft ==# 'pandoc' | return 'markdown'
  elseif ft ==# 'tex'    | return 'latex'
  " Pandoc does not support XML as a generic input format, but it does support
  " EndNote XML and Jats XML out of which the latter seems more universal.
  elseif ft ==# 'xml'    | return 'jats'
  elseif ft ==# 'text' || empty(ft)             | return 'markdown'
  elseif index(s:supported_filetypes, &ft) >= 0 | return ft
  else
    echomsg 'Unsupported filetype: '..ft..', falling back to Markdown as input format!'
    return 'markdown'
  endif
endfunction

let b:pandoc_compiler_from = get(b:, 'pandoc_compiler_from', s:PandocFiletype(&filetype))
let b:pandoc_compiler_lang = get(b:, 'pandoc_compiler_lang', &spell ? matchstr(&spelllang, '^\a\a') : '')

execute 'CompilerSet makeprg=pandoc'..escape(
      \ ' --standalone' .
      \ (b:pandoc_compiler_from ==# 'markdown' && (getline(1) =~# '^%\s\+\S\+' || (search('^title:\s+\S+', 'cnw') > 0)) ?
      \ '' : ' --metadata title=%:t:r:S') .
      \ (empty(b:pandoc_compiler_lang) ?
      \ '' : ' --metadata lang='..b:pandoc_compiler_lang) .
      \ ' --from='..b:pandoc_compiler_from .
      \ ' '..get(b:, 'pandoc_compiler_args', get(g:, 'pandoc_compiler_args', '')) .
      \ ' --output %:r:S.$* -- %:S', ' ')

CompilerSet errorformat=%f,\ line\ %l:\ %m

let &cpo = s:keepcpo
unlet s:keepcpo
