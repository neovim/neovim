" Vim syntax file
" Language: Scheme (CHICKEN)
" Last Change: 2018-02-05
" Author: Evan Hanson <evhan@foldling.org>
" Maintainer: Evan Hanson <evhan@foldling.org>
" URL: https://foldling.org/vim/syntax/chicken.vim
" Notes: This is supplemental syntax, to be loaded after the core Scheme
" syntax file (syntax/scheme.vim). Enable it by setting b:is_chicken=1
" and filetype=scheme.

" Only to be used on top of the Scheme syntax.
if !exists('b:did_scheme_syntax')
  finish
endif

" Lighten parentheses.
hi! def link schemeParentheses Comment

" foo#bar
syn match schemeExtraSyntax /[^ #'`\t\n()\[\]"|;]\+#[^ '`\t\n()\[\]"|;]\+/

" ##foo#bar
syn match schemeExtraSyntax /##[^ '`\t\n()\[\]"|;]\+/

" Heredocs.
syn region schemeString start=/#<[<#]\s*\z(.*\)/ end=/^\z1$/

" Keywords.
syn match schemeKeyword /#[!:][a-zA-Z0-9!$%&*+-./:<=>?@^_~#]\+/
syn match schemeKeyword /[a-zA-Z0-9!$%&*+-./:<=>?@^_~#]\+:\>/

" C/C++ syntax.
let s:c = globpath(&rtp, 'syntax/cpp.vim', 0, 1)
if len(s:c)
  exe 'syn include @c ' s:c[0]
  syn region c matchgroup=schemeComment start=/#>/ end=/<#/ contains=@c
endif

syn keyword schemeSyntax define-record

syn keyword schemeLibrarySyntax declare
syn keyword schemeLibrarySyntax module
syn keyword schemeLibrarySyntax reexport
syn keyword schemeLibrarySyntax require-library

syn keyword schemeTypeSyntax -->
syn keyword schemeTypeSyntax ->
syn keyword schemeTypeSyntax :
syn keyword schemeTypeSyntax assume
syn keyword schemeTypeSyntax compiler-typecase
syn keyword schemeTypeSyntax define-specialization
syn keyword schemeTypeSyntax define-type
syn keyword schemeTypeSyntax the

syn keyword schemeExtraSyntax and-let*
syn keyword schemeExtraSyntax match
syn keyword schemeExtraSyntax match-lambda
syn keyword schemeExtraSyntax match-lambda*

syn keyword schemeSpecialSyntax define-compiler-syntax
syn keyword schemeSpecialSyntax define-constant
syn keyword schemeSpecialSyntax define-external
syn keyword schemeSpecialSyntax define-inline
syn keyword schemeSpecialSyntax foreign-code
syn keyword schemeSpecialSyntax foreign-declare
syn keyword schemeSpecialSyntax foreign-lambda
syn keyword schemeSpecialSyntax foreign-lambda*
syn keyword schemeSpecialSyntax foreign-primitive
syn keyword schemeSpecialSyntax foreign-safe-lambda
syn keyword schemeSpecialSyntax foreign-safe-lambda*
syn keyword schemeSpecialSyntax foreign-value

syn keyword schemeSyntaxSyntax begin-for-syntax
syn keyword schemeSyntaxSyntax define-for-syntax
syn keyword schemeSyntaxSyntax er-macro-transformer
syn keyword schemeSyntaxSyntax ir-macro-transformer
syn keyword schemeSyntaxSyntax require-library-for-syntax
