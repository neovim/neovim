" Vim syntax file
" Language:	(VAX) Macro Assembly
" Maintainer:	Tom Uijldert <tom.uijldert [at] cmg.nl>
" Last change:	2004 May 16
"
" This is incomplete. Feel free to contribute...
"

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case ignore

" Partial list of register symbols
syn keyword vmasmReg	r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12
syn keyword vmasmReg	ap fp sp pc iv dv

" All matches - order is important!
syn keyword vmasmOpcode adawi adwc ashl ashq bitb bitw bitl decb decw decl
syn keyword vmasmOpcode ediv emul incb incw incl mcomb mcomw mcoml
syn keyword vmasmOpcode movzbw movzbl movzwl popl pushl rotl sbwc
syn keyword vmasmOpcode cmpv cmpzv cmpc3 cmpc5 locc matchc movc3 movc5
syn keyword vmasmOpcode movtc movtuc scanc skpc spanc crc extv extzv
syn keyword vmasmOpcode ffc ffs insv aobleq aoblss bbc bbs bbcci bbssi
syn keyword vmasmOpcode blbc blbs brb brw bsbb bsbw caseb casew casel
syn keyword vmasmOpcode jmp jsb rsb sobgeq sobgtr callg calls ret
syn keyword vmasmOpcode bicpsw bispsw bpt halt index movpsl nop popr pushr xfc
syn keyword vmasmOpcode insqhi insqti insque remqhi remqti remque
syn keyword vmasmOpcode addp4 addp6 ashp cmpp3 cmpp4 cvtpl cvtlp cvtps cvtpt
syn keyword vmasmOpcode cvtsp cvttp divp movp mulp subp4 subp6 editpc
syn keyword vmasmOpcode prober probew rei ldpctx svpctx mfpr mtpr bugw bugl
syn keyword vmasmOpcode vldl vldq vgathl vgathq vstl vstq vscatl vscatq
syn keyword vmasmOpcode vvcvt iota mfvp mtvp vsync
syn keyword vmasmOpcode beql[u] bgtr[u] blss[u]
syn match vmasmOpcode "\<add[bwlfdgh][23]\>"
syn match vmasmOpcode "\<bi[cs][bwl][23]\>"
syn match vmasmOpcode "\<clr[bwlqofdgh]\>"
syn match vmasmOpcode "\<cmp[bwlfdgh]\>"
syn match vmasmOpcode "\<cvt[bwlfdgh][bwlfdgh]\>"
syn match vmasmOpcode "\<cvtr[fdgh]l\>"
syn match vmasmOpcode "\<div[bwlfdgh][23]\>"
syn match vmasmOpcode "\<emod[fdgh]\>"
syn match vmasmOpcode "\<mneg[bwlfdgh]\>"
syn match vmasmOpcode "\<mov[bwlqofdgh]\>"
syn match vmasmOpcode "\<mul[bwlfdgh][23]\>"
syn match vmasmOpcode "\<poly[fdgh]\>"
syn match vmasmOpcode "\<sub[bwlfdgh][23]\>"
syn match vmasmOpcode "\<tst[bwlfdgh]\>"
syn match vmasmOpcode "\<xor[bwl][23]\>"
syn match vmasmOpcode "\<mova[bwlfqdgho]\>"
syn match vmasmOpcode "\<push[bwlfqdgho]\>"
syn match vmasmOpcode "\<acb[bwlfgdh]\>"
syn match vmasmOpcode "\<b[lng]equ\=\>"
syn match vmasmOpcode "\<b[cv][cs]\>"
syn match vmasmOpcode "\<bb[cs][cs]\>"
syn match vmasmOpcode "\<v[vs]add[lfdg]\>"
syn match vmasmOpcode "\<v[vs]cmp[lfdg]\>"
syn match vmasmOpcode "\<v[vs]div[fdg]\>"
syn match vmasmOpcode "\<v[vs]mul[lfdg]\>"
syn match vmasmOpcode "\<v[vs]sub[lfdg]\>"
syn match vmasmOpcode "\<v[vs]bi[cs]l\>"
syn match vmasmOpcode "\<v[vs]xorl\>"
syn match vmasmOpcode "\<v[vs]merge\>"
syn match vmasmOpcode "\<v[vs]s[rl]ll\>"

" Various number formats
syn match vmasmdecNumber	"[+-]\=[0-9]\+\>"
syn match vmasmdecNumber	"^d[0-9]\+\>"
syn match vmasmhexNumber	"^x[0-9a-f]\+\>"
syn match vmasmoctNumber	"^o[0-7]\+\>"
syn match vmasmbinNumber	"^b[01]\+\>"
syn match vmasmfloatNumber	"[-+]\=[0-9]\+E[-+]\=[0-9]\+"
syn match vmasmfloatNumber	"[-+]\=[0-9]\+\.[0-9]*\(E[-+]\=[0-9]\+\)\="

" Valid labels
syn match vmasmLabel		"^[a-z_$.][a-z0-9_$.]\{,30}::\="
syn match vmasmLabel		"\<[0-9]\{1,5}\$:\="          " Local label

" Character string constants
"       Too complex really. Could be "<...>" but those could also be
"       expressions. Don't know how to handle chosen delimiters
"       ("^<sep>...<sep>")
" syn region vmasmString		start="<" end=">" oneline

" Operators
syn match vmasmOperator	"[-+*/@&!\\]"
syn match vmasmOperator	"="
syn match vmasmOperator	"=="		" Global assignment
syn match vmasmOperator	"%length(.*)"
syn match vmasmOperator	"%locate(.*)"
syn match vmasmOperator	"%extract(.*)"
syn match vmasmOperator	"^[amfc]"
syn match vmasmOperator	"[bwlg]^"

syn match vmasmOperator	"\<\(not_\)\=equal\>"
syn match vmasmOperator	"\<less_equal\>"
syn match vmasmOperator	"\<greater\(_equal\)\=\>"
syn match vmasmOperator	"\<less_than\>"
syn match vmasmOperator	"\<\(not_\)\=defined\>"
syn match vmasmOperator	"\<\(not_\)\=blank\>"
syn match vmasmOperator	"\<identical\>"
syn match vmasmOperator	"\<different\>"
syn match vmasmOperator	"\<eq\>"
syn match vmasmOperator	"\<[gl]t\>"
syn match vmasmOperator	"\<n\=df\>"
syn match vmasmOperator	"\<n\=b\>"
syn match vmasmOperator	"\<idn\>"
syn match vmasmOperator	"\<[nlg]e\>"
syn match vmasmOperator	"\<dif\>"

" Special items for comments
syn keyword vmasmTodo		contained todo

" Comments
syn match vmasmComment		";.*" contains=vmasmTodo

" Include
syn match vmasmInclude		"\.library\>"

" Macro definition
syn match vmasmMacro		"\.macro\>"
syn match vmasmMacro		"\.mexit\>"
syn match vmasmMacro		"\.endm\>"
syn match vmasmMacro		"\.mcall\>"
syn match vmasmMacro		"\.mdelete\>"

" Conditional assembly
syn match vmasmPreCond		"\.iff\=\>"
syn match vmasmPreCond		"\.if_false\>"
syn match vmasmPreCond		"\.iftf\=\>"
syn match vmasmPreCond		"\.if_true\(_false\)\=\>"
syn match vmasmPreCond		"\.iif\>"

" Loop control
syn match vmasmRepeat		"\.irpc\=\>"
syn match vmasmRepeat		"\.repeat\>"
syn match vmasmRepeat		"\.rept\>"
syn match vmasmRepeat		"\.endr\>"

" Directives
syn match vmasmDirective	"\.address\>"
syn match vmasmDirective	"\.align\>"
syn match vmasmDirective	"\.asci[cdiz]\>"
syn match vmasmDirective	"\.blk[abdfghloqw]\>"
syn match vmasmDirective	"\.\(signed_\)\=byte\>"
syn match vmasmDirective	"\.\(no\)\=cross\>"
syn match vmasmDirective	"\.debug\>"
syn match vmasmDirective	"\.default displacement\>"
syn match vmasmDirective	"\.[dfgh]_floating\>"
syn match vmasmDirective	"\.disable\>"
syn match vmasmDirective	"\.double\>"
syn match vmasmDirective	"\.dsabl\>"
syn match vmasmDirective	"\.enable\=\>"
syn match vmasmDirective	"\.endc\=\>"
syn match vmasmDirective	"\.entry\>"
syn match vmasmDirective	"\.error\>"
syn match vmasmDirective	"\.even\>"
syn match vmasmDirective	"\.external\>"
syn match vmasmDirective	"\.extrn\>"
syn match vmasmDirective	"\.float\>"
syn match vmasmDirective	"\.globa\=l\>"
syn match vmasmDirective	"\.ident\>"
syn match vmasmDirective	"\.link\>"
syn match vmasmDirective	"\.list\>"
syn match vmasmDirective	"\.long\>"
syn match vmasmDirective	"\.mask\>"
syn match vmasmDirective	"\.narg\>"
syn match vmasmDirective	"\.nchr\>"
syn match vmasmDirective	"\.nlist\>"
syn match vmasmDirective	"\.ntype\>"
syn match vmasmDirective	"\.octa\>"
syn match vmasmDirective	"\.odd\>"
syn match vmasmDirective	"\.opdef\>"
syn match vmasmDirective	"\.packed\>"
syn match vmasmDirective	"\.page\>"
syn match vmasmDirective	"\.print\>"
syn match vmasmDirective	"\.psect\>"
syn match vmasmDirective	"\.quad\>"
syn match vmasmDirective	"\.ref[1248]\>"
syn match vmasmDirective	"\.ref16\>"
syn match vmasmDirective	"\.restore\(_psect\)\=\>"
syn match vmasmDirective	"\.save\(_psect\)\=\>"
syn match vmasmDirective	"\.sbttl\>"
syn match vmasmDirective	"\.\(no\)\=show\>"
syn match vmasmDirective	"\.\(sub\)\=title\>"
syn match vmasmDirective	"\.transfer\>"
syn match vmasmDirective	"\.warn\>"
syn match vmasmDirective	"\.weak\>"
syn match vmasmDirective	"\.\(signed_\)\=word\>"

syn case match

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_macro_syntax_inits")
  if version < 508
    let did_macro_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  " The default methods for highlighting.  Can be overridden later
  " Comment Constant Error Identifier PreProc Special Statement Todo Type
  "
  " Constant		Boolean Character Number String
  " Identifier		Function
  " PreProc		Define Include Macro PreCondit
  " Special		Debug Delimiter SpecialChar SpecialComment Tag
  " Statement		Conditional Exception Keyword Label Operator Repeat
  " Type		StorageClass Structure Typedef

  HiLink vmasmComment		Comment
  HiLink vmasmTodo		Todo

  HiLink vmasmhexNumber		Number		" Constant
  HiLink vmasmoctNumber		Number		" Constant
  HiLink vmasmbinNumber		Number		" Constant
  HiLink vmasmdecNumber		Number		" Constant
  HiLink vmasmfloatNumber	Number		" Constant

"  HiLink vmasmString		String		" Constant

  HiLink vmasmReg		Identifier
  HiLink vmasmOperator		Identifier

  HiLink vmasmInclude		Include		" PreProc
  HiLink vmasmMacro		Macro		" PreProc
  " HiLink vmasmMacroParam	Keyword		" Statement

  HiLink vmasmDirective		Special
  HiLink vmasmPreCond		Special


  HiLink vmasmOpcode		Statement
  HiLink vmasmCond		Conditional	" Statement
  HiLink vmasmRepeat		Repeat		" Statement

  HiLink vmasmLabel		Type
  delcommand HiLink
endif

let b:current_syntax = "vmasm"

" vim: ts=8 sw=2
