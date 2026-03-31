" Vim syntax file
" Language:     Speedup, plant simulator from AspenTech
" Maintainer:   Stefan.Schwarzer <s.schwarzer@ndh.net>
" URL:		http://www.ndh.net/home/sschwarzer/download/spup.vim
" Last Change:  2012 Feb 03 by Thilo Six
" Filename:     spup.vim

" Bugs
" - in the appropriate sections keywords are always highlighted
"   even if they are not used with the appropriate meaning;
"   example: in
"       MODEL demonstration
"       TYPE
"      *area AS area
"   both "area" are highlighted as spupType.
"
" If you encounter problems or have questions or suggestions, mail me

" Remove old syntax stuff
" quit when a syntax file was already loaded
if exists("b:current_syntax")
    finish
endif

let s:cpo_save = &cpo
set cpo&vim

" don't highlight several keywords like subsections
"let strict_subsections = 1

" highlight types usually found in DECLARE section
if !exists("highlight_types")
    let highlight_types = 1
endif

" one line comment syntax (# comments)
" 1. allow appended code after comment, do not complain
" 2. show code beginning with the second # as an error
" 3. show whole lines with more than one # as an error
if !exists("oneline_comments")
    let oneline_comments = 2
endif

" Speedup SECTION regions
syn case ignore
syn region spupCdi	  matchgroup=spupSection start="^CDI"	     end="^\*\*\*\*" contains=spupCdiSubs,@spupOrdinary
syn region spupConditions matchgroup=spupSection start="^CONDITIONS" end="^\*\*\*\*" contains=spupConditionsSubs,@spupOrdinary,spupConditional,spupOperator,spupCode
syn region spupDeclare    matchgroup=spupSection start="^DECLARE"    end="^\*\*\*\*" contains=spupDeclareSubs,@spupOrdinary,spupTypes,spupCode
syn region spupEstimation matchgroup=spupSection start="^ESTIMATION" end="^\*\*\*\*" contains=spupEstimationSubs,@spupOrdinary
syn region spupExternal   matchgroup=spupSection start="^EXTERNAL"   end="^\*\*\*\*" contains=spupExternalSubs,@spupOrdinary
syn region spupFlowsheet  matchgroup=spupSection start="^FLOWSHEET"  end="^\*\*\*\*" contains=spupFlowsheetSubs,@spupOrdinary,spupStreams,@spupTextproc
syn region spupFunction   matchgroup=spupSection start="^FUNCTION"   end="^\*\*\*\*" contains=spupFunctionSubs,@spupOrdinary,spupHelp,spupCode,spupTypes
syn region spupGlobal     matchgroup=spupSection start="^GLOBAL"     end="^\*\*\*\*" contains=spupGlobalSubs,@spupOrdinary
syn region spupHomotopy   matchgroup=spupSection start="^HOMOTOPY"   end="^\*\*\*\*" contains=spupHomotopySubs,@spupOrdinary
syn region spupMacro      matchgroup=spupSection start="^MACRO"      end="^\*\*\*\*" contains=spupMacroSubs,@spupOrdinary,@spupTextproc,spupTypes,spupStreams,spupOperator
syn region spupModel      matchgroup=spupSection start="^MODEL"      end="^\*\*\*\*" contains=spupModelSubs,@spupOrdinary,spupConditional,spupOperator,spupTypes,spupStreams,@spupTextproc,spupHelp
syn region spupOperation  matchgroup=spupSection start="^OPERATION"  end="^\*\*\*\*" contains=spupOperationSubs,@spupOrdinary,@spupTextproc
syn region spupOptions    matchgroup=spupSection start="^OPTIONS"    end="^\*\*\*\*" contains=spupOptionsSubs,@spupOrdinary
syn region spupProcedure  matchgroup=spupSection start="^PROCEDURE"  end="^\*\*\*\*" contains=spupProcedureSubs,@spupOrdinary,spupHelp,spupCode,spupTypes
syn region spupProfiles   matchgroup=spupSection start="^PROFILES"   end="^\*\*\*\*" contains=@spupOrdinary,@spupTextproc
syn region spupReport     matchgroup=spupSection start="^REPORT"     end="^\*\*\*\*" contains=spupReportSubs,@spupOrdinary,spupHelp,@spupTextproc
syn region spupTitle      matchgroup=spupSection start="^TITLE"      end="^\*\*\*\*" contains=spupTitleSubs,spupComment,spupConstant,spupError
syn region spupUnit       matchgroup=spupSection start="^UNIT"       end="^\*\*\*\*" contains=spupUnitSubs,@spupOrdinary

" Subsections
syn keyword spupCdiSubs	       INPUT FREE OUTPUT LINEARTIME MINNONZERO CALCULATE FILES SCALING contained
syn keyword spupDeclareSubs    TYPE STREAM contained
syn keyword spupEstimationSubs ESTIMATE SSEXP DYNEXP RESULT contained
syn keyword spupExternalSubs   TRANSMIT RECEIVE contained
syn keyword spupFlowsheetSubs  STREAM contained
syn keyword spupFunctionSubs   INPUT OUTPUT contained
syn keyword spupGlobalSubs     VARIABLES MAXIMIZE MINIMIZE CONSTRAINT contained
syn keyword spupHomotopySubs   VARY OPTIONS contained
syn keyword spupMacroSubs      MODEL FLOWSHEET contained
syn keyword spupModelSubs      CATEGORY SET TYPE STREAM EQUATION PROCEDURE contained
syn keyword spupOperationSubs  SET PRESET INITIAL SSTATE FREE contained
syn keyword spupOptionsSubs    ROUTINES TRANSLATE EXECUTION contained
syn keyword spupProcedureSubs  INPUT OUTPUT SPACE PRECALL POSTCALL DERIVATIVE STREAM contained
" no subsections for Profiles
syn keyword spupReportSubs     SET INITIAL FIELDS FIELDMARK DISPLAY WITHIN contained
syn keyword spupUnitSubs       ROUTINES SET contained

" additional keywords for subsections
if !exists( "strict_subsections" )
    syn keyword spupConditionsSubs STOP PRINT contained
    syn keyword spupDeclareSubs    UNIT SET COMPONENTS THERMO OPTIONS contained
    syn keyword spupEstimationSubs VARY MEASURE INITIAL contained
    syn keyword spupFlowsheetSubs  TYPE FEED PRODUCT INPUT OUTPUT CONNECTION OF IS contained
    syn keyword spupMacroSubs      CONNECTION STREAM SET INPUT OUTPUT OF IS FEED PRODUCT TYPE contained
    syn keyword spupModelSubs      AS ARRAY OF INPUT OUTPUT CONNECTION contained
    syn keyword spupOperationSubs  WITHIN contained
    syn keyword spupReportSubs     LEFT RIGHT CENTER CENTRE UOM TIME DATE VERSION RELDATE contained
    syn keyword spupUnitSubs       IS A contained
endif

" Speedup data types
if exists( "highlight_types" )
    syn keyword spupTypes act_coeff_liq area coefficient concentration contained
    syn keyword spupTypes control_signal cond_liq cond_vap cp_mass_liq contained
    syn keyword spupTypes cp_mol_liq cp_mol_vap cv_mol_liq cv_mol_vap contained
    syn keyword spupTypes diffus_liq diffus_vap delta_p dens_mass contained
    syn keyword spupTypes dens_mass_sol dens_mass_liq dens_mass_vap dens_mol contained
    syn keyword spupTypes dens_mol_sol dens_mol_liq dens_mol_vap enthflow contained
    syn keyword spupTypes enth_mass enth_mass_liq enth_mass_vap enth_mol contained
    syn keyword spupTypes enth_mol_sol enth_mol_liq enth_mol_vap entr_mol contained
    syn keyword spupTypes entr_mol_sol entr_mol_liq entr_mol_vap fraction contained
    syn keyword spupTypes flow_mass flow_mass_liq flow_mass_vap flow_mol contained
    syn keyword spupTypes flow_mol_vap flow_mol_liq flow_vol flow_vol_vap contained
    syn keyword spupTypes flow_vol_liq fuga_vap fuga_liq fuga_sol contained
    syn keyword spupTypes gibb_mol_sol heat_react heat_trans_coeff contained
    syn keyword spupTypes holdup_heat holdup_heat_liq holdup_heat_vap contained
    syn keyword spupTypes holdup_mass holdup_mass_liq holdup_mass_vap contained
    syn keyword spupTypes holdup_mol holdup_mol_liq holdup_mol_vap k_value contained
    syn keyword spupTypes length length_delta length_short liqfraction contained
    syn keyword spupTypes liqmassfraction mass massfraction molefraction contained
    syn keyword spupTypes molweight moment_inertia negative notype percent contained
    syn keyword spupTypes positive pressure press_diff press_drop press_rise contained
    syn keyword spupTypes ratio reaction reaction_mass rotation surf_tens contained
    syn keyword spupTypes temperature temperature_abs temp_diff temp_drop contained
    syn keyword spupTypes temp_rise time vapfraction vapmassfraction contained
    syn keyword spupTypes velocity visc_liq visc_vap volume zmom_rate contained
    syn keyword spupTypes seg_rate smom_rate tmom_rate zmom_mass seg_mass contained
    syn keyword spupTypes smom_mass tmom_mass zmom_holdup seg_holdup contained
    syn keyword spupTypes smom_holdup tmom_holdup contained
endif

" stream types
syn keyword spupStreams  mainstream vapour liquid contained

" "conditional" keywords
syn keyword spupConditional  IF THEN ELSE ENDIF contained
" Operators, symbols etc.
syn keyword spupOperator  AND OR NOT contained
syn match spupSymbol  "[,\-+=:;*/\"<>@%()]" contained
syn match spupSpecial  "[&\$?]" contained
" Surprisingly, Speedup allows no unary + instead of the -
syn match spupError  "[(=+\-*/]\s*+\d\+\([ed][+-]\=\d\+\)\=\>"lc=1 contained
syn match spupError  "[(=+\-*/]\s*+\d\+\.\([ed][+-]\=\d\+\)\=\>"lc=1 contained
syn match spupError  "[(=+\-*/]\s*+\d*\.\d\+\([ed][+-]\=\d\+\)\=\>"lc=1 contained
" String
syn region spupString  start=+"+  end=+"+  oneline contained
syn region spupString  start=+'+  end=+'+  oneline contained
" Identifier
syn match spupIdentifier  "\<[a-z][a-z0-9_]*\>" contained
" Textprocessor directives
syn match spupTextprocGeneric  "?[a-z][a-z0-9_]*\>" contained
syn region spupTextprocError matchgroup=spupTextprocGeneric start="?ERROR"  end="?END"he=s-1 contained
" Number, without decimal point
syn match spupNumber  "-\=\d\+\([ed][+-]\=\d\+\)\=" contained
" Number, allows 1. before exponent
syn match spupNumber  "-\=\d\+\.\([ed][+-]\=\d\+\)\=" contained
" Number allows .1 before exponent
syn match spupNumber  "-\=\d*\.\d\+\([ed][+-]\=\d\+\)\=" contained
" Help subsections
syn region spupHelp  start="^HELP"hs=e+1  end="^\$ENDHELP"he=s-1 contained
" Fortran code
syn region spupCode  start="^CODE"hs=e+1  end="^\$ENDCODE"he=s-1 contained
" oneline comments
if oneline_comments > 3
    oneline_comments = 2   " default
endif
if oneline_comments == 1
    syn match spupComment  "#[^#]*#\="
elseif oneline_comments == 2
    syn match spupError  "#.*$"
    syn match spupComment  "#[^#]*"  nextgroup=spupError
elseif oneline_comments == 3
    syn match spupComment  "#[^#]*"
    syn match spupError  "#[^#]*#.*"
endif
" multiline comments
syn match spupOpenBrace "{" contained
syn match spupError  "}"
syn region spupComment  matchgroup=spupComment2  start="{"  end="}"  keepend  contains=spupOpenBrace

syn cluster spupOrdinary  contains=spupNumber,spupIdentifier,spupSymbol
syn cluster spupOrdinary  add=spupError,spupString,spupComment
syn cluster spupTextproc  contains=spupTextprocGeneric,spupTextprocError

" define synchronizing; especially OPERATION sections can become very large
syn sync clear
syn sync minlines=100
syn sync maxlines=500

syn sync match spupSyncOperation  grouphere spupOperation  "^OPERATION"
syn sync match spupSyncCdi	  grouphere spupCdi	   "^CDI"
syn sync match spupSyncConditions grouphere spupConditions "^CONDITIONS"
syn sync match spupSyncDeclare    grouphere spupDeclare    "^DECLARE"
syn sync match spupSyncEstimation grouphere spupEstimation "^ESTIMATION"
syn sync match spupSyncExternal   grouphere spupExternal   "^EXTERNAL"
syn sync match spupSyncFlowsheet  grouphere spupFlowsheet  "^FLOWSHEET"
syn sync match spupSyncFunction   grouphere spupFunction   "^FUNCTION"
syn sync match spupSyncGlobal     grouphere spupGlobal     "^GLOBAL"
syn sync match spupSyncHomotopy   grouphere spupHomotopy   "^HOMOTOPY"
syn sync match spupSyncMacro      grouphere spupMacro      "^MACRO"
syn sync match spupSyncModel      grouphere spupModel      "^MODEL"
syn sync match spupSyncOperation  grouphere spupOperation  "^OPERATION"
syn sync match spupSyncOptions    grouphere spupOptions    "^OPTIONS"
syn sync match spupSyncProcedure  grouphere spupProcedure  "^PROCEDURE"
syn sync match spupSyncProfiles   grouphere spupProfiles   "^PROFILES"
syn sync match spupSyncReport     grouphere spupReport     "^REPORT"
syn sync match spupSyncTitle      grouphere spupTitle      "^TITLE"
syn sync match spupSyncUnit       grouphere spupUnit       "^UNIT"

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link spupCdi	    spupSection
hi def link spupConditions   spupSection
hi def link spupDeclare	    spupSection
hi def link spupEstimation   spupSection
hi def link spupExternal	    spupSection
hi def link spupFlowsheet    spupSection
hi def link spupFunction	    spupSection
hi def link spupGlobal	    spupSection
hi def link spupHomotopy	    spupSection
hi def link spupMacro	    spupSection
hi def link spupModel	    spupSection
hi def link spupOperation    spupSection
hi def link spupOptions	    spupSection
hi def link spupProcedure    spupSection
hi def link spupProfiles	    spupSection
hi def link spupReport	    spupSection
hi def link spupTitle	    spupConstant  " this is correct, truly ;)
hi def link spupUnit	    spupSection

hi def link spupCdiSubs	      spupSubs
hi def link spupConditionsSubs spupSubs
hi def link spupDeclareSubs    spupSubs
hi def link spupEstimationSubs spupSubs
hi def link spupExternalSubs   spupSubs
hi def link spupFlowsheetSubs  spupSubs
hi def link spupFunctionSubs   spupSubs
hi def link spupHomotopySubs   spupSubs
hi def link spupMacroSubs      spupSubs
hi def link spupModelSubs      spupSubs
hi def link spupOperationSubs  spupSubs
hi def link spupOptionsSubs    spupSubs
hi def link spupProcedureSubs  spupSubs
hi def link spupReportSubs     spupSubs
hi def link spupUnitSubs	      spupSubs

hi def link spupCode	       Normal
hi def link spupComment	       Comment
hi def link spupComment2	       spupComment
hi def link spupConditional     Statement
hi def link spupConstant	       Constant
hi def link spupError	       Error
hi def link spupHelp	       Normal
hi def link spupIdentifier      Identifier
hi def link spupNumber	       Constant
hi def link spupOperator	       Special
hi def link spupOpenBrace       spupError
hi def link spupSection	       Statement
hi def link spupSpecial	       spupTextprocGeneric
hi def link spupStreams	       Type
hi def link spupString	       Constant
hi def link spupSubs	       Statement
hi def link spupSymbol	       Special
hi def link spupTextprocError   Normal
hi def link spupTextprocGeneric PreProc
hi def link spupTypes	       Type


let b:current_syntax = "spup"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim:ts=8
