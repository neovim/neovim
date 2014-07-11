" Vim filetype plugin
" Language:      Scheme
" Maintainer:    Sergey Khorev <sergey.khorev@gmail.com>
" URL:		 http://sites.google.com/site/khorser/opensource/vim
" Original author:    Dorai Sitaram <ds26@gte.com>
" Original URL:		 http://www.ccs.neu.edu/~dorai/vimplugins/vimplugins.html
" Last Change:   Oct 23, 2013

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

" Copy-paste from ftplugin/lisp.vim
setl comments=:;
setl define=^\\s*(def\\k*
setl formatoptions-=t
setl iskeyword+=+,-,*,/,%,<,=,>,:,$,?,!,@-@,94
setl lisp
setl commentstring=;%s

setl comments^=:;;;,:;;,sr:#\|,mb:\|,ex:\|#

" Scheme-specific settings
if exists("b:is_mzscheme") || exists("is_mzscheme")
    " improve indenting
    setl iskeyword+=#,%,^
    setl lispwords+=module,parameterize,let-values,let*-values,letrec-values
    setl lispwords+=define-values,opt-lambda,case-lambda,syntax-rules,with-syntax,syntax-case
    setl lispwords+=define-signature,unit,unit/sig,compund-unit/sig,define-values/invoke-unit/sig
endif

if exists("b:is_chicken") || exists("is_chicken")
    " improve indenting
    setl iskeyword+=#,%,^
    setl lispwords+=let-optionals,let-optionals*,declare
    setl lispwords+=let-values,let*-values,letrec-values
    setl lispwords+=define-values,opt-lambda,case-lambda,syntax-rules,with-syntax,syntax-case
    setl lispwords+=cond-expand,and-let*,foreign-lambda,foreign-lambda*
endif

let b:undo_ftplugin = "setlocal comments< define< formatoptions< iskeyword< lispwords< lisp< commentstring<"
