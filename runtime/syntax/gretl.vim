" Vim syntax file
" Language:	gretl (http://gretl.sf.net)
" Maintainer:	Vaidotas Zemlys <zemlys@gmail.com>
" Last Change:  2006 Apr 30
" Filenames:	*.inp *.gretl
" URL:	http://uosis.mif.vu.lt/~zemlys/vim-syntax/gretl.vim
" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded

if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

if version >= 600
  setlocal iskeyword=@,48-57,_,.
else
  set iskeyword=@,48-57,_,.
endif

syn case match

" Constant
" string enclosed in double quotes
syn region gString start=/"/ skip=/\\\\\|\\"/ end=/"/
" number with no fractional part or exponent
syn match gNumber /\d\+/
" floating point number with integer and fractional parts and optional exponent
syn match gFloat /\d\+\.\d*\([Ee][-+]\=\d\+\)\=/
" floating point number with no integer part and optional exponent
syn match gFloat /\.\d\+\([Ee][-+]\=\d\+\)\=/
" floating point number with no fractional part and optional exponent
syn match gFloat /\d\+[Ee][-+]\=\d\+/

" Gretl commands
syn keyword gCommands add addobs addto adf append ar arch arma break boxplot chow coeffsum coint coint2 corc corr corrgm criteria critical cusum data delete diff else end endif endloop eqnprint equation estimate fcast fcasterr fit freq function funcerr garch genr gnuplot graph hausman hccm help hilu hsk hurst if import include info kpss label labels lad lags ldiff leverage lmtest logistic logit logs loop mahal meantest mle modeltab mpols multiply nls nulldata ols omit omitfrom open outfile panel pca pergm plot poisson pooled print printf probit pvalue pwe quit remember rename reset restrict rhodiff rmplot run runs scatters sdiff set setobs setmiss shell sim smpl spearman square store summary system tabprint testuhat tobit transpos tsls var varlist vartest vecm vif wls 

"Gretl genr functions
syn keyword gGenrFunc log exp sin cos tan atan diff ldiff sdiff mean sd min max sort int ln coeff abs rho sqrt sum nobs firstobs lastobs normal uniform stderr cum missing ok misszero corr vcv var sst cov median zeromiss pvalue critical obsnum mpow dnorm cnorm gamma lngamma resample hpfilt bkfilt fracdiff varnum isvector islist nelem 

" Identifier
" identifier with leading letter and optional following keyword characters
syn match gIdentifier /\a\k*/

"  Variable with leading $
syn match gVariable /\$\k*/
" Arrow
syn match gArrow /<-/

" Special
syn match gDelimiter /[,;:]/

" Error
syn region gRegion matchgroup=Delimiter start=/(/ matchgroup=Delimiter end=/)/ transparent contains=ALLBUT,rError,rBraceError,rCurlyError,gBCstart,gBCend
syn region gRegion matchgroup=Delimiter start=/{/ matchgroup=Delimiter end=/}/ transparent contains=ALLBUT,rError,rBraceError,rParenError
syn region gRegion matchgroup=Delimiter start=/\[/ matchgroup=Delimiter end=/]/ transparent contains=ALLBUT,rError,rCurlyError,rParenError
syn match gError      /[)\]}]/
syn match gBraceError /[)}]/ contained
syn match gCurlyError /[)\]]/ contained
syn match gParenError /[\]}]/ contained

" Comment
syn match gComment /#.*/
syn match gBCstart /(\*/
syn match gBCend /\*)/

syn region gBlockComment matchgroup=gCommentStart start="(\*" end="\*)"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_r_syn_inits")
  if version < 508
    let did_r_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif
  HiLink gComment      Comment
  HiLink gCommentStart Comment
  HiLink gBlockComment Comment
  HiLink gString       String
  HiLink gNumber       Number
  HiLink gBoolean      Boolean
  HiLink gFloat        Float
  HiLink gCommands     Repeat	
  HiLink gGenrFunc     Type
  HiLink gDelimiter    Delimiter
  HiLink gError        Error
  HiLink gBraceError   Error
  HiLink gCurlyError   Error
  HiLink gParenError   Error
  HiLink gIdentifier   Normal
  HiLink gVariable     Identifier
  HiLink gArrow	       Repeat
  delcommand HiLink
endif

let b:current_syntax="gretl"

" vim: ts=8 sw=2
