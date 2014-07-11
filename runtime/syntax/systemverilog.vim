" Vim syntax file
" Language:    SystemVerilog
" Maintainer:  kocha <kocha.lsifrontend@gmail.com>
" Last Change: 12-Aug-2013. 

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
    syntax clear
elseif exists("b:current_syntax")
    finish
endif

" Read in Verilog syntax files
if version < 600
    so <sfile>:p:h/verilog.vim
else
    runtime! syntax/verilog.vim
    unlet b:current_syntax
endif

" IEEE1800-2005
syn keyword systemverilogStatement   always_comb always_ff always_latch
syn keyword systemverilogStatement   class endclass new
syn keyword systemverilogStatement   virtual local const protected
syn keyword systemverilogStatement   package endpackage
syn keyword systemverilogStatement   rand randc constraint randomize
syn keyword systemverilogStatement   with inside dist
syn keyword systemverilogStatement   sequence endsequence randsequence 
syn keyword systemverilogStatement   srandom
syn keyword systemverilogStatement   logic bit byte
syn keyword systemverilogStatement   int longint shortint
syn keyword systemverilogStatement   struct packed
syn keyword systemverilogStatement   final
syn keyword systemverilogStatement   import export
syn keyword systemverilogStatement   context pure 
syn keyword systemverilogStatement   void shortreal chandle string
syn keyword systemverilogStatement   clocking endclocking iff
syn keyword systemverilogStatement   interface endinterface modport
syn keyword systemverilogStatement   cover covergroup coverpoint endgroup
syn keyword systemverilogStatement   property endproperty
syn keyword systemverilogStatement   program endprogram
syn keyword systemverilogStatement   bins binsof illegal_bins ignore_bins
syn keyword systemverilogStatement   alias matches solve static assert
syn keyword systemverilogStatement   assume super before expect bind
syn keyword systemverilogStatement   extends null tagged extern this
syn keyword systemverilogStatement   first_match throughout timeprecision
syn keyword systemverilogStatement   timeunit type union 
syn keyword systemverilogStatement   uwire var cross ref wait_order intersect
syn keyword systemverilogStatement   wildcard within

syn keyword systemverilogTypeDef     typedef enum

syn keyword systemverilogConditional randcase
syn keyword systemverilogConditional unique priority

syn keyword systemverilogRepeat      return break continue
syn keyword systemverilogRepeat      do foreach

syn keyword systemverilogLabel       join_any join_none forkjoin

" IEEE1800-2009 add
syn keyword systemverilogStatement   checker endchecker
syn keyword systemverilogStatement   accept_on reject_on
syn keyword systemverilogStatement   sync_accept_on sync_reject_on
syn keyword systemverilogStatement   eventually nexttime until until_with
syn keyword systemverilogStatement   s_always s_eventually s_nexttime s_until s_until_with
syn keyword systemverilogStatement   let untyped
syn keyword systemverilogStatement   strong weak
syn keyword systemverilogStatement   restrict global implies

syn keyword systemverilogConditional unique0

" IEEE1800-2012 add
syn keyword systemverilogStatement   implements
syn keyword systemverilogStatement   interconnect soft nettype

" Define the default highlighting.
if version >= 508 || !exists("did_systemverilog_syn_inits")
   if version < 508
      let did_systemverilog_syn_inits = 1
      command -nargs=+ HiLink hi link <args>
   else
      command -nargs=+ HiLink hi def link <args>
   endif

   " The default highlighting.
   HiLink systemverilogStatement       Statement
   HiLink systemverilogTypeDef         TypeDef
   HiLink systemverilogConditional     Conditional
   HiLink systemverilogRepeat          Repeat
   HiLink systemverilogLabel           Label
   HiLink systemverilogGlobal          Define
   HiLink systemverilogNumber          Number

   delcommand HiLink
endif

let b:current_syntax = "systemverilog"

" vim: ts=8
