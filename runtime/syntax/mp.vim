" Vim syntax file
" Language:           MetaPost
" Maintainer:         Nicola Vitacolonna <nvitacolonna@gmail.com>
" Former Maintainers: Andreas Scherer <andreas.scherer@pobox.com>
" Last Change:        2016 Oct 14

if exists("b:current_syntax")
  finish
endif

let s:cpo_sav = &cpo
set cpo&vim

if exists("g:plain_mf_macros")
  let s:plain_mf_macros = g:plain_mf_macros
endif
if exists("g:plain_mf_modes")
  let s:plain_mf_modes = g:plain_mf_modes
endif
if exists("g:other_mf_macros")
  let s:other_mf_macros = g:other_mf_macros
endif

let g:plain_mf_macros = 0 " plain.mf has no special meaning for MetaPost
let g:plain_mf_modes  = 0 " No METAFONT modes
let g:other_mf_macros = 0 " cmbase.mf, logo.mf, ... neither

" Read the METAFONT syntax to start with
runtime! syntax/mf.vim
unlet b:current_syntax " Necessary for syn include below

" Restore the value of existing global variables
if exists("s:plain_mf_macros")
  let g:plain_mf_macros = s:plain_mf_macros
else
  unlet g:plain_mf_macros
endif
if exists("s:plain_mf_modes")
  let g:plain_mf_modes = s:plain_mf_modes
else
  unlet g:plain_mf_modes
endif
if exists("s:other_mf_macros")
  let g:other_mf_macros = s:other_mf_macros
else
  unlet g:other_mf_macros
endif

" Use TeX highlighting inside verbatimtex/btex... etex
syn include @MPTeX syntax/tex.vim
unlet b:current_syntax
" These are defined as keywords rather than using matchgroup
" in order to make them available to syntaxcomplete.
syn keyword mpTeXdelim       btex etex verbatimtex contained
syn region mpTeXinsert
      \ start=/\<verbatimtex\>\|\<btex\>/rs=e+1
      \ end=/\<etex\>/re=s-1 keepend
      \ contains=@MPTeX,mpTeXdelim

" iskeyword must be set after the syn include above, because tex.vim sets `syn
" iskeyword`. Note that keywords do not contain numbers (numbers are
" subscripts)
syntax iskeyword @,_

" MetaPost primitives not found in METAFONT
syn keyword mpBoolExp        bounded clipped filled stroked textual arclength
syn keyword mpNumExp         arctime blackpart bluepart colormodel cyanpart
syn keyword mpNumExp         fontsize greenpart greypart magentapart redpart
syn keyword mpPairExp        yellowpart llcorner lrcorner ulcorner urcorner
" envelope is seemingly undocumented, but it exists since mpost 1.003.
" The syntax is: envelope <polygonal pen> of <path primary>. For example,
"     path p;
"     p := envelope pensquare of (up--left);
" (Thanks to Daniel H. Luecking for the example!)
syn keyword mpPathExp        envelope pathpart
syn keyword mpPenExp         penpart
syn keyword mpPicExp         dashpart glyph infont
syn keyword mpStringExp      fontpart readfrom textpart
syn keyword mpType           cmykcolor color rgbcolor
" Other MetaPost primitives listed in the manual
syn keyword mpPrimitive      mpxbreak within
" Internal quantities not found in METAFONT
" (Table 6 in MetaPost: A User's Manual)
syn keyword mpInternal       defaultcolormodel hour minute linecap linejoin
syn keyword mpInternal       miterlimit mpprocset mpversion numberprecision
syn keyword mpInternal       numbersystem outputfilename outputformat
syn keyword mpInternal       outputformatoptions outputtemplate prologues
syn keyword mpInternal       restoreclipcolor tracinglostchars troffmode
syn keyword mpInternal       truecorners
" List of commands not found in METAFONT (from MetaPost: A User's Manual)
syn keyword mpCommand        clip closefrom dashed filenametemplate fontmapfile
syn keyword mpCommand        fontmapline setbounds withcmykcolor withcolor
syn keyword mpCommand        withgreyscale withoutcolor withpostscript
syn keyword mpCommand        withprescript withrgbcolor write
" METAFONT internal variables not found in MetaPost
syn keyword notDefined       autorounding chardx chardy fillin granularity
syn keyword notDefined       proofing smoothing tracingedges tracingpens
syn keyword notDefined       turningcheck xoffset yoffset
" Suffix defined only in METAFONT:
syn keyword notDefined       nodot
" Other not implemented primitives (see MetaPost: A User's Manual, §C.1)
syn keyword notDefined       cull display openwindow numspecial totalweight
syn keyword notDefined       withweight

" Keywords defined by plain.mp
if get(g:, "plain_mp_macros", 1) || get(g:, "mp_metafun_macros", 0)
  syn keyword mpDef          beginfig clear_pen_memory clearit clearpen clearpen
  syn keyword mpDef          clearxy colorpart cutdraw downto draw drawarrow
  syn keyword mpDef          drawdblarrow drawdot drawoptions endfig erase
  syn keyword mpDef          exitunless fill filldraw flex gobble hide interact
  syn keyword mpDef          label loggingall makelabel numtok penstroke pickup
  syn keyword mpDef          range reflectedabout rotatedaround shipit
  syn keyword mpDef          stop superellipse takepower tracingall tracingnone
  syn keyword mpDef          undraw undrawdot unfill unfilldraw upto
  syn match   mpDef          "???"
  syn keyword mpVardef       arrowhead bbox bot buildcycle byte ceiling center
  syn keyword mpVardef       counterclockwise decr dir direction directionpoint
  syn keyword mpVardef       dotlabel dotlabels image incr interpath inverse
  syn keyword mpVardef       labels lft magstep max min penlabels penpos round
  syn keyword mpVardef       rt savepen solve tensepath thelabel top unitvector
  syn keyword mpVardef       whatever z
  syn keyword mpPrimaryDef   div dotprod gobbled mod
  syn keyword mpSecondaryDef intersectionpoint
  syn keyword mpTertiaryDef  cutafter cutbefore softjoin thru
  syn keyword mpNewInternal  ahangle ahlength bboxmargin beveled butt defaultpen
  syn keyword mpNewInternal  defaultscale dotlabeldiam eps epsilon infinity
  syn keyword mpNewInternal  join_radius labeloffset mitered pen_bot pen_lft
  syn keyword mpNewInternal  pen_rt pen_top rounded squared tolerance
  " Predefined constants
  syn keyword mpConstant     EOF background base_name base_version black
  syn keyword mpConstant     blankpicture blue ditto down evenly fullcircle
  syn keyword mpConstant     green halfcircle identity left origin penrazor
  syn keyword mpConstant     penspeck pensquare quartercircle red right
  syn keyword mpConstant     unitsquare up white withdots
  " Other predefined variables
  syn keyword mpVariable     currentpen currentpen_path currentpicture cuttings
  syn keyword mpVariable     defaultfont extra_beginfig extra_endfig
  syn match   mpVariable     /\<\%(laboff\|labxf\|labyf\)\>/
  syn match   mpVariable     /\<\%(laboff\|labxf\|labyf\)\.\%(lft\|rt\|bot\|top\|ulft\|urt\|llft\|lrt\)\>/
  " let statements:
  syn keyword mpnumExp       abs
  syn keyword mpDef          rotatedabout
  syn keyword mpCommand      bye relax
  " on and off are not technically keywords, but it is nice to highlight them
  " inside dashpattern().
  syn keyword mpOnOff        off on contained
  syn keyword mpDash         dashpattern contained
  syn region  mpDashPattern
        \ start="dashpattern\s*"
        \ end=")"he=e-1
        \ contains=mfNumeric,mfLength,mpOnOff,mpDash
endif

" Keywords defined by mfplain.mp
if get(g:, "mfplain_mp_macros", 0)
  syn keyword mpDef          beginchar capsule_def change_width
  syn keyword mpDef          define_blacker_pixels define_corrected_pixels
  syn keyword mpDef          define_good_x_pixels define_good_y_pixels
  syn keyword mpDef          define_horizontal_corrected_pixels define_pixels
  syn keyword mpDef          define_whole_blacker_pixels define_whole_pixels
  syn keyword mpDef          define_whole_vertical_blacker_pixels
  syn keyword mpDef          define_whole_vertical_pixels endchar
  syn keyword mpDef          font_coding_scheme font_extra_space font_identifier
  syn keyword mpDef          font_normal_shrink font_normal_space
  syn keyword mpDef          font_normal_stretch font_quad font_size font_slant
  syn keyword mpDef          font_x_height italcorr labelfont lowres_fix makebox
  syn keyword mpDef          makegrid maketicks mode_def mode_setup proofrule
  syn keyword mpDef          smode
  syn keyword mpVardef       hround proofrulethickness vround
  syn keyword mpNewInternal  blacker o_correction
  syn keyword mpVariable     extra_beginchar extra_endchar extra_setup rulepen
  " plus some no-ops, also from mfplain.mp
  syn keyword mpDef          cull cullit gfcorners imagerules nodisplays
  syn keyword mpDef          notransforms openit proofoffset screenchars
  syn keyword mpDef          screenrule screenstrokes showit
  syn keyword mpVardef       grayfont slantfont titlefont
  syn keyword mpVariable     currenttransform
  syn keyword mpConstant     unitpixel
  " These are not listed in the MetaPost manual, and some are ignored by
  " MetaPost, but are nonetheless defined in mfplain.mp
  syn keyword mpDef          killtext
  syn match   mpVardef       "\<good\.\%(x\|y\|lft\|rt\|top\|bot\)\>"
  syn keyword mpVariable     aspect_ratio localfont mag mode mode_name
  syn keyword mpVariable     proofcolor
  syn keyword mpConstant     lowres proof smoke
  syn keyword mpNewInternal  autorounding bp_per_pixel granularity
  syn keyword mpNewInternal  number_of_modes proofing smoothing turningcheck
endif

" Keywords defined by all base macro packages:
" - (r)boxes.mp
" - format.mp
" - graph.mp
" - marith.mp
" - sarith.mp
" - string.mp
" - TEX.mp
if get(g:, "other_mp_macros", 1)
  " boxes and rboxes
  syn keyword mpDef          boxjoin drawboxed drawboxes drawunboxed
  syn keyword mpNewInternal  circmargin defaultdx defaultdy rbox_radius
  syn keyword mpVardef       boxit bpath circleit fixpos fixsize generic_declare
  syn keyword mpVardef       generic_redeclare generisize pic rboxit str_prefix
  " format
  syn keyword mpVardef       Mformat format init_numbers roundd
  syn keyword mpVariable     Fe_base Fe_plus
  syn keyword mpConstant     Ten_to
  " graph
  syn keyword mpDef          Gfor Gxyscale OUT auto begingraph endgraph gdata
  syn keyword mpDef          gdraw gdrawarrow gdrawdblarrow gfill plot
  syn keyword mpVardef       augment autogrid frame gdotlabel glabel grid itick
  syn keyword mpVardef       otick
  syn keyword mpVardef       Mreadpath setcoords setrange
  syn keyword mpNewInternal  Gmarks Gminlog Gpaths linear log
  syn keyword mpVariable     Autoform Gemarks Glmarks Gumarks
  syn keyword mpConstant     Gtemplate
  syn match   mpVariable     /Gmargin\.\%(low\|high\)/
  " marith
  syn keyword mpVardef       Mabs Meform Mexp Mexp_str Mlog Mlog_Str Mlog_str
  syn keyword mpPrimaryDef   Mdiv Mmul
  syn keyword mpSecondaryDef Madd Msub
  syn keyword mpTertiaryDef  Mleq
  syn keyword mpNewInternal  Mten Mzero
  " sarith
  syn keyword mpVardef       Sabs Scvnum
  syn keyword mpPrimaryDef   Sdiv Smul
  syn keyword mpSecondaryDef Sadd Ssub
  syn keyword mpTertiaryDef  Sleq Sneq
  " string
  syn keyword mpVardef       cspan isdigit loptok
  " TEX
  syn keyword mpVardef       TEX TEXPOST TEXPRE
endif

" Up to date as of 23-Sep-2016.
if get(b:, 'mp_metafun_macros', get(g:, 'mp_metafun_macros', 0))
  " Highlight TeX keywords (for use in ConTeXt documents)
  syn match   mpTeXKeyword  '\\[a-zA-Z@]\+'

  " These keywords have been added manually.
  syn keyword mpPrimitive runscript

  " The following MetaFun keywords have been extracted automatically from
  " ConTeXt source code. They include all "public" macros (where a macro is
  " considered public if and only if it does not start with _, mfun_, mlib_, or
  " do_, and it does not end with _), all "public" unsaved variables, and all
  " `let` statements.

  " mp-abck.mpiv
  syn keyword mpDef          abck_grid_line anchor_box box_found boxfilloptions
  syn keyword mpDef          boxgridoptions boxlineoptions draw_multi_pars
  syn keyword mpDef          draw_multi_side draw_multi_side_path freeze_box
  syn keyword mpDef          initialize_box initialize_box_pos
  syn keyword mpDef          multi_side_draw_options show_multi_kind
  syn keyword mpDef          show_multi_pars
  syn keyword mpVardef       abck_baseline_grid abck_draw_path abck_graphic_grid
  syn keyword mpVariable     boxdashtype boxfilloffset boxfilltype
  syn keyword mpVariable     boxgriddirection boxgriddistance boxgridshift
  syn keyword mpVariable     boxgridtype boxgridwidth boxlineoffset
  syn keyword mpVariable     boxlineradius boxlinetype boxlinewidth multikind
  syn keyword mpConstant     context_abck
  " mp-apos.mpiv
  syn keyword mpDef          anch_sidebars_draw boxfilloptions boxlineoptions
  syn keyword mpDef          connect_positions
  syn keyword mpConstant     context_apos
  " mp-asnc.mpiv
  syn keyword mpDef          FlushSyncTasks ProcessSyncTask ResetSyncTasks
  syn keyword mpDef          SetSyncColor SetSyncThreshold SyncTask
  syn keyword mpVardef       PrepareSyncTasks SyncBox TheSyncColor
  syn keyword mpVardef       TheSyncThreshold
  syn keyword mpVariable     CurrentSyncClass NOfSyncPaths SyncColor
  syn keyword mpVariable     SyncLeftOffset SyncPaths SyncTasks SyncThreshold
  syn keyword mpVariable     SyncThresholdMethod SyncWidth
  syn keyword mpConstant     context_asnc
  " mp-back.mpiv
  syn keyword mpDef          some_double_back some_hash
  syn keyword mpVariable     back_nillcolor
  syn keyword mpConstant     context_back
  " mp-bare.mpiv
  syn keyword mpVardef       colordecimals rawtextext
  syn keyword mpPrimaryDef   infont
  syn keyword mpConstant     context_bare
  " mp-base.mpiv
  " This is essentially plain.mp with only a few keywords added
  syn keyword mpNumExp       graypart
  syn keyword mpType         graycolor greycolor
  syn keyword mpConstant     cyan magenta yellow
  " mp-butt.mpiv
  syn keyword mpDef          predefinedbutton some_button
  syn keyword mpConstant     context_butt
  " mp-char.mpiv
  syn keyword mpDef          flow_begin_chart flow_begin_sub_chart
  syn keyword mpDef          flow_chart_draw_comment flow_chart_draw_exit
  syn keyword mpDef          flow_chart_draw_label flow_chart_draw_text
  syn keyword mpDef          flow_clip_chart flow_collapse_points
  syn keyword mpDef          flow_connect_bottom_bottom flow_connect_bottom_left
  syn keyword mpDef          flow_connect_bottom_right flow_connect_bottom_top
  syn keyword mpDef          flow_connect_left_bottom flow_connect_left_left
  syn keyword mpDef          flow_connect_left_right flow_connect_left_top
  syn keyword mpDef          flow_connect_right_bottom flow_connect_right_left
  syn keyword mpDef          flow_connect_right_right flow_connect_right_top
  syn keyword mpDef          flow_connect_top_bottom flow_connect_top_left
  syn keyword mpDef          flow_connect_top_right flow_connect_top_top
  syn keyword mpDef          flow_draw_connection flow_draw_connection_point
  syn keyword mpDef          flow_draw_midpoint flow_draw_shape
  syn keyword mpDef          flow_draw_test_area flow_draw_test_shape
  syn keyword mpDef          flow_draw_test_shapes flow_end_chart
  syn keyword mpDef          flow_end_sub_chart flow_flush_connections
  syn keyword mpDef          flow_flush_picture flow_flush_pictures
  syn keyword mpDef          flow_flush_shape flow_flush_shapes
  syn keyword mpDef          flow_initialize_grid flow_new_chart flow_new_shape
  syn keyword mpDef          flow_scaled_to_grid flow_show_connection
  syn keyword mpDef          flow_show_connections flow_show_shapes
  syn keyword mpDef          flow_xy_offset flow_y_pos
  syn keyword mpVardef       flow_connection_path flow_down_on_grid
  syn keyword mpVardef       flow_down_to_grid flow_i_point flow_left_on_grid
  syn keyword mpVardef       flow_left_to_grid flow_offset
  syn keyword mpVardef       flow_points_initialized flow_right_on_grid
  syn keyword mpVardef       flow_right_to_grid flow_smooth_connection
  syn keyword mpVardef       flow_trim_points flow_trimmed flow_up_on_grid
  syn keyword mpVardef       flow_up_to_grid flow_valid_connection
  syn keyword mpVardef       flow_x_on_grid flow_xy_bottom flow_xy_left
  syn keyword mpVardef       flow_xy_on_grid flow_xy_right flow_xy_top
  syn keyword mpVardef       flow_y_on_grid
  syn keyword mpVariable     flow_arrowtip flow_chart_background_color
  syn keyword mpVariable     flow_chart_offset flow_comment_offset
  syn keyword mpVariable     flow_connection_arrow_size
  syn keyword mpVariable     flow_connection_dash_size
  syn keyword mpVariable     flow_connection_line_color
  syn keyword mpVariable     flow_connection_line_width
  syn keyword mpVariable     flow_connection_smooth_size flow_connections
  syn keyword mpVariable     flow_cpath flow_dash_pattern flow_dashline
  syn keyword mpVariable     flow_exit_offset flow_forcevalid flow_grid_height
  syn keyword mpVariable     flow_grid_width flow_label_offset flow_max_x
  syn keyword mpVariable     flow_max_y flow_peepshape flow_reverse_connection
  syn keyword mpVariable     flow_reverse_y flow_shape_action flow_shape_archive
  syn keyword mpVariable     flow_shape_decision flow_shape_down
  syn keyword mpVariable     flow_shape_fill_color flow_shape_height
  syn keyword mpVariable     flow_shape_left flow_shape_line_color
  syn keyword mpVariable     flow_shape_line_width flow_shape_loop
  syn keyword mpVariable     flow_shape_multidocument flow_shape_node
  syn keyword mpVariable     flow_shape_procedure flow_shape_product
  syn keyword mpVariable     flow_shape_right flow_shape_singledocument
  syn keyword mpVariable     flow_shape_subprocedure flow_shape_up
  syn keyword mpVariable     flow_shape_wait flow_shape_width
  syn keyword mpVariable     flow_show_all_points flow_show_con_points
  syn keyword mpVariable     flow_show_mid_points flow_showcrossing flow_smooth
  syn keyword mpVariable     flow_touchshape flow_xypoint flow_zfactor
  syn keyword mpConstant     context_flow
  " mp-chem.mpiv
  syn keyword mpDef          chem_init_all chem_reset chem_start_structure
  syn keyword mpDef          chem_transformed
  syn keyword mpVardef       chem_ad chem_adj chem_align chem_arrow chem_au
  syn keyword mpVardef       chem_b chem_bb chem_bd chem_bw chem_c chem_cc
  syn keyword mpVardef       chem_ccd chem_cd chem_crz chem_cz chem_dash chem_db
  syn keyword mpVardef       chem_diff chem_dir chem_do chem_dr chem_draw
  syn keyword mpVardef       chem_drawarrow chem_eb chem_ed chem_ep chem_er
  syn keyword mpVardef       chem_es chem_et chem_fill chem_hb chem_init_some
  syn keyword mpVardef       chem_label chem_ldb chem_ldd chem_line chem_lr
  syn keyword mpVardef       chem_lrb chem_lrbd chem_lrd chem_lrh chem_lrn
  syn keyword mpVardef       chem_lrt chem_lrz chem_lsr chem_lsub chem_mark
  syn keyword mpVardef       chem_marked chem_mid chem_mids chem_midz chem_mir
  syn keyword mpVardef       chem_mov chem_move chem_number chem_oe chem_off
  syn keyword mpVardef       chem_pb chem_pe chem_r chem_r_fragment chem_rb
  syn keyword mpVardef       chem_rbd chem_rd chem_rdb chem_rdd chem_restore
  syn keyword mpVardef       chem_rh chem_rm chem_rn chem_rot chem_rr chem_rrb
  syn keyword mpVardef       chem_rrbd chem_rrd chem_rrh chem_rrn chem_rrt
  syn keyword mpVardef       chem_rrz chem_rsr chem_rsub chem_rt chem_rz chem_s
  syn keyword mpVardef       chem_save chem_sb chem_sd chem_set chem_sr chem_ss
  syn keyword mpVardef       chem_start_component chem_stop_component
  syn keyword mpVardef       chem_stop_structure chem_sub chem_symbol chem_tb
  syn keyword mpVardef       chem_text chem_z chem_zln chem_zlt chem_zn chem_zrn
  syn keyword mpVardef       chem_zrt chem_zt
  syn keyword mpVariable     chem_mark_pair chem_stack_mirror chem_stack_origin
  syn keyword mpVariable     chem_stack_p chem_stack_previous
  syn keyword mpVariable     chem_stack_rotation chem_trace_boundingbox
  syn keyword mpVariable     chem_trace_nesting chem_trace_text
  syn keyword mpConstant     context_chem
  " mp-core.mpiv
  syn keyword mpDef          FlushSyncTasks ProcessSyncTask
  syn keyword mpDef          RegisterLocalTextArea RegisterPlainTextArea
  syn keyword mpDef          RegisterRegionTextArea RegisterTextArea
  syn keyword mpDef          ResetLocalTextArea ResetSyncTasks ResetTextAreas
  syn keyword mpDef          SaveTextAreas SetSyncColor SetSyncThreshold
  syn keyword mpDef          SyncTask anchor_box box_found boxfilloptions
  syn keyword mpDef          boxgridoptions boxlineoptions collapse_multi_pars
  syn keyword mpDef          draw_box draw_multi_pars draw_par freeze_box
  syn keyword mpDef          initialize_area initialize_area_par initialize_box
  syn keyword mpDef          initialize_box_pos initialize_par
  syn keyword mpDef          prepare_multi_pars relocate_multipars save_multipar
  syn keyword mpDef          set_par_line_height show_multi_pars show_par
  syn keyword mpDef          simplify_multi_pars sort_multi_pars
  syn keyword mpVardef       InsideSavedTextArea InsideSomeSavedTextArea
  syn keyword mpVardef       InsideSomeTextArea InsideTextArea PrepareSyncTasks
  syn keyword mpVardef       SyncBox TextAreaH TextAreaW TextAreaWH TextAreaX
  syn keyword mpVardef       TextAreaXY TextAreaY TheSyncColor TheSyncThreshold
  syn keyword mpVardef       baseline_grid graphic_grid multi_par_at_top
  syn keyword mpVariable     CurrentSyncClass NOfSavedTextAreas
  syn keyword mpVariable     NOfSavedTextColumns NOfSyncPaths NOfTextAreas
  syn keyword mpVariable     NOfTextColumns PlainTextArea RegionTextArea
  syn keyword mpVariable     SavedTextColumns SyncColor SyncLeftOffset SyncPaths
  syn keyword mpVariable     SyncTasks SyncThreshold SyncThresholdMethod
  syn keyword mpVariable     SyncWidth TextAreas TextColumns
  syn keyword mpVariable     auto_multi_par_hsize boxdashtype boxfilloffset
  syn keyword mpVariable     boxfilltype boxgriddirection boxgriddistance
  syn keyword mpVariable     boxgridshift boxgridtype boxgridwidth boxlineradius
  syn keyword mpVariable     boxlinetype boxlinewidth check_multi_par_chain
  syn keyword mpVariable     compensate_multi_par_topskip
  syn keyword mpVariable     enable_multi_par_fallback force_multi_par_chain
  syn keyword mpVariable     ignore_multi_par_page last_multi_par_shift lefthang
  syn keyword mpVariable     local_multi_par_area multi_column_first_page_hack
  syn keyword mpVariable     multi_par_pages multiloc multilocs multipar
  syn keyword mpVariable     multipars multiref multirefs nofmultipars
  syn keyword mpVariable     obey_multi_par_hang obey_multi_par_more
  syn keyword mpVariable     one_piece_multi_par par_hang_after par_hang_indent
  syn keyword mpVariable     par_indent par_left_skip par_line_height
  syn keyword mpVariable     par_right_skip par_start_pos par_stop_pos
  syn keyword mpVariable     par_strut_depth par_strut_height ppos righthang
  syn keyword mpVariable     snap_multi_par_tops somehang span_multi_column_pars
  syn keyword mpVariable     use_multi_par_region
  syn keyword mpConstant     context_core
  syn keyword LET            anchor_area anchor_par draw_area
  " mp-cows.mpiv
  syn keyword mpConstant     context_cows cow
  " mp-crop.mpiv
  syn keyword mpDef          page_marks_add_color page_marks_add_lines
  syn keyword mpDef          page_marks_add_marking page_marks_add_number
  syn keyword mpVardef       crop_color crop_gray crop_marks_cmyk
  syn keyword mpVardef       crop_marks_cmykrgb crop_marks_gray crop_marks_lines
  syn keyword mpVariable     crop_colors more page
  syn keyword mpConstant     context_crop
  " mp-figs.mpiv
  syn keyword mpDef          naturalfigure registerfigure
  syn keyword mpVardef       figuredimensions figureheight figuresize
  syn keyword mpVardef       figurewidth
  syn keyword mpConstant     context_figs
  " mp-fobg.mpiv
  syn keyword mpDef          DrawFoFrame
  syn keyword mpVardef       equalpaths
  syn keyword mpPrimaryDef   inset outset
  syn keyword mpVariable     FoBackground FoBackgroundColor FoFrame FoLineColor
  syn keyword mpVariable     FoLineStyle FoLineWidth FoSplit
  syn keyword mpConstant     FoAll FoBottom FoDash FoDotted FoDouble FoGroove
  syn keyword mpConstant     FoHidden FoInset FoLeft FoMedium FoNoColor FoNone
  syn keyword mpConstant     FoOutset FoRidge FoRight FoSolid FoThick FoThin
  syn keyword mpConstant     FoTop context_fobg
  " mp-form.mpiv
  syn keyword mpConstant     context_form
  " mp-func.mpiv
  syn keyword mpDef          constructedfunction constructedpairs
  syn keyword mpDef          constructedpath curvedfunction curvedpairs
  syn keyword mpDef          curvedpath function pathconnectors straightfunction
  syn keyword mpDef          straightpairs straightpath
  syn keyword mpConstant     context_func
  " mp-grap.mpiv
  syn keyword mpDef          Gfor OUT auto begingraph circles crosses diamonds
  syn keyword mpDef          downtriangles endgraph gdata gdraw gdrawarrow
  syn keyword mpDef          gdrawdblarrow gfill graph_addto
  syn keyword mpDef          graph_addto_currentpicture graph_comma
  syn keyword mpDef          graph_coordinate_multiplication graph_draw
  syn keyword mpDef          graph_draw_label graph_errorbar_text graph_fill
  syn keyword mpDef          graph_generate_exponents
  syn keyword mpDef          graph_generate_label_position
  syn keyword mpDef          graph_generate_numbers graph_label_location
  syn keyword mpDef          graph_scan_mark graph_scan_marks graph_setbounds
  syn keyword mpDef          graph_suffix graph_tick_label
  syn keyword mpDef          graph_with_pen_and_color graph_withlist
  syn keyword mpDef          graph_xyscale lefttriangles makefunctionpath plot
  syn keyword mpDef          plotsymbol points rainbow righttriangles smoothpath
  syn keyword mpDef          squares stars uptriangles witherrorbars
  syn keyword mpVardef       addtopath augment autogrid constant_fit
  syn keyword mpVardef       constant_function det escaped_format exp
  syn keyword mpVardef       exponential_fit exponential_function format
  syn keyword mpVardef       formatted frame functionpath gaussian_fit
  syn keyword mpVardef       gaussian_function gdotlabel glabel graph_Feform
  syn keyword mpVardef       graph_Meform graph_arrowhead_extent graph_bounds
  syn keyword mpVardef       graph_clear_bounds
  syn keyword mpVardef       graph_convert_user_path_to_internal graph_cspan
  syn keyword mpVardef       graph_draw_arrowhead graph_error graph_errorbars
  syn keyword mpVardef       graph_exp graph_factor_and_exponent_to_string
  syn keyword mpVardef       graph_gridline_picture graph_is_null
  syn keyword mpVardef       graph_label_convert_user_to_internal graph_loptok
  syn keyword mpVardef       graph_match_exponents graph_mlog
  syn keyword mpVardef       graph_modified_exponent_ypart graph_pair_adjust
  syn keyword mpVardef       graph_picture_conversion graph_post_draw
  syn keyword mpVardef       graph_read_line graph_readpath graph_remap
  syn keyword mpVardef       graph_scan_path graph_select_exponent_mark
  syn keyword mpVardef       graph_select_mark graph_set_bounds
  syn keyword mpVardef       graph_set_default_bounds graph_shapesize
  syn keyword mpVardef       graph_stash_label graph_tick_mark_spacing
  syn keyword mpVardef       graph_unknown_pair_bbox grid isdigit itick
  syn keyword mpVardef       linear_fit linear_function ln logten lorentzian_fit
  syn keyword mpVardef       lorentzian_function otick polynomial_fit
  syn keyword mpVardef       polynomial_function power_law_fit
  syn keyword mpVardef       power_law_function powten setcoords setrange
  syn keyword mpVardef       sortpath strfmt tick varfmt
  syn keyword mpNewInternal  Mzero doubleinfinity graph_log_minimum
  syn keyword mpNewInternal  graph_minimum_number_of_marks largestmantissa
  syn keyword mpNewInternal  linear lntwo log mlogten singleinfinity
  syn keyword mpVariable     Autoform determinant fit_chi_squared
  syn keyword mpVariable     graph_errorbar_picture graph_exp_marks
  syn keyword mpVariable     graph_frame_pair_a graph_frame_pair_b
  syn keyword mpVariable     graph_lin_marks graph_log_marks graph_modified_bias
  syn keyword mpVariable     graph_modified_higher graph_modified_lower
  syn keyword mpVariable     graph_shape r_s resistance_color resistance_name
  syn keyword mpConstant     context_grap
  " mp-grid.mpiv
  syn keyword mpDef          hlingrid hloggrid vlingrid vloggrid
  syn keyword mpVardef       hlinlabel hlintext hlogtext linlin linlinpath
  syn keyword mpVardef       linlog linlogpath loglin loglinpath loglog
  syn keyword mpVardef       loglogpath processpath vlinlabel vlintext vlogtext
  syn keyword mpVariable     fmt_initialize fmt_pictures fmt_precision
  syn keyword mpVariable     fmt_separator fmt_zerocheck grid_eps
  syn keyword mpConstant     context_grid
  " mp-grph.mpiv
  syn keyword mpDef          beginfig begingraphictextfig data_mpo_file
  syn keyword mpDef          data_mpy_file doloadfigure draw endfig
  syn keyword mpDef          endgraphictextfig fill fixedplace graphictext
  syn keyword mpDef          loadfigure new_graphictext normalwithshade number
  syn keyword mpDef          old_graphictext outlinefill protectgraphicmacros
  syn keyword mpDef          resetfig reversefill withdrawcolor withfillcolor
  syn keyword mpDef          withshade
  syn keyword mpVariable     currentgraphictext figureshift
  syn keyword mpConstant     context_grph
  " mp-idea.mpiv
  syn keyword mpVardef       bcomponent ccomponent gcomponent mcomponent
  syn keyword mpVardef       rcomponent somecolor ycomponent
  " mp-luas.mpiv
  syn keyword mpDef          luacall message
  syn keyword mpVardef       MP lua lualist
  syn keyword mpConstant     context_luas
  " mp-mlib.mpiv
  syn keyword mpDef          autoalign bitmapimage circular_shade cmyk comment
  syn keyword mpDef          defineshade eofill eofillup externalfigure figure
  syn keyword mpDef          fillup label linear_shade multitonecolor namedcolor
  syn keyword mpDef          nofill onlayer passarrayvariable passvariable
  syn keyword mpDef          plain_label register resolvedcolor scantokens
  syn keyword mpDef          set_circular_vector set_linear_vector shaded
  syn keyword mpDef          spotcolor startpassingvariable stoppassingvariable
  syn keyword mpDef          thelabel transparent[] usemetafunlabels
  syn keyword mpDef          useplainlabels withcircularshade withlinearshade
  syn keyword mpDef          withmask withproperties withshadecenter
  syn keyword mpDef          withshadecolors withshadedirection withshadedomain
  syn keyword mpDef          withshadefactor withshadefraction withshadeorigin
  syn keyword mpDef          withshaderadius withshadestep withshadetransform
  syn keyword mpDef          withshadevector withtransparency
  syn keyword mpVardef       anchored checkbounds checkedbounds
  syn keyword mpVardef       define_circular_shade define_linear_shade dotlabel
  syn keyword mpVardef       escaped_format fmttext fontsize format formatted
  syn keyword mpVardef       installlabel onetimefmttext onetimetextext
  syn keyword mpVardef       outlinetext plain_thelabel properties rawfmttext
  syn keyword mpVardef       rawtexbox rawtextext rule strfmt strut texbox
  syn keyword mpVardef       textext thefmttext thelabel thetexbox thetextext
  syn keyword mpVardef       tostring transparency_alternative_to_number
  syn keyword mpVardef       validtexbox varfmt verbatim
  syn keyword mpPrimaryDef   asgroup infont normalinfont shadedinto
  syn keyword mpPrimaryDef   shownshadecenter shownshadedirection
  syn keyword mpPrimaryDef   shownshadeorigin shownshadevector withshade
  syn keyword mpPrimaryDef   withshademethod
  syn keyword mpNewInternal  colorburntransparent colordodgetransparent
  syn keyword mpNewInternal  colortransparent darkentransparent
  syn keyword mpNewInternal  differencetransparent exclusiontransparent
  syn keyword mpNewInternal  hardlighttransparent huetransparent
  syn keyword mpNewInternal  lightentransparent luminositytransparent
  syn keyword mpNewInternal  multiplytransparent normaltransparent
  syn keyword mpNewInternal  overlaytransparent saturationtransparent
  syn keyword mpNewInternal  screentransparent shadefactor softlighttransparent
  syn keyword mpNewInternal  textextoffset
  syn keyword mpType         property transparency
  syn keyword mpVariable     currentoutlinetext shadeddown shadedleft
  syn keyword mpVariable     shadedright shadedup shadeoffset trace_shades
  syn keyword mpConstant     context_mlib
  " mp-page.mpiv
  syn keyword mpDef          BoundCoverAreas BoundPageAreas Enlarged FakeRule
  syn keyword mpDef          FakeWord LoadPageState OverlayBox RuleColor
  syn keyword mpDef          SetAreaVariables SetPageArea SetPageBackPage
  syn keyword mpDef          SetPageCoverPage SetPageField SetPageFrontPage
  syn keyword mpDef          SetPageHsize SetPageHstep SetPageLocation
  syn keyword mpDef          SetPagePage SetPageSpine SetPageVariables
  syn keyword mpDef          SetPageVsize SetPageVstep StartCover StartPage
  syn keyword mpDef          StopCover StopPage SwapPageState innerenlarged
  syn keyword mpDef          llEnlarged lrEnlarged outerenlarged ulEnlarged
  syn keyword mpDef          urEnlarged
  syn keyword mpVardef       BackPageHeight BackPageWidth BackSpace BaseLineSkip
  syn keyword mpVardef       BodyFontSize BottomDistance BottomHeight
  syn keyword mpVardef       BottomSpace CoverHeight CoverWidth CurrentColumn
  syn keyword mpVardef       CurrentHeight CurrentWidth CutSpace EmWidth
  syn keyword mpVardef       ExHeight FooterDistance FooterHeight
  syn keyword mpVardef       FrontPageHeight FrontPageWidth HSize HeaderDistance
  syn keyword mpVardef       HeaderHeight InPageBody InnerEdgeDistance
  syn keyword mpVardef       InnerEdgeWidth InnerMarginDistance InnerMarginWidth
  syn keyword mpVardef       InnerSpaceWidth LastPageNumber LayoutColumnDistance
  syn keyword mpVardef       LayoutColumnWidth LayoutColumns LeftEdgeDistance
  syn keyword mpVardef       LeftEdgeWidth LeftMarginDistance LeftMarginWidth
  syn keyword mpVardef       LineHeight MakeupHeight MakeupWidth NOfColumns
  syn keyword mpVardef       NOfPages OnOddPage OnRightPage OuterEdgeDistance
  syn keyword mpVardef       OuterEdgeWidth OuterMarginDistance OuterMarginWidth
  syn keyword mpVardef       OuterSpaceWidth OverlayDepth OverlayHeight
  syn keyword mpVardef       OverlayLineWidth OverlayOffset OverlayWidth
  syn keyword mpVardef       PageDepth PageFraction PageNumber PageOffset
  syn keyword mpVardef       PaperBleed PaperHeight PaperWidth PrintPaperHeight
  syn keyword mpVardef       PrintPaperWidth RealPageNumber RightEdgeDistance
  syn keyword mpVardef       RightEdgeWidth RightMarginDistance RightMarginWidth
  syn keyword mpVardef       SpineHeight SpineWidth StrutDepth StrutHeight
  syn keyword mpVardef       TextHeight TextWidth TopDistance TopHeight TopSkip
  syn keyword mpVardef       TopSpace VSize defaultcolormodel
  syn keyword mpVariable     Area BackPage CoverPage CurrentLayout Field
  syn keyword mpVariable     FrontPage HorPos Hsize Hstep Location Page
  syn keyword mpVariable     PageStateAvailable RuleDepth RuleDirection
  syn keyword mpVariable     RuleFactor RuleH RuleHeight RuleOffset RuleOption
  syn keyword mpVariable     RuleThickness RuleV RuleWidth Spine VerPos Vsize
  syn keyword mpVariable     Vstep
  syn keyword mpConstant     context_page
  " mp-shap.mpiv
  syn keyword mpDef          drawline drawshape some_shape
  syn keyword mpDef          start_predefined_shape_definition
  syn keyword mpDef          stop_predefined_shape_definition
  syn keyword mpVardef       drawpredefinedline drawpredefinedshape
  syn keyword mpVardef       some_shape_path
  syn keyword mpVariable     predefined_shapes predefined_shapes_xradius
  syn keyword mpVariable     predefined_shapes_xxradius
  syn keyword mpVariable     predefined_shapes_yradius
  syn keyword mpVariable     predefined_shapes_yyradius
  syn keyword mpConstant     context_shap
  " mp-step.mpiv
  syn keyword mpDef          initialize_step_variables midbottomboundary
  syn keyword mpDef          midtopboundary step_begin_cell step_begin_chart
  syn keyword mpDef          step_cell_ali step_cell_bot step_cell_top
  syn keyword mpDef          step_cells step_end_cell step_end_chart
  syn keyword mpDef          step_text_bot step_text_mid step_text_top
  syn keyword mpDef          step_texts
  syn keyword mpVariable     cell_distance_x cell_distance_y cell_fill_color
  syn keyword mpVariable     cell_line_color cell_line_width cell_offset
  syn keyword mpVariable     chart_align chart_category chart_vertical
  syn keyword mpVariable     line_distance line_height line_line_color
  syn keyword mpVariable     line_line_width line_offset nofcells
  syn keyword mpVariable     text_distance_set text_fill_color text_line_color
  syn keyword mpVariable     text_line_width text_offset
  syn keyword mpConstant     context_cell
  " mp-symb.mpiv
  syn keyword mpDef          finishglyph prepareglyph
  syn keyword mpConstant     lefttriangle midbar onebar righttriangle sidebar
  syn keyword mpConstant     sublefttriangle subrighttriangle twobar
  " mp-text.mpiv
  syn keyword mpDef          build_parshape
  syn keyword mpVardef       found_point
  syn keyword mpVariable     trace_parshape
  syn keyword mpConstant     context_text
  " mp-tool.mpiv
  syn keyword mpCommand      dump
  syn keyword mpDef          addbackground b_color beginglyph break centerarrow
  syn keyword mpDef          clearxy condition data_mpd_file detaileddraw
  syn keyword mpDef          detailpaths dowithpath draw drawboundary
  syn keyword mpDef          drawboundingbox drawcontrollines drawcontrolpoints
  syn keyword mpDef          drawfill draworigin drawpath drawpathonly
  syn keyword mpDef          drawpathwithpoints drawpoint drawpointlabels
  syn keyword mpDef          drawpoints drawticks drawwholepath drawxticks
  syn keyword mpDef          drawyticks endglyph fill finishsavingdata g_color
  syn keyword mpDef          inner_boundingbox job_name leftarrow loadmodule
  syn keyword mpDef          midarrowhead naturalizepaths newboolean newcolor
  syn keyword mpDef          newnumeric newpair newpath newpicture newstring
  syn keyword mpDef          newtransform normalcolors normaldraw normalfill
  syn keyword mpDef          normalwithcolor outer_boundingbox pop_boundingbox
  syn keyword mpDef          popboundingbox popcurrentpicture push_boundingbox
  syn keyword mpDef          pushboundingbox pushcurrentpicture r_color readfile
  syn keyword mpDef          recolor redraw refill register_dirty_chars
  syn keyword mpDef          remapcolor remapcolors remappedcolor reprocess
  syn keyword mpDef          resetarrows resetcolormap resetdrawoptions
  syn keyword mpDef          resolvedcolor restroke retext rightarrow savedata
  syn keyword mpDef          saveoptions scale_currentpicture set_ahlength
  syn keyword mpDef          set_grid showgrid startplaincompatibility
  syn keyword mpDef          startsavingdata stopplaincompatibility
  syn keyword mpDef          stopsavingdata stripe_path_a stripe_path_n undashed
  syn keyword mpDef          undrawfill untext visualizeddraw visualizedfill
  syn keyword mpDef          visualizepaths withcolor withgray
  syn keyword mpDef          xscale_currentpicture xshifted
  syn keyword mpDef          xyscale_currentpicture yscale_currentpicture
  syn keyword mpDef          yshifted
  syn keyword mpVardef       acos acosh anglebetween area arrowhead
  syn keyword mpVardef       arrowheadonpath arrowpath asciistring asin asinh
  syn keyword mpVardef       atan basiccolors bbheight bbwidth bcomponent
  syn keyword mpVardef       blackcolor bottomboundary boundingbox c_phantom
  syn keyword mpVardef       ccomponent center cleanstring colorcircle
  syn keyword mpVardef       colordecimals colordecimalslist colorlike colorpart
  syn keyword mpVardef       colortype complementary complemented copylist cos
  syn keyword mpVardef       cosh cot cotd curved ddddecimal dddecimal ddecimal
  syn keyword mpVardef       decorated drawarrowpath epsed exp freedotlabel
  syn keyword mpVardef       freelabel gcomponent getunstringed grayed greyed
  syn keyword mpVardef       hsvtorgb infinite innerboundingbox interpolated inv
  syn keyword mpVardef       invcos inverted invsin invtan laddered leftboundary
  syn keyword mpVardef       leftpath leftrightpath listsize listtocurves
  syn keyword mpVardef       listtolines ln log mcomponent new_on_grid
  syn keyword mpVardef       outerboundingbox paired pen_size penpoint phantom
  syn keyword mpVardef       pointarrow pow punked rangepath rcomponent
  syn keyword mpVardef       redecorated repathed rightboundary rightpath
  syn keyword mpVardef       rotation roundedsquare set_inner_boundingbox
  syn keyword mpVardef       set_outer_boundingbox setunstringed shapedlist
  syn keyword mpVardef       simplified sin sinh sortlist sqr straightpath tan
  syn keyword mpVardef       tand tanh tensecircle thefreelabel topboundary
  syn keyword mpVardef       tripled undecorated unitvector unspiked unstringed
  syn keyword mpVardef       whitecolor ycomponent
  syn keyword mpPrimaryDef   along blownup bottomenlarged cornered crossed
  syn keyword mpPrimaryDef   enlarged enlonged leftenlarged llenlarged llmoved
  syn keyword mpPrimaryDef   lrenlarged lrmoved on paralleled randomized
  syn keyword mpPrimaryDef   randomizedcontrols randomshifted rightenlarged
  syn keyword mpPrimaryDef   shortened sized smoothed snapped softened squeezed
  syn keyword mpPrimaryDef   stretched superellipsed topenlarged ulenlarged
  syn keyword mpPrimaryDef   ulmoved uncolored urenlarged urmoved xsized
  syn keyword mpPrimaryDef   xstretched xyscaled xysized ysized ystretched zmod
  syn keyword mpSecondaryDef anglestriped intersection_point numberstriped
  syn keyword mpSecondaryDef peepholed
  syn keyword mpTertiaryDef  cutends
  syn keyword mpNewInternal  ahdimple ahvariant anglelength anglemethod
  syn keyword mpNewInternal  angleoffset charscale cmykcolormodel graycolormodel
  syn keyword mpNewInternal  greycolormodel maxdimensions metapostversion
  syn keyword mpNewInternal  nocolormodel rgbcolormodel striped_normal_inner
  syn keyword mpNewInternal  striped_normal_outer striped_reverse_inner
  syn keyword mpNewInternal  striped_reverse_outer
  syn keyword mpType         grayscale greyscale quadruplet triplet
  syn keyword mpVariable     ahfactor collapse_data color_map drawoptionsfactor
  syn keyword mpVariable     freedotlabelsize freelabeloffset grid grid_full
  syn keyword mpVariable     grid_h grid_left grid_nx grid_ny grid_w grid_x
  syn keyword mpVariable     grid_y intersection_found originlength
  syn keyword mpVariable     plain_compatibility_data pointlabelfont
  syn keyword mpVariable     pointlabelscale refillbackground savingdata
  syn keyword mpVariable     savingdatadone swappointlabels ticklength tickstep
  syn keyword mpConstant     CRLF DQUOTE PERCENT SPACE bcircle context_tool crlf
  syn keyword mpConstant     darkblue darkcyan darkgray darkgreen darkmagenta
  syn keyword mpConstant     darkred darkyellow downtriangle dquote freesquare
  syn keyword mpConstant     fulldiamond fullsquare fulltriangle lcircle
  syn keyword mpConstant     lefttriangle lightgray llcircle lltriangle lrcircle
  syn keyword mpConstant     lrtriangle mpversion nocolor noline oddly
  syn keyword mpConstant     originpath percent rcircle righttriangle space
  syn keyword mpConstant     tcircle triangle ulcircle ultriangle unitcircle
  syn keyword mpConstant     unitdiamond unittriangle uptriangle urcircle
  syn keyword mpConstant     urtriangle
endif " MetaFun macros

" Define the default highlighting
hi def link mpTeXdelim     mpPrimitive
hi def link mpBoolExp      mfBoolExp
hi def link mpNumExp       mfNumExp
hi def link mpPairExp      mfPairExp
hi def link mpPathExp      mfPathExp
hi def link mpPenExp       mfPenExp
hi def link mpPicExp       mfPicExp
hi def link mpStringExp    mfStringExp
hi def link mpInternal     mfInternal
hi def link mpCommand      mfCommand
hi def link mpType         mfType
hi def link mpPrimitive    mfPrimitive
hi def link mpDef          mfDef
hi def link mpVardef       mpDef
hi def link mpPrimaryDef   mpDef
hi def link mpSecondaryDef mpDef
hi def link mpTertiaryDef  mpDef
hi def link mpNewInternal  mpInternal
hi def link mpVariable     mfVariable
hi def link mpConstant     mfConstant
hi def link mpOnOff        mpPrimitive
hi def link mpDash         mpPrimitive
hi def link mpTeXKeyword   Identifier

let b:current_syntax = "mp"

let &cpo = s:cpo_sav
unlet! s:cpo_sav

" vim:sw=2
