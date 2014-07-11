" Vim syntax file
" Language:		SKILL for Diva
" Maintainer:	Toby Schaffer <jtschaff@eos.ncsu.edu>
" Last Change:	2001 May 09
" Comments:		SKILL is a Lisp-like programming language for use in EDA
"				tools from Cadence Design Systems. It allows you to have
"				a programming environment within the Cadence environment
"				that gives you access to the complete tool set and design
"				database. These items are for Diva verification rules decks.

" Don't remove any old syntax stuff hanging around! We need stuff
" from skill.vim.
if !exists("did_skill_syntax_inits")
  if version < 600
	so <sfile>:p:h/skill.vim
  else
    runtime! syntax/skill.vim
  endif
endif

syn keyword divaDRCKeywords		area enc notch ovlp sep width
syn keyword divaDRCKeywords		app diffNet length lengtha lengthb
syn keyword divaDRCKeywords		notParallel only_perp opposite parallel
syn keyword divaDRCKeywords		sameNet shielded with_perp
syn keyword divaDRCKeywords		edge edgea edgeb fig figa figb
syn keyword divaDRCKeywords		normalGrow squareGrow message raw
syn keyword divaMeasKeywords	perimeter length bends_all bends_full
syn keyword divaMeasKeywords	bends_part corners_all corners_full
syn keyword divaMeasKeywords	corners_part angles_all angles_full
syn keyword divaMeasKeywords	angles_part fig_count butting coincident
syn keyword divaMeasKeywords	over not_over outside inside enclosing
syn keyword divaMeasKeywords	figure one_net two_net three_net grounded
syn keyword divaMeasKeywords	polarized limit keep ignore
syn match divaCtrlFunctions		"(ivIf\>"hs=s+1
syn match divaCtrlFunctions		"\<ivIf("he=e-1
syn match divaCtrlFunctions		"(switch\>"hs=s+1
syn match divaCtrlFunctions		"\<switch("he=e-1
syn match divaCtrlFunctions		"(and\>"hs=s+1
syn match divaCtrlFunctions		"\<and("he=e-1
syn match divaCtrlFunctions		"(or\>"hs=s+1
syn match divaCtrlFunctions		"\<or("he=e-1
syn match divaCtrlFunctions		"(null\>"hs=s+1
syn match divaCtrlFunctions		"\<null("he=e-1
syn match divaExtFunctions		"(save\(Interconnect\|Property\|Parameter\|Recognition\)\>"hs=s+1
syn match divaExtFunctions		"\<save\(Interconnect\|Property\|Parameter\|Recognition\)("he=e-1
syn match divaExtFunctions		"(\(save\|measure\|attach\|multiLevel\|calculate\)Parasitic\>"hs=s+1
syn match divaExtFunctions		"\<\(save\|measure\|attach\|multiLevel\|calculate\)Parasitic("he=e-1
syn match divaExtFunctions		"(\(calculate\|measure\)Parameter\>"hs=s+1
syn match divaExtFunctions		"\<\(calculate\|measure\)Parameter("he=e-1
syn match divaExtFunctions		"(measure\(Resistance\|Fringe\)\>"hs=s+1
syn match divaExtFunctions		"\<measure\(Resistance\|Fringe\)("he=e-1
syn match divaExtFunctions		"(extract\(Device\|MOS\)\>"hs=s+1
syn match divaExtFunctions		"\<extract\(Device\|MOS\)("he=e-1
syn match divaDRCFunctions		"(checkAllLayers\>"hs=s+1
syn match divaDRCFunctions		"\<checkAllLayers("he=e-1
syn match divaDRCFunctions		"(checkLayer\>"hs=s+1
syn match divaDRCFunctions		"\<checkLayer("he=e-1
syn match divaDRCFunctions		"(drc\>"hs=s+1
syn match divaDRCFunctions		"\<drc("he=e-1
syn match divaDRCFunctions		"(drcAntenna\>"hs=s+1
syn match divaDRCFunctions		"\<drcAntenna("he=e-1
syn match divaFunctions			"(\(drcExtract\|lvs\)Rules\>"hs=s+1
syn match divaFunctions			"\<\(drcExtract\|lvs\)Rules("he=e-1
syn match divaLayerFunctions	"(saveDerived\>"hs=s+1
syn match divaLayerFunctions	"\<saveDerived("he=e-1
syn match divaLayerFunctions	"(copyGraphics\>"hs=s+1
syn match divaLayerFunctions	"\<copyGraphics("he=e-1
syn match divaChkFunctions		"(dubiousData\>"hs=s+1
syn match divaChkFunctions		"\<dubiousData("he=e-1
syn match divaChkFunctions		"(offGrid\>"hs=s+1
syn match divaChkFunctions		"\<offGrid("he=e-1
syn match divaLVSFunctions		"(compareDeviceProperty\>"hs=s+1
syn match divaLVSFunctions		"\<compareDeviceProperty("he=e-1
syn match divaLVSFunctions		"(ignoreTerminal\>"hs=s+1
syn match divaLVSFunctions		"\<ignoreTerminal("he=e-1
syn match divaLVSFunctions		"(parameterMatchType\>"hs=s+1
syn match divaLVSFunctions		"\<parameterMatchType("he=e-1
syn match divaLVSFunctions		"(\(permute\|prune\|remove\)Device\>"hs=s+1
syn match divaLVSFunctions		"\<\(permute\|prune\|remove\)Device("he=e-1
syn match divaGeomFunctions		"(geom\u\a\+\(45\|90\)\=\>"hs=s+1
syn match divaGeomFunctions		"\<geom\u\a\+\(45\|90\)\=("he=e-1

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_diva_syntax_inits")
	if version < 508
		let did_diva_syntax_inits = 1
		command -nargs=+ HiLink hi link <args>
	else
		command -nargs=+ HiLink hi def link <args>
	endif

	HiLink divaDRCKeywords		Statement
	HiLink divaMeasKeywords		Statement
	HiLink divaCtrlFunctions	Conditional
	HiLink divaExtFunctions		Function
	HiLink divaDRCFunctions		Function
	HiLink divaFunctions		Function
	HiLink divaLayerFunctions	Function
	HiLink divaChkFunctions		Function
	HiLink divaLVSFunctions		Function
	HiLink divaGeomFunctions	Function

	delcommand HiLink
endif

let b:current_syntax = "diva"

" vim:ts=4
