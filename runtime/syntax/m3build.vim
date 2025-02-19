" Vim syntax file
" Language:	Modula-3 Makefile
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2021 April 15

if exists("b:current_syntax")
  finish
endif

runtime! syntax/m3quake.vim

" Identifiers
syn match m3buildPredefinedVariable "\<\%(TARGET\|OS_TYPE\|BUILD_DIR\|PKG_USE\|WDROOT\)\>"

" Build Procedures {{{1
" Generated from cm3/m3-sys/cm3/src/M3Build.m3
syn keyword m3buildProcedure HasCBackend

"    (* packages & locations *)
syn keyword m3buildProcedure Pkg
syn keyword m3buildProcedure override
syn keyword m3buildProcedure path_of
syn keyword m3buildProcedure pkg_subdir

"    (* names *)
syn keyword m3buildProcedure program_name
syn keyword m3buildProcedure library_name

"    (* calls in the generated .M3EXPORT files *)
syn keyword m3buildProcedure _define_lib
syn keyword m3buildProcedure _define_pgm
syn keyword m3buildProcedure _import_template
syn keyword m3buildProcedure _import_m3lib
syn keyword m3buildProcedure _import_otherlib
syn keyword m3buildProcedure _map_add_interface
syn keyword m3buildProcedure _map_add_generic_interface
syn keyword m3buildProcedure _map_add_module
syn keyword m3buildProcedure _map_add_generic_module
syn keyword m3buildProcedure _map_add_c
syn keyword m3buildProcedure _map_add_h
syn keyword m3buildProcedure _map_add_s

"    (* compiler options *)
syn keyword m3buildProcedure m3_debug
syn keyword m3buildProcedure m3_optimize
syn keyword m3buildProcedure build_shared
syn keyword m3buildProcedure build_standalone

"    (* derived files *)
syn keyword m3buildProcedure m3_compile_only
syn keyword m3buildProcedure m3_finish_up

"    (* predefined system libraries *)
syn keyword m3buildProcedure import_sys_lib

"    (* options *)
syn keyword m3buildProcedure m3_option
syn keyword m3buildProcedure remove_m3_option

"    (* deleting *)
syn keyword m3buildProcedure deriveds

"    (* imports *)
syn keyword m3buildProcedure include_dir
syn keyword m3buildProcedure include_pkg
syn keyword m3buildProcedure import
syn keyword m3buildProcedure import_version
syn keyword m3buildProcedure import_obj
syn keyword m3buildProcedure import_lib

"    (* objects *)
syn keyword m3buildProcedure pgm_object

"    (* sources *)
syn keyword m3buildProcedure source
syn keyword m3buildProcedure pgm_source
syn keyword m3buildProcedure interface
syn keyword m3buildProcedure Interface
syn keyword m3buildProcedure implementation
syn keyword m3buildProcedure module
syn keyword m3buildProcedure Module
syn keyword m3buildProcedure h_source
syn keyword m3buildProcedure c_source
syn keyword m3buildProcedure s_source
syn keyword m3buildProcedure ship_source

"    (* generics *)
syn keyword m3buildProcedure generic_interface
syn keyword m3buildProcedure Generic_interface
syn keyword m3buildProcedure generic_implementation
syn keyword m3buildProcedure Generic_implementation
syn keyword m3buildProcedure generic_module
syn keyword m3buildProcedure Generic_module
syn keyword m3buildProcedure build_generic_intf
syn keyword m3buildProcedure build_generic_impl

"    (* derived sources *)
syn keyword m3buildProcedure derived_interface
syn keyword m3buildProcedure derived_implementation
syn keyword m3buildProcedure derived_c
syn keyword m3buildProcedure derived_h

"    (* hiding/exporting *)
syn keyword m3buildProcedure hide_interface
syn keyword m3buildProcedure hide_generic_interface
syn keyword m3buildProcedure hide_generic_implementation
syn keyword m3buildProcedure export_interface
syn keyword m3buildProcedure export_generic_interface
syn keyword m3buildProcedure export_generic_implementation

"    (* templates *)
syn keyword m3buildProcedure template

"    (* library building *)
syn keyword m3buildProcedure library
syn keyword m3buildProcedure Library

"    (* program building *)
syn keyword m3buildProcedure program
syn keyword m3buildProcedure Program
syn keyword m3buildProcedure c_program
syn keyword m3buildProcedure C_program

"    (* man pages *)
syn keyword m3buildProcedure manPage
syn keyword m3buildProcedure ManPage

"    (* emacs *)
syn keyword m3buildProcedure Gnuemacs
syn keyword m3buildProcedure CompiledGnuemacs

"    (* "-find" support *)
syn keyword m3buildProcedure find_unit
syn keyword m3buildProcedure enum_units

"    (* export functions *)
syn keyword m3buildProcedure install_sources
syn keyword m3buildProcedure install_derived
syn keyword m3buildProcedure install_derived_link
syn keyword m3buildProcedure install_derived_symbolic_link
syn keyword m3buildProcedure install_derived_hard_link
syn keyword m3buildProcedure install_link_to_derived
syn keyword m3buildProcedure install_symbolic_link_to_derived
syn keyword m3buildProcedure install_hard_link_to_derived
syn keyword m3buildProcedure install_symbolic_link
syn keyword m3buildProcedure install_file

"    (* installation functions *)
syn keyword m3buildProcedure BindExport
syn keyword m3buildProcedure BinExport
syn keyword m3buildProcedure LibdExport
syn keyword m3buildProcedure LibExport
syn keyword m3buildProcedure EmacsdExport
syn keyword m3buildProcedure EmacsExport
syn keyword m3buildProcedure DocdExport
syn keyword m3buildProcedure DocExport
syn keyword m3buildProcedure MandExport
syn keyword m3buildProcedure ManExport
syn keyword m3buildProcedure HtmlExport
syn keyword m3buildProcedure RootExport
syn keyword m3buildProcedure RootdExport

"    (* misc *)
syn keyword m3buildProcedure gen_m3exports
syn keyword m3buildProcedure generate_tfile
syn keyword m3buildProcedure delete_file
syn keyword m3buildProcedure link_file
syn keyword m3buildProcedure symbolic_link_file
syn keyword m3buildProcedure hard_link_file
" }}}

hi def link m3buildPredefinedVariable Identifier
hi def link m3buildProcedure	      Function

let b:current_syntax = "m3build"

" vim: nowrap sw=2 sts=2 ts=8 noet fdm=marker:
