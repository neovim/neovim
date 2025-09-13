" Vim syntax file
" Language:		Vim help file
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Last Change:		2025 Jul 12
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn iskeyword @,48-57,_,192-255

if !exists('g:help_example_languages')
  let g:help_example_languages = #{ vim: 'vim' }
endif

syn match helpHeadline		"^[A-Z.][-A-Z0-9 .,()_']*?\=\ze\(\s\+\*\|$\)"
syn match helpSectionDelim	"^===.*===$"
syn match helpSectionDelim	"^---.*--$"

if has("conceal")
  syn region helpExample	matchgroup=helpIgnore
        \ start="\%(^\| \)>[a-z0-9]*$" end="^[^ \t]"me=e-1 end="^<" concealends
else
   syn region helpExample	matchgroup=helpIgnore
         \ start="\%(^\| \)>[a-z0-9]*$" end="^[^ \t]"me=e-1 end="^<"
endif

for [s:lang, s:syntax] in g:help_example_languages->items()
  unlet! b:current_syntax
  " silent! to prevent E403
  execute 'silent! syn include' $'@helpExampleHighlight_{s:lang}'
        \ $'syntax/{s:syntax}.vim'

  execute $'syn region helpExampleHighlight_{s:lang} matchgroup=helpIgnore'
        \ $'start=/\%(^\| \)>{s:lang}$/'
        \ 'end=/^[^ \t]/me=e-1 end=/^</'
        \ (has("conceal") ? 'concealends' : '')
        \ $'contains=@helpExampleHighlight_{s:lang} keepend'
endfor
unlet! s:lang s:syntax

syn match helpHyperTextJump	"\\\@<!|[#-)!+-~]\+|" contains=helpBar
syn match helpHyperTextEntry	"\*[#-)!+-~]\+\*\s"he=e-1 contains=helpStar
syn match helpHyperTextEntry	"\*[#-)!+-~]\+\*$" contains=helpStar
if has("conceal")
  syn match helpBar		contained "|" conceal
  syn match helpBacktick	contained "`" conceal
  syn match helpStar		contained "\*" conceal
else
  syn match helpBar		contained "|"
  syn match helpBacktick	contained "`"
  syn match helpStar		contained "\*"
endif
syn match helpNormal		"|.*====*|"
syn match helpNormal		"|||"
syn match helpNormal		":|vim:|"	" for :help modeline
syn match helpVim		"\<Vim version [0-9][0-9.a-z]*"
syn match helpVim		"VIM REFERENCE.*"
syn match helpVim		"NVIM REFERENCE.*"
syn match helpOption		"'[a-z]\{2,\}'"
syn match helpOption		"'t_..'"
syn match helpNormal		"'ab'"
syn match helpCommand		"`[^` \t]\+`"hs=s+1,he=e-1 contains=helpBacktick
" doesn't allow a . directly after an ending backtick. See :helpgrep `[^`,]\+ [^`,]\+`\.
syn match helpCommand		"\(^\|[^a-z"[]\)\zs`[^`]\+`\ze\([^a-z\t."']\|[.?!]\?$\)"hs=s+1,he=e-1 contains=helpBacktick
syn match helpHeader		"\s*\zs.\{-}\ze\s\=\~$" nextgroup=helpIgnore
syn match helpGraphic		".* \ze`$" nextgroup=helpIgnore
if has("conceal")
  syn match helpIgnore		"." contained conceal
else
  syn match helpIgnore		"." contained
endif

" match 'iskeyword' word boundaries, '!-~,^*,^|,^",192-255'
let s:iskeyword =  '!#-)+-{}~\d192-\d255'
let s:start_word = $'\%(^\|[^{s:iskeyword}]\)\@1<='
let s:end_word =      $'\%([^{s:iskeyword}]\|$\)\@='

exec $'syn match helpNote	"{s:start_word}\%(note\|Note\|NOTE\|Notes\):\={s:end_word}"'
exec $'syn match helpNote       "\c[[(]note\%(:\|{s:end_word}\)"ms=s+1'
exec $'syn match helpWarning	"{s:start_word}\%(WARNING:\=\|Warning:\){s:end_word}"'
exec $'syn match helpDeprecated	"{s:start_word}\%(DEPRECATED:\=\|Deprecated:\){s:end_word}"'
exec $'syn match helpSpecial	"{s:start_word}N{s:end_word}"'
exec $'syn match helpSpecial	"{s:start_word}N\.$"me=e-1'
exec $'syn match helpSpecial	"{s:start_word}N\.\s"me=e-2'
exec $'syn match helpSpecial	"(N{s:end_word}"ms=s+1'
syn match helpSpecial		"\[N]"
" avoid highlighting N  N in quickref.txt
syn match helpSpecial		"N  N"he=s+1
syn match helpSpecial		"Nth"me=e-2
syn match helpSpecial		"N-1"me=e-2
" highlighting N for :resize in windows.txt
exec $'syn match helpSpecial	"] -N{s:end_word}"ms=s+3'
exec $'syn match helpSpecial	"+N{s:end_word}"ms=s+1'
exec $'syn match helpSpecial	"\[+-]N{s:end_word}"ms=s+4'

unlet s:iskeyword s:start_word s:end_word

" highlighting N of cinoptions-values in indent.txt
syn match helpSpecial		"^\t-\?\zsNs\?\s"me=s+1
" highlighting N of cinoptions-values in indent.txt
syn match helpSpecial		"^\t[>enf{}^L:=lbghNEpti+cC/(uUwWkmMjJ)*#P]N\s"ms=s+2,me=e-1
syn match helpSpecial		"{[-_a-zA-Z0-9'"*+/:%#=[\]<>.,]\+}"
syn match helpSpecial		"\s\[[-a-z^A-Z0-9_]\{2,}]"ms=s+1
syn match helpSpecial		"<[-a-zA-Z0-9_]\+>"
syn match helpSpecial		"<buffer=\w\+>"
syn match helpSpecial		"<[SCM]-.>"
syn match helpNormal		"<---*>"
syn match helpSpecial		"\[range]"
syn match helpSpecial		"\[line]"
syn match helpSpecial		"\[count]"
syn match helpSpecial		"\[offset]"
syn match helpSpecial		"\[cmd]"
syn match helpSpecial		"\[num]"
syn match helpSpecial		"\[+num]"
syn match helpSpecial		"\[-num]"
syn match helpSpecial		"\[+cmd]"
syn match helpSpecial		"\[++opt]"
syn match helpSpecial		"\[++once]"
syn match helpSpecial		"\[++nested]"
syn match helpSpecial		"\[++t]"
syn match helpSpecial		"\[arg]"
syn match helpSpecial		"\[arguments]"
syn match helpSpecial		"\[ident]"
syn match helpSpecial		"\[addr]"
syn match helpSpecial		"\[group]"
" Don't highlight [converted] and others that do not have a tag
syn match helpNormal		"\[\(readonly\|fifo\|socket\|converted\|crypted\)]"

syn match helpSpecial		"CTRL-."
syn match helpSpecial		"CTRL-<\a\+>"
syn match helpSpecial		"CTRL-SHIFT-."
syn match helpSpecial		"CTRL-Break"
syn match helpSpecial		"CTRL-PageUp"
syn match helpSpecial		"CTRL-PageDown"
syn match helpSpecial		"CTRL-Insert"
syn match helpSpecial		"CTRL-Del"
syn match helpSpecial		"CTRL-{char}"
syn match helpSpecial		"META-."
syn match helpSpecial		"ALT-."

" Highlight group items in their own color.
syn match helpComment		"\t[* ]Comment\t\+[a-z].*"
syn match helpConstant		"\t[* ]Constant\t\+[a-z].*"
syn match helpString		"\t[* ]String\t\+[a-z].*"
syn match helpCharacter		"\t[* ]Character\t\+[a-z].*"
syn match helpNumber		"\t[* ]Number\t\+[a-z].*"
syn match helpBoolean		"\t[* ]Boolean\t\+[a-z].*"
syn match helpFloat		"\t[* ]Float\t\+[a-z].*"
syn match helpIdentifier	"\t[* ]Identifier\t\+[a-z].*"
syn match helpFunction		"\t[* ]Function\t\+[a-z].*"
syn match helpStatement		"\t[* ]Statement\t\+[a-z].*"
syn match helpConditional	"\t[* ]Conditional\t\+[a-z].*"
syn match helpRepeat		"\t[* ]Repeat\t\+[a-z].*"
syn match helpLabel		"\t[* ]Label\t\+[a-z].*"
syn match helpOperator		"\t[* ]Operator\t\+["a-z].*"
syn match helpKeyword		"\t[* ]Keyword\t\+[a-z].*"
syn match helpException		"\t[* ]Exception\t\+[a-z].*"
syn match helpPreProc		"\t[* ]PreProc\t\+[a-z].*"
syn match helpInclude		"\t[* ]Include\t\+[a-z].*"
syn match helpDefine		"\t[* ]Define\t\+[a-z].*"
syn match helpMacro		"\t[* ]Macro\t\+[a-z].*"
syn match helpPreCondit		"\t[* ]PreCondit\t\+[a-z].*"
syn match helpType		"\t[* ]Type\t\+[a-z].*"
syn match helpStorageClass	"\t[* ]StorageClass\t\+[a-z].*"
syn match helpStructure		"\t[* ]Structure\t\+[a-z].*"
syn match helpTypedef		"\t[* ]Typedef\t\+[Aa-z].*"
syn match helpSpecial		"\t[* ]Special\t\+[a-z].*"
syn match helpSpecialChar	"\t[* ]SpecialChar\t\+[a-z].*"
syn match helpTag		"\t[* ]Tag\t\+[a-z].*"
syn match helpDelimiter		"\t[* ]Delimiter\t\+[a-z].*"
syn match helpSpecialComment	"\t[* ]SpecialComment\t\+[a-z].*"
syn match helpDebug		"\t[* ]Debug\t\+[a-z].*"
syn match helpUnderlined	"\t[* ]Underlined\t\+[a-z].*"
syn match helpError		"\t[* ]Error\t\+[a-z].*"
syn match helpTodo		"\t[* ]Todo\t\+[a-z].*"

syn match helpURL `\v<(((https?|ftp|gopher)://|(mailto|file|news):)[^'" \t<>{}]+|(www|web|w3)[a-z0-9_-]*\.[a-z0-9._-]+\.[^'" \t<>{}]+)[a-zA-Z0-9/]`

syn match helpDiffAdded		"\t[* ]Added\t\+[a-z].*"
syn match helpDiffChanged	"\t[* ]Changed\t\+[a-z].*"
syn match helpDiffRemoved	"\t[* ]Removed\t\+[a-z].*"

" Additionally load a language-specific syntax file "help_ab.vim".
let s:i = match(expand("%"), '\.\a\ax$')
if s:i > 0
  exe "runtime syntax/help_" . strpart(expand("%"), s:i + 1, 2) . ".vim"
endif
unlet s:i

syn sync minlines=40


" Define the default highlighting.
" Only used when an item doesn't have highlighting yet
hi def link helpIgnore		Ignore
hi def link helpHyperTextJump	Identifier
hi def link helpBar		Ignore
hi def link helpBacktick	Ignore
hi def link helpStar		Ignore
hi def link helpHyperTextEntry	String
hi def link helpHeadline	Statement
hi def link helpHeader		PreProc
hi def link helpSectionDelim	PreProc
hi def link helpVim		Identifier
hi def link helpCommand		Comment
hi def link helpExample		Comment
hi def link helpOption		Type
hi def link helpSpecial		Special
hi def link helpNote		Todo
hi def link helpWarning		Todo
hi def link helpDeprecated	Todo

hi def link helpComment		Comment
hi def link helpConstant	Constant
hi def link helpString		String
hi def link helpCharacter	Character
hi def link helpNumber		Number
hi def link helpBoolean		Boolean
hi def link helpFloat		Float
hi def link helpIdentifier	Identifier
hi def link helpFunction	Function
hi def link helpStatement	Statement
hi def link helpConditional	Conditional
hi def link helpRepeat		Repeat
hi def link helpLabel		Label
hi def link helpOperator	Operator
hi def link helpKeyword		Keyword
hi def link helpException	Exception
hi def link helpPreProc		PreProc
hi def link helpInclude		Include
hi def link helpDefine		Define
hi def link helpMacro		Macro
hi def link helpPreCondit	PreCondit
hi def link helpType		Type
hi def link helpStorageClass	StorageClass
hi def link helpStructure	Structure
hi def link helpTypedef		Typedef
hi def link helpSpecialChar	SpecialChar
hi def link helpTag		Tag
hi def link helpDelimiter	Delimiter
hi def link helpSpecialComment	SpecialComment
hi def link helpDebug		Debug
hi def link helpUnderlined	Underlined
hi def link helpError		Error
hi def link helpTodo		Todo
hi def link helpURL		String
hi def link helpDiffAdded	Added
hi def link helpDiffChanged	Changed
hi def link helpDiffRemoved	Removed

let b:current_syntax = "help"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8 sw=2
