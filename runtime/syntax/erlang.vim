" Vim syntax file
" Language:     Erlang (http://www.erlang.org)
" Maintainer:   Csaba Hoch <csaba.hoch@gmail.com>
" Contributor:  Adam Rutkowski <hq@mtod.org>
"               Johannes Christ <jc@jchri.st>
" Last Update:  2025-Jul-06
" License:      Vim license
" URL:          https://github.com/vim-erlang/vim-erlang-runtime

" Acknowledgements: This script was originally created by Kresimir Marzic [1].
" The script was then revamped by Csaba Hoch [2]. During the revamp, the new
" highlighting style and some code was taken from the Erlang syntax script
" that is part of vimerl [3], created by Oscar Hellström [4] and improved by
" Ricardo Catalinas Jiménez [5].

" [1]: Kreąimir Marľić (Kresimir Marzic) <kmarzic@fly.srk.fer.hr>
" [2]: Csaba Hoch <csaba.hoch@gmail.com>
" [3]: https://github.com/jimenezrick/vimerl
" [4]: Oscar Hellström <oscar@oscarh.net> (http://oscar.hellstrom.st)
" [5]: Ricardo Catalinas Jiménez <jimenezrick@gmail.com>

" Customization:
"
" To use the old highlighting style, add this to your .vimrc:
"
"     let g:erlang_old_style_highlight = 1

" quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

if !exists('g:main_syntax')
  " This is an Erlang source file, and this is the main execution of
  " syntax/erlang.vim.
  let g:main_syntax = 'erlang'
elseif g:main_syntax == 'erlang'
  " This is an Erlang source file, and this is an inner execution of
  " syntax/erlang.vim. For example:
  "
  " 1.  The main execution of syntax/erlang.vim included syntax/markdown.vim
  "     because "g:erlang_use_markdown_for_docs == 1".
  "
  " 2.  syntax/markdown.vim included syntax/erlang.vim because
  "     "g:markdown_fenced_languages == ['erlang']". This is the inner
  "     execution of syntax/erlang.vim.
  "
  " To avoid infinite recursion with Markdown and Erlang including each other,
  " and to avoid the inner syntax/erlang.vim execution messing up the
  " variables of the outer erlang.vim execution, we finish executing the inner
  " erlang.vim.
  "
  " In the inner execution, we already have the Erlang syntax items included,
  " so the highlighting of Erlang within Markdown within Erlang will be
  " acceptable. It won't highlight Markdown inside Erlang inside Markdown
  " inside Erlang.
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" "g:erlang_old_style_highlight": Whether to use old style highlighting.
"
" *   "g:erlang_old_style_highlight == 0" (default): Use new style
"     highlighting.
"
" *   "g:erlang_old_style_highlight == 1": Use old style highlighting.
let s:old_style = (exists("g:erlang_old_style_highlight") &&
                  \g:erlang_old_style_highlight == 1)

" "g:erlang_use_markdown_for_docs": Whether to use Markdown highlighting in
" docstrings.
"
" *   "g:erlang_use_markdown_for_docs == 1": Enable Markdown highlighting in
"     docstrings.
"
" *   "g:erlang_use_markdown_for_docs == 0" (default): Disable Markdown
"     highlighting in docstrings.
"
" If "g:main_syntax" is not 'erlang', this is not an Erlang source file but
" for example a Markdown file, and syntax/markdown.vim is including
" syntax/erlang.vim. To avoid infinite recursion with Markdown and Erlang
" including each other, we disable sourcing syntax/markdown.vim in this case.
if exists("g:erlang_use_markdown_for_docs") && g:main_syntax == 'erlang'
  let s:use_markdown = g:erlang_use_markdown_for_docs
else
  let s:use_markdown = 0
endif

" "g:erlang_docstring_default_highlight": How to highlight the text inside
" docstrings (except the text which is highlighted by Markdown).
"
" If "g:erlang_use_markdown_for_docs == 1":
"
" *   "g:erlang_docstring_default_highlight == 'Comment'" (default): the plugin
"     highlights the plain text inside Markdown as Markdown normally does,
"     with comment highlighting to regular text in the docstring.
"
" *   If you set g:erlang_docstring_default_highlight to the name of highlight
"     group, for example "String", the plugin highlights the plain text inside
"     Markdown with the specified highlight group. See ":highlight" for the
"     available groups. You may also set it to an empty string to disable any
"     specific highlighting.
"
" If "g:erlang_use_markdown_for_docs == 0":
"
" *   "g:erlang_docstring_default_highlight == 'Comment'" (default): the plugin
"     does not highlight the contents of the docstring as markdown, but
"     continues to display them in the style of comments.
"
" *   If you set g:erlang_docstring_default_highlight to the name of highlight
"     group, for example "String", the plugin highlights the plain text inside
"     Markdown with the specified highlight group. See ":highlight" for the
"     available groups. You may also set it to an empty string to disable any
"     specific highlighting.
"
" Configuration examples:
"
"    " Highlight docstrings as Markdown.
"    let g:erlang_use_markdown_for_docs = 1
"    let g:erlang_docstring_default_highlight = 'Comment'
"
"    " 1. Highlight Markdown elements in docstrings as Markdown.
"    " 2. Highlight the plain text in docstrings as String.
"    let g:erlang_use_markdown_for_docs = 1
"    let g:erlang_docstring_default_highlight = 'String'
"
"    " Highlight docstrings as strings.
"    let g:erlang_use_markdown_for_docs = 0
"    let g:erlang_docstring_default_highlight = 'String'
"
"    " Highlight docstrings as comments (default).
"    let g:erlang_use_markdown_for_docs = 0
"    let g:erlang_docstring_default_highlight = 'Comment'
if exists("g:erlang_docstring_default_highlight")
  let s:docstring_default_highlight = g:erlang_docstring_default_highlight
else
  let s:docstring_default_highlight = 'Comment'
endif

" Case sensitive
syn case match

setlocal iskeyword+=$,@-@

" Comments
syn match erlangComment           '%.*$' contains=erlangCommentAnnotation,erlangTodo
syn match erlangCommentAnnotation ' \@<=@\%(clear\|docfile\|end\|headerfile\|todo\|TODO\|type\|author\|copyright\|doc\|reference\|see\|since\|title\|version\|deprecated\|hidden\|param\|private\|equiv\|spec\|throws\)' contained
syn match erlangCommentAnnotation /`[^']*'/ contained
syn keyword erlangTodo            TODO FIXME XXX contained

" Numbers (minimum base is 2, maximum is 36.)
syn match erlangNumberInteger '\<\d\+\>'
syn match erlangNumberInteger '\<\%([2-9]\|[12]\d\|3[0-6]\)\+#[[:alnum:]]\+\>'
syn match erlangNumberFloat   '\<\d\+\.\d\+\%([eE][+-]\=\d\+\)\=\>'

" Strings, atoms, characters
syn region erlangString            start=/"/ end=/"/ contains=erlangStringModifier
syn region erlangStringTripleQuoted matchgroup=String start=/"""/ end=/\%(^\s*\)\@<="""/ keepend

" Documentation
syn region erlangDocString          start=/^-\%(module\)\=doc\s*\~\="/ end=/"\.$/                  contains=@erlangDocStringCluster keepend
syn region erlangDocString          start=/^-\%(module\)\=doc\s*<<"/ end=/">>\.$/                  contains=@erlangDocStringCluster keepend
syn region erlangDocString          start=/^-\%(module\)\=doc\s*\~\="""/ end=/\%(^\s*\)\@<="""\.$/ contains=@erlangDocStringCluster keepend
syn region erlangDocString          start=/^-\%(module\)\=doc\s*<<"""/ end=/\%(^\s*\)\@<=""">>\.$/ contains=@erlangDocStringCluster keepend
syn cluster erlangDocStringCluster contains=erlangInnerDocAttribute,erlangDocStringDelimiter
syn region erlangDocStringDelimiter matchgroup=erlangString start=/"/ end=/"/ contains=@erlangDocStringContained contained
syn region erlangDocStringDelimiter matchgroup=erlangString start=/"""/ end=/"""/ contains=@erlangDocStringContained contained

if s:use_markdown
  syn cluster erlangDocStringContained contains=@markdown
endif

syn region erlangQuotedAtom        start=/'/ end=/'/ contains=erlangQuotedAtomModifier
syn match erlangStringModifier     '\\\%(\o\{1,3}\|x\x\x\|x{\x\+}\|\^.\|.\)\|\~\%([ni~]\|\%(-\=\d\+\|\*\)\=\.\=\%(\*\|\d\+\)\=\%(\..\)\=[tl]*[cfegswpWPBX#bx+]\)' contained
syn match erlangQuotedAtomModifier '\\\%(\o\{1,3}\|x\x\x\|x{\x\+}\|\^.\|.\)' contained
syn match erlangModifier           '\$\%([^\\]\|\\\%(\o\{1,3}\|x\x\x\|x{\x\+}\|\^.\|.\)\)'

" Operators, separators
syn match erlangOperator   '==\|=:=\|/=\|=/=\|<\|=<\|>\|>=\|=>\|:=\|?=\|++\|--\|=\|!\|<-\|+\|-\|\*\|\/'
syn match erlangEqualsBinary '=<<\%(<\)\@!'
syn keyword erlangOperator div rem or xor bor bxor bsl bsr and band not bnot andalso orelse
syn match erlangBracket    '{\|}\|\[\|]\||\|||'
syn match erlangPipe       '|'
syn match erlangRightArrow '->'

" Atoms, function calls (order is important)
syn match erlangAtom           '\<\l[[:alnum:]_@]*' contains=erlangBoolean
syn keyword erlangBoolean      true false contained
syn match erlangLocalFuncCall  '\<\a[[:alnum:]_@]*\>\%(\%(\s\|\n\|%.*\n\)*(\)\@=' contains=erlangBIF
syn match erlangLocalFuncRef   '\<\a[[:alnum:]_@]*\>\%(\%(\s\|\n\|%.*\n\)*/\)\@='
syn match erlangGlobalFuncCall '\<\%(\a[[:alnum:]_@]*\%(\s\|\n\|%.*\n\)*\.\%(\s\|\n\|%.*\n\)*\)*\a[[:alnum:]_@]*\%(\s\|\n\|%.*\n\)*:\%(\s\|\n\|%.*\n\)*\a[[:alnum:]_@]*\>\%(\%(\s\|\n\|%.*\n\)*(\)\@=' contains=erlangComment,erlangVariable
syn match erlangGlobalFuncRef  '\<\%(\a[[:alnum:]_@]*\%(\s\|\n\|%.*\n\)*\.\%(\s\|\n\|%.*\n\)*\)*\a[[:alnum:]_@]*\%(\s\|\n\|%.*\n\)*:\%(\s\|\n\|%.*\n\)*\a[[:alnum:]_@]*\>\%(\%(\s\|\n\|%.*\n\)*/\)\@=' contains=erlangComment,erlangVariable

" Variables, macros, records, maps
syn match erlangVariable '\<[A-Z][[:alnum:]_@]*'
syn match erlangAnonymousVariable '\<_[[:alnum:]_@]*'
syn match erlangMacro    '??\=[[:alnum:]_@]\+'
syn match erlangMacro    '\%(-define(\)\@<=[[:alnum:]_@]\+'
syn region erlangQuotedMacro         start=/??\=\s*'/ end=/'/ contains=erlangQuotedAtomModifier
syn match erlangMap      '#'
syn match erlangRecord   '#\s*\l[[:alnum:]_@]*'
syn region erlangQuotedRecord        start=/#\s*'/ end=/'/ contains=erlangQuotedAtomModifier

" Shebang (this line has to be after the ErlangMap)
syn match erlangShebang  '^#!.*'

" Bitstrings
syn match erlangBitType '\%(\/\%(\s\|\n\|%.*\n\)*\)\@<=\%(integer\|float\|binary\|bytes\|bitstring\|bits\|binary\|utf8\|utf16\|utf32\|signed\|unsigned\|big\|little\|native\|unit\)\%(\%(\s\|\n\|%.*\n\)*-\%(\s\|\n\|%.*\n\)*\%(integer\|float\|binary\|bytes\|bitstring\|bits\|binary\|utf8\|utf16\|utf32\|signed\|unsigned\|big\|little\|native\|unit\)\)*' contains=erlangComment

" Constants and Directives
syn match erlangUnknownAttribute '^\s*-\%(\s\|\n\|%.*\n\)*\l[[:alnum:]_@]*' contains=erlangComment
syn match erlangAttribute '^\s*-\%(\s\|\n\|%.*\n\)*\%(behaviou\=r\|compile\|dialyzer\|export\|export_type\|file\|import\|module\|author\|copyright\|vsn\|on_load\|optional_callbacks\|feature\|mode\)\>' contains=erlangComment
syn match erlangDocAttribute '^\s*-\%(\s\|\n\|%.*\n\)*\%(moduledoc\|doc\)\>' contains=erlangComment,erlangDocString
syn match erlangInnerDocAttribute '^\s*-\%(\s\|\n\|%.*\n\)*\%(moduledoc\|doc\)\>' contained
syn match erlangInclude   '^\s*-\%(\s\|\n\|%.*\n\)*\%(include\|include_lib\)\>' contains=erlangComment
syn match erlangRecordDef '^\s*-\%(\s\|\n\|%.*\n\)*record\>' contains=erlangComment
syn match erlangDefine    '^\s*-\%(\s\|\n\|%.*\n\)*\%(define\|undef\)\>' contains=erlangComment
syn match erlangPreCondit '^\s*-\%(\s\|\n\|%.*\n\)*\%(ifdef\|ifndef\|else\|endif\)\>' contains=erlangComment
syn match erlangType      '^\s*-\%(\s\|\n\|%.*\n\)*\%(spec\|type\|opaque\|nominal\|callback\)\>' contains=erlangComment

" Keywords
syn keyword erlangKeyword after begin case catch cond end fun if let of else
syn keyword erlangKeyword receive when try maybe

" Build-in-functions (BIFs)
syn keyword erlangBIF abs alive apply atom_to_binary atom_to_list contained
syn keyword erlangBIF binary_part binary_to_atom contained
syn keyword erlangBIF binary_to_existing_atom binary_to_float contained
syn keyword erlangBIF binary_to_integer bitstring_to_list contained
syn keyword erlangBIF binary_to_list binary_to_term bit_size contained
syn keyword erlangBIF byte_size check_old_code check_process_code contained
syn keyword erlangBIF concat_binary date delete_module demonitor contained
syn keyword erlangBIF disconnect_node element erase error exit contained
syn keyword erlangBIF float float_to_binary float_to_list contained
syn keyword erlangBIF garbage_collect get get_keys group_leader contained
syn keyword erlangBIF halt hd integer_to_binary integer_to_list contained
syn keyword erlangBIF iolist_to_binary iolist_size is_alive contained
syn keyword erlangBIF is_atom is_binary is_bitstring is_boolean contained
syn keyword erlangBIF is_float is_function is_integer is_list is_map is_map_key contained
syn keyword erlangBIF is_number is_pid is_port is_process_alive contained
syn keyword erlangBIF is_record is_reference is_tuple length link contained
syn keyword erlangBIF list_to_atom list_to_binary contained
syn keyword erlangBIF list_to_bitstring list_to_existing_atom contained
syn keyword erlangBIF list_to_float list_to_integer list_to_pid contained
syn keyword erlangBIF list_to_tuple load_module make_ref map_size max contained
syn keyword erlangBIF min module_loaded monitor monitor_node node contained
syn keyword erlangBIF nodes now open_port pid_to_list port_close contained
syn keyword erlangBIF port_command port_connect pre_loaded contained
syn keyword erlangBIF process_flag process_flag process_info contained
syn keyword erlangBIF process purge_module put register registered contained
syn keyword erlangBIF round self setelement size spawn spawn_link contained
syn keyword erlangBIF spawn_monitor spawn_opt split_binary contained
syn keyword erlangBIF statistics term_to_binary throw time tl contained
syn keyword erlangBIF trunc tuple_size tuple_to_list unlink contained
syn keyword erlangBIF unregister whereis contained

" Sync at the beginning of functions: if this is not used, multiline string
" are not always recognized, and the indentation script cannot use the
" "searchpair" (because it would not always skip strings and comments when
" looking for keywords and opening parens/brackets).
syn sync match erlangSync grouphere NONE "^[a-z]\s*("
let b:erlang_syntax_synced = 1

" Define the default highlighting. See ":help group-name" for the groups and
" their colors.

if s:use_markdown
  " Add markdown syntax elements for docstrings (actually, for all
  " triple-quoted strings).
  unlet! b:current_syntax

  syn include @markdown syntax/markdown.vim
  let b:current_syntax = "erlang"

  " markdown-erlang.vim includes html.vim, which includes css.vim, which adds
  " the dash character (-) to the list of syntax keywords, which causes
  " `-VarName` not to be highlighted as a variable in the Erlang code.
  "
  " Here we override that.
  syntax iskeyword @,48-57,192-255,$,_
endif

" Comments
hi def link erlangComment Comment
hi def link erlangCommentAnnotation Special
hi def link erlangTodo Todo
hi def link erlangShebang Comment

" Numbers
hi def link erlangNumberInteger Number
hi def link erlangNumberFloat Float

" Strings, atoms, characters
hi def link erlangString String
hi def link erlangStringTripleQuoted String

" Triple quoted strings
if s:docstring_default_highlight != ''
  execute 'hi def link erlangDocStringDelimiter '. s:docstring_default_highlight
endif

if s:old_style
hi def link erlangQuotedAtom Type
else
hi def link erlangQuotedAtom String
endif

hi def link erlangStringModifier Special
hi def link erlangQuotedAtomModifier Special
hi def link erlangModifier Special

" Operators, separators
hi def link erlangOperator Operator
hi def link erlangEqualsBinary ErrorMsg
hi def link erlangRightArrow Operator
if s:old_style
hi def link erlangBracket Normal
hi def link erlangPipe Normal
else
hi def link erlangBracket Delimiter
hi def link erlangPipe Delimiter
endif

" Atoms, functions, variables, macros
if s:old_style
hi def link erlangAtom Normal
hi def link erlangLocalFuncCall Normal
hi def link erlangLocalFuncRef Normal
hi def link erlangGlobalFuncCall Function
hi def link erlangGlobalFuncRef Function
hi def link erlangVariable Normal
hi def link erlangAnonymousVariable erlangVariable
hi def link erlangMacro Normal
hi def link erlangQuotedMacro Normal
hi def link erlangRecord Normal
hi def link erlangQuotedRecord Normal
hi def link erlangMap Normal
else
hi def link erlangAtom String
hi def link erlangLocalFuncCall Normal
hi def link erlangLocalFuncRef Normal
hi def link erlangGlobalFuncCall Normal
hi def link erlangGlobalFuncRef Normal
hi def link erlangVariable Identifier
hi def link erlangAnonymousVariable erlangVariable
hi def link erlangMacro Macro
hi def link erlangQuotedMacro Macro
hi def link erlangRecord Structure
hi def link erlangQuotedRecord Structure
hi def link erlangMap Structure
endif

" Bitstrings
if !s:old_style
hi def link erlangBitType Type
endif

" Constants and Directives
if s:old_style
hi def link erlangAttribute Type
hi def link erlangMacroDef Type
hi def link erlangUnknownAttribute Normal
hi def link erlangInclude Type
hi def link erlangRecordDef Type
hi def link erlangDefine Type
hi def link erlangPreCondit Type
hi def link erlangType Type
else
hi def link erlangAttribute Keyword
hi def link erlangDocAttribute Keyword
hi def link erlangInnerDocAttribute Keyword
hi def link erlangMacroDef Macro
hi def link erlangUnknownAttribute Normal
hi def link erlangInclude Include
hi def link erlangRecordDef Keyword
hi def link erlangDefine Define
hi def link erlangPreCondit PreCondit
hi def link erlangType Type
endif

" Keywords
hi def link erlangKeyword Keyword

" Build-in-functions (BIFs)
hi def link erlangBIF Function

if s:old_style
hi def link erlangBoolean Statement
hi def link erlangExtra Statement
hi def link erlangSignal Statement
else
hi def link erlangBoolean Boolean
hi def link erlangExtra Statement
hi def link erlangSignal Statement
endif

let b:current_syntax = "erlang"

if g:main_syntax ==# 'erlang'
  unlet g:main_syntax
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: sw=2 et
