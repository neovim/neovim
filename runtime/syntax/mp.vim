" Vim syntax file
" Language:	MetaPost
" Maintainer:	Andreas Scherer <andreas.scherer@pobox.com>
" Last Change:	April 30, 2001

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syn clear
elseif exists("b:current_syntax")
  finish
endif

let plain_mf_macros = 0 " plain.mf has no special meaning for MetaPost
let other_mf_macros = 0 " cmbase.mf, logo.mf, ... neither

" Read the Metafont syntax to start with
if version < 600
  source <sfile>:p:h/mf.vim
else
  runtime! syntax/mf.vim
endif

" MetaPost has TeX inserts for typeset labels
" verbatimtex, btex, and etex will be treated as keywords
syn match mpTeXbegin "\(verbatimtex\|btex\)"
syn match mpTeXend "etex"
syn region mpTeXinsert start="\(verbatimtex\|btex\)"hs=e+1 end="etex"he=s-1 contains=mpTeXbegin,mpTeXend keepend

" MetaPost primitives not found in Metafont
syn keyword mpInternal bluepart clip color dashed fontsize greenpart infont
syn keyword mpInternal linecap linejoin llcorner lrcorner miterlimit mpxbreak
syn keyword mpInternal prologues redpart setbounds tracinglostchars
syn keyword mpInternal truecorners ulcorner urcorner withcolor

" Metafont primitives not found in MetaPost
syn keyword notDefined autorounding chardx chardy fillin granularity hppp
syn keyword notDefined proofing smoothing tracingedges tracingpens
syn keyword notDefined turningcheck vppp xoffset yoffset

" Keywords defined by plain.mp
if !exists("plain_mp_macros")
  let plain_mp_macros = 1 " Set this to '0' if your source gets too colourful
endif
if plain_mp_macros
  syn keyword mpMacro ahangle ahlength background bbox bboxmargin beginfig
  syn keyword mpMacro beveled black blue buildcycle butt center cutafter
  syn keyword mpMacro cutbefore cuttings dashpattern defaultfont defaultpen
  syn keyword mpMacro defaultscale dotlabel dotlabels drawarrow drawdblarrow
  syn keyword mpMacro drawoptions endfig evenly extra_beginfig extra_endfig
  syn keyword mpMacro green label labeloffset mitered red rounded squared
  syn keyword mpMacro thelabel white base_name base_version
  syn keyword mpMacro upto downto exitunless relax gobble gobbled
  syn keyword mpMacro interact loggingall tracingall tracingnone
  syn keyword mpMacro eps epsilon infinity right left up down origin
  syn keyword mpMacro quartercircle halfcircle fullcircle unitsquare identity
  syn keyword mpMacro blankpicture withdots ditto EOF pensquare penrazor
  syn keyword mpMacro penspeck whatever abs round ceiling byte dir unitvector
  syn keyword mpMacro inverse counterclockwise tensepath mod div dotprod
  syn keyword mpMacro takepower direction directionpoint intersectionpoint
  syn keyword mpMacro softjoin incr decr reflectedabout rotatedaround
  syn keyword mpMacro rotatedabout min max flex superellipse interpath
  syn keyword mpMacro magstep currentpen currentpen_path currentpicture
  syn keyword mpMacro fill draw filldraw drawdot unfill undraw unfilldraw
  syn keyword mpMacro undrawdot erase cutdraw image pickup numeric_pickup
  syn keyword mpMacro pen_lft pen_rt pen_top pen_bot savepen clearpen
  syn keyword mpMacro clear_pen_memory lft rt top bot ulft urt llft lrt
  syn keyword mpMacro penpos penstroke arrowhead makelabel labels penlabel
  syn keyword mpMacro range numtok thru clearxy clearit clearpen pickup
  syn keyword mpMacro shipit bye hide stop solve
endif

" Keywords defined by mfplain.mp
if !exists("mfplain_mp_macros")
  let mfplain_mp_macros = 0 " Set this to '1' to include these macro names
endif
if mfplain_mp_macros
  syn keyword mpMacro beginchar blacker capsule_def change_width
  syn keyword mpMacro define_blacker_pixels define_corrected_pixels
  syn keyword mpMacro define_good_x_pixels define_good_y_pixels
  syn keyword mpMacro define_horizontal_corrected_pixels
  syn keyword mpMacro define_pixels define_whole_blacker_pixels
  syn keyword mpMacro define_whole_vertical_blacker_pixels
  syn keyword mpMacro define_whole_vertical_pixels endchar
  syn keyword mpMacro extra_beginchar extra_endchar extra_setup
  syn keyword mpMacro font_coding_scheme font_extra_space font_identifier
  syn keyword mpMacro font_normal_shrink font_normal_space
  syn keyword mpMacro font_normal_stretch font_quad font_size
  syn keyword mpMacro font_slant font_x_height italcorr labelfont
  syn keyword mpMacro makebox makegrid maketicks mode_def mode_setup
  syn keyword mpMacro o_correction proofrule proofrulethickness rulepen smode

  " plus some no-ops, also from mfplain.mp
  syn keyword mpMacro cullit currenttransform gfcorners grayfont hround
  syn keyword mpMacro imagerules lowres_fix nodisplays notransforms openit
  syn keyword mpMacro proofoffset screenchars screenrule screenstrokes
  syn keyword mpMacro showit slantfont titlefont unitpixel vround
endif

" Keywords defined by other macro packages, e.g., boxes.mp
if !exists("other_mp_macros")
  let other_mp_macros = 1 " Set this to '0' if your source gets too colourful
endif
if other_mp_macros
  syn keyword mpMacro circmargin defaultdx defaultdy
  syn keyword mpMacro boxit boxjoin bpath circleit drawboxed drawboxes
  syn keyword mpMacro drawunboxed fixpos fixsize pic
endif

" Define the default highlighting
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_mp_syntax_inits")
  if version < 508
    let did_mp_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink mpTeXinsert	String
  HiLink mpTeXbegin	Statement
  HiLink mpTeXend	Statement
  HiLink mpInternal	mfInternal
  HiLink mpMacro	Macro

  delcommand HiLink
endif

let b:current_syntax = "mp"

" vim: ts=8
