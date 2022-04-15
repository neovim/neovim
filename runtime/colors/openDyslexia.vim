" Colorscheme for vim/nvim 
" Provides easier readabillity for dyslexia
" Languages supported:
" Java, JavaScript, shell, Python, C, C++, C#, Ruby, Go, PHP, vim script, 
" Matlab, Rust, YAML, CSS, HTML, and others that have these general syntax rules

set background=dark

hi clear

if exists("syntax_on")
	syntax reset	
endif

let colors_name = "openDyslexia"

" General colors
hi Normal           guifg=#f6f3e8     guibg=black       gui=NONE      ctermfg=white       ctermbg=NONE        cterm=NONE
hi NonText          guifg=#070707     guibg=black       gui=NONE      ctermfg=black       ctermbg=NONE        cterm=NONE

hi Cursor           guifg=black       guibg=white       gui=NONE      ctermfg=black       ctermbg=white       cterm=reverse
hi LineNr           guifg=#3D3D3D     guibg=black       gui=NONE      ctermfg=darkgray    ctermbg=NONE        cterm=NONE

hi VertSplit        guifg=#202020     guibg=#202020     gui=NONE      ctermfg=darkgray    ctermbg=darkgray    cterm=NONE
hi StatusLine       guifg=#CCCCCC     guibg=#202020     gui=italic    ctermfg=white       ctermbg=darkgray    cterm=NONE
hi StatusLineNC     guifg=black       guibg=#202020     gui=NONE      ctermfg=blue        ctermbg=darkgray    cterm=NONE  

hi Folded           guifg=#a0a8b0     guibg=#384048     gui=NONE      ctermfg=NONE        ctermbg=NONE        cterm=NONE
hi Title            guifg=#f6f3e8     guibg=NONE        gui=bold      ctermfg=NONE        ctermbg=NONE        cterm=NONE
hi Visual           guifg=NONE        guibg=#262D51     gui=NONE      ctermfg=NONE        ctermbg=NONE	      cterm=NONE

hi SpecialKey       guifg=#808080     guibg=#343434     gui=NONE      ctermfg=NONE        ctermbg=NONE        cterm=NONE

hi WildMenu         guifg=green       guibg=yellow      gui=NONE      ctermfg=black       ctermbg=yellow      cterm=NONE
hi PmenuSbar        guifg=black       guibg=white       gui=NONE      ctermfg=black       ctermbg=white       cterm=NONE

hi Error            guifg=NONE        guibg=NONE        gui=undercurl ctermfg=red       ctermbg=white         cterm=undercurl     guisp=#FF6C60 " undercurl color
hi ErrorMsg         guifg=white       guibg=#FF6C60     gui=BOLD      ctermfg=red       ctermbg=white         cterm=undercurl
hi WarningMsg       guifg=white       guibg=#FF6C60     gui=BOLD      ctermfg=red       ctermbg=white         cterm=undercurl

" Message displayed in lower left, such as --INSERT--
hi ModeMsg          guifg=black       guibg=#C6C5FE     gui=BOLD      ctermfg=black       ctermbg=42        cterm=BOLD

if version >= 700 " Vim 7.x specific colors
  hi CursorLine     guifg=NONE        guibg=#121212     gui=NONE      ctermfg=NONE        ctermbg=NONE        cterm=BOLD
  hi CursorColumn   guifg=NONE        guibg=#121212     gui=NONE      ctermfg=NONE        ctermbg=NONE        cterm=BOLD
  hi MatchParen     guifg=#f6f3e8     guibg=#857b6f     gui=BOLD      ctermfg=white       ctermbg=NONE	      cterm=NONE
  hi Pmenu          guifg=#f6f3e8     guibg=#444444     gui=NONE      ctermfg=NONE        ctermbg=NONE        cterm=NONE
  hi PmenuSel       guifg=#000000     guibg=#cae682     gui=NONE      ctermfg=NONE        ctermbg=NONE        cterm=NONE
  hi Search         guifg=NONE        guibg=NONE        gui=underline ctermfg=NONE        ctermbg=NONE        cterm=underline
endif

" Syntax highlighting
hi Comment          guifg=#7C7C7C     guibg=NONE        gui=NONE      ctermfg=102	ctermbg=NONE        cterm=NONE
hi String           guifg=#A8FF60     guibg=NONE        gui=NONE      ctermfg=183	ctermbg=NONE        cterm=NONE
hi Number           guifg=#FF73FD     guibg=NONE        gui=NONE      ctermfg=209     	  ctermbg=NONE        cterm=NONE
"string = 206
hi Keyword          guifg=#96CBFE     guibg=NONE        gui=NONE      ctermfg=38        ctermbg=NONE        cterm=NONE
hi Include 	    guifg=#96CBFE     guibg=NONE        gui=NONE      ctermfg=212	  ctermbg=NONE        cterm=NONE
hi Macro            guifg=#96CBFE     guibg=NONE        gui=NONE      ctermfg=212         ctermbg=NONE        cterm=NONE
hi Define           guifg=#96CBFE     guibg=NONE        gui=NONE      ctermfg=212         ctermbg=NONE        cterm=NONE

hi PreProc          guifg=#96CBFE     guibg=NONE        gui=NONE      ctermfg=86	  ctermbg=NONE        cterm=NONE
hi Conditional      guifg=#6699CC     guibg=NONE        gui=NONE      ctermfg=46	 ctermbg=NONE        cterm=NONE 
hi PreCondit        guifg=#96CBFE     guibg=NONE        gui=NONE      ctermfg=212	  ctermbg=NONE        cterm=NONE
hi Constant         guifg=#A8FF60     guibg=NONE        gui=NONE      ctermfg=123       ctermbg=NONE        cterm=NONE

hi Identifier       guifg=#C6C5FE     guibg=NONE        gui=NONE      ctermfg=153        ctermbg=NONE        cterm=NONE
hi Function         guifg=#FFD2A7     guibg=NONE        gui=NONE      ctermfg=42         ctermbg=NONE        cterm=NONE
hi StorageClass     guifg=#FFFFB6     guibg=NONE        gui=NONE      ctermfg=41 	  ctermbg=NONE        cterm=NONE
hi Type             guifg=#FFFFB6     guibg=NONE        gui=NONE      ctermfg=81	  ctermbg=NONE        cterm=NONE
hi Statement        guifg=#6699CC     guibg=NONE        gui=NONE      ctermfg=135	 ctermbg=NONE        cterm=NONE

hi Special          guifg=#E18964     guibg=NONE        gui=NONE      ctermfg=39       ctermbg=NONE        cterm=NONE
hi Operator         guifg=white       guibg=NONE        gui=NONE      ctermfg=white       ctermbg=NONE        cterm=NONE
hi Todo		    guifg=#7C7C7C     guibg=NONE	gui=NONE      ctermfg=242	 ctermbg=NONE	      cterm=BOLD

hi link Delimiter	Function
hi link Character       Constant
hi link Boolean         Constant
hi link Float           Number
hi link Label           Statement
hi link Repeat          Statement
hi link PreCondit       PreProc
hi link Typedef         Type
hi link Structure       Type
hi link Tag             Special
hi link SpecialChar     Special
hi link SpecialComment  Special
hi link Debug           Special

" *  LINKS FOR OTHER LANGUAGES * 
hi link javaScriptNumber	Number
hi link javaScriptMember	Type
hi link javaScriptNull		String
hi link javaScriptIdentifier	Type
hi link javaAnnotation		Comment
hi link javaParen		Function

hi link goFunctionCall    	Identifier
hi link goConstants		Constant
hi link goDeclaration		Statement
hi link goDeclType		Type
hi link goBuiltins		Constant
hi link goDirective		Constant

hi link rustCommentLine		Comment

" * ruby Syntax *
hi rubyClass 	   		ctermfg=197 	ctermbg=NONE	 cterm=NONE 	guifg=#f92672 	guibg=NONE 	gui=NONE
hi rubyFunction    		ctermfg=148 	ctermbg=NONE	 cterm=NONE 	guifg=#a6e22e 	guibg=NONE 	gui=NONE
hi rubyInterpolationDelimiter 	ctermfg=NONE 	ctermbg=NONE	 cterm=NONE 	guifg=NONE 	guibg=NONE 	gui=NONE
hi rubySymbol 			ctermfg=141 	ctermbg=NONE	 cterm=NONE 	guifg=#ae81ff 	guibg=NONE 	gui=NONE
hi rubyConstant 		ctermfg=81 	ctermbg=NONE	 cterm=NONE 	guifg=#66d9ef	guibg=NONE 	gui=italic

hi rubyStringDelimiter 		ctermfg=186 	ctermbg=NONE	 cterm=NONE	guifg=#e6db74 	guibg=NONE 	gui=NONE
hi rubyBlockParameter 		ctermfg=208 	ctermbg=NONE	 cterm=NONE	guifg=#fd971f 	guibg=NONE 	gui=italic
hi rubyInstanceVariable 	ctermfg=NONE 	ctermbg=NONE	 cterm=NONE 	guifg=NONE 	guibg=NONE 	gui=NONE
hi rubyInclude 			ctermfg=197 	ctermbg=NONE	 cterm=NONE 	guifg=#f92672 	guibg=NONE 	gui=NONE

hi rubyGlobalVariable 		ctermfg=NONE 	ctermbg=NONE	 cterm=NONE	guifg=NONE 	guibg=NONE 	gui=NONE
hi rubyRegexp 			ctermfg=186 	ctermbg=NONE	 cterm=NONE	guifg=#e6db74 	guibg=NONE 	gui=NONE
hi rubyRegexpDelimiter 		ctermfg=186 	ctermbg=NONE	 cterm=NONE	guifg=#e6db74 	guibg=NONE 	gui=NONE

hi rubyEscape 			ctermfg=141 	ctermbg=NONE	 cterm=NONE	guifg=#ae81ff 	guibg=NONE 	gui=NONE
hi rubyControl 			ctermfg=197 	ctermbg=NONE	 cterm=NONE 	guifg=#f92672 	guibg=NONE 	gui=NONE
hi rubyClassVariable 		ctermfg=NONE 	ctermbg=NONE	 cterm=NONE	guifg=NONE 	guibg=NONE 	gui=NONE

hi rubyOperator 		ctermfg=197 	ctermbg=NONE	 cterm=NONE 	guifg=#f92672 	guibg=NONE 	gui=NONE
hi rubyException 		ctermfg=197 	ctermbg=NONE	 cterm=NONE 	guifg=#f92672 	guibg=NONE 	gui=NONE
hi rubyPseudoVariable 		ctermfg=NONE 	ctermbg=NONE	 cterm=NONE 	guifg=NONE 	guibg=NONE 	gui=NONE
hi rubyRailsUserClass 		ctermfg=81 	ctermbg=NONE	 cterm=NONE 	guifg=#66d9ef 	guibg=NONE 	gui=italic

hi rubyRailsARAssociationMethod ctermfg=81 	ctermbg=NONE	 cterm=NONE	guifg=#66d9ef 	guibg=NONE 	gui=NONE
hi rubyRailsARMethod 		ctermfg=81 	ctermbg=NONE	 cterm=NONE 	guifg=#66d9ef 	guibg=NONE 	gui=NONE
hi rubyRailsRenderMethod 	ctermfg=81 	ctermbg=NONE	 cterm=NONE 	guifg=#66d9ef 	guibg=NONE 	gui=NONE
hi rubyRailsMethod 		ctermfg=81 	ctermbg=NONE	 cterm=NONE 	guifg=#66d9ef 	guibg=NONE 	gui=NONE

hi erubyDelimiter 		ctermfg=NONE 	ctermbg=NONE 	cterm=NONE 	guifg=NONE 	guibg=NONE 	gui=NONE
hi erubyComment 		ctermfg=95 	ctermbg=NONE 	cterm=NONE 	guifg=#75715e 	guibg=NONE 	gui=NONE
hi erubyRailsMethod 		ctermfg=81 	ctermbg=NONE	cterm=NONE 	guifg=#66d9ef 	guibg=NONE 	gui=NONE


" * html syntax *
hi htmlTag 			ctermfg=NONE 	ctermbg=NONE	 cterm=NONE 	guifg=NONE 	guibg=NONE 	gui=NONE
hi htmlEndTag 			ctermfg=NONE 	ctermbg=NONE	 cterm=NONE 	guifg=#a6e22e 	guibg=NONE 	gui=NONE
hi htmlTagName 			ctermfg=NONE 	ctermbg=NONE	 cterm=NONE 	guifg=NONE 	guibg=NONE 	gui=NONE
hi htmlArg 			ctermfg=NONE 	ctermbg=NONE	 cterm=NONE 	guifg=NONE 	guibg=NONE 	gui=NONE
hi htmlSpecialChar 		ctermfg=141 	ctermbg=NONE	 cterm=NONE 	guifg=#ae81ff 	guibg=NONE 	gui=NONE


" * JavaScript syntax *
hi javaScriptFunction 		ctermfg=83 	ctermbg=NONE	 cterm=NONE 	guifg=#66d9ef 	guibg=NONE 	gui=italic
hi javaScriptRailsFunction 	ctermfg=83	ctermbg=NONE	 cterm=NONE 	guifg=#66d9ef 	guibg=NONE 	gui=NONE
hi javaScriptBraces 		ctermfg=white 	ctermbg=NONE	 cterm=NONE 	guifg=NONE 	guibg=NONE 	gui=NONE


" * yaml syntax *
hi yamlKey 			ctermfg=197 	ctermbg=NONE	 cterm=NONE 	guifg=#f92672 	guibg=NONE 	gui=NONE
hi yamlAnchor 			ctermfg=NONE 	ctermbg=NONE	 cterm=NONE 	guifg=NONE 	guibg=NONE 	gui=NONE
hi yamlAlias 			ctermfg=NONE 	ctermbg=NONE	 cterm=NONE 	guifg=NONE 	guibg=NONE 	gui=NONE
hi yamlDocumentHeader 		ctermfg=186 	ctermbg=NONE	 cterm=NONE 	guifg=#e6db74 	guibg=NONE 	gui=NONE


" * CSS syntax *
hi cssURL 			ctermfg=208 	ctermbg=NONE	 cterm=NONE 	guifg=#fd971f 	guibg=NONE 	gui=italic
hi cssFunctionName 		ctermfg=81 	ctermbg=NONE	 cterm=NONE 	guifg=#66d9ef 	guibg=NONE 	gui=NONE
hi cssColor 			ctermfg=141 	ctermbg=NONE	 cterm=NONE 	guifg=#ae81ff 	guibg=NONE 	gui=NONE
hi cssPseudoClassId 		ctermfg=148 	ctermbg=NONE	 cterm=NONE 	guifg=#a6e22e 	guibg=NONE 	gui=NONE
hi cssClassName 		ctermfg=148 	ctermbg=NONE	 cterm=NONE 	guifg=#a6e22e 	guibg=NONE 	gui=NONE
hi cssValueLength 		ctermfg=141 	ctermbg=NONE	 cterm=NONE 	guifg=#ae81ff 	guibg=NONE 	gui=NONE
hi cssCommonAttr 		ctermfg=81 	ctermbg=NONE	 cterm=NONE 	guifg=#66d9ef 	guibg=NONE 	gui=NONE
hi cssBraces 			ctermfg=NONE 	ctermbg=NONE	 cterm=NONE 	guifg=NONE 	guibg=NONE 	gui=NONE

" * rust syntax *
hi  rustCommentLineDoc 		ctermfg=81      ctermbg=NONE     cterm=NONE     guifg=#66d9ef   guibg=NONE      gui=NONE
hi rustCommentLineDocLeader	ctermfg=81      ctermbg=NONE     cterm=NONE     guifg=#66d9ef   guibg=NONE      gui=NONE
hi rustCommentLineDocError	ctermfg=81      ctermbg=NONE     cterm=NONE     guifg=#66d9ef   guibg=NONE      gui=NONE
hi rustCommentBlock		ctermfg=81      ctermbg=NONE     cterm=NONE     guifg=#66d9ef   guibg=NONE      gui=NONE
hi rustCommentBlockDoc		ctermfg=81      ctermbg=NONE     cterm=NONE     guifg=#66d9ef   guibg=NONE      gui=NONE
hi rustCommentBlockDocStar	ctermfg=81      ctermbg=NONE     cterm=NONE     guifg=#66d9ef   guibg=NONE      gui=NONE
hi rustCommentBlockDocError 	ctermfg=81      ctermbg=NONE     cterm=NONE     guifg=#66d9ef   guibg=NONE      gui=NONE
hi rustCommentDocCodeFence	ctermfg=81      ctermbg=NONE     cterm=NONE     guifg=#66d9ef   guibg=NONE      gui=NONE

" * go syntax "
hi goFunction			ctermfg=red      ctermbg=NONE     cterm=NONE     guifg=#66d9ef   guibg=NONE      gui=NONE
