" Vim syntax file
" Language:	GYP
" Maintainer:	ObserverOfTime <chronobserver@disroot.org>
" Filenames:	*.gyp,*.gypi
" Last Change:	2022 Sep 27

if !exists('g:main_syntax')
  if exists('b:current_syntax') && b:current_syntax ==# 'gyp'
    finish
  endif
  let g:main_syntax = 'gyp'
endif

" Based on JSON syntax
runtime! syntax/json.vim

" Single quotes are allowed
syn clear jsonStringSQError

syn match jsonKeywordMatch /'\([^']\|\\\'\)\+'[[:blank:]\r\n]*\:/ contains=jsonKeyword
if has('conceal') && (!exists('g:vim_json_conceal') || g:vim_json_conceal==1)
   syn region  jsonKeyword matchgroup=jsonQuote start=/'/  end=/'\ze[[:blank:]\r\n]*\:/ concealends contained
else
   syn region  jsonKeyword matchgroup=jsonQuote start=/'/  end=/'\ze[[:blank:]\r\n]*\:/ contained
endif

syn match  jsonStringMatch /'\([^']\|\\\'\)\+'\ze[[:blank:]\r\n]*[,}\]]/ contains=jsonString
if has('conceal') && (!exists('g:vim_json_conceal') || g:vim_json_conceal==1)
    syn region  jsonString oneline matchgroup=jsonQuote start=/'/  skip=/\\\\\|\\'/  end=/'/ concealends contains=jsonEscape contained
else
    syn region  jsonString oneline matchgroup=jsonQuote start=/'/  skip=/\\\\\|\\'/  end=/'/ contains=jsonEscape contained
endif

" Trailing commas are allowed
if !exists('g:vim_json_warnings') || g:vim_json_warnings==1
    syn clear jsonTrailingCommaError
endif

" Python-style comments are allowed
syn match   jsonComment  /#.*$/ contains=jsonTodo,@Spell
syn keyword jsonTodo     FIXME NOTE TODO XXX TBD contained

hi def link jsonComment Comment
hi def link jsonTodo    Todo

let b:current_syntax = 'gyp'
if g:main_syntax ==# 'gyp'
  unlet g:main_syntax
endif
