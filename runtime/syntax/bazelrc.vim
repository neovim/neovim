" Vim syntax file
" Language:	Bazel rc file
" Maintainer:	Barrett Ruth <br@barrettruth.com>
" Last Change:	2026 Aug 25
" Reference:	https://bazel.build/run/bazelrc

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif
let s:cpo_save = &cpo
set cpo&vim

syn case match
syn iskeyword @,48-57,_,-

" Comments {{{1

" Backslash-newline is removed from the whole file before it is split into
" lines, so a comment ending in one continues into the line below it.
syn region  bazelrcComment
      \ start=/#/
      \ skip=/\\$/
      \ end=/$/
      \ contains=bazelrcTodo,@Spell
syn keyword bazelrcTodo	contained TODO FIXME XXX NOTE

" Words {{{1

" Bazel joins a continued line onto the one above before splitting the file
" into lines, so what follows is a further option rather than a new command.
syn match   bazelrcContinuation /\\$/
      \ skipnl
      \ nextgroup=bazelrcContinued
syn match   bazelrcContinued  contained  transparent  /.*/
      \ contains=bazelrcComment,bazelrcContinuation,bazelrcEscape,
      \	         bazelrcFlag,bazelrcString

" A backslash escape is absorbed before quoting is considered, so it applies
" inside single quotes too, and '\#' is a literal '#' rather than a comment.
syn match   bazelrcEscape	/\\./
" A quote may open part-way through a word.  An unterminated one is ignored
" rather than continued onto the line below.
syn region  bazelrcString  oneline
      \ start=/'/
      \ skip=/\\./
      \ end=/'/
      \ contains=bazelrcEscape
syn region  bazelrcString  oneline
      \ start=/"/
      \ skip=/\\./
      \ end=/"/
      \ contains=bazelrcEscape

" Imports {{{1

syn match   bazelrcImport	/^\s*try-import-if-bazel-version\>/
      \ skipwhite
      \ nextgroup=bazelrcVersion
syn match   bazelrcImport	/^\s*\%(try-\)\=import\>/
      \ skipwhite
      \ nextgroup=bazelrcPath
" The comparison and the version it applies to are a single word.
syn match   bazelrcVersion  contained
      \ /\%(<=\|>=\|==\|!=\|[<>~]\)[^ \t#]\+/
      \ skipwhite
      \ nextgroup=bazelrcPath
syn match   bazelrcPath  contained
      \ /\%(\\.\|[^ \t#]\)\+/
      \ contains=bazelrcEscape,bazelrcString,bazelrcWorkspace
" Substituted only as a prefix, and the trailing slash belongs to it.
syn match   bazelrcWorkspace  contained /\%(^\|\s\)\@1<=%workspace%\//

" Commands and options {{{1

syn match   bazelrcCommand
      \ /^\s*\<\%(always\|aquery\|build\|canonicalize-flags\|clean\|common
      \\|config\|coverage\|cquery\|dump\|fetch\|help\|info\|license
      \\|mobile-install\|mod\|print_action\|query\|run\|shutdown\|startup
      \\|test\|vendor\|version\)\>/
      \ nextgroup=bazelrcConfig
" A command is split on its first colon, so a config name may contain colons.
syn match   bazelrcConfig  contained /:[^ \t#]\+/

syn match   bazelrcFlag		/--[^ \t#=]*/	nextgroup=bazelrcValue
syn match   bazelrcFlag		/\%(^\|\s\)\@1<=-[a-zA-Z]\>/
      \ nextgroup=bazelrcValue
syn region  bazelrcValue  contained  oneline
      \ matchgroup=bazelrcOperator
      \ start=/=/
      \ end=/\ze[ \t#]/
      \ end=/$/
      \ contains=bazelrcString,bazelrcEscape

" Syncing {{{1

" A comment may continue onto the following line.
syn sync linebreaks=1

" Default Highlighting {{{1

hi def link bazelrcComment	Comment
hi def link bazelrcTodo		Todo
hi def link bazelrcContinuation	Special
hi def link bazelrcEscape	SpecialChar
hi def link bazelrcString	String
hi def link bazelrcImport	Include
hi def link bazelrcVersion	Constant
hi def link bazelrcPath		String
hi def link bazelrcWorkspace	PreProc
hi def link bazelrcCommand	Statement
hi def link bazelrcConfig	Type
hi def link bazelrcFlag		Identifier
hi def link bazelrcOperator	Operator

" }}}

let b:current_syntax = "bazelrc"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 fdm=marker:
