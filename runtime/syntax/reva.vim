" Vim syntax file
" Language:	Reva Forth
" Version:	2011.2
" Last Change:	2012/02/13
" Maintainer:	Ron Aaron <ron@ronware.org>
" URL:		http://ronware.org/reva/
" Filetypes:	*.rf *.frt
" NOTE: 	You should also have the ftplugin/reva.vim file to set 'isk'

" quit when a syntax file was already loaded
if exists("b:current_syntax")
   finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn clear

" Synchronization method
syn sync ccomment
syn sync maxlines=100


syn case ignore
" Some special, non-FORTH keywords
"syn keyword revaTodo contained todo fixme bugbug todo: bugbug: note:
syn match revaTodo contained '\(todo\|fixme\|bugbug\|note\)[:]*'
syn match revaTodo contained 'copyright\(\s(c)\)\=\(\s[0-9]\{2,4}\)\='

syn match revaHelpDesc '\S.*' contained
syn match revaHelpStuff '\<\(def\|stack\|ctx\|ver\|os\|related\):\s.*'
syn region revaHelpStuff start='\<desc:\>' end='^\S' contains=revaHelpDesc
syn region revaEOF start='\<|||\>' end='{$}' contains=revaHelpStuff


syn case match
" basic mathematical and logical operators
syn keyword revaoperators + - * / mod /mod negate abs min max umin umax
syn keyword revaoperators and or xor not invert 1+ 1-
syn keyword revaoperators m+ */ */mod m* um* m*/ um/mod fm/mod sm/rem
syn keyword revaoperators d+ d- dnegate dabs dmin dmax > < = >> << u< <>


" stack manipulations
syn keyword revastack drop nip dup over tuck swap rot -rot ?dup pick roll
syn keyword revastack 2drop 2nip 2dup 2over 2swap 2rot 3drop
syn keyword revastack >r r> r@ rdrop
" syn keyword revastack sp@ sp! rp@ rp!

" address operations
syn keyword revamemory @ ! +! c@ c! 2@ 2! align aligned allot allocate here free resize
syn keyword revaadrarith chars char+ cells cell+ cell cell- 2cell+ 2cell- 3cell+ 4cell+
syn keyword revamemblks move fill

" conditionals
syn keyword revacond if else then =if >if <if <>if if0  ;; catch throw

" iterations
syn keyword revaloop while repeat until again
syn keyword revaloop do loop i j leave  unloop skip more

" new words
syn match revaColonDef '\<noname:\|\<:\s+' contains=revaComment
syn keyword revaEndOfColonDef ; ;inline
syn keyword revadefine constant constant, variable create variable,
syn keyword revadefine user value to +to defer! defer@ defer is does> immediate
syn keyword revadefine compile literal ' [']

" Built in words
com! -nargs=+ Builtin syn keyword revaBuiltin <args>
Builtin execute ahead interp bye >body here pad words make
Builtin accept close cr creat delete ekey emit fsize ioerr key?
Builtin mtime open/r open/rw read rename seek space spaces stat
Builtin tell type type_ write (seek) (argv) (save) 0; 0drop;
Builtin >class >lz >name >xt alias alias: appname argc asciiz, asciizl,
Builtin body> clamp depth disassemble findprev fnvhash getenv here,
Builtin iterate last! last@ later link lz> lzmax os parse/ peek
Builtin peek-n pop prior push put rp@ rpick save setenv slurp
Builtin stack-empty? stack-iterate stack-size stack: THROW_BADFUNC
Builtin THROW_BADLIB THROW_GENERIC used xt>size z,
Builtin +lplace +place -chop /char /string bounds c+lplace c+place
Builtin chop cmp cmpi count lc lcount lplace place quote rsplit search split
Builtin zcount zt \\char
Builtin chdir g32 k32 u32 getcwd getpid hinst osname stdin stdout
Builtin (-lib) (bye) (call) (else) (find) (func) (here) (if (lib) (s0) (s^)
Builtin (to~) (while) >in >rel ?literal appstart cold compiling? context? d0 default_class
Builtin defer? dict dolstr dostr find-word h0 if) interp isa onexit
Builtin onstartup pdoes pop>ebx prompt rel> rp0 s0 src srcstr state str0 then,> then> tib
Builtin tp vector vector! word? xt? .ver revaver revaver# && '' 'constant 'context
Builtin 'create 'defer 'does 'forth 'inline 'macro 'macront 'notail 'value 'variable
Builtin (.r) (context) (create) (header) (hide) (inline) (p.r) (words~) (xfind)
Builtin ++ -- , -2drop -2nip -link -swap . .2x .classes .contexts .funcs .libs .needs .r
Builtin .rs .x 00; 0do 0if 1, 2, 3, 2* 2/ 2constant 2variable 3dup 4dup ;then >base >defer
Builtin >rr ? ?do @execute @rem appdir argv as back base base! between chain cleanup-libs
Builtin cmove> context?? ctrl-c ctx>name data: defer: defer@def dictgone do_cr eleave
Builtin endcase endof eval exception exec false find func: header heapgone help help/
Builtin hex# hide inline{ last lastxt lib libdir literal, makeexename mnotail ms ms@
Builtin newclass noop nosavedict notail nul of off on p: padchar parse parseln
Builtin parsews rangeof rdepth remains reset reva revaused rol8 rr> scratch setclass sp
Builtin strof super> temp time&date true turnkey? undo vfunc: w! w@
Builtin xchg xchg2 xfind xt>name xwords { {{ }} }  _+ _1+ _1- pathsep case \||
" p[ [''] [ [']


" debugging
syn keyword revadebug .s dump see

" basic character operations
" syn keyword revaCharOps (.) CHAR EXPECT FIND WORD TYPE -TRAILING EMIT KEY
" syn keyword revaCharOps KEY? TIB CR
" syn match revaCharOps '\<char\s\S\s'
" syn match revaCharOps '\<\[char\]\s\S\s'
" syn region revaCharOps start=+."\s+ skip=+\\"+ end=+"+

" char-number conversion
syn keyword revaconversion s>d >digit digit> >single >double >number >float

" contexts
syn keyword revavocs forth macro inline
syn keyword revavocs context:
syn match revavocs /\<\~[^~ ]*/
syn match revavocs /[^~ ]*\~\>/

" numbers
syn keyword revamath decimal hex base binary octal
syn match revainteger '\<-\=[0-9.]*[0-9.]\+\>'
" recognize hex and binary numbers, the '$' and '%' notation is for greva
syn match revainteger '\<\$\x*\x\+\>' " *1* --- dont't mess
syn match revainteger '\<\x*\d\x*\>'  " *2* --- this order!
syn match revainteger '\<%[0-1]*[0-1]\+\>'
syn match revainteger "\<'.\>"

" Strings
" syn region revaString start=+\.\?\"+ end=+"+ end=+$+
syn region revaString start=/"/ skip=/\\"/ end=/"/

" Comments
syn region revaComment start='\\S\s' end='.*' contains=revaTodo
syn match revaComment '\.(\s[^)]\{-})' contains=revaTodo
syn region revaComment start='(\s' skip='\\)' end=')' contains=revaTodo
syn match revaComment '(\s[^\-]*\-\-[^\-]\{-})' contains=revaTodo
syn match revaComment '\<|\s.*$' contains=revaTodo
syn match revaColonDef '\<:m\?\s*[^ \t]\+\>' contains=revaComment

" Include files
syn match revaInclude '\<\(include\|needs\)\s\+\S\+'


" Define the default highlighting.
if !exists("did_reva_syntax_inits")
    let did_reva_syntax_inits=1
    " The default methods for highlighting. Can be overriden later.
    hi def link revaEOF cIf0
    hi def link revaHelpStuff  special
    hi def link revaHelpDesc Comment
    hi def link revaTodo Todo
    hi def link revaOperators Operator
    hi def link revaMath Number
    hi def link revaInteger Number
    hi def link revaStack Special
    hi def link revaFStack Special
    hi def link revaSP Special
    hi def link revaMemory Operator
    hi def link revaAdrArith Function
    hi def link revaMemBlks Function
    hi def link revaCond Conditional
    hi def link revaLoop Repeat
    hi def link revaColonDef Define
    hi def link revaEndOfColonDef Define
    hi def link revaDefine Define
    hi def link revaDebug Debug
    hi def link revaCharOps Character
    hi def link revaConversion String
    hi def link revaForth Statement
    hi def link revaVocs Statement
    hi def link revaString String
    hi def link revaComment Comment
    hi def link revaClassDef Define
    hi def link revaEndOfClassDef Define
    hi def link revaObjectDef Define
    hi def link revaEndOfObjectDef Define
    hi def link revaInclude Include
    hi def link revaBuiltin Keyword
endif

let b:current_syntax = "reva"
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8:sw=4:nocindent:smartindent:
