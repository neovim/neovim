" Vim syntax file
" Language:	TeX
" Maintainer:	Charles E. Campbell <NdrchipO@ScampbellPfamily.AbizM>
" Last Change:	Dec 07, 2016
" Version:	102
" URL:		http://www.drchip.org/astronaut/vim/index.html#SYNTAX_TEX
"
" Notes: {{{1
"
" 1. If you have a \begin{verbatim} that appears to overrun its boundaries,
"    use %stopzone.
"
" 2. Run-on equations ($..$ and $$..$$, particularly) can also be stopped
"    by suitable use of %stopzone.
"
" 3. If you have a slow computer, you may wish to modify
"
"	syn sync maxlines=200
"	syn sync minlines=50
"
"    to values that are more to your liking.
"
" 4. There is no match-syncing for $...$ and $$...$$; hence large
"    equation blocks constructed that way may exhibit syncing problems.
"    (there's no difference between begin/end patterns)
"
" 5. If you have the variable "g:tex_no_error" defined then none of the
"    lexical error-checking will be done.
"
"    ie. let g:tex_no_error=1
"
" 6. Please see  :help latex-syntax  for information on
"      syntax folding           :help tex-folding
"      spell checking           :help tex-nospell
"      commands and mathzones   :help tex-runon
"      new command highlighting :help tex-morecommands
"      error highlighting       :help tex-error
"      new math groups          :help tex-math
"      new styles               :help tex-style
"      using conceal mode       :help tex-conceal

" Version Clears: {{{1
" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim
scriptencoding utf-8

" by default, enable all region-based highlighting
let s:tex_fast= "bcmMprsSvV"
if exists("g:tex_fast")
 if type(g:tex_fast) != 1
  " g:tex_fast exists and is not a string, so
  " turn off all optional region-based highighting
  let s:tex_fast= ""
 else
  let s:tex_fast= g:tex_fast
 endif
endif

" let user determine which classes of concealment will be supported
"   a=accents/ligatures d=delimiters m=math symbols  g=Greek  s=superscripts/subscripts
if !exists("g:tex_conceal")
 let s:tex_conceal= 'abdmgsS'
else
 let s:tex_conceal= g:tex_conceal
endif
if !exists("g:tex_superscripts")
 let s:tex_superscripts= '[0-9a-zA-W.,:;+-<>/()=]'
else
 let s:tex_superscripts= g:tex_superscripts
endif
if !exists("g:tex_subscripts")
 let s:tex_subscripts= '[0-9aehijklmnoprstuvx,+-/().]'
else
 let s:tex_subscripts= g:tex_subscripts
endif

" Determine whether or not to use "*.sty" mode {{{1
" The user may override the normal determination by setting
"   g:tex_stylish to 1      (for    "*.sty" mode)
"    or to           0 else (normal "*.tex" mode)
" or on a buffer-by-buffer basis with b:tex_stylish
let s:extfname=expand("%:e")
if exists("g:tex_stylish")
 let b:tex_stylish= g:tex_stylish
elseif !exists("b:tex_stylish")
 if s:extfname == "sty" || s:extfname == "cls" || s:extfname == "clo" || s:extfname == "dtx" || s:extfname == "ltx"
  let b:tex_stylish= 1
 else
  let b:tex_stylish= 0
 endif
endif

" handle folding {{{1
if !exists("g:tex_fold_enabled")
 let s:tex_fold_enabled= 0
elseif g:tex_fold_enabled && !has("folding")
 let s:tex_fold_enabled= 0
 echomsg "Ignoring g:tex_fold_enabled=".g:tex_fold_enabled."; need to re-compile vim for +fold support"
else
 let s:tex_fold_enabled= 1
endif
if s:tex_fold_enabled && &fdm == "manual"
 setl fdm=syntax
endif
if s:tex_fold_enabled && has("folding")
 com! -nargs=* TexFold <args> fold 
else
 com! -nargs=* TexFold <args> 
endif

" (La)TeX keywords: uses the characters 0-9,a-z,A-Z,192-255 only... {{{1
" but _ is the only one that causes problems.
" One may override this iskeyword setting by providing
" g:tex_isk
if exists("g:tex_isk")
 if b:tex_stylish && g:tex_isk !~ '@'
  let b:tex_isk= '@,'.g:tex_isk
 else
  let b:tex_isk= g:tex_isk
 endif
elseif b:tex_stylish
 let b:tex_isk="@,48-57,a-z,A-Z,192-255"
else
 let b:tex_isk="48-57,a-z,A-Z,192-255"
endif
if v:version > 704 || (v:version == 704 && has("patch-7.4.1142"))
 exe "syn iskeyword ".b:tex_isk
else
 exe "setl isk=".b:tex_isk
endif
if exists("g:tex_no_error") && g:tex_no_error
 let s:tex_no_error= 1
else
 let s:tex_no_error= 0
endif
if exists("g:tex_comment_nospell") && g:tex_comment_nospell
 let s:tex_comment_nospell= 1
else
 let s:tex_comment_nospell= 0
endif
if exists("g:tex_nospell") && g:tex_nospell
 let s:tex_nospell = 1
else
 let s:tex_nospell = 0
endif

" Clusters: {{{1
" --------
syn cluster texCmdGroup			contains=texCmdBody,texComment,texDefParm,texDelimiter,texDocType,texInput,texLength,texLigature,texMathDelim,texMathOper,texNewCmd,texNewEnv,texRefZone,texSection,texBeginEnd,texBeginEndName,texSpecialChar,texStatement,texString,texTypeSize,texTypeStyle,@texMathZones
if !s:tex_no_error
 syn cluster texCmdGroup		add=texMathError
endif
syn cluster texEnvGroup			contains=texMatcher,texMathDelim,texSpecialChar,texStatement
syn cluster texFoldGroup		contains=texAccent,texBadMath,texComment,texDefCmd,texDelimiter,texDocType,texInput,texInputFile,texLength,texLigature,texMatcher,texMathZoneV,texMathZoneW,texMathZoneX,texMathZoneY,texMathZoneZ,texNewCmd,texNewEnv,texOnlyMath,texOption,texParen,texRefZone,texSection,texBeginEnd,texSectionZone,texSpaceCode,texSpecialChar,texStatement,texString,texTypeSize,texTypeStyle,texZone,@texMathZones,texTitle,texAbstract,texBoldStyle,texItalStyle,texNoSpell
syn cluster texBoldGroup		contains=texAccent,texBadMath,texComment,texDefCmd,texDelimiter,texDocType,texInput,texInputFile,texLength,texLigature,texMatcher,texMathZoneV,texMathZoneW,texMathZoneX,texMathZoneY,texMathZoneZ,texNewCmd,texNewEnv,texOnlyMath,texOption,texParen,texRefZone,texSection,texBeginEnd,texSectionZone,texSpaceCode,texSpecialChar,texStatement,texString,texTypeSize,texTypeStyle,texZone,@texMathZones,texTitle,texAbstract,texBoldStyle,texBoldItalStyle,texNoSpell
syn cluster texItalGroup		contains=texAccent,texBadMath,texComment,texDefCmd,texDelimiter,texDocType,texInput,texInputFile,texLength,texLigature,texMatcher,texMathZoneV,texMathZoneW,texMathZoneX,texMathZoneY,texMathZoneZ,texNewCmd,texNewEnv,texOnlyMath,texOption,texParen,texRefZone,texSection,texBeginEnd,texSectionZone,texSpaceCode,texSpecialChar,texStatement,texString,texTypeSize,texTypeStyle,texZone,@texMathZones,texTitle,texAbstract,texItalStyle,texItalBoldStyle,texNoSpell
if !s:tex_nospell
 syn cluster texMatchGroup		contains=texAccent,texBadMath,texComment,texDefCmd,texDelimiter,texDocType,texInput,texLength,texLigature,texMatcher,texNewCmd,texNewEnv,texOnlyMath,texParen,texRefZone,texSection,texSpecialChar,texStatement,texString,texTypeSize,texTypeStyle,texZone,texInputFile,texOption,@Spell
 syn cluster texMatchNMGroup		contains=texAccent,texBadMath,texComment,texDefCmd,texDelimiter,texDocType,texInput,texLength,texLigature,texMatcherNM,texNewCmd,texNewEnv,texOnlyMath,texParen,texRefZone,texSection,texSpecialChar,texStatement,texString,texTypeSize,texTypeStyle,texZone,texInputFile,texOption,@Spell
 syn cluster texStyleGroup		contains=texAccent,texBadMath,texComment,texDefCmd,texDelimiter,texDocType,texInput,texLength,texLigature,texNewCmd,texNewEnv,texOnlyMath,texParen,texRefZone,texSection,texSpecialChar,texStatement,texString,texTypeSize,texTypeStyle,texZone,texInputFile,texOption,texStyleStatement,@Spell,texStyleMatcher
else
 syn cluster texMatchGroup		contains=texAccent,texBadMath,texComment,texDefCmd,texDelimiter,texDocType,texInput,texLength,texLigature,texMatcher,texNewCmd,texNewEnv,texOnlyMath,texParen,texRefZone,texSection,texSpecialChar,texStatement,texString,texTypeSize,texTypeStyle,texZone,texInputFile,texOption
 syn cluster texMatchNMGroup		contains=texAccent,texBadMath,texComment,texDefCmd,texDelimiter,texDocType,texInput,texLength,texLigature,texMatcherNM,texNewCmd,texNewEnv,texOnlyMath,texParen,texRefZone,texSection,texSpecialChar,texStatement,texString,texTypeSize,texTypeStyle,texZone,texInputFile,texOption
 syn cluster texStyleGroup		contains=texAccent,texBadMath,texComment,texDefCmd,texDelimiter,texDocType,texInput,texLength,texLigature,texNewCmd,texNewEnv,texOnlyMath,texParen,texRefZone,texSection,texSpecialChar,texStatement,texString,texTypeSize,texTypeStyle,texZone,texInputFile,texOption,texStyleStatement,texStyleMatcher
endif
syn cluster texPreambleMatchGroup	contains=texAccent,texBadMath,texComment,texDefCmd,texDelimiter,texDocType,texInput,texLength,texLigature,texMatcherNM,texNewCmd,texNewEnv,texOnlyMath,texParen,texRefZone,texSection,texSpecialChar,texStatement,texString,texTitle,texTypeSize,texTypeStyle,texZone,texInputFile,texOption,texMathZoneZ
syn cluster texRefGroup			contains=texMatcher,texComment,texDelimiter
if !exists("g:tex_no_math")
 syn cluster texPreambleMatchGroup	contains=texAccent,texBadMath,texComment,texDefCmd,texDelimiter,texDocType,texInput,texLength,texLigature,texMatcherNM,texNewCmd,texNewEnv,texOnlyMath,texParen,texRefZone,texSection,texSpecialChar,texStatement,texString,texTitle,texTypeSize,texTypeStyle,texZone,texInputFile,texOption,texMathZoneZ
 syn cluster texMathZones		contains=texMathZoneV,texMathZoneW,texMathZoneX,texMathZoneY,texMathZoneZ
 syn cluster texMatchGroup		add=@texMathZones
 syn cluster texMathDelimGroup		contains=texMathDelimBad,texMathDelimKey,texMathDelimSet1,texMathDelimSet2
 syn cluster texMathMatchGroup		contains=@texMathZones,texComment,texDefCmd,texDelimiter,texDocType,texInput,texLength,texLigature,texMathDelim,texMathMatcher,texMathOper,texNewCmd,texNewEnv,texRefZone,texSection,texSpecialChar,texStatement,texString,texTypeSize,texTypeStyle,texZone
 syn cluster texMathZoneGroup		contains=texComment,texDelimiter,texLength,texMathDelim,texMathMatcher,texMathOper,texMathSymbol,texMathText,texRefZone,texSpecialChar,texStatement,texTypeSize,texTypeStyle
 if !s:tex_no_error
  syn cluster texMathMatchGroup		add=texMathError
  syn cluster texMathZoneGroup		add=texMathError
 endif
 syn cluster texMathZoneGroup		add=@NoSpell
 " following used in the \part \chapter \section \subsection \subsubsection
 " \paragraph \subparagraph \author \title highlighting
 syn cluster texDocGroup		contains=texPartZone,@texPartGroup
 syn cluster texPartGroup		contains=texChapterZone,texSectionZone,texParaZone
 syn cluster texChapterGroup		contains=texSectionZone,texParaZone
 syn cluster texSectionGroup		contains=texSubSectionZone,texParaZone
 syn cluster texSubSectionGroup		contains=texSubSubSectionZone,texParaZone
 syn cluster texSubSubSectionGroup	contains=texParaZone
 syn cluster texParaGroup		contains=texSubParaZone
 if has("conceal") && &enc == 'utf-8'
  syn cluster texMathZoneGroup		add=texGreek,texSuperscript,texSubscript,texMathSymbol
  syn cluster texMathMatchGroup		add=texGreek,texSuperscript,texSubscript,texMathSymbol
 endif
endif

" Try to flag {} and () mismatches: {{{1
if s:tex_fast =~# 'm'
  if !s:tex_no_error
   syn region texMatcher	matchgroup=Delimiter start="{" skip="\\\\\|\\[{}]"	end="}"			transparent contains=@texMatchGroup,texError
   syn region texMatcher	matchgroup=Delimiter start="\["				end="]"			transparent contains=@texMatchGroup,texError,@NoSpell
   syn region texMatcherNM	matchgroup=Delimiter start="{" skip="\\\\\|\\[{}]"	end="}"			transparent contains=@texMatchNMGroup,texError
   syn region texMatcherNM	matchgroup=Delimiter start="\["				end="]"			transparent contains=@texMatchNMGroup,texError,@NoSpell
  else
   syn region texMatcher	matchgroup=Delimiter start="{" skip="\\\\\|\\[{}]"	end="}"			transparent contains=@texMatchGroup
   syn region texMatcher	matchgroup=Delimiter start="\["				end="]"			transparent contains=@texMatchGroup
   syn region texMatcherNM	matchgroup=Delimiter start="{" skip="\\\\\|\\[{}]"	end="}"			transparent contains=@texMatchNMGroup
   syn region texMatcherNM	matchgroup=Delimiter start="\["				end="]"			transparent contains=@texMatchNMGroup
  endif
  if !s:tex_nospell
   syn region texParen		start="("	end=")"								transparent contains=@texMatchGroup,@Spell
  else
   syn region texParen		start="("	end=")"								transparent contains=@texMatchGroup
  endif
endif
if !s:tex_no_error
 syn match  texError		"[}\])]"
endif
if s:tex_fast =~# 'M'
  if !exists("g:tex_no_math")
   if !s:tex_no_error
    syn match  texMathError	"}"	contained
   endif
   syn region texMathMatcher	matchgroup=Delimiter	start="{"          skip="\%(\\\\\)*\\}"     end="}" end="%stopzone\>"	contained contains=@texMathMatchGroup
  endif
endif

" TeX/LaTeX keywords: {{{1
" Instead of trying to be All Knowing, I just match \..alphameric..
" Note that *.tex files may not have "@" in their \commands
if exists("g:tex_tex") || b:tex_stylish
  syn match texStatement	"\\[a-zA-Z@]\+"
else
  syn match texStatement	"\\\a\+"
  if !s:tex_no_error
   syn match texError		"\\\a*@[a-zA-Z@]*"
  endif
endif

" TeX/LaTeX delimiters: {{{1
syn match texDelimiter		"&"
syn match texDelimiter		"\\\\"

" Tex/Latex Options: {{{1
syn match texOption		"[^\\]\zs#\d\+\|^#\d\+"

" texAccent (tnx to Karim Belabas) avoids annoying highlighting for accents: {{{1
if b:tex_stylish
  syn match texAccent		"\\[bcdvuH][^a-zA-Z@]"me=e-1
  syn match texLigature		"\\\([ijolL]\|ae\|oe\|ss\|AA\|AE\|OE\)[^a-zA-Z@]"me=e-1
else
  syn match texAccent		"\\[bcdvuH]\A"me=e-1
  syn match texLigature		"\\\([ijolL]\|ae\|oe\|ss\|AA\|AE\|OE\)\A"me=e-1
endif
syn match texAccent		"\\[bcdvuH]$"
syn match texAccent		+\\[=^.\~"`']+
syn match texAccent		+\\['=t'.c^ud"vb~Hr]{\a}+
syn match texLigature		"\\\([ijolL]\|ae\|oe\|ss\|AA\|AE\|OE\)$"

" \begin{}/\end{} section markers: {{{1
syn match  texBeginEnd		"\\begin\>\|\\end\>" nextgroup=texBeginEndName
if s:tex_fast =~# 'm'
  syn region texBeginEndName		matchgroup=Delimiter	start="{"		end="}"	contained	nextgroup=texBeginEndModifier	contains=texComment
  syn region texBeginEndModifier	matchgroup=Delimiter	start="\["		end="]"	contained	contains=texComment,@texMathZones,@NoSpell
endif

" \documentclass, \documentstyle, \usepackage: {{{1
syn match  texDocType		"\\documentclass\>\|\\documentstyle\>\|\\usepackage\>"	nextgroup=texBeginEndName,texDocTypeArgs
if s:tex_fast =~# 'm'
  syn region texDocTypeArgs	matchgroup=Delimiter start="\[" end="]"			contained	nextgroup=texBeginEndName	contains=texComment,@NoSpell
endif

" Preamble syntax-based folding support: {{{1
if s:tex_fold_enabled && has("folding")
 syn region texPreamble	transparent fold	start='\zs\\documentclass\>' end='\ze\\begin{document}'	contains=texStyle,@texPreambleMatchGroup
endif

" TeX input: {{{1
syn match texInput		"\\input\s\+[a-zA-Z/.0-9_^]\+"hs=s+7				contains=texStatement
syn match texInputFile		"\\include\(graphics\|list\)\=\(\[.\{-}\]\)\=\s*{.\{-}}"	contains=texStatement,texInputCurlies,texInputFileOpt
syn match texInputFile		"\\\(epsfig\|input\|usepackage\)\s*\(\[.*\]\)\={.\{-}}"		contains=texStatement,texInputCurlies,texInputFileOpt
syn match texInputCurlies	"[{}]"								contained
if s:tex_fast =~# 'm'
 syn region texInputFileOpt	matchgroup=Delimiter start="\[" end="\]"			contained	contains=texComment
endif

" Type Styles (LaTeX 2.09): {{{1
syn match texTypeStyle		"\\rm\>"
syn match texTypeStyle		"\\em\>"
syn match texTypeStyle		"\\bf\>"
syn match texTypeStyle		"\\it\>"
syn match texTypeStyle		"\\sl\>"
syn match texTypeStyle		"\\sf\>"
syn match texTypeStyle		"\\sc\>"
syn match texTypeStyle		"\\tt\>"

" Type Styles: attributes, commands, families, etc (LaTeX2E): {{{1
if s:tex_conceal !~# 'b'
 syn match texTypeStyle		"\\textbf\>"
 syn match texTypeStyle		"\\textit\>"
endif
syn match texTypeStyle		"\\textmd\>"
syn match texTypeStyle		"\\textrm\>"
syn match texTypeStyle		"\\textsc\>"
syn match texTypeStyle		"\\textsf\>"
syn match texTypeStyle		"\\textsl\>"
syn match texTypeStyle		"\\texttt\>"
syn match texTypeStyle		"\\textup\>"
syn match texTypeStyle		"\\emph\>"

syn match texTypeStyle		"\\mathbb\>"
syn match texTypeStyle		"\\mathbf\>"
syn match texTypeStyle		"\\mathcal\>"
syn match texTypeStyle		"\\mathfrak\>"
syn match texTypeStyle		"\\mathit\>"
syn match texTypeStyle		"\\mathnormal\>"
syn match texTypeStyle		"\\mathrm\>"
syn match texTypeStyle		"\\mathsf\>"
syn match texTypeStyle		"\\mathtt\>"

syn match texTypeStyle		"\\rmfamily\>"
syn match texTypeStyle		"\\sffamily\>"
syn match texTypeStyle		"\\ttfamily\>"

syn match texTypeStyle		"\\itshape\>"
syn match texTypeStyle		"\\scshape\>"
syn match texTypeStyle		"\\slshape\>"
syn match texTypeStyle		"\\upshape\>"

syn match texTypeStyle		"\\bfseries\>"
syn match texTypeStyle		"\\mdseries\>"

" Some type sizes: {{{1
syn match texTypeSize		"\\tiny\>"
syn match texTypeSize		"\\scriptsize\>"
syn match texTypeSize		"\\footnotesize\>"
syn match texTypeSize		"\\small\>"
syn match texTypeSize		"\\normalsize\>"
syn match texTypeSize		"\\large\>"
syn match texTypeSize		"\\Large\>"
syn match texTypeSize		"\\LARGE\>"
syn match texTypeSize		"\\huge\>"
syn match texTypeSize		"\\Huge\>"

" Spacecodes (TeX'isms): {{{1
" \mathcode`\^^@="2201  \delcode`\(="028300  \sfcode`\)=0 \uccode`X=`X  \lccode`x=`x
syn match texSpaceCode		"\\\(math\|cat\|del\|lc\|sf\|uc\)code`"me=e-1 nextgroup=texSpaceCodeChar
syn match texSpaceCodeChar    "`\\\=.\(\^.\)\==\(\d\|\"\x\{1,6}\|`.\)"	contained

" Sections, subsections, etc: {{{1
if s:tex_fast =~# 'p'
 if !s:tex_nospell
  TexFold syn region texDocZone			matchgroup=texSection start='\\begin\s*{\s*document\s*}' end='\\end\s*{\s*document\s*}'											contains=@texFoldGroup,@texDocGroup,@Spell
  TexFold syn region texPartZone		matchgroup=texSection start='\\part\>'			 end='\ze\s*\\\%(part\>\|end\s*{\s*document\s*}\)'								contains=@texFoldGroup,@texPartGroup,@Spell
  TexFold syn region texChapterZone		matchgroup=texSection start='\\chapter\>'		 end='\ze\s*\\\%(chapter\>\|part\>\|end\s*{\s*document\s*}\)'							contains=@texFoldGroup,@texChapterGroup,@Spell
  TexFold syn region texSectionZone		matchgroup=texSection start='\\section\>'		 end='\ze\s*\\\%(section\>\|chapter\>\|part\>\|end\s*{\s*document\s*}\)'					contains=@texFoldGroup,@texSectionGroup,@Spell
  TexFold syn region texSubSectionZone		matchgroup=texSection start='\\subsection\>'		 end='\ze\s*\\\%(\%(sub\)\=section\>\|chapter\>\|part\>\|end\s*{\s*document\s*}\)'				contains=@texFoldGroup,@texSubSectionGroup,@Spell
  TexFold syn region texSubSubSectionZone	matchgroup=texSection start='\\subsubsection\>'		 end='\ze\s*\\\%(\%(sub\)\{,2}section\>\|chapter\>\|part\>\|end\s*{\s*document\s*}\)'				contains=@texFoldGroup,@texSubSubSectionGroup,@Spell
  TexFold syn region texParaZone		matchgroup=texSection start='\\paragraph\>'		 end='\ze\s*\\\%(paragraph\>\|\%(sub\)*section\>\|chapter\>\|part\>\|end\s*{\s*document\s*}\)'			contains=@texFoldGroup,@texParaGroup,@Spell
  TexFold syn region texSubParaZone		matchgroup=texSection start='\\subparagraph\>'		 end='\ze\s*\\\%(\%(sub\)\=paragraph\>\|\%(sub\)*section\>\|chapter\>\|part\>\|end\s*{\s*document\s*}\)'	contains=@texFoldGroup,@Spell
  TexFold syn region texTitle			matchgroup=texSection start='\\\%(author\|title\)\>\s*{' end='}'													contains=@texFoldGroup,@Spell
  TexFold syn region texAbstract		matchgroup=texSection start='\\begin\s*{\s*abstract\s*}' end='\\end\s*{\s*abstract\s*}'											contains=@texFoldGroup,@Spell
 else
  TexFold syn region texDocZone			matchgroup=texSection start='\\begin\s*{\s*document\s*}' end='\\end\s*{\s*document\s*}'											contains=@texFoldGroup,@texDocGroup
  TexFold syn region texPartZone		matchgroup=texSection start='\\part\>'			 end='\ze\s*\\\%(part\>\|end\s*{\s*document\s*}\)'								contains=@texFoldGroup,@texPartGroup
  TexFold syn region texChapterZone		matchgroup=texSection start='\\chapter\>'		 end='\ze\s*\\\%(chapter\>\|part\>\|end\s*{\s*document\s*}\)'							contains=@texFoldGroup,@texChapterGroup
  TexFold syn region texSectionZone		matchgroup=texSection start='\\section\>'		 end='\ze\s*\\\%(section\>\|chapter\>\|part\>\|end\s*{\s*document\s*}\)'					contains=@texFoldGroup,@texSectionGroup
  TexFold syn region texSubSectionZone		matchgroup=texSection start='\\subsection\>'		 end='\ze\s*\\\%(\%(sub\)\=section\>\|chapter\>\|part\>\|end\s*{\s*document\s*}\)'				contains=@texFoldGroup,@texSubSectionGroup
  TexFold syn region texSubSubSectionZone	matchgroup=texSection start='\\subsubsection\>'		 end='\ze\s*\\\%(\%(sub\)\{,2}section\>\|chapter\>\|part\>\|end\s*{\s*document\s*}\)'				contains=@texFoldGroup,@texSubSubSectionGroup
  TexFold syn region texParaZone		matchgroup=texSection start='\\paragraph\>'		 end='\ze\s*\\\%(paragraph\>\|\%(sub\)*section\>\|chapter\>\|part\>\|end\s*{\s*document\s*}\)'			contains=@texFoldGroup,@texParaGroup
  TexFold syn region texSubParaZone		matchgroup=texSection start='\\subparagraph\>'		 end='\ze\s*\\\%(\%(sub\)\=paragraph\>\|\%(sub\)*section\>\|chapter\>\|part\>\|end\s*{\s*document\s*}\)'	contains=@texFoldGroup
  TexFold syn region texTitle			matchgroup=texSection start='\\\%(author\|title\)\>\s*{' end='}'													contains=@texFoldGroup
  TexFold syn region texAbstract		matchgroup=texSection start='\\begin\s*{\s*abstract\s*}' end='\\end\s*{\s*abstract\s*}'											contains=@texFoldGroup
  endif
endif

" particular support for bold and italic {{{1
if s:tex_fast =~# 'b'
  if s:tex_conceal =~# 'b'
   if !exists("g:tex_nospell") || !g:tex_nospell
    syn region texBoldStyle	matchgroup=texTypeStyle start="\\textbf\s*{" matchgroup=texTypeStyle  end="}" concealends contains=@texBoldGroup,@Spell
    syn region texBoldItalStyle	matchgroup=texTypeStyle start="\\textit\s*{" matchgroup=texTypeStyle  end="}" concealends contains=@texItalGroup,@Spell
    syn region texItalStyle	matchgroup=texTypeStyle start="\\textit\s*{" matchgroup=texTypeStyle  end="}" concealends contains=@texItalGroup,@Spell
    syn region texItalBoldStyle	matchgroup=texTypeStyle start="\\textbf\s*{" matchgroup=texTypeStyle  end="}" concealends contains=@texBoldGroup,@Spell
   else                                                                                              
    syn region texBoldStyle	matchgroup=texTypeStyle start="\\textbf\s*{" matchgroup=texTypeStyle  end="}" concealends contains=@texBoldGroup
    syn region texBoldItalStyle	matchgroup=texTypeStyle start="\\textit\s*{" matchgroup=texTypeStyle  end="}" concealends contains=@texItalGroup
    syn region texItalStyle	matchgroup=texTypeStyle start="\\textit\s*{" matchgroup=texTypeStyle  end="}" concealends contains=@texItalGroup
    syn region texItalBoldStyle	matchgroup=texTypeStyle start="\\textbf\s*{" matchgroup=texTypeStyle  end="}" concealends contains=@texBoldGroup
   endif
  endif
endif

" Bad Math (mismatched): {{{1
if !exists("g:tex_no_math") && !s:tex_no_error
 syn match texBadMath		"\\end\s*{\s*\(array\|gathered\|bBpvV]matrix\|split\|subequations\|smallmatrix\|xxalignat\)\s*}"
 syn match texBadMath		"\\end\s*{\s*\(align\|alignat\|displaymath\|displaymath\|eqnarray\|equation\|flalign\|gather\|math\|multline\|xalignat\)\*\=\s*}"
 syn match texBadMath		"\\[\])]"
endif

" Math Zones: {{{1
if !exists("g:tex_no_math")
 " TexNewMathZone: function creates a mathzone with the given suffix and mathzone name. {{{2
 "                 Starred forms are created if starform is true.  Starred
 "                 forms have syntax group and synchronization groups with a
 "                 "S" appended.  Handles: cluster, syntax, sync, and highlighting.
 fun! TexNewMathZone(sfx,mathzone,starform)
   let grpname  = "texMathZone".a:sfx
   let syncname = "texSyncMathZone".a:sfx
   if s:tex_fold_enabled
    let foldcmd= " fold"
   else
    let foldcmd= ""
   endif
   exe "syn cluster texMathZones add=".grpname
   if s:tex_fast =~# 'M'
    exe 'syn region '.grpname.' start='."'".'\\begin\s*{\s*'.a:mathzone.'\s*}'."'".' end='."'".'\\end\s*{\s*'.a:mathzone.'\s*}'."'".' keepend contains=@texMathZoneGroup'.foldcmd
    exe 'syn sync match '.syncname.' grouphere '.grpname.' "\\begin\s*{\s*'.a:mathzone.'\*\s*}"'
    exe 'syn sync match '.syncname.' grouphere '.grpname.' "\\begin\s*{\s*'.a:mathzone.'\*\s*}"'
   endif
   exe 'hi def link '.grpname.' texMath'
   if a:starform
    let grpname  = "texMathZone".a:sfx.'S'
    let syncname = "texSyncMathZone".a:sfx.'S'
    exe "syn cluster texMathZones add=".grpname
    if s:tex_fast =~# 'M'
     exe 'syn region '.grpname.' start='."'".'\\begin\s*{\s*'.a:mathzone.'\*\s*}'."'".' end='."'".'\\end\s*{\s*'.a:mathzone.'\*\s*}'."'".' keepend contains=@texMathZoneGroup'.foldcmd
     exe 'syn sync match '.syncname.' grouphere '.grpname.' "\\begin\s*{\s*'.a:mathzone.'\*\s*}"'
     exe 'syn sync match '.syncname.' grouphere '.grpname.' "\\begin\s*{\s*'.a:mathzone.'\*\s*}"'
    endif
    exe 'hi def link '.grpname.' texMath'
   endif
 endfun

 " Standard Math Zones: {{{2
 call TexNewMathZone("A","align",1)
 call TexNewMathZone("B","alignat",1)
 call TexNewMathZone("C","displaymath",1)
 call TexNewMathZone("D","eqnarray",1)
 call TexNewMathZone("E","equation",1)
 call TexNewMathZone("F","flalign",1)
 call TexNewMathZone("G","gather",1)
 call TexNewMathZone("H","math",1)
 call TexNewMathZone("I","multline",1)
 call TexNewMathZone("J","xalignat",1)
 call TexNewMathZone("K","xxalignat",0)

 " Inline Math Zones: {{{2
 if s:tex_fast =~# 'M'
  if has("conceal") && &enc == 'utf-8' && s:tex_conceal =~# 'd'
   syn region texMathZoneV	matchgroup=Delimiter start="\\("			matchgroup=Delimiter	end="\\)\|%stopzone\>"			keepend concealends contains=@texMathZoneGroup
   syn region texMathZoneW	matchgroup=Delimiter start="\\\["			matchgroup=Delimiter	end="\\]\|%stopzone\>"			keepend concealends contains=@texMathZoneGroup
   syn region texMathZoneX	matchgroup=Delimiter start="\$" skip="\\\\\|\\\$"	matchgroup=Delimiter	end="\$"	end="%stopzone\>"		concealends contains=@texMathZoneGroup
   syn region texMathZoneY	matchgroup=Delimiter start="\$\$" 			matchgroup=Delimiter	end="\$\$"	end="%stopzone\>"	keepend concealends contains=@texMathZoneGroup
  else
   syn region texMathZoneV	matchgroup=Delimiter start="\\("			matchgroup=Delimiter	end="\\)\|%stopzone\>"			keepend contains=@texMathZoneGroup
   syn region texMathZoneW	matchgroup=Delimiter start="\\\["			matchgroup=Delimiter	end="\\]\|%stopzone\>"			keepend contains=@texMathZoneGroup
   syn region texMathZoneX	matchgroup=Delimiter start="\$" skip="\%(\\\\\)*\\\$"	matchgroup=Delimiter	end="\$"	end="%stopzone\>"		contains=@texMathZoneGroup
   syn region texMathZoneY	matchgroup=Delimiter start="\$\$" 			matchgroup=Delimiter	end="\$\$"	end="%stopzone\>"	keepend	contains=@texMathZoneGroup
  endif
  syn region texMathZoneZ	matchgroup=texStatement start="\\ensuremath\s*{"	matchgroup=texStatement	end="}"		end="%stopzone\>"	contains=@texMathZoneGroup
 endif

 syn match texMathOper		"[_^=]" contained

 " Text Inside Math Zones: {{{2
 if s:tex_fast =~# 'M'
  if !exists("g:tex_nospell") || !g:tex_nospell
   syn region texMathText matchgroup=texStatement start='\\\(\(inter\)\=text\|mbox\)\s*{'	end='}'	contains=@texFoldGroup,@Spell
  else
   syn region texMathText matchgroup=texStatement start='\\\(\(inter\)\=text\|mbox\)\s*{'	end='}'	contains=@texFoldGroup
  endif
 endif

 " \left..something.. and \right..something.. support: {{{2
 syn match   texMathDelimBad	contained		"\S"
 if has("conceal") && &enc == 'utf-8' && s:tex_conceal =~# 'm'
  syn match   texMathDelim	contained		"\\left\["
  syn match   texMathDelim	contained		"\\left\\{"	skipwhite nextgroup=texMathDelimSet1,texMathDelimSet2,texMathDelimBad contains=texMathSymbol cchar={
  syn match   texMathDelim	contained		"\\right\\}"	skipwhite nextgroup=texMathDelimSet1,texMathDelimSet2,texMathDelimBad contains=texMathSymbol cchar=}
  let s:texMathDelimList=[
     \ ['<'            , '<'] ,
     \ ['>'            , '>'] ,
     \ ['('            , '('] ,
     \ [')'            , ')'] ,
     \ ['\['           , '['] ,
     \ [']'            , ']'] ,
     \ ['\\{'          , '{'] ,
     \ ['\\}'          , '}'] ,
     \ ['|'            , '|'] ,
     \ ['\\|'          , '‖'] ,
     \ ['\\backslash'  , '\'] ,
     \ ['\\downarrow'  , '↓'] ,
     \ ['\\Downarrow'  , '⇓'] ,
     \ ['\\lbrace'     , '['] ,
     \ ['\\lceil'      , '⌈'] ,
     \ ['\\lfloor'     , '⌊'] ,
     \ ['\\lgroup'     , '⌊'] ,
     \ ['\\lmoustache' , '⎛'] ,
     \ ['\\rbrace'     , ']'] ,
     \ ['\\rceil'      , '⌉'] ,
     \ ['\\rfloor'     , '⌋'] ,
     \ ['\\rgroup'     , '⌋'] ,
     \ ['\\rmoustache' , '⎞'] ,
     \ ['\\uparrow'    , '↑'] ,
     \ ['\\Uparrow'    , '↑'] ,
     \ ['\\updownarrow', '↕'] ,
     \ ['\\Updownarrow', '⇕']]
  if &ambw == "double" || exists("g:tex_usedblwidth")
    let s:texMathDelimList= s:texMathDelimList + [
     \ ['\\langle'     , '〈'] ,
     \ ['\\rangle'     , '〉'] ,
  else
    let s:texMathDelimList= s:texMathDelimList + [
     \ ['\\langle'     , '<'] ,
     \ ['\\rangle'     , '>']]
  endif
  syn match texMathDelim	'\\[bB]igg\=[lr]' contained nextgroup=texMathDelimBad
  for texmath in s:texMathDelimList
   exe "syn match texMathDelim	'\\\\[bB]igg\\=[lr]\\=".texmath[0]."'	contained conceal cchar=".texmath[1]
  endfor

 else
  syn match   texMathDelim	contained		"\\\(left\|right\)\>"	skipwhite nextgroup=texMathDelimSet1,texMathDelimSet2,texMathDelimBad
  syn match   texMathDelim	contained		"\\[bB]igg\=[lr]\=\>"	skipwhite nextgroup=texMathDelimSet1,texMathDelimSet2,texMathDelimBad
  syn match   texMathDelimSet2	contained	"\\"		nextgroup=texMathDelimKey,texMathDelimBad
  syn match   texMathDelimSet1	contained	"[<>()[\]|/.]\|\\[{}|]"
  syn keyword texMathDelimKey	contained	backslash       lceil           lVert           rgroup          uparrow
  syn keyword texMathDelimKey	contained	downarrow       lfloor          rangle          rmoustache      Uparrow
  syn keyword texMathDelimKey	contained	Downarrow       lgroup          rbrace          rvert           updownarrow
  syn keyword texMathDelimKey	contained	langle          lmoustache      rceil           rVert           Updownarrow
  syn keyword texMathDelimKey	contained	lbrace          lvert           rfloor
 endif
 syn match   texMathDelim	contained		"\\\(left\|right\)arrow\>\|\<\([aA]rrow\|brace\)\=vert\>"
 syn match   texMathDelim	contained		"\\lefteqn\>"
endif

" Special TeX characters  ( \$ \& \% \# \{ \} \_ \S \P ) : {{{1
syn match texSpecialChar	"\\[$&%#{}_]"
if b:tex_stylish
  syn match texSpecialChar	"\\[SP@][^a-zA-Z@]"me=e-1
else
  syn match texSpecialChar	"\\[SP@]\A"me=e-1
endif
syn match texSpecialChar	"\\\\"
if !exists("g:tex_no_math")
 syn match texOnlyMath		"[_^]"
endif
syn match texSpecialChar	"\^\^[0-9a-f]\{2}\|\^\^\S"
if s:tex_conceal !~# 'S'
 syn match texSpecialChar	'\\glq\>'	contained conceal cchar=‚
 syn match texSpecialChar	'\\grq\>'	contained conceal cchar=‘
 syn match texSpecialChar	'\\glqq\>'	contained conceal cchar=„
 syn match texSpecialChar	'\\grqq\>'	contained conceal cchar=“
 syn match texSpecialChar	'\\hyp\>'	contained conceal cchar=-
endif

" Comments: {{{1
"    Normal TeX LaTeX     :   %....
"    Documented TeX Format:  ^^A...	-and-	leading %s (only)
if !s:tex_comment_nospell
 syn cluster texCommentGroup	contains=texTodo,@Spell
else
 syn cluster texCommentGroup	contains=texTodo,@NoSpell
endif
syn case ignore
syn keyword texTodo		contained		combak	fixme	todo	xxx
syn case match
if s:extfname == "dtx"
 syn match texComment		"\^\^A.*$"	contains=@texCommentGroup
 syn match texComment		"^%\+"		contains=@texCommentGroup
else
 if s:tex_fold_enabled
  " allows syntax-folding of 2 or more contiguous comment lines
  " single-line comments are not folded
  syn match  texComment	"%.*$"				contains=@texCommentGroup
  if s:tex_fast =~# 'c'
   TexFold syn region texComment						start="^\zs\s*%.*\_s*%"	skip="^\s*%"	end='^\ze\s*[^%]'	contains=@texCommentGroup
   TexFold syn region texNoSpell	contained	matchgroup=texComment	start="%\s*nospell\s*{"	end="%\s*nospell\s*}"			contains=@texFoldGroup,@NoSpell
  endif
 else
  syn match texComment		"%.*$"			contains=@texCommentGroup
  if s:tex_fast =~# 'c'
   syn region texNoSpell		contained	matchgroup=texComment start="%\s*nospell\s*{"	end="%\s*nospell\s*}"	contains=@texFoldGroup,@NoSpell
  endif
 endif
endif

" Separate lines used for verb` and verb# so that the end conditions {{{1
" will appropriately terminate.
" If g:tex_verbspell exists, then verbatim texZones will permit spellchecking there.
if s:tex_fast =~# 'v'
  if exists("g:tex_verbspell") && g:tex_verbspell
   syn region texZone		start="\\begin{[vV]erbatim}"		end="\\end{[vV]erbatim}\|%stopzone\>"	contains=@Spell
   " listings package:
   syn region texZone		start="\\begin{lstlisting}"		end="\\end{lstlisting}\|%stopzone\>"	contains=@Spell
   if b:tex_stylish
    syn region texZone		start="\\verb\*\=\z([^\ta-zA-Z@]\)"	end="\z1\|%stopzone\>"			contains=@Spell
   else
    syn region texZone		start="\\verb\*\=\z([^\ta-zA-Z]\)"	end="\z1\|%stopzone\>"			contains=@Spell
   endif
  else
   syn region texZone		start="\\begin{[vV]erbatim}"		end="\\end{[vV]erbatim}\|%stopzone\>"
   if b:tex_stylish
     syn region texZone		start="\\verb\*\=\z([^\ta-zA-Z@]\)"	end="\z1\|%stopzone\>"
   else
     syn region texZone		start="\\verb\*\=\z([^\ta-zA-Z]\)"	end="\z1\|%stopzone\>"
   endif
  endif
endif

" Tex Reference Zones: {{{1
if s:tex_fast =~# 'r'
  syn region texZone		matchgroup=texStatement start="@samp{"			end="}\|%stopzone\>"	contains=@texRefGroup
  syn region texRefZone		matchgroup=texStatement start="\\nocite{"		end="}\|%stopzone\>"	contains=@texRefGroup
  syn region texRefZone		matchgroup=texStatement start="\\bibliography{"		end="}\|%stopzone\>"	contains=@texRefGroup
  syn region texRefZone		matchgroup=texStatement start="\\label{"		end="}\|%stopzone\>"	contains=@texRefGroup
  syn region texRefZone		matchgroup=texStatement start="\\\(page\|eq\)ref{"	end="}\|%stopzone\>"	contains=@texRefGroup
  syn region texRefZone		matchgroup=texStatement start="\\v\=ref{"		end="}\|%stopzone\>"	contains=@texRefGroup
  syn region texRefOption	contained	matchgroup=Delimiter start='\[' end=']'		contains=@texRefGroup,texRefZone	nextgroup=texRefOption,texCite
  syn region texCite		contained	matchgroup=Delimiter start='{' end='}'		contains=@texRefGroup,texRefZone,texCite
endif
syn match  texRefZone		'\\cite\%([tp]\*\=\)\=' nextgroup=texRefOption,texCite

" Handle newcommand, newenvironment : {{{1
syn match  texNewCmd				"\\newcommand\>"			nextgroup=texCmdName skipwhite skipnl
if s:tex_fast =~# 'V'
  syn region texCmdName contained matchgroup=Delimiter start="{"rs=s+1  end="}"		nextgroup=texCmdArgs,texCmdBody skipwhite skipnl
  syn region texCmdArgs contained matchgroup=Delimiter start="\["rs=s+1 end="]"		nextgroup=texCmdBody skipwhite skipnl
  syn region texCmdBody contained matchgroup=Delimiter start="{"rs=s+1 skip="\\\\\|\\[{}]"	matchgroup=Delimiter end="}" contains=@texCmdGroup
endif
syn match  texNewEnv				"\\newenvironment\>"			nextgroup=texEnvName skipwhite skipnl
if s:tex_fast =~# 'V'
  syn region texEnvName contained matchgroup=Delimiter start="{"rs=s+1  end="}"		nextgroup=texEnvBgn skipwhite skipnl
  syn region texEnvBgn  contained matchgroup=Delimiter start="{"rs=s+1  end="}"		nextgroup=texEnvEnd skipwhite skipnl contains=@texEnvGroup
  syn region texEnvEnd  contained matchgroup=Delimiter start="{"rs=s+1  end="}"		skipwhite skipnl contains=@texEnvGroup
endif

" Definitions/Commands: {{{1
syn match texDefCmd				"\\def\>"				nextgroup=texDefName skipwhite skipnl
if b:tex_stylish
  syn match texDefName contained		"\\[a-zA-Z@]\+"				nextgroup=texDefParms,texCmdBody skipwhite skipnl
  syn match texDefName contained		"\\[^a-zA-Z@]"				nextgroup=texDefParms,texCmdBody skipwhite skipnl
else
  syn match texDefName contained		"\\\a\+"				nextgroup=texDefParms,texCmdBody skipwhite skipnl
  syn match texDefName contained		"\\\A"					nextgroup=texDefParms,texCmdBody skipwhite skipnl
endif
syn match texDefParms  contained		"#[^{]*"	contains=texDefParm	nextgroup=texCmdBody skipwhite skipnl
syn match  texDefParm  contained		"#\d\+"

" TeX Lengths: {{{1
syn match  texLength		"\<\d\+\([.,]\d\+\)\=\s*\(true\)\=\s*\(bp\|cc\|cm\|dd\|em\|ex\|in\|mm\|pc\|pt\|sp\)\>"

" TeX String Delimiters: {{{1
syn match texString		"\(``\|''\|,,\)"

" makeatletter -- makeatother sections
if !s:tex_no_error
 if s:tex_fast =~# 'S'
  syn region texStyle			matchgroup=texStatement start='\\makeatletter' end='\\makeatother'	contains=@texStyleGroup contained
 endif
 syn match  texStyleStatement		"\\[a-zA-Z@]\+"	contained
 if s:tex_fast =~# 'S'
  syn region texStyleMatcher		matchgroup=Delimiter start="{" skip="\\\\\|\\[{}]"	end="}"		contains=@texStyleGroup,texError	contained
  syn region texStyleMatcher		matchgroup=Delimiter start="\["				end="]"		contains=@texStyleGroup,texError	contained
 endif
endif

" Conceal mode support (supports set cole=2) {{{1
if has("conceal") && &enc == 'utf-8'

 " Math Symbols {{{2
 " (many of these symbols were contributed by Björn Winckler)
 if s:tex_conceal =~# 'm'
  let s:texMathList=[
    \ ['|'		, '‖'],
    \ ['aleph'		, 'ℵ'],
    \ ['amalg'		, '∐'],
    \ ['angle'		, '∠'],
    \ ['approx'		, '≈'],
    \ ['ast'		, '∗'],
    \ ['asymp'		, '≍'],
    \ ['backepsilon'	, '∍'],
    \ ['backsimeq'	, '≃'],
    \ ['backslash'	, '∖'],
    \ ['barwedge'	, '⊼'],
    \ ['because'	, '∵'],
    \ ['beth'           , 'ܒ'],
    \ ['between'	, '≬'],
    \ ['bigcap'		, '∩'],
    \ ['bigcirc'	, '○'],
    \ ['bigcup'		, '∪'],
    \ ['bigodot'	, '⊙'],
    \ ['bigoplus'	, '⊕'],
    \ ['bigotimes'	, '⊗'],
    \ ['bigsqcup'	, '⊔'],
    \ ['bigtriangledown', '∇'],
    \ ['bigtriangleup'	, '∆'],
    \ ['bigvee'		, '⋁'],
    \ ['bigwedge'	, '⋀'],
    \ ['blacksquare'	, '∎'],
    \ ['bot'		, '⊥'],
    \ ['bowtie'	        , '⋈'],
    \ ['boxdot'		, '⊡'],
    \ ['boxminus'	, '⊟'],
    \ ['boxplus'	, '⊞'],
    \ ['boxtimes'	, '⊠'],
    \ ['Box'            , '☐'],
    \ ['bullet'	        , '•'],
    \ ['bumpeq'		, '≏'],
    \ ['Bumpeq'		, '≎'],
    \ ['cap'		, '∩'],
    \ ['Cap'		, '⋒'],
    \ ['cdot'		, '·'],
    \ ['cdots'		, '⋯'],
    \ ['circ'		, '∘'],
    \ ['circeq'		, '≗'],
    \ ['circlearrowleft', '↺'],
    \ ['circlearrowright', '↻'],
    \ ['circledast'	, '⊛'],
    \ ['circledcirc'	, '⊚'],
    \ ['clubsuit'	, '♣'],
    \ ['complement'	, '∁'],
    \ ['cong'		, '≅'],
    \ ['coprod'		, '∐'],
    \ ['copyright'	, '©'],
    \ ['cup'		, '∪'],
    \ ['Cup'		, '⋓'],
    \ ['curlyeqprec'	, '⋞'],
    \ ['curlyeqsucc'	, '⋟'],
    \ ['curlyvee'	, '⋎'],
    \ ['curlywedge'	, '⋏'],
    \ ['dagger'	        , '†'],
    \ ['dashv'		, '⊣'],
    \ ['ddagger'	, '‡'],
    \ ['ddots'	        , '⋱'],
    \ ['diamond'	, '⋄'],
    \ ['diamondsuit'	, '♢'],
    \ ['div'		, '÷'],
    \ ['doteq'		, '≐'],
    \ ['doteqdot'	, '≑'],
    \ ['dotplus'	, '∔'],
    \ ['dots'		, '…'],
    \ ['dotsb'		, '⋯'],
    \ ['dotsc'		, '…'],
    \ ['dotsi'		, '⋯'],
    \ ['dotso'		, '…'],
    \ ['doublebarwedge'	, '⩞'],
    \ ['downarrow'	, '↓'],
    \ ['Downarrow'	, '⇓'],
    \ ['ell'		, 'ℓ'],
    \ ['emptyset'	, '∅'],
    \ ['eqcirc'		, '≖'],
    \ ['eqsim'		, '≂'],
    \ ['eqslantgtr'	, '⪖'],
    \ ['eqslantless'	, '⪕'],
    \ ['equiv'		, '≡'],
    \ ['eth'            , 'ð'],
    \ ['exists'		, '∃'],
    \ ['fallingdotseq'	, '≒'],
    \ ['flat'		, '♭'],
    \ ['forall'		, '∀'],
    \ ['frown'		, '⁔'],
    \ ['ge'		, '≥'],
    \ ['geq'		, '≥'],
    \ ['geqq'		, '≧'],
    \ ['gets'		, '←'],
    \ ['gimel'          , 'ℷ'],
    \ ['gg'		, '⟫'],
    \ ['gneqq'		, '≩'],
    \ ['gtrdot'		, '⋗'],
    \ ['gtreqless'	, '⋛'],
    \ ['gtrless'	, '≷'],
    \ ['gtrsim'		, '≳'],
    \ ['hbar'		, 'ℏ'],
    \ ['heartsuit'	, '♡'],
    \ ['hookleftarrow'	, '↩'],
    \ ['hookrightarrow'	, '↪'],
    \ ['iff'            , '⇔'],
    \ ['iiint'		, '∭'],
    \ ['iint'		, '∬'],
    \ ['Im'		, 'ℑ'],
    \ ['imath'		, 'ɩ'],
    \ ['implies'	, '⇒'],
    \ ['in'		, '∈'],
    \ ['infty'		, '∞'],
    \ ['int'		, '∫'],
    \ ['jmath'		, '𝚥'],
    \ ['land'		, '∧'],
    \ ['lceil'		, '⌈'],
    \ ['ldots'		, '…'],
    \ ['le'		, '≤'],
    \ ['leadsto'	, '↝'],
    \ ['left('		, '('],
    \ ['left\['		, '['],
    \ ['left\\{'	, '{'],
    \ ['leftarrow'	, '←'],
    \ ['Leftarrow'	, '⇐'],
    \ ['leftarrowtail'	, '↢'],
    \ ['leftharpoondown', '↽'],
    \ ['leftharpoonup'	, '↼'],
    \ ['leftrightarrow'	, '↔'],
    \ ['Leftrightarrow'	, '⇔'],
    \ ['leftrightsquigarrow', '↭'],
    \ ['leftthreetimes'	, '⋋'],
    \ ['leq'		, '≤'],
    \ ['leq'		, '≤'],
    \ ['leqq'		, '≦'],
    \ ['lessdot'	, '⋖'],
    \ ['lesseqgtr'	, '⋚'],
    \ ['lesssim'	, '≲'],
    \ ['lfloor'		, '⌊'],
    \ ['ll'		, '≪'],
    \ ['lmoustache'     , '╭'],
    \ ['lneqq'		, '≨'],
    \ ['lor'		, '∨'],
    \ ['ltimes'		, '⋉'],
    \ ['mapsto'		, '↦'],
    \ ['measuredangle'	, '∡'],
    \ ['mid'		, '∣'],
    \ ['models'		, '╞'],
    \ ['mp'		, '∓'],
    \ ['nabla'		, '∇'],
    \ ['natural'	, '♮'],
    \ ['ncong'		, '≇'],
    \ ['ne'		, '≠'],
    \ ['nearrow'	, '↗'],
    \ ['neg'		, '¬'],
    \ ['neq'		, '≠'],
    \ ['nexists'	, '∄'],
    \ ['ngeq'		, '≱'],
    \ ['ngeqq'		, '≱'],
    \ ['ngtr'		, '≯'],
    \ ['ni'		, '∋'],
    \ ['nleftarrow'	, '↚'],
    \ ['nLeftarrow'	, '⇍'],
    \ ['nLeftrightarrow', '⇎'],
    \ ['nleq'		, '≰'],
    \ ['nleqq'		, '≰'],
    \ ['nless'		, '≮'],
    \ ['nmid'		, '∤'],
    \ ['notin'		, '∉'],
    \ ['nparallel'      , '∦'],
    \ ['nprec'		, '⊀'],
    \ ['nrightarrow'	, '↛'],
    \ ['nRightarrow'	, '⇏'],
    \ ['nsim'		, '≁'],
    \ ['nsucc'		, '⊁'],
    \ ['ntriangleleft'	, '⋪'],
    \ ['ntrianglelefteq', '⋬'],
    \ ['ntriangleright'	, '⋫'],
    \ ['ntrianglerighteq', '⋭'],
    \ ['nvdash'		, '⊬'],
    \ ['nvDash'		, '⊭'],
    \ ['nVdash'		, '⊮'],
    \ ['nwarrow'	, '↖'],
    \ ['odot'		, '⊙'],
    \ ['oint'		, '∮'],
    \ ['ominus'		, '⊖'],
    \ ['oplus'		, '⊕'],
    \ ['oslash'		, '⊘'],
    \ ['otimes'		, '⊗'],
    \ ['owns'		, '∋'],
    \ ['P'	        , '¶'],
    \ ['parallel'	, '║'],
    \ ['partial'	, '∂'],
    \ ['perp'		, '⊥'],
    \ ['pitchfork'	, '⋔'],
    \ ['pm'		, '±'],
    \ ['prec'		, '≺'],
    \ ['precapprox'	, '⪷'],
    \ ['preccurlyeq'	, '≼'],
    \ ['preceq'		, '⪯'],
    \ ['precnapprox'	, '⪹'],
    \ ['precneqq'	, '⪵'],
    \ ['precsim'	, '≾'],
    \ ['prime'		, '′'],
    \ ['prod'		, '∏'],
    \ ['propto'		, '∝'],
    \ ['rceil'		, '⌉'],
    \ ['Re'		, 'ℜ'],
    \ ['rfloor'		, '⌋'],
    \ ['right)'		, ')'],
    \ ['right]'		, ']'],
    \ ['right\\}'	, '}'],
    \ ['rightarrow'	, '→'],
    \ ['Rightarrow'	, '⇒'],
    \ ['rightarrowtail'	, '↣'],
    \ ['rightleftharpoons', '⇌'],
    \ ['rightsquigarrow', '↝'],
    \ ['rightthreetimes', '⋌'],
    \ ['risingdotseq'	, '≓'],
    \ ['rmoustache'     , '╮'],
    \ ['rtimes'		, '⋊'],
    \ ['S'	        , '§'],
    \ ['searrow'	, '↘'],
    \ ['setminus'	, '∖'],
    \ ['sharp'		, '♯'],
    \ ['sim'		, '∼'],
    \ ['simeq'		, '⋍'],
    \ ['smile'		, '‿'],
    \ ['spadesuit'	, '♠'],
    \ ['sphericalangle'	, '∢'],
    \ ['sqcap'		, '⊓'],
    \ ['sqcup'		, '⊔'],
    \ ['sqsubset'	, '⊏'],
    \ ['sqsubseteq'	, '⊑'],
    \ ['sqsupset'	, '⊐'],
    \ ['sqsupseteq'	, '⊒'],
    \ ['star'		, '✫'],
    \ ['subset'		, '⊂'],
    \ ['Subset'		, '⋐'],
    \ ['subseteq'	, '⊆'],
    \ ['subseteqq'	, '⫅'],
    \ ['subsetneq'	, '⊊'],
    \ ['subsetneqq'	, '⫋'],
    \ ['succ'		, '≻'],
    \ ['succapprox'	, '⪸'],
    \ ['succcurlyeq'	, '≽'],
    \ ['succeq'		, '⪰'],
    \ ['succnapprox'	, '⪺'],
    \ ['succneqq'	, '⪶'],
    \ ['succsim'	, '≿'],
    \ ['sum'		, '∑'],
    \ ['supset'		, '⊃'],
    \ ['Supset'		, '⋑'],
    \ ['supseteq'	, '⊇'],
    \ ['supseteqq'	, '⫆'],
    \ ['supsetneq'	, '⊋'],
    \ ['supsetneqq'	, '⫌'],
    \ ['surd'		, '√'],
    \ ['swarrow'	, '↙'],
    \ ['therefore'	, '∴'],
    \ ['times'		, '×'],
    \ ['to'		, '→'],
    \ ['top'		, '⊤'],
    \ ['triangle'	, '∆'],
    \ ['triangleleft'	, '⊲'],
    \ ['trianglelefteq'	, '⊴'],
    \ ['triangleq'	, '≜'],
    \ ['triangleright'	, '⊳'],
    \ ['trianglerighteq', '⊵'],
    \ ['twoheadleftarrow', '↞'],
    \ ['twoheadrightarrow', '↠'],
    \ ['ulcorner'       , '⌜'],
    \ ['uparrow'	, '↑'],
    \ ['Uparrow'	, '⇑'],
    \ ['updownarrow'	, '↕'],
    \ ['Updownarrow'	, '⇕'],
    \ ['urcorner'       , '⌝'],
    \ ['varnothing'	, '∅'],
    \ ['vartriangle'	, '∆'],
    \ ['vdash'		, '⊢'],
    \ ['vDash'		, '⊨'],
    \ ['Vdash'		, '⊩'],
    \ ['vdots'		, '⋮'],
    \ ['vee'		, '∨'],
    \ ['veebar'		, '⊻'],
    \ ['Vvdash'		, '⊪'],
    \ ['wedge'		, '∧'],
    \ ['wp'		, '℘'],
    \ ['wr'		, '≀']]
"    \ ['jmath'		, 'X']
"    \ ['uminus'	, 'X']
"    \ ['uplus'		, 'X']
  if &ambw == "double" || exists("g:tex_usedblwidth")
    let s:texMathList= s:texMathList + [
    \ ['right\\rangle'	, '〉'],
    \ ['left\\langle'	, '〈']]
  else
    let s:texMathList= s:texMathList + [
    \ ['right\\rangle'	, '>'],
    \ ['left\\langle'	, '<']]
  endif
  for texmath in s:texMathList
   if texmath[0] =~# '\w$'
    exe "syn match texMathSymbol '\\\\".texmath[0]."\\>' contained conceal cchar=".texmath[1]
   else
    exe "syn match texMathSymbol '\\\\".texmath[0]."' contained conceal cchar=".texmath[1]
   endif
  endfor

  if &ambw == "double"
   syn match texMathSymbol '\\gg\>'			contained conceal cchar=≫
   syn match texMathSymbol '\\ll\>'			contained conceal cchar=≪
  else
   syn match texMathSymbol '\\gg\>'			contained conceal cchar=⟫
   syn match texMathSymbol '\\ll\>'			contained conceal cchar=⟪
  endif

  syn match texMathSymbol '\\hat{a}' contained conceal cchar=â
  syn match texMathSymbol '\\hat{A}' contained conceal cchar=Â
  syn match texMathSymbol '\\hat{c}' contained conceal cchar=ĉ
  syn match texMathSymbol '\\hat{C}' contained conceal cchar=Ĉ
  syn match texMathSymbol '\\hat{e}' contained conceal cchar=ê
  syn match texMathSymbol '\\hat{E}' contained conceal cchar=Ê
  syn match texMathSymbol '\\hat{g}' contained conceal cchar=ĝ
  syn match texMathSymbol '\\hat{G}' contained conceal cchar=Ĝ
  syn match texMathSymbol '\\hat{i}' contained conceal cchar=î
  syn match texMathSymbol '\\hat{I}' contained conceal cchar=Î
  syn match texMathSymbol '\\hat{o}' contained conceal cchar=ô
  syn match texMathSymbol '\\hat{O}' contained conceal cchar=Ô
  syn match texMathSymbol '\\hat{s}' contained conceal cchar=ŝ
  syn match texMathSymbol '\\hat{S}' contained conceal cchar=Ŝ
  syn match texMathSymbol '\\hat{u}' contained conceal cchar=û
  syn match texMathSymbol '\\hat{U}' contained conceal cchar=Û
  syn match texMathSymbol '\\hat{w}' contained conceal cchar=ŵ
  syn match texMathSymbol '\\hat{W}' contained conceal cchar=Ŵ
  syn match texMathSymbol '\\hat{y}' contained conceal cchar=ŷ
  syn match texMathSymbol '\\hat{Y}' contained conceal cchar=Ŷ
"  syn match texMathSymbol '\\bar{a}' contained conceal cchar=a̅
 endif

 " Greek {{{2
 if s:tex_conceal =~# 'g'
  fun! s:Greek(group,pat,cchar)
    exe 'syn match '.a:group." '".a:pat."' contained conceal cchar=".a:cchar
  endfun
  call s:Greek('texGreek','\\alpha\>'		,'α')
  call s:Greek('texGreek','\\beta\>'		,'β')
  call s:Greek('texGreek','\\gamma\>'		,'γ')
  call s:Greek('texGreek','\\delta\>'		,'δ')
  call s:Greek('texGreek','\\epsilon\>'		,'ϵ')
  call s:Greek('texGreek','\\varepsilon\>'	,'ε')
  call s:Greek('texGreek','\\zeta\>'		,'ζ')
  call s:Greek('texGreek','\\eta\>'		,'η')
  call s:Greek('texGreek','\\theta\>'		,'θ')
  call s:Greek('texGreek','\\vartheta\>'	,'ϑ')
  call s:Greek('texGreek','\\kappa\>'		,'κ')
  call s:Greek('texGreek','\\lambda\>'		,'λ')
  call s:Greek('texGreek','\\mu\>'		,'μ')
  call s:Greek('texGreek','\\nu\>'		,'ν')
  call s:Greek('texGreek','\\xi\>'		,'ξ')
  call s:Greek('texGreek','\\pi\>'		,'π')
  call s:Greek('texGreek','\\varpi\>'		,'ϖ')
  call s:Greek('texGreek','\\rho\>'		,'ρ')
  call s:Greek('texGreek','\\varrho\>'		,'ϱ')
  call s:Greek('texGreek','\\sigma\>'		,'σ')
  call s:Greek('texGreek','\\varsigma\>'	,'ς')
  call s:Greek('texGreek','\\tau\>'		,'τ')
  call s:Greek('texGreek','\\upsilon\>'		,'υ')
  call s:Greek('texGreek','\\phi\>'		,'ϕ')
  call s:Greek('texGreek','\\varphi\>'		,'φ')
  call s:Greek('texGreek','\\chi\>'		,'χ')
  call s:Greek('texGreek','\\psi\>'		,'ψ')
  call s:Greek('texGreek','\\omega\>'		,'ω')
  call s:Greek('texGreek','\\Gamma\>'		,'Γ')
  call s:Greek('texGreek','\\Delta\>'		,'Δ')
  call s:Greek('texGreek','\\Theta\>'		,'Θ')
  call s:Greek('texGreek','\\Lambda\>'		,'Λ')
  call s:Greek('texGreek','\\Xi\>'		,'Χ')
  call s:Greek('texGreek','\\Pi\>'		,'Π')
  call s:Greek('texGreek','\\Sigma\>'		,'Σ')
  call s:Greek('texGreek','\\Upsilon\>'		,'Υ')
  call s:Greek('texGreek','\\Phi\>'		,'Φ')
  call s:Greek('texGreek','\\Psi\>'		,'Ψ')
  call s:Greek('texGreek','\\Omega\>'		,'Ω')
  delfun s:Greek
 endif

 " Superscripts/Subscripts {{{2
 if s:tex_conceal =~# 's'
  if s:tex_fast =~# 's'
   syn region texSuperscript	matchgroup=Delimiter start='\^{'	skip="\\\\\|\\[{}]" end='}'	contained concealends contains=texSpecialChar,texSuperscripts,texStatement,texSubscript,texSuperscript,texMathMatcher
   syn region texSubscript	matchgroup=Delimiter start='_{'		skip="\\\\\|\\[{}]" end='}'	contained concealends contains=texSpecialChar,texSubscripts,texStatement,texSubscript,texSuperscript,texMathMatcher
  endif
  " s:SuperSub:
  fun! s:SuperSub(group,leader,pat,cchar)
    if a:pat =~# '^\\' || (a:leader == '\^' && a:pat =~# s:tex_superscripts) || (a:leader == '_' && a:pat =~# s:tex_subscripts)
"     call Decho("SuperSub: group<".a:group."> leader<".a:leader."> pat<".a:pat."> cchar<".a:cchar.">")
     exe 'syn match '.a:group." '".a:leader.a:pat."' contained conceal cchar=".a:cchar
     exe 'syn match '.a:group."s '".a:pat        ."' contained conceal cchar=".a:cchar.' nextgroup='.a:group.'s'
    endif
  endfun
  call s:SuperSub('texSuperscript','\^','0','⁰')
  call s:SuperSub('texSuperscript','\^','1','¹')
  call s:SuperSub('texSuperscript','\^','2','²')
  call s:SuperSub('texSuperscript','\^','3','³')
  call s:SuperSub('texSuperscript','\^','4','⁴')
  call s:SuperSub('texSuperscript','\^','5','⁵')
  call s:SuperSub('texSuperscript','\^','6','⁶')
  call s:SuperSub('texSuperscript','\^','7','⁷')
  call s:SuperSub('texSuperscript','\^','8','⁸')
  call s:SuperSub('texSuperscript','\^','9','⁹')
  call s:SuperSub('texSuperscript','\^','a','ᵃ')
  call s:SuperSub('texSuperscript','\^','b','ᵇ')
  call s:SuperSub('texSuperscript','\^','c','ᶜ')
  call s:SuperSub('texSuperscript','\^','d','ᵈ')
  call s:SuperSub('texSuperscript','\^','e','ᵉ')
  call s:SuperSub('texSuperscript','\^','f','ᶠ')
  call s:SuperSub('texSuperscript','\^','g','ᵍ')
  call s:SuperSub('texSuperscript','\^','h','ʰ')
  call s:SuperSub('texSuperscript','\^','i','ⁱ')
  call s:SuperSub('texSuperscript','\^','j','ʲ')
  call s:SuperSub('texSuperscript','\^','k','ᵏ')
  call s:SuperSub('texSuperscript','\^','l','ˡ')
  call s:SuperSub('texSuperscript','\^','m','ᵐ')
  call s:SuperSub('texSuperscript','\^','n','ⁿ')
  call s:SuperSub('texSuperscript','\^','o','ᵒ')
  call s:SuperSub('texSuperscript','\^','p','ᵖ')
  call s:SuperSub('texSuperscript','\^','r','ʳ')
  call s:SuperSub('texSuperscript','\^','s','ˢ')
  call s:SuperSub('texSuperscript','\^','t','ᵗ')
  call s:SuperSub('texSuperscript','\^','u','ᵘ')
  call s:SuperSub('texSuperscript','\^','v','ᵛ')
  call s:SuperSub('texSuperscript','\^','w','ʷ')
  call s:SuperSub('texSuperscript','\^','x','ˣ')
  call s:SuperSub('texSuperscript','\^','y','ʸ')
  call s:SuperSub('texSuperscript','\^','z','ᶻ')
  call s:SuperSub('texSuperscript','\^','A','ᴬ')
  call s:SuperSub('texSuperscript','\^','B','ᴮ')
  call s:SuperSub('texSuperscript','\^','D','ᴰ')
  call s:SuperSub('texSuperscript','\^','E','ᴱ')
  call s:SuperSub('texSuperscript','\^','G','ᴳ')
  call s:SuperSub('texSuperscript','\^','H','ᴴ')
  call s:SuperSub('texSuperscript','\^','I','ᴵ')
  call s:SuperSub('texSuperscript','\^','J','ᴶ')
  call s:SuperSub('texSuperscript','\^','K','ᴷ')
  call s:SuperSub('texSuperscript','\^','L','ᴸ')
  call s:SuperSub('texSuperscript','\^','M','ᴹ')
  call s:SuperSub('texSuperscript','\^','N','ᴺ')
  call s:SuperSub('texSuperscript','\^','O','ᴼ')
  call s:SuperSub('texSuperscript','\^','P','ᴾ')
  call s:SuperSub('texSuperscript','\^','R','ᴿ')
  call s:SuperSub('texSuperscript','\^','T','ᵀ')
  call s:SuperSub('texSuperscript','\^','U','ᵁ')
  call s:SuperSub('texSuperscript','\^','W','ᵂ')
  call s:SuperSub('texSuperscript','\^',',','︐')
  call s:SuperSub('texSuperscript','\^',':','︓')
  call s:SuperSub('texSuperscript','\^',';','︔')
  call s:SuperSub('texSuperscript','\^','+','⁺')
  call s:SuperSub('texSuperscript','\^','-','⁻')
  call s:SuperSub('texSuperscript','\^','<','˂')
  call s:SuperSub('texSuperscript','\^','>','˃')
  call s:SuperSub('texSuperscript','\^','/','ˊ')
  call s:SuperSub('texSuperscript','\^','(','⁽')
  call s:SuperSub('texSuperscript','\^',')','⁾')
  call s:SuperSub('texSuperscript','\^','\.','˙')
  call s:SuperSub('texSuperscript','\^','=','˭')
  call s:SuperSub('texSubscript','_','0','₀')
  call s:SuperSub('texSubscript','_','1','₁')
  call s:SuperSub('texSubscript','_','2','₂')
  call s:SuperSub('texSubscript','_','3','₃')
  call s:SuperSub('texSubscript','_','4','₄')
  call s:SuperSub('texSubscript','_','5','₅')
  call s:SuperSub('texSubscript','_','6','₆')
  call s:SuperSub('texSubscript','_','7','₇')
  call s:SuperSub('texSubscript','_','8','₈')
  call s:SuperSub('texSubscript','_','9','₉')
  call s:SuperSub('texSubscript','_','a','ₐ')
  call s:SuperSub('texSubscript','_','e','ₑ')
  call s:SuperSub('texSubscript','_','h','ₕ')
  call s:SuperSub('texSubscript','_','i','ᵢ')
  call s:SuperSub('texSubscript','_','j','ⱼ')
  call s:SuperSub('texSubscript','_','k','ₖ')
  call s:SuperSub('texSubscript','_','l','ₗ')
  call s:SuperSub('texSubscript','_','m','ₘ')
  call s:SuperSub('texSubscript','_','n','ₙ')
  call s:SuperSub('texSubscript','_','o','ₒ')
  call s:SuperSub('texSubscript','_','p','ₚ')
  call s:SuperSub('texSubscript','_','r','ᵣ')
  call s:SuperSub('texSubscript','_','s','ₛ')
  call s:SuperSub('texSubscript','_','t','ₜ')
  call s:SuperSub('texSubscript','_','u','ᵤ')
  call s:SuperSub('texSubscript','_','v','ᵥ')
  call s:SuperSub('texSubscript','_','x','ₓ')
  call s:SuperSub('texSubscript','_',',','︐')
  call s:SuperSub('texSubscript','_','+','₊')
  call s:SuperSub('texSubscript','_','-','₋')
  call s:SuperSub('texSubscript','_','/','ˏ')
  call s:SuperSub('texSubscript','_','(','₍')
  call s:SuperSub('texSubscript','_',')','₎')
  call s:SuperSub('texSubscript','_','\.','‸')
  call s:SuperSub('texSubscript','_','r','ᵣ')
  call s:SuperSub('texSubscript','_','v','ᵥ')
  call s:SuperSub('texSubscript','_','x','ₓ')
  call s:SuperSub('texSubscript','_','\\beta\>' ,'ᵦ')
  call s:SuperSub('texSubscript','_','\\delta\>','ᵨ')
  call s:SuperSub('texSubscript','_','\\phi\>'  ,'ᵩ')
  call s:SuperSub('texSubscript','_','\\gamma\>','ᵧ')
  call s:SuperSub('texSubscript','_','\\chi\>'  ,'ᵪ')

  delfun s:SuperSub
 endif

 " Accented characters: {{{2
 if s:tex_conceal =~# 'a'
  if b:tex_stylish
   syn match texAccent		"\\[bcdvuH][^a-zA-Z@]"me=e-1
   syn match texLigature		"\\\([ijolL]\|ae\|oe\|ss\|AA\|AE\|OE\)[^a-zA-Z@]"me=e-1
  else
   fun! s:Accents(chr,...)
     let i= 1
     for accent in ["`","\\'","^",'"','\~','\.','=',"c","H","k","r","u","v"]
      if i > a:0
       break
      endif
      if strlen(a:{i}) == 0 || a:{i} == ' ' || a:{i} == '?'
       let i= i + 1
       continue
      endif
      if accent =~# '\a'
       exe "syn match texAccent '".'\\'.accent.'\(\s*{'.a:chr.'}\|\s\+'.a:chr.'\)'."' conceal cchar=".a:{i}
      else
       exe "syn match texAccent '".'\\'.accent.'\s*\({'.a:chr.'}\|'.a:chr.'\)'."' conceal cchar=".a:{i}
      endif
      let i= i + 1
     endfor
   endfun
   "                  \`  \'  \^  \"  \~  \.  \=  \c  \H  \k  \r  \u  \v
   call s:Accents('a','à','á','â','ä','ã','ȧ','ā',' ',' ','ą','å','ă','ǎ')
   call s:Accents('A','À','Á','Â','Ä','Ã','Ȧ','Ā',' ',' ','Ą','Å','Ă','Ǎ')
   call s:Accents('c',' ','ć','ĉ',' ',' ','ċ',' ','ç',' ',' ',' ',' ','č')
   call s:Accents('C',' ','Ć','Ĉ',' ',' ','Ċ',' ','Ç',' ',' ',' ',' ','Č')
   call s:Accents('d',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ','ď')
   call s:Accents('D',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ','Ď')
   call s:Accents('e','è','é','ê','ë','ẽ','ė','ē','ȩ',' ','ę',' ','ĕ','ě')
   call s:Accents('E','È','É','Ê','Ë','Ẽ','Ė','Ē','Ȩ',' ','Ę',' ','Ĕ','Ě')
   call s:Accents('g',' ','ǵ','ĝ',' ',' ','ġ',' ','ģ',' ',' ',' ','ğ','ǧ')
   call s:Accents('G',' ','Ǵ','Ĝ',' ',' ','Ġ',' ','Ģ',' ',' ',' ','Ğ','Ǧ')
   call s:Accents('h',' ',' ','ĥ',' ',' ',' ',' ',' ',' ',' ',' ',' ','ȟ')
   call s:Accents('H',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ','Ȟ')
   call s:Accents('i','ì','í','î','ï','ĩ','į','ī',' ',' ','į',' ','ĭ','ǐ')
   call s:Accents('I','Ì','Í','Î','Ï','Ĩ','İ','Ī',' ',' ','Į',' ','Ĭ','Ǐ')
   call s:Accents('J',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ','ǰ')
   call s:Accents('k',' ',' ',' ',' ',' ',' ',' ','ķ',' ',' ',' ',' ','ǩ')
   call s:Accents('K',' ',' ',' ',' ',' ',' ',' ','Ķ',' ',' ',' ',' ','Ǩ')
   call s:Accents('l',' ','ĺ','ľ',' ',' ',' ',' ','ļ',' ',' ',' ',' ','ľ')
   call s:Accents('L',' ','Ĺ','Ľ',' ',' ',' ',' ','Ļ',' ',' ',' ',' ','Ľ')
   call s:Accents('n',' ','ń',' ',' ','ñ',' ',' ','ņ',' ',' ',' ',' ','ň')
   call s:Accents('N',' ','Ń',' ',' ','Ñ',' ',' ','Ņ',' ',' ',' ',' ','Ň')
   call s:Accents('o','ò','ó','ô','ö','õ','ȯ','ō',' ','ő','ǫ',' ','ŏ','ǒ')
   call s:Accents('O','Ò','Ó','Ô','Ö','Õ','Ȯ','Ō',' ','Ő','Ǫ',' ','Ŏ','Ǒ')
   call s:Accents('r',' ','ŕ',' ',' ',' ',' ',' ','ŗ',' ',' ',' ',' ','ř')
   call s:Accents('R',' ','Ŕ',' ',' ',' ',' ',' ','Ŗ',' ',' ',' ',' ','Ř')
   call s:Accents('s',' ','ś','ŝ',' ',' ',' ',' ','ş',' ','ȿ',' ',' ','š')
   call s:Accents('S',' ','Ś','Ŝ',' ',' ',' ',' ','Ş',' ',' ',' ',' ','Š')
   call s:Accents('t',' ',' ',' ',' ',' ',' ',' ','ţ',' ',' ',' ',' ','ť')
   call s:Accents('T',' ',' ',' ',' ',' ',' ',' ','Ţ',' ',' ',' ',' ','Ť')
   call s:Accents('u','ù','ú','û','ü','ũ',' ','ū',' ','ű','ų','ů','ŭ','ǔ')
   call s:Accents('U','Ù','Ú','Û','Ü','Ũ',' ','Ū',' ','Ű','Ų','Ů','Ŭ','Ǔ')
   call s:Accents('w',' ',' ','ŵ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ')
   call s:Accents('W',' ',' ','Ŵ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ')
   call s:Accents('y','ỳ','ý','ŷ','ÿ','ỹ',' ',' ',' ',' ',' ',' ',' ',' ')
   call s:Accents('Y','Ỳ','Ý','Ŷ','Ÿ','Ỹ',' ',' ',' ',' ',' ',' ',' ',' ')
   call s:Accents('z',' ','ź',' ',' ',' ','ż',' ',' ',' ',' ',' ',' ','ž')
   call s:Accents('Z',' ','Ź',' ',' ',' ','Ż',' ',' ',' ',' ',' ',' ','Ž')
   call s:Accents('\\i','ì','í','î','ï','ĩ','į',' ',' ',' ',' ',' ','ĭ',' ')
   "                    \`  \'  \^  \"  \~  \.  \=  \c  \H  \k  \r  \u  \v
   delfun s:Accents
   syn match texAccent   '\\aa\>'	conceal cchar=å
   syn match texAccent   '\\AA\>'	conceal cchar=Å
   syn match texAccent	'\\o\>'		conceal cchar=ø
   syn match texAccent	'\\O\>'		conceal cchar=Ø
   syn match texLigature	'\\AE\>'	conceal cchar=Æ
   syn match texLigature	'\\ae\>'	conceal cchar=æ
   syn match texLigature	'\\oe\>'	conceal cchar=œ
   syn match texLigature	'\\OE\>'	conceal cchar=Œ
   syn match texLigature	'\\ss\>'	conceal cchar=ß
  endif
 endif
endif

" ---------------------------------------------------------------------
" LaTeX synchronization: {{{1
syn sync maxlines=200
syn sync minlines=50

syn  sync match texSyncStop			groupthere NONE		"%stopzone\>"

" Synchronization: {{{1
" The $..$ and $$..$$ make for impossible sync patterns
" (one can't tell if a "$$" starts or stops a math zone by itself)
" The following grouptheres coupled with minlines above
" help improve the odds of good syncing.
if !exists("g:tex_no_math")
 syn sync match texSyncMathZoneA		groupthere NONE		"\\end{abstract}"
 syn sync match texSyncMathZoneA		groupthere NONE		"\\end{center}"
 syn sync match texSyncMathZoneA		groupthere NONE		"\\end{description}"
 syn sync match texSyncMathZoneA		groupthere NONE		"\\end{enumerate}"
 syn sync match texSyncMathZoneA		groupthere NONE		"\\end{itemize}"
 syn sync match texSyncMathZoneA		groupthere NONE		"\\end{table}"
 syn sync match texSyncMathZoneA		groupthere NONE		"\\end{tabular}"
 syn sync match texSyncMathZoneA		groupthere NONE		"\\\(sub\)*section\>"
endif

" ---------------------------------------------------------------------
" Highlighting: {{{1

" Define the default highlighting. {{{1
if !exists("skip_tex_syntax_inits")

  " TeX highlighting groups which should share similar highlighting
  if !exists("g:tex_no_error")
   if !exists("g:tex_no_math")
    hi def link texBadMath		texError
    hi def link texMathDelimBad		texError
    hi def link texMathError		texError
    if !b:tex_stylish
      hi def link texOnlyMath		texError
    endif
   endif
   hi def link texError			Error
  endif

  hi texBoldStyle		gui=bold	cterm=bold
  hi texItalStyle		gui=italic	cterm=italic
  hi texBoldItalStyle		gui=bold,italic cterm=bold,italic
  hi texItalBoldStyle		gui=bold,italic cterm=bold,italic
  hi def link texCite		texRefZone
  hi def link texDefCmd		texDef
  hi def link texDefName	texDef
  hi def link texDocType	texCmdName
  hi def link texDocTypeArgs	texCmdArgs
  hi def link texInputFileOpt	texCmdArgs
  hi def link texInputCurlies	texDelimiter
  hi def link texLigature	texSpecialChar
  if !exists("g:tex_no_math")
   hi def link texMathDelimSet1	texMathDelim
   hi def link texMathDelimSet2	texMathDelim
   hi def link texMathDelimKey	texMathDelim
   hi def link texMathMatcher	texMath
   hi def link texAccent	texStatement
   hi def link texGreek		texStatement
   hi def link texSuperscript	texStatement
   hi def link texSubscript	texStatement
   hi def link texSuperscripts 	texSuperscript
   hi def link texSubscripts 	texSubscript
   hi def link texMathSymbol	texStatement
   hi def link texMathZoneV	texMath
   hi def link texMathZoneW	texMath
   hi def link texMathZoneX	texMath
   hi def link texMathZoneY	texMath
   hi def link texMathZoneV	texMath
   hi def link texMathZoneZ	texMath
  endif
  hi def link texBeginEnd	texCmdName
  hi def link texBeginEndName	texSection
  hi def link texSpaceCode	texStatement
  hi def link texStyleStatement	texStatement
  hi def link texTypeSize	texType
  hi def link texTypeStyle	texType

   " Basic TeX highlighting groups
  hi def link texCmdArgs	Number
  hi def link texCmdName	Statement
  hi def link texComment	Comment
  hi def link texDef		Statement
  hi def link texDefParm	Special
  hi def link texDelimiter	Delimiter
  hi def link texInput		Special
  hi def link texInputFile	Special
  hi def link texLength		Number
  hi def link texMath		Special
  hi def link texMathDelim	Statement
  hi def link texMathOper	Operator
  hi def link texNewCmd		Statement
  hi def link texNewEnv		Statement
  hi def link texOption		Number
  hi def link texRefZone	Special
  hi def link texSection	PreCondit
  hi def link texSpaceCodeChar	Special
  hi def link texSpecialChar	SpecialChar
  hi def link texStatement	Statement
  hi def link texString		String
  hi def link texTodo		Todo
  hi def link texType		Type
  hi def link texZone		PreCondit

endif

" Cleanup: {{{1
delc TexFold
unlet s:extfname
let   b:current_syntax = "tex"
let &cpo               = s:keepcpo
unlet s:keepcpo
" vim: ts=8 fdm=marker
