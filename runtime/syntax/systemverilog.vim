" Vim syntax file
" Language:    SystemVerilog
" Maintainer:  kocha <kocha.lsifrontend@gmail.com>
" Last Change: 12-Aug-2013. 

" quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

" Read in Verilog syntax files
runtime! syntax/verilog.vim
unlet b:current_syntax

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

" The default highlighting.
hi def link systemverilogStatement       Statement
hi def link systemverilogTypeDef         TypeDef
hi def link systemverilogConditional     Conditional
hi def link systemverilogRepeat          Repeat
hi def link systemverilogLabel           Label
hi def link systemverilogGlobal          Define
hi def link systemverilogNumber          Number


let b:current_syntax = "systemverilog"

" vim: ts=8
