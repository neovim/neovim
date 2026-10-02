" Vim syntax file
" Language:	ed(1)
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2026 Aug 27

if exists("b:current_syntax")
  finish
endif
let s:cpo_save = &cpo
set cpo&vim

syn match  edLineStart
      \ /^/
      \ skipwhite
      \ nextgroup=@edAddress,edAddressSeparator,@edCommand

" Addresses {{{1

" TODO: Rename edAddress_Line, edAdress_Mark etc?
syn match   edAddress  contained
      \ /[.$]\|\d\+\|'[a-z]/
      \ skipwhite
      \ nextgroup=@edAddressModifier,edAddressSeparator,@edCommand
syn region  edAddress_Pattern  contained
      \ matchgroup=Delimiter
      \ start=+/+
      \ end=+/\|$+
      \ skipwhite
      \ nextgroup=@edAddressModifier,
      \		  edAddressSeparator,
      \		  @edCommand,
      \		  edAddress_Pattern_Flag
      \ contains=edRegex_SlashEscape,
      \		 edRegex_BackslashEscape,
      \		 edRegex_BracketExpression
syn region  edAddress_Pattern  contained
      \ matchgroup=Delimiter
      \ start=/?/
      \ end=/?\|$/
      \ skipwhite
      \ nextgroup=@edAddressModifier,
      \		  edAddressSeparator,
      \		  @edCommand,
      \		  edAddress_Pattern_Flag
      \ contains=edRegex_QuestionMarkEscape,
      \		 edRegex_BackslashEscape,
      \		 edRegex_BracketExpression

syn match  edAddress_Pattern_Flag  contained
      \ +[/?]\@1<=I+
      \ skipwhite
      \ nextgroup=@edAddressModifier,edAddressSeparator,@edCommand

syn match   edRegex_BracketExpression  contained
      \ /\[\^\=\]\=\%(\[:.\{-}:\]\|\[\..\{-}\.\]\|\[=.\{-}=\]\|[^]]\)*\]/
      \ contains=NONE
      \ transparent
syn match   edRegex_SlashEscape        contained
      \ +\\/+
      \ contains=NONE
      \ transparent
syn match   edRegex_QuestionMarkEscape contained
      \ /\\?/
      \ contains=NONE
      \ transparent
syn match   edRegex_BackslashEscape    contained
      \ /\\\\/
      \ contains=NONE
      \ transparent
syn match   edRegex_EscapeSequence     contained
      \ /\\./
      \ contains=NONE
      \ transparent


syn cluster edAddress
      \ contains=edAddress,edAddress_Pattern,edAddressModifier_Offset

syn match   edAddressModifier_Offset  contained
      \ /[+-]\s*\%(\d\+\)\=/
      \ skipwhite
      \ nextgroup=@edAddressModifier,edAddressSeparator,@edCommand
" BSD extension
syn match   edAddressModifier_Offset  contained
      \ /\^\s*\%(\d\+\)\=/
      \ skipwhite
      \ nextgroup=@edAddressModifier,edAddressSeparator,@edCommand
syn match   edAddressModifier_Count  contained
      \ /\d\+/
      \ skipwhite
      \ nextgroup=@edAddressModifier,edAddressSeparator,@edCommand
syn cluster edAddressModifier
      \ contains=edAddressModifier_Offset,edAddressModifier_Count

syn match   edAddressSeparator	contained
      \ /[,;]/
      \ skipwhite
      \ nextgroup=@edAddress,edAddressSeparator,@edCommand
" BSD/GNU extension
syn match   edAddressSeparator	contained
      \ /%/
      \ skipwhite
      \ nextgroup=@edAddress,edAddressSeparator,@edCommand

" Commands {{{1

" Append Command {{{2
syn match   edCommand_Append  contained
      \ /a/
      \ skipnl
      \ nextgroup=@edCommandPrint_InputMode,
      \		  edArg_InputMode_Text,
      \		  edArg_InputMode_EndMarker,
      \		  edLineContinue_InputMode

syn match  edArg_InputMode_EndMarker  contained
      \ /^\.\ze\%(\s*\\\)\=$/

syn region  edArg_InputMode_Text  contained
      \ start=/^\%(\.$\)\@!/
      "\ end=/^\.$/
      \ matchgroup=edArg_InputMode_EndMarker
      "\ TODO: remove \\?
      \ end=/^\.\ze\%(\s*\\\)\=$/
      \ fold
syn region  edArg_InputMode_Text_Global  contained
      \ start=/^\%(\.$\)\@!/
      \ end=/\ze\\\@1<!\n/
      \ matchgroup=edArg_InputMode_EndMarker
      \ end=/^\.\ze\%(\s*\\\)\=$/
      \ skipwhite
      \ nextgroup=edLineContinue
      \ contains=edLineContinue_InputMode_Text
      \ fold

" Change Command {{{2
syn match   edCommand_Change  contained
      \ /c/
      \ skipnl
      \ nextgroup=@edCommandPrint_InputMode,
      \		  edArg_InputMode_Text,
      \		  edArg_InputMode_EndMarker,
      \		  edLineContinue_InputMode

" Delete Command {{{2
syn match   edCommand_Delete  contained
      \ /d/
      \ nextgroup=@edCommandPrint

" TODO: maybe implement as a region so that the command list is contained?
" Global Command {{{2
syn match   edCommand_Global  contained
      \ /g/
      \ nextgroup=edCommand_Global_Arg_Regexp
syn region  edCommand_Global_Arg_Regexp  contained
      \ matchgroup=Delimiter
      \ start=/\z([^\\ \n]\)/
      \ end=/\z1\|$/
      \ skipwhite
      \ nextgroup=@edAddress,
      \		  edAddressSeparator,
      \		  @edCommand,
      \		  edCommand_Global_Arg_Regexp_Flag
      \ contains=edRegex_EscapeSequence,edRegex_BracketExpression

" GNU extension
syn match edCommand_Global_Arg_Regexp_Flag  contained
      \ /[^\\ \n]\@1<=I/
      \ skipwhite
      \ nextgroup=@edAddress,edAddressSeparator,@edCommand

syn match   edLineContinue_InputMode  contained
      \ /\\$/
      \ skipnl
      \ nextgroup=edArg_InputMode_Text_Global,edArg_InputMode_EndMarker
syn match   edLineContinue_InputMode_Text  contained /\\$/
syn match   edLineContinue  /\\$/ skipnl nextgroup=edLineStart

" Interactive Global Command {{{2
syn match   edCommand_InteractiveGlobal  contained
      \ /G/
      \ nextgroup=edCommand_InteractiveGlobal_Arg_Regexp
syn region  edCommand_InteractiveGlobal_Arg_Regexp  contained
      \ matchgroup=Delimiter
      \ start=/\z([^\\ \n]\)/
      \ end=/\z1\|$/
      \ nextgroup=edCommand_InteractiveGlobal_Arg_Regexp_Flag
      \ contains=edRegex_EscapeSequence,edRegex_BracketExpression

" GNU extension
syn match edCommand_InteractiveGlobal_Arg_Regexp_Flag  contained
      \ /[^\\ \n]\@1<=I/

syn match   edCommand_Repeat  contained
      \ /&/

" Insert Command {{{2
syn match   edCommand_Insert  contained
      \ /i/
      \ skipnl
      \ nextgroup=@edCommandPrint_InputMode,
      \		  edArg_InputMode_Text,
      \		  edArg_InputMode_EndMarker,
      \		  edLineContinue_InputMode

" Join Command {{{2
syn match   edCommand_Join  contained
      \ /j/
      \ nextgroup=@edCommandPrint

" Mark Command {{{2
syn match   edCommand_Mark  contained
      \ /k/
      \ nextgroup=edCommand_Mark_Arg_Name
syn match   edCommand_Mark_Arg_Name  contained
      \ /[a-z]/
      \ nextgroup=@edCommandPrint

" List Command {{{2
syn match   edCommand_List  contained
      \ /l/
      \ nextgroup=@edCommandPrint

syn match edCommand_List_InputMode contained
      \ /^\@1<!l/
      \ skipnl
      \ nextgroup=@edCommandPrint_InputMode,
      \		  edArg_InputMode_Text,
      \		  edArg_InputMode_EndMarker,
      \		  edLineContinue_InputMode

" Move Command {{{2
syn match   edCommand_Move  contained
      \ /m/
      "\ GNU extension
      \ skipwhite
      \ nextgroup=@edAddress,edAddressSeparator,@edCommandPrint

" Number Command {{{2
syn match   edCommand_Number  contained
      \ /n/
      \ nextgroup=@edCommandPrint

syn match edCommand_Number_InputMode contained
      \ /^\@1<!n/
      \ skipnl
      \ nextgroup=@edCommandPrint_InputMode,
      \		  edArg_InputMode_Text,
      \		  edArg_InputMode_EndMarker,
      \		  edLineContinue_InputMode

" Print Command {{{2
syn match   edCommand_Print  contained
      \ /p/
      \ nextgroup=@edCommandPrint

syn match edCommand_Print_InputMode contained
      \ /^\@1<!p/
      \ skipnl
      \ nextgroup=@edCommandPrint_InputMode,
      \		  edArg_InputMode_Text,
      \		  edArg_InputMode_EndMarker,
      \		  edLineContinue_InputMode

" Read Command {{{2
syn match   edCommand_Read  contained
      \ /r\>/
      \ skipwhite
      \ nextgroup=edArg_File,edCommand_ShellEscape

" Substitute Command {{{2
syn match   edCommand_Substitute  contained
      \ /s/
      \ nextgroup=edCommand_Substitute_Arg_Regexp
syn region  edCommand_Substitute_Arg_Regexp  contained
      \ matchgroup=Delimiter
      \ start=/\z([^\\ \n]\)/
      "\ /$/ so we don't run to EOF when editing
      \ end=/\ze\z1\|$/
      \ nextgroup=edCommand_Substitute_Arg_Replacement
      \ contains=edRegex_EscapeSequence,edRegex_BracketExpression
syn region  edCommand_Substitute_Arg_Replacement  contained
      \ matchgroup=Delimiter
      \ start=/\z(.\)/
      \ skip=/\\$/
      \ end=/\z1\|$/
      \ nextgroup=edCommand_Substitute_Arg_Flag,edCommand_Substitute_Arg_Count
      \ contains=edCommand_Substitute_Arg_Replacement_Escape,
      \		 edCommand_Substitute_Arg_Replacement_Newline,
      \		 edCommand_Substitute_Arg_Replacement_Match

syn region  edCommand_Substitute_Arg_Replacement  contained
      \ matchgroup=Delimiter
      \ start=/\z(.\)%\@=/
      \ end=/\%(\z1%\)\@<=\%(\z1\|$\)/
      \ nextgroup=edCommand_Substitute_Arg_Flag,edCommand_Substitute_Arg_Count
      \ contains=edCommand_Substitute_Arg_Replacement_Repeat
      \ oneline

syn match   edCommand_Substitute_Arg_Replacement_Escape	  contained /\\./
syn match   edCommand_Substitute_Arg_Replacement_Newline  contained /\\$/
syn match   edCommand_Substitute_Arg_Replacement_Match	  contained /&/
syn match   edCommand_Substitute_Arg_Replacement_Repeat	  contained /%/

syn match   edCommand_Substitute_Arg_Flag  contained
      \ /g/
      \ nextgroup=edCommand_Substitute_Arg_Flag,edCommand_Substitute_Arg_Count
" GNU extension
syn match   edCommand_Substitute_Arg_Flag  contained
      \ /[iI]/
      \ nextgroup=edCommand_Substitute_Arg_Flag,edCommand_Substitute_Arg_Count

syn match   edCommand_Substitute_Arg_Count  contained
      \ /\d\+/
      \ nextgroup=edCommand_Substitute_Arg_Flag

syn match  edCommand_Substitute_Arg_Flag  contained
      \ /[lnp]/
      \ skipnl
      \ nextgroup=edCommand_Substitute_Arg_Flag,edCommand_Substitute_Arg_Count

" repeat last s command
" BSD/GNU extension

syn match   edCommand_Substitute  contained
      \ /s\%(\%([gpr]\|\d\+\)\{1,4}\&\%(.*\([gpr]\).*\1\)\@!\&\%(.*\d\D\+\d\)\@!.*\)\>/
      \ contains=edCommand_Substitute_Arg_Flag,edCommand_Substitute_Arg_Count

syn match   edCommand_Substitute_Arg_Flag  contained
      \ /r/
      \ nextgroup=edCommand_Substitute_Arg_Flag,edCommand_Substitute_Arg_Count

" Copy Command {{{2
syn match   edCommand_Copy  contained
      \ /t/
      "\ GNU extension
      \ skipwhite
      \ nextgroup=@edAddress,edAddressSeparator,@edCommandPrint

" TODO: maybe implement as a region so that the command list is contained?
" Global Not-Matched Command {{{2
syn match   edCommand_GlobalNotMatched	contained
      \ /v/
      \ nextgroup=edCommand_GlobalNotMatched_Arg_Regexp
syn region  edCommand_GlobalNotMatched_Arg_Regexp  contained
      \ matchgroup=Delimiter
      \ start=/\z([^\\ \n]\)/
      \ end=/\z1\|$/
      \ skipwhite
      \ nextgroup=@edAddress,
      \		  edAddressSeparator,
      \		  @edCommand,
      \		  edCommand_GlobalNotMatched_Arg_Regexp_Flag
      \ contains=edRegex_EscapeSequence,edRegex_BracketExpression

" GNU extension
syn match edCommand_GlobalNotMatched_Arg_Regexp_Flag  contained
      \ /[^\\ \n]\@1<=I/
      \ skipwhite
      \ nextgroup=@edAddress,edAddressSeparator,@edCommand

" Interactive Global Not-Matched Command {{{2
syn match   edCommand_InteractiveGlobalNotMatched  contained
      \ /V/
      \ nextgroup=edCommand_InteractiveGlobalNotMatched_Arg_Regexp
syn region  edCommand_InteractiveGlobalNotMatched_Arg_Regexp  contained
      \ matchgroup=Delimiter
      \ start=/\z([^\\ \n]\)/
      \ end=/\z1\|$/
      \ nextgroup=edCommand_InteractiveGlobalNotMatched_Arg_Regexp_Flag
      \ contains=edRegex_EscapeSequence,edRegex_BracketExpression

" GNU extension
syn match edCommand_InteractiveGlobalNotMatched_Arg_Regexp_Flag  contained
      \ /[^\\ \n]\@1<=I/

" Write Command {{{2
syn match   edCommand_Write  contained
      \ /w\>/
      \ skipwhite
      \ nextgroup=edArg_File,edCommand_ShellEscape

" Write Append Command {{{2
" BSD/GNU extension
syn match   edCommand_WriteAppend  contained
      \ /W\>/
      \ skipwhite
      \ nextgroup=edArg_File,edCommand_ShellEscape

" Write Quit Command {{{2
" BSD/GNU extension
syn match   edCommand_WriteQuit  contained
      \ /wq\>/
      \ skipwhite
      \ nextgroup=edArg_File,edCommand_ShellEscape

" Paste Cut Buffer Command {{{2
" GNU extension
syn match   edCommand_Paste  contained
      \ /x/
      \ nextgroup=@edCommandPrint

" Yank Cut Buffer Command {{{2
" GNU extension
syn match   edCommand_Yank  contained
      \ /y/
      \ nextgroup=@edCommandPrint

" Scroll Command {{{2
" BSD/GNU extension
syn match   edCommand_Scroll  contained
      \ /z/
      \ nextgroup=edCommand_Scroll_Arg_Count,@edCommandPrint
syn match   edCommand_Scroll_Arg_Count	contained
      \ /\d\+/
      \ nextgroup=@edCommandPrint

" Line Number Command {{{2
syn match   edCommand_LineNumber  contained
      \ /=/
      \ nextgroup=@edCommandPrint
" }}}

" no address prefix commands

" Edit Command {{{2
syn match   edCommand_Edit  contained
      \ /\<e\>/
      \ skipwhite
      \ nextgroup=edArg_File,edCommand_ShellEscape

" Edit Without Checking Command {{{2
syn match   edCommand_EditWithoutChecking  contained
      \ /\<E\>/
      \ skipwhite
      \ nextgroup=edArg_File,edCommand_ShellEscape

" Filename Command {{{2
syn match   edCommand_Filename	contained
      \ /\<f\>/
      \ skipwhite
      \ nextgroup=edArg_File

" Help Command {{{2
syn match   edCommand_Help  contained
      \ /\<h/
      \ nextgroup=@edCommandPrint

" Help-Mode Command {{{2
syn match   edCommand_HelpMode	contained
      \ /\<H/
      \ nextgroup=@edCommandPrint

" Prompt Command {{{2
syn match   edCommand_Prompt  contained
      \ /\<P/
      \ nextgroup=@edCommandPrint

" Quit Command {{{2
syn match   edCommand_Quit  contained
      \ /\<q\>/

" Quit Without Checking Command {{{2
syn match   edCommand_QuitWithoutChecking  contained
      \ /\<Q\>/

" Undo Command {{{2
syn match   edCommand_Undo  contained
      \ /\<u/
      \ nextgroup=@edCommandPrint

" Shell Escape Command {{{2
syn match   edCommand_ShellEscape  contained
      \ /!/
      \ skipwhite
      \ nextgroup=edCommand_ShellEscape_Arg_Command,
      \		  edCommand_ShellEscape_Arg_Previous
syn match   edCommand_ShellEscape_Arg_Command  contained
      \ /\S.*$/
      \ contains=edCommand_ShellEscape_Arg_Command_Filename,
      \		 edCommand_ShellEscape_Arg_Command_FilenameEscape,
      \		 edCommand_ShellEscape_Arg_Command_BackslashEscape

syn match edCommand_ShellEscape_Arg_Command_Filename  contained
      \ /%/

syn match   edCommand_ShellEscape_Arg_Command_FilenameEscape   contained /\\%/
syn match   edCommand_ShellEscape_Arg_Command_BackslashEscape  contained /\\\\/

syn match   edCommand_ShellEscape_Arg_Previous	contained
      \ /!/
      \ skipwhite
      \ nextgroup=edCommand_ShellEscape_Arg_Command

" Comment Command {{{2
" GNU extension
syn match   edCommand_Comment  contained
      \ /#.*/
" }}}

syn cluster edCommand contains=edCommand_\a\+

" Command Args {{{2
syn match   edArg_File	contained /!\@!\S.*$/

" Command Suffixes {{{1
syn cluster edCommandPrint
      \ contains=edCommand_List,edCommand_Number,edCommand_Print
syn cluster edCommandPrint_InputMode
      \ contains=edCommand_List_InputMode,
      \		 edCommand_Number_InputMode,
      \		 edCommand_Print_InputMode

" Syncing {{{1

syn sync fromstart

" Default Highlighting {{{1

" addresses

hi def link edAddress				  Constant
hi def link edAddressModifier_Offset		  Special
hi def link edAddressModifier_Count		  Special
hi def link edAddress_Pattern			  Regexp
hi def link edAddress_Pattern_Flag		  Special

" commands (addresses)

hi def link edCommand				  Statement

hi def link edCommand_Append			  Statement
hi def link edCommand_Change			  Statement
hi def link edCommand_Copy			  Statement
hi def link edCommand_Delete			  Statement
hi def link edCommand_GlobalNotMatched		  Statement
hi def link edCommand_Global			  Statement
hi def link edCommand_Insert			  Statement
hi def link edCommand_InteractiveGlobalNotMatched Statement
hi def link edCommand_InteractiveGlobal		  Statement
hi def link edCommand_Join			  Statement
hi def link edCommand_LineNumber		  Statement
hi def link edCommand_List			  Statement
hi def link edCommand_List_InputMode		  edCommand_List
hi def link edCommand_Mark			  Statement
hi def link edCommand_Move			  Statement
hi def link edCommand_Number			  Statement
hi def link edCommand_Number_InputMode		  edCommand_Number
hi def link edCommand_Paste			  Statement
hi def link edCommand_Print			  Statement
hi def link edCommand_Print_InputMode		  edCommand_Print
hi def link edCommand_Read			  Statement
hi def link edCommand_Repeat			  Statement
hi def link edCommand_Scroll			  Statement
hi def link edCommand_Substitute		  Statement
hi def link edCommand_WriteAppend		  Statement
hi def link edCommand_WriteQuit			  Statement
hi def link edCommand_Write			  Statement
hi def link edCommand_Yank			  Statement

" commands (no addresses)

hi def link edCommand_Edit			  Statement
hi def link edCommand_EditWithoutChecking	  Statement
hi def link edCommand_Filename			  Statement
hi def link edCommand_HelpMode			  Statement
hi def link edCommand_Help			  Statement
hi def link edCommand_Prompt			  Statement
hi def link edCommand_Quit			  Statement
hi def link edCommand_QuitWithoutChecking	  Statement
hi def link edCommand_ShellEscape		  Statement
hi def link edCommand_Undo			  Statement

hi def link edCommand_Comment			  Comment

" command args

hi def link edArg_InputMode_Text		  Normal
hi def link edArg_InputMode_Text_Global		  edArg_InputMode_Text
hi def link edArg_InputMode_EndMarker		  edCommand

hi def link edCommand_Mark_Arg_Name		  Constant

hi def link edCommand_Scroll_Arg_Count		  Number

hi def link edCommand_ShellEscape_Arg_Command_Filename		  Special
hi def link edCommand_ShellEscape_Arg_Command_FilenameEscape	  Special
hi def link edCommand_ShellEscape_Arg_Command_BackslashEscape	  Special
hi def link edCommand_ShellEscape_Arg_Previous			  Constant

hi def link edCommand_Substitute_Arg_Regexp			  Regexp
hi def link edCommand_Substitute_Arg_Replacement_Escape		  Special
hi def link edCommand_Substitute_Arg_Replacement_Newline	  Special
hi def link edCommand_Substitute_Arg_Replacement_Match		  Special
hi def link edCommand_Substitute_Arg_Replacement_Repeat		  Special
hi def link edCommand_Substitute_Arg_Flag			  Special
hi def link edCommand_Substitute_Arg_Count			  Special

hi def link edCommand_Global_Arg_Regexp				  Regexp
hi def link edCommand_Global_Arg_Regexp_Flag			  Special
hi def link edCommand_InteractiveGlobal_Arg_Regexp		  Regexp
hi def link edCommand_InteractiveGlobal_Arg_Regexp_Flag		  Special
hi def link edCommand_GlobalNotMatched_Arg_Regexp		  Regexp
hi def link edCommand_GlobalNotMatched_Arg_Regexp_Flag		  Special
hi def link edCommand_InteractiveGlobalNotMatched_Arg_Regexp	  Regexp
hi def link edCommand_InteractiveGlobalNotMatched_Arg_Regexp_Flag Special

" line continuation

hi def link edLineContinue			  Delimiter
hi def link edLineContinue_InputMode		  edLineContinue
hi def link edLineContinue_InputMode_Text	  edLineContinue


" }}}

let b:current_syntax = "ed"

let &cpo = s:cpo_save
unlet! s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet fdm=marker:
