" Vim syntax file
" Language:     AVR Assembler (AVRA)
" AVRA Home:    http://avra.sourceforge.net/index.html
" AVRA Version: 1.3.0
" Maintainer:	  Marius Ghita <mhitza@gmail.com>

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword=a-z,A-Z,48-57,.,_
" 'isident' is a global option, better not set it
" setlocal isident=a-z,A-Z,48-57,.,_
syn case ignore

syn keyword avraRegister r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12 r13 r14
syn keyword avraRegister r15 r16 r17 r18 r19 r20 r21 r22 r23 r24 r25 r26 r27
syn keyword avraRegister r28 r29 r30 r31

syn keyword avraInstr add adc adiw sub subi sbc sbci sbiw and andi or ori eor
syn keyword avraInstr com neg sbr cbr inc dec tst clr ser mul muls mulsu fmul
syn keyword avraInstr fmuls fmulsu des rjmp ijmp eijmp jmp rcall icall eicall
syn keyword avraInstr call ret reti cpse cp cpc cpi sbrc sbrs sbic sbis brbs
syn keyword avraInstr brbc breq brne brcs brcc brsh brlo brmi brpl brge brlt
syn keyword avraInstr brhs brhc brts brtc brvs brvc brie brid mov movw ldi lds
syn keyword avraInstr ld ldd sts st std lpm elpm spm in out push pop xch las
syn keyword avraInstr lac lat lsl lsr rol ror asr swap bset bclr sbi cbi bst bld
syn keyword avraInstr sec clc sen cln sez clz sei cli ses cls sev clv set clt
syn keyword avraInstr seh clh break nop sleep wdr

syn keyword avraDirective .byte .cseg .db .def .device .dseg .dw .endmacro .equ
syn keyword avraDirective .eseg .exit .include .list .listmac .macro .nolist
syn keyword avraDirective .org .set .define .undef .ifdef .ifndef .if .else
syn keyword avraDirective .elif .elseif .warning

syn keyword avraOperator low high byte2 byte3 byte4 lwrd hwrd page exp2 log2

syn match avraNumericOperator "[-*/+]"
syn match avraUnaryOperator   "!"
syn match avraBinaryOperator  "<<\|>>\|<\|<=\|>\|>=\|==\|!="
syn match avraBitwiseOperator "[~&^|]\|&&\|||"

syn match avraBinaryNumber    "\<0[bB][0-1]*\>"
syn match avraHexNumber       "\<0[xX][0-9a-fA-F]\+\>"
syn match avraDecNumber       "\<\(0\|[1-9]\d*\)\>"

syn region avraComment start=";" end="$"
syn region avraString  start="\"" end="\"\|$"

syn match avraLabel "^\s*[^; \t]\+:"

hi def link avraBinaryNumber    avraNumber
hi def link avraHexNumber       avraNumber
hi def link avraDecNumber       avraNumber

hi def link avraNumericOperator avraOperator
hi def link avraUnaryOperator   avraOperator
hi def link avraBinaryOperator  avraOperator
hi def link avraBitwiseOperator avraOperator


hi def link avraOperator  operator
hi def link avraComment   comment
hi def link avraDirective preproc
hi def link avraRegister  type
hi def link avraNumber    constant
hi def link avraString    String
hi def link avraInstr     keyword
hi def link avraLabel     label

let b:current_syntax = "avra"

let &cpo = s:cpo_save
unlet s:cpo_save
