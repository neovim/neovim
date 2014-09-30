" Vim syntax file
" Language:	Hercules
" Maintainer:	Dana Edwards <Dana_Edwards@avanticorp.com>
" Extensions:   *.vc,*.ev,*.rs
" Last change:  Nov. 9, 2001
" Comment:      Hercules physical IC design verification software ensures
"		that an IC's physical design matches its logical design and
"		satisfies manufacturing rules.

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Ignore case
syn case ignore

" Hercules runset sections
syn keyword   herculesType	  header assign_property alias assign
syn keyword   herculesType	  options preprocess_options
syn keyword   herculesType	  explode_options technology_options
syn keyword   herculesType	  drc_options database_options
syn keyword   herculesType	  text_options lpe_options evaccess_options
syn keyword   herculesType	  check_point compare_group environment
syn keyword   herculesType	  grid_check include layer_stats load_group
syn keyword   herculesType	  restart run_only self_intersect set snap
syn keyword   herculesType	  system variable waiver

" Hercules commands
syn keyword   herculesStatement   attach_property boolean cell_extent
syn keyword   herculesStatement   common_hierarchy connection_points
syn keyword   herculesStatement   copy data_filter alternate delete
syn keyword   herculesStatement   explode explode_all fill_pattern find_net
syn keyword   herculesStatement   flatten
syn keyword   herculesStatement   level negate polygon_features push
syn keyword   herculesStatement   rectangles relocate remove_overlap reverse select
syn keyword   herculesStatement   select_cell select_contains select_edge select_net size
syn keyword   herculesStatement   text_polygon text_property vertex area cut
syn keyword   herculesStatement   density enclose external inside_edge
syn keyword   herculesStatement   internal notch vectorize center_to_center
syn keyword   herculesStatement   length mask_align moscheck rescheck
syn keyword   herculesStatement   analysis buildsub init_lpe_db capacitor
syn keyword   herculesStatement   device gendev nmos pmos diode npn pnp
syn keyword   herculesStatement   resistor set_param save_property
syn keyword   herculesStatement   connect disconnect text  text_boolean
syn keyword   herculesStatement   replace_text create_ports label graphics
syn keyword   herculesStatement   save_netlist_database lpe_stats netlist
syn keyword   herculesStatement   spice graphics_property graphics_netlist
syn keyword   herculesStatement   write_milkyway multi_rule_enclose
syn keyword   herculesStatement   if error_property equate compare
syn keyword   herculesStatement   antenna_fix c_thru dev_connect_check
syn keyword   herculesStatement   dev_net_count device_count net_filter
syn keyword   herculesStatement   net_path_check ratio process_text_opens

" Hercules keywords
syn keyword   herculesStatement   black_box_file block compare_dir equivalence
syn keyword   herculesStatement   format gdsin_dir group_dir group_dir_usage
syn keyword   herculesStatement   inlib layout_path outlib output_format
syn keyword   herculesStatement   output_layout_path schematic schematic_format
syn keyword   herculesStatement   scheme_file output_block else
syn keyword   herculesStatement   and or not xor andoverlap inside outside by to
syn keyword   herculesStatement   with connected connected_all texted_with texted
syn keyword   herculesStatement   by_property cutting edge_touch enclosing inside
syn keyword   herculesStatement   inside_hole interact touching vertex

" Hercules comments
syn region    herculesComment		start="/\*" skip="/\*" end="\*/" contains=herculesTodo
syn match     herculesComment		"//.*" contains=herculesTodo

" Preprocessor directives
syn match     herculesPreProc "^#.*"
syn match     herculesPreProc "^@.*"
syn match     herculesPreProc "macros"

" Hercules COMMENT option
syn match     herculesCmdCmnt "comment.*=.*"

" Spacings, Resolutions, Ranges, Ratios, etc.
syn match     herculesNumber	      "-\=\<[0-9]\+L\=\>\|0[xX][0-9]\+\>"

" Parenthesis sanity checker
syn region    herculesZone       matchgroup=Delimiter start="(" matchgroup=Delimiter end=")" transparent contains=ALLBUT,herculesError,herculesBraceError,herculesCurlyError
syn region    herculesZone       matchgroup=Delimiter start="{" matchgroup=Delimiter end="}" transparent contains=ALLBUT,herculesError,herculesBraceError,herculesParenError
syn region    herculesZone       matchgroup=Delimiter start="\[" matchgroup=Delimiter end="]" transparent contains=ALLBUT,herculesError,herculesCurlyError,herculesParenError
syn match     herculesError      "[)\]}]"
syn match     herculesBraceError "[)}]"  contained
syn match     herculesCurlyError "[)\]]" contained
syn match     herculesParenError "[\]}]" contained

" Hercules output format
"syn match  herculesOutput "([0-9].*)"
"syn match  herculesOutput "([0-9].*\;.*)"
syn match     herculesOutput "perm\s*=.*(.*)"
syn match     herculesOutput "temp\s*=\s*"
syn match     herculesOutput "error\s*=\s*(.*)"

"Modify the following as needed.  The trade-off is performance versus functionality.
syn sync      lines=100

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_hercules_syntax_inits")
  if version < 508
    let did_hercules_syntax_inits = 1
    " Default methods for highlighting.
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink herculesStatement  Statement
  HiLink herculesType       Type
  HiLink herculesComment    Comment
  HiLink herculesPreProc    PreProc
  HiLink herculesTodo       Todo
  HiLink herculesOutput     Include
  HiLink herculesCmdCmnt    Identifier
  HiLink herculesNumber     Number
  HiLink herculesBraceError herculesError
  HiLink herculesCurlyError herculesError
  HiLink herculesParenError herculesError
  HiLink herculesError      Error

  delcommand HiLink
endif

let b:current_syntax = "hercules"

" vim: ts=8
