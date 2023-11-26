" Vim syntax file
" Language:     SDC - Synopsys Design Constraints
" Maintainer:   Maurizio Tranchero - maurizio.tranchero@gmail.com
" Last Change:  Thu Mar  25 17:35:16 CET 2009
" Credits:      based on TCL Vim syntax file
" Version:	0.3

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read the TCL syntax to start with
runtime! syntax/tcl.vim

" SDC-specific keywords
syn keyword sdcCollections	foreach_in_collection
syn keyword sdcObjectsQuery	get_clocks get_ports
syn keyword sdcObjectsInfo	get_point_info get_node_info get_path_info
syn keyword sdcObjectsInfo	get_timing_paths set_attribute
syn keyword sdcConstraints	set_false_path
syn keyword sdcNonIdealities	set_min_delay set_max_delay
syn keyword sdcNonIdealities	set_input_delay set_output_delay
syn keyword sdcNonIdealities	set_load set_min_capacitance set_max_capacitance
syn keyword sdcCreateOperations	create_clock create_timing_netlist update_timing_netlist

" command flags highlighting
syn match sdcFlags		"[[:space:]]-[[:alpha:]_]*\>"

" Define the default highlighting.
hi def link sdcCollections      Repeat
hi def link sdcObjectsInfo      Operator
hi def link sdcCreateOperations	Operator
hi def link sdcObjectsQuery	Operator
hi def link sdcConstraints	Operator
hi def link sdcNonIdealities	Operator
hi def link sdcFlags		Special

let b:current_syntax = "sdc"

" vim: ts=8
