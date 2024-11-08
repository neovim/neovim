" Vim compiler file
" Compiler:     Pandoc
" Maintainer:   Konfekt
" Last Change:	2024 Sep 8
"
" Expects output file extension, say `:make html` or `:make pdf`.
" Passes additional arguments to pandoc, say `:make html --self-contained`.
" Adjust command-line flags by buffer-local/global variable
" b/g:pandoc_compiler_args which defaults to empty.

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

silent! function s:PandocLang()
  let lang = get(b:, 'pandoc_compiler_lang',
      \ &spell ? matchstr(&spelllang, '^\a\a') : '')
  if lang ==# 'en' | let lang = '' | endif
  return empty(lang) ? '' : '--metadata lang='..lang
endfunction

execute 'CompilerSet makeprg=pandoc'..escape(
    \ ' --standalone'..
    \ (s:PandocFiletype(&filetype) ==# 'markdown' && (getline(1) =~# '^%\s\+\S\+' || (search('^title:\s+\S+', 'cnw') > 0)) ?
    \ '' : ' --metadata title=%:t:r:S')..
    \ ' '..s:PandocLang()..
    \ ' --from='..s:PandocFiletype(&filetype)..
    \ ' '..get(b:, 'pandoc_compiler_args', get(g:, 'pandoc_compiler_args', ''))..
    \ ' --output %:r:S.$* -- %:S', ' ')
CompilerSet errorformat=\"%f\",\ line\ %l:\ %m

let &cpo = s:keepcpo
unlet s:keepcpo
