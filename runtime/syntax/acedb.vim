" Vim syntax file
" Language:	AceDB model files
" Maintainer:	Stewart Morris (Stewart.Morris@ed.ac.uk)
" Last change:	Thu Apr 26 10:38:01 BST 2001
" URL:		http://www.ed.ac.uk/~swmorris/vim/acedb.vim

" Syntax file to handle all $ACEDB/wspec/*.wrm files, primarily models.wrm
" AceDB software is available from http://www.acedb.org

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn keyword	acedbXref	XREF
syn keyword	acedbModifier	UNIQUE REPEAT

syn case ignore
syn keyword	acedbModifier	Constraints
syn keyword	acedbType	DateType Int Text Float

" Magic tags from: http://genome.cornell.edu/acedocs/magic/summary.html
syn keyword	acedbMagic	pick_me_to_call No_cache Non_graphic Title
syn keyword	acedbMagic	Flipped Centre Extent View Default_view
syn keyword	acedbMagic	From_map Minimal_view Main_Marker Map Includes
syn keyword	acedbMagic	Mapping_data More_data Position Ends Left Right
syn keyword	acedbMagic	Multi_Position Multi_Ends With Error Relative
syn keyword	acedbMagic	Min Anchor Gmap Grid_map Grid Submenus Cambridge
syn keyword	acedbMagic	No_buttons Columns Colour Surround_colour Tag
syn keyword	acedbMagic	Scale_unit Cursor Cursor_on Cursor_unit
syn keyword	acedbMagic	Locator Magnification Projection_lines_on
syn keyword	acedbMagic	Marker_points Marker_intervals Contigs
syn keyword	acedbMagic	Physical_genes Two_point Multi_point Likelihood
syn keyword	acedbMagic	Point_query Point_yellow Point_width
syn keyword	acedbMagic	Point_pne Point_pe Point_nne Point_ne
syn keyword	acedbMagic	Derived_tags DT_query DT_width DT_no_duplicates
syn keyword	acedbMagic	RH_data RH_query RH_spacing RH_show_all
syn keyword	acedbMagic	Names_on Width Symbol Colours Pne Pe Nne pMap
syn keyword	acedbMagic	Sequence Gridded FingerPrint In_Situ Cosmid_grid
syn keyword	acedbMagic	Layout Lines_at Space_at No_stagger A1_labelling
syn keyword	acedbMagic	DNA Structure From Source Source_Exons
syn keyword	acedbMagic	Coding CDS Transcript Assembly_tags Allele
syn keyword	acedbMagic	Display Colour Frame_sensitive Strand_sensitive
syn keyword	acedbMagic	Score_bounds Percent Bumpable Width Symbol
syn keyword	acedbMagic	Blixem_N Address E_mail Paper Reference Title
syn keyword	acedbMagic	Point_1 Point_2 Calculation Full One_recombinant
syn keyword	acedbMagic	Tested Selected_trans Backcross Back_one
syn keyword	acedbMagic	Dom_semi Dom_let Direct Complex_mixed Calc
syn keyword	acedbMagic	Calc_upper_conf Item_1 Item_2 Results A_non_B
syn keyword	acedbMagic	Score Score_by_offset Score_by_width
syn keyword	acedbMagic	Right_priority Blastn Blixem Blixem_X
syn keyword	acedbMagic	Journal Year Volume Page Author
syn keyword	acedbMagic	Selected One_all Recs_all One_let
syn keyword	acedbMagic	Sex_full Sex_one Sex_cis Dom_one Dom_selected
syn keyword	acedbMagic	Calc_distance Calc_lower_conf Canon_for_cosmid
syn keyword	acedbMagic	Reversed_physical Points Positive Negative
syn keyword	acedbMagic	Point_error_scale Point_segregate_ordered
syn keyword	acedbMagic	Point_symbol Interval_JTM Interval_RD
syn keyword	acedbMagic	EMBL_feature Homol Feature
syn keyword	acedbMagic	DT_tag Spacer Spacer_colour Spacer_width
syn keyword	acedbMagic	RH_positive RH_negative RH_contradictory Query
syn keyword	acedbMagic	Clone Y_remark PCR_remark Hybridizes_to
syn keyword	acedbMagic	Row Virtual_row Mixed In_pool Subpool B_non_A
syn keyword	acedbMagic	Interval_SRK Point_show_marginal Subsequence
syn keyword	acedbMagic	Visible Properties Transposon

syn match	acedbClass	"^?\w\+\|^#\w\+"
syn match	acedbComment	"//.*"
syn region	acedbComment	start="/\*" end="\*/"
syn match	acedbComment	"^#\W.*"
syn match	acedbHelp	"^\*\*\w\+$"
syn match	acedbTag	"[^^]?\w\+\|[^^]#\w\+"
syn match	acedbBlock	"//#.\+#$"
syn match	acedbOption	"^_[DVH]\S\+"
syn match	acedbFlag	"\s\+-\h\+"
syn match	acedbSubclass	"^Class"
syn match	acedbSubtag	"^Visible\|^Is_a_subclass_of\|^Filter\|^Hidden"
syn match	acedbNumber	"\<\d\+\>"
syn match	acedbNumber	"\<\d\+\.\d\+\>"
syn match	acedbHyb	"\<Positive_\w\+\>\|\<Negative\w\+\>"
syn region	acedbString	start=/"/ end=/"/ skip=/\\"/ oneline

" Rest of syntax highlighting rules start here

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link acedbMagic	Special
hi def link acedbHyb	Special
hi def link acedbType	Type
hi def link acedbOption	Type
hi def link acedbSubclass	Type
hi def link acedbSubtag	Include
hi def link acedbFlag	Include
hi def link acedbTag	Include
hi def link acedbClass	Todo
hi def link acedbHelp	Todo
hi def link acedbXref	Identifier
hi def link acedbModifier	Label
hi def link acedbComment	Comment
hi def link acedbBlock	ModeMsg
hi def link acedbNumber	Number
hi def link acedbString	String


let b:current_syntax = "acedb"

" The structure of the model.wrm file is sensitive to mixed tab and space
" indentation and assumes tabs are 8 so...
se ts=8
