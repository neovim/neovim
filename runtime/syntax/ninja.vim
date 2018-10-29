" ninja build file syntax.
" Language: ninja build file as described at
"           http://ninja-build.org/manual.html
" Version: 1.5
" Last Change: 2018/04/05
" Maintainer: Nicolas Weber <nicolasweber@gmx.de>
" Version 1.5 of this script is in the upstream vim repository and will be
" included in the next vim release. If you change this, please send your change
" upstream.

" ninja lexer and parser are at
" https://github.com/ninja-build/ninja/blob/master/src/lexer.in.cc
" https://github.com/ninja-build/ninja/blob/master/src/manifest_parser.cc

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case match

" Comments are only matched when the # is at the beginning of the line (with
" optional whitespace), as long as the prior line didn't end with a $
" continuation.
syn match ninjaComment /\(\$\n\)\@<!\_^\s*#.*$/  contains=@Spell

" Toplevel statements are the ones listed here and
" toplevel variable assignments (ident '=' value).
" lexer.in.cc, ReadToken() and manifest_parser.cc, Parse()
syn match ninjaKeyword "^build\>"
syn match ninjaKeyword "^rule\>"
syn match ninjaKeyword "^pool\>"
syn match ninjaKeyword "^default\>"
syn match ninjaKeyword "^include\>"
syn match ninjaKeyword "^subninja\>"

" Both 'build' and 'rule' begin a variable scope that ends
" on the first line without indent. 'rule' allows only a
" limited set of magic variables, 'build' allows general
" let assignments.
" manifest_parser.cc, ParseRule()
syn region ninjaRule start="^rule" end="^\ze\S" contains=TOP transparent
syn keyword ninjaRuleCommand contained containedin=ninjaRule command
                                     \ deps depfile description generator
                                     \ pool restat rspfile rspfile_content

syn region ninjaPool start="^pool" end="^\ze\S" contains=TOP transparent
syn keyword ninjaPoolCommand contained containedin=ninjaPool  depth

" Strings are parsed as follows:
" lexer.in.cc, ReadEvalString()
" simple_varname = [a-zA-Z0-9_-]+;
" varname = [a-zA-Z0-9_.-]+;
" $$ -> $
" $\n -> line continuation
" '$ ' -> escaped space
" $simple_varname -> variable
" ${varname} -> variable

syn match   ninjaDollar "\$\$"
syn match   ninjaWrapLineOperator "\$$"
syn match   ninjaSimpleVar "\$[a-zA-Z0-9_-]\+"
syn match   ninjaVar       "\${[a-zA-Z0-9_.-]\+}"

" operators are:
" variable assignment =
" rule definition :
" implicit dependency |
" order-only dependency ||
syn match ninjaOperator "\(=\|:\||\|||\)\ze\s"

hi def link ninjaComment Comment
hi def link ninjaKeyword Keyword
hi def link ninjaRuleCommand Statement
hi def link ninjaPoolCommand Statement
hi def link ninjaDollar ninjaOperator
hi def link ninjaWrapLineOperator ninjaOperator
hi def link ninjaOperator Operator
hi def link ninjaSimpleVar ninjaVar
hi def link ninjaVar Identifier

let b:current_syntax = "ninja"

let &cpo = s:cpo_save
unlet s:cpo_save
