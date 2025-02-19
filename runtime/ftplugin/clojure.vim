" Vim filetype plugin file
" Language:           Clojure
" Maintainer:         Alex Vear <alex@vear.uk>
" Former Maintainers: Sung Pae <self@sungpae.com>
"                     Meikel Brandmeyer <mb@kotka.de>
" URL:                https://github.com/clojure-vim/clojure.vim
" License:            Vim (see :h license)
" Last Change:        2022-03-24
"                     2024 Jan 14 by Vim Project (browsefilter)

if exists("b:did_ftplugin")
	finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = 'setlocal iskeyword< define< formatoptions< comments< commentstring< lispwords<'

setlocal iskeyword+=?,-,*,!,+,/,=,<,>,.,:,$,%,&,\|

" There will be false positives, but this is better than missing the whole set
" of user-defined def* definitions.
setlocal define=\\v[(/]def(ault)@!\\S*

" Remove 't' from 'formatoptions' to avoid auto-wrapping code.
setlocal formatoptions-=t

" Lisp comments are routinely nested (e.g. ;;; SECTION HEADING)
setlocal comments=n:;
setlocal commentstring=;\ %s

" Specially indented symbols from clojure.core and clojure.test.
"
" Clojure symbols are indented in the defn style when they:
"
"   * Define vars and anonymous functions
"   * Create new lexical scopes or scopes with altered environments
"   * Create conditional branches from a predicate function or value
"
" The arglists for these functions are generally in the form of [x & body];
" Functions that accept a flat list of forms do not treat the first argument
" specially and hence are not indented specially.
"
" -*- LISPWORDS -*-
" Generated from https://github.com/clojure-vim/clojure.vim/blob/fd280e33e84c88e97860930557dba3ff80b1a82d/clj/src/vim_clojure_static/generate.clj
setlocal lispwords=as->,binding,bound-fn,case,catch,cond->,cond->>,condp,def,definline,definterface,defmacro,defmethod,defmulti,defn,defn-,defonce,defprotocol,defrecord,defstruct,deftest,deftest-,deftype,doseq,dotimes,doto,extend,extend-protocol,extend-type,fn,for,if,if-let,if-not,if-some,let,letfn,locking,loop,ns,proxy,reify,set-test,testing,when,when-first,when-let,when-not,when-some,while,with-bindings,with-in-str,with-local-vars,with-open,with-precision,with-redefs,with-redefs-fn,with-test

" Provide insert mode completions for special forms and clojure.core. As
" 'omnifunc' is set by popular Clojure REPL client plugins, we also set
" 'completefunc' so that the user has some form of completion available when
" 'omnifunc' is set and no REPL connection exists.
for s:setting in ['omnifunc', 'completefunc']
	if exists('&' . s:setting) && empty(eval('&' . s:setting))
		execute 'setlocal ' . s:setting . '=clojurecomplete#Complete'
		let b:undo_ftplugin .= ' | setlocal ' . s:setting . '<'
	endif
endfor

" Skip brackets in ignored syntax regions when using the % command
if exists('loaded_matchit')
	let b:match_words = &matchpairs
	let b:match_skip = 's:comment\|string\|regex\|character'
	let b:undo_ftplugin .= ' | unlet! b:match_words b:match_skip'
endif

" Filter files in the browse dialog
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
	let b:browsefilter = "Clojure Files\t*.clj;*.cljc;*.cljs;*.cljx\n" .
				\ "EDN Files\t*.edn\n" .
				\ "Java Files\t*.java\n"
	if has("win32")
		let b:browsefilter .= "All Files (*.*)\t*\n"
	else
		let b:browsefilter .= "All Files (*)\t*\n"
	endif
	let b:undo_ftplugin .= ' | unlet! b:browsefilter'
endif

let &cpo = s:cpo_save

unlet! s:cpo_save s:setting s:dir

" vim:sts=8:sw=8:ts=8:noet
