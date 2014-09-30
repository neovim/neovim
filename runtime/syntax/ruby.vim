" Vim syntax file
" Language:		Ruby
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" URL:			https://github.com/vim-ruby/vim-ruby
" Release Coordinator:	Doug Kearns <dougkearns@gmail.com>
" ----------------------------------------------------------------------------
"
" Previous Maintainer:	Mirko Nasato
" Thanks to perl.vim authors, and to Reimer Behrends. :-) (MN)
" ----------------------------------------------------------------------------

if exists("b:current_syntax")
  finish
endif

if has("folding") && exists("ruby_fold")
  setlocal foldmethod=syntax
endif

syn cluster rubyNotTop contains=@rubyExtendedStringSpecial,@rubyRegexpSpecial,@rubyDeclaration,rubyConditional,rubyExceptional,rubyMethodExceptional,rubyTodo

if exists("ruby_space_errors")
  if !exists("ruby_no_trail_space_error")
    syn match rubySpaceError display excludenl "\s\+$"
  endif
  if !exists("ruby_no_tab_space_error")
    syn match rubySpaceError display " \+\t"me=e-1
  endif
endif

" Operators
if exists("ruby_operators")
  syn match  rubyOperator "[~!^&|*/%+-]\|\%(class\s*\)\@<!<<\|<=>\|<=\|\%(<\|\<class\s\+\u\w*\s*\)\@<!<[^<]\@=\|===\|==\|=\~\|>>\|>=\|=\@<!>\|\*\*\|\.\.\.\|\.\.\|::"
  syn match  rubyOperator "->\|-=\|/=\|\*\*=\|\*=\|&&=\|&=\|&&\|||=\||=\|||\|%=\|+=\|!\~\|!="
  syn region rubyBracketOperator matchgroup=rubyOperator start="\%(\w[?!]\=\|[]})]\)\@<=\[\s*" end="\s*]" contains=ALLBUT,@rubyNotTop
endif

" Expression Substitution and Backslash Notation
syn match rubyStringEscape "\\\\\|\\[abefnrstv]\|\\\o\{1,3}\|\\x\x\{1,2}"						    contained display
syn match rubyStringEscape "\%(\\M-\\C-\|\\C-\\M-\|\\M-\\c\|\\c\\M-\|\\c\|\\C-\|\\M-\)\%(\\\o\{1,3}\|\\x\x\{1,2}\|\\\=\S\)" contained display
syn match rubyQuoteEscape  "\\[\\']"											    contained display

syn region rubyInterpolation	      matchgroup=rubyInterpolationDelimiter start="#{" end="}" contained contains=ALLBUT,@rubyNotTop
syn match  rubyInterpolation	      "#\%(\$\|@@\=\)\w\+"    display contained contains=rubyInterpolationDelimiter,rubyInstanceVariable,rubyClassVariable,rubyGlobalVariable,rubyPredefinedVariable
syn match  rubyInterpolationDelimiter "#\ze\%(\$\|@@\=\)\w\+" display contained
syn match  rubyInterpolation	      "#\$\%(-\w\|\W\)"       display contained contains=rubyInterpolationDelimiter,rubyPredefinedVariable,rubyInvalidVariable
syn match  rubyInterpolationDelimiter "#\ze\$\%(-\w\|\W\)"    display contained
syn region rubyNoInterpolation	      start="\\#{" end="}"            contained
syn match  rubyNoInterpolation	      "\\#{"		      display contained
syn match  rubyNoInterpolation	      "\\#\%(\$\|@@\=\)\w\+"  display contained
syn match  rubyNoInterpolation	      "\\#\$\W"		      display contained

syn match rubyDelimEscape	"\\[(<{\[)>}\]]" transparent display contained contains=NONE

syn region rubyNestedParentheses    start="("  skip="\\\\\|\\)"  matchgroup=rubyString end=")"	transparent contained
syn region rubyNestedCurlyBraces    start="{"  skip="\\\\\|\\}"  matchgroup=rubyString end="}"	transparent contained
syn region rubyNestedAngleBrackets  start="<"  skip="\\\\\|\\>"  matchgroup=rubyString end=">"	transparent contained
syn region rubyNestedSquareBrackets start="\[" skip="\\\\\|\\\]" matchgroup=rubyString end="\]"	transparent contained

" These are mostly Oniguruma ready
syn region rubyRegexpComment	matchgroup=rubyRegexpSpecial   start="(?#"								  skip="\\)"  end=")"  contained
syn region rubyRegexpParens	matchgroup=rubyRegexpSpecial   start="(\(?:\|?<\=[=!]\|?>\|?<[a-z_]\w*>\|?[imx]*-[imx]*:\=\|\%(?#\)\@!\)" skip="\\)"  end=")"  contained transparent contains=@rubyRegexpSpecial
syn region rubyRegexpBrackets	matchgroup=rubyRegexpCharClass start="\[\^\="								  skip="\\\]" end="\]" contained transparent contains=rubyStringEscape,rubyRegexpEscape,rubyRegexpCharClass oneline
syn match  rubyRegexpCharClass	"\\[DdHhSsWw]"	       contained display
syn match  rubyRegexpCharClass	"\[:\^\=\%(alnum\|alpha\|ascii\|blank\|cntrl\|digit\|graph\|lower\|print\|punct\|space\|upper\|xdigit\):\]" contained
syn match  rubyRegexpEscape	"\\[].*?+^$|\\/(){}[]" contained
syn match  rubyRegexpQuantifier	"[*?+][?+]\="	       contained display
syn match  rubyRegexpQuantifier	"{\d\+\%(,\d*\)\=}?\=" contained display
syn match  rubyRegexpAnchor	"[$^]\|\\[ABbGZz]"     contained display
syn match  rubyRegexpDot	"\."		       contained display
syn match  rubyRegexpSpecial	"|"		       contained display
syn match  rubyRegexpSpecial	"\\[1-9]\d\=\d\@!"     contained display
syn match  rubyRegexpSpecial	"\\k<\%([a-z_]\w*\|-\=\d\+\)\%([+-]\d\+\)\=>" contained display
syn match  rubyRegexpSpecial	"\\k'\%([a-z_]\w*\|-\=\d\+\)\%([+-]\d\+\)\='" contained display
syn match  rubyRegexpSpecial	"\\g<\%([a-z_]\w*\|-\=\d\+\)>" contained display
syn match  rubyRegexpSpecial	"\\g'\%([a-z_]\w*\|-\=\d\+\)'" contained display

syn cluster rubyStringSpecial	      contains=rubyInterpolation,rubyNoInterpolation,rubyStringEscape
syn cluster rubyExtendedStringSpecial contains=@rubyStringSpecial,rubyNestedParentheses,rubyNestedCurlyBraces,rubyNestedAngleBrackets,rubyNestedSquareBrackets
syn cluster rubyRegexpSpecial	      contains=rubyInterpolation,rubyNoInterpolation,rubyStringEscape,rubyRegexpSpecial,rubyRegexpEscape,rubyRegexpBrackets,rubyRegexpCharClass,rubyRegexpDot,rubyRegexpQuantifier,rubyRegexpAnchor,rubyRegexpParens,rubyRegexpComment

" Numbers and ASCII Codes
syn match rubyASCIICode	"\%(\w\|[]})\"'/]\)\@<!\%(?\%(\\M-\\C-\|\\C-\\M-\|\\M-\\c\|\\c\\M-\|\\c\|\\C-\|\\M-\)\=\%(\\\o\{1,3}\|\\x\x\{1,2}\|\\\=\S\)\)"
syn match rubyInteger	"\%(\%(\w\|[]})\"']\s*\)\@<!-\)\=\<0[xX]\x\+\%(_\x\+\)*\>"								display
syn match rubyInteger	"\%(\%(\w\|[]})\"']\s*\)\@<!-\)\=\<\%(0[dD]\)\=\%(0\|[1-9]\d*\%(_\d\+\)*\)\>"						display
syn match rubyInteger	"\%(\%(\w\|[]})\"']\s*\)\@<!-\)\=\<0[oO]\=\o\+\%(_\o\+\)*\>"								display
syn match rubyInteger	"\%(\%(\w\|[]})\"']\s*\)\@<!-\)\=\<0[bB][01]\+\%(_[01]\+\)*\>"								display
syn match rubyFloat	"\%(\%(\w\|[]})\"']\s*\)\@<!-\)\=\<\%(0\|[1-9]\d*\%(_\d\+\)*\)\.\d\+\%(_\d\+\)*\>"					display
syn match rubyFloat	"\%(\%(\w\|[]})\"']\s*\)\@<!-\)\=\<\%(0\|[1-9]\d*\%(_\d\+\)*\)\%(\.\d\+\%(_\d\+\)*\)\=\%([eE][-+]\=\d\+\%(_\d\+\)*\)\>"	display

" Identifiers
syn match rubyLocalVariableOrMethod "\<[_[:lower:]][_[:alnum:]]*[?!=]\=" contains=NONE display transparent
syn match rubyBlockArgument	    "&[_[:lower:]][_[:alnum:]]"		 contains=NONE display transparent

syn match  rubyConstant		"\%(\%([.@$]\@<!\.\)\@<!\<\|::\)\_s*\zs\u\w*\%(\>\|::\)\@=\%(\s*(\)\@!"
syn match  rubyClassVariable	"@@\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*" display
syn match  rubyInstanceVariable "@\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*"  display
syn match  rubyGlobalVariable	"$\%(\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*\|-.\)"
syn match  rubySymbol		"[]})\"':]\@<!:\%(\^\|\~\|<<\|<=>\|<=\|<\|===\|[=!]=\|[=!]\~\|!\|>>\|>=\|>\||\|-@\|-\|/\|\[]=\|\[]\|\*\*\|\*\|&\|%\|+@\|+\|`\)"
syn match  rubySymbol		"[]})\"':]\@<!:\$\%(-.\|[`~<=>_,;:!?/.'"@$*\&+0]\)"
syn match  rubySymbol		"[]})\"':]\@<!:\%(\$\|@@\=\)\=\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*"
syn match  rubySymbol		"[]})\"':]\@<!:\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*\%([?!=]>\@!\)\="
syn match  rubySymbol		"\%([{(,]\_s*\)\@<=\l\w*[!?]\=::\@!"he=e-1
syn match  rubySymbol		"[]})\"':]\@<!\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*[!?]\=:\s\@="he=e-1
syn match  rubySymbol		"\%([{(,]\_s*\)\@<=[[:space:],{]\l\w*[!?]\=::\@!"hs=s+1,he=e-1
syn match  rubySymbol		"[[:space:],{]\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*[!?]\=:\s\@="hs=s+1,he=e-1
syn region rubySymbol		start="[]})\"':]\@<!:'"  end="'"  skip="\\\\\|\\'"  contains=rubyQuoteEscape fold
syn region rubySymbol		start="[]})\"':]\@<!:\"" end="\"" skip="\\\\\|\\\"" contains=@rubyStringSpecial fold

syn match  rubyBlockParameter	  "\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*" contained
syn region rubyBlockParameterList start="\%(\%(\<do\>\|{\)\s*\)\@<=|" end="|" oneline display contains=rubyBlockParameter

syn match rubyInvalidVariable	 "$[^ A-Za-z_-]"
syn match rubyPredefinedVariable #$[!$&"'*+,./0:;<=>?@\`~]#
syn match rubyPredefinedVariable "$\d\+"										   display
syn match rubyPredefinedVariable "$_\>"											   display
syn match rubyPredefinedVariable "$-[0FIKadilpvw]\>"									   display
syn match rubyPredefinedVariable "$\%(deferr\|defout\|stderr\|stdin\|stdout\)\>"					   display
syn match rubyPredefinedVariable "$\%(DEBUG\|FILENAME\|KCODE\|LOADED_FEATURES\|LOAD_PATH\|PROGRAM_NAME\|SAFE\|VERBOSE\)\>" display
syn match rubyPredefinedConstant "\%(\%(\.\@<!\.\)\@<!\|::\)\_s*\zs\%(MatchingData\|ARGF\|ARGV\|ENV\)\>\%(\s*(\)\@!"
syn match rubyPredefinedConstant "\%(\%(\.\@<!\.\)\@<!\|::\)\_s*\zs\%(DATA\|FALSE\|NIL\)\>\%(\s*(\)\@!"
syn match rubyPredefinedConstant "\%(\%(\.\@<!\.\)\@<!\|::\)\_s*\zs\%(STDERR\|STDIN\|STDOUT\|TOPLEVEL_BINDING\|TRUE\)\>\%(\s*(\)\@!"
syn match rubyPredefinedConstant "\%(\%(\.\@<!\.\)\@<!\|::\)\_s*\zs\%(RUBY_\%(VERSION\|RELEASE_DATE\|PLATFORM\|PATCHLEVEL\|REVISION\|DESCRIPTION\|COPYRIGHT\|ENGINE\)\)\>\%(\s*(\)\@!"

" Normal Regular Expression
syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="\%(\%(^\|\<\%(and\|or\|while\|until\|unless\|if\|elsif\|when\|not\|then\|else\)\|[;\~=!|&(,[<>?:*+-]\)\s*\)\@<=/" end="/[iomxneus]*" skip="\\\\\|\\/" contains=@rubyRegexpSpecial fold
syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="\%(\h\k*\s\+\)\@<=/[ \t=]\@!" end="/[iomxneus]*" skip="\\\\\|\\/" contains=@rubyRegexpSpecial fold

" Generalized Regular Expression
syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r\z([~`!@#$%^&*_\-+=|\:;"',.? /]\)" end="\z1[iomxneus]*" skip="\\\\\|\\\z1" contains=@rubyRegexpSpecial fold
syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r{"				 end="}[iomxneus]*"   skip="\\\\\|\\}"	 contains=@rubyRegexpSpecial fold
syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r<"				 end=">[iomxneus]*"   skip="\\\\\|\\>"	 contains=@rubyRegexpSpecial,rubyNestedAngleBrackets,rubyDelimEscape fold
syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r\["				 end="\][iomxneus]*"  skip="\\\\\|\\\]"	 contains=@rubyRegexpSpecial fold
syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r("				 end=")[iomxneus]*"   skip="\\\\\|\\)"	 contains=@rubyRegexpSpecial fold

" Normal String and Shell Command Output
syn region rubyString matchgroup=rubyStringDelimiter start="\"" end="\"" skip="\\\\\|\\\"" contains=@rubyStringSpecial,@Spell fold
syn region rubyString matchgroup=rubyStringDelimiter start="'"	end="'"  skip="\\\\\|\\'"  contains=rubyQuoteEscape,@Spell    fold
syn region rubyString matchgroup=rubyStringDelimiter start="`"	end="`"  skip="\\\\\|\\`"  contains=@rubyStringSpecial fold

" Generalized Single Quoted String, Symbol and Array of Strings
syn region rubyString matchgroup=rubyStringDelimiter start="%[qwi]\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)" end="\z1" skip="\\\\\|\\\z1" fold
syn region rubyString matchgroup=rubyStringDelimiter start="%[qwi]{"				   end="}"   skip="\\\\\|\\}"	fold contains=rubyNestedCurlyBraces,rubyDelimEscape
syn region rubyString matchgroup=rubyStringDelimiter start="%[qwi]<"				   end=">"   skip="\\\\\|\\>"	fold contains=rubyNestedAngleBrackets,rubyDelimEscape
syn region rubyString matchgroup=rubyStringDelimiter start="%[qwi]\["				   end="\]"  skip="\\\\\|\\\]"	fold contains=rubyNestedSquareBrackets,rubyDelimEscape
syn region rubyString matchgroup=rubyStringDelimiter start="%[qwi]("				   end=")"   skip="\\\\\|\\)"	fold contains=rubyNestedParentheses,rubyDelimEscape
syn region rubyString matchgroup=rubyStringDelimiter start="%q "				   end=" "   skip="\\\\\|\\)"	fold
syn region rubySymbol matchgroup=rubySymbolDelimiter start="%s\z([~`!@#$%^&*_\-+=|\:;"',.? /]\)"   end="\z1" skip="\\\\\|\\\z1" fold
syn region rubySymbol matchgroup=rubySymbolDelimiter start="%s{"				   end="}"   skip="\\\\\|\\}"	fold contains=rubyNestedCurlyBraces,rubyDelimEscape
syn region rubySymbol matchgroup=rubySymbolDelimiter start="%s<"				   end=">"   skip="\\\\\|\\>"	fold contains=rubyNestedAngleBrackets,rubyDelimEscape
syn region rubySymbol matchgroup=rubySymbolDelimiter start="%s\["				   end="\]"  skip="\\\\\|\\\]"	fold contains=rubyNestedSquareBrackets,rubyDelimEscape
syn region rubySymbol matchgroup=rubySymbolDelimiter start="%s("				   end=")"   skip="\\\\\|\\)"	fold contains=rubyNestedParentheses,rubyDelimEscape

" Generalized Double Quoted String and Array of Strings and Shell Command Output
" Note: %= is not matched here as the beginning of a double quoted string
syn region rubyString matchgroup=rubyStringDelimiter start="%\z([~`!@#$%^&*_\-+|\:;"',.?/]\)"	    end="\z1" skip="\\\\\|\\\z1" contains=@rubyStringSpecial fold
syn region rubyString matchgroup=rubyStringDelimiter start="%[QWIx]\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)" end="\z1" skip="\\\\\|\\\z1" contains=@rubyStringSpecial fold
syn region rubyString matchgroup=rubyStringDelimiter start="%[QWIx]\={"				    end="}"   skip="\\\\\|\\}"	 contains=@rubyStringSpecial,rubyNestedCurlyBraces,rubyDelimEscape    fold
syn region rubyString matchgroup=rubyStringDelimiter start="%[QWIx]\=<"				    end=">"   skip="\\\\\|\\>"	 contains=@rubyStringSpecial,rubyNestedAngleBrackets,rubyDelimEscape  fold
syn region rubyString matchgroup=rubyStringDelimiter start="%[QWIx]\=\["				    end="\]"  skip="\\\\\|\\\]"	 contains=@rubyStringSpecial,rubyNestedSquareBrackets,rubyDelimEscape fold
syn region rubyString matchgroup=rubyStringDelimiter start="%[QWIx]\=("				    end=")"   skip="\\\\\|\\)"	 contains=@rubyStringSpecial,rubyNestedParentheses,rubyDelimEscape    fold
syn region rubyString matchgroup=rubyStringDelimiter start="%[Qx] "				    end=" "   skip="\\\\\|\\)"   contains=@rubyStringSpecial fold

" Here Document
syn region rubyHeredocStart matchgroup=rubyStringDelimiter start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<-\=\zs\%(\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*\)+	 end=+$+ oneline contains=ALLBUT,@rubyNotTop
syn region rubyHeredocStart matchgroup=rubyStringDelimiter start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<-\=\zs"\%([^"]*\)"+ end=+$+ oneline contains=ALLBUT,@rubyNotTop
syn region rubyHeredocStart matchgroup=rubyStringDelimiter start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<-\=\zs'\%([^']*\)'+ end=+$+ oneline contains=ALLBUT,@rubyNotTop
syn region rubyHeredocStart matchgroup=rubyStringDelimiter start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<-\=\zs`\%([^`]*\)`+ end=+$+ oneline contains=ALLBUT,@rubyNotTop

syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]})"'.]\)\s\|\w\)\@<!<<\z(\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*\)\ze\%(.*<<-\=['`"]\=\h\)\@!+hs=s+2	matchgroup=rubyStringDelimiter end=+^\z1$+ contains=rubyHeredocStart,rubyHeredoc,@rubyStringSpecial fold keepend
syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]})"'.]\)\s\|\w\)\@<!<<"\z([^"]*\)"\ze\%(.*<<-\=['`"]\=\h\)\@!+hs=s+2	matchgroup=rubyStringDelimiter end=+^\z1$+ contains=rubyHeredocStart,rubyHeredoc,@rubyStringSpecial fold keepend
syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]})"'.]\)\s\|\w\)\@<!<<'\z([^']*\)'\ze\%(.*<<-\=['`"]\=\h\)\@!+hs=s+2	matchgroup=rubyStringDelimiter end=+^\z1$+ contains=rubyHeredocStart,rubyHeredoc			fold keepend
syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]})"'.]\)\s\|\w\)\@<!<<`\z([^`]*\)`\ze\%(.*<<-\=['`"]\=\h\)\@!+hs=s+2	matchgroup=rubyStringDelimiter end=+^\z1$+ contains=rubyHeredocStart,rubyHeredoc,@rubyStringSpecial fold keepend

syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]}).]\)\s\|\w\)\@<!<<-\z(\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*\)\ze\%(.*<<-\=['`"]\=\h\)\@!+hs=s+3    matchgroup=rubyStringDelimiter end=+^\s*\zs\z1$+ contains=rubyHeredocStart,@rubyStringSpecial fold keepend
syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]}).]\)\s\|\w\)\@<!<<-"\z([^"]*\)"\ze\%(.*<<-\=['`"]\=\h\)\@!+hs=s+3  matchgroup=rubyStringDelimiter end=+^\s*\zs\z1$+ contains=rubyHeredocStart,@rubyStringSpecial fold keepend
syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]}).]\)\s\|\w\)\@<!<<-'\z([^']*\)'\ze\%(.*<<-\=['`"]\=\h\)\@!+hs=s+3  matchgroup=rubyStringDelimiter end=+^\s*\zs\z1$+ contains=rubyHeredocStart		     fold keepend
syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]}).]\)\s\|\w\)\@<!<<-`\z([^`]*\)`\ze\%(.*<<-\=['`"]\=\h\)\@!+hs=s+3  matchgroup=rubyStringDelimiter end=+^\s*\zs\z1$+ contains=rubyHeredocStart,@rubyStringSpecial fold keepend

if exists('main_syntax') && main_syntax == 'eruby'
  let b:ruby_no_expensive = 1
end

syn match  rubyAliasDeclaration    "[^[:space:];#.()]\+" contained contains=rubySymbol,rubyGlobalVariable,rubyPredefinedVariable nextgroup=rubyAliasDeclaration2 skipwhite
syn match  rubyAliasDeclaration2   "[^[:space:];#.()]\+" contained contains=rubySymbol,rubyGlobalVariable,rubyPredefinedVariable
syn match  rubyMethodDeclaration   "[^[:space:];#(]\+"	 contained contains=rubyConstant,rubyBoolean,rubyPseudoVariable,rubyInstanceVariable,rubyClassVariable,rubyGlobalVariable
syn match  rubyClassDeclaration    "[^[:space:];#<]\+"	 contained contains=rubyConstant,rubyOperator
syn match  rubyModuleDeclaration   "[^[:space:];#<]\+"	 contained contains=rubyConstant,rubyOperator
syn match  rubyFunction "\<[_[:alpha:]][_[:alnum:]]*[?!=]\=[[:alnum:]_.:?!=]\@!" contained containedin=rubyMethodDeclaration
syn match  rubyFunction "\%(\s\|^\)\@<=[_[:alpha:]][_[:alnum:]]*[?!=]\=\%(\s\|$\)\@=" contained containedin=rubyAliasDeclaration,rubyAliasDeclaration2
syn match  rubyFunction "\%([[:space:].]\|^\)\@<=\%(\[\]=\=\|\*\*\|[+-]@\=\|[*/%|&^~]\|<<\|>>\|[<>]=\=\|<=>\|===\|[=!]=\|[=!]\~\|!\|`\)\%([[:space:];#(]\|$\)\@=" contained containedin=rubyAliasDeclaration,rubyAliasDeclaration2,rubyMethodDeclaration

syn cluster rubyDeclaration contains=rubyAliasDeclaration,rubyAliasDeclaration2,rubyMethodDeclaration,rubyModuleDeclaration,rubyClassDeclaration,rubyFunction,rubyBlockParameter

" Keywords
" Note: the following keywords have already been defined:
" begin case class def do end for if module unless until while
syn match   rubyControl	       "\<\%(and\|break\|in\|next\|not\|or\|redo\|rescue\|retry\|return\)\>[?!]\@!"
syn match   rubyOperator       "\<defined?" display
syn match   rubyKeyword	       "\<\%(super\|yield\)\>[?!]\@!"
syn match   rubyBoolean	       "\<\%(true\|false\)\>[?!]\@!"
syn match   rubyPseudoVariable "\<\%(nil\|self\|__ENCODING__\|__FILE__\|__LINE__\|__callee__\|__method__\)\>[?!]\@!" " TODO: reorganise
syn match   rubyBeginEnd       "\<\%(BEGIN\|END\)\>[?!]\@!"

" Expensive Mode - match 'end' with the appropriate opening keyword for syntax
" based folding and special highlighting of module/class/method definitions
if !exists("b:ruby_no_expensive") && !exists("ruby_no_expensive")
  syn match  rubyDefine "\<alias\>"  nextgroup=rubyAliasDeclaration  skipwhite skipnl
  syn match  rubyDefine "\<def\>"    nextgroup=rubyMethodDeclaration skipwhite skipnl
  syn match  rubyDefine "\<undef\>"  nextgroup=rubyFunction	     skipwhite skipnl
  syn match  rubyClass	"\<class\>"  nextgroup=rubyClassDeclaration  skipwhite skipnl
  syn match  rubyModule "\<module\>" nextgroup=rubyModuleDeclaration skipwhite skipnl

  syn region rubyMethodBlock start="\<def\>"	matchgroup=rubyDefine end="\%(\<def\_s\+\)\@<!\<end\>" contains=ALLBUT,@rubyNotTop fold
  syn region rubyBlock	     start="\<class\>"	matchgroup=rubyClass  end="\<end\>"		       contains=ALLBUT,@rubyNotTop fold
  syn region rubyBlock	     start="\<module\>" matchgroup=rubyModule end="\<end\>"		       contains=ALLBUT,@rubyNotTop fold

  " modifiers
  syn match rubyConditionalModifier "\<\%(if\|unless\)\>"    display
  syn match rubyRepeatModifier	     "\<\%(while\|until\)\>" display

  syn region rubyDoBlock      matchgroup=rubyControl start="\<do\>" end="\<end\>"                 contains=ALLBUT,@rubyNotTop fold
  " curly bracket block or hash literal
  syn region rubyCurlyBlock	matchgroup=rubyCurlyBlockDelimiter  start="{" end="}"				contains=ALLBUT,@rubyNotTop fold
  syn region rubyArrayLiteral	matchgroup=rubyArrayDelimiter	    start="\%(\w\|[\]})]\)\@<!\[" end="]"	contains=ALLBUT,@rubyNotTop fold

  " statements without 'do'
  syn region rubyBlockExpression       matchgroup=rubyControl	  start="\<begin\>" end="\<end\>" contains=ALLBUT,@rubyNotTop fold
  syn region rubyCaseExpression	       matchgroup=rubyConditional start="\<case\>"  end="\<end\>" contains=ALLBUT,@rubyNotTop fold
  syn region rubyConditionalExpression matchgroup=rubyConditional start="\%(\%(^\|\.\.\.\=\|[{:,;([<>~\*/%&^|+=-]\|\%(\<[_[:lower:]][_[:alnum:]]*\)\@<![?!]\)\s*\)\@<=\%(if\|unless\)\>" end="\%(\%(\%(\.\@<!\.\)\|::\)\s*\)\@<!\<end\>" contains=ALLBUT,@rubyNotTop fold

  syn match rubyConditional "\<\%(then\|else\|when\)\>[?!]\@!"	contained containedin=rubyCaseExpression
  syn match rubyConditional "\<\%(then\|else\|elsif\)\>[?!]\@!" contained containedin=rubyConditionalExpression

  syn match rubyExceptional	  "\<\%(\%(\%(;\|^\)\s*\)\@<=rescue\|else\|ensure\)\>[?!]\@!" contained containedin=rubyBlockExpression
  syn match rubyMethodExceptional "\<\%(\%(\%(;\|^\)\s*\)\@<=rescue\|else\|ensure\)\>[?!]\@!" contained containedin=rubyMethodBlock

  " statements with optional 'do'
  syn region rubyOptionalDoLine   matchgroup=rubyRepeat start="\<for\>[?!]\@!" start="\%(\%(^\|\.\.\.\=\|[{:,;([<>~\*/%&^|+-]\|\%(\<[_[:lower:]][_[:alnum:]]*\)\@<![!=?]\)\s*\)\@<=\<\%(until\|while\)\>" matchgroup=rubyOptionalDo end="\%(\<do\>\)" end="\ze\%(;\|$\)" oneline contains=ALLBUT,@rubyNotTop
  syn region rubyRepeatExpression start="\<for\>[?!]\@!" start="\%(\%(^\|\.\.\.\=\|[{:,;([<>~\*/%&^|+-]\|\%(\<[_[:lower:]][_[:alnum:]]*\)\@<![!=?]\)\s*\)\@<=\<\%(until\|while\)\>" matchgroup=rubyRepeat end="\<end\>" contains=ALLBUT,@rubyNotTop nextgroup=rubyOptionalDoLine fold

  if !exists("ruby_minlines")
    let ruby_minlines = 500
  endif
  exec "syn sync minlines=" . ruby_minlines

else
  syn match rubyControl "\<def\>[?!]\@!"    nextgroup=rubyMethodDeclaration skipwhite skipnl
  syn match rubyControl "\<class\>[?!]\@!"  nextgroup=rubyClassDeclaration  skipwhite skipnl
  syn match rubyControl "\<module\>[?!]\@!" nextgroup=rubyModuleDeclaration skipwhite skipnl
  syn match rubyControl "\<\%(case\|begin\|do\|for\|if\|unless\|while\|until\|else\|elsif\|ensure\|then\|when\|end\)\>[?!]\@!"
  syn match rubyKeyword "\<\%(alias\|undef\)\>[?!]\@!"
endif

" Special Methods
if !exists("ruby_no_special_methods")
  syn keyword rubyAccess    public protected private public_class_method private_class_method public_constant private_constant module_function
  " attr is a common variable name
  syn match   rubyAttribute "\%(\%(^\|;\)\s*\)\@<=attr\>\(\s*[.=]\)\@!"
  syn keyword rubyAttribute attr_accessor attr_reader attr_writer
  syn match   rubyControl   "\<\%(exit!\|\%(abort\|at_exit\|exit\|fork\|loop\|trap\)\>[?!]\@!\)"
  syn keyword rubyEval	    eval class_eval instance_eval module_eval
  syn keyword rubyException raise fail catch throw
  " false positive with 'include?'
  syn match   rubyInclude   "\<include\>[?!]\@!"
  syn keyword rubyInclude   autoload extend load prepend require require_relative
  syn keyword rubyKeyword   callcc caller lambda proc
endif

" Comments and Documentation
syn match   rubySharpBang "\%^#!.*" display
syn keyword rubyTodo	  FIXME NOTE TODO OPTIMIZE XXX todo contained
syn match   rubyComment   "#.*" contains=rubySharpBang,rubySpaceError,rubyTodo,@Spell
if !exists("ruby_no_comment_fold")
  syn region rubyMultilineComment start="\%(\%(^\s*#.*\n\)\@<!\%(^\s*#.*\n\)\)\%(\(^\s*#.*\n\)\{1,}\)\@=" end="\%(^\s*#.*\n\)\@<=\%(^\s*#.*\n\)\%(^\s*#\)\@!" contains=rubyComment transparent fold keepend
  syn region rubyDocumentation	  start="^=begin\ze\%(\s.*\)\=$" end="^=end\%(\s.*\)\=$" contains=rubySpaceError,rubyTodo,@Spell fold
else
  syn region rubyDocumentation	  start="^=begin\s*$" end="^=end\s*$" contains=rubySpaceError,rubyTodo,@Spell
endif

" Note: this is a hack to prevent 'keywords' being highlighted as such when called as methods with an explicit receiver
syn match rubyKeywordAsMethod "\%(\%(\.\@<!\.\)\|::\)\_s*\%(alias\|and\|begin\|break\|case\|class\|def\|defined\|do\|else\)\>"		  transparent contains=NONE
syn match rubyKeywordAsMethod "\%(\%(\.\@<!\.\)\|::\)\_s*\%(elsif\|end\|ensure\|false\|for\|if\|in\|module\|next\|nil\)\>"		  transparent contains=NONE
syn match rubyKeywordAsMethod "\%(\%(\.\@<!\.\)\|::\)\_s*\%(not\|or\|redo\|rescue\|retry\|return\|self\|super\|then\|true\)\>"		  transparent contains=NONE
syn match rubyKeywordAsMethod "\%(\%(\.\@<!\.\)\|::\)\_s*\%(undef\|unless\|until\|when\|while\|yield\|BEGIN\|END\|__FILE__\|__LINE__\)\>" transparent contains=NONE

syn match rubyKeywordAsMethod "\<\%(alias\|begin\|case\|class\|def\|do\|end\)[?!]" transparent contains=NONE
syn match rubyKeywordAsMethod "\<\%(if\|module\|undef\|unless\|until\|while\)[?!]" transparent contains=NONE

syn match rubyKeywordAsMethod "\%(\%(\.\@<!\.\)\|::\)\_s*\%(abort\|at_exit\|attr\|attr_accessor\|attr_reader\)\>"	transparent contains=NONE
syn match rubyKeywordAsMethod "\%(\%(\.\@<!\.\)\|::\)\_s*\%(attr_writer\|autoload\|callcc\|catch\|caller\)\>"		transparent contains=NONE
syn match rubyKeywordAsMethod "\%(\%(\.\@<!\.\)\|::\)\_s*\%(eval\|class_eval\|instance_eval\|module_eval\|exit\)\>"	transparent contains=NONE
syn match rubyKeywordAsMethod "\%(\%(\.\@<!\.\)\|::\)\_s*\%(extend\|fail\|fork\|include\|lambda\)\>"			transparent contains=NONE
syn match rubyKeywordAsMethod "\%(\%(\.\@<!\.\)\|::\)\_s*\%(load\|loop\|prepend\|private\|proc\|protected\)\>"		transparent contains=NONE
syn match rubyKeywordAsMethod "\%(\%(\.\@<!\.\)\|::\)\_s*\%(public\|require\|require_relative\|raise\|throw\|trap\)\>"	transparent contains=NONE

" __END__ Directive
syn region rubyData matchgroup=rubyDataDirective start="^__END__$" end="\%$" fold

hi def link rubyClass			rubyDefine
hi def link rubyModule			rubyDefine
hi def link rubyMethodExceptional	rubyDefine
hi def link rubyDefine			Define
hi def link rubyFunction		Function
hi def link rubyConditional		Conditional
hi def link rubyConditionalModifier	rubyConditional
hi def link rubyExceptional		rubyConditional
hi def link rubyRepeat			Repeat
hi def link rubyRepeatModifier		rubyRepeat
hi def link rubyOptionalDo		rubyRepeat
hi def link rubyControl			Statement
hi def link rubyInclude			Include
hi def link rubyInteger			Number
hi def link rubyASCIICode		Character
hi def link rubyFloat			Float
hi def link rubyBoolean			Boolean
hi def link rubyException		Exception
if !exists("ruby_no_identifiers")
  hi def link rubyIdentifier		Identifier
else
  hi def link rubyIdentifier		NONE
endif
hi def link rubyClassVariable		rubyIdentifier
hi def link rubyConstant		Type
hi def link rubyGlobalVariable		rubyIdentifier
hi def link rubyBlockParameter		rubyIdentifier
hi def link rubyInstanceVariable	rubyIdentifier
hi def link rubyPredefinedIdentifier	rubyIdentifier
hi def link rubyPredefinedConstant	rubyPredefinedIdentifier
hi def link rubyPredefinedVariable	rubyPredefinedIdentifier
hi def link rubySymbol			Constant
hi def link rubyKeyword			Keyword
hi def link rubyOperator		Operator
hi def link rubyBeginEnd		Statement
hi def link rubyAccess			Statement
hi def link rubyAttribute		Statement
hi def link rubyEval			Statement
hi def link rubyPseudoVariable		Constant

hi def link rubyComment			Comment
hi def link rubyData			Comment
hi def link rubyDataDirective		Delimiter
hi def link rubyDocumentation		Comment
hi def link rubyTodo			Todo

hi def link rubyQuoteEscape		rubyStringEscape
hi def link rubyStringEscape		Special
hi def link rubyInterpolationDelimiter	Delimiter
hi def link rubyNoInterpolation		rubyString
hi def link rubySharpBang		PreProc
hi def link rubyRegexpDelimiter		rubyStringDelimiter
hi def link rubySymbolDelimiter		rubyStringDelimiter
hi def link rubyStringDelimiter		Delimiter
hi def link rubyHeredoc			rubyString
hi def link rubyString			String
hi def link rubyRegexpEscape		rubyRegexpSpecial
hi def link rubyRegexpQuantifier	rubyRegexpSpecial
hi def link rubyRegexpAnchor		rubyRegexpSpecial
hi def link rubyRegexpDot		rubyRegexpCharClass
hi def link rubyRegexpCharClass		rubyRegexpSpecial
hi def link rubyRegexpSpecial		Special
hi def link rubyRegexpComment		Comment
hi def link rubyRegexp			rubyString

hi def link rubyInvalidVariable		Error
hi def link rubyError			Error
hi def link rubySpaceError		rubyError

let b:current_syntax = "ruby"

" vim: nowrap sw=2 sts=2 ts=8 noet:
