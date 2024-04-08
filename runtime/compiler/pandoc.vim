" Vim compiler file
" Compiler:     Pandoc
" Maintainer:   Konfekt
"
" Expects output file extension, say `:make html` or `:make pdf`.
" Passes additional arguments to pandoc, say `:make html --self-contained`.

if exists("current_compiler")
  finish
endif

if exists(":CompilerSet") != 2		" older Vim always used :setlocal
  command -nargs=* CompilerSet setlocal <args>
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
  if ft ==# 'pandoc'
    return 'markdown'
  elseif ft ==# 'tex'
    return 'latex'
  elseif ft ==# 'xml'
    " Pandoc does not support XML as a generic input format, but it does support
    " EndNote XML and Jats XML out of which the latter seems more universal.
    return 'jats'
  elseif ft ==# 'text' || empty(ft)
    return 'markdown'
  elseif index(s:supported_filetypes, &ft) >= 0
    return ft
  else
    echomsg 'Unsupported filetype: ' . a:filetype ', falling back to Markdown as input format!'
    return 'markdown'
  endif
endfunction
execute 'CompilerSet makeprg=pandoc\ --standalone' .
      \ '\ --metadata\ title=%:t:r:S' .
      \ '\ --metadata\ lang=' . matchstr(&spelllang, '^\a\a') .
      \ '\ --from=' . s:PandocFiletype(&filetype) .
      \ '\ --output\ %:r:S.$*\ %:S'

CompilerSet errorformat="%f",\ line\ %l:\ %m

let &cpo = s:keepcpo
unlet s:keepcpo
