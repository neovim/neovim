" Vim syntax file
" Language:	JAL
" Version: 0.1
" Last Change:	2003 May 11
" Maintainer:  Mark Gross <mark@thegnar.org>
" This is a syntax definition for the JAL language.
" It is based on the Source Forge compiler source code.
" https://sourceforge.net/projects/jal/
"
" TODO test.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case ignore
syn sync lines=250

syn keyword picTodo NOTE TODO XXX contained

syn match picIdentifier "[a-z_$][a-z0-9_$]*"
syn match picLabel      "^[A-Z_$][A-Z0-9_$]*"
syn match picLabel      "^[A-Z_$][A-Z0-9_$]*:"me=e-1

syn match picASCII      "A\='.'"
syn match picBinary     "B'[0-1]\+'"
syn match picDecimal    "D'\d\+'"
syn match picDecimal    "\d\+"
syn match picHexadecimal "0x\x\+"
syn match picHexadecimal "H'\x\+'"
syn match picHexadecimal "[0-9]\x*h"
syn match picOctal      "O'[0-7]\o*'"

syn match picComment    ";.*" contains=picTodo

syn region picString    start=+"+ end=+"+

syn keyword picRegister indf tmr0 pcl status fsr port_a port_b port_c port_d port_e x84_eedata x84_eeadr pclath intcon
syn keyword picRegister f877_tmr1l   f877_tmr1h   f877_t1con   f877_t2con   f877_ccpr1l  f877_ccpr1h  f877_ccp1con
syn keyword picRegister f877_pir1    f877_pir2    f877_pie1    f877_adcon1  f877_adcon0  f877_pr2     f877_adresl  f877_adresh
syn keyword picRegister f877_eeadr   f877_eedath  f877_eeadrh  f877_eedata  f877_eecon1  f877_eecon2  f628_EECON2
syn keyword picRegister f877_rcsta   f877_txsta   f877_spbrg   f877_txreg   f877_rcreg   f628_EEDATA  f628_EEADR   f628_EECON1

" Register --- bits
" STATUS
syn keyword picRegisterPart status_c status_dc status_z status_pd
syn keyword picRegisterPart status_to status_rp0 status_rp1 status_irp

" pins
syn keyword picRegisterPart pin_a0 pin_a1 pin_a2 pin_a3 pin_a4 pin_a5
syn keyword picRegisterPart pin_b0 pin_b1 pin_b2 pin_b3 pin_b4 pin_b5 pin_b6 pin_b7
syn keyword picRegisterPart pin_c0 pin_c1 pin_c2 pin_c3 pin_c4 pin_c5 pin_c6 pin_c7
syn keyword picRegisterPart pin_d0 pin_d1 pin_d2 pin_d3 pin_d4 pin_d5 pin_d6 pin_d7
syn keyword picRegisterPart pin_e0 pin_e1 pin_e2

syn keyword picPortDir port_a_direction  port_b_direction  port_c_direction  port_d_direction  port_e_direction

syn match picPinDir "pin_a[012345]_direction"
syn match picPinDir "pin_b[01234567]_direction"
syn match picPinDir "pin_c[01234567]_direction"
syn match picPinDir "pin_d[01234567]_direction"
syn match picPinDir "pin_e[012]_direction"


" INTCON
syn keyword picRegisterPart intcon_gie intcon_eeie intcon_peie intcon_t0ie intcon_inte
syn keyword picRegisterPart intcon_rbie intcon_t0if intcon_intf intcon_rbif

" TIMER
syn keyword picRegisterPart t1ckps1 t1ckps0 t1oscen t1sync tmr1cs tmr1on tmr1ie tmr1if

"cpp bits
syn keyword picRegisterPart ccp1x ccp1y

" adcon bits
syn keyword picRegisterPart adcon0_go adcon0_ch0 adcon0_ch1 adcon0_ch2

" EECON
syn keyword picRegisterPart  eecon1_rd eecon1_wr eecon1_wren eecon1_wrerr eecon1_eepgd
syn keyword picRegisterPart f628_eecon1_rd f628_eecon1_wr f628_eecon1_wren f628_eecon1_wrerr

" usart
syn keyword picRegisterPart tx9 txen sync brgh tx9d
syn keyword picRegisterPart spen rx9 cren ferr oerr rx9d
syn keyword picRegisterPart TXIF RCIF

" OpCodes...
syn keyword picOpcode addlw andlw call clrwdt goto iorlw movlw option retfie retlw return sleep sublw tris
syn keyword picOpcode xorlw addwf andwf clrf clrw comf decf decfsz incf incfsz retiw iorwf movf movwf nop
syn keyword picOpcode rlf rrf subwf swapf xorwf bcf bsf btfsc btfss skpz skpnz setz clrz skpc skpnc setc clrc
syn keyword picOpcode skpdc skpndc setdc clrdc movfw tstf bank page HPAGE mullw mulwf cpfseq cpfsgt cpfslt banka bankb


syn keyword jalBoolean		true false
syn keyword jalBoolean		off on
syn keyword jalBit		high low
syn keyword jalConstant		Input Output all_input all_output
syn keyword jalConditional	if else then elsif end if
syn keyword jalLabel		goto
syn keyword jalRepeat		for while forever loop
syn keyword jalStatement	procedure function
syn keyword jalStatement	return end volatile const var
syn keyword jalType		bit byte

syn keyword jalModifier		interrupt assembler asm put get
syn keyword jalStatement	out in is begin at
syn keyword jalDirective	pragma jump_table target target_clock target_chip name error test assert
syn keyword jalPredefined       hs xt rc lp internal 16c84 16f84 16f877 sx18 sx28 12c509a 12c508
syn keyword jalPredefined       12ce674 16f628 18f252 18f242 18f442 18f452 12f629 12f675 16f88
syn keyword jalPredefined	16f876 16f873 sx_12 sx18 sx28 pic_12 pic_14 pic_16

syn keyword jalDirective chip osc clock  fuses  cpu watchdog powerup protection

syn keyword jalFunction		bank_0 bank_1 bank_2 bank_3 bank_4 bank_5 bank_6 bank_7 trisa trisb trisc trisd trise
syn keyword jalFunction		_trisa_flush _trisb_flush _trisc_flush _trisd_flush _trise_flush

syn keyword jalPIC		local idle_loop

syn region  jalAsm		matchgroup=jalAsmKey start="\<assembler\>" end="\<end assembler\>" contains=jalComment,jalPreProc,jalLabel,picIdentifier, picLabel,picASCII,picDecimal,picHexadecimal,picOctal,picComment,picString,picRegister,picRigisterPart,picOpcode,picDirective,jalPIC
syn region  jalAsm		matchgroup=jalAsmKey start="\<asm\>" end=/$/ contains=jalComment,jalPreProc,jalLabel,picIdentifier, picLabel,picASCII,picDecimal,picHexadecimal,picOctal,picComment,picString,picRegister,picRigisterPart,picOpcode,picDirective,jalPIC

syn region  jalPsudoVars matchgroup=jalPsudoVarsKey start="\<'put\>" end="/<is/>"  contains=jalComment

syn match  jalStringEscape	contained "#[12][0-9]\=[0-9]\="
syn match   jalIdentifier		"\<[a-zA-Z_][a-zA-Z0-9_]*\>"
syn match   jalSymbolOperator		"[+\-/*=]"
syn match   jalSymbolOperator		"!"
syn match   jalSymbolOperator		"<"
syn match   jalSymbolOperator		">"
syn match   jalSymbolOperator		"<="
syn match   jalSymbolOperator		">="
syn match   jalSymbolOperator		"!="
syn match   jalSymbolOperator		"=="
syn match   jalSymbolOperator		"<<"
syn match   jalSymbolOperator		">>"
syn match   jalSymbolOperator		"|"
syn match   jalSymbolOperator		"&"
syn match   jalSymbolOperator		"%"
syn match   jalSymbolOperator		"?"
syn match   jalSymbolOperator		"[()]"
syn match   jalSymbolOperator		"[\^.]"
syn match   jalLabel			"[\^]*:"

syn match  jalNumber		"-\=\<\d[0-9_]\+\>"
syn match  jalHexNumber		"0x[0-9A-Fa-f_]\+\>"
syn match  jalBinNumber		"0b[01_]\+\>"

" String
"wrong strings
syn region  jalStringError matchgroup=jalStringError start=+"+ end=+"+ end=+$+ contains=jalStringEscape

"right strings
syn region  jalString matchgroup=jalString start=+'+ end=+'+ oneline contains=jalStringEscape
" To see the start and end of strings:
syn region  jalString matchgroup=jalString start=+"+ end=+"+ oneline contains=jalStringEscapeGPC

syn keyword jalTodo contained	TODO
syn region jalComment		start=/-- /  end=/$/ oneline contains=jalTodo
syn region jalComment		start=/--\t/  end=/$/ oneline contains=jalTodo
syn match  jalComment		/--\_$/
syn region jalPreProc		start="include"  end=/$/ contains=JalComment,jalToDo


if exists("jal_no_tabs")
	syn match jalShowTab "\t"
endif


" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link jalAcces		jalStatement
hi def link jalBoolean		Boolean
hi def link jalBit			Boolean
hi def link jalComment		Comment
hi def link jalConditional		Conditional
hi def link jalConstant		Constant
hi def link jalDelimiter		Identifier
hi def link jalDirective		PreProc
hi def link jalException		Exception
hi def link jalFloat		Float
hi def link jalFunction		Function
hi def link jalPsudoVarsKey	Function
hi def link jalLabel		Label
hi def link jalMatrixDelimiter	Identifier
hi def link jalModifier		Type
hi def link jalNumber		Number
hi def link jalBinNumber		Number
hi def link jalHexNumber		Number
hi def link jalOperator		Operator
hi def link jalPredefined		Constant
hi def link jalPreProc		PreProc
hi def link jalRepeat		Repeat
hi def link jalStatement		Statement
hi def link jalString		String
hi def link jalStringEscape	Special
hi def link jalStringEscapeGPC	Special
hi def link jalStringError		Error
hi def link jalStruct		jalStatement
hi def link jalSymbolOperator	jalOperator
hi def link jalTodo		Todo
hi def link jalType		Type
hi def link jalUnclassified	Statement
hi def link jalAsm			Assembler
hi def link jalError		Error
hi def link jalAsmKey		Statement
hi def link jalPIC			Statement

hi def link jalShowTab		Error

hi def link picTodo		Todo
hi def link picComment		Comment
hi def link picDirective		Statement
hi def link picLabel		Label
hi def link picString		String

hi def link picOpcode		Keyword
hi def link picRegister		Structure
hi def link picRegisterPart	Special
hi def link picPinDir		SPecial
hi def link picPortDir		SPecial

hi def link picASCII		String
hi def link picBinary		Number
hi def link picDecimal		Number
hi def link picHexadecimal		Number
hi def link picOctal		Number

hi def link picIdentifier		Identifier



let b:current_syntax = "jal"

" vim: ts=8 sw=2
