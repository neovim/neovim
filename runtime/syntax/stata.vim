" stata.vim -- Vim syntax file for Stata do, ado, and class files.
" Language:	Stata and/or Mata
" Maintainer:	Jeff Pitblado <jpitblado@stata.com>
" Last Change:	26apr2006
" Version:	1.1.4

" Log:
" 14apr2006	renamed syntax groups st* to stata*
"		'syntax clear' only under version control
"		check for 'b:current_syntax', removed 'did_stata_syntax_inits'
" 17apr2006	fixed start expression for stataFunc
" 26apr2006	fixed brace confusion in stataErrInParen and stataErrInBracket
"		fixed paren/bracket confusion in stataFuncGroup

if version < 600
	syntax clear
elseif exists("b:current_syntax")
	finish
endif

syntax case match

" comments - single line
" note that the triple slash continuing line comment comes free
syn region stataStarComment  start=/^\s*\*/ end=/$/    contains=stataComment oneline
syn region stataSlashComment start="\s//"   end=/$/    contains=stataComment oneline
syn region stataSlashComment start="^//"    end=/$/    contains=stataComment oneline
" comments - multiple line
syn region stataComment      start="/\*"    end="\*/"  contains=stataComment

" global macros - simple case
syn match  stataGlobal /\$\a\w*/
" global macros - general case
syn region stataGlobal start=/\${/ end=/}/ oneline contains=@stataMacroGroup
" local macros - general case
syn region stataLocal  start=/`/ end=/'/   oneline contains=@stataMacroGroup

" numeric formats
syn match  stataFormat /%-\=\d\+\.\d\+[efg]c\=/
" numeric hex format
syn match  stataFormat /%-\=21x/
" string format
syn match  stataFormat /%\(\|-\|\~\)\d\+s/

" Statements
syn keyword stataConditional else if
syn keyword stataRepeat      foreach
syn keyword stataRepeat      forv[alues]
syn keyword stataRepeat      while

" Common programming commands
syn keyword stataCommand about
syn keyword stataCommand adopath
syn keyword stataCommand adoupdate
syn keyword stataCommand assert
syn keyword stataCommand break
syn keyword stataCommand by
syn keyword stataCommand cap[ture]
syn keyword stataCommand cd
syn keyword stataCommand chdir
syn keyword stataCommand checksum
syn keyword stataCommand class
syn keyword stataCommand classutil
syn keyword stataCommand compress
syn keyword stataCommand conf[irm]
syn keyword stataCommand conren
syn keyword stataCommand continue
syn keyword stataCommand cou[nt]
syn keyword stataCommand cscript
syn keyword stataCommand cscript_log
syn keyword stataCommand #delimit
syn keyword stataCommand d[escribe]
syn keyword stataCommand dir
syn keyword stataCommand discard
syn keyword stataCommand di[splay]
syn keyword stataCommand do
syn keyword stataCommand doedit
syn keyword stataCommand drop
syn keyword stataCommand edit
syn keyword stataCommand end
syn keyword stataCommand erase
syn keyword stataCommand eret[urn]
syn keyword stataCommand err[or]
syn keyword stataCommand e[xit]
syn keyword stataCommand expand
syn keyword stataCommand expandcl
syn keyword stataCommand file
syn keyword stataCommand findfile
syn keyword stataCommand format
syn keyword stataCommand g[enerate]
syn keyword stataCommand gettoken
syn keyword stataCommand gl[obal]
syn keyword stataCommand help
syn keyword stataCommand hexdump
syn keyword stataCommand include
syn keyword stataCommand infile
syn keyword stataCommand infix
syn keyword stataCommand input
syn keyword stataCommand insheet
syn keyword stataCommand joinby
syn keyword stataCommand la[bel]
syn keyword stataCommand levelsof
syn keyword stataCommand list
syn keyword stataCommand loc[al]
syn keyword stataCommand log
syn keyword stataCommand ma[cro]
syn keyword stataCommand mark
syn keyword stataCommand markout
syn keyword stataCommand marksample
syn keyword stataCommand mata
syn keyword stataCommand matrix
syn keyword stataCommand memory
syn keyword stataCommand merge
syn keyword stataCommand mkdir
syn keyword stataCommand more
syn keyword stataCommand net
syn keyword stataCommand nobreak
syn keyword stataCommand n[oisily]
syn keyword stataCommand note[s]
syn keyword stataCommand numlist
syn keyword stataCommand outfile
syn keyword stataCommand outsheet
syn keyword stataCommand _parse
syn keyword stataCommand pause
syn keyword stataCommand plugin
syn keyword stataCommand post
syn keyword stataCommand postclose
syn keyword stataCommand postfile
syn keyword stataCommand preserve
syn keyword stataCommand print
syn keyword stataCommand printer
syn keyword stataCommand profiler
syn keyword stataCommand pr[ogram]
syn keyword stataCommand q[uery]
syn keyword stataCommand qui[etly]
syn keyword stataCommand rcof
syn keyword stataCommand reg[ress]
syn keyword stataCommand rename
syn keyword stataCommand repeat
syn keyword stataCommand replace
syn keyword stataCommand reshape
syn keyword stataCommand ret[urn]
syn keyword stataCommand _rmcoll
syn keyword stataCommand _rmcoll
syn keyword stataCommand _rmcollright
syn keyword stataCommand rmdir
syn keyword stataCommand _robust
syn keyword stataCommand save
syn keyword stataCommand sca[lar]
syn keyword stataCommand search
syn keyword stataCommand serset
syn keyword stataCommand set
syn keyword stataCommand shell
syn keyword stataCommand sleep
syn keyword stataCommand sort
syn keyword stataCommand split
syn keyword stataCommand sret[urn]
syn keyword stataCommand ssc
syn keyword stataCommand su[mmarize]
syn keyword stataCommand syntax
syn keyword stataCommand sysdescribe
syn keyword stataCommand sysdir
syn keyword stataCommand sysuse
syn keyword stataCommand token[ize]
syn keyword stataCommand translate
syn keyword stataCommand type
syn keyword stataCommand unab
syn keyword stataCommand unabcmd
syn keyword stataCommand update
syn keyword stataCommand use
syn keyword stataCommand vers[ion]
syn keyword stataCommand view
syn keyword stataCommand viewsource
syn keyword stataCommand webdescribe
syn keyword stataCommand webseek
syn keyword stataCommand webuse
syn keyword stataCommand which
syn keyword stataCommand who
syn keyword stataCommand window

" Literals
syn match  stataQuote   /"/
syn region stataEString matchgroup=Nothing start=/`"/ end=/"'/ oneline contains=@stataMacroGroup,stataQuote,stataString,stataEString
syn region stataString  matchgroup=Nothing start=/"/ end=/"/   oneline contains=@stataMacroGroup

" define clusters
syn cluster stataFuncGroup contains=@stataMacroGroup,stataFunc,stataString,stataEstring,stataParen,stataBracket
syn cluster stataMacroGroup contains=stataGlobal,stataLocal
syn cluster stataParenGroup contains=stataParenError,stataBracketError,stataBraceError,stataSpecial,stataFormat

" Stata functions
" Math
syn region stataFunc matchgroup=Function start=/\<abs(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<acos(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<asin(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<atan(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<atan2(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<atanh(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<ceil(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<cloglog(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<comb(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<cos(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<digamma(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<exp(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<floor(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<int(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<invcloglog(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<invlogit(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<ln(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<lnfact(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<lnfactorial(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<lngamma(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<log(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<log10(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<logit(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<max(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<mod(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<reldif(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<round(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<sign(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<sin(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<sqrt(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<sum(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<tan(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<tanh(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<trigamma(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<trunc(/ end=/)/ contains=@stataFuncGroup
" Probability distriubtions and density functions
syn region stataFunc matchgroup=Function start=/\<betaden(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<Binomial(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<binorm(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<binormal(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<chi2(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<chi2tail(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<dgammapda(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<dgammapdada(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<dgammapdadx(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<dgammapdx(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<dgammapdxdx(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<F(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<Fden(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<Ftail(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<gammaden(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<gammap(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<ibeta(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<invbinomial(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<invchi2(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<invchi2tail(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<invF(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<invFtail(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<invgammap(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<invibeta(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<invnchi2(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<invFtail(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<invibeta(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<invnorm(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<invnormal(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<invttail(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<lnnormal(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<lnnormalden(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<nbetaden(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<nchi2(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<nFden(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<nFtail(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<nibeta(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<norm(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<normal(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<normalden(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<normden(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<npnchi2(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<tden(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<ttail(/ end=/)/ contains=@stataFuncGroup
" Random numbers
syn region stataFunc matchgroup=Function start=/\<uniform(/ end=/)/ contains=@stataFuncGroup
" String
syn region stataFunc matchgroup=Function start=/\<abbrev(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<hchar(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<indexnot(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<itrim(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<length(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<lower(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<ltrim(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<plural(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<proper(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<real(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<regexm(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<regexr(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<regexs(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<reverse(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<rtrim(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<string(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<strlen(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<strmatch(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<strpos(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<subinstr(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<subinword(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<substr(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<trim(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<upper(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<word(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<wordcount(/ end=/)/ contains=@stataFuncGroup
" Programming
syn region stataFunc matchgroup=Function start=/\<autocode(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<byteorder(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<c(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<_caller(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<chop(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<clip(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<cond(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<e(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<epsdouble(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<epsfloat(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<float(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<has_eprop(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<has_eprop(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<inlist(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<inrange(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<irecode(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<matrix(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<maxbyte(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<maxdouble(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<maxfloat(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<maxint(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<maxlong(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<mi(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<minbyte(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<mindouble(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<minfloat(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<minint(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<minlong(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<missing(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<r(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<recode(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<replay(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<return(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<s(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<scalar(/ end=/)/ contains=@stataFuncGroup
" Date
syn region stataFunc matchgroup=Function start=/\<d(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<date(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<day(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<dow(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<doy(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<halfyear(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<mdy(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<month(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<quarter(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<week(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<year(/ end=/)/ contains=@stataFuncGroup
" Time-series
syn region stataFunc matchgroup=Function start=/\<daily(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<halfyearly(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<monthly(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<quarterly(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<weekly(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<yearly(/ end=/)/ contains=@stataFuncGroup
"
syn region stataFunc matchgroup=Function start=/\<yh(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<ym(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<yq(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<yw(/ end=/)/ contains=@stataFuncGroup
"
syn region stataFunc matchgroup=Function start=/\<d(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<h(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<m(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<q(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<w(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<y(/ end=/)/ contains=@stataFuncGroup
"
syn region stataFunc matchgroup=Function start=/\<dofd(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<dofh(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<dofm(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<dofq(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<dofw(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<dofy(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<hofd(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<mofd(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<qofd(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<wofd(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<yofd(/ end=/)/ contains=@stataFuncGroup
"
syn region stataFunc matchgroup=Function start=/\<tin(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<twithin(/ end=/)/ contains=@stataFuncGroup
" Matrix
syn region stataFunc matchgroup=Function start=/\<colnumb(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<colsof(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<det(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<diag0cnt(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<el(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<issymmetric(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<matmissing(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<mreldif(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<rownumb(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<rowsof(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<trace(/ end=/)/ contains=@stataFuncGroup
"
syn region stataFunc matchgroup=Function start=/\<cholsky(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<corr(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<diag(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<get(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<hadamard(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<I(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<inv(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<invsym(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<J(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<matuniform(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<nullmat(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<sweep(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<vec(/ end=/)/ contains=@stataFuncGroup
syn region stataFunc matchgroup=Function start=/\<vecdiag(/ end=/)/ contains=@stataFuncGroup

" Errors to catch
" taken from $VIMRUNTIME/syntax/c.vim 
" catch errors caused by wrong parenthesis, braces and brackets
syn region	stataParen	transparent start=/(/ end=/)/  contains=ALLBUT,@stataParenGroup,stataErrInBracket,stataErrInBrace
syn region	stataBracket	transparent start=/\[/ end=/]/ contains=ALLBUT,@stataParenGroup,stataErrInParen,stataErrInBrace
syn region	stataBrace	transparent start=/{/ end=/}/  contains=ALLBUT,@stataParenGroup,stataErrInParen,stataErrInBracket
syn match	stataParenError	/[\])}]/
syn match	stataBracketError	/]/
syn match	stataBraceError	/}/
syn match	stataErrInParen	contained /[\]}]/
syn match	stataErrInBracket	contained /[)}]/
syn match	stataErrInBrace	contained /[)\]]/

" assign highlight groups
hi def link stataBraceError	stataError
hi def link stataBracketError	stataError
hi def link stataErrInBrace	stataError
hi def link stataErrInBracket	stataError
hi def link stataErrInParen	stataError
hi def link stataEString	stataString
hi def link stataFormat		stataSpecial
hi def link stataGlobal		stataMacro
hi def link stataLocal		stataMacro
hi def link stataParenError	stataError
hi def link stataSlashComment	stataComment
hi def link stataStarComment	stataComment

hi def link stataCommand	Define
hi def link stataComment	Comment
hi def link stataConditional	Conditional
hi def link stataError		Error
hi def link stataFunc		None
hi def link stataMacro		Define
hi def link stataRepeat		Repeat
hi def link stataSpecial	SpecialChar
hi def link stataString		String

let b:current_syntax = "stata"

" vim: ts=8
