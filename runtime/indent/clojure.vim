" Vim indent file
" Language:           Clojure
" Maintainer:         Alex Vear <alex@vear.uk>
" Former Maintainers: Sung Pae <self@sungpae.com>
"                     Meikel Brandmeyer <mb@kotka.de>
" URL:                https://github.com/clojure-vim/clojure.vim
" License:            Vim (see :h license)
" Last Change:        2022-03-24

if exists("b:did_indent")
	finish
endif
let b:did_indent = 1

let s:save_cpo = &cpo
set cpo&vim

let b:undo_indent = 'setlocal autoindent< smartindent< expandtab< softtabstop< shiftwidth< indentexpr< indentkeys<'

setlocal noautoindent nosmartindent
setlocal softtabstop=2 shiftwidth=2 expandtab
setlocal indentkeys=!,o,O

if exists("*searchpairpos")

	if !exists('g:clojure_maxlines')
		let g:clojure_maxlines = 300
	endif

	if !exists('g:clojure_fuzzy_indent')
		let g:clojure_fuzzy_indent = 1
	endif

	if !exists('g:clojure_fuzzy_indent_patterns')
		let g:clojure_fuzzy_indent_patterns = ['^with', '^def', '^let']
	endif

	if !exists('g:clojure_fuzzy_indent_blacklist')
		let g:clojure_fuzzy_indent_blacklist = ['-fn$', '\v^with-%(meta|out-str|loading-context)$']
	endif

	if !exists('g:clojure_special_indent_words')
		let g:clojure_special_indent_words = 'deftype,defrecord,reify,proxy,extend-type,extend-protocol,letfn'
	endif

	if !exists('g:clojure_align_multiline_strings')
		let g:clojure_align_multiline_strings = 0
	endif

	if !exists('g:clojure_align_subforms')
		let g:clojure_align_subforms = 0
	endif

	function! s:syn_id_name()
		return synIDattr(synID(line("."), col("."), 0), "name")
	endfunction

	function! s:ignored_region()
		return s:syn_id_name() =~? '\vstring|regex|comment|character'
	endfunction

	function! s:current_char()
		return getline('.')[col('.')-1]
	endfunction

	function! s:current_word()
		return getline('.')[col('.')-1 : searchpos('\v>', 'n', line('.'))[1]-2]
	endfunction

	function! s:is_paren()
		return s:current_char() =~# '\v[\(\)\[\]\{\}]' && !s:ignored_region()
	endfunction

	" Returns 1 if string matches a pattern in 'patterns', which should be
	" a list of patterns.
	function! s:match_one(patterns, string)
		for pat in a:patterns
			if a:string =~# pat | return 1 | endif
		endfor
	endfunction

	function! s:match_pairs(open, close, stopat)
		" Stop only on vector and map [ resp. {. Ignore the ones in strings and
		" comments.
		if a:stopat == 0 && g:clojure_maxlines > 0
			let stopat = max([line(".") - g:clojure_maxlines, 0])
		else
			let stopat = a:stopat
		endif

		let pos = searchpairpos(a:open, '', a:close, 'bWn', "!s:is_paren()", stopat)
		return [pos[0], col(pos)]
	endfunction

	function! s:clojure_check_for_string_worker()
		" Check whether there is the last character of the previous line is
		" highlighted as a string. If so, we check whether it's a ". In this
		" case we have to check also the previous character. The " might be the
		" closing one. In case the we are still in the string, we search for the
		" opening ". If this is not found we take the indent of the line.
		let nb = prevnonblank(v:lnum - 1)

		if nb == 0
			return -1
		endif

		call cursor(nb, 0)
		call cursor(0, col("$") - 1)
		if s:syn_id_name() !~? "string"
			return -1
		endif

		" This will not work for a " in the first column...
		if s:current_char() == '"'
			call cursor(0, col("$") - 2)
			if s:syn_id_name() !~? "string"
				return -1
			endif
			if s:current_char() != '\'
				return -1
			endif
			call cursor(0, col("$") - 1)
		endif

		let p = searchpos('\(^\|[^\\]\)\zs"', 'bW')

		if p != [0, 0]
			return p[1] - 1
		endif

		return indent(".")
	endfunction

	function! s:check_for_string()
		let pos = getpos('.')
		try
			let val = s:clojure_check_for_string_worker()
		finally
			call setpos('.', pos)
		endtry
		return val
	endfunction

	function! s:strip_namespace_and_macro_chars(word)
		return substitute(a:word, "\\v%(.*/|[#'`~@^,]*)(.*)", '\1', '')
	endfunction

	function! s:clojure_is_method_special_case_worker(position)
		" Find the next enclosing form.
		call search('\S', 'Wb')

		" Special case: we are at a '(('.
		if s:current_char() == '('
			return 0
		endif
		call cursor(a:position)

		let next_paren = s:match_pairs('(', ')', 0)

		" Special case: we are now at toplevel.
		if next_paren == [0, 0]
			return 0
		endif
		call cursor(next_paren)

		call search('\S', 'W')
		let w = s:strip_namespace_and_macro_chars(s:current_word())

		if g:clojure_special_indent_words =~# '\V\<' . w . '\>'

			" `letfn` is a special-special-case.
			if w ==# 'letfn'
				" Earlier code left the cursor at:
				"     (letfn [...] ...)
				"      ^

				" Search and get coordinates of first `[`
				"     (letfn [...] ...)
				"            ^
				call search('\[', 'W')
				let pos = getcurpos()
				let letfn_bracket = [pos[1], pos[2]]

				" Move cursor to start of the form this function was
				" initially called on.  Grab the coordinates of the
				" closest outer `[`.
				call cursor(a:position)
				let outer_bracket = s:match_pairs('\[', '\]', 0)

				" If the located square brackets are not the same,
				" don't use special-case formatting.
				if outer_bracket != letfn_bracket
					return 0
				endif
			endif

			return 1
		endif

		return 0
	endfunction

	function! s:is_method_special_case(position)
		let pos = getpos('.')
		try
			let val = s:clojure_is_method_special_case_worker(a:position)
		finally
			call setpos('.', pos)
		endtry
		return val
	endfunction

	" Check if form is a reader conditional, that is, it is prefixed by #?
	" or #?@
	function! s:is_reader_conditional_special_case(position)
		return getline(a:position[0])[a:position[1] - 3 : a:position[1] - 2] == "#?"
			\|| getline(a:position[0])[a:position[1] - 4 : a:position[1] - 2] == "#?@"
	endfunction

	" Returns 1 for opening brackets, -1 for _anything else_.
	function! s:bracket_type(char)
		return stridx('([{', a:char) > -1 ? 1 : -1
	endfunction

	" Returns: [opening-bracket-lnum, indent]
	function! s:clojure_indent_pos()
		" Get rid of special case.
		if line(".") == 1
			return [0, 0]
		endif

		" We have to apply some heuristics here to figure out, whether to use
		" normal lisp indenting or not.
		let i = s:check_for_string()
		if i > -1
			return [0, i + !!g:clojure_align_multiline_strings]
		endif

		call cursor(0, 1)

		" Find the next enclosing [ or {. We can limit the second search
		" to the line, where the [ was found. If no [ was there this is
		" zero and we search for an enclosing {.
		let paren = s:match_pairs('(', ')', 0)
		let bracket = s:match_pairs('\[', '\]', paren[0])
		let curly = s:match_pairs('{', '}', bracket[0])

		" In case the curly brace is on a line later then the [ or - in
		" case they are on the same line - in a higher column, we take the
		" curly indent.
		if curly[0] > bracket[0] || curly[1] > bracket[1]
			if curly[0] > paren[0] || curly[1] > paren[1]
				return curly
			endif
		endif

		" If the curly was not chosen, we take the bracket indent - if
		" there was one.
		if bracket[0] > paren[0] || bracket[1] > paren[1]
			return bracket
		endif

		" There are neither { nor [ nor (, ie. we are at the toplevel.
		if paren == [0, 0]
			return paren
		endif

		" Now we have to reimplement lispindent. This is surprisingly easy, as
		" soon as one has access to syntax items.
		"
		" - Check whether we are in a special position after a word in
		"   g:clojure_special_indent_words. These are special cases.
		" - Get the next keyword after the (.
		" - If its first character is also a (, we have another sexp and align
		"   one column to the right of the unmatched (.
		" - In case it is in lispwords, we indent the next line to the column of
		"   the ( + sw.
		" - If not, we check whether it is last word in the line. In that case
		"   we again use ( + sw for indent.
		" - In any other case we use the column of the end of the word + 2.
		call cursor(paren)

		if s:is_method_special_case(paren)
			return [paren[0], paren[1] + &shiftwidth - 1]
		endif

		if s:is_reader_conditional_special_case(paren)
			return paren
		endif

		" In case we are at the last character, we use the paren position.
		if col("$") - 1 == paren[1]
			return paren
		endif

		" In case after the paren is a whitespace, we search for the next word.
		call cursor(0, col('.') + 1)
		if s:current_char() == ' '
			call search('\v\S', 'W')
		endif

		" If we moved to another line, there is no word after the (. We
		" use the ( position for indent.
		if line(".") > paren[0]
			return paren
		endif

		" We still have to check, whether the keyword starts with a (, [ or {.
		" In that case we use the ( position for indent.
		let w = s:current_word()
		if s:bracket_type(w[0]) == 1
			return paren
		endif

		" If the keyword begins with #, check if it is an anonymous
		" function or set, in which case we indent by the shiftwidth
		" (minus one if g:clojure_align_subforms = 1), or if it is
		" ignored, in which case we use the ( position for indent.
		if w[0] == "#"
			" TODO: Handle #=() and other rare reader invocations?
			if w[1] == '(' || w[1] == '{'
				return [paren[0], paren[1] + (g:clojure_align_subforms ? 0 : &shiftwidth - 1)]
			elseif w[1] == '_'
				return paren
			endif
		endif

		" Test words without namespace qualifiers and leading reader macro
		" metacharacters.
		"
		" e.g. clojure.core/defn and #'defn should both indent like defn.
		let ww = s:strip_namespace_and_macro_chars(w)

		if &lispwords =~# '\V\<' . ww . '\>'
			return [paren[0], paren[1] + &shiftwidth - 1]
		endif

		if g:clojure_fuzzy_indent
			\ && !s:match_one(g:clojure_fuzzy_indent_blacklist, ww)
			\ && s:match_one(g:clojure_fuzzy_indent_patterns, ww)
			return [paren[0], paren[1] + &shiftwidth - 1]
		endif

		call search('\v\_s', 'cW')
		call search('\v\S', 'W')
		if paren[0] < line(".")
			return [paren[0], paren[1] + (g:clojure_align_subforms ? 0 : &shiftwidth - 1)]
		endif

		call search('\v\S', 'bW')
		return [line('.'), col('.') + 1]
	endfunction

	function! GetClojureIndent()
		let lnum = line('.')
		let orig_lnum = lnum
		let orig_col = col('.')
		let [opening_lnum, indent] = s:clojure_indent_pos()

		" Account for multibyte characters
		if opening_lnum > 0
			let indent -= indent - virtcol([opening_lnum, indent])
		endif

		" Return if there are no previous lines to inherit from
		if opening_lnum < 1 || opening_lnum >= lnum - 1
			call cursor(orig_lnum, orig_col)
			return indent
		endif

		let bracket_count = 0

		" Take the indent of the first previous non-white line that is
		" at the same sexp level. cf. src/misc1.c:get_lisp_indent()
		while 1
			let lnum = prevnonblank(lnum - 1)
			let col = 1

			if lnum <= opening_lnum
				break
			endif

			call cursor(lnum, col)

			" Handle bracket counting edge case
			if s:is_paren()
				let bracket_count += s:bracket_type(s:current_char())
			endif

			while 1
				if search('\v[(\[{}\])]', '', lnum) < 1
					break
				elseif !s:ignored_region()
					let bracket_count += s:bracket_type(s:current_char())
				endif
			endwhile

			if bracket_count == 0
				" Check if this is part of a multiline string
				call cursor(lnum, 1)
				if s:syn_id_name() !~? '\vstring|regex'
					call cursor(orig_lnum, orig_col)
					return indent(lnum)
				endif
			endif
		endwhile

		call cursor(orig_lnum, orig_col)
		return indent
	endfunction

	setlocal indentexpr=GetClojureIndent()

else

	" In case we have searchpairpos not available we fall back to
	" normal lisp indenting.
	setlocal indentexpr=
	setlocal lisp
	let b:undo_indent .= '| setlocal lisp<'

endif

let &cpo = s:save_cpo
unlet! s:save_cpo

" vim:sts=8:sw=8:ts=8:noet
