" Vim indent file
" Language:             Racket
" Maintainer:           D. Ben Knoble <ben.knoble+github@gmail.com>
" Previous Maintainer:  Will Langstroth <will@langstroth.com>
" URL:                  https://github.com/benknoble/vim-racket
" Last Change:          2024 Jan 31

if exists("b:did_indent")
   finish
endif
let b:did_indent = 1

setlocal lisp autoindent nosmartindent
if has('vim9script')
  setlocal indentexpr=racket#Indent() lispoptions+=expr:1
endif

setlocal lispwords+=module,module*,module+,parameterize,parameterize*,let-values,let*-values,letrec-values,local
setlocal lispwords+=define/contract
setlocal lispwords+=λ
setlocal lispwords+=with-handlers
setlocal lispwords+=define-values,opt-lambda,case-lambda,syntax-rules,with-syntax,syntax-case,syntax-parse
setlocal lispwords+=define-for-syntax,define-syntax-parser,define-syntax-parse-rule,define-syntax-class,define-splicing-syntax-class
setlocal lispwords+=define-syntax-parameter,syntax-parameterize
setlocal lispwords+=define-signature,unit,unit/sig,compund-unit/sig,define-values/invoke-unit/sig
setlocal lispwords+=define-opt/c,define-syntax-rule
setlocal lispwords+=define-test-suite,test-case
setlocal lispwords+=struct
setlocal lispwords+=with-input-from-file,with-output-to-file
setlocal lispwords+=begin,begin0
setlocal lispwords+=place
setlocal lispwords+=cond

" Racket OOP
" TODO missing a lot of define-like forms here (e.g., define/augment, etc.)
setlocal lispwords+=class,class*,mixin,interface,class/derived
setlocal lispwords+=define/public,define/pubment,define/public-final
setlocal lispwords+=define/override,define/overment,define/override-final
setlocal lispwords+=define/augment,define/augride,define/augment-final
setlocal lispwords+=define/private

" kanren
setlocal lispwords+=fresh,run,run*,project,conde,condu

" loops
setlocal lispwords+=for,for/list,for/fold,for*,for*/list,for*/fold,for/or,for/and,for*/or,for*/and
setlocal lispwords+=for/hash,for/hasheq,for/hasheqv,for/sum,for/flvector,for*/flvector,for/vector,for*/vector,for*/sum,for*/hash,for*/hasheq,for*/hasheqv
setlocal lispwords+=for/async
setlocal lispwords+=for/set,for*/set
setlocal lispwords+=for/first,for*/first
setlocal lispwords+=for/last,for*/last
setlocal lispwords+=for/stream,for*/stream

setlocal lispwords+=match,match*,match/values,define/match,match-lambda,match-lambda*,match-lambda**
setlocal lispwords+=match-let,match-let*,match-let-values,match-let*-values
setlocal lispwords+=match-letrec,match-define,match-define-values

setlocal lispwords+=let/cc,let/ec

" qi
setlocal lispwords+=define-flow,define-switch,flow-lambda,switch-lambda,on,switch,π,λ01
setlocal lispwords+=define-qi-syntax,define-qi-syntax-parser,define-qi-syntax-rule

" gui-easy
setlocal lispwords+=if-view,case-view,cond-view,list-view,dyn-view
setlocal lispwords+=case/dep
setlocal lispwords+=define/obs

let b:undo_indent = "setlocal lisp< ai< si< lw<" .. (has('vim9script') ? ' indentexpr< lispoptions<' : '')
