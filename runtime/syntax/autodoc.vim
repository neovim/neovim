" Vim syntax file
" Language:	Autodoc
" Maintainer:	Stephen R. van den Berg <srb@cuci.nl>
" Last Change:	2018 Jan 23
" Version:	2.9
" Remark:       Included by pike.vim, cmod.vim and optionally c.vim
" Remark:       In order to make c.vim use it, set: c_autodoc

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case match

" A bunch of useful autodoc keywords
syn keyword autodocStatement contained appears belongs global
syn keyword autodocStatement contained decl directive inherit
syn keyword autodocStatement contained deprecated obsolete bugs
syn keyword autodocStatement contained copyright example fixme note param returns
syn keyword autodocStatement contained seealso thanks throws constant
syn keyword autodocStatement contained member index elem
syn keyword autodocStatement contained value type item

syn keyword autodocRegion contained enum mapping code multiset array
syn keyword autodocRegion contained int string section mixed ol ul dl
syn keyword autodocRegion contained class module namespace
syn keyword autodocRegion contained endenum endmapping endcode endmultiset
syn keyword autodocRegion contained endarray endint endstring endsection
syn keyword autodocRegion contained endmixed endol endul enddl
syn keyword autodocRegion contained endclass endmodule endnamespace

syn keyword autodocIgnore contained ignore endignore

syn keyword autodocStatAcc contained b i u tt url pre sub sup
syn keyword autodocStatAcc contained ref rfc xml dl expr image

syn keyword	autodocTodo		contained TODO FIXME XXX

syn match autodocLineStart	display "\(//\|/\?\*\)\@2<=!"
syn match autodocWords "[^!@{}[\]]\+" display contains=@Spell

syn match autodocLink "@\[[^[\]]\+]"hs=s+2,he=e-1 display contains=autodocLead
syn match autodocAtStmt "@[a-z]\+\%(\s\|$\)\@="hs=s+1 display contains=autodocStatement,autodocIgnore,autodocLead,autodocRegion

" Due to limitations of the matching algorithm, we cannot highlight
" nested autodocNStmtAcc structures correctly
syn region autodocNStmtAcc start="@[a-z]\+{" end="@}" contains=autodocStatAcc,autodocLead keepend

syn match autodocUrl contained display ".\+"
syn region autodocAtUrlAcc start="{"ms=s+1 end="@}"he=e-1,me=e-2 contained display contains=autodocUrl,autodocLead keepend
syn region autodocNUrlAcc start="@url{" end="@}" contains=autodocStatAcc,autodocAtUrlAcc,autodocLead transparent

syn match autodocSpecial "@@" display
syn match autodocLead "@" display contained

"when wanted, highlight trailing white space
if exists("c_space_errors")
  if !exists("c_no_trail_space_error")
    syn match	autodocSpaceError	display excludenl "\s\+$"
  endif
  if !exists("c_no_tab_space_error")
    syn match	autodocSpaceError	display " \+\t"me=e-1
  endif
endif

if exists("c_minlines")
  let b:c_minlines = c_minlines
else
  if !exists("c_no_if0")
    let b:c_minlines = 50	" #if 0 constructs can be long
  else
    let b:c_minlines = 15	" mostly for () constructs
  endif
endif
exec "syn sync ccomment autodocComment minlines=" . b:c_minlines

" Define the default highlighting.
" Only used when an item doesn't have highlighting yet
hi def link autodocStatement	Statement
hi def link autodocStatAcc	Statement
hi def link autodocRegion	Structure
hi def link autodocAtStmt	Error
hi def link autodocNStmtAcc	Identifier
hi def link autodocLink		Type
hi def link autodocTodo		Todo
hi def link autodocSpaceError	Error
hi def link autodocLineStart	SpecialComment
hi def link autodocSpecial	SpecialChar
hi def link autodocUrl		Underlined
hi def link autodocLead		Statement
hi def link autodocIgnore	Delimiter

let b:current_syntax = "autodoc"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8
