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

" Prelude {{{1
if exists("b:current_syntax")
  finish
endif

" this file uses line continuations
let s:cpo_sav = &cpo
set cpo&vim

" Folding Config {{{1
if has("folding") && exists("ruby_fold")
  setlocal foldmethod=syntax
endif

let s:foldable_groups = split(
      \	  get(
      \	    b:,
      \	    'ruby_foldable_groups',
      \	    get(g:, 'ruby_foldable_groups', 'ALL')
      \	  )
      \	)

function! s:foldable(...) abort
  if index(s:foldable_groups, 'ALL') > -1
    return 1
  endif

  for l:i in a:000
    if index(s:foldable_groups, l:i) > -1
      return 1
    endif
  endfor

  return 0
endfunction " }}}

syn cluster rubyNotTop contains=@rubyExtendedStringSpecial,@rubyRegexpSpecial,@rubyDeclaration,rubyConditional,rubyExceptional,rubyMethodExceptional,rubyTodo

" Whitespace Errors {{{1
if exists("ruby_space_errors")
  if !exists("ruby_no_trail_space_error")
    syn match rubySpaceError display excludenl "\s\+$"
  endif
  if !exists("ruby_no_tab_space_error")
    syn match rubySpaceError display " \+\t"me=e-1
  endif
endif

" Operators {{{1
if exists("ruby_operators")
  syn match  rubyOperator "[~!^|*/%+-]\|&\.\@!\|\%(class\s*\)\@<!<<\|<=>\|<=\|\%(<\|\<class\s\+\u\w*\s*\)\@<!<[^<]\@=\|===\|==\|=\~\|>>\|>=\|=\@1<!>\|\*\*\|\.\.\.\|\.\.\|::"
  syn match  rubyOperator "->\|-=\|/=\|\*\*=\|\*=\|&&=\|&=\|&&\|||=\||=\|||\|%=\|+=\|!\~\|!="
  syn region rubyBracketOperator matchgroup=rubyOperator start="\%(\w[?!]\=\|[]})]\)\@2<=\[\s*" end="\s*]" contains=ALLBUT,@rubyNotTop
endif

" Expression Substitution and Backslash Notation {{{1
syn match rubyStringEscape "\\\\\|\\[abefnrstv]\|\\\o\{1,3}\|\\x\x\{1,2}"						    contained display
syn match rubyStringEscape "\%(\\M-\\C-\|\\C-\\M-\|\\M-\\c\|\\c\\M-\|\\c\|\\C-\|\\M-\)\%(\\\o\{1,3}\|\\x\x\{1,2}\|\\\=\S\)" contained display
syn match rubyQuoteEscape  "\\[\\']"											    contained display

syn region rubyInterpolation	      matchgroup=rubyInterpolationDelimiter start="#{" end="}" contained contains=ALLBUT,@rubyNotTop
syn match  rubyInterpolation	      "#\%(\$\|@@\=\)\w\+"    display contained contains=rubyInterpolationDelimiter,rubyInstanceVariable,rubyClassVariable,rubyGlobalVariable,rubyPredefinedVariable
syn match  rubyInterpolationDelimiter "#\ze\%(\$\|@@\=\)\w\+" display contained
syn match  rubyInterpolation	      "#\$\%(-\w\|\W\)"       display contained contains=rubyInterpolationDelimiter,rubyPredefinedVariable,rubyInvalidVariable
syn match  rubyInterpolationDelimiter "#\ze\$\%(-\w\|\W\)"    display contained
syn region rubyNoInterpolation	      start="\\#{" end="}"	      contained
syn match  rubyNoInterpolation	      "\\#{"		      display contained
syn match  rubyNoInterpolation	      "\\#\%(\$\|@@\=\)\w\+"  display contained
syn match  rubyNoInterpolation	      "\\#\$\W"		      display contained

syn match rubyDelimiterEscape	"\\[(<{\[)>}\]]" transparent display contained contains=NONE

syn region rubyNestedParentheses    start="("  skip="\\\\\|\\)"  matchgroup=rubyString end=")"	transparent contained
syn region rubyNestedCurlyBraces    start="{"  skip="\\\\\|\\}"  matchgroup=rubyString end="}"	transparent contained
syn region rubyNestedAngleBrackets  start="<"  skip="\\\\\|\\>"  matchgroup=rubyString end=">"	transparent contained
syn region rubyNestedSquareBrackets start="\[" skip="\\\\\|\\\]" matchgroup=rubyString end="\]"	transparent contained

" Regular Expression Metacharacters {{{1
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

" Numbers and ASCII Codes {{{1
syn match rubyASCIICode "\%(\w\|[]})\"'/]\)\@1<!\%(?\%(\\M-\\C-\|\\C-\\M-\|\\M-\\c\|\\c\\M-\|\\c\|\\C-\|\\M-\)\=\%(\\\o\{1,3}\|\\x\x\{1,2}\|\\\=\S\)\)"
syn match rubyInteger	"\%(\%(\w\|[]})\"']\s*\)\@<!-\)\=\<0[xX]\x\+\%(_\x\+\)*r\=i\=\>"								display
syn match rubyInteger	"\%(\%(\w\|[]})\"']\s*\)\@<!-\)\=\<\%(0[dD]\)\=\%(0\|[1-9]\d*\%(_\d\+\)*\)r\=i\=\>"						display
syn match rubyInteger	"\%(\%(\w\|[]})\"']\s*\)\@<!-\)\=\<0[oO]\=\o\+\%(_\o\+\)*r\=i\=\>"								display
syn match rubyInteger	"\%(\%(\w\|[]})\"']\s*\)\@<!-\)\=\<0[bB][01]\+\%(_[01]\+\)*r\=i\=\>"								display
syn match rubyFloat	"\%(\%(\w\|[]})\"']\s*\)\@<!-\)\=\<\%(0\|[1-9]\d*\%(_\d\+\)*\)\.\d\+\%(_\d\+\)*r\=i\=\>"					display
syn match rubyFloat	"\%(\%(\w\|[]})\"']\s*\)\@<!-\)\=\<\%(0\|[1-9]\d*\%(_\d\+\)*\)\%(\.\d\+\%(_\d\+\)*\)\=\%([eE][-+]\=\d\+\%(_\d\+\)*\)r\=i\=\>"	display

" Identifiers {{{1
syn match rubyLocalVariableOrMethod "\<[_[:lower:]][_[:alnum:]]*[?!=]\=" contains=NONE display transparent
syn match rubyBlockArgument	    "&[_[:lower:]][_[:alnum:]]"		 contains=NONE display transparent

syn match  rubyConstant		"\%(\%(^\|[^.]\)\.\s*\)\@<!\<\u\%(\w\|[^\x00-\x7F]\)*\>\%(\s*(\)\@!"
syn match  rubyClassVariable	"@@\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*" display
syn match  rubyInstanceVariable "@\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*"	display
syn match  rubyGlobalVariable	"$\%(\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*\|-.\)"
syn match  rubySymbol		"[]})\"':]\@1<!:\%(\^\|\~@\|\~\|<<\|<=>\|<=\|<\|===\|[=!]=\|[=!]\~\|!@\|!\|>>\|>=\|>\||\|-@\|-\|/\|\[]=\|\[]\|\*\*\|\*\|&\|%\|+@\|+\|`\)"
syn match  rubySymbol		"[]})\"':]\@1<!:\$\%(-.\|[`~<=>_,;:!?/.'"@$*\&+0]\)"
syn match  rubySymbol		"[]})\"':]\@1<!:\%(\$\|@@\=\)\=\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*"
syn match  rubySymbol		"[]})\"':]\@1<!:\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*\%([?!=]>\@!\)\="

if s:foldable(':')
  syn region rubySymbol		start="[]})\"':]\@1<!:'"  end="'"  skip="\\\\\|\\'"  contains=rubyQuoteEscape fold
  syn region rubySymbol		start="[]})\"':]\@1<!:\"" end="\"" skip="\\\\\|\\\"" contains=@rubyStringSpecial fold
else
  syn region rubySymbol		start="[]})\"':]\@1<!:'"  end="'"  skip="\\\\\|\\'"  contains=rubyQuoteEscape
  syn region rubySymbol		start="[]})\"':]\@1<!:\"" end="\"" skip="\\\\\|\\\"" contains=@rubyStringSpecial
endif

syn match  rubyCapitalizedMethod	"\%(\%(^\|[^.]\)\.\s*\)\@<!\<\u\%(\w\|[^\x00-\x7F]\)*\>\%(\s*(\)*\s*(\@="

syn match  rubyBlockParameter	  "\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*" contained
syn region rubyBlockParameterList start="\%(\%(\<do\>\|{\)\_s*\)\@32<=|" end="|" oneline display contains=rubyBlockParameter

syn match rubyInvalidVariable	 "$[^ A-Za-z_-]"
syn match rubyPredefinedVariable #$[!$&"'*+,./0:;<=>?@\`~]#
syn match rubyPredefinedVariable "$\d\+"										   display
syn match rubyPredefinedVariable "$_\>"											   display
syn match rubyPredefinedVariable "$-[0FIKadilpvw]\>"									   display
syn match rubyPredefinedVariable "$\%(deferr\|defout\|stderr\|stdin\|stdout\)\>"					   display
syn match rubyPredefinedVariable "$\%(DEBUG\|FILENAME\|KCODE\|LOADED_FEATURES\|LOAD_PATH\|PROGRAM_NAME\|SAFE\|VERBOSE\)\>" display
syn match rubyPredefinedConstant "\%(\%(^\|[^.]\)\.\s*\)\@<!\<\%(ARGF\|ARGV\|ENV\|DATA\|FALSE\|NIL\|STDERR\|STDIN\|STDOUT\|TOPLEVEL_BINDING\|TRUE\)\>\%(\s*(\)\@!"
syn match rubyPredefinedConstant "\%(\%(^\|[^.]\)\.\s*\)\@<!\<\%(RUBY_\%(VERSION\|RELEASE_DATE\|PLATFORM\|PATCHLEVEL\|REVISION\|DESCRIPTION\|COPYRIGHT\|ENGINE\)\)\>\%(\s*(\)\@!"

" Normal Regular Expression {{{1
if s:foldable('/')
  syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="\%(\%(^\|\<\%(and\|or\|while\|until\|unless\|if\|elsif\|when\|not\|then\|else\)\|[;\~=!|&(,{[<>?:*+-]\)\s*\)\@<=/" end="/[iomxneus]*" skip="\\\\\|\\/" contains=@rubyRegexpSpecial fold
  syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="\%(\h\k*\s\+\)\@<=/[ \t=]\@!" end="/[iomxneus]*" skip="\\\\\|\\/" contains=@rubyRegexpSpecial fold
else
  syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="\%(\%(^\|\<\%(and\|or\|while\|until\|unless\|if\|elsif\|when\|not\|then\|else\)\|[;\~=!|&(,{[<>?:*+-]\)\s*\)\@<=/" end="/[iomxneus]*" skip="\\\\\|\\/" contains=@rubyRegexpSpecial
  syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="\%(\h\k*\s\+\)\@<=/[ \t=]\@!" end="/[iomxneus]*" skip="\\\\\|\\/" contains=@rubyRegexpSpecial
endif

" Generalized Regular Expression {{{1
if s:foldable('%')
  syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)" end="\z1[iomxneus]*" skip="\\\\\|\\\z1" contains=@rubyRegexpSpecial fold
  syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r{"				end="}[iomxneus]*"   skip="\\\\\|\\}"	 contains=@rubyRegexpSpecial fold
  syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r<"				end=">[iomxneus]*"   skip="\\\\\|\\>"	 contains=@rubyRegexpSpecial,rubyNestedAngleBrackets,rubyDelimiterEscape fold
  syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r\["				end="\][iomxneus]*"  skip="\\\\\|\\\]"	 contains=@rubyRegexpSpecial fold
  syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r("				end=")[iomxneus]*"   skip="\\\\\|\\)"	 contains=@rubyRegexpSpecial fold
  syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r\z(\s\)"				end="\z1[iomxneus]*" skip="\\\\\|\\\z1" contains=@rubyRegexpSpecial fold
else
  syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)" end="\z1[iomxneus]*" skip="\\\\\|\\\z1" contains=@rubyRegexpSpecial
  syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r{"				end="}[iomxneus]*"   skip="\\\\\|\\}"	 contains=@rubyRegexpSpecial
  syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r<"				end=">[iomxneus]*"   skip="\\\\\|\\>"	 contains=@rubyRegexpSpecial,rubyNestedAngleBrackets,rubyDelimiterEscape
  syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r\["				end="\][iomxneus]*"  skip="\\\\\|\\\]"	 contains=@rubyRegexpSpecial
  syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r("				end=")[iomxneus]*"   skip="\\\\\|\\)"	 contains=@rubyRegexpSpecial
  syn region rubyRegexp matchgroup=rubyRegexpDelimiter start="%r\z(\s\)"				end="\z1[iomxneus]*" skip="\\\\\|\\\z1" contains=@rubyRegexpSpecial
endif

" Normal String {{{1
let s:spell_cluster = exists('ruby_spellcheck_strings') ? ',@Spell' : ''
exe 'syn region rubyString matchgroup=rubyStringDelimiter start="\"" end="\"" skip="\\\\\|\\\"" ' .
      \ (s:foldable('%') ? 'fold' : '') . ' contains=@rubyStringSpecial' . s:spell_cluster
exe 'syn region rubyString matchgroup=rubyStringDelimiter start="''" end="''" skip="\\\\\|\\''" ' .
      \ (s:foldable('%') ? 'fold' : '') . ' contains=rubyQuoteEscape'	 . s:spell_cluster

" Shell Command Output {{{1
if s:foldable('%')
  syn region rubyString matchgroup=rubyStringDelimiter start="`" end="`" skip="\\\\\|\\`" contains=@rubyStringSpecial fold
else
  syn region rubyString matchgroup=rubyStringDelimiter start="`" end="`" skip="\\\\\|\\`" contains=@rubyStringSpecial
endif

" Generalized Single Quoted String, Symbol and Array of Strings {{{1
if s:foldable('%')
  syn region rubyString matchgroup=rubyStringDelimiter start="%[qw]\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)" end="\z1" skip="\\\\\|\\\z1" fold
  syn region rubyString matchgroup=rubyStringDelimiter start="%[qw]{"				     end="}"   skip="\\\\\|\\}"	  fold contains=rubyNestedCurlyBraces,rubyDelimiterEscape
  syn region rubyString matchgroup=rubyStringDelimiter start="%[qw]<"				     end=">"   skip="\\\\\|\\>"	  fold contains=rubyNestedAngleBrackets,rubyDelimiterEscape
  syn region rubyString matchgroup=rubyStringDelimiter start="%[qw]\["				     end="\]"  skip="\\\\\|\\\]"  fold contains=rubyNestedSquareBrackets,rubyDelimiterEscape
  syn region rubyString matchgroup=rubyStringDelimiter start="%[qw]("				     end=")"   skip="\\\\\|\\)"	  fold contains=rubyNestedParentheses,rubyDelimiterEscape
  syn region rubyString matchgroup=rubyStringDelimiter start="%q\z(\s\)"			     end="\z1" skip="\\\\\|\\\z1" fold
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%s\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)"    end="\z1" skip="\\\\\|\\\z1" fold
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%s{"				     end="}"   skip="\\\\\|\\}"	  fold contains=rubyNestedCurlyBraces,rubyDelimiterEscape
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%s<"				     end=">"   skip="\\\\\|\\>"	  fold contains=rubyNestedAngleBrackets,rubyDelimiterEscape
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%s\["				     end="\]"  skip="\\\\\|\\\]"  fold contains=rubyNestedSquareBrackets,rubyDelimiterEscape
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%s("				     end=")"   skip="\\\\\|\\)"	  fold contains=rubyNestedParentheses,rubyDelimiterEscape
  syn region rubyString matchgroup=rubyStringDelimiter start="%s\z(\s\)"			     end="\z1" skip="\\\\\|\\\z1" fold
else
  syn region rubyString matchgroup=rubyStringDelimiter start="%[qw]\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)" end="\z1" skip="\\\\\|\\\z1"
  syn region rubyString matchgroup=rubyStringDelimiter start="%[qw]{"				     end="}"   skip="\\\\\|\\}"	  contains=rubyNestedCurlyBraces,rubyDelimiterEscape
  syn region rubyString matchgroup=rubyStringDelimiter start="%[qw]<"				     end=">"   skip="\\\\\|\\>"	  contains=rubyNestedAngleBrackets,rubyDelimiterEscape
  syn region rubyString matchgroup=rubyStringDelimiter start="%[qw]\["				     end="\]"  skip="\\\\\|\\\]"  contains=rubyNestedSquareBrackets,rubyDelimiterEscape
  syn region rubyString matchgroup=rubyStringDelimiter start="%[qw]("				     end=")"   skip="\\\\\|\\)"	  contains=rubyNestedParentheses,rubyDelimiterEscape
  syn region rubyString matchgroup=rubyStringDelimiter start="%q\z(\s\)"			     end="\z1" skip="\\\\\|\\\z1"
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%s\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)"    end="\z1" skip="\\\\\|\\\z1"
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%s{"				     end="}"   skip="\\\\\|\\}"	  contains=rubyNestedCurlyBraces,rubyDelimiterEscape
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%s<"				     end=">"   skip="\\\\\|\\>"	  contains=rubyNestedAngleBrackets,rubyDelimiterEscape
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%s\["				     end="\]"  skip="\\\\\|\\\]"  contains=rubyNestedSquareBrackets,rubyDelimiterEscape
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%s("				     end=")"   skip="\\\\\|\\)"	  contains=rubyNestedParentheses,rubyDelimiterEscape
  syn region rubyString matchgroup=rubyStringDelimiter start="%s\z(\s\)"			     end="\z1" skip="\\\\\|\\\z1"
endif

" Generalized Double Quoted String and Array of Strings and Shell Command Output {{{1
" Note: %= is not matched here as the beginning of a double quoted string
if s:foldable('%')
  syn region rubyString matchgroup=rubyStringDelimiter start="%\z([~`!@#$%^&*_\-+|\:;"',.?/]\)"	      end="\z1" skip="\\\\\|\\\z1" contains=@rubyStringSpecial fold
  syn region rubyString matchgroup=rubyStringDelimiter start="%[QWx]\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)" end="\z1" skip="\\\\\|\\\z1" contains=@rubyStringSpecial fold
  syn region rubyString matchgroup=rubyStringDelimiter start="%[QWx]\={"			      end="}"	skip="\\\\\|\\}"   contains=@rubyStringSpecial,rubyNestedCurlyBraces,rubyDelimiterEscape    fold
  syn region rubyString matchgroup=rubyStringDelimiter start="%[QWx]\=<"			      end=">"	skip="\\\\\|\\>"   contains=@rubyStringSpecial,rubyNestedAngleBrackets,rubyDelimiterEscape  fold
  syn region rubyString matchgroup=rubyStringDelimiter start="%[QWx]\=\["			      end="\]"	skip="\\\\\|\\\]"  contains=@rubyStringSpecial,rubyNestedSquareBrackets,rubyDelimiterEscape fold
  syn region rubyString matchgroup=rubyStringDelimiter start="%[QWx]\=("			      end=")"	skip="\\\\\|\\)"   contains=@rubyStringSpecial,rubyNestedParentheses,rubyDelimiterEscape    fold
  syn region rubyString matchgroup=rubyStringDelimiter start="%[Qx]\z(\s\)"			      end="\z1" skip="\\\\\|\\\z1" contains=@rubyStringSpecial fold
else
  syn region rubyString matchgroup=rubyStringDelimiter start="%\z([~`!@#$%^&*_\-+|\:;"',.?/]\)"	      end="\z1" skip="\\\\\|\\\z1" contains=@rubyStringSpecial
  syn region rubyString matchgroup=rubyStringDelimiter start="%[QWx]\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)" end="\z1" skip="\\\\\|\\\z1" contains=@rubyStringSpecial
  syn region rubyString matchgroup=rubyStringDelimiter start="%[QWx]\={"			      end="}"	skip="\\\\\|\\}"   contains=@rubyStringSpecial,rubyNestedCurlyBraces,rubyDelimiterEscape
  syn region rubyString matchgroup=rubyStringDelimiter start="%[QWx]\=<"			      end=">"	skip="\\\\\|\\>"   contains=@rubyStringSpecial,rubyNestedAngleBrackets,rubyDelimiterEscape
  syn region rubyString matchgroup=rubyStringDelimiter start="%[QWx]\=\["			      end="\]"	skip="\\\\\|\\\]"  contains=@rubyStringSpecial,rubyNestedSquareBrackets,rubyDelimiterEscape
  syn region rubyString matchgroup=rubyStringDelimiter start="%[QWx]\=("			      end=")"	skip="\\\\\|\\)"   contains=@rubyStringSpecial,rubyNestedParentheses,rubyDelimiterEscape
  syn region rubyString matchgroup=rubyStringDelimiter start="%[Qx]\z(\s\)"			      end="\z1" skip="\\\\\|\\\z1" contains=@rubyStringSpecial
endif

" Array of Symbols {{{1
if s:foldable('%')
  " Array of Symbols
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%i\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)" end="\z1" skip="\\\\\|\\\z1"	fold
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%i{"				  end="}"   skip="\\\\\|\\}"	fold contains=rubyNestedCurlyBraces,rubyDelimiterEscape
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%i<"				  end=">"   skip="\\\\\|\\>"	fold contains=rubyNestedAngleBrackets,rubyDelimiterEscape
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%i\["				  end="\]"  skip="\\\\\|\\\]"	fold contains=rubyNestedSquareBrackets,rubyDelimiterEscape
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%i("				  end=")"   skip="\\\\\|\\)"	fold contains=rubyNestedParentheses,rubyDelimiterEscape

  " Array of interpolated Symbols
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%I\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)" end="\z1" skip="\\\\\|\\\z1"	contains=@rubyStringSpecial fold
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%I{"				  end="}"   skip="\\\\\|\\}"	contains=@rubyStringSpecial,rubyNestedCurlyBraces,rubyDelimiterEscape    fold
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%I<"				  end=">"   skip="\\\\\|\\>"	contains=@rubyStringSpecial,rubyNestedAngleBrackets,rubyDelimiterEscape  fold
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%I\["				  end="\]"  skip="\\\\\|\\\]"	contains=@rubyStringSpecial,rubyNestedSquareBrackets,rubyDelimiterEscape fold
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%I("				  end=")"   skip="\\\\\|\\)"	contains=@rubyStringSpecial,rubyNestedParentheses,rubyDelimiterEscape    fold
else
  " Array of Symbols
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%i\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)" end="\z1" skip="\\\\\|\\\z1"
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%i{"				  end="}"   skip="\\\\\|\\}"	contains=rubyNestedCurlyBraces,rubyDelimiterEscape
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%i<"				  end=">"   skip="\\\\\|\\>"	contains=rubyNestedAngleBrackets,rubyDelimiterEscape
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%i\["				  end="\]"  skip="\\\\\|\\\]"	contains=rubyNestedSquareBrackets,rubyDelimiterEscape
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%i("				  end=")"   skip="\\\\\|\\)"	contains=rubyNestedParentheses,rubyDelimiterEscape

  " Array of interpolated Symbols
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%I\z([~`!@#$%^&*_\-+=|\:;"',.?/]\)" end="\z1" skip="\\\\\|\\\z1"	contains=@rubyStringSpecial
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%I{"				  end="}"   skip="\\\\\|\\}"	contains=@rubyStringSpecial,rubyNestedCurlyBraces,rubyDelimiterEscape
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%I<"				  end=">"   skip="\\\\\|\\>"	contains=@rubyStringSpecial,rubyNestedAngleBrackets,rubyDelimiterEscape
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%I\["				  end="\]"  skip="\\\\\|\\\]"	contains=@rubyStringSpecial,rubyNestedSquareBrackets,rubyDelimiterEscape
  syn region rubySymbol matchgroup=rubySymbolDelimiter start="%I("				  end=")"   skip="\\\\\|\\)"	contains=@rubyStringSpecial,rubyNestedParentheses,rubyDelimiterEscape
endif

" Here Document {{{1
syn region rubyHeredocStart matchgroup=rubyStringDelimiter start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<[-~]\=\zs\%(\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*\)+	 end=+$+ oneline contains=ALLBUT,@rubyNotTop
syn region rubyHeredocStart matchgroup=rubyStringDelimiter start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<[-~]\=\zs"\%([^"]*\)"+ end=+$+ oneline contains=ALLBUT,@rubyNotTop
syn region rubyHeredocStart matchgroup=rubyStringDelimiter start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<[-~]\=\zs'\%([^']*\)'+ end=+$+ oneline contains=ALLBUT,@rubyNotTop
syn region rubyHeredocStart matchgroup=rubyStringDelimiter start=+\%(\%(class\s*\|\%([]})"'.]\|::\)\)\_s*\|\w\)\@<!<<[-~]\=\zs`\%([^`]*\)`+ end=+$+ oneline contains=ALLBUT,@rubyNotTop

if s:foldable('<<')
  syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]})"'.]\)\s\|\w\)\@<!<<\z(\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*\)\ze\%(.*<<[-~]\=['`"]\=\h\)\@!+hs=s+2	matchgroup=rubyStringDelimiter end=+^\z1$+ contains=rubyHeredocStart,rubyHeredoc,@rubyStringSpecial fold keepend
  syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]})"'.]\)\s\|\w\)\@<!<<"\z([^"]*\)"\ze\%(.*<<[-~]\=['`"]\=\h\)\@!+hs=s+2	matchgroup=rubyStringDelimiter end=+^\z1$+ contains=rubyHeredocStart,rubyHeredoc,@rubyStringSpecial fold keepend
  syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]})"'.]\)\s\|\w\)\@<!<<'\z([^']*\)'\ze\%(.*<<[-~]\=['`"]\=\h\)\@!+hs=s+2	matchgroup=rubyStringDelimiter end=+^\z1$+ contains=rubyHeredocStart,rubyHeredoc		    fold keepend
  syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]})"'.]\)\s\|\w\)\@<!<<`\z([^`]*\)`\ze\%(.*<<[-~]\=['`"]\=\h\)\@!+hs=s+2	matchgroup=rubyStringDelimiter end=+^\z1$+ contains=rubyHeredocStart,rubyHeredoc,@rubyStringSpecial fold keepend

  syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]}).]\)\s\|\w\)\@<!<<[-~]\z(\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*\)\ze\%(.*<<[-~]\=['`"]\=\h\)\@!+hs=s+3    matchgroup=rubyStringDelimiter end=+^\s*\zs\z1$+ contains=rubyHeredocStart,@rubyStringSpecial fold keepend
  syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]}).]\)\s\|\w\)\@<!<<[-~]"\z([^"]*\)"\ze\%(.*<<[-~]\=['`"]\=\h\)\@!+hs=s+3  matchgroup=rubyStringDelimiter end=+^\s*\zs\z1$+ contains=rubyHeredocStart,@rubyStringSpecial fold keepend
  syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]}).]\)\s\|\w\)\@<!<<[-~]'\z([^']*\)'\ze\%(.*<<[-~]\=['`"]\=\h\)\@!+hs=s+3  matchgroup=rubyStringDelimiter end=+^\s*\zs\z1$+ contains=rubyHeredocStart		    fold keepend
  syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]}).]\)\s\|\w\)\@<!<<[-~]`\z([^`]*\)`\ze\%(.*<<[-~]\=['`"]\=\h\)\@!+hs=s+3  matchgroup=rubyStringDelimiter end=+^\s*\zs\z1$+ contains=rubyHeredocStart,@rubyStringSpecial fold keepend
else
  syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]})"'.]\)\s\|\w\)\@<!<<\z(\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*\)\ze\%(.*<<[-~]\=['`"]\=\h\)\@!+hs=s+2	matchgroup=rubyStringDelimiter end=+^\z1$+ contains=rubyHeredocStart,rubyHeredoc,@rubyStringSpecial keepend
  syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]})"'.]\)\s\|\w\)\@<!<<"\z([^"]*\)"\ze\%(.*<<[-~]\=['`"]\=\h\)\@!+hs=s+2	matchgroup=rubyStringDelimiter end=+^\z1$+ contains=rubyHeredocStart,rubyHeredoc,@rubyStringSpecial keepend
  syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]})"'.]\)\s\|\w\)\@<!<<'\z([^']*\)'\ze\%(.*<<[-~]\=['`"]\=\h\)\@!+hs=s+2	matchgroup=rubyStringDelimiter end=+^\z1$+ contains=rubyHeredocStart,rubyHeredoc		    keepend
  syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]})"'.]\)\s\|\w\)\@<!<<`\z([^`]*\)`\ze\%(.*<<[-~]\=['`"]\=\h\)\@!+hs=s+2	matchgroup=rubyStringDelimiter end=+^\z1$+ contains=rubyHeredocStart,rubyHeredoc,@rubyStringSpecial keepend

  syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]}).]\)\s\|\w\)\@<!<<[-~]\z(\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*\)\ze\%(.*<<[-~]\=['`"]\=\h\)\@!+hs=s+3    matchgroup=rubyStringDelimiter end=+^\s*\zs\z1$+ contains=rubyHeredocStart,@rubyStringSpecial keepend
  syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]}).]\)\s\|\w\)\@<!<<[-~]"\z([^"]*\)"\ze\%(.*<<[-~]\=['`"]\=\h\)\@!+hs=s+3  matchgroup=rubyStringDelimiter end=+^\s*\zs\z1$+ contains=rubyHeredocStart,@rubyStringSpecial keepend
  syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]}).]\)\s\|\w\)\@<!<<[-~]'\z([^']*\)'\ze\%(.*<<[-~]\=['`"]\=\h\)\@!+hs=s+3  matchgroup=rubyStringDelimiter end=+^\s*\zs\z1$+ contains=rubyHeredocStart		    keepend
  syn region rubyString start=+\%(\%(class\|::\)\_s*\|\%([]}).]\)\s\|\w\)\@<!<<[-~]`\z([^`]*\)`\ze\%(.*<<[-~]\=['`"]\=\h\)\@!+hs=s+3  matchgroup=rubyStringDelimiter end=+^\s*\zs\z1$+ contains=rubyHeredocStart,@rubyStringSpecial keepend
endif

" eRuby Config {{{1
if exists('main_syntax') && main_syntax == 'eruby'
  let b:ruby_no_expensive = 1
end

" Module, Class, Method and Alias Declarations {{{1
syn match  rubyAliasDeclaration    "[^[:space:];#.()]\+" contained contains=rubySymbol,rubyGlobalVariable,rubyPredefinedVariable nextgroup=rubyAliasDeclaration2 skipwhite
syn match  rubyAliasDeclaration2   "[^[:space:];#.()]\+" contained contains=rubySymbol,rubyGlobalVariable,rubyPredefinedVariable
syn match  rubyMethodDeclaration   "[^[:space:];#(]\+"	 contained contains=rubyConstant,rubyBoolean,rubyPseudoVariable,rubyInstanceVariable,rubyClassVariable,rubyGlobalVariable
syn match  rubyClassDeclaration    "[^[:space:];#<]\+"	 contained contains=rubyConstant,rubyOperator
syn match  rubyModuleDeclaration   "[^[:space:];#<]\+"	 contained contains=rubyConstant,rubyOperator
syn match  rubyFunction "\<[_[:alpha:]][_[:alnum:]]*[?!=]\=[[:alnum:]_.:?!=]\@!" contained containedin=rubyMethodDeclaration
syn match  rubyFunction "\%(\s\|^\)\@1<=[_[:alpha:]][_[:alnum:]]*[?!=]\=\%(\s\|$\)\@=" contained containedin=rubyAliasDeclaration,rubyAliasDeclaration2
syn match  rubyFunction "\%([[:space:].]\|^\)\@2<=\%(\[\]=\=\|\*\*\|[-+!~]@\=\|[*/%|&^~]\|<<\|>>\|[<>]=\=\|<=>\|===\|[=!]=\|[=!]\~\|!\|`\)\%([[:space:];#(]\|$\)\@=" contained containedin=rubyAliasDeclaration,rubyAliasDeclaration2,rubyMethodDeclaration

syn cluster rubyDeclaration contains=rubyAliasDeclaration,rubyAliasDeclaration2,rubyMethodDeclaration,rubyModuleDeclaration,rubyClassDeclaration,rubyFunction,rubyBlockParameter

" Keywords {{{1
" Note: the following keywords have already been defined:
" begin case class def do end for if module unless until while
syn match   rubyControl	       "\<\%(and\|break\|in\|next\|not\|or\|redo\|rescue\|retry\|return\)\>[?!]\@!"
syn match   rubyOperator       "\<defined?" display
syn match   rubyKeyword	       "\<\%(super\|yield\)\>[?!]\@!"
syn match   rubyBoolean	       "\<\%(true\|false\)\>[?!]\@!"
syn match   rubyPseudoVariable "\<\%(nil\|self\|__ENCODING__\|__dir__\|__FILE__\|__LINE__\|__callee__\|__method__\)\>[?!]\@!" " TODO: reorganise
syn match   rubyBeginEnd       "\<\%(BEGIN\|END\)\>[?!]\@!"

" Expensive Mode {{{1
" Match 'end' with the appropriate opening keyword for syntax based folding
" and special highlighting of module/class/method definitions
if !exists("b:ruby_no_expensive") && !exists("ruby_no_expensive")
  syn match  rubyDefine "\<alias\>"  nextgroup=rubyAliasDeclaration  skipwhite skipnl
  syn match  rubyDefine "\<def\>"    nextgroup=rubyMethodDeclaration skipwhite skipnl
  syn match  rubyDefine "\<undef\>"  nextgroup=rubyFunction	     skipwhite skipnl
  syn match  rubyClass	"\<class\>"  nextgroup=rubyClassDeclaration  skipwhite skipnl
  syn match  rubyModule "\<module\>" nextgroup=rubyModuleDeclaration skipwhite skipnl

  if s:foldable('def')
    syn region rubyMethodBlock start="\<def\>"	matchgroup=rubyDefine end="\%(\<def\_s\+\)\@<!\<end\>" contains=ALLBUT,@rubyNotTop fold
  else
    syn region rubyMethodBlock start="\<def\>"	matchgroup=rubyDefine end="\%(\<def\_s\+\)\@<!\<end\>" contains=ALLBUT,@rubyNotTop
  endif

  if s:foldable('class')
    syn region rubyBlock start="\<class\>"	matchgroup=rubyClass end="\<end\>" contains=ALLBUT,@rubyNotTop fold
  else
    syn region rubyBlock start="\<class\>"	matchgroup=rubyClass end="\<end\>" contains=ALLBUT,@rubyNotTop
  endif

  if s:foldable('module')
    syn region rubyBlock start="\<module\>" matchgroup=rubyModule end="\<end\>" contains=ALLBUT,@rubyNotTop fold
  else
    syn region rubyBlock start="\<module\>" matchgroup=rubyModule end="\<end\>" contains=ALLBUT,@rubyNotTop
  endif

  " modifiers
  syn match rubyLineContinuation    "\\$" nextgroup=rubyConditionalModifier,rubyRepeatModifier skipwhite skipnl
  syn match rubyConditionalModifier "\<\%(if\|unless\)\>"
  syn match rubyRepeatModifier	    "\<\%(while\|until\)\>"

  if s:foldable('do')
    syn region rubyDoBlock matchgroup=rubyControl start="\<do\>" end="\<end\>" contains=ALLBUT,@rubyNotTop fold
  else
    syn region rubyDoBlock matchgroup=rubyControl start="\<do\>" end="\<end\>" contains=ALLBUT,@rubyNotTop
  endif

  " curly bracket block or hash literal
  if s:foldable('{')
    syn region rubyCurlyBlock matchgroup=rubyCurlyBlockDelimiter start="{" end="}" contains=ALLBUT,@rubyNotTop fold
  else
    syn region rubyCurlyBlock matchgroup=rubyCurlyBlockDelimiter start="{" end="}" contains=ALLBUT,@rubyNotTop
  endif

  if s:foldable('[')
    syn region rubyArrayLiteral	matchgroup=rubyArrayDelimiter start="\%(\w\|[\]})]\)\@<!\[" end="]" contains=ALLBUT,@rubyNotTop fold
  else
    syn region rubyArrayLiteral	matchgroup=rubyArrayDelimiter start="\%(\w\|[\]})]\)\@<!\[" end="]" contains=ALLBUT,@rubyNotTop
  endif

  " statements without 'do'
  if s:foldable('begin')
    syn region rubyBlockExpression matchgroup=rubyControl start="\<begin\>" end="\<end\>" contains=ALLBUT,@rubyNotTop fold
  else
    syn region rubyBlockExpression matchgroup=rubyControl start="\<begin\>" end="\<end\>" contains=ALLBUT,@rubyNotTop
  endif

  if s:foldable('case')
    syn region rubyCaseExpression matchgroup=rubyConditional start="\<case\>" end="\<end\>" contains=ALLBUT,@rubyNotTop fold
  else
    syn region rubyCaseExpression matchgroup=rubyConditional start="\<case\>" end="\<end\>" contains=ALLBUT,@rubyNotTop
  endif

  if s:foldable('if')
    syn region rubyConditionalExpression matchgroup=rubyConditional start="\%(\%(^\|\.\.\.\=\|[{:,;([<>~\*%&^|+=-]\|\%(\<[_[:lower:]][_[:alnum:]]*\)\@<![?!]\)\s*\)\@<=\%(if\|unless\)\>" end="\%(\%(\%(\.\@1<!\.\)\|::\)\s*\)\@<!\<end\>" contains=ALLBUT,@rubyNotTop fold
  else
    syn region rubyConditionalExpression matchgroup=rubyConditional start="\%(\%(^\|\.\.\.\=\|[{:,;([<>~\*%&^|+=-]\|\%(\<[_[:lower:]][_[:alnum:]]*\)\@<![?!]\)\s*\)\@<=\%(if\|unless\)\>" end="\%(\%(\%(\.\@1<!\.\)\|::\)\s*\)\@<!\<end\>" contains=ALLBUT,@rubyNotTop
  endif

  syn match rubyConditional "\<\%(then\|else\|when\)\>[?!]\@!"	contained containedin=rubyCaseExpression
  syn match rubyConditional "\<\%(then\|else\|elsif\)\>[?!]\@!" contained containedin=rubyConditionalExpression

  syn match rubyExceptional	  "\<\%(\%(\%(;\|^\)\s*\)\@<=rescue\|else\|ensure\)\>[?!]\@!" contained containedin=rubyBlockExpression
  syn match rubyMethodExceptional "\<\%(\%(\%(;\|^\)\s*\)\@<=rescue\|else\|ensure\)\>[?!]\@!" contained containedin=rubyMethodBlock

  " statements with optional 'do'
  syn region rubyOptionalDoLine   matchgroup=rubyRepeat start="\<for\>[?!]\@!" start="\%(\%(^\|\.\.\.\=\|[{:,;([<>~\*/%&^|+-]\|\%(\<[_[:lower:]][_[:alnum:]]*\)\@<![!=?]\)\s*\)\@<=\<\%(until\|while\)\>" matchgroup=rubyOptionalDo end="\%(\<do\>\)" end="\ze\%(;\|$\)" oneline contains=ALLBUT,@rubyNotTop

  if s:foldable('for')
    syn region rubyRepeatExpression start="\<for\>[?!]\@!" start="\%(\%(^\|\.\.\.\=\|[{:,;([<>~\*/%&^|+-]\|\%(\<[_[:lower:]][_[:alnum:]]*\)\@<![!=?]\)\s*\)\@<=\<\%(until\|while\)\>" matchgroup=rubyRepeat end="\<end\>" contains=ALLBUT,@rubyNotTop nextgroup=rubyOptionalDoLine fold
  else
    syn region rubyRepeatExpression start="\<for\>[?!]\@!" start="\%(\%(^\|\.\.\.\=\|[{:,;([<>~\*/%&^|+-]\|\%(\<[_[:lower:]][_[:alnum:]]*\)\@<![!=?]\)\s*\)\@<=\<\%(until\|while\)\>" matchgroup=rubyRepeat end="\<end\>" contains=ALLBUT,@rubyNotTop nextgroup=rubyOptionalDoLine
  endif

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

" Special Methods {{{1
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
  syn keyword rubyInclude   autoload extend load prepend refine require require_relative using
  syn keyword rubyKeyword   callcc caller lambda proc
endif

" Comments and Documentation {{{1
syn match   rubySharpBang "\%^#!.*" display
syn keyword rubyTodo	  FIXME NOTE TODO OPTIMIZE HACK REVIEW XXX todo contained
syn match   rubyComment   "#.*" contains=rubySharpBang,rubySpaceError,rubyTodo,@Spell
if !exists("ruby_no_comment_fold") && s:foldable('#')
  syn region rubyMultilineComment start="^\s*#.*\n\%(^\s*#\)\@=" end="^\s*#.*\n\%(^\s*#\)\@!" contains=rubyComment transparent fold keepend
  syn region rubyDocumentation	  start="^=begin\ze\%(\s.*\)\=$" end="^=end\%(\s.*\)\=$" contains=rubySpaceError,rubyTodo,@Spell fold
else
  syn region rubyDocumentation	  start="^=begin\s*$" end="^=end\s*$" contains=rubySpaceError,rubyTodo,@Spell
endif

" Keyword Nobbling {{{1
" Note: this is a hack to prevent 'keywords' being highlighted as such when called as methods with an explicit receiver
syn match rubyKeywordAsMethod "\%(\%(\.\@1<!\.\)\|::\)\_s*\%([_[:lower:]][_[:alnum:]]*\|\<\%(BEGIN\|END\)\>\)" transparent contains=NONE
syn match rubyKeywordAsMethod "\(defined?\|exit!\)\@!\<[_[:lower:]][_[:alnum:]]*[?!]"			       transparent contains=NONE

" More Symbols {{{1
syn match  rubySymbol		"\%([{(,]\_s*\)\zs\l\w*[!?]\=::\@!"he=e-1
syn match  rubySymbol		"[]})\"':]\@1<!\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*[!?]\=:[[:space:],]\@="he=e-1
syn match  rubySymbol		"\%([{(,]\_s*\)\zs[[:space:],{]\l\w*[!?]\=::\@!"hs=s+1,he=e-1
syn match  rubySymbol		"[[:space:],{(]\%(\h\|[^\x00-\x7F]\)\%(\w\|[^\x00-\x7F]\)*[!?]\=:[[:space:],]\@="hs=s+1,he=e-1

" __END__ Directive {{{1
if s:foldable('__END__')
  syn region rubyData matchgroup=rubyDataDirective start="^__END__$" end="\%$" fold
else
  syn region rubyData matchgroup=rubyDataDirective start="^__END__$" end="\%$"
endif

" Default Highlighting {{{1
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
hi def link rubyCapitalizedMethod	rubyLocalVariableOrMethod

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
hi def link rubySymbolDelimiter		rubySymbol
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

" Postscript {{{1
let b:current_syntax = "ruby"

let &cpo = s:cpo_sav
unlet! s:cpo_sav

" vim: nowrap sw=2 sts=2 ts=8 noet fdm=marker:
