" Vim syntax file
" Language:	Latte
" Maintainer:	Nick Moffitt, <nick@zork.net>
" Last Change:	14 June, 2000
"
" Notes:
" I based this on the TeX and Scheme syntax files (but mostly scheme).
" See http://www.latte.org for info on the language.

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn match latteError "[{}\\]"
syn match latteOther "\\{"
syn match latteOther "\\}"
syn match latteOther "\\\\"

if version < 600
  set iskeyword=33,43,45,48-57,63,65-90,95,97-122,_
else
  setlocal iskeyword=33,43,45,48-57,63,65-90,95,97-122,_
endif

syn region latteVar matchgroup=SpecialChar start=!\\[A-Za-z_]!rs=s+1 end=![^A-Za-z0-9?!+_-]!me=e-1 contains=ALLBUT,latteNumber,latteOther
syn region latteVar matchgroup=SpecialChar start=!\\[=\&][A-Za-z_]!rs=s+2 end=![^A-Za-z0-9?!+_-]!me=e-1 contains=ALLBUT,latteNumber,latteOther
syn region latteString	start=+\\"+ skip=+\\\\"+ end=+\\"+

syn region latteGroup	matchgroup=Delimiter start="{" skip="\\[{}]" matchgroup=Delimiter end="}" contains=ALLBUT,latteSyntax

syn region latteUnquote matchgroup=Delimiter start="\\,{" skip="\\[{}]" matchgroup=Delimiter end="}" contains=ALLBUT,latteSyntax
syn region latteSplice matchgroup=Delimiter start="\\,@{" skip="\\[{}]" matchgroup=Delimiter end="}" contains=ALLBUT,latteSyntax
syn region latteQuote matchgroup=Delimiter start="\\'{" skip="\\[{}]" matchgroup=Delimiter end="}"
syn region latteQuote matchgroup=Delimiter start="\\`{" skip="\\[{}]" matchgroup=Delimiter end="}" contains=latteUnquote,latteSplice

syn match  latteOperator   '\\/'
syn match  latteOperator   '='

syn match  latteComment	"\\;.*$"

" This was gathered by slurping in the index.

syn keyword latteSyntax __FILE__ __latte-version__ contained
syn keyword latteSyntax _bal-tag _pre _tag add and append apply back contained
syn keyword latteSyntax caar cadr car cdar cddr cdr ceil compose contained
syn keyword latteSyntax concat cons def defmacro divide downcase contained
syn keyword latteSyntax empty? equal? error explode file-contents contained
syn keyword latteSyntax floor foreach front funcall ge?  getenv contained
syn keyword latteSyntax greater-equal? greater? group group? gt? html contained
syn keyword latteSyntax if include lambda le? length less-equal? contained
syn keyword latteSyntax less? let lmap load-file load-library lt?  macro contained
syn keyword latteSyntax member?  modulo multiply not nth operator? contained
syn keyword latteSyntax or ordinary quote process-output push-back contained
syn keyword latteSyntax push-front quasiquote quote random rdc reverse contained
syn keyword latteSyntax set!  snoc splicing unquote strict-html4 contained
syn keyword latteSyntax string-append string-ge?  string-greater-equal? contained
syn keyword latteSyntax string-greater?  string-gt?  string-le? contained
syn keyword latteSyntax string-less-equal?  string-less?  string-lt? contained
syn keyword latteSyntax string?  subseq substr subtract  contained
syn keyword latteSyntax upcase useless warn while zero?  contained


" If it's good enough for scheme...

syn sync match matchPlace grouphere NONE "^[^ \t]"
" ... i.e. synchronize on a line that starts at the left margin

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_latte_syntax_inits")
  if version < 508
    let did_latte_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink latteSyntax		Statement
  HiLink latteVar			Function

  HiLink latteString		String
  HiLink latteQuote			String

  HiLink latteDelimiter		Delimiter
  HiLink latteOperator		Operator

  HiLink latteComment		Comment
  HiLink latteError			Error

  delcommand HiLink
endif

let b:current_syntax = "latte"
