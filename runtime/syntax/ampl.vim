" Language:     ampl (A Mathematical Programming Language)
" Maintainer:   Krief David <david.krief@etu.enseeiht.fr> or <david_krief@hotmail.com>
" Last Change:  2003 May 11


if version < 600
 syntax clear
elseif exists("b:current_syntax")
 finish
endif




"--
syn match   amplEntityKeyword     "\(subject to\)\|\(subj to\)\|\(s\.t\.\)"
syn keyword amplEntityKeyword	  minimize   maximize  objective

syn keyword amplEntityKeyword	  coeff      coef      cover	    obj       default
syn keyword amplEntityKeyword	  from	     to        to_come	    net_in    net_out
syn keyword amplEntityKeyword	  dimen      dimension



"--
syn keyword amplType		  integer    binary    set	    param     var
syn keyword amplType		  node	     ordered   circular     reversed  symbolic
syn keyword amplType		  arc



"--
syn keyword amplStatement	  check      close     \display     drop      include
syn keyword amplStatement	  print      printf    quit	    reset     restore
syn keyword amplStatement	  solve      update    write	    shell     model
syn keyword amplStatement	  data	     option    let	    solution  fix
syn keyword amplStatement	  unfix      end       function     pipe      format



"--
syn keyword amplConditional	  if	     then      else	    and       or
syn keyword amplConditional	  exists     forall    in	    not       within



"--
syn keyword amplRepeat		  while      repeat    for



"--
syn keyword amplOperators	  union      diff      difference   symdiff   sum
syn keyword amplOperators	  inter      intersect intersection cross     setof
syn keyword amplOperators	  by	     less      mod	    div       product
"syn keyword amplOperators	   min	      max
"conflict between functions max, min and operators max, min

syn match   amplBasicOperators    "||\|<=\|==\|\^\|<\|=\|!\|-\|\.\.\|:="
syn match   amplBasicOperators    "&&\|>=\|!=\|\*\|>\|:\|/\|+\|\*\*"




"--
syn match   amplComment		"\#.*"
syn region  amplComment		start=+\/\*+		  end=+\*\/+

syn region  amplStrings		start=+\'+    skip=+\\'+  end=+\'+
syn region  amplStrings		start=+\"+    skip=+\\"+  end=+\"+

syn match   amplNumerics	"[+-]\=\<\d\+\(\.\d\+\)\=\([dDeE][-+]\=\d\+\)\=\>"
syn match   amplNumerics	"[+-]\=Infinity"


"--
syn keyword amplSetFunction	  card	     next     nextw	  prev	    prevw
syn keyword amplSetFunction	  first      last     member	  ord	    ord0

syn keyword amplBuiltInFunction   abs	     acos     acosh	  alias     asin
syn keyword amplBuiltInFunction   asinh      atan     atan2	  atanh     ceil
syn keyword amplBuiltInFunction   cos	     exp      floor	  log	    log10
syn keyword amplBuiltInFunction   max	     min      precision   round     sin
syn keyword amplBuiltInFunction   sinh	     sqrt     tan	  tanh	    trunc

syn keyword amplRandomGenerator   Beta	     Cauchy   Exponential Gamma     Irand224
syn keyword amplRandomGenerator   Normal     Poisson  Uniform	  Uniform01



"-- to highlight the 'dot-suffixes'
syn match   amplDotSuffix	"\h\w*\.\(lb\|ub\)"hs=e-2
syn match   amplDotSuffix	"\h\w*\.\(lb0\|lb1\|lb2\|lrc\|ub0\)"hs=e-3
syn match   amplDotSuffix	"\h\w*\.\(ub1\|ub2\|urc\|val\|lbs\|ubs\)"hs=e-3
syn match   amplDotSuffix	"\h\w*\.\(init\|body\|dinit\|dual\)"hs=e-4
syn match   amplDotSuffix	"\h\w*\.\(init0\|ldual\|slack\|udual\)"hs=e-5
syn match   amplDotSuffix	"\h\w*\.\(lslack\|uslack\|dinit0\)"hs=e-6



"--
syn match   amplPiecewise	"<<\|>>"



"-- Todo.
syn keyword amplTodo contained	 TODO FIXME XXX










if version >= 508 || !exists("did_ampl_syntax_inits")
  if version < 508
    let did_ampl_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  " The default methods for highlighting. Can be overridden later.
  HiLink amplEntityKeyword	Keyword
  HiLink amplType		Type
  HiLink amplStatement		Statement
  HiLink amplOperators		Operator
  HiLink amplBasicOperators	Operator
  HiLink amplConditional	Conditional
  HiLink amplRepeat		Repeat
  HiLink amplStrings		String
  HiLink amplNumerics		Number
  HiLink amplSetFunction	Function
  HiLink amplBuiltInFunction	Function
  HiLink amplRandomGenerator	Function
  HiLink amplComment		Comment
  HiLink amplDotSuffix		Special
  HiLink amplPiecewise		Special

  delcommand HiLink
endif

let b:current_syntax = "ampl"

" vim: ts=8


