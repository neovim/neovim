" Vim syntax file
" Language:	Latte
" Maintainer:	Nick Moffitt, <nick@zork.net>
" Last Change:	14 June, 2000
"
" Notes:
" I based this on the TeX and Scheme syntax files (but mostly scheme).
" See http://www.latte.org for info on the language.

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn match latteError "[{}\\]"
syn match latteOther "\\{"
syn match latteOther "\\}"
syn match latteOther "\\\\"

setlocal iskeyword=33,43,45,48-57,63,65-90,95,97-122,_

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
" Only when an item doesn't have highlighting yet

hi def link latteSyntax		Statement
hi def link latteVar			Function

hi def link latteString		String
hi def link latteQuote			String

hi def link latteDelimiter		Delimiter
hi def link latteOperator		Operator

hi def link latteComment		Comment
hi def link latteError			Error


let b:current_syntax = "latte"
