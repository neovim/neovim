" Vim syntax file
" Language:    Verilog-AMS
" Maintainer:  S. Myles Prather <smprather@gmail.com>
"
" Version 1.1  S. Myles Prather <smprather@gmail.com>
"              Moved some keywords to the type category.
"              Added the metrix suffixes to the number matcher.
" Version 1.2  Prasanna Tamhankar <pratam@gmail.com>
"              Minor reserved keyword updates.
" Last Update: Thursday September 15 15:36:03 CST 2005 

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
   syntax clear
elseif exists("b:current_syntax")
   finish
endif

" Set the local value of the 'iskeyword' option
if version >= 600
   setlocal iskeyword=@,48-57,_,192-255
else
   set iskeyword=@,48-57,_,192-255
endif

" Annex B.1 'All keywords'
syn keyword verilogamsStatement above abs absdelay acos acosh ac_stim
syn keyword verilogamsStatement always analog analysis and asin
syn keyword verilogamsStatement asinh assign atan atan2 atanh
syn keyword verilogamsStatement buf bufif0 bufif1 ceil cmos connectmodule
syn keyword verilogamsStatement connectrules cos cosh cross ddt ddx deassign
syn keyword verilogamsStatement defparam disable discipline
syn keyword verilogamsStatement driver_update edge enddiscipline
syn keyword verilogamsStatement endconnectrules endmodule endfunction endgenerate
syn keyword verilogamsStatement endnature endparamset endprimitive endspecify
syn keyword verilogamsStatement endtable endtask event exp final_step
syn keyword verilogamsStatement flicker_noise floor flow force fork
syn keyword verilogamsStatement function generate highz0
syn keyword verilogamsStatement highz1 hypot idt idtmod if ifnone inf initial
syn keyword verilogamsStatement initial_step inout input join
syn keyword verilogamsStatement laplace_nd laplace_np laplace_zd laplace_zp
syn keyword verilogamsStatement large last_crossing limexp ln localparam log
syn keyword verilogamsStatement macromodule max medium min module nand nature
syn keyword verilogamsStatement negedge net_resolution nmos noise_table nor not
syn keyword verilogamsStatement notif0 notif1 or output paramset pmos
syn keyword verilogamsType      parameter real integer electrical input output
syn keyword verilogamsType      inout reg tri tri0 tri1 triand trior trireg
syn keyword verilogamsType      string from exclude aliasparam ground genvar
syn keyword verilogamsType      branch time realtime
syn keyword verilogamsStatement posedge potential pow primitive pull0 pull1
syn keyword verilogamsStatement pullup pulldown rcmos release
syn keyword verilogamsStatement rnmos rpmos rtran rtranif0 rtranif1
syn keyword verilogamsStatement scalared sin sinh slew small specify specparam
syn keyword verilogamsStatement sqrt strong0 strong1 supply0 supply1
syn keyword verilogamsStatement table tan tanh task timer tran tranif0
syn keyword verilogamsStatement tranif1 transition
syn keyword verilogamsStatement vectored wait wand weak0 weak1
syn keyword verilogamsStatement white_noise wire wor wreal xnor xor zi_nd
syn keyword verilogamsStatement zi_np zi_zd zi_zp
syn keyword verilogamsRepeat    forever repeat while for
syn keyword verilogamsLabel     begin end
syn keyword verilogamsConditional if else case casex casez default endcase
syn match   verilogamsConstant  ":inf"lc=1
syn match   verilogamsConstant  "-inf"lc=1
" Annex B.2 Discipline/nature
syn keyword verilogamsStatement abstol access continuous ddt_nature discrete
syn keyword verilogamsStatement domain idt_nature units 
" Annex B.3 Connect Rules
syn keyword verilogamsStatement connect merged resolveto split

syn match   verilogamsOperator  "[&|~><!)(*#%@+/=?:;}{,.\^\-\[\]]"
syn match   verilogamsOperator  "<+"
syn match   verilogamsStatement "[vV]("me=e-1
syn match   verilogamsStatement "[iI]("me=e-1

syn keyword verilogamsTodo contained TODO
syn region  verilogamsComment start="/\*" end="\*/" contains=verilogamsTodo
syn match   verilogamsComment "//.*" contains=verilogamsTodo

syn match verilogamsGlobal "`celldefine"
syn match verilogamsGlobal "`default_nettype"
syn match verilogamsGlobal "`define"
syn match verilogamsGlobal "`else"
syn match verilogamsGlobal "`elsif"
syn match verilogamsGlobal "`endcelldefine"
syn match verilogamsGlobal "`endif"
syn match verilogamsGlobal "`ifdef"
syn match verilogamsGlobal "`ifndef"
syn match verilogamsGlobal "`include"
syn match verilogamsGlobal "`line"
syn match verilogamsGlobal "`nounconnected_drive"
syn match verilogamsGlobal "`resetall"
syn match verilogamsGlobal "`timescale"
syn match verilogamsGlobal "`unconnected_drive"
syn match verilogamsGlobal "`undef"
syn match verilogamsSystask "$[a-zA-Z0-9_]\+\>"

syn match verilogamsConstant "\<[A-Z][A-Z0-9_]\+\>"

syn match   verilogamsNumber "\(\<\d\+\|\)'[bB]\s*[0-1_xXzZ?]\+\>"
syn match   verilogamsNumber "\(\<\d\+\|\)'[oO]\s*[0-7_xXzZ?]\+\>"
syn match   verilogamsNumber "\(\<\d\+\|\)'[dD]\s*[0-9_xXzZ?]\+\>"
syn match   verilogamsNumber "\(\<\d\+\|\)'[hH]\s*[0-9a-fA-F_xXzZ?]\+\>"
syn match   verilogamsNumber "\<[+-]\=[0-9_]\+\(\.[0-9_]*\|\)\(e[0-9_]*\|\)[TGMKkmunpfa]\=\>"

syn region  verilogamsString start=+"+ skip=+\\"+ end=+"+ contains=verilogamsEscape
syn match   verilogamsEscape +\\[nt"\\]+ contained
syn match   verilogamsEscape "\\\o\o\=\o\=" contained

"Modify the following as needed.  The trade-off is performance versus
"functionality.
syn sync lines=50

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_verilogams_syn_inits")
   if version < 508
      let did_verilogams_syn_inits = 1
      command -nargs=+ HiLink hi link <args>
   else
      command -nargs=+ HiLink hi def link <args>
   endif

   " The default highlighting.
   HiLink verilogamsCharacter    Character
   HiLink verilogamsConditional  Conditional
   HiLink verilogamsRepeat       Repeat
   HiLink verilogamsString       String
   HiLink verilogamsTodo         Todo
   HiLink verilogamsComment      Comment
   HiLink verilogamsConstant     Constant
   HiLink verilogamsLabel        Label
   HiLink verilogamsNumber       Number
   HiLink verilogamsOperator     Special
   HiLink verilogamsStatement    Statement
   HiLink verilogamsGlobal       Define
   HiLink verilogamsDirective    SpecialComment
   HiLink verilogamsEscape       Special
   HiLink verilogamsType         Type
   HiLink verilogamsSystask      Function

   delcommand HiLink
endif

let b:current_syntax = "verilogams"

" vim: ts=8
