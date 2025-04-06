" Vim syntax file
" Language:     SDC - Synopsys Design Constraints
" Maintainer:   Maurizio Tranchero - maurizio.tranchero@gmail.com
" Credits:      based on TCL Vim syntax file
" Version:	0.3
" Last Change:  Thu Mar  25 17:35:16 CET 2009
" 2024 Jul 17 by Vim Project (update to SDC 2.1)

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" Read the TCL syntax to start with
runtime! syntax/tcl.vim

" TCL extension related to SDC and available from some vendors
" (not defined in SDC standard!)
syn keyword sdcCollections	foreach_in_collection
syn keyword sdcObjectsInfo	get_point_info get_node_info get_path_info
syn keyword sdcObjectsInfo	get_timing_paths set_attribute

" SDC rev. 2.1 specific keywords
syn keyword sdcObjectsQuery	get_clocks get_ports get_cells
syn keyword sdcObjectsQuery	get_pins get_nets all_inputs
syn keyword sdcObjectsQuery	all_outputs all_registers all_clocks
syn keyword sdcObjectsQuery	get_libs get_lib_cells get_lib_pins

syn keyword sdcConstraints	set_false_path set_clock_groups set_sense
syn keyword sdcConstraints	set_propagated_clock set_clock_gating_check
syn keyword sdcConstraints	set_ideal_latency set_ideal_network
syn keyword sdcConstraints	set_ideal_transistion set_max_time_borrow
syn keyword sdcConstraints	set_data_check group_path set_max_transition
syn keyword sdcConstraints	set_max_fanout set_driving_cell
syn keyword sdcConstraints	set_port_fanout_number set_multi_cycle_path
syn keyword sdcConstraints	set_disable_timing set_min_pulse_width

syn keyword sdcNonIdealities	set_min_delay set_max_delay
syn keyword sdcNonIdealities	set_input_delay set_output_delay
syn keyword sdcNonIdealities	set_load set_min_capacitance set_max_capacitance
syn keyword sdcNonIdealities	set_clock_latency set_clock_transition set_clock_uncertainty
syn keyword sdcNonIdealities	set_resistance set_timing_derate set_drive
syn keyword sdcNonIdealities	set_input_transition set_fanout_load

syn keyword sdcCreateOperations	create_clock create_timing_netlist update_timing_netlist
syn keyword sdcCreateOperations	create_generated_clock

syn keyword sdcPowerArea	set_max_area create_voltage_area
syn keyword sdcPowerArea	set_level_shifter_threshold set_max_dynamic_power
syn keyword sdcPowerArea	set_level_shifter_strategy set_max_leakage_power

syn keyword sdcModeConfig	set_case_analysis set_logic_dc
syn keyword sdcModeConfig	set_logic_zero set_logic_one

syn keyword sdcMiscCommmands	sdc_version set_wire_load_selection_group
syn keyword sdcMiscCommmands	set_units set_wire_load_mode set_wire_load_model
syn keyword sdcMiscCommmands	set_wire_load_min_block_size set_operating_conditions
syn keyword sdcMiscCommmands	current_design

" command flags highlighting
syn match sdcFlags		"[[:space:]]-[[:alpha:]_]*\>"

" Define the default highlighting.
hi def link sdcCollections      Repeat
hi def link sdcObjectsInfo      Operator
hi def link sdcCreateOperations	Operator
hi def link sdcObjectsQuery	Function
hi def link sdcConstraints	Operator
hi def link sdcNonIdealities	Operator
hi def link sdcPowerArea	Operator
hi def link sdcModeConfig	Operator
hi def link sdcMiscCommmands	Operator
hi def link sdcFlags		Special

let b:current_syntax = "sdc"

" vim: ts=8
