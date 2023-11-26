" Vim completion script
" Language:	PHP
" Maintainer:	Dávid Szabó ( complex857 AT gmail DOT com )
" Previous Maintainer:	Mikolaj Machowski ( mikmach AT wp DOT pl )
" URL: https://github.com/shawncplus/phpcomplete.vim
" Last Change:  2018 Oct 10
"
"	OPTIONS:
"
"		let g:phpcomplete_relax_static_constraint = 1/0  [default 0]
"			Enables completion for non-static methods when completing for static context (::).
"			This generates E_STRICT level warning, but php calls these methods nonetheless.
"
"		let g:phpcomplete_complete_for_unknown_classes = 1/0 [default 0]
"			Enables completion of variables and functions in "everything under the sun" fashion
"			when completing for an instance or static class context but the code can't tell the class
"			or locate the file that it lives in.
"			The completion list generated this way is only filtered by the completion base
"			and generally not much more accurate then simple keyword completion.
"
"		let g:phpcomplete_search_tags_for_variables = 1/0 [default 0]
"			Enables use of tags when the plugin tries to find variables.
"			When enabled the plugin will search for the variables in the tag files with kind 'v',
"			lines like $some_var = new Foo; but these usually yield highly inaccurate results and
"			can	be fairly slow.
"
"		let g:phpcomplete_min_num_of_chars_for_namespace_completion = n [default 1]
"			This option controls the number of characters the user needs to type before
"			the tags will be searched for namespaces and classes in typed out namespaces in
"			"use ..." context. Setting this to 0 is not recommended because that means the code
"			have to scan every tag, and vim's taglist() function runs extremely slow with a
"			"match everything" pattern.
"
"		let g:phpcomplete_parse_docblock_comments = 1/0 [default 0]
"			When enabled the preview window's content will include information
"			extracted from docblock comments of the completions.
"			Enabling this option will add return types to the completion menu for functions too.
"
"		let g:phpcomplete_cache_taglists = 1/0 [default 1]
"			When enabled the taglist() lookups will be cached and subsequent searches
"			for the same pattern will not check the tagfiles any more, thus making the
"			lookups faster. Cache expiration is based on the mtimes of the tag files.
"
"	TODO:
"	- Switching to HTML (XML?) completion (SQL) inside of phpStrings
"	- allow also for XML completion <- better do html_flavor for HTML
"	  completion
"	- outside of <?php?> getting parent tag may cause problems. Heh, even in
"	  perfect conditions GetLastOpenTag doesn't cooperate... Inside of
"	  phpStrings this can be even a bonus but outside of <?php?> it is not the
"	  best situation

if !exists('g:phpcomplete_relax_static_constraint')
	let g:phpcomplete_relax_static_constraint = 0
endif

if !exists('g:phpcomplete_complete_for_unknown_classes')
	let g:phpcomplete_complete_for_unknown_classes = 0
endif

if !exists('g:phpcomplete_search_tags_for_variables')
	let g:phpcomplete_search_tags_for_variables = 0
endif

if !exists('g:phpcomplete_min_num_of_chars_for_namespace_completion')
	let g:phpcomplete_min_num_of_chars_for_namespace_completion = 1
endif

if !exists('g:phpcomplete_parse_docblock_comments')
	let g:phpcomplete_parse_docblock_comments = 0
endif

if !exists('g:phpcomplete_cache_taglists')
	let g:phpcomplete_cache_taglists = 1
endif

if !exists('s:cache_classstructures')
	let s:cache_classstructures = {}
endif

if !exists('s:cache_tags')
	let s:cache_tags = {}
endif

if !exists('s:cache_tags_checksum')
	let s:cache_tags_checksum = ''
endif

let s:script_path = fnamemodify(resolve(expand('<sfile>:p')), ':h')

function! phpcomplete#CompletePHP(findstart, base) " {{{
	if a:findstart
		unlet! b:php_menu
		" Check if we are inside of PHP markup
		let pos = getpos('.')
		let phpbegin = searchpairpos('<?', '', '?>', 'bWn',
				\ 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string\\|comment"')
		let phpend = searchpairpos('<?', '', '?>', 'Wn',
				\ 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string\\|comment"')

		if phpbegin == [0,0] && phpend == [0,0]
			" We are outside of any PHP markup. Complete HTML
			let htmlbegin = htmlcomplete#CompleteTags(1, '')
			let cursor_col = pos[2]
			let base = getline('.')[htmlbegin : cursor_col]
			let b:php_menu = htmlcomplete#CompleteTags(0, base)
			return htmlbegin
		else
			" locate the start of the word
			let line = getline('.')
			let start = col('.') - 1
			let compl_begin = col('.') - 2
			while start >= 0 && line[start - 1] =~ '[\\a-zA-Z_0-9\x7f-\xff$]'
				let start -= 1
			endwhile
			let b:phpbegin = phpbegin
			let b:compl_context = phpcomplete#GetCurrentInstruction(line('.'), max([0, col('.') - 2]), phpbegin)

			return start
			" We can be also inside of phpString with HTML tags. Deal with
			" it later (time, not lines).
		endif
	endif


	" If exists b:php_menu it means completion was already constructed we
	" don't need to do anything more
	if exists("b:php_menu")
		return b:php_menu
	endif

	if !exists('g:php_builtin_functions')
		call phpcomplete#LoadData()
	endif

	" a:base is very short - we need context
	if exists("b:compl_context")
		let context = b:compl_context
		unlet! b:compl_context
		" chop of the "base" from the end of the current instruction
		if a:base != ""
			let context = substitute(context, '\s*[$a-zA-Z_0-9\x7f-\xff]*$', '', '')
		end
	else
		let context = ''
	end

	try
		let eventignore = &eventignore
		let &eventignore = 'all'
		let winheight = winheight(0)
		let winnr = winnr()

		let [current_namespace, imports] = phpcomplete#GetCurrentNameSpace(getline(0, line('.')))

		if context =~? '^use\s' || context ==? 'use'
			return phpcomplete#CompleteUse(a:base)
		endif

		if context =~ '\(->\|::\)$'
			" {{{
			" Get name of the class
			let classname = phpcomplete#GetClassName(line('.'), context, current_namespace, imports)

			" Get location of class definition, we have to iterate through all
			if classname != ''
				if classname =~ '\'
					" split the last \ segment as a classname, everything else is the namespace
					let classname_parts = split(classname, '\')
					let namespace = join(classname_parts[0:-2], '\')
					let classname = classname_parts[-1]
				else
					let namespace = '\'
				endif
				let classlocation = phpcomplete#GetClassLocation(classname, namespace)
			else
				let classlocation = ''
			endif

			if classlocation != ''
				if classlocation == 'VIMPHP_BUILTINOBJECT' && has_key(g:php_builtin_classes, tolower(classname))
					return phpcomplete#CompleteBuiltInClass(context, classname, a:base)
				endif

				if filereadable(classlocation)
					let classfile = readfile(classlocation)
					let classcontent = ''
					let classcontent .= "\n".phpcomplete#GetClassContents(classlocation, classname)
					let sccontent = split(classcontent, "\n")
					let visibility = expand('%:p') == fnamemodify(classlocation, ':p') ? 'private' : 'public'

					return phpcomplete#CompleteUserClass(context, a:base, sccontent, visibility)
				endif
			endif

			return phpcomplete#CompleteUnknownClass(a:base, context)
			" }}}
		elseif context =~? 'implements'
			return phpcomplete#CompleteClassName(a:base, ['i'], current_namespace, imports)
		elseif context =~? 'instanceof'
			return phpcomplete#CompleteClassName(a:base, ['c', 'n'], current_namespace, imports)
		elseif context =~? 'extends\s\+.\+$' && a:base == ''
			return ['implements']
		elseif context =~? 'extends'
			let kinds = context =~? 'class\s' ? ['c'] : ['i']
			return phpcomplete#CompleteClassName(a:base, kinds, current_namespace, imports)
		elseif context =~? 'class [a-zA-Z_\x7f-\xff\\][a-zA-Z_0-9\x7f-\xff\\]*'
			" special case when you've typed the class keyword and the name too, only extends and implements allowed there
			return filter(['extends', 'implements'], 'stridx(v:val, a:base) == 0')
		elseif context =~? 'new'
			return phpcomplete#CompleteClassName(a:base, ['c'], current_namespace, imports)
		endif

		if a:base =~ '^\$'
			return phpcomplete#CompleteVariable(a:base)
		else
			return phpcomplete#CompleteGeneral(a:base, current_namespace, imports)
		endif
	finally
		silent! exec winnr.'resize '.winheight
		let &eventignore = eventignore
	endtry
endfunction
" }}}

function! phpcomplete#CompleteUse(base) " {{{
	" completes builtin class names regadless of g:phpcomplete_min_num_of_chars_for_namespace_completion
	" completes namespaces from tags
	"   * requires patched ctags
	" completes classnames from tags within the already typed out namespace using the "namespace" field of tags
	"   * requires patched ctags

	let res = []

	" class and namespace names are always considered absoltute in use ... expressions, leading slash is not recommended
	" by the php manual, so we gonna get rid of that
	if a:base =~? '^\'
		let base = substitute(a:base, '^\', '', '')
	else
		let base = a:base
	endif

	let namespace_match_pattern  = substitute(base, '\\', '\\\\', 'g')
	let classname_match_pattern = matchstr(base, '[^\\]\+$')
	let namespace_for_class = substitute(substitute(namespace_match_pattern, '\\\\', '\\', 'g'), '\\*'.classname_match_pattern.'$', '', '')

	if len(namespace_match_pattern) >= g:phpcomplete_min_num_of_chars_for_namespace_completion
		if len(classname_match_pattern) >= g:phpcomplete_min_num_of_chars_for_namespace_completion
			let tags = phpcomplete#GetTaglist('^\('.namespace_match_pattern.'\|'.classname_match_pattern.'\)')
		else
			let tags = phpcomplete#GetTaglist('^'.namespace_match_pattern)
		endif

		let patched_ctags_detected = 0
		let namespaced_matches = []
		let no_namespace_matches = []
		for tag in tags
			if has_key(tag, 'namespace')
				let patched_ctags_detected = 1
			endif

			if tag.kind ==? 'n' && tag.name =~? '^'.namespace_match_pattern
				let patched_ctags_detected = 1
				call add(namespaced_matches, {'word': tag.name, 'kind': 'n', 'menu': tag.filename, 'info': tag.filename })
			elseif has_key(tag, 'namespace') && (tag.kind ==? 'c' || tag.kind ==? 'i' || tag.kind ==? 't') && tag.namespace ==? namespace_for_class
				call add(namespaced_matches, {'word': namespace_for_class.'\'.tag.name, 'kind': tag.kind, 'menu': tag.filename, 'info': tag.filename })
			elseif (tag.kind ==? 'c' || tag.kind ==? 'i' || tag.kind ==? 't')
				call add(no_namespace_matches, {'word': namespace_for_class.'\'.tag.name, 'kind': tag.kind, 'menu': tag.filename, 'info': tag.filename })
			endif
		endfor
		" if it seems that the tags file have namespace information we can safely throw
		" away namespaceless tag matches since we can be sure they are invalid
		if patched_ctags_detected
			no_namespace_matches = []
		endif
		let res += namespaced_matches + no_namespace_matches
	endif

	if base !~ '\'
		let builtin_classnames = filter(keys(copy(g:php_builtin_classnames)), 'v:val =~? "^'.classname_match_pattern.'"')
		for classname in builtin_classnames
			call add(res, {'word': g:php_builtin_classes[tolower(classname)].name, 'kind': 'c'})
		endfor
		let builtin_interfacenames = filter(keys(copy(g:php_builtin_interfacenames)), 'v:val =~? "^'.classname_match_pattern.'"')
		for interfacename in builtin_interfacenames
			call add(res, {'word': g:php_builtin_interfaces[tolower(interfacename)].name, 'kind': 'i'})
		endfor
	endif

	for comp in res
		let comp.word = substitute(comp.word, '^\\', '', '')
	endfor

	return res
endfunction
" }}}

function! phpcomplete#CompleteGeneral(base, current_namespace, imports) " {{{
	" Complete everything
	"  + functions,  DONE
	"  + keywords of language DONE
	"  + defines (constant definitions), DONE
	"  + extend keywords for predefined constants, DONE
	"  + classes (after new), DONE
	"  + limit choice after -> and :: to funcs and vars DONE

	" Internal solution for finding functions in current file.

	if a:base =~? '^\'
		let leading_slash = '\'
	else
		let leading_slash = ''
	endif

	let file = getline(1, '$')
	call filter(file,
				\ 'v:val =~ "function\\s\\+&\\?[a-zA-Z_\\x7f-\\xff][a-zA-Z_0-9\\x7f-\\xff]*\\s*("')
	let jfile = join(file, ' ')
	let int_values = split(jfile, 'function\s\+')
	let int_functions = {}
	for i in int_values
		let f_name = matchstr(i,
					\ '^&\?\zs[a-zA-Z_\x7f-\xff][a-zA-Z_0-9\x7f-\xff]*\ze')
		if f_name =~? '^'.substitute(a:base, '\\', '\\\\', 'g')
			let f_args = matchstr(i,
						\ '^&\?[a-zA-Z_\x7f-\xff][a-zA-Z_0-9\x7f-\xff]*\s*(\zs.\{-}\ze)\_s*\(;\|{\|$\)')
			let int_functions[f_name.'('] = f_args.')'
		endif
	endfor

	" Internal solution for finding constants in current file
	let file = getline(1, '$')
	call filter(file, 'v:val =~ "define\\s*("')
	let jfile = join(file, ' ')
	let int_values = split(jfile, 'define\s*(\s*')
	let int_constants = {}
	for i in int_values
		let c_name = matchstr(i, '\(["'']\)\zs[a-zA-Z_\x7f-\xff][a-zA-Z_0-9\x7f-\xff]*\ze\1')
		if c_name != '' && c_name =~# '^'.substitute(a:base, '\\', '\\\\', 'g')
			let int_constants[leading_slash.c_name] = ''
		endif
	endfor

	" Prepare list of functions from tags file
	let ext_functions  = {}
	let ext_constants  = {}
	let ext_classes    = {}
	let ext_traits     = {}
	let ext_interfaces = {}
	let ext_namespaces = {}

	let base = substitute(a:base, '^\\', '', '')
	let [tag_match_pattern, namespace_for_tag] = phpcomplete#ExpandClassName(a:base, a:current_namespace, a:imports)
	let namespace_match_pattern  = substitute((namespace_for_tag == '' ? '' : namespace_for_tag.'\').tag_match_pattern, '\\', '\\\\', 'g')

	let tags = []
	if len(namespace_match_pattern) >= g:phpcomplete_min_num_of_chars_for_namespace_completion && len(tag_match_pattern) >= g:phpcomplete_min_num_of_chars_for_namespace_completion && tag_match_pattern != namespace_match_pattern
		let tags = phpcomplete#GetTaglist('\c^\('.tag_match_pattern.'\|'.namespace_match_pattern.'\)')
	elseif len(namespace_match_pattern) >= g:phpcomplete_min_num_of_chars_for_namespace_completion
		let tags = phpcomplete#GetTaglist('\c^'.namespace_match_pattern)
	elseif len(tag_match_pattern) >= g:phpcomplete_min_num_of_chars_for_namespace_completion
		let tags = phpcomplete#GetTaglist('\c^'.tag_match_pattern)
	endif

	for tag in tags
		if !has_key(tag, 'namespace') || tag.namespace ==? a:current_namespace || tag.namespace ==? namespace_for_tag
			if has_key(tag, 'namespace')
				let full_name = tag.namespace.'\'.tag.name " absolute namespaced name (without leading '\')

				let base_parts = split(a:base, '\')
				if len(base_parts) > 1
					let namespace_part = join(base_parts[0:-2], '\')
				else
					let namespace_part = ''
				endif
				let relative_name = (namespace_part == '' ? '' : namespace_part.'\').tag.name
			endif

			if tag.kind ==? 'n' && tag.name =~? '^'.namespace_match_pattern
				let info = tag.name.' - '.tag.filename
				" patched ctag provides absolute namespace names as tag name, namespace tags dont have namespace fields
				let full_name = tag.name

				let base_parts = split(a:base, '\')
				let full_name_parts = split(full_name, '\')
				if len(base_parts) > 1
					" the first segment could be a renamed import, take the first segment from the user provided input
					" so if it's a sub namespace of a renamed namespace, just use the typed in segments in place of the absolute path
					" for example:
					"     you have a namespace NS1\SUBNS as SUB
					"     you have a sub-sub-namespace NS1\SUBNS\SUBSUB
					"     typed in SUB\SU
					"     the tags will return NS1\SUBNS\SUBSUB
					"     the completion should be: SUB\SUBSUB by replacing the NS1\SUBSN to SUB as in the import
					if has_key(a:imports, base_parts[0]) && a:imports[base_parts[0]].kind == 'n'
						let import = a:imports[base_parts[0]]
						let relative_name = substitute(full_name, '^'.substitute(import.name, '\\', '\\\\', 'g'), base_parts[0], '')
					else
						let relative_name = strpart(full_name, stridx(full_name, a:base))
					endif
				else
					let relative_name = strpart(full_name, stridx(full_name, a:base))
				endif

				if leading_slash == ''
					let ext_namespaces[relative_name.'\'] = info
				else
					let ext_namespaces['\'.full_name.'\'] = info
				endif
			elseif tag.kind ==? 'f' && !has_key(tag, 'class') " class related functions (methods) completed elsewhere, only works with patched ctags
				if has_key(tag, 'signature')
					let prototype = tag.signature[1:-2] " drop the ()s around the string
				else
					let prototype = matchstr(tag.cmd,
								\ 'function\s\+&\?[^[:space:]]\+\s*(\s*\zs.\{-}\ze\s*)\s*{\?')
				endif
				let info = prototype.') - '.tag.filename

				if !has_key(tag, 'namespace')
					let ext_functions[tag.name.'('] = info
				else
					if tag.namespace ==? namespace_for_tag
						if leading_slash == ''
							let ext_functions[relative_name.'('] = info
						else
							let ext_functions['\'.full_name.'('] = info
						endif
					endif
				endif
			elseif tag.kind ==? 'd'
				let info = ' - '.tag.filename
				if !has_key(tag, 'namespace')
					let ext_constants[tag.name] = info
				else
					if tag.namespace ==? namespace_for_tag
						if leading_slash == ''
							let ext_constants[relative_name] = info
						else
							let ext_constants['\'.full_name] = info
						endif
					endif
				endif
			elseif tag.kind ==? 'c' || tag.kind ==? 'i' || tag.kind ==? 't'
				let info = ' - '.tag.filename

				let key = ''
				if !has_key(tag, 'namespace')
					let key = tag.name
				else
					if tag.namespace ==? namespace_for_tag
						if leading_slash == ''
							let key = relative_name
						else
							let key = '\'.full_name
						endif
					endif
				endif

				if key != ''
					if tag.kind ==? 'c'
						let ext_classes[key] = info
					elseif tag.kind ==? 'i'
						let ext_interfaces[key] = info
					elseif tag.kind ==? 't'
						let ext_traits[key] = info
					endif
				endif
			endif
		endif
	endfor

	let builtin_constants  = {}
	let builtin_classnames = {}
	let builtin_interfaces = {}
	let builtin_functions  = {}
	let builtin_keywords   = {}
	let base = substitute(a:base, '^\', '', '')
	if a:current_namespace == '\' || (a:base =~ '^\\' && a:base =~ '^\\[^\\]*$')

		" Add builtin class names
		for [classname, info] in items(g:php_builtin_classnames)
			if classname =~? '^'.base
				let builtin_classnames[leading_slash.g:php_builtin_classes[tolower(classname)].name] = info
			endif
		endfor
		for [interfacename, info] in items(g:php_builtin_interfacenames)
			if interfacename =~? '^'.base
				let builtin_interfaces[leading_slash.g:php_builtin_interfaces[tolower(interfacename)].name] = info
			endif
		endfor
	endif

	" Prepare list of constants from built-in constants
	for [constant, info] in items(g:php_constants)
		if constant =~# '^'.base
			let builtin_constants[leading_slash.constant] = info
		endif
	endfor

	if leading_slash == '' " keywords should not be completed when base starts with '\'
		" Treat keywords as constants
		for [constant, info] in items(g:php_keywords)
			if constant =~? '^'.a:base
				let builtin_keywords[constant] = info
			endif
		endfor
	endif

	for [function_name, info] in items(g:php_builtin_functions)
		if function_name =~? '^'.base
			let builtin_functions[leading_slash.function_name] = info
		endif
	endfor

	" All constants
	call extend(int_constants, ext_constants)

	" All functions
	call extend(int_functions, ext_functions)
	call extend(int_functions, builtin_functions)

	for [imported_name, import] in items(a:imports)
		if imported_name =~? '^'.base
			if import.kind ==? 'c'
				if import.builtin
					let builtin_classnames[imported_name] = ' '.import.name
				else
					let ext_classes[imported_name] = ' '.import.name.' - '.import.filename
				endif
			elseif import.kind ==? 'i'
				if import.builtin
					let builtin_interfaces[imported_name] = ' '.import.name
				else
					let ext_interfaces[imported_name] = ' '.import.name.' - '.import.filename
				endif
			elseif import.kind ==? 't'
				let ext_traits[imported_name] = ' '.import.name.' - '.import.filename
			endif

			" no builtin interfaces
			if import.kind == 'n'
				let ext_namespaces[imported_name.'\'] = ' '.import.name.' - '.import.filename
			endif
		end
	endfor

	let all_values = {}

	" Add functions found in this file
	call extend(all_values, int_functions)

	" Add namespaces from tags
	call extend(all_values, ext_namespaces)

	" Add constants from the current file
	call extend(all_values, int_constants)

	" Add built-in constants
	call extend(all_values, builtin_constants)

	" Add external classes
	call extend(all_values, ext_classes)

	" Add external interfaces
	call extend(all_values, ext_interfaces)

	" Add external traits
	call extend(all_values, ext_traits)

	" Add built-in classes
	call extend(all_values, builtin_classnames)

	" Add built-in interfaces
	call extend(all_values, builtin_interfaces)

	" Add php keywords
	call extend(all_values, builtin_keywords)

	let final_list = []
	let int_list = sort(keys(all_values))
	for i in int_list
		if has_key(ext_namespaces, i)
			let final_list += [{'word':i, 'kind':'n', 'menu': ext_namespaces[i], 'info': ext_namespaces[i]}]
		elseif has_key(int_functions, i)
			let final_list +=
						\ [{'word':i,
						\	'info':i.int_functions[i],
						\	'menu':int_functions[i],
						\	'kind':'f'}]
		elseif has_key(ext_classes, i) || has_key(builtin_classnames, i)
			let info = has_key(ext_classes, i) ? ext_classes[i] : builtin_classnames[i].' - builtin'
			let final_list += [{'word':i, 'kind': 'c', 'menu': info, 'info': i.info}]
		elseif has_key(ext_interfaces, i) || has_key(builtin_interfaces, i)
			let info = has_key(ext_interfaces, i) ? ext_interfaces[i] : builtin_interfaces[i].' - builtin'
			let final_list += [{'word':i, 'kind': 'i', 'menu': info, 'info': i.info}]
		elseif has_key(ext_traits, i)
			let final_list += [{'word':i, 'kind': 't', 'menu': ext_traits[i], 'info': ext_traits[i]}]
		elseif has_key(int_constants, i) || has_key(builtin_constants, i)
			let info = has_key(int_constants, i) ? int_constants[i] : ' - builtin'
			let final_list += [{'word':i, 'kind': 'd', 'menu': info, 'info': i.info}]
		else
			let final_list += [{'word':i}]
		endif
	endfor

	return final_list
endfunction
" }}}

function! phpcomplete#CompleteUnknownClass(base, context) " {{{
	let res = []

	if g:phpcomplete_complete_for_unknown_classes != 1
		return []
	endif

	if a:base =~ '^\$'
		let adddollar = '$'
	else
		let adddollar = ''
	endif

	let file = getline(1, '$')

	" Internal solution for finding object properties in current file.
	if a:context =~ '::'
		let variables = filter(deepcopy(file),
					\ 'v:val =~ "^\\s*\\(static\\|static\\s\\+\\(public\\|var\\)\\|\\(public\\|var\\)\\s\\+static\\)\\s\\+\\$"')
	elseif a:context =~ '->'
		let variables = filter(deepcopy(file),
					\ 'v:val =~ "^\\s*\\(public\\|var\\)\\s\\+\\$"')
	endif
	let jvars = join(variables, ' ')
	let svars = split(jvars, '\$')
	let int_vars = {}
	for i in svars
		let c_var = matchstr(i,
					\ '^\zs[a-zA-Z_\x7f-\xff][a-zA-Z_0-9\x7f-\xff]*\ze')
		if c_var != ''
			let int_vars[adddollar.c_var] = ''
		endif
	endfor

	" Internal solution for finding functions in current file.
	call filter(deepcopy(file),
			\ 'v:val =~ "function\\s\\+&\\?[a-zA-Z_\\x7f-\\xff][a-zA-Z_0-9\\x7f-\\xff]*\\s*("')
	let jfile = join(file, ' ')
	let int_values = split(jfile, 'function\s\+')
	let int_functions = {}
	for i in int_values
		let f_name = matchstr(i,
				\ '^&\?\zs[a-zA-Z_\x7f-\xff][a-zA-Z_0-9\x7f-\xff]*\ze')
		let f_args = matchstr(i,
				\ '^&\?[a-zA-Z_\x7f-\xff][a-zA-Z_0-9\x7f-\xff]*\s*(\zs.\{-}\ze)\_s*\(;\|{\|$\)')

		let int_functions[f_name.'('] = f_args.')'
	endfor

	" collect external functions from tags
	let ext_functions = {}
	let tags = phpcomplete#GetTaglist('^'.substitute(a:base, '^\$', '', ''))
	for tag in tags
		if tag.kind ==? 'f'
			let item = tag.name
			if has_key(tag, 'signature')
				let prototype = tag.signature[1:-2]
			else
				let prototype = matchstr(tag.cmd,
						\ 'function\s\+&\?[^[:space:]]\+\s*(\s*\zs.\{-}\ze\s*)\s*{\?')
			endif
			let ext_functions[item.'('] = prototype.') - '.tag['filename']
		endif
	endfor

	" All functions to one hash for later reference when deciding kind
	call extend(int_functions, ext_functions)

	let all_values = {}
	call extend(all_values, int_functions)
	call extend(all_values, int_vars) " external variables are already in
	call extend(all_values, g:php_builtin_object_functions)

	for m in sort(keys(all_values))
		if m =~ '\(^\|::\)'.a:base
			call add(res, m)
		endif
	endfor

	let start_list = res

	let final_list = []
	for i in start_list
		if has_key(int_vars, i)
			let class = ' '
			if all_values[i] != ''
				let class = i.' class '
			endif
			let final_list += [{'word':i, 'info':class.all_values[i], 'kind':'v'}]
		else
			let final_list +=
					\ [{'word':substitute(i, '.*::', '', ''),
					\	'info':i.all_values[i],
					\	'menu':all_values[i],
					\	'kind':'f'}]
		endif
	endfor
	return final_list
endfunction
" }}}

function! phpcomplete#CompleteVariable(base) " {{{
	let res = []

	" Internal solution for current file.
	let file = getline(1, '$')
	let jfile = join(file, ' ')
	let int_vals = split(jfile, '\ze\$')
	let int_vars = {}
	for i in int_vals
		if i =~? '^\$[a-zA-Z_\x7f-\xff][a-zA-Z_0-9\x7f-\xff]*\s*=\s*new'
			let val = matchstr(i,
						\ '^\$[a-zA-Z_\x7f-\xff][a-zA-Z_0-9\x7f-\xff]*')
		else
			let val = matchstr(i,
						\ '^\$[a-zA-Z_\x7f-\xff][a-zA-Z_0-9\x7f-\xff]*')
		endif
		if val != ''
			let int_vars[val] = ''
		endif
	endfor

	call extend(int_vars, g:php_builtin_vars)

	" ctags has support for PHP, use tags file for external variables
	if  g:phpcomplete_search_tags_for_variables
		let ext_vars = {}
		let tags = phpcomplete#GetTaglist('\C^'.substitute(a:base, '^\$', '', ''))
		for tag in tags
			if tag.kind ==? 'v'
				let item = tag.name
				let m_menu = ''
				if tag.cmd =~? tag['name'].'\s*=\s*new\s\+'
					let m_menu = matchstr(tag.cmd,
								\ '\c=\s*new\s\+\zs[a-zA-Z_0-9\x7f-\xff]\+\ze')
				endif
				let ext_vars['$'.item] = m_menu
			endif
		endfor
		call extend(int_vars, ext_vars)
	endif

	for m in sort(keys(int_vars))
		if m =~# '^\'.a:base
			call add(res, m)
		endif
	endfor

	let int_list = res

	let int_dict = []
	for i in int_list
		if int_vars[i] != ''
			let class = ' '
			if int_vars[i] != ''
				let class = i.' class '
			endif
			let int_dict += [{'word':i, 'info':class.int_vars[i], 'menu':int_vars[i], 'kind':'v'}]
		else
			let int_dict += [{'word':i, 'kind':'v'}]
		endif
	endfor

	return int_dict
endfunction
" }}}

function! phpcomplete#CompleteClassName(base, kinds, current_namespace, imports) " {{{
	let kinds = sort(a:kinds)
	" Complete class name
	let res = []
	if a:base =~? '^\'
		let leading_slash = '\'
		let base = substitute(a:base, '^\', '', '')
	else
		let leading_slash = ''
		let base = a:base
	endif

	" Internal solution for finding classes in current file.
	let file = getline(1, '$')
	let filterstr = ''

	if kinds == ['c', 'i']
		let filterstr = 'v:val =~? "\\(class\\|interface\\)\\s\\+[a-zA-Z_\\x7f-\\xff][a-zA-Z_0-9\\x7f-\\xff]*\\s*"'
	elseif kinds == ['c', 'n']
		let filterstr = 'v:val =~? "\\(class\\|namespace\\)\\s\\+[a-zA-Z_\\x7f-\\xff][a-zA-Z_0-9\\x7f-\\xff]*\\s*"'
	elseif kinds == ['c']
		let filterstr = 'v:val =~? "class\\s\\+[a-zA-Z_\\x7f-\\xff][a-zA-Z_0-9\\x7f-\\xff]*\\s*"'
	elseif kinds == ['i']
		let filterstr = 'v:val =~? "interface\\s\\+[a-zA-Z_\\x7f-\\xff][a-zA-Z_0-9\\x7f-\\xff]*\\s*"'
	endif

	call filter(file, filterstr)

	for line in file
		let c_name = matchstr(line, '\c\(class\|interface\)\s*\zs[a-zA-Z_\x7f-\xff][a-zA-Z_0-9\x7f-\xff]*')
		let kind = (line =~? '^\s*class' ? 'c' : 'i')
		if c_name != '' && c_name =~? '^'.base
			call add(res, {'word': c_name, 'kind': kind})
		endif
	endfor

	" resolve the typed in part with namespaces (if there's a \ in it)
	let [tag_match_pattern, namespace_for_class] = phpcomplete#ExpandClassName(a:base, a:current_namespace, a:imports)

	let tags = []
	if len(tag_match_pattern) >= g:phpcomplete_min_num_of_chars_for_namespace_completion
		let tags = phpcomplete#GetTaglist('^\c'.tag_match_pattern)
	endif

	if len(tags)
		let base_parts = split(a:base, '\')
		if len(base_parts) > 1
			let namespace_part = join(base_parts[0:-2], '\').'\'
		else
			let namespace_part = ''
		endif
		let no_namespace_matches = []
		let namespaced_matches = []
		let seen_namespaced_tag = 0
		for tag in tags
			if has_key(tag, 'namespace')
				let seen_namespaced_tag = 1
			endif
			let relative_name = namespace_part.tag.name
			" match base without the namespace part for namespaced base but not namespaced tags, for tagfiles with old ctags
			if !has_key(tag, 'namespace') && index(kinds, tag.kind) != -1 && stridx(tolower(tag.name), tolower(base[len(namespace_part):])) == 0
				call add(no_namespace_matches, {'word': leading_slash.relative_name, 'kind': tag.kind, 'menu': tag.filename, 'info': tag.filename })
			endif
			if has_key(tag, 'namespace') && index(kinds, tag.kind) != -1 && tag.namespace ==? namespace_for_class
				let full_name = tag.namespace.'\'.tag.name " absolute namespaced name (without leading '\')
				call add(namespaced_matches, {'word': leading_slash == '\' ? leading_slash.full_name : relative_name, 'kind': tag.kind, 'menu': tag.filename, 'info': tag.filename })
			endif
		endfor
		" if there was a tag with namespace field, assume tag files with namespace support, so the matches
		" without a namespace field are in the global namespace so if there were namespace in the base
		" we should not add them to the matches
		if seen_namespaced_tag && namespace_part != ''
			let no_namespace_matches = []
		endif
		let res += no_namespace_matches + namespaced_matches
	endif

	" look for built in classnames and interfaces
	let base_parts = split(base, '\')
	if a:current_namespace == '\' || (leading_slash == '\' && len(base_parts) < 2)
		if index(kinds, 'c') != -1
			let builtin_classnames = filter(keys(copy(g:php_builtin_classnames)), 'v:val =~? "^'.substitute(a:base, '\\', '', 'g').'"')
			for classname in builtin_classnames
				let menu = ''
				" if we have a constructor for this class, add parameters as to the info
				if has_key(g:php_builtin_classes[tolower(classname)].methods, '__construct')
					let menu = g:php_builtin_classes[tolower(classname)]['methods']['__construct']['signature']
				endif
				call add(res, {'word': leading_slash.g:php_builtin_classes[tolower(classname)].name, 'kind': 'c', 'menu': menu})
			endfor
		endif

		if index(kinds, 'i') != -1
			let builtin_interfaces = filter(keys(copy(g:php_builtin_interfaces)), 'v:val =~? "^'.substitute(a:base, '\\', '', 'g').'"')
			for interfacename in builtin_interfaces
				call add(res, {'word': leading_slash.g:php_builtin_interfaces[interfacename]['name'], 'kind': 'i', 'menu': ''})
			endfor
		endif
	endif

	" add matching imported things
	for [imported_name, import] in items(a:imports)
		if imported_name =~? '^'.base && index(kinds, import.kind) != -1
			let menu = import.name.(import.builtin ? ' - builtin' : '')
			call add(res, {'word': imported_name, 'kind': import.kind, 'menu': menu})
		endif
	endfor

	let res = sort(res, 'phpcomplete#CompareCompletionRow')
	return res
endfunction
" }}}

function! phpcomplete#CompareCompletionRow(i1, i2) " {{{
	return a:i1.word == a:i2.word ? 0 : a:i1.word > a:i2.word ? 1 : -1
endfunction
" }}}

function! s:getNextCharWithPos(filelines, current_pos) " {{{
	let line_no   = a:current_pos[0]
	let col_no    = a:current_pos[1]
	let last_line = a:filelines[len(a:filelines) - 1]
	let end_pos   = [len(a:filelines) - 1, strlen(last_line) - 1]
	if line_no > end_pos[0] || line_no == end_pos[0] && col_no > end_pos[1]
		return ['EOF', 'EOF']
	endif

	" we've not reached the end of the current line break
	if col_no + 1 < strlen(a:filelines[line_no])
		let col_no += 1
	else
		" we've reached the end of the current line, jump to the next
		" non-blank line (blank lines have no position where we can read from,
		" not even a whitespace. The newline char does not positionable by vim
		let line_no += 1
		while strlen(a:filelines[line_no]) == 0
			let line_no += 1
		endwhile

		let col_no = 0
	endif

	" return 'EOF' string to signal end of file, normal results only one char
	" in length
	if line_no == end_pos[0] && col_no > end_pos[1]
		return ['EOF', 'EOF']
	endif

	return [[line_no, col_no], a:filelines[line_no][col_no]]
endfunction " }}}

function! phpcomplete#EvaluateModifiers(modifiers, required_modifiers, prohibited_modifiers) " {{{
	" if there's no modifier, and no modifier is allowed and no modifier is required
	if len(a:modifiers) == 0 && len(a:required_modifiers) == 0
		return 1
	else
		" check if every required modifier is present
		for required_modifier in a:required_modifiers
			if index(a:modifiers, required_modifier) == -1
				return 0
			endif
		endfor

		for modifier in a:modifiers
			" if the modifier is prohibited it's a no match
			if index(a:prohibited_modifiers, modifier) != -1
				return 0
			endif
		endfor

		" anything that is not explicitly required or prohibited is allowed
		return 1
	endif
endfunction
" }}}

function! phpcomplete#CompleteUserClass(context, base, sccontent, visibility) " {{{
	let final_list = []
	let res  = []

	let required_modifiers = []
	let prohibited_modifiers = []

	if a:visibility == 'public'
		let prohibited_modifiers += ['private', 'protected']
	endif

	" limit based on context to static or normal methods
	let static_con = ''
	if a:context =~ '::$' && a:context !~? 'parent::$'
		if g:phpcomplete_relax_static_constraint != 1
			let required_modifiers += ['static']
		endif
	elseif a:context =~ '->$'
		let prohibited_modifiers += ['static']
	endif

	let all_function = filter(deepcopy(a:sccontent),
				\ 'v:val =~ "^\\s*\\(public\\s\\+\\|protected\\s\\+\\|private\\s\\+\\|final\\s\\+\\|abstract\\s\\+\\|static\\s\\+\\)*function"')

	let functions = []
	for i in all_function
		let modifiers = split(matchstr(tolower(i), '\zs.\+\zefunction'), '\s\+')
		if phpcomplete#EvaluateModifiers(modifiers, required_modifiers, prohibited_modifiers) == 1
			call add(functions, i)
		endif
	endfor

	let c_functions = {}
	let c_doc = {}
	for i in functions
		let f_name = matchstr(i,
					\ 'function\s*&\?\zs[a-zA-Z_\x7f-\xff][a-zA-Z_0-9\x7f-\xff]*\ze')
		let f_args = matchstr(i,
					\ 'function\s*&\?[a-zA-Z_\x7f-\xff][a-zA-Z_0-9\x7f-\xff]*\s*(\zs.\{-}\ze)\_s*\(;\|{\|\_$\)')
		if f_name != '' && stridx(f_name, '__') != 0
			let c_functions[f_name.'('] = f_args
			if g:phpcomplete_parse_docblock_comments
				let c_doc[f_name.'('] = phpcomplete#GetDocBlock(a:sccontent, 'function\s*&\?\<'.f_name.'\>')
			endif
		endif
	endfor

	" limit based on context to static or normal attributes
	if a:context =~ '::$' && a:context !~? 'parent::$'
		" variables must have static to be accessed as static unlike functions
		let required_modifiers += ['static']
	endif
	let all_variable = filter(deepcopy(a:sccontent),
					\ 'v:val =~ "\\(^\\s*\\(var\\s\\+\\|public\\s\\+\\|protected\\s\\+\\|private\\s\\+\\|final\\s\\+\\|abstract\\s\\+\\|static\\s\\+\\)\\+\\$\\|^\\s*\\(\\/\\|\\*\\)*\\s*@property\\s\\+\\S\\+\\s\\S\\{-}\\s*$\\)"')

	let variables = []
	for i in all_variable
		let modifiers = split(matchstr(tolower(i), '\zs.\+\ze\$'), '\s\+')
		if phpcomplete#EvaluateModifiers(modifiers, required_modifiers, prohibited_modifiers) == 1
			call add(variables, i)
		endif
	endfor

	let static_vars = split(join(variables, ' '), '\$')
	let c_variables = {}

	let var_index = 0
	for i in static_vars
		let c_var = matchstr(i,
					\ '^\zs[a-zA-Z_\x7f-\xff][a-zA-Z_0-9\x7f-\xff]*\ze')
		if c_var != ''
			if a:context =~ '::$'
				let c_var = '$'.c_var
			endif
			let c_variables[c_var] = ''
			if g:phpcomplete_parse_docblock_comments && len(get(variables, var_index)) > 0
				let c_doc[c_var] = phpcomplete#GetDocBlock(a:sccontent, variables[var_index])
			endif
			let var_index += 1
		endif
	endfor

	let constants = filter(deepcopy(a:sccontent),
				\ 'v:val =~ "^\\s*const\\s\\+"')

	let jcons = join(constants, ' ')
	let scons = split(jcons, 'const')

	let c_constants = {}
	let const_index = 0
	for i in scons
		let c_con = matchstr(i,
					\ '^\s*\zs[a-zA-Z_\x7f-\xff][a-zA-Z_0-9\x7f-\xff]*\ze')
		if c_con != ''
			let c_constants[c_con] = ''
			if g:phpcomplete_parse_docblock_comments && len(get(constants, const_index)) > 0
				let c_doc[c_con] = phpcomplete#GetDocBlock(a:sccontent, constants[const_index])
			endif
			let const_index += 1
		endif
	endfor

	let all_values = {}
	call extend(all_values, c_functions)
	call extend(all_values, c_variables)
	call extend(all_values, c_constants)

	for m in sort(keys(all_values))
		if stridx(m, a:base) == 0
			call add(res, m)
		endif
	endfor

	let start_list = res

	let final_list = []
	for i in start_list
		let docblock = phpcomplete#ParseDocBlock(get(c_doc, i, ''))
		if has_key(c_variables, i)
			let final_list +=
						\ [{'word': i,
						\	'info':phpcomplete#FormatDocBlock(docblock),
						\	'menu':get(docblock.var, 'type', ''),
						\	'kind':'v'}]
		elseif has_key(c_constants, i)
			let info = phpcomplete#FormatDocBlock(docblock)
			if info != ''
				let info = "\n".info
			endif
			let final_list +=
						\ [{'word':i,
						\	'info':i.info,
						\	'menu':all_values[i],
						\	'kind':'d'}]
		else
			let return_type = get(docblock.return, 'type', '')
			if return_type != ''
				let return_type = ' | '.return_type
			endif
			let info = phpcomplete#FormatDocBlock(docblock)
			if info != ''
				let info = "\n".info
			endif
			let final_list +=
						\ [{'word':substitute(i, '.*::', '', ''),
						\	'info':i.all_values[i].')'.info,
						\	'menu':all_values[i].')'.return_type,
						\	'kind':'f'}]
		endif
	endfor

	return final_list
endfunction
" }}}

function! phpcomplete#CompleteBuiltInClass(context, classname, base) " {{{
	let class_info = g:php_builtin_classes[tolower(a:classname)]
	let res = []
	if a:context =~ '->$' " complete for everything instance related
		" methods
		for [method_name, method_info] in items(class_info.methods)
			if stridx(method_name, '__') != 0 && (a:base == '' || method_name =~? '^'.a:base)
				call add(res, {'word':method_name.'(', 'kind': 'f', 'menu': method_info.signature, 'info': method_info.signature })
			endif
		endfor
		" properties
		for [property_name, property_info] in items(class_info.properties)
			if a:base == '' || property_name =~? '^'.a:base
				call add(res, {'word':property_name, 'kind': 'v', 'menu': property_info.type, 'info': property_info.type })
			endif
		endfor
	elseif a:context =~ '::$' " complete for everything static
		" methods
		for [method_name, method_info] in items(class_info.static_methods)
			if a:base == '' || method_name =~? '^'.a:base
				call add(res, {'word':method_name.'(', 'kind': 'f', 'menu': method_info.signature, 'info': method_info.signature })
			endif
		endfor
		" properties
		for [property_name, property_info] in items(class_info.static_properties)
			if a:base == '' || property_name =~? '^'.a:base
				call add(res, {'word':property_name, 'kind': 'v', 'menu': property_info.type, 'info': property_info.type })
			endif
		endfor
		" constants
		for [constant_name, constant_info] in items(class_info.constants)
			if a:base == '' || constant_name =~? '^'.a:base
				call add(res, {'word':constant_name, 'kind': 'd', 'menu': constant_info, 'info': constant_info})
			endif
		endfor
	endif
	return res
endfunction
" }}}

function! phpcomplete#GetTaglist(pattern) " {{{
	let cache_checksum = ''
	if g:phpcomplete_cache_taglists == 1
		" build a string with  format of "<tagfile>:<mtime>$<tagfile2>:<mtime2>..."
		" to validate that the tags are not changed since the time we saved the results in cache
		for tagfile in sort(tagfiles())
			let cache_checksum .= fnamemodify(tagfile, ':p').':'.getftime(tagfile).'$'
		endfor

		if s:cache_tags_checksum != cache_checksum
			" tag file(s) changed
			" since we don't know where individual tags coming from when calling taglist() we zap the whole cache
			" no way to clear only the entries originating from the changed tag file
			let s:cache_tags = {}
		endif

		if has_key(s:cache_tags, a:pattern)
			return s:cache_tags[a:pattern]
		endif
	endif

	let tags = taglist(a:pattern)
	for tag in tags
		for prop in keys(tag)
			if prop == 'cmd' || prop == 'static' || prop == 'kind' || prop == 'builtin'
				continue
			endif
			let tag[prop] = substitute(tag[prop], '\\\\', '\\', 'g')
		endfor
	endfor
	let s:cache_tags[a:pattern] = tags
	let has_key = has_key(s:cache_tags, a:pattern)
	let s:cache_tags_checksum = cache_checksum
	return tags
endfunction
" }}}

function! phpcomplete#GetCurrentInstruction(line_number, col_number, phpbegin) " {{{
	" locate the current instruction (up until the previous non comment or string ";" or php region start (<?php or <?) without newlines
	let col_number = a:col_number
	let line_number = a:line_number
	let line = getline(a:line_number)
	let current_char = -1
	let instruction = ''
	let parent_depth = 0
	let bracket_depth = 0
	let stop_chars = [
				\ '!', '@', '%', '^', '&',
				\ '*', '/', '-', '+', '=',
				\ ':', '>', '<', '.', '?',
				\ ';', '(', '|', '['
				\ ]

	let phpbegin_length = len(matchstr(getline(a:phpbegin[0]), '\zs<?\(php\)\?\ze'))
	let phpbegin_end = [a:phpbegin[0], a:phpbegin[1] - 1 + phpbegin_length]

	" will hold the first place where a coma could have ended the match
	let first_coma_break_pos = -1
	let next_char = len(line) < col_number ? line[col_number + 1] : ''

	while !(line_number == 1 && col_number == 1)
		if current_char != -1
			let next_char = current_char
		endif

		let current_char = line[col_number]
		let synIDName = synIDattr(synID(line_number, col_number + 1, 0), 'name')

		if col_number - 1 == -1
			let prev_line_number = line_number - 1
			let prev_line = getline(line_number - 1)
			let prev_col_number = strlen(prev_line)
		else
			let prev_line_number = line_number
			let prev_col_number = col_number - 1
			let prev_line = line
		endif
		let prev_char = prev_line[prev_col_number]

		" skip comments
		if synIDName =~? 'comment\|phpDocTags'
			let current_char = ''
		endif

		" break on the last char of the "and" and "or" operators
		if synIDName == 'phpOperator' && (current_char == 'r' || current_char == 'd')
			break
		endif

		" break on statements as "return" or "throws"
		if synIDName == 'phpStatement' || synIDName == 'phpException'
			break
		endif

		" if the current char should be considered
		if current_char != '' && parent_depth >= 0 && bracket_depth >= 0 && synIDName !~? 'comment\|string'
			" break if we are on a "naked" stop_char (operators, colon, openparent...)
			if index(stop_chars, current_char) != -1
				let do_break = 1
				" dont break if it does look like a "->"
				if (prev_char == '-' && current_char == '>') || (current_char == '-' && next_char == '>')
					let do_break = 0
				endif
				" dont break if it does look like a "::"
				if (prev_char == ':' && current_char == ':') || (current_char == ':' && next_char == ':')
					let do_break = 0
				endif

				if do_break
					break
				endif
			endif

			" save the coma position for later use if there's a "naked" , possibly separating a parameter and it is not in a parented part
			if first_coma_break_pos == -1 && current_char == ','
				let first_coma_break_pos = len(instruction)
			endif
		endif

		" count nested darenthesis and brackets so we can tell if we need to break on a ';' or not (think of for (;;) loops)
		if synIDName =~? 'phpBraceFunc\|phpParent\|Delimiter'
			if current_char == '('
				let parent_depth += 1
			elseif current_char == ')'
				let parent_depth -= 1

			elseif current_char == '['
				let bracket_depth += 1
			elseif current_char == ']'
				let bracket_depth -= 1
			endif
		endif

		" stop collecting chars if we see a function start { (think of first line in a function)
		if (current_char == '{' || current_char == '}') && synIDName =~? 'phpBraceFunc\|phpParent\|Delimiter'
			break
		endif

		" break if we are reached the php block start (<?php or <?)
		if [line_number, col_number] == phpbegin_end
			break
		endif

		let instruction = current_char.instruction

		" step a char or a line back if we are on the first column of the line already
		let col_number -= 1
		if col_number == -1
			let line_number -= 1
			let line = getline(line_number)
			let col_number = strlen(line)
		endif
	endwhile

	" strip leading whitespace
	let instruction = substitute(instruction, '^\s\+', '', '')

	" there were a "naked" coma in the instruction
	if first_coma_break_pos != -1
		if instruction !~? '^use' && instruction !~? '^class' " use ... statements and class declarations should not be broken up by comas
			let pos = (-1 * first_coma_break_pos) + 1
			let instruction = instruction[pos :]
		endif
	endif

	" HACK to remove one line conditionals from code like "if ($foo) echo 'bar'"
	" what the plugin really need is a proper php tokenizer
	if instruction =~? '\c^\(if\|while\|foreach\|for\)\s*('
		" clear everything up until the first (
		let instruction = substitute(instruction, '^\(if\|while\|foreach\|for\)\s*(\s*', '', '')

		" lets iterate through the instruction until we can find the pair for the opening (
		let i = 0
		let depth = 1
		while i < len(instruction)
			if instruction[i] == '('
				let depth += 1
			endif
			if instruction[i] == ')'
				let depth -= 1
			endif
			if depth == 0
				break
			end
			let i += 1
		endwhile
		let instruction = instruction[i + 1 : len(instruction)]
	endif

	" trim whitespace from the ends
	let instruction = substitute(instruction, '\v^(^\s+)|(\s+)$', '', 'g')

	return instruction
endfunction " }}}

function! phpcomplete#GetCallChainReturnType(classname_candidate, class_candidate_namespace, imports, methodstack) " {{{
	" Tries to get the classname and namespace for a chained method call like:
	"	$this->foo()->bar()->baz()->

	let classname_candidate = a:classname_candidate
	let class_candidate_namespace = a:class_candidate_namespace
	let methodstack = a:methodstack
	let unknown_result = ['', '']
	let prev_method_is_array = (methodstack[0] =~ '\v^[^([]+\[' ? 1 : 0)
	let classname_candidate_is_array = (classname_candidate =~ '\[\]$' ? 1 : 0)

	if prev_method_is_array
		if classname_candidate_is_array
			let classname_candidate = substitute(classname_candidate, '\[\]$', '', '')
		else
			return unknown_result
		endif
	endif

	if (len(methodstack) == 1)
		let [classname_candidate, class_candidate_namespace] = phpcomplete#ExpandClassName(classname_candidate, class_candidate_namespace, a:imports)
		return [classname_candidate, class_candidate_namespace]
	else
		call remove(methodstack, 0)
		let method_is_array = (methodstack[0] =~ '\v^[^[]+\[' ? 1 : 0)
		let method = matchstr(methodstack[0], '\v^\$*\zs[^[(]+\ze')

		let classlocation = phpcomplete#GetClassLocation(classname_candidate, class_candidate_namespace)

		if classlocation == 'VIMPHP_BUILTINOBJECT' && has_key(g:php_builtin_classes, tolower(classname_candidate))
			let class_info = g:php_builtin_classes[tolower(classname_candidate)]
			if has_key(class_info['methods'], method)
				return phpcomplete#GetCallChainReturnType(class_info['methods'][method].return_type, '\', a:imports, methodstack)
			endif
			if has_key(class_info['properties'], method)
				return phpcomplete#GetCallChainReturnType(class_info['properties'][method].type, '\', a:imports, methodstack)
			endif
			if has_key(class_info['static_methods'], method)
				return phpcomplete#GetCallChainReturnType(class_info['static_methods'][method].return_type, '\', a:imports, methodstack)
			endif
			if has_key(class_info['static_properties'], method)
				return phpcomplete#GetCallChainReturnType(class_info['static_properties'][method].type, '\', a:imports, methodstack)
			endif

			return unknown_result

		elseif classlocation != '' && filereadable(classlocation)
			" Read the next method from the stack and extract only the name

			let classcontents = phpcomplete#GetCachedClassContents(classlocation, classname_candidate)

			" Get Structured information of all classes and subclasses including namespace and includes
			" try to find the method's return type in docblock comment
			for classstructure in classcontents
				let docblock_target_pattern = 'function\s\+&\?'.method.'\>\|\(public\|private\|protected\|var\).\+\$'.method.'\>\|@property.\+\$'.method.'\>'
				let doc_str = phpcomplete#GetDocBlock(split(classstructure.content, '\n'), docblock_target_pattern)
				let return_type_hint = phpcomplete#GetFunctionReturnTypeHint(split(classstructure.content, '\n'), 'function\s\+&\?'.method.'\>')
				if doc_str != '' || return_type_hint != ''
					break
				endif
			endfor
			if doc_str != '' || return_type_hint != ''
				let docblock = phpcomplete#ParseDocBlock(doc_str)
				if has_key(docblock.return, 'type') || has_key(docblock.var, 'type') || len(docblock.properties) > 0 || return_type_hint != ''
					if return_type_hint == ''
						let type = has_key(docblock.return, 'type') ? docblock.return.type : has_key(docblock.var, 'type') ? docblock.var.type : ''

						if type == ''
							for property in docblock.properties
								if property.description =~? method
									let type = property.type
									break
								endif
							endfor
						endif
					else
						let type = return_type_hint
					end

					" there's a namespace in the type, threat the type as FQCN
					if type =~ '\\'
						let parts = split(substitute(type, '^\\', '', ''), '\')
						let class_candidate_namespace = join(parts[0:-2], '\')
						let classname_candidate = parts[-1]
						" check for renamed namespace in imports
						if has_key(classstructure.imports, class_candidate_namespace)
							let class_candidate_namespace = classstructure.imports[class_candidate_namespace].name
						endif
					else
						" no namespace in the type, threat it as a relative classname
						let returnclass = type
						if has_key(classstructure.imports, returnclass)
							if has_key(classstructure.imports[returnclass], 'namespace')
								let fullnamespace = classstructure.imports[returnclass].namespace
							else
								let fullnamespace = class_candidate_namespace
							endif
						else
							let fullnamespace = class_candidate_namespace
						endif
						" make @return self, static, $this the same way
						" (not exactly what php means by these)
						if returnclass == 'self' || returnclass == 'static' || returnclass == '$this' || returnclass == 'self[]' || returnclass == 'static[]' || returnclass == '$this[]'
							if returnclass =~ '\[\]$'
								let classname_candidate = a:classname_candidate.'[]'
							else
								let classname_candidate = a:classname_candidate
							endif
							let class_candidate_namespace = a:class_candidate_namespace
						else
							let [classname_candidate, class_candidate_namespace] = phpcomplete#ExpandClassName(returnclass, fullnamespace, a:imports)
						endif
					endif

					return phpcomplete#GetCallChainReturnType(classname_candidate, class_candidate_namespace, a:imports, methodstack)
				endif
			endif

			return unknown_result
		else
			return unknown_result
		endif
	endif
endfunction " }}}

function! phpcomplete#GetMethodStack(line) " {{{
	let methodstack = []
	let i = 0
	let end = len(a:line)

	let current_part = ''

	let parent_depth = 0
	let in_string = 0
	let string_start = ''

	let next_char = ''

	while i	< end
		let current_char = a:line[i]
		let next_char = i + 1 < end ? a:line[i + 1] : ''
		let prev_char = i >= 1 ? a:line[i - 1] : ''
		let prev_prev_char = i >= 2 ? a:line[i - 2] : ''

		if in_string == 0 && parent_depth == 0 && ((current_char == '-' && next_char == '>') || (current_char == ':' && next_char == ':'))
			call add(methodstack, current_part)
			let current_part = ''
			let i += 2
			continue
		endif

		" if it looks like a string
		if current_char == "'" || current_char == '"'
			" and it is not escaped
			if prev_char != '\' || (prev_char == '\' && prev_prev_char == '\')
				" and we are in a string already
				if in_string
					" and that string started with this char too
					if current_char == string_start
						" clear the string mark
						let in_string = 0
					endif
				else " ... and we are not in a string
					" set the string mark
					let in_string = 1
					let string_start = current_char
				endif
			endif
		endif

		if !in_string && a:line[i] == '('
			let parent_depth += 1
		endif
		if !in_string && a:line[i] == ')'
			let parent_depth -= 1
		endif

		let current_part .= current_char
		let i += 1
	endwhile

	" add the last remaining part, this can be an empty string and this is expected
	" the empty string represents the completion base (which happen to be an empty string)
	if current_part != ''
		call add(methodstack, current_part)
	endif

	return methodstack
endfunction
" }}}

function! phpcomplete#GetClassName(start_line, context, current_namespace, imports) " {{{
	" Get class name
	" Class name can be detected in few ways:
	" @var $myVar class
	" @var class $myVar
	" in the same line (php 5.4 (new Class)-> syntax)
	" line above
	" or line in tags file

	let class_name_pattern = '[a-zA-Z_\x7f-\xff\\][a-zA-Z_0-9\x7f-\xff\\]*'
	let function_name_pattern = '[a-zA-Z_\x7f-\xff][a-zA-Z_0-9\x7f-\xff]*'
	let function_invocation_pattern = '[a-zA-Z_\x7f-\xff\\][a-zA-Z_0-9\x7f-\xff\\]*('
	let variable_name_pattern = '\$[a-zA-Z_\x7f-\xff][a-zA-Z0-9_\x7f-\xff]*'

	let classname_candidate = ''
	let class_candidate_namespace = a:current_namespace
	let class_candidate_imports = a:imports
	let methodstack = phpcomplete#GetMethodStack(a:context)

	if a:context =~? '\$this->' || a:context =~? '\(self\|static\)::' || a:context =~? 'parent::'
		let i = 1
		while i < a:start_line
			let line = getline(a:start_line - i)

			" Don't complete self:: or $this if outside of a class
			" (assumes correct indenting)
			if line =~ '^}'
				return ''
			endif

			if line =~? '\v^\s*(abstract\s+|final\s+)*\s*class\s'
				let class_name = matchstr(line, '\cclass\s\+\zs'.class_name_pattern.'\ze')
				let extended_class = matchstr(line, '\cclass\s\+'.class_name_pattern.'\s\+extends\s\+\zs'.class_name_pattern.'\ze')

				let classname_candidate = a:context =~? 'parent::' ? extended_class : class_name
				if classname_candidate != ''
					let [classname_candidate, class_candidate_namespace] = phpcomplete#GetCallChainReturnType(classname_candidate, class_candidate_namespace, class_candidate_imports, methodstack)
					" return absolute classname, without leading \
					return (class_candidate_namespace == '\' || class_candidate_namespace == '') ? classname_candidate : class_candidate_namespace.'\'.classname_candidate
				endif
			endif

			let i += 1
		endwhile
	elseif a:context =~? '(\s*new\s\+'.class_name_pattern.'\s*)->'
		let classname_candidate = matchstr(a:context, '\cnew\s\+\zs'.class_name_pattern.'\ze')
		let [classname_candidate, class_candidate_namespace] = phpcomplete#GetCallChainReturnType(classname_candidate, class_candidate_namespace, class_candidate_imports, methodstack)
		" return absolute classname, without leading \
		return (class_candidate_namespace == '\' || class_candidate_namespace == '') ? classname_candidate : class_candidate_namespace.'\'.classname_candidate
	elseif get(methodstack, 0) =~# function_invocation_pattern
		let function_name = matchstr(methodstack[0], '^\s*\zs'.function_name_pattern)
		let function_file = phpcomplete#GetFunctionLocation(function_name, a:current_namespace)
		if function_file == ''
			let function_file = phpcomplete#GetFunctionLocation(function_name, '\')
		endif

		if function_file == 'VIMPHP_BUILTINFUNCTION'
			" built in function, grab the return type from the info string
			let return_type = matchstr(g:php_builtin_functions[function_name.'('], '\v\|\s+\zs.+$')
			let classname_candidate = return_type
			let class_candidate_namespace = '\'
		elseif function_file != '' && filereadable(function_file)
			let file_lines = readfile(function_file)
			let docblock_str = phpcomplete#GetDocBlock(file_lines, 'function\s*&\?\<'.function_name.'\>')
			let return_type_hint = phpcomplete#GetFunctionReturnTypeHint(file_lines, 'function\s*&\?'.function_name.'\>')
			let docblock = phpcomplete#ParseDocBlock(docblock_str)
			let type = has_key(docblock.return, 'type') ? docblock.return.type : return_type_hint
			if type != ''
				let classname_candidate = type
				let [class_candidate_namespace, function_imports] = phpcomplete#GetCurrentNameSpace(file_lines)
				" try to expand the classname of the returned type with the context got from the function's source file

				let [classname_candidate, class_candidate_namespace] = phpcomplete#ExpandClassName(classname_candidate, class_candidate_namespace, function_imports)
			endif
		endif
		if classname_candidate != ''
			let [classname_candidate, class_candidate_namespace] = phpcomplete#GetCallChainReturnType(classname_candidate, class_candidate_namespace, class_candidate_imports, methodstack)
			" return absolute classname, without leading \
			return (class_candidate_namespace == '\' || class_candidate_namespace == '') ? classname_candidate : class_candidate_namespace.'\'.classname_candidate
		endif
	else
		" extract the variable name from the context
		let object = methodstack[0]
		let object_is_array = (object =~ '\v^[^[]+\[' ? 1 : 0)
		let object = matchstr(object, variable_name_pattern)

		let function_boundary = phpcomplete#GetCurrentFunctionBoundaries()
		let search_end_line = max([1, function_boundary[0][0]])
		" -1 makes us ignore the current line (where the completion was invoked
		let lines = reverse(getline(search_end_line, a:start_line - 1))

		" check Constant lookup
		let constant_object = matchstr(a:context, '\zs'.class_name_pattern.'\ze::')
		if constant_object != ''
			let classname_candidate = constant_object
		endif

		if classname_candidate == ''
			" scan the file backwards from current line for explicit type declaration (@var $variable Classname)
			for line in lines
				" in file lookup for /* @var $foo Class */
				if line =~# '@var\s\+'.object.'\s\+'.class_name_pattern
					let classname_candidate = matchstr(line, '@var\s\+'.object.'\s\+\zs'.class_name_pattern.'\(\[\]\)\?')
					let [classname_candidate, class_candidate_namespace] = phpcomplete#ExpandClassName(classname_candidate, a:current_namespace, a:imports)
					break
				endif
				" in file lookup for /* @var Class $foo */
				if line =~# '@var\s\+'.class_name_pattern.'\s\+'.object
					let classname_candidate = matchstr(line, '@var\s\+\zs'.class_name_pattern.'\(\[\]\)\?\ze'.'\s\+'.object)
					let [classname_candidate, class_candidate_namespace] = phpcomplete#ExpandClassName(classname_candidate, a:current_namespace, a:imports)
					break
				endif
			endfor
		endif

		if classname_candidate != ''
			let [classname_candidate, class_candidate_namespace] = phpcomplete#GetCallChainReturnType(classname_candidate, class_candidate_namespace, class_candidate_imports, methodstack)
			" return absolute classname, without leading \
			return (class_candidate_namespace == '\' || class_candidate_namespace == '') ? classname_candidate : class_candidate_namespace.'\'.classname_candidate
		endif
		" scan the file backwards from the current line
		let i = 1
		for line in lines " {{{
			" do in-file lookup of $var = new Class
			if line =~# '^\s*'.object.'\s*=\s*new\s\+'.class_name_pattern && !object_is_array
				let classname_candidate = matchstr(line, object.'\c\s*=\s*new\s*\zs'.class_name_pattern.'\ze')
				let [classname_candidate, class_candidate_namespace] = phpcomplete#ExpandClassName(classname_candidate, a:current_namespace, a:imports)
				break
			endif

			" in-file lookup for Class::getInstance()
			if line =~# '^\s*'.object.'\s*=&\?\s*'.class_name_pattern.'\s*::\s*getInstance' && !object_is_array
				let classname_candidate = matchstr(line, object.'\s*=&\?\s*\zs'.class_name_pattern.'\ze\s*::\s*getInstance')
				let [classname_candidate, class_candidate_namespace] = phpcomplete#ExpandClassName(classname_candidate, a:current_namespace, a:imports)
				break
			endif

			" do in-file lookup for static method invocation of a built-in class, like: $d = DateTime::createFromFormat()
			if line =~# '^\s*'.object.'\s*=&\?\s*'.class_name_pattern.'\s*::\s*$\?[a-zA-Z_0-9\x7f-\xff]\+'
				let classname  = matchstr(line, '^\s*'.object.'\s*=&\?\s*\zs'.class_name_pattern.'\ze\s*::')
				if has_key(a:imports, classname) && a:imports[classname].kind == 'c'
					let classname = a:imports[classname].name
				endif
				if has_key(g:php_builtin_classes, tolower(classname))
					let sub_methodstack = phpcomplete#GetMethodStack(matchstr(line, '^\s*'.object.'\s*=&\?\s*\s\+\zs.*'))
					let [classname_candidate, class_candidate_namespace] = phpcomplete#GetCallChainReturnType(classname, '\', {}, sub_methodstack)
					return classname_candidate
				else
					" try to get the class name from the static method's docblock
					let [classname, namespace_for_class] = phpcomplete#ExpandClassName(classname, a:current_namespace, a:imports)
					let sub_methodstack = phpcomplete#GetMethodStack(matchstr(line, '^\s*'.object.'\s*=&\?\s*\s\+\zs.*'))
					let [classname_candidate, class_candidate_namespace] = phpcomplete#GetCallChainReturnType(
						\ classname,
						\ namespace_for_class,
						\ a:imports,
						\ sub_methodstack)

					return (class_candidate_namespace == '\' || class_candidate_namespace == '') ? classname_candidate : class_candidate_namespace.'\'.classname_candidate
				endif
			endif

			" function declaration line
			if line =~? 'function\(\s\+'.function_name_pattern.'\)\?\s*('
				let function_lines = join(reverse(copy(lines)), " ")
				" search for type hinted arguments
				if function_lines =~? 'function\(\s\+'.function_name_pattern.'\)\?\s*(.\{-}'.class_name_pattern.'\s\+'.object && !object_is_array
					let f_args = matchstr(function_lines, '\cfunction\(\s\+'.function_name_pattern.'\)\?\s*(\zs.\{-}\ze)')
					let args = split(f_args, '\s*\zs,\ze\s*')
					for arg in args
						if arg =~# object.'\(,\|$\)'
							let classname_candidate = matchstr(arg, '\s*\zs'.class_name_pattern.'\ze\s\+'.object)
							let [classname_candidate, class_candidate_namespace] = phpcomplete#ExpandClassName(classname_candidate, a:current_namespace, a:imports)
							break
						endif
					endfor
					if classname_candidate != ''
						break
					endif
				endif

				" search for docblock for the function
				let match_line = substitute(line, '\\', '\\\\', 'g')
				let sccontent = getline(0, a:start_line - i)
				let doc_str = phpcomplete#GetDocBlock(sccontent, match_line)
				if doc_str != ''
					let docblock = phpcomplete#ParseDocBlock(doc_str)
					for param in docblock.params
						if param.name =~? object
							let classname_candidate = matchstr(param.type, class_name_pattern.'\(\[\]\)\?')
							let [classname_candidate, class_candidate_namespace] = phpcomplete#ExpandClassName(classname_candidate, a:current_namespace, a:imports)
							break
						endif
					endfor
					if classname_candidate != ''
						break
					endif
				endif
			endif

			" assignment for the variable in question with a variable on the right hand side
			if line =~# '^\s*'.object.'\s*=&\?\s\+\(clone\)\?\s*'.variable_name_pattern

				" try to find the next non-comment or string ";" char
				let start_col = match(line, '^\s*'.object.'\C\s*=\zs&\?\s\+\(clone\)\?\s*'.variable_name_pattern)
				let filelines = reverse(copy(lines))
				let [pos, char] = s:getNextCharWithPos(filelines, [len(filelines) - i, start_col])
				let chars_read = 1
				let last_pos = pos
				" function_boundary == 0 if we are not in a function
				let real_lines_offset = len(function_boundary) == 1 ? 1 : function_boundary[0][0]
				" read while end of the file
				while char != 'EOF' && chars_read < 1000
					let last_pos = pos
					let [pos, char] = s:getNextCharWithPos(filelines, pos)
					let chars_read += 1
					" we got a candidate
					if char == ';'
						" pos values is relative to the function's lines,
						" line 0 need to be offsetted with the line number
						" where te function was started to get the line number
						" in real buffer terms
						let synIDName = synIDattr(synID(real_lines_offset + pos[0], pos[1] + 1, 0), 'name')
						" it's not a comment or string, end search
						if synIDName !~? 'comment\|string'
							break
						endif
					endif
				endwhile

				let prev_context = phpcomplete#GetCurrentInstruction(real_lines_offset + last_pos[0], last_pos[1], b:phpbegin)
				if prev_context == ''
					" cannot get previous context give up
					return
				endif
				let prev_class = phpcomplete#GetClassName(a:start_line - i, prev_context, a:current_namespace, a:imports)

				if stridx(prev_class, '\') != -1
					let classname_parts = split(prev_class, '\\\+')
					let classname_candidate = classname_parts[-1]
					let class_candidate_namespace = join(classname_parts[0:-2], '\')
				else
					let classname_candidate = prev_class
					let class_candidate_namespace = '\'
				endif
				break
			endif

			" assignment for the variable in question with a function on the right hand side
			if line =~# '^\s*'.object.'\s*=&\?\s*'.function_invocation_pattern
				" try to find the next non-comment or string ";" char
				let start_col = match(line, '\C^\s*'.object.'\s*=\zs&\?\s*'.function_invocation_pattern)
				let filelines = reverse(copy(lines))
				let [pos, char] = s:getNextCharWithPos(filelines, [len(filelines) - i, start_col])
				let chars_read = 1
				let last_pos = pos
				" function_boundary == 0 if we are not in a function
				let real_lines_offset = len(function_boundary) == 1 ? 1 : function_boundary[0][0]
				" read while end of the file
				while char != 'EOF' && chars_read < 1000
					let last_pos = pos
					let [pos, char] = s:getNextCharWithPos(filelines, pos)
					let chars_read += 1
					" we got a candidate
					if char == ';'
						" pos values is relative to the function's lines,
						" line 0 need to be offsetted with the line number
						" where te function was started to get the line number
						" in real buffer terms
						let synIDName = synIDattr(synID(real_lines_offset + pos[0], pos[1] + 1, 0), 'name')
						" it's not a comment or string, end search
						if synIDName !~? 'comment\|string'
							break
						endif
					endif
				endwhile

				let prev_context = phpcomplete#GetCurrentInstruction(real_lines_offset + last_pos[0], last_pos[1], b:phpbegin)
				if prev_context == ''
					" cannot get previous context give up
					return
				endif

				let function_name = matchstr(prev_context, '^'.function_invocation_pattern.'\ze')
				let function_name = matchstr(function_name, '^\zs.\+\ze\s*($') " strip the trailing (
				let [function_name, function_namespace] = phpcomplete#ExpandClassName(function_name, a:current_namespace, a:imports)

				let function_file = phpcomplete#GetFunctionLocation(function_name, function_namespace)
				if function_file == ''
					let function_file = phpcomplete#GetFunctionLocation(function_name, '\')
				endif

				if function_file == 'VIMPHP_BUILTINFUNCTION'
					" built in function, grab the return type from the info string
					let return_type = matchstr(g:php_builtin_functions[function_name.'('], '\v\|\s+\zs.+$')
					let classname_candidate = return_type
					let class_candidate_namespace = '\'
					break
				elseif function_file != '' && filereadable(function_file)
					let file_lines = readfile(function_file)
					let docblock_str = phpcomplete#GetDocBlock(file_lines, 'function\s*&\?\<'.function_name.'\>')
					let return_type_hint = phpcomplete#GetFunctionReturnTypeHint(file_lines, 'function\s*&\?'.function_name.'\>')
					let docblock = phpcomplete#ParseDocBlock(docblock_str)
					let type = has_key(docblock.return, 'type') ? docblock.return.type : return_type_hint
					if type != ''
						let classname_candidate = type
						let [class_candidate_namespace, function_imports] = phpcomplete#GetCurrentNameSpace(file_lines)
						" try to expand the classname of the returned type with the context got from the function's source file
						let [classname_candidate, class_candidate_namespace] = phpcomplete#ExpandClassName(classname_candidate, class_candidate_namespace, function_imports)
						break
					endif
				endif
			endif

			" foreach with the variable in question
			if line =~? 'foreach\s*(.\{-}\s\+'.object.'\s*)'
				let sub_context = matchstr(line, 'foreach\s*(\s*\zs.\{-}\ze\s\+as')
				let prev_class = phpcomplete#GetClassName(a:start_line - i, sub_context, a:current_namespace, a:imports)

				" the iterated expression should return an array type
				if prev_class =~ '\[\]$'
					let prev_class = matchstr(prev_class, '\v^[^[]+')
				else
					return
				endif

				if stridx(prev_class, '\') != -1
					let classname_parts = split(prev_class, '\\\+')
					let classname_candidate = classname_parts[-1]
					let class_candidate_namespace = join(classname_parts[0:-2], '\')
				else
					let classname_candidate = prev_class
					let class_candidate_namespace = '\'
				endif
				break
			endif

			" catch clause with the variable in question
			if line =~? 'catch\s*(\zs'.class_name_pattern.'\ze\s\+'.object
				let classname = matchstr(line, 'catch\s*(\zs'.class_name_pattern.'\ze\s\+'.object)
				if stridx(classname, '\') != -1
					let classname_parts = split(classname, '\\\+')
					let classname_candidate = classname_parts[-1]
					let class_candidate_namespace = join(classname_parts[0:-2], '\')
				else
					let classname_candidate = classname
					let class_candidate_namespace = '\'
				endif
				break
			endif

			let i += 1
		endfor " }}}

		if classname_candidate != ''
			let [classname_candidate, class_candidate_namespace] = phpcomplete#GetCallChainReturnType(classname_candidate, class_candidate_namespace, class_candidate_imports, methodstack)
			" return absolute classname, without leading \
			return (class_candidate_namespace == '\' || class_candidate_namespace == '') ? classname_candidate : class_candidate_namespace.'\'.classname_candidate
		endif

		" OK, first way failed, now check tags file(s)
		" This method is useless when local variables are not indexed by ctags and
		" pretty inaccurate even if it is
		if g:phpcomplete_search_tags_for_variables
			let tags = phpcomplete#GetTaglist('^'.substitute(object, '^\$', '', ''))
			if len(tags) == 0
				return
			else
				for tag in tags
					if tag.kind ==? 'v' && tag.cmd =~? '=\s*new\s\+\zs'.class_name_pattern.'\ze'
						let classname = matchstr(tag.cmd, '=\s*new\s\+\zs'.class_name_pattern.'\ze')
						" unescape the classname, it would have "\" doubled since it is an ex command
						let classname = substitute(classname, '\\\(\_.\)', '\1', 'g')
						return classname
					endif
				endfor
			endif
		endif
	endif
endfunction
" }}}

function! phpcomplete#GetClassLocation(classname, namespace) " {{{
	" Check classname may be name of built in object
	if has_key(g:php_builtin_classes, tolower(a:classname)) && (a:namespace == '' || a:namespace == '\')
		return 'VIMPHP_BUILTINOBJECT'
	endif
	if has_key(g:php_builtin_interfaces, tolower(a:classname)) && (a:namespace == '' || a:namespace == '\')
		return 'VIMPHP_BUILTINOBJECT'
	endif

	if a:namespace == '' || a:namespace == '\'
		let search_namespace = '\'
	else
		let search_namespace = tolower(a:namespace)
	endif
	let [current_namespace, imports] = phpcomplete#GetCurrentNameSpace(getline(0, line('.')))

	" do in-file lookup for class definition
	let i = 1
	while i < line('.')
		let line = getline(line('.')-i)
		if line =~? '^\s*\(abstract\s\+\|final\s\+\)*\s*\(class\|interface\|trait\)\s*'.a:classname.'\(\s\+\|$\|{\)' && tolower(current_namespace) == search_namespace
			return expand('%:p')
		else
			let i += 1
			continue
		endif
	endwhile

	" Get class location from tags
	let no_namespace_candidate = ''
	let tags = phpcomplete#GetTaglist('^'.a:classname.'$')
	for tag in tags
		" We'll allow interfaces and traits to be handled classes since you
		" can't have colliding names with different kinds anyway
		if tag.kind == 'c' || tag.kind == 'i' || tag.kind == 't'
			if !has_key(tag, 'namespace')
				let no_namespace_candidate = tag.filename
			else
				if search_namespace == tolower(tag.namespace)
					return tag.filename
				endif
			endif
		endif
	endfor
	if no_namespace_candidate != ''
		return no_namespace_candidate
	endif

	return ''
endfunction
" }}}

function! phpcomplete#GetFunctionLocation(function_name, namespace) " {{{
	" builtin functions doesn't need explicit \ in front of them even in namespaces,
	" aliased built-in function names are not handled
	if has_key(g:php_builtin_functions, a:function_name.'(')
		return 'VIMPHP_BUILTINFUNCTION'
	endif


	" do in-file lookup for function definition
	let i = 1
	let buffer_lines = getline(1, line('$'))
	for line in buffer_lines
		if line =~? '^\s*function\s\+&\?'.a:function_name.'\s*('
			return expand('%:p')
		endif
	endfor


	if a:namespace == '' || a:namespace == '\'
		let search_namespace = '\'
	else
		let search_namespace = tolower(a:namespace)
	endif
	let no_namespace_candidate = ''
	let tags = phpcomplete#GetTaglist('\c^'.a:function_name.'$')

	for tag in tags
		if tag.kind == 'f'
			if !has_key(tag, 'namespace')
				let no_namespace_candidate = tag.filename
			else
				if search_namespace == tolower(tag.namespace)
					return tag.filename
				endif
			endif
		endif
	endfor
	if no_namespace_candidate != ''
		return no_namespace_candidate
	endif

	return ''
endfunction
" }}}

function! phpcomplete#GetCachedClassContents(classlocation, class_name) " {{{
	let full_file_path = fnamemodify(a:classlocation, ':p')
	let cache_key = full_file_path.'#'.a:class_name.'#'.getftime(full_file_path)

	" try to read from the cache first
	if has_key(s:cache_classstructures, cache_key)
		let classcontents = s:cache_classstructures[cache_key]
		" cached class contents can contain content from multiple files (superclasses) so we have to
		" validate cached result's validness by the filemtimes used to create the cached value
		let valid = 1
		for classstructure in classcontents
			if getftime(classstructure.file) != classstructure.mtime
				let valid = 0
				" we could break here, but the time required for checking probably worth
				" the memory we can free by checking every file in the cached hierarchy
				call phpcomplete#ClearCachedClassContents(classstructure.file)
			endif
		endfor

		if valid
			" cache hit, we found an entry for this file + class pair and every
			" file in the response is also valid
			return classcontents
		else
			" clear the outdated cached value from the cache store
			call remove(s:cache_classstructures, cache_key)
			call phpcomplete#ClearCachedClassContents(full_file_path)

			" fall through for the read from files path
		endif
	else
		call phpcomplete#ClearCachedClassContents(full_file_path)
	endif

	" cache miss, fetch the content from the files itself
	let classfile = readfile(a:classlocation)
	let classcontents = phpcomplete#GetClassContentsStructure(full_file_path, classfile, a:class_name)
	let s:cache_classstructures[cache_key] = classcontents

	return classcontents
endfunction " }}}

function! phpcomplete#ClearCachedClassContents(full_file_path) " {{{
	for [cache_key, cached_value] in items(s:cache_classstructures)
		if stridx(cache_key, a:full_file_path.'#') == 0
			call remove(s:cache_classstructures, cache_key)
		endif
	endfor
endfunction " }}}

function! phpcomplete#GetClassContentsStructure(file_path, file_lines, class_name) " {{{
	" returns dictionary containing content, namespace and imports for the class and all parent classes.
	" Example:
	" [
	"	{
	"		class: 'foo',
	"		content: '... class foo extends bar ... ',
	"		namespace: 'NS\Foo',
	"		imports : { ... },
	"		file: '/foo.php',
	"		mtime: 42,
	"	},
	"	{
	"		class: 'bar',
	"		content: '... class bar extends baz ... ',
	"		namespace: 'NS\Bar',
	"		imports : { ... }
	"		file: '/bar.php',
	"		mtime: 42,
	"	},
	"	...
	" ]
	"
	let full_file_path = fnamemodify(a:file_path, ':p')
	let class_name_pattern = '[a-zA-Z_\x7f-\xff\\][a-zA-Z_0-9\x7f-\xff\\]*'
	let cfile = join(a:file_lines, "\n")
	let result = []
	" We use new buffer and (later) normal! because
	" this is the most efficient way. The other way
	" is to go through the looong string looking for
	" matching {}

	" remember the window we started at
	let phpcomplete_original_window = winnr()

	silent! below 1new
	silent! 0put =cfile
	call search('\c\(class\|interface\|trait\)\_s\+'.a:class_name.'\(\>\|$\)')
	let cfline = line('.')
	call search('{')
	let endline = line('.')

	let content = join(getline(cfline, endline), "\n")
	" Catch extends
	if content =~? 'extends'
		let extends_string = matchstr(content, '\(class\|interface\)\_s\+'.a:class_name.'\_.\+extends\_s\+\zs\('.class_name_pattern.'\(,\|\_s\)*\)\+\ze\(extends\|{\)')
		let extended_classes = map(split(extends_string, '\(,\|\_s\)\+'), 'substitute(v:val, "\\_s\\+", "", "g")')
	else
		let extended_classes = ''
	endif

	" Catch implements
	if content =~? 'implements'
		let implements_string = matchstr(content, 'class\_s\+'.a:class_name.'\_.\+implements\_s\+\zs\('.class_name_pattern.'\(,\|\_s\)*\)\+\ze')
		let implemented_interfaces = map(split(implements_string, '\(,\|\_s\)\+'), 'substitute(v:val, "\\_s\\+", "", "g")')
	else
		let implemented_interfaces = []
	endif
	call searchpair('{', '', '}', 'W')
	let class_closing_bracket_line = line('.')

	" Include class docblock
	let doc_line = cfline - 1
	if getline(doc_line) =~? '^\s*\*/'
		while doc_line != 0
			if getline(doc_line) =~? '^\s*/\*\*'
				let cfline = doc_line
				break
			endif
			let doc_line -= 1
		endwhile
	endif

	let classcontent = join(getline(cfline, class_closing_bracket_line), "\n")

	let used_traits = []
	" move back to the line next to the class's definition
	call cursor(endline + 1, 1)
	let keep_searching = 1
	while keep_searching != 0
		" try to grab "use..." keywords
		let [lnum, col] = searchpos('\c^\s\+use\s\+'.class_name_pattern, 'cW', class_closing_bracket_line)
		let syn_name = synIDattr(synID(lnum, col, 0), "name")
		if syn_name =~? 'string\|comment'
			call cursor(lnum + 1, 1)
			continue
		endif

		let trait_line = getline(lnum)
		if trait_line !~? ';'
			" try to find the next line containing ';'
			let l = lnum
			let search_line = trait_line

			" add lines from the file until theres no ';' in them
			while search_line !~? ';' && l > 0
				" file lines are reversed so we need to go backwards
				let l += 1
				let search_line = getline(l)
				let trait_line .= ' '.substitute(search_line, '\(^\s\+\|\s\+$\)', '', 'g')
			endwhile
		endif
		let use_expression = matchstr(trait_line, '^\s*use\s\+\zs.\{-}\ze;')
		let use_parts = map(split(use_expression, '\s*,\s*'), 'substitute(v:val, "\\s+", " ", "g")')
		let used_traits += map(use_parts, 'substitute(v:val, "\\s", "", "g")')
		call cursor(lnum + 1, 1)

		if [lnum, col] == [0, 0]
			let keep_searching = 0
		endif
	endwhile

	silent! bw! %

	let [current_namespace, imports] = phpcomplete#GetCurrentNameSpace(a:file_lines[0:cfline])
	" go back to original window
	exe phpcomplete_original_window.'wincmd w'
	call add(result, {
				\ 'class': a:class_name,
				\ 'content': classcontent,
				\ 'namespace': current_namespace,
				\ 'imports': imports,
				\ 'file': full_file_path,
				\ 'mtime': getftime(full_file_path),
				\ })

	let all_extends = used_traits
	if len(extended_classes) > 0
		call extend(all_extends, extended_classes)
	endif
	if len(implemented_interfaces) > 0
		call extend(all_extends, implemented_interfaces)
	endif
	if len(all_extends) > 0
		for class in all_extends
			let [class, namespace] = phpcomplete#ExpandClassName(class, current_namespace, imports)
			if namespace == ''
				let namespace = '\'
			endif
			let classlocation = phpcomplete#GetClassLocation(class, namespace)
			if classlocation == "VIMPHP_BUILTINOBJECT"
				if has_key(g:php_builtin_classes, tolower(class))
					let result += [phpcomplete#GenerateBuiltinClassStub('class', g:php_builtin_classes[tolower(class)])]
				endif
				if has_key(g:php_builtin_interfaces, tolower(class))
					let result += [phpcomplete#GenerateBuiltinClassStub('interface', g:php_builtin_interfaces[tolower(class)])]
				endif
			elseif classlocation != '' && filereadable(classlocation)
				let full_file_path = fnamemodify(classlocation, ':p')
				let result += phpcomplete#GetClassContentsStructure(full_file_path, readfile(full_file_path), class)
			elseif tolower(current_namespace) == tolower(namespace) && match(join(a:file_lines, "\n"), '\c\(class\|interface\|trait\)\_s\+'.class.'\(\>\|$\)') != -1
				" try to find the declaration in the same file.
				let result += phpcomplete#GetClassContentsStructure(full_file_path, a:file_lines, class)
			endif
		endfor
	endif

	return result
endfunction
" }}}

function! phpcomplete#GetClassContents(classlocation, class_name) " {{{
	let classcontents = phpcomplete#GetCachedClassContents(a:classlocation, a:class_name)
	let result = []
	for classstructure in classcontents
		call add(result, classstructure.content)
	endfor
	return join(result, "\n")
endfunction
" }}}

function! phpcomplete#GenerateBuiltinClassStub(type, class_info) " {{{
	let re = a:type.' '.a:class_info['name']." {"
	if has_key(a:class_info, 'constants')
		for [name, initializer] in items(a:class_info.constants)
			let re .= "\n\tconst ".name." = ".initializer.";"
		endfor
	endif
	if has_key(a:class_info, 'properties')
		for [name, info] in items(a:class_info.properties)
			let re .= "\n\t// @var $".name." ".info.type
			let re .= "\n\tpublic $".name.";"
		endfor
	endif
	if has_key(a:class_info, 'static_properties')
		for [name, info] in items(a:class_info.static_properties)
			let re .= "\n\t// @var ".name." ".info.type
			let re .= "\n\tpublic static ".name." = ".info.initializer.";"
		endfor
	endif
	if has_key(a:class_info, 'methods')
		for [name, info] in items(a:class_info.methods)
			if name =~ '^__'
				continue
			endif
			let re .= "\n\t/**"
			let re .= "\n\t * ".name
			let re .= "\n\t *"
			let re .= "\n\t * @return ".info.return_type
			let re .= "\n\t */"
			let re .= "\n\tpublic function ".name."(".info.signature."){"
			let re .= "\n\t}"
		endfor
	endif
	if has_key(a:class_info, 'static_methods')
		for [name, info] in items(a:class_info.static_methods)
			let re .= "\n\t/**"
			let re .= "\n\t * ".name
			let re .= "\n\t *"
			let re .= "\n\t * @return ".info.return_type
			let re .= "\n\t */"
			let re .= "\n\tpublic static function ".name."(".info.signature."){"
			let re .= "\n\t}"
		endfor
	endif
	let re .= "\n}"

	return { a:type : a:class_info['name'],
				\ 'content': re,
				\ 'namespace': '',
				\ 'imports': {},
				\ 'file': 'VIMPHP_BUILTINOBJECT',
				\ 'mtime': 0,
				\ }
endfunction " }}}

function! phpcomplete#GetDocBlock(sccontent, search) " {{{
	let i = 0
	let l = 0
	let comment_start = -1
	let comment_end = -1
	let sccontent_len = len(a:sccontent)

	while (i < sccontent_len)
		let line = a:sccontent[i]
		" search for a function declaration
		if line =~? a:search
			if line =~? '@property'
				let doc_line = i
				while doc_line != sccontent_len - 1
					if a:sccontent[doc_line] =~? '^\s*\*/'
						let l = doc_line
						break
					endif
					let doc_line += 1
				endwhile
			else
				let l = i - 1
			endif
			" start backward search for the comment block
			while l != 0
				let line = a:sccontent[l]
				" if it's a one line docblock like comment and we can just return it right away
				if line =~? '^\s*\/\*\*.\+\*\/\s*$'
					return substitute(line, '\v^\s*(\/\*\*\s*)|(\s*\*\/)\s*$', '', 'g')
				"... or if comment end found save line position and end search
				elseif line =~? '^\s*\*/'
					let comment_end = l
					break
				" ... or the line doesn't blank (only whitespace or nothing) end search
				elseif line !~? '^\s*$'
					break
				endif
				let l -= 1
			endwhile
			" no comment found
			if comment_end == -1
				return ''
			end

			while l >= 0
				let line = a:sccontent[l]
				if line =~? '^\s*/\*\*'
					let comment_start = l
					break
				endif
				let l -= 1
			endwhile

			" no docblock comment start found
			if comment_start == -1
				return ''
			end

			let comment_start += 1 " we dont need the /**
			let comment_end   -= 1 " we dont need the */

			" remove leading whitespace and '*'s
			let docblock = join(map(copy(a:sccontent[comment_start :comment_end]), 'substitute(v:val, "^\\s*\\*\\s*", "", "")'), "\n")
			return docblock
		endif
		let i += 1
	endwhile
	return ''
endfunction
" }}}

function! phpcomplete#ParseDocBlock(docblock) " {{{
	let res = {
		\ 'description': '',
		\ 'params': [],
		\ 'return': {},
		\ 'throws': [],
		\ 'var': {},
		\ 'properties': [],
		\ }

	let res.description = substitute(matchstr(a:docblock, '\zs\_.\{-}\ze\(@type\|@var\|@param\|@return\|$\)'), '\(^\_s*\|\_s*$\)', '', 'g')
	let docblock_lines = split(a:docblock, "\n")

	let param_lines = filter(copy(docblock_lines), 'v:val =~? "^@param"')
	for param_line in param_lines
		let parts = matchlist(param_line, '@param\s\+\(\S\+\)\s\+\(\S\+\)\s*\(.*\)')
		if len(parts) > 0
			call add(res.params, {
						\ 'line': parts[0],
						\ 'type': phpcomplete#GetTypeFromDocBlockParam(get(parts, 1, '')),
						\ 'name': get(parts, 2, ''),
						\ 'description': get(parts, 3, '')})
		endif
	endfor

	let return_line = filter(copy(docblock_lines), 'v:val =~? "^@return"')
	if len(return_line) > 0
		let return_parts = matchlist(return_line[0], '@return\s\+\(\S\+\)\s*\(.*\)')
		let res['return'] = {
					\ 'line': return_parts[0],
					\ 'type': phpcomplete#GetTypeFromDocBlockParam(get(return_parts, 1, '')),
					\ 'description': get(return_parts, 2, '')}
	endif

	let exception_lines = filter(copy(docblock_lines), 'v:val =~? "^\\(@throws\\|@exception\\)"')
	for exception_line in exception_lines
		let parts = matchlist(exception_line, '^\(@throws\|@exception\)\s\+\(\S\+\)\s*\(.*\)')
		if len(parts) > 0
			call add(res.throws, {
						\ 'line': parts[0],
						\ 'type': phpcomplete#GetTypeFromDocBlockParam(get(parts, 2, '')),
						\ 'description': get(parts, 3, '')})
		endif
	endfor

	let var_line = filter(copy(docblock_lines), 'v:val =~? "^\\(@var\\|@type\\)"')
	if len(var_line) > 0
		let var_parts = matchlist(var_line[0], '\(@var\|@type\)\s\+\(\S\+\)\s*\(.*\)')
		let res['var'] = {
					\ 'line': var_parts[0],
					\ 'type': phpcomplete#GetTypeFromDocBlockParam(get(var_parts, 2, '')),
					\ 'description': get(var_parts, 3, '')}
	endif

	let property_lines = filter(copy(docblock_lines), 'v:val =~? "^@property"')
	for property_line in property_lines
		let parts = matchlist(property_line, '\(@property\)\s\+\(\S\+\)\s*\(.*\)')
		if len(parts) > 0
			call add(res.properties, {
						\ 'line': parts[0],
						\ 'type': phpcomplete#GetTypeFromDocBlockParam(get(parts, 2, '')),
						\ 'description': get(parts, 3, '')})
		endif
	endfor

	return res
endfunction
" }}}

function! phpcomplete#GetFunctionReturnTypeHint(sccontent, search)
	let i = 0
	let l = 0
	let function_line_start = -1
	let function_line_end = -1
	let sccontent_len = len(a:sccontent)
	let return_type = ''

	while (i < sccontent_len)
		let line = a:sccontent[i]
		" search for a function declaration
		if line =~? a:search
			let l = i
			let function_line_start = i
			" now search for the first { where the function body starts
			while l < sccontent_len
				let line = a:sccontent[l]
				if line =~? '\V{'
					let function_line_end = l
					break
				endif
				let l += 1
			endwhile
			break
		endif
		let i += 1
	endwhile

	" now grab the lines that holds the function declaration line
	if function_line_start != -1 && function_line_end != -1
		let function_line = join(a:sccontent[function_line_start :function_line_end], " ")
		let class_name_pattern = '[a-zA-Z_\x7f-\xff\\][a-zA-Z_0-9\x7f-\xff\\]*'
		let return_type = matchstr(function_line, '\c\s*:\s*\zs'.class_name_pattern.'\ze\s*{')
	endif
	return return_type

endfunction

function! phpcomplete#GetTypeFromDocBlockParam(docblock_type) " {{{
	if a:docblock_type !~ '|'
		return a:docblock_type
	endif

	let primitive_types = [
				\ 'string', 'float', 'double', 'int',
				\ 'scalar', 'array', 'bool', 'void', 'mixed',
				\ 'null', 'callable', 'resource', 'object']

	" add array of primitives to the list too, like string[]
	let primitive_types += map(copy(primitive_types), 'v:val."[]"')
	let types = split(a:docblock_type, '|')
	for type in types
		if index(primitive_types, type) == -1
			return type
		endif
	endfor

	" only primitive types found, return the first one
	return types[0]

endfunction
" }}}

function! phpcomplete#FormatDocBlock(info) " {{{
	let res = ''
	if len(a:info.description)
		let res .= "Description:\n".join(map(split(a:info['description'], "\n"), '"\t".v:val'), "\n")."\n"
	endif

	if len(a:info.params)
		let res .= "\nArguments:\n"
		for arginfo in a:info.params
			let res .= "\t".arginfo['name'].' '.arginfo['type']
			if len(arginfo.description) > 0
				let res .= ': '.arginfo['description']
			endif
			let res .= "\n"
		endfor
	endif

	if has_key(a:info.return, 'type')
		let res .= "\nReturn:\n\t".a:info['return']['type']
		if len(a:info.return.description) > 0
			let res .= ": ".a:info['return']['description']
		endif
		let res .= "\n"
	endif

	if len(a:info.throws)
		let res .= "\nThrows:\n"
		for excinfo in a:info.throws
			let res .= "\t".excinfo['type']
			if len(excinfo['description']) > 0
				let res .= ": ".excinfo['description']
			endif
			let res .= "\n"
		endfor
	endif

	if has_key(a:info.var, 'type')
		let res .= "Type:\n\t".a:info['var']['type']."\n"
		if len(a:info['var']['description']) > 0
			let res .= ': '.a:info['var']['description']
		endif
	endif

	return res
endfunction!
" }}}

function! phpcomplete#GetCurrentNameSpace(file_lines) " {{{
	let original_window = winnr()

	silent! below 1new
	silent! 0put =a:file_lines
	normal! G

	" clear out classes, functions and other blocks
	while 1
		let block_start_pos = searchpos('\c\(class\|trait\|function\|interface\)\s\+\_.\{-}\zs{', 'Web')
		if block_start_pos == [0, 0]
			break
		endif
		let block_end_pos = searchpairpos('{', '', '}\|\%$', 'W', 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string\\|comment"')

		if block_end_pos != [0, 0]
			" end of the block found, just delete it
			silent! exec block_start_pos[0].','.block_end_pos[0].'d _'
		else
			" block pair not found, use block start as beginning and the end
			" of the buffer instead
			silent! exec block_start_pos[0].',$d _'
		endif
	endwhile
	normal! G

	" grab the remains
	let file_lines = reverse(getline(1, line('.') - 1))

	silent! bw! %
	exe original_window.'wincmd w'

	let namespace_name_pattern = '[a-zA-Z_\x7f-\xff\\][a-zA-Z_0-9\x7f-\xff\\]*'
	let i = 0
	let file_length = len(file_lines)
	let imports = {}
	let current_namespace = '\'

	while i < file_length
		let line = file_lines[i]

		if line =~? '^\(<?php\)\?\s*namespace\s*'.namespace_name_pattern
			let current_namespace = matchstr(line, '\c^\(<?php\)\?\s*namespace\s*\zs'.namespace_name_pattern.'\ze')
			break
		endif

		if line =~? '^\s*use\>'
			if line =~? ';'
				let use_line = line
			else
				" try to find the next line containing ';'
				let l = i
				let search_line = line
				let use_line = line

				" add lines from the file until there's no ';' in them
				while search_line !~? ';' && l > 0
					" file lines are reversed so we need to go backwards
					let l -= 1
					let search_line = file_lines[l]
					let use_line .= ' '.substitute(search_line, '\(^\s\+\|\s\+$\)', '', 'g')
				endwhile
			endif
			let use_expression = matchstr(use_line, '^\c\s*use\s\+\zs.\{-}\ze;')
			let use_parts = map(split(use_expression, '\s*,\s*'), 'substitute(v:val, "\\s+", " ", "g")')
			for part in use_parts
				if part =~? '\s\+as\s\+'
					let [object, name] = split(part, '\s\+as\s\+\c')
					let object = substitute(object, '^\\', '', '')
					let name   = substitute(name, '^\\', '', '')
				else
					let object = part
					let name = part
					let object = substitute(object, '^\\', '', '')
					let name   = substitute(name, '^\\', '', '')
					if name =~? '\\'
						let	name = matchstr(name, '\\\zs[^\\]\+\ze$')
					endif
				endif

				" leading slash is not required use imports are always absolute
				let imports[name] = {'name': object, 'kind': ''}
			endfor

			" find kind flags from tags or built in methods for the objects we extracted
			" they can be either classes, interfaces or namespaces, no other thing is importable in php
			for [key, import] in items(imports)
				" if there's a \ in the name we have it's definitely not a built in thing, look for tags
				if import.name =~ '\\'
					let patched_ctags_detected = 0
					let [classname, namespace_for_classes] = phpcomplete#ExpandClassName(import.name, '\', {})
					let namespace_name_candidate = substitute(import.name, '\\', '\\\\', 'g')
					" can be a namespace name as is, or can be a tagname at the end with a namespace
					let tags = phpcomplete#GetTaglist('^\('.namespace_name_candidate.'\|'.classname.'\)$')
					if len(tags) > 0
						for tag in tags
							" if there's a namespace with the name of the import
							if tag.kind == 'n' && tag.name == import.name
								call extend(import, tag)
								let import['builtin'] = 0
								let patched_ctags_detected = 1
								break
							endif
							" if the name matches with the extracted classname and namespace
							if (tag.kind == 'c' || tag.kind == 'i' || tag.kind == 't') && tag.name == classname
								if has_key(tag, 'namespace')
									let patched_ctags_detected = 1
									if tag.namespace == namespace_for_classes
										call extend(import, tag)
										let import['builtin'] = 0
										break
									endif
								elseif !exists('no_namespace_candidate')
									" save the first namespacless match to be used if no better
									" candidate found later on
									let tag.namespace = namespace_for_classes
									let no_namespace_candidate = tag
								endif
							endif
						endfor
						" there were a namespacless class name match, if we think that the
						" tags are not generated with patched ctags we will take it as a match
						if exists('no_namespace_candidate') && !patched_ctags_detected
							call extend(import, no_namespace_candidate)
							let import['builtin'] = 0
						endif
					else
						" if no tags are found, extract the namespace from the name
						let ns = matchstr(import.name, '\c\zs[a-zA-Z0-9\\]\+\ze\\' . name)
						if len(ns) > 0
							let import['name'] = name
							let import['namespace'] = ns
							let import['builtin'] = 0
						endif
					endif
				else
					" if no \ in the name, it can be a built in class
					if has_key(g:php_builtin_classnames, tolower(import.name))
						let import['kind'] = 'c'
						let import['builtin'] = 1
					elseif has_key(g:php_builtin_interfacenames, tolower(import.name))
						let import['kind'] = 'i'
						let import['builtin'] = 1
					else
						" or can be a tag with exactly matching name
						let tags = phpcomplete#GetTaglist('^'.import['name'].'$')
						for tag in tags
							" search for the first matching namespace, class, interface with no namespace
							if !has_key(tag, 'namespace') && (tag.kind == 'n' || tag.kind == 'c' || tag.kind == 'i' || tag.kind == 't')
								call extend(import, tag)
								let import['builtin'] = 0
								break
							endif
						endfor
					endif
				endif
				if exists('no_namespace_candidate')
					unlet no_namespace_candidate
				endif
			endfor
		endif
		let i += 1
	endwhile
	let sorted_imports = {}
	for name in sort(keys(imports))
		let sorted_imports[name] = imports[name]
	endfor
	return [current_namespace, sorted_imports]
endfunction
" }}}

function! phpcomplete#GetCurrentFunctionBoundaries() " {{{
	let old_cursor_pos = [line('.'), col('.')]
	let current_line_no = old_cursor_pos[0]
	let function_pattern = '\c\(.*\%#\)\@!\_^\s*\zs\(abstract\s\+\|final\s\+\|private\s\+\|protected\s\+\|public\s\+\|static\s\+\)*function\_.\{-}(\_.\{-})\_.\{-}{'

	let func_start_pos = searchpos(function_pattern, 'Wbc')
	if func_start_pos == [0, 0]
		call cursor(old_cursor_pos[0], old_cursor_pos[1])
		return 0
	endif

	" get the line where the function declaration actually started
	call search('\cfunction\_.\{-}(\_.\{-})\_.\{-}{', 'Wce')

	" get the position of the function block's closing "}"
	let func_end_pos = searchpairpos('{', '', '}', 'W')
	if func_end_pos == [0, 0]
		" there is a function start but no end found, assume that we are in a
		" function but the user did not typed the closing "}" yet and the
		" function runs to the end of the file
		let func_end_pos = [line('$'), len(getline(line('$')))]
	endif

	" Decho func_start_pos[0].' <= '.current_line_no.' && '.current_line_no.' <= '.func_end_pos[0]
	if func_start_pos[0] <= current_line_no && current_line_no <= func_end_pos[0]
		call cursor(old_cursor_pos[0], old_cursor_pos[1])
		return [func_start_pos, func_end_pos]
	endif

	call cursor(old_cursor_pos[0], old_cursor_pos[1])
	return 0
endfunction
" }}}

function! phpcomplete#ExpandClassName(classname, current_namespace, imports) " {{{
	" if there's an imported class, just use that class's information
	if has_key(a:imports, a:classname) && (a:imports[a:classname].kind == 'c' || a:imports[a:classname].kind == 'i' || a:imports[a:classname].kind == 't')
		let namespace = has_key(a:imports[a:classname], 'namespace') ? a:imports[a:classname].namespace : ''
		return [a:imports[a:classname].name, namespace]
	endif

	" try to find relative namespace in imports, imported names takes precedence over
	" current namespace when resolving relative namespaced class names
	if a:classname !~ '^\' && a:classname =~ '\\'
		let classname_parts = split(a:classname, '\\\+')
		if has_key(a:imports, classname_parts[0]) && a:imports[classname_parts[0]].kind == 'n'
			let classname_parts[0] = a:imports[classname_parts[0]].name
			let namespace = join(classname_parts[0:-2], '\')
			let classname = classname_parts[-1]
			return [classname, namespace]
		endif
	endif

	" no imported class or namespace matched, expand with the current namespace
	let namespace = ''
	let classname = a:classname
	" if the classname have namespaces in in or we are in a namespace
	if a:classname =~ '\\' || (a:current_namespace != '\' && a:current_namespace != '')
		" add current namespace to the a:classname
		if a:classname !~ '^\'
			let classname = a:current_namespace.'\'.substitute(a:classname, '^\\', '', '')
		else
			" remove leading \, tag files doesn't have those
			let classname = substitute(a:classname, '^\\', '', '')
		endif
		" split classname to classname and namespace
		let classname_parts = split(classname, '\\\+')
		if len(classname_parts) > 1
			let namespace = join(classname_parts[0:-2], '\')
			let classname = classname_parts[-1]
		endif
	endif
	return [classname, namespace]
endfunction
" }}}

function! phpcomplete#LoadData() " {{{
" Keywords/reserved words, all other special things
" Later it is possible to add some help to values, or type of defined variable
let g:php_keywords={'PHP_SELF':'','argv':'','argc':'','GATEWAY_INTERFACE':'','SERVER_ADDR':'','SERVER_NAME':'','SERVER_SOFTWARE':'','SERVER_PROTOCOL':'','REQUEST_METHOD':'','REQUEST_TIME':'','QUERY_STRING':'','DOCUMENT_ROOT':'','HTTP_ACCEPT':'','HTTP_ACCEPT_CHARSET':'','HTTP_ACCEPT_ENCODING':'','HTTP_ACCEPT_LANGUAGE':'','HTTP_CONNECTION':'','HTTP_POST':'','HTTP_REFERER':'','HTTP_USER_AGENT':'','HTTPS':'','REMOTE_ADDR':'','REMOTE_HOST':'','REMOTE_PORT':'','SCRIPT_FILENAME':'','SERVER_ADMIN':'','SERVER_PORT':'','SERVER_SIGNATURE':'','PATH_TRANSLATED':'','SCRIPT_NAME':'','REQUEST_URI':'','PHP_AUTH_DIGEST':'','PHP_AUTH_USER':'','PHP_AUTH_PW':'','AUTH_TYPE':'','and':'','or':'','xor':'','__FILE__':'','exception':'','__LINE__':'','as':'','break':'','case':'','class':'','const':'','continue':'','declare':'','default':'','do':'','echo':'','else':'','elseif':'','enddeclare':'','endfor':'','endforeach':'','endif':'','endswitch':'','endwhile':'','extends':'','for':'','foreach':'','function':'','global':'','if':'','new':'','static':'','switch':'','use':'','var':'','while':'','final':'','php_user_filter':'','interface':'','implements':'','public':'','private':'','protected':'','abstract':'','clone':'','try':'','catch':'','throw':'','cfunction':'','old_function':'','this':'','INI_USER': '','INI_PERDIR': '','INI_SYSTEM': '','INI_ALL': '','ABDAY_1': '','ABDAY_2': '','ABDAY_3': '','ABDAY_4': '','ABDAY_5': '','ABDAY_6': '','ABDAY_7': '','DAY_1': '','DAY_2': '','DAY_3': '','DAY_4': '','DAY_5': '','DAY_6': '','DAY_7': '','ABMON_1': '','ABMON_2': '','ABMON_3': '','ABMON_4': '','ABMON_5': '','ABMON_6': '','ABMON_7': '','ABMON_8': '','ABMON_9': '','ABMON_10': '','ABMON_11': '','ABMON_12': '','MON_1': '','MON_2': '','MON_3': '','MON_4': '','MON_5': '','MON_6': '','MON_7': '','MON_8': '','MON_9': '','MON_10': '','MON_11': '','MON_12': '','AM_STR': '','D_T_FMT': '','ALT_DIGITS': '',}
" One giant hash of all built-in function, class, interface and constant grouped by extension
let php_builtin = {'functions':{},'classes':{},'interfaces':{},'constants':{},}
let php_builtin['functions']['math']={'abs(':'mixed $number | number','acos(':'float $arg | float','acosh(':'float $arg | float','asin(':'float $arg | float','asinh(':'float $arg | float','atan(':'float $arg | float','atan2(':'float $y, float $x | float','atanh(':'float $arg | float','base_convert(':'string $number, int $frombase, int $tobase | string','bindec(':'string $binary_string | number','ceil(':'float $value | float','cos(':'float $arg | float','cosh(':'float $arg | float','decbin(':'int $number | string','dechex(':'int $number | string','decoct(':'int $number | string','deg2rad(':'float $number | float','exp(':'float $arg | float','expm1(':'float $arg | float','floor(':'float $value | float','fmod(':'float $x, float $y | float','getrandmax(':'void | int','hexdec(':'string $hex_string | number','hypot(':'float $x, float $y | float','is_finite(':'float $val | bool','is_infinite(':'float $val | bool','is_nan(':'float $val | bool','lcg_value(':'void | float','log(':'float $arg [, float $base = M_E] | float','log10(':'float $arg | float','log1p(':'float $number | float','max(':'array $values | mixed','min(':'array $values | mixed','mt_getrandmax(':'void | int','mt_rand(':'void | int','mt_srand(':'[ int $seed] | void','octdec(':'string $octal_string | number','pi(':'void | float','pow(':'number $base, number $exp | number','rad2deg(':'float $number | float','rand(':'void | int','round(':'float $val [, int $precision = 0 [, int $mode = PHP_ROUND_HALF_UP]] | float','sin(':'float $arg | float','sinh(':'float $arg | float','sqrt(':'float $arg | float','srand(':'[ int $seed] | void','tan(':'float $arg | float','tanh(':'float $arg | float',}
let php_builtin['functions']['strings']={'addcslashes(':'string $str, string $charlist | string','addslashes(':'string $str | string','bin2hex(':'string $str | string','chop(':'chop — Alias of rtrim()','chr(':'int $ascii | string','chunk_split(':'string $body [, int $chunklen = 76 [, string $end = "\r\n"]] | string','convert_cyr_string(':'string $str, string $from, string $to | string','convert_uudecode(':'string $data | string','convert_uuencode(':'string $data | string','count_chars(':'string $string [, int $mode = 0] | mixed','crc32(':'string $str | int','crypt(':'string $str [, string $salt] | string','echo(':'string $arg1 [, string $...] | void','explode(':'string $delimiter, string $string [, int $limit] | array','fprintf(':'resource $handle, string $format [, mixed $args [, mixed $...]] | int','get_html_translation_table(':'[ int $table = HTML_SPECIALCHARS [, int $flags = ENT_COMPAT | ENT_HTML401 [, string $encoding = ''UTF-8'']]] | array','hebrev(':'string $hebrew_text [, int $max_chars_per_line = 0] | string','hebrevc(':'string $hebrew_text [, int $max_chars_per_line = 0] | string','hex2bin(':'string $data | string','html_entity_decode(':'string $string [, int $flags = ENT_COMPAT | ENT_HTML401 [, string $encoding = ''UTF-8'']] | string','htmlentities(':'string $string [, int $flags = ENT_COMPAT | ENT_HTML401 [, string $encoding = ''UTF-8'' [, bool $double_encode = true]]] | string','htmlspecialchars_decode(':'string $string [, int $flags = ENT_COMPAT | ENT_HTML401] | string','htmlspecialchars(':'string $string [, int $flags = ENT_COMPAT | ENT_HTML401 [, string $encoding = ''UTF-8'' [, bool $double_encode = true]]] | string','implode(':'string $glue, array $pieces | string','join(':'join — Alias of implode()','lcfirst(':'string $str | string','levenshtein(':'string $str1, string $str2 | int','localeconv(':'void | array','ltrim(':'string $str [, string $character_mask] | string','md5_file(':'string $filename [, bool $raw_output = false] | string','md5(':'string $str [, bool $raw_output = false] | string','metaphone(':'string $str [, int $phonemes = 0] | string','money_format(':'string $format, float $number | string','nl_langinfo(':'int $item | string','nl2br(':'string $string [, bool $is_xhtml = true] | string','number_format(':'float $number [, int $decimals = 0] | string','ord(':'string $string | int','parse_str(':'string $str [, array &$arr] | void','print(':'string $arg | int','printf(':'string $format [, mixed $args [, mixed $...]] | int','quoted_printable_decode(':'string $str | string','quoted_printable_encode(':'string $str | string','quotemeta(':'string $str | string','rtrim(':'string $str [, string $character_mask] | string','setlocale(':'int $category, string $locale [, string $...] | string','sha1_file(':'string $filename [, bool $raw_output = false] | string','sha1(':'string $str [, bool $raw_output = false] | string','similar_text(':'string $first, string $second [, float &$percent] | int','soundex(':'string $str | string','sprintf(':'string $format [, mixed $args [, mixed $...]] | string','sscanf(':'string $str, string $format [, mixed &$...] | mixed','str_getcsv(':'string $input [, string $delimiter = '','' [, string $enclosure = ''"'' [, string $escape = ''\\'']]] | array','str_ireplace(':'mixed $search, mixed $replace, mixed $subject [, int &$count] | mixed','str_pad(':'string $input, int $pad_length [, string $pad_string = " " [, int $pad_type = STR_PAD_RIGHT]] | string','str_repeat(':'string $input, int $multiplier | string','str_replace(':'mixed $search, mixed $replace, mixed $subject [, int &$count] | mixed','str_rot13(':'string $str | string','str_shuffle(':'string $str | string','str_split(':'string $string [, int $split_length = 1] | array','str_word_count(':'string $string [, int $format = 0 [, string $charlist]] | mixed','strcasecmp(':'string $str1, string $str2 | int','strchr(':'strchr — Alias of strstr()','strcmp(':'string $str1, string $str2 | int','strcoll(':'string $str1, string $str2 | int','strcspn(':'string $str1, string $str2 [, int $start [, int $length]] | int','strip_tags(':'string $str [, string $allowable_tags] | string','stripcslashes(':'string $str | string','stripos(':'string $haystack, string $needle [, int $offset = 0] | int','stripslashes(':'string $str | string','stristr(':'string $haystack, mixed $needle [, bool $before_needle = false] | string','strlen(':'string $string | int','strnatcasecmp(':'string $str1, string $str2 | int','strnatcmp(':'string $str1, string $str2 | int','strncasecmp(':'string $str1, string $str2, int $len | int','strncmp(':'string $str1, string $str2, int $len | int','strpbrk(':'string $haystack, string $char_list | string','strpos(':'string $haystack, mixed $needle [, int $offset = 0] | mixed','strrchr(':'string $haystack, mixed $needle | string','strrev(':'string $string | string','strripos(':'string $haystack, string $needle [, int $offset = 0] | int','strrpos(':'string $haystack, string $needle [, int $offset = 0] | int','strspn(':'string $subject, string $mask [, int $start [, int $length]] | int','strstr(':'string $haystack, mixed $needle [, bool $before_needle = false] | string','strtok(':'string $str, string $token | string','strtolower(':'string $str | string','strtoupper(':'string $string | string','strtr(':'string $str, string $from, string $to | string','substr_compare(':'string $main_str, string $str, int $offset [, int $length [, bool $case_insensitivity = false]] | int','substr_count(':'string $haystack, string $needle [, int $offset = 0 [, int $length]] | int','substr_replace(':'mixed $string, mixed $replacement, mixed $start [, mixed $length] | mixed','substr(':'string $string, int $start [, int $length] | string','trim(':'string $str [, string $character_mask = " \t\n\r\0\x0B"] | string','ucfirst(':'string $str | string','ucwords(':'string $str | string','vfprintf(':'resource $handle, string $format, array $args | int','vprintf(':'string $format, array $args | int','vsprintf(':'string $format, array $args | string','wordwrap(':'string $str [, int $width = 75 [, string $break = "\n" [, bool $cut = false]]] | string',}
let php_builtin['functions']['apache']={'apache_child_terminate(':'void | bool','apache_get_modules(':'void | array','apache_get_version(':'void | string','apache_getenv(':'string $variable [, bool $walk_to_top = false] | string','apache_lookup_uri(':'string $filename | object','apache_note(':'string $note_name [, string $note_value = ""] | string','apache_request_headers(':'void | array','apache_reset_timeout(':'void | bool','apache_response_headers(':'void | array','apache_setenv(':'string $variable, string $value [, bool $walk_to_top = false] | bool','getallheaders(':'void | array','virtual(':'string $filename | bool',}
let php_builtin['functions']['arrays']={'array_change_key_case(':'array $array [, int $case = CASE_LOWER] | array','array_chunk(':'array $array, int $size [, bool $preserve_keys = false] | array','array_column(':'array $array, mixed $column_key [, mixed $index_key = null] | array','array_combine(':'array $keys, array $values | array','array_count_values(':'array $array | array','array_diff_assoc(':'array $array1, array $array2 [, array $...] | array','array_diff_key(':'array $array1, array $array2 [, array $...] | array','array_diff_uassoc(':'array $array1, array $array2 [, array $... [, callable $key_compare_func]] | array','array_diff_ukey(':'array $array1, array $array2 [, array $... [, callable $key_compare_func]] | array','array_diff(':'array $array1, array $array2 [, array $...] | array','array_fill_keys(':'array $keys, mixed $value | array','array_fill(':'int $start_index, int $num, mixed $value | array','array_filter(':'array $array [, callable $callback] | array','array_flip(':'array $array | array','array_intersect_assoc(':'array $array1, array $array2 [, array $...] | array','array_intersect_key(':'array $array1, array $array2 [, array $...] | array','array_intersect_uassoc(':'array $array1, array $array2 [, array $... [, callable $key_compare_func]] | array','array_intersect_ukey(':'array $array1, array $array2 [, array $... [, callable $key_compare_func]] | array','array_intersect(':'array $array1, array $array2 [, array $...] | array','array_key_exists(':'mixed $key, array $array | bool','array_keys(':'array $array [, mixed $search_value [, bool $strict = false]] | array','array_map(':'callable $callback, array $array1 [, array $...] | array','array_merge_recursive(':'array $array1 [, array $...] | array','array_merge(':'array $array1 [, array $...] | array','array_multisort(':'array &$array1 [, mixed $array1_sort_order = SORT_ASC [, mixed $array1_sort_flags = SORT_REGULAR [, mixed $...]]] | bool','array_pad(':'array $array, int $size, mixed $value | array','array_pop(':'array &$array | mixed','array_product(':'array $array | number','array_push(':'array &$array, mixed $value1 [, mixed $...] | int','array_rand(':'array $array [, int $num = 1] | mixed','array_reduce(':'array $array, callable $callback [, mixed $initial = NULL] | mixed','array_replace_recursive(':'array $array1, array $array2 [, array $...] | array','array_replace(':'array $array1, array $array2 [, array $...] | array','array_reverse(':'array $array [, bool $preserve_keys = false] | array','array_search(':'mixed $needle, array $haystack [, bool $strict = false] | mixed','array_shift(':'array &$array | mixed','array_slice(':'array $array, int $offset [, int $length = NULL [, bool $preserve_keys = false]] | array','array_splice(':'array &$input, int $offset [, int $length [, mixed $replacement = array()]] | array','array_sum(':'array $array | number','array_udiff_assoc(':'array $array1, array $array2 [, array $... [, callable $value_compare_func]] | array','array_udiff_uassoc(':'array $array1, array $array2 [, array $... [, callable $value_compare_func [, callable $key_compare_func]]] | array','array_udiff(':'array $array1, array $array2 [, array $... [, callable $value_compare_func]] | array','array_uintersect_assoc(':'array $array1, array $array2 [, array $... [, callable $value_compare_func]] | array','array_uintersect_uassoc(':'array $array1, array $array2 [, array $... [, callable $value_compare_func [, callable $key_compare_func]]] | array','array_uintersect(':'array $array1, array $array2 [, array $... [, callable $value_compare_func]] | array','array_unique(':'array $array [, int $sort_flags = SORT_STRING] | array','array_unshift(':'array &$array, mixed $value1 [, mixed $...] | int','array_values(':'array $array | array','array_walk_recursive(':'array &$array, callable $callback [, mixed $userdata = NULL] | bool','array_walk(':'array &$array, callable $callback [, mixed $userdata = NULL] | bool','array(':'[ mixed $...] | array','arsort(':'array &$array [, int $sort_flags = SORT_REGULAR] | bool','asort(':'array &$array [, int $sort_flags = SORT_REGULAR] | bool','compact(':'mixed $varname1 [, mixed $...] | array','count(':'mixed $array_or_countable [, int $mode = COUNT_NORMAL] | int','current(':'array &$array | mixed','each(':'array &$array | array','end(':'array &$array | mixed','extract(':'array &$array [, int $flags = EXTR_OVERWRITE [, string $prefix = NULL]] | int','in_array(':'mixed $needle, array $haystack [, bool $strict = FALSE] | bool','key_exists(':'key_exists — Alias of array_key_exists()','key(':'array &$array | mixed','krsort(':'array &$array [, int $sort_flags = SORT_REGULAR] | bool','ksort(':'array &$array [, int $sort_flags = SORT_REGULAR] | bool','list(':'mixed $var1 [, mixed $...] | array','natcasesort(':'array &$array | bool','natsort(':'array &$array | bool','next(':'array &$array | mixed','pos(':'pos — Alias of current()','prev(':'array &$array | mixed','range(':'mixed $start, mixed $end [, number $step = 1] | array','reset(':'array &$array | mixed','rsort(':'array &$array [, int $sort_flags = SORT_REGULAR] | bool','shuffle(':'array &$array | bool','sizeof(':'sizeof — Alias of count()','sort(':'array &$array [, int $sort_flags = SORT_REGULAR] | bool','uasort(':'array &$array, callable $value_compare_func | bool','uksort(':'array &$array, callable $key_compare_func | bool','usort(':'array &$array, callable $value_compare_func | bool',}
let php_builtin['functions']['php_options_info']={'assert_options(':'int $what [, mixed $value] | mixed','assert(':'mixed $assertion [, string $description] | bool','cli_get_process_title(':'void | string','cli_set_process_title(':'string $title | bool','dl(':'string $library | bool','extension_loaded(':'string $name | bool','gc_collect_cycles(':'void | int','gc_disable(':'void | void','gc_enable(':'void | void','gc_enabled(':'void | bool','get_cfg_var(':'string $option | string','get_current_user(':'void | string','get_defined_constants(':'[ bool $categorize = false] | array','get_extension_funcs(':'string $module_name | array','get_include_path(':'void | string','get_included_files(':'void | array','get_loaded_extensions(':'[ bool $zend_extensions = false] | array','get_magic_quotes_gpc(':'void | bool','get_magic_quotes_runtime(':'void | bool','get_required_files(':'get_required_files — Alias of get_included_files()','getenv(':'string $varname | string','getlastmod(':'void | int','getmygid(':'void | int','getmyinode(':'void | int','getmypid(':'void | int','getmyuid(':'void | int','getopt(':'string $options [, array $longopts] | array','getrusage(':'[ int $who = 0] | array','ini_alter(':'ini_alter — Alias of ini_set()','ini_get_all(':'[ string $extension [, bool $details = true]] | array','ini_get(':'string $varname | string','ini_restore(':'string $varname | void','ini_set(':'string $varname, string $newvalue | string','magic_quotes_runtime(':'magic_quotes_runtime — Alias of set_magic_quotes_runtime()','memory_get_peak_usage(':'[ bool $real_usage = false] | int','memory_get_usage(':'[ bool $real_usage = false] | int','php_ini_loaded_file(':'void | string','php_ini_scanned_files(':'void | string','php_logo_guid(':'void | string','php_sapi_name(':'void | string','php_uname(':'[ string $mode = "a"] | string','phpcredits(':'[ int $flag = CREDITS_ALL] | bool','phpinfo(':'[ int $what = INFO_ALL] | bool','phpversion(':'[ string $extension] | string','putenv(':'string $setting | bool','restore_include_path(':'void | void','set_include_path(':'string $new_include_path | string','set_magic_quotes_runtime(':'bool $new_setting | bool','set_time_limit(':'int $seconds | void','sys_get_temp_dir(':'void | string','version_compare(':'string $version1, string $version2 [, string $operator] | mixed','zend_logo_guid(':'void | string','zend_thread_id(':'void | int','zend_version(':'void | string',}
let php_builtin['functions']['classes_objects']={'__autoload(':'string $class | void','call_user_method_array(':'string $method_name, object &$obj, array $params | mixed','call_user_method(':'string $method_name, object &$obj [, mixed $parameter [, mixed $...]] | mixed','class_alias(':'string $original, string $alias [, bool $autoload = TRUE] | bool','class_exists(':'string $class_name [, bool $autoload = true] | bool','get_called_class(':'void | string','get_class_methods(':'mixed $class_name | array','get_class_vars(':'string $class_name | array','get_class(':'[ object $object = NULL] | string','get_declared_classes(':'void | array','get_declared_interfaces(':'void | array','get_declared_traits(':'void | array','get_object_vars(':'object $object | array','get_parent_class(':'[ mixed $object] | string','interface_exists(':'string $interface_name [, bool $autoload = true] | bool','is_a(':'object $object, string $class_name [, bool $allow_string = FALSE] | bool','is_subclass_of(':'mixed $object, string $class_name [, bool $allow_string = TRUE] | bool','method_exists(':'mixed $object, string $method_name | bool','property_exists(':'mixed $class, string $property | bool','trait_exists(':'string $traitname [, bool $autoload] | bool',}
let php_builtin['functions']['urls']={'base64_decode(':'string $data [, bool $strict = false] | string','base64_encode(':'string $data | string','get_headers(':'string $url [, int $format = 0] | array','get_meta_tags(':'string $filename [, bool $use_include_path = false] | array','http_build_query(':'mixed $query_data [, string $numeric_prefix [, string $arg_separator [, int $enc_type = PHP_QUERY_RFC1738]]] | string','parse_url(':'string $url [, int $component = -1] | mixed','rawurldecode(':'string $str | string','rawurlencode(':'string $str | string','urldecode(':'string $str | string','urlencode(':'string $str | string',}
let php_builtin['functions']['filesystem']={'basename(':'string $path [, string $suffix] | string','chgrp(':'string $filename, mixed $group | bool','chmod(':'string $filename, int $mode | bool','chown(':'string $filename, mixed $user | bool','clearstatcache(':'[ bool $clear_realpath_cache = false [, string $filename]] | void','copy(':'string $source, string $dest [, resource $context] | bool','dirname(':'string $path | string','disk_free_space(':'string $directory | float','disk_total_space(':'string $directory | float','diskfreespace(':'diskfreespace — Alias of disk_free_space()','fclose(':'resource $handle | bool','feof(':'resource $handle | bool','fflush(':'resource $handle | bool','fgetc(':'resource $handle | string','fgetcsv(':'resource $handle [, int $length = 0 [, string $delimiter = '','' [, string $enclosure = ''"'' [, string $escape = ''\\'']]]] | array','fgets(':'resource $handle [, int $length] | string','fgetss(':'resource $handle [, int $length [, string $allowable_tags]] | string','file_exists(':'string $filename | bool','file_get_contents(':'string $filename [, bool $use_include_path = false [, resource $context [, int $offset = -1 [, int $maxlen]]]] | string','file_put_contents(':'string $filename, mixed $data [, int $flags = 0 [, resource $context]] | int','file(':'string $filename [, int $flags = 0 [, resource $context]] | array','fileatime(':'string $filename | int','filectime(':'string $filename | int','filegroup(':'string $filename | int','fileinode(':'string $filename | int','filemtime(':'string $filename | int','fileowner(':'string $filename | int','fileperms(':'string $filename | int','filesize(':'string $filename | int','filetype(':'string $filename | string','flock(':'resource $handle, int $operation [, int &$wouldblock] | bool','fnmatch(':'string $pattern, string $string [, int $flags = 0] | bool','fopen(':'string $filename, string $mode [, bool $use_include_path = false [, resource $context]] | resource','fpassthru(':'resource $handle | int','fputcsv(':'resource $handle, array $fields [, string $delimiter = '','' [, string $enclosure = ''"'']] | int','fputs(':'fputs — Alias of fwrite()','fread(':'resource $handle, int $length | string','fscanf(':'resource $handle, string $format [, mixed &$...] | mixed','fseek(':'resource $handle, int $offset [, int $whence = SEEK_SET] | int','fstat(':'resource $handle | array','ftell(':'resource $handle | int','ftruncate(':'resource $handle, int $size | bool','fwrite(':'resource $handle, string $string [, int $length] | int','glob(':'string $pattern [, int $flags = 0] | array','is_dir(':'string $filename | bool','is_executable(':'string $filename | bool','is_file(':'string $filename | bool','is_link(':'string $filename | bool','is_readable(':'string $filename | bool','is_uploaded_file(':'string $filename | bool','is_writable(':'string $filename | bool','is_writeable(':'is_writeable — Alias of is_writable()','lchgrp(':'string $filename, mixed $group | bool','lchown(':'string $filename, mixed $user | bool','link(':'string $target, string $link | bool','linkinfo(':'string $path | int','lstat(':'string $filename | array','mkdir(':'string $pathname [, int $mode = 0777 [, bool $recursive = false [, resource $context]]] | bool','move_uploaded_file(':'string $filename, string $destination | bool','parse_ini_file(':'string $filename [, bool $process_sections = false [, int $scanner_mode = INI_SCANNER_NORMAL]] | array','parse_ini_string(':'string $ini [, bool $process_sections = false [, int $scanner_mode = INI_SCANNER_NORMAL]] | array','pathinfo(':'string $path [, int $options = PATHINFO_DIRNAME | PATHINFO_BASENAME | PATHINFO_EXTENSION | PATHINFO_FILENAME] | mixed','pclose(':'resource $handle | int','popen(':'string $command, string $mode | resource','readfile(':'string $filename [, bool $use_include_path = false [, resource $context]] | int','readlink(':'string $path | string','realpath_cache_get(':'void | array','realpath_cache_size(':'void | int','realpath(':'string $path | string','rename(':'string $oldname, string $newname [, resource $context] | bool','rewind(':'resource $handle | bool','rmdir(':'string $dirname [, resource $context] | bool','set_file_buffer(':'set_file_buffer — Alias of stream_set_write_buffer()','stat(':'string $filename | array','symlink(':'string $target, string $link | bool','tempnam(':'string $dir, string $prefix | string','tmpfile(':'void | resource','touch(':'string $filename [, int $time = time() [, int $atime]] | bool','umask(':'[ int $mask] | int','unlink(':'string $filename [, resource $context] | bool',}
let php_builtin['functions']['variable_handling']={'boolval(':'mixed $var | boolean','debug_zval_dump(':'mixed $variable [, mixed $...] | void','doubleval(':'doubleval — Alias of floatval()','empty(':'mixed $var | bool','floatval(':'mixed $var | float','get_defined_vars(':'void | array','get_resource_type(':'resource $handle | string','gettype(':'mixed $var | string','import_request_variables(':'string $types [, string $prefix] | bool','intval(':'mixed $var [, int $base = 10] | int','is_array(':'mixed $var | bool','is_bool(':'mixed $var | bool','is_callable(':'callable $name [, bool $syntax_only = false [, string &$callable_name]] | bool','is_double(':'is_double — Alias of is_float()','is_float(':'mixed $var | bool','is_int(':'mixed $var | bool','is_integer(':'is_integer — Alias of is_int()','is_long(':'is_long — Alias of is_int()','is_null(':'mixed $var | bool','is_numeric(':'mixed $var | bool','is_object(':'mixed $var | bool','is_real(':'is_real — Alias of is_float()','is_resource(':'mixed $var | bool','is_scalar(':'mixed $var | bool','is_string(':'mixed $var | bool','isset(':'mixed $var [, mixed $...] | bool','print_r(':'mixed $expression [, bool $return = false] | mixed','serialize(':'mixed $value | string','settype(':'mixed &$var, string $type | bool','strval(':'mixed $var | string','unserialize(':'string $str | mixed','unset(':'mixed $var [, mixed $...] | void','var_dump(':'mixed $expression [, mixed $...] | void','var_export(':'mixed $expression [, bool $return = false] | mixed',}
let php_builtin['functions']['calendar']={'cal_days_in_month(':'int $calendar, int $month, int $year | int','cal_from_jd(':'int $jd, int $calendar | array','cal_info(':'[ int $calendar = -1] | array','cal_to_jd(':'int $calendar, int $month, int $day, int $year | int','easter_date(':'[ int $year] | int','easter_days(':'[ int $year [, int $method = CAL_EASTER_DEFAULT]] | int','frenchtojd(':'int $month, int $day, int $year | int','gregoriantojd(':'int $month, int $day, int $year | int','jddayofweek(':'int $julianday [, int $mode = CAL_DOW_DAYNO] | mixed','jdmonthname(':'int $julianday, int $mode | string','jdtofrench(':'int $juliandaycount | string','jdtogregorian(':'int $julianday | string','jdtojewish(':'int $juliandaycount [, bool $hebrew = false [, int $fl = 0]] | string','jdtojulian(':'int $julianday | string','jdtounix(':'int $jday | int','jewishtojd(':'int $month, int $day, int $year | int','juliantojd(':'int $month, int $day, int $year | int','unixtojd(':'[ int $timestamp = time()] | int',}
let php_builtin['functions']['function_handling']={'call_user_func_array(':'callable $callback, array $param_arr | mixed','call_user_func(':'callable $callback [, mixed $parameter [, mixed $...]] | mixed','create_function(':'string $args, string $code | string','forward_static_call_array(':'callable $function, array $parameters | mixed','forward_static_call(':'callable $function [, mixed $parameter [, mixed $...]] | mixed','func_get_arg(':'int $arg_num | mixed','func_get_args(':'void | array','func_num_args(':'void | int','function_exists(':'string $function_name | bool','get_defined_functions(':'void | array','register_shutdown_function(':'callable $callback [, mixed $parameter [, mixed $...]] | void','register_tick_function(':'callable $function [, mixed $arg [, mixed $...]] | bool','unregister_tick_function(':'string $function_name | void',}
let php_builtin['functions']['directories']={'chdir(':'string $directory | bool','chroot(':'string $directory | bool','closedir(':'[ resource $dir_handle] | void','dir(':'string $directory [, resource $context] | Directory','getcwd(':'void | string','opendir(':'string $path [, resource $context] | resource','readdir(':'[ resource $dir_handle] | string','rewinddir(':'[ resource $dir_handle] | void','scandir(':'string $directory [, int $sorting_order = SCANDIR_SORT_ASCENDING [, resource $context]] | array',}
let php_builtin['functions']['date_time']={'checkdate(':'int $month, int $day, int $year | bool','date_default_timezone_get(':'void | string','date_default_timezone_set(':'string $timezone_identifier | bool','date_parse_from_format(':'string $format, string $date | array','date_parse(':'string $date | array','date_sun_info(':'int $time, float $latitude, float $longitude | array','date_sunrise(':'int $timestamp [, int $format = SUNFUNCS_RET_STRING [, float $latitude = ini_get("date.default_latitude") [, float $longitude = ini_get("date.default_longitude") [, float $zenith = ini_get("date.sunrise_zenith") [, float $gmt_offset = 0]]]]] | mixed','date_sunset(':'int $timestamp [, int $format = SUNFUNCS_RET_STRING [, float $latitude = ini_get("date.default_latitude") [, float $longitude = ini_get("date.default_longitude") [, float $zenith = ini_get("date.sunset_zenith") [, float $gmt_offset = 0]]]]] | mixed','date(':'string $format [, int $timestamp = time()] | string','getdate(':'[ int $timestamp = time()] | array','gettimeofday(':'[ bool $return_float = false] | mixed','gmdate(':'string $format [, int $timestamp = time()] | string','gmmktime(':'[ int $hour = gmdate("H") [, int $minute = gmdate("i") [, int $second = gmdate("s") [, int $month = gmdate("n") [, int $day = gmdate("j") [, int $year = gmdate("Y") [, int $is_dst = -1]]]]]]] | int','gmstrftime(':'string $format [, int $timestamp = time()] | string','idate(':'string $format [, int $timestamp = time()] | int','localtime(':'[ int $timestamp = time() [, bool $is_associative = false]] | array','microtime(':'[ bool $get_as_float = false] | mixed','mktime(':'[ int $hour = date("H") [, int $minute = date("i") [, int $second = date("s") [, int $month = date("n") [, int $day = date("j") [, int $year = date("Y") [, int $is_dst = -1]]]]]]] | int','strftime(':'string $format [, int $timestamp = time()] | string','strptime(':'string $date, string $format | array','strtotime(':'string $time [, int $now = time()] | int','time(':'void | int','timezone_name_from_abbr(':'string $abbr [, int $gmtOffset = -1 [, int $isdst = -1]] | string','timezone_version_get(':'void | string',}
let php_builtin['functions']['network']={'checkdnsrr(':'string $host [, string $type = "MX"] | bool','closelog(':'void | bool','define_syslog_variables(':'void | void','dns_get_record(':'string $hostname [, int $type = DNS_ANY [, array &$authns [, array &$addtl [, bool &$raw = false]]]] | array','fsockopen(':'string $hostname [, int $port = -1 [, int &$errno [, string &$errstr [, float $timeout = ini_get("default_socket_timeout")]]]] | resource','gethostbyaddr(':'string $ip_address | string','gethostbyname(':'string $hostname | string','gethostbynamel(':'string $hostname | array','gethostname(':'void | string','getmxrr(':'string $hostname, array &$mxhosts [, array &$weight] | bool','getprotobyname(':'string $name | int','getprotobynumber(':'int $number | string','getservbyname(':'string $service, string $protocol | int','getservbyport(':'int $port, string $protocol | string','header_register_callback(':'callable $callback | bool','header_remove(':'[ string $name] | void','header(':'string $string [, bool $replace = true [, int $http_response_code]] | void','headers_list(':'void | array','headers_sent(':'[ string &$file [, int &$line]] | bool','http_response_code(':'[ int $response_code] | int','inet_ntop(':'string $in_addr | string','inet_pton(':'string $address | string','ip2long(':'string $ip_address | int','long2ip(':'string $proper_address | string','openlog(':'string $ident, int $option, int $facility | bool','pfsockopen(':'string $hostname [, int $port = -1 [, int &$errno [, string &$errstr [, float $timeout = ini_get("default_socket_timeout")]]]] | resource','setcookie(':'string $name [, string $value [, int $expire = 0 [, string $path [, string $domain [, bool $secure = false [, bool $httponly = false]]]]]] | bool','setrawcookie(':'string $name [, string $value [, int $expire = 0 [, string $path [, string $domain [, bool $secure = false [, bool $httponly = false]]]]]] | bool','socket_get_status(':'socket_get_status — Alias of stream_get_meta_data()','socket_set_blocking(':'socket_set_blocking — Alias of stream_set_blocking()','socket_set_timeout(':'socket_set_timeout — Alias of stream_set_timeout()','syslog(':'int $priority, string $message | bool',}
let php_builtin['functions']['spl']={'class_implements(':'mixed $class [, bool $autoload = true] | array','class_parents(':'mixed $class [, bool $autoload = true] | array','class_uses(':'mixed $class [, bool $autoload = true] | array','iterator_apply(':'Traversable $iterator, callable $function [, array $args] | int','iterator_count(':'Traversable $iterator | int','iterator_to_array(':'Traversable $iterator [, bool $use_keys = true] | array','spl_autoload_call(':'string $class_name | void','spl_autoload_extensions(':'[ string $file_extensions] | string','spl_autoload_functions(':'void | array','spl_autoload_register(':'[ callable $autoload_function [, bool $throw = true [, bool $prepend = false]]] | bool','spl_autoload_unregister(':'mixed $autoload_function | bool','spl_autoload(':'string $class_name [, string $file_extensions = spl_autoload_extensions()] | void','spl_classes(':'void | array','spl_object_hash(':'object $obj | string',}
let php_builtin['functions']['misc']={'connection_aborted(':'void | int','connection_status(':'void | int','connection_timeout(':'void | int','constant(':'string $name | mixed','define(':'string $name, mixed $value [, bool $case_insensitive = false] | bool','defined(':'string $name | bool','eval(':'string $code | mixed','exit(':'[ string $status] | void','get_browser(':'[ string $user_agent [, bool $return_array = false]] | mixed','__halt_compiler(':'void | void','highlight_file(':'string $filename [, bool $return = false] | mixed','highlight_string(':'string $str [, bool $return = false] | mixed','ignore_user_abort(':'[ string $value] | int','pack(':'string $format [, mixed $args [, mixed $...]] | string','php_check_syntax(':'string $filename [, string &$error_message] | bool','php_strip_whitespace(':'string $filename | string','show_source(':'show_source — Alias of highlight_file()','sleep(':'int $seconds | int','sys_getloadavg(':'void | array','time_nanosleep(':'int $seconds, int $nanoseconds | mixed','time_sleep_until(':'float $timestamp | bool','uniqid(':'[ string $prefix = "" [, bool $more_entropy = false]] | string','unpack(':'string $format, string $data | array','usleep(':'int $micro_seconds | void',}
let php_builtin['functions']['curl']={'curl_close(':'resource $ch | void','curl_copy_handle(':'resource $ch | resource','curl_errno(':'resource $ch | int','curl_error(':'resource $ch | string','curl_escape(':'resource $ch, string $str | string','curl_exec(':'resource $ch | mixed','curl_getinfo(':'resource $ch [, int $opt = 0] | mixed','curl_init(':'[ string $url = NULL] | resource','curl_multi_add_handle(':'resource $mh, resource $ch | int','curl_multi_close(':'resource $mh | void','curl_multi_exec(':'resource $mh, int &$still_running | int','curl_multi_getcontent(':'resource $ch | string','curl_multi_info_read(':'resource $mh [, int &$msgs_in_queue = NULL] | array','curl_multi_init(':'void | resource','curl_multi_remove_handle(':'resource $mh, resource $ch | int','curl_multi_select(':'resource $mh [, float $timeout = 1.0] | int','curl_multi_setopt(':'resource $mh, int $option, mixed $value | bool','curl_multi_strerror(':'int $errornum | string','curl_pause(':'resource $ch, int $bitmask | int','curl_reset(':'resource $ch | void','curl_setopt_array(':'resource $ch, array $options | bool','curl_setopt(':'resource $ch, int $option, mixed $value | bool','curl_share_close(':'resource $sh | void','curl_share_init(':'void | resource','curl_share_setopt(':'resource $sh, int $option, string $value | bool','curl_strerror(':'int $errornum | string','curl_unescape(':'resource $ch, string $str | string','curl_version(':'[ int $age = CURLVERSION_NOW] | array',}
let php_builtin['functions']['error_handling']={'debug_backtrace(':'[ int $options = DEBUG_BACKTRACE_PROVIDE_OBJECT [, int $limit = 0]] | array','debug_print_backtrace(':'[ int $options = 0 [, int $limit = 0]] | void','error_get_last(':'void | array','error_log(':'string $message [, int $message_type = 0 [, string $destination [, string $extra_headers]]] | bool','error_reporting(':'[ int $level] | int','restore_error_handler(':'void | bool','restore_exception_handler(':'void | bool','set_error_handler(':'callable $error_handler [, int $error_types = E_ALL | E_STRICT] | mixed','set_exception_handler(':'callable $exception_handler | callable','trigger_error(':'string $error_msg [, int $error_type = E_USER_NOTICE] | bool',}
let php_builtin['functions']['dom']={'dom_import_simplexml(':'SimpleXMLElement $node | DOMElement',}
let php_builtin['functions']['program_execution']={'escapeshellarg(':'string $arg | string','escapeshellcmd(':'string $command | string','exec(':'string $command [, array &$output [, int &$return_var]] | string','passthru(':'string $command [, int &$return_var] | void','proc_close(':'resource $process | int','proc_get_status(':'resource $process | array','proc_nice(':'int $increment | bool','proc_open(':'string $cmd, array $descriptorspec, array &$pipes [, string $cwd [, array $env [, array $other_options]]] | resource','proc_terminate(':'resource $process [, int $signal = 15] | bool','shell_exec(':'string $cmd | string','system(':'string $command [, int &$return_var] | string',}
let php_builtin['functions']['mail']={'ezmlm_hash(':'string $addr | int','mail(':'string $to, string $subject, string $message [, string $additional_headers [, string $additional_parameters]] | bool',}
let php_builtin['functions']['fastcgi_process_manager']={'fastcgi_finish_request(':'void | boolean',}
let php_builtin['functions']['filter']={'filter_has_var(':'int $type, string $variable_name | bool','filter_id(':'string $filtername | int','filter_input_array(':'int $type [, mixed $definition [, bool $add_empty = true]] | mixed','filter_input(':'int $type, string $variable_name [, int $filter = FILTER_DEFAULT [, mixed $options]] | mixed','filter_list(':'void | array','filter_var_array(':'array $data [, mixed $definition [, bool $add_empty = true]] | mixed','filter_var(':'mixed $variable [, int $filter = FILTER_DEFAULT [, mixed $options]] | mixed',}
let php_builtin['functions']['fileinfo']={'finfo_buffer(':'resource $finfo [, string $string = NULL [, int $options = FILEINFO_NONE [, resource $context = NULL]]] | string','finfo_close(':'resource $finfo | bool','finfo_file(':'resource $finfo [, string $file_name = NULL [, int $options = FILEINFO_NONE [, resource $context = NULL]]] | string','finfo_open(':'[ int $options = FILEINFO_NONE [, string $magic_file = NULL]] | resource','finfo_set_flags(':'resource $finfo, int $options | bool','mime_content_type(':'string $filename | string',}
let php_builtin['functions']['output_control']={'flush(':'void | void','ob_clean(':'void | void','ob_end_clean(':'void | bool','ob_end_flush(':'void | bool','ob_flush(':'void | void','ob_get_clean(':'void | string','ob_get_contents(':'void | string','ob_get_flush(':'void | string','ob_get_length(':'void | int','ob_get_level(':'void | int','ob_get_status(':'[ bool $full_status = FALSE] | array','ob_gzhandler(':'string $buffer, int $mode | string','ob_implicit_flush(':'[ int $flag = true] | void','ob_list_handlers(':'void | array','ob_start(':'[ callable $output_callback = NULL [, int $chunk_size = 0 [, int $flags = PHP_OUTPUT_HANDLER_STDFLAGS]]] | bool','output_add_rewrite_var(':'string $name, string $value | bool','output_reset_rewrite_vars(':'void | bool',}
let php_builtin['functions']['gd']={'gd_info(':'void | array','getimagesize(':'string $filename [, array &$imageinfo] | array','getimagesizefromstring(':'string $imagedata [, array &$imageinfo] | array','image_type_to_extension(':'int $imagetype [, bool $include_dot = TRUE] | string','image_type_to_mime_type(':'int $imagetype | string','image2wbmp(':'resource $image [, string $filename [, int $threshold]] | bool','imageaffine(':'resource $image, array $affine [, array $clip] | resource','imageaffinematrixconcat(':'array $m1, array $m2 | array','imageaffinematrixget(':'int $type [, mixed $options] | array','imagealphablending(':'resource $image, bool $blendmode | bool','imageantialias(':'resource $image, bool $enabled | bool','imagearc(':'resource $image, int $cx, int $cy, int $width, int $height, int $start, int $end, int $color | bool','imagechar(':'resource $image, int $font, int $x, int $y, string $c, int $color | bool','imagecharup(':'resource $image, int $font, int $x, int $y, string $c, int $color | bool','imagecolorallocate(':'resource $image, int $red, int $green, int $blue | int','imagecolorallocatealpha(':'resource $image, int $red, int $green, int $blue, int $alpha | int','imagecolorat(':'resource $image, int $x, int $y | int','imagecolorclosest(':'resource $image, int $red, int $green, int $blue | int','imagecolorclosestalpha(':'resource $image, int $red, int $green, int $blue, int $alpha | int','imagecolorclosesthwb(':'resource $image, int $red, int $green, int $blue | int','imagecolordeallocate(':'resource $image, int $color | bool','imagecolorexact(':'resource $image, int $red, int $green, int $blue | int','imagecolorexactalpha(':'resource $image, int $red, int $green, int $blue, int $alpha | int','imagecolormatch(':'resource $image1, resource $image2 | bool','imagecolorresolve(':'resource $image, int $red, int $green, int $blue | int','imagecolorresolvealpha(':'resource $image, int $red, int $green, int $blue, int $alpha | int','imagecolorset(':'resource $image, int $index, int $red, int $green, int $blue [, int $alpha = 0] | void','imagecolorsforindex(':'resource $image, int $index | array','imagecolorstotal(':'resource $image | int','imagecolortransparent(':'resource $image [, int $color] | int','imageconvolution(':'resource $image, array $matrix, float $div, float $offset | bool','imagecopy(':'resource $dst_im, resource $src_im, int $dst_x, int $dst_y, int $src_x, int $src_y, int $src_w, int $src_h | bool','imagecopymerge(':'resource $dst_im, resource $src_im, int $dst_x, int $dst_y, int $src_x, int $src_y, int $src_w, int $src_h, int $pct | bool','imagecopymergegray(':'resource $dst_im, resource $src_im, int $dst_x, int $dst_y, int $src_x, int $src_y, int $src_w, int $src_h, int $pct | bool','imagecopyresampled(':'resource $dst_image, resource $src_image, int $dst_x, int $dst_y, int $src_x, int $src_y, int $dst_w, int $dst_h, int $src_w, int $src_h | bool','imagecopyresized(':'resource $dst_image, resource $src_image, int $dst_x, int $dst_y, int $src_x, int $src_y, int $dst_w, int $dst_h, int $src_w, int $src_h | bool','imagecreate(':'int $width, int $height | resource','imagecreatefromgd(':'string $filename | resource','imagecreatefromgd2(':'string $filename | resource','imagecreatefromgd2part(':'string $filename, int $srcX, int $srcY, int $width, int $height | resource','imagecreatefromgif(':'string $filename | resource','imagecreatefromjpeg(':'string $filename | resource','imagecreatefrompng(':'string $filename | resource','imagecreatefromstring(':'string $image | resource','imagecreatefromwbmp(':'string $filename | resource','imagecreatefromwebp(':'string $filename | resource','imagecreatefromxbm(':'string $filename | resource','imagecreatefromxpm(':'string $filename | resource','imagecreatetruecolor(':'int $width, int $height | resource','imagecrop(':'resource $image, array $rect | resource','imagecropauto(':'resource $image [, int $mode = -1 [, float $threshold = .5 [, int $color = -1]]] | resource','imagedashedline(':'resource $image, int $x1, int $y1, int $x2, int $y2, int $color | bool','imagedestroy(':'resource $image | bool','imageellipse(':'resource $image, int $cx, int $cy, int $width, int $height, int $color | bool','imagefill(':'resource $image, int $x, int $y, int $color | bool','imagefilledarc(':'resource $image, int $cx, int $cy, int $width, int $height, int $start, int $end, int $color, int $style | bool','imagefilledellipse(':'resource $image, int $cx, int $cy, int $width, int $height, int $color | bool','imagefilledpolygon(':'resource $image, array $points, int $num_points, int $color | bool','imagefilledrectangle(':'resource $image, int $x1, int $y1, int $x2, int $y2, int $color | bool','imagefilltoborder(':'resource $image, int $x, int $y, int $border, int $color | bool','imagefilter(':'resource $image, int $filtertype [, int $arg1 [, int $arg2 [, int $arg3 [, int $arg4]]]] | bool','imageflip(':'resource $image, int $mode | bool','imagefontheight(':'int $font | int','imagefontwidth(':'int $font | int','imageftbbox(':'float $size, float $angle, string $fontfile, string $text [, array $extrainfo] | array','imagefttext(':'resource $image, float $size, float $angle, int $x, int $y, int $color, string $fontfile, string $text [, array $extrainfo] | array','imagegammacorrect(':'resource $image, float $inputgamma, float $outputgamma | bool','imagegd(':'resource $image [, string $filename] | bool','imagegd2(':'resource $image [, string $filename [, int $chunk_size [, int $type = IMG_GD2_RAW]]] | bool','imagegif(':'resource $image [, string $filename] | bool','imagegrabscreen(':'void | resource','imagegrabwindow(':'int $window_handle [, int $client_area = 0] | resource','imageinterlace(':'resource $image [, int $interlace = 0] | int','imageistruecolor(':'resource $image | bool','imagejpeg(':'resource $image [, string $filename [, int $quality]] | bool','imagelayereffect(':'resource $image, int $effect | bool','imageline(':'resource $image, int $x1, int $y1, int $x2, int $y2, int $color | bool','imageloadfont(':'string $file | int','imagepalettecopy(':'resource $destination, resource $source | void','imagepalettetotruecolor(':'resource $src | bool','imagepng(':'resource $image [, string $filename [, int $quality [, int $filters]]] | bool','imagepolygon(':'resource $image, array $points, int $num_points, int $color | bool','imagepsbbox(':'string $text, resource $font, int $size | array','imagepsencodefont(':'resource $font_index, string $encodingfile | bool','imagepsextendfont(':'resource $font_index, float $extend | bool','imagepsfreefont(':'resource $font_index | bool','imagepsloadfont(':'string $filename | resource','imagepsslantfont(':'resource $font_index, float $slant | bool','imagepstext(':'resource $image, string $text, resource $font_index, int $size, int $foreground, int $background, int $x, int $y [, int $space = 0 [, int $tightness = 0 [, float $angle = 0.0 [, int $antialias_steps = 4]]]] | array','imagerectangle(':'resource $image, int $x1, int $y1, int $x2, int $y2, int $color | bool','imagerotate(':'resource $image, float $angle, int $bgd_color [, int $ignore_transparent = 0] | resource','imagesavealpha(':'resource $image, bool $saveflag | bool','imagescale(':'resource $image, int $new_width [, int $new_height = -1 [, int $mode = IMG_BILINEAR_FIXED]] | resource','imagesetbrush(':'resource $image, resource $brush | bool','imagesetinterpolation(':'resource $image [, int $method = IMG_BILINEAR_FIXED] | bool','imagesetpixel(':'resource $image, int $x, int $y, int $color | bool','imagesetstyle(':'resource $image, array $style | bool','imagesetthickness(':'resource $image, int $thickness | bool','imagesettile(':'resource $image, resource $tile | bool','imagestring(':'resource $image, int $font, int $x, int $y, string $string, int $color | bool','imagestringup(':'resource $image, int $font, int $x, int $y, string $string, int $color | bool','imagesx(':'resource $image | int','imagesy(':'resource $image | int','imagetruecolortopalette(':'resource $image, bool $dither, int $ncolors | bool','imagettfbbox(':'float $size, float $angle, string $fontfile, string $text | array','imagettftext(':'resource $image, float $size, float $angle, int $x, int $y, int $color, string $fontfile, string $text | array','imagetypes(':'void | int','imagewbmp(':'resource $image [, string $filename [, int $foreground]] | bool','imagewebp(':'resource $image, string $filename | bool','imagexbm(':'resource $image, string $filename [, int $foreground] | bool','iptcembed(':'string $iptcdata, string $jpeg_file_name [, int $spool] | mixed','iptcparse(':'string $iptcblock | array','jpeg2wbmp(':'string $jpegname, string $wbmpname, int $dest_height, int $dest_width, int $threshold | bool','png2wbmp(':'string $pngname, string $wbmpname, int $dest_height, int $dest_width, int $threshold | bool',}
let php_builtin['functions']['iconv']={'iconv_get_encoding(':'[ string $type = "all"] | mixed','iconv_mime_decode_headers(':'string $encoded_headers [, int $mode = 0 [, string $charset = ini_get("iconv.internal_encoding")]] | array','iconv_mime_decode(':'string $encoded_header [, int $mode = 0 [, string $charset = ini_get("iconv.internal_encoding")]] | string','iconv_mime_encode(':'string $field_name, string $field_value [, array $preferences = NULL] | string','iconv_set_encoding(':'string $type, string $charset | bool','iconv_strlen(':'string $str [, string $charset = ini_get("iconv.internal_encoding")] | int','iconv_strpos(':'string $haystack, string $needle [, int $offset = 0 [, string $charset = ini_get("iconv.internal_encoding")]] | int','iconv_strrpos(':'string $haystack, string $needle [, string $charset = ini_get("iconv.internal_encoding")] | int','iconv_substr(':'string $str, int $offset [, int $length = iconv_strlen($str, $charset) [, string $charset = ini_get("iconv.internal_encoding")]] | string','iconv(':'string $in_charset, string $out_charset, string $str | string','ob_iconv_handler(':'string $contents, int $status | string',}
let php_builtin['functions']['json']={'json_decode(':'string $json [, bool $assoc = false [, int $depth = 512 [, int $options = 0]]] | mixed','json_encode(':'mixed $value [, int $options = 0 [, int $depth = 512]] | string','json_last_error_msg(':'void | string','json_last_error(':'void | int',}
let php_builtin['functions']['libxml']={'libxml_clear_errors(':'void | void','libxml_disable_entity_loader(':'[ bool $disable = true] | bool','libxml_get_errors(':'void | array','libxml_get_last_error(':'void | LibXMLError','libxml_set_external_entity_loader(':'callable $resolver_function | void','libxml_set_streams_context(':'resource $streams_context | void','libxml_use_internal_errors(':'[ bool $use_errors = false] | bool',}
let php_builtin['functions']['multibyte_string']={'mb_check_encoding(':'[ string $var = NULL [, string $encoding = mb_internal_encoding()]] | bool','mb_convert_case(':'string $str, int $mode [, string $encoding = mb_internal_encoding()] | string','mb_convert_encoding(':'string $str, string $to_encoding [, mixed $from_encoding = mb_internal_encoding()] | string','mb_convert_kana(':'string $str [, string $option = "KV" [, string $encoding = mb_internal_encoding()]] | string','mb_convert_variables(':'string $to_encoding, mixed $from_encoding, mixed &$vars [, mixed &$...] | string','mb_decode_mimeheader(':'string $str | string','mb_decode_numericentity(':'string $str, array $convmap [, string $encoding = mb_internal_encoding()] | string','mb_detect_encoding(':'string $str [, mixed $encoding_list = mb_detect_order() [, bool $strict = false]] | string','mb_detect_order(':'[ mixed $encoding_list = mb_detect_order()] | mixed','mb_encode_mimeheader(':'string $str [, string $charset = mb_internal_encoding() [, string $transfer_encoding = "B" [, string $linefeed = "\r\n" [, int $indent = 0]]]] | string','mb_encode_numericentity(':'string $str, array $convmap [, string $encoding = mb_internal_encoding() [, bool $is_hex = FALSE]] | string','mb_encoding_aliases(':'string $encoding | array','mb_ereg_match(':'string $pattern, string $string [, string $option = "msr"] | bool','mb_ereg_replace_callback(':'string $pattern, callable $callback, string $string [, string $option = "msr"] | string','mb_ereg_replace(':'string $pattern, string $replacement, string $string [, string $option = "msr"] | string','mb_ereg_search_getpos(':'void | int','mb_ereg_search_getregs(':'void | array','mb_ereg_search_init(':'string $string [, string $pattern [, string $option = "msr"]] | bool','mb_ereg_search_pos(':'[ string $pattern [, string $option = "ms"]] | array','mb_ereg_search_regs(':'[ string $pattern [, string $option = "ms"]] | array','mb_ereg_search_setpos(':'int $position | bool','mb_ereg_search(':'[ string $pattern [, string $option = "ms"]] | bool','mb_ereg(':'string $pattern, string $string [, array $regs] | int','mb_eregi_replace(':'string $pattern, string $replace, string $string [, string $option = "msri"] | string','mb_eregi(':'string $pattern, string $string [, array $regs] | int','mb_get_info(':'[ string $type = "all"] | mixed','mb_http_input(':'[ string $type = ""] | mixed','mb_http_output(':'[ string $encoding = mb_http_output()] | mixed','mb_internal_encoding(':'[ string $encoding = mb_internal_encoding()] | mixed','mb_language(':'[ string $language = mb_language()] | mixed','mb_list_encodings(':'void | array','mb_output_handler(':'string $contents, int $status | string','mb_parse_str(':'string $encoded_string [, array &$result] | bool','mb_preferred_mime_name(':'string $encoding | string','mb_regex_encoding(':'[ string $encoding = mb_regex_encoding()] | mixed','mb_regex_set_options(':'[ string $options = mb_regex_set_options()] | string','mb_send_mail(':'string $to, string $subject, string $message [, string $additional_headers = NULL [, string $additional_parameter = NULL]] | bool','mb_split(':'string $pattern, string $string [, int $limit = -1] | array','mb_strcut(':'string $str, int $start [, int $length = NULL [, string $encoding = mb_internal_encoding()]] | string','mb_strimwidth(':'string $str, int $start, int $width [, string $trimmarker = "" [, string $encoding = mb_internal_encoding()]] | string','mb_stripos(':'string $haystack, string $needle [, int $offset = 0 [, string $encoding = mb_internal_encoding()]] | int','mb_stristr(':'string $haystack, string $needle [, bool $before_needle = false [, string $encoding = mb_internal_encoding()]] | string','mb_strlen(':'string $str [, string $encoding = mb_internal_encoding()] | mixed','mb_strpos(':'string $haystack, string $needle [, int $offset = 0 [, string $encoding = mb_internal_encoding()]] | int','mb_strrchr(':'string $haystack, string $needle [, bool $part = false [, string $encoding = mb_internal_encoding()]] | string','mb_strrichr(':'string $haystack, string $needle [, bool $part = false [, string $encoding = mb_internal_encoding()]] | string','mb_strripos(':'string $haystack, string $needle [, int $offset = 0 [, string $encoding = mb_internal_encoding()]] | int','mb_strrpos(':'string $haystack, string $needle [, int $offset = 0 [, string $encoding = mb_internal_encoding()]] | int','mb_strstr(':'string $haystack, string $needle [, bool $before_needle = false [, string $encoding = mb_internal_encoding()]] | string','mb_strtolower(':'string $str [, string $encoding = mb_internal_encoding()] | string','mb_strtoupper(':'string $str [, string $encoding = mb_internal_encoding()] | string','mb_strwidth(':'string $str [, string $encoding = mb_internal_encoding()] | int','mb_substitute_character(':'[ mixed $substrchar = mb_substitute_character()] | mixed','mb_substr_count(':'string $haystack, string $needle [, string $encoding = mb_internal_encoding()] | int','mb_substr(':'string $str, int $start [, int $length = NULL [, string $encoding = mb_internal_encoding()]] | string',}
let php_builtin['functions']['mssql']={'mssql_bind(':'resource $stmt, string $param_name, mixed &$var, int $type [, bool $is_output = false [, bool $is_null = false [, int $maxlen = -1]]] | bool','mssql_close(':'[ resource $link_identifier] | bool','mssql_connect(':'[ string $servername [, string $username [, string $password [, bool $new_link = false]]]] | resource','mssql_data_seek(':'resource $result_identifier, int $row_number | bool','mssql_execute(':'resource $stmt [, bool $skip_results = false] | mixed','mssql_fetch_array(':'resource $result [, int $result_type = MSSQL_BOTH] | array','mssql_fetch_assoc(':'resource $result_id | array','mssql_fetch_batch(':'resource $result | int','mssql_fetch_field(':'resource $result [, int $field_offset = -1] | object','mssql_fetch_object(':'resource $result | object','mssql_fetch_row(':'resource $result | array','mssql_field_length(':'resource $result [, int $offset = -1] | int','mssql_field_name(':'resource $result [, int $offset = -1] | string','mssql_field_seek(':'resource $result, int $field_offset | bool','mssql_field_type(':'resource $result [, int $offset = -1] | string','mssql_free_result(':'resource $result | bool','mssql_free_statement(':'resource $stmt | bool','mssql_get_last_message(':'void | string','mssql_guid_string(':'string $binary [, bool $short_format = false] | string','mssql_init(':'string $sp_name [, resource $link_identifier] | resource','mssql_min_error_severity(':'int $severity | void','mssql_min_message_severity(':'int $severity | void','mssql_next_result(':'resource $result_id | bool','mssql_num_fields(':'resource $result | int','mssql_num_rows(':'resource $result | int','mssql_pconnect(':'[ string $servername [, string $username [, string $password [, bool $new_link = false]]]] | resource','mssql_query(':'string $query [, resource $link_identifier [, int $batch_size = 0]] | mixed','mssql_result(':'resource $result, int $row, mixed $field | string','mssql_rows_affected(':'resource $link_identifier | int','mssql_select_db(':'string $database_name [, resource $link_identifier] | bool',}
let php_builtin['functions']['mysql']={'mysql_affected_rows(':'[ resource $link_identifier = NULL] | int','mysql_client_encoding(':'[ resource $link_identifier = NULL] | string','mysql_close(':'[ resource $link_identifier = NULL] | bool','mysql_connect(':'[ string $server = ini_get("mysql.default_host") [, string $username = ini_get("mysql.default_user") [, string $password = ini_get("mysql.default_password") [, bool $new_link = false [, int $client_flags = 0]]]]] | resource','mysql_create_db(':'string $database_name [, resource $link_identifier = NULL] | bool','mysql_data_seek(':'resource $result, int $row_number | bool','mysql_db_name(':'resource $result, int $row [, mixed $field = NULL] | string','mysql_db_query(':'string $database, string $query [, resource $link_identifier = NULL] | resource','mysql_drop_db(':'string $database_name [, resource $link_identifier = NULL] | bool','mysql_errno(':'[ resource $link_identifier = NULL] | int','mysql_error(':'[ resource $link_identifier = NULL] | string','mysql_escape_string(':'string $unescaped_string | string','mysql_fetch_array(':'resource $result [, int $result_type = MYSQL_BOTH] | array','mysql_fetch_assoc(':'resource $result | array','mysql_fetch_field(':'resource $result [, int $field_offset = 0] | object','mysql_fetch_lengths(':'resource $result | array','mysql_fetch_object(':'resource $result [, string $class_name [, array $params]] | object','mysql_fetch_row(':'resource $result | array','mysql_field_flags(':'resource $result, int $field_offset | string','mysql_field_len(':'resource $result, int $field_offset | int','mysql_field_name(':'resource $result, int $field_offset | string','mysql_field_seek(':'resource $result, int $field_offset | bool','mysql_field_table(':'resource $result, int $field_offset | string','mysql_field_type(':'resource $result, int $field_offset | string','mysql_free_result(':'resource $result | bool','mysql_get_client_info(':'void | string','mysql_get_host_info(':'[ resource $link_identifier = NULL] | string','mysql_get_proto_info(':'[ resource $link_identifier = NULL] | int','mysql_get_server_info(':'[ resource $link_identifier = NULL] | string','mysql_info(':'[ resource $link_identifier = NULL] | string','mysql_insert_id(':'[ resource $link_identifier = NULL] | int','mysql_list_dbs(':'[ resource $link_identifier = NULL] | resource','mysql_list_fields(':'string $database_name, string $table_name [, resource $link_identifier = NULL] | resource','mysql_list_processes(':'[ resource $link_identifier = NULL] | resource','mysql_list_tables(':'string $database [, resource $link_identifier = NULL] | resource','mysql_num_fields(':'resource $result | int','mysql_num_rows(':'resource $result | int','mysql_pconnect(':'[ string $server = ini_get("mysql.default_host") [, string $username = ini_get("mysql.default_user") [, string $password = ini_get("mysql.default_password") [, int $client_flags = 0]]]] | resource','mysql_ping(':'[ resource $link_identifier = NULL] | bool','mysql_query(':'string $query [, resource $link_identifier = NULL] | mixed','mysql_real_escape_string(':'string $unescaped_string [, resource $link_identifier = NULL] | string','mysql_result(':'resource $result, int $row [, mixed $field = 0] | string','mysql_select_db(':'string $database_name [, resource $link_identifier = NULL] | bool','mysql_set_charset(':'string $charset [, resource $link_identifier = NULL] | bool','mysql_stat(':'[ resource $link_identifier = NULL] | string','mysql_tablename(':'resource $result, int $i | string','mysql_thread_id(':'[ resource $link_identifier = NULL] | int','mysql_unbuffered_query(':'string $query [, resource $link_identifier = NULL] | resource',}
let php_builtin['functions']['mysqli']={'mysqli_disable_reads_from_master(':'mysqli $link | bool','mysqli_disable_rpl_parse(':'mysqli $link | bool','mysqli_enable_reads_from_master(':'mysqli $link | bool','mysqli_enable_rpl_parse(':'mysqli $link | bool','mysqli_get_cache_stats(':'void | array','mysqli_master_query(':'mysqli $link, string $query | bool','mysqli_rpl_parse_enabled(':'mysqli $link | int','mysqli_rpl_probe(':'mysqli $link | bool','mysqli_slave_query(':'mysqli $link, string $query | bool',}
let php_builtin['functions']['password_hashing']={'password_get_info(':'string $hash | array','password_hash(':'string $password, integer $algo [, array $options] | string','password_needs_rehash(':'string $hash, string $algo [, string $options] | boolean','password_verify(':'string $password, string $hash | boolean',}
let php_builtin['functions']['postgresql']={'pg_affected_rows(':'resource $result | int','pg_cancel_query(':'resource $connection | bool','pg_client_encoding(':'[ resource $connection] | string','pg_close(':'[ resource $connection] | bool','pg_connect(':'string $connection_string [, int $connect_type] | resource','pg_connection_busy(':'resource $connection | bool','pg_connection_reset(':'resource $connection | bool','pg_connection_status(':'resource $connection | int','pg_convert(':'resource $connection, string $table_name, array $assoc_array [, int $options = 0] | array','pg_copy_from(':'resource $connection, string $table_name, array $rows [, string $delimiter [, string $null_as]] | bool','pg_copy_to(':'resource $connection, string $table_name [, string $delimiter [, string $null_as]] | array','pg_dbname(':'[ resource $connection] | string','pg_delete(':'resource $connection, string $table_name, array $assoc_array [, int $options = PGSQL_DML_EXEC] | mixed','pg_end_copy(':'[ resource $connection] | bool','pg_escape_bytea(':'[ resource $connection [, string $data]] | string','pg_escape_identifier(':'[ resource $connection [, string $data]] | string','pg_escape_literal(':'[ resource $connection [, string $data]] | string','pg_escape_string(':'[ resource $connection [, string $data]] | string','pg_execute(':'[ resource $connection [, string $stmtname [, array $params]]] | resource','pg_fetch_all_columns(':'resource $result [, int $column = 0] | array','pg_fetch_all(':'resource $result | array','pg_fetch_array(':'resource $result [, int $row [, int $result_type = PGSQL_BOTH]] | array','pg_fetch_assoc(':'resource $result [, int $row] | array','pg_fetch_object(':'resource $result [, int $row [, int $result_type = PGSQL_ASSOC]] | object','pg_fetch_result(':'resource $result, int $row, mixed $field | string','pg_fetch_row(':'resource $result [, int $row] | array','pg_field_is_null(':'resource $result, int $row, mixed $field | int','pg_field_name(':'resource $result, int $field_number | string','pg_field_num(':'resource $result, string $field_name | int','pg_field_prtlen(':'resource $result, int $row_number, mixed $field_name_or_number | int','pg_field_size(':'resource $result, int $field_number | int','pg_field_table(':'resource $result, int $field_number [, bool $oid_only = false] | mixed','pg_field_type_oid(':'resource $result, int $field_number | int','pg_field_type(':'resource $result, int $field_number | string','pg_free_result(':'resource $result | bool','pg_get_notify(':'resource $connection [, int $result_type] | array','pg_get_pid(':'resource $connection | int','pg_get_result(':'[ resource $connection] | resource','pg_host(':'[ resource $connection] | string','pg_insert(':'resource $connection, string $table_name, array $assoc_array [, int $options = PGSQL_DML_EXEC] | mixed','pg_last_error(':'[ resource $connection] | string','pg_last_notice(':'resource $connection | string','pg_last_oid(':'resource $result | string','pg_lo_close(':'resource $large_object | bool','pg_lo_create(':'[ resource $connection [, mixed $object_id]] | int','pg_lo_export(':'[ resource $connection [, int $oid [, string $pathname]]] | bool','pg_lo_import(':'[ resource $connection [, string $pathname [, mixed $object_id]]] | int','pg_lo_open(':'resource $connection, int $oid, string $mode | resource','pg_lo_read_all(':'resource $large_object | int','pg_lo_read(':'resource $large_object [, int $len = 8192] | string','pg_lo_seek(':'resource $large_object, int $offset [, int $whence = PGSQL_SEEK_CUR] | bool','pg_lo_tell(':'resource $large_object | int','pg_lo_truncate(':'resource $large_object, int $size | bool','pg_lo_unlink(':'resource $connection, int $oid | bool','pg_lo_write(':'resource $large_object, string $data [, int $len] | int','pg_meta_data(':'resource $connection, string $table_name [, bool $extended] | array','pg_num_fields(':'resource $result | int','pg_num_rows(':'resource $result | int','pg_options(':'[ resource $connection] | string','pg_parameter_status(':'[ resource $connection [, string $param_name]] | string','pg_pconnect(':'string $connection_string [, int $connect_type] | resource','pg_ping(':'[ resource $connection] | bool','pg_port(':'[ resource $connection] | int','pg_prepare(':'[ resource $connection [, string $stmtname [, string $query]]] | resource','pg_put_line(':'[ resource $connection [, string $data]] | bool','pg_query_params(':'[ resource $connection [, string $query [, array $params]]] | resource','pg_query(':'[ resource $connection [, string $query]] | resource','pg_result_error_field(':'resource $result, int $fieldcode | string','pg_result_error(':'resource $result | string','pg_result_seek(':'resource $result, int $offset | bool','pg_result_status(':'resource $result [, int $type = PGSQL_STATUS_LONG] | mixed','pg_select(':'resource $connection, string $table_name, array $assoc_array [, int $options = PGSQL_DML_EXEC] | mixed','pg_send_execute(':'resource $connection, string $stmtname, array $params | bool','pg_send_prepare(':'resource $connection, string $stmtname, string $query | bool','pg_send_query_params(':'resource $connection, string $query, array $params | bool','pg_send_query(':'resource $connection, string $query | bool','pg_set_client_encoding(':'[ resource $connection [, string $encoding]] | int','pg_set_error_verbosity(':'[ resource $connection [, int $verbosity]] | int','pg_trace(':'string $pathname [, string $mode = "w" [, resource $connection]] | bool','pg_transaction_status(':'resource $connection | int','pg_tty(':'[ resource $connection] | string','pg_unescape_bytea(':'string $data | string','pg_untrace(':'[ resource $connection] | bool','pg_update(':'resource $connection, string $table_name, array $data, array $condition [, int $options = PGSQL_DML_EXEC] | mixed','pg_version(':'[ resource $connection] | array',}
let php_builtin['functions']['pcre']={'preg_filter(':'mixed $pattern, mixed $replacement, mixed $subject [, int $limit = -1 [, int &$count]] | mixed','preg_grep(':'string $pattern, array $input [, int $flags = 0] | array','preg_last_error(':'void | int','preg_match_all(':'string $pattern, string $subject [, array &$matches [, int $flags = PREG_PATTERN_ORDER [, int $offset = 0]]] | int','preg_match(':'string $pattern, string $subject [, array &$matches [, int $flags = 0 [, int $offset = 0]]] | int','preg_quote(':'string $str [, string $delimiter = NULL] | string','preg_replace_callback(':'mixed $pattern, callable $callback, mixed $subject [, int $limit = -1 [, int &$count]] | mixed','preg_replace(':'mixed $pattern, mixed $replacement, mixed $subject [, int $limit = -1 [, int &$count]] | mixed','preg_split(':'string $pattern, string $subject [, int $limit = -1 [, int $flags = 0]] | array',}
let php_builtin['functions']['sessions']={'session_cache_expire(':'[ string $new_cache_expire] | int','session_cache_limiter(':'[ string $cache_limiter] | string','session_commit(':'session_commit — Alias of session_write_close()','session_decode(':'string $data | bool','session_destroy(':'void | bool','session_encode(':'void | string','session_get_cookie_params(':'void | array','session_id(':'[ string $id] | string','session_is_registered(':'string $name | bool','session_module_name(':'[ string $module] | string','session_name(':'[ string $name] | string','session_regenerate_id(':'[ bool $delete_old_session = false] | bool','session_register_shutdown(':'void | void','session_register(':'mixed $name [, mixed $...] | bool','session_save_path(':'[ string $path] | string','session_set_cookie_params(':'int $lifetime [, string $path [, string $domain [, bool $secure = false [, bool $httponly = false]]]] | void','session_set_save_handler(':'callable $open, callable $close, callable $read, callable $write, callable $destroy, callable $gc | bool','session_start(':'void | bool','session_status(':'void | int','session_unregister(':'string $name | bool','session_unset(':'void | void','session_write_close(':'void | void',}
let php_builtin['functions']['streams']={'set_socket_blocking(':'set_socket_blocking — Alias of stream_set_blocking()','stream_bucket_append(':'resource $brigade, resource $bucket | void','stream_bucket_make_writeable(':'resource $brigade | object','stream_bucket_new(':'resource $stream, string $buffer | object','stream_bucket_prepend(':'resource $brigade, resource $bucket | void','stream_context_create(':'[ array $options [, array $params]] | resource','stream_context_get_default(':'[ array $options] | resource','stream_context_get_options(':'resource $stream_or_context | array','stream_context_get_params(':'resource $stream_or_context | array','stream_context_set_default(':'array $options | resource','stream_context_set_option(':'resource $stream_or_context, string $wrapper, string $option, mixed $value | bool','stream_context_set_params(':'resource $stream_or_context, array $params | bool','stream_copy_to_stream(':'resource $source, resource $dest [, int $maxlength = -1 [, int $offset = 0]] | int','stream_encoding(':'resource $stream [, string $encoding] | bool','stream_filter_append(':'resource $stream, string $filtername [, int $read_write [, mixed $params]] | resource','stream_filter_prepend(':'resource $stream, string $filtername [, int $read_write [, mixed $params]] | resource','stream_filter_register(':'string $filtername, string $classname | bool','stream_filter_remove(':'resource $stream_filter | bool','stream_get_contents(':'resource $handle [, int $maxlength = -1 [, int $offset = -1]] | string','stream_get_filters(':'void | array','stream_get_line(':'resource $handle, int $length [, string $ending] | string','stream_get_meta_data(':'resource $stream | array','stream_get_transports(':'void | array','stream_get_wrappers(':'void | array','stream_is_local(':'mixed $stream_or_url | bool','stream_notification_callback(':'int $notification_code, int $severity, string $message, int $message_code, int $bytes_transferred, int $bytes_max | void','stream_resolve_include_path(':'string $filename | string','stream_select(':'array &$read, array &$write, array &$except, int $tv_sec [, int $tv_usec = 0] | int','stream_set_blocking(':'resource $stream, int $mode | bool','stream_set_chunk_size(':'resource $fp, int $chunk_size | int','stream_set_read_buffer(':'resource $stream, int $buffer | int','stream_set_timeout(':'resource $stream, int $seconds [, int $microseconds = 0] | bool','stream_set_write_buffer(':'resource $stream, int $buffer | int','stream_socket_accept(':'resource $server_socket [, float $timeout = ini_get("default_socket_timeout") [, string &$peername]] | resource','stream_socket_client(':'string $remote_socket [, int &$errno [, string &$errstr [, float $timeout = ini_get("default_socket_timeout") [, int $flags = STREAM_CLIENT_CONNECT [, resource $context]]]]] | resource','stream_socket_enable_crypto(':'resource $stream, bool $enable [, int $crypto_type [, resource $session_stream]] | mixed','stream_socket_get_name(':'resource $handle, bool $want_peer | string','stream_socket_pair(':'int $domain, int $type, int $protocol | array','stream_socket_recvfrom(':'resource $socket, int $length [, int $flags = 0 [, string &$address]] | string','stream_socket_sendto(':'resource $socket, string $data [, int $flags = 0 [, string $address]] | int','stream_socket_server(':'string $local_socket [, int &$errno [, string &$errstr [, int $flags = STREAM_SERVER_BIND | STREAM_SERVER_LISTEN [, resource $context]]]] | resource','stream_socket_shutdown(':'resource $stream, int $how | bool','stream_supports_lock(':'resource $stream | bool','stream_wrapper_register(':'string $protocol, string $classname [, int $flags = 0] | bool','stream_wrapper_restore(':'string $protocol | bool','stream_wrapper_unregister(':'string $protocol | bool',}
let php_builtin['functions']['simplexml']={'simplexml_import_dom(':'DOMNode $node [, string $class_name = "SimpleXMLElement"] | SimpleXMLElement','simplexml_load_file(':'string $filename [, string $class_name = "SimpleXMLElement" [, int $options = 0 [, string $ns = "" [, bool $is_prefix = false]]]] | SimpleXMLElement','simplexml_load_string(':'string $data [, string $class_name = "SimpleXMLElement" [, int $options = 0 [, string $ns = "" [, bool $is_prefix = false]]]] | SimpleXMLElement',}
let php_builtin['functions']['xmlwriter']={'xmlwriter_end_attribute(':'resource $xmlwriter | bool','xmlwriter_end_cdata(':'resource $xmlwriter | bool','xmlwriter_end_comment(':'resource $xmlwriter | bool','xmlwriter_end_document(':'resource $xmlwriter | bool','xmlwriter_end_dtd_attlist(':'resource $xmlwriter | bool','xmlwriter_end_dtd_element(':'resource $xmlwriter | bool','xmlwriter_end_dtd_entity(':'resource $xmlwriter | bool','xmlwriter_end_dtd(':'resource $xmlwriter | bool','xmlwriter_end_element(':'resource $xmlwriter | bool','xmlwriter_end_pi(':'resource $xmlwriter | bool','xmlwriter_flush(':'resource $xmlwriter [, bool $empty = true] | mixed','xmlwriter_full_end_element(':'resource $xmlwriter | bool','xmlwriter_open_memory(':'void | resource','xmlwriter_open_uri(':'string $uri | resource','xmlwriter_output_memory(':'resource $xmlwriter [, bool $flush = true] | string','xmlwriter_set_indent_string(':'resource $xmlwriter, string $indentString | bool','xmlwriter_set_indent(':'resource $xmlwriter, bool $indent | bool','xmlwriter_start_attribute_ns(':'resource $xmlwriter, string $prefix, string $name, string $uri | bool','xmlwriter_start_attribute(':'resource $xmlwriter, string $name | bool','xmlwriter_start_cdata(':'resource $xmlwriter | bool','xmlwriter_start_comment(':'resource $xmlwriter | bool','xmlwriter_start_document(':'resource $xmlwriter [, string $version = 1.0 [, string $encoding = NULL [, string $standalone]]] | bool','xmlwriter_start_dtd_attlist(':'resource $xmlwriter, string $name | bool','xmlwriter_start_dtd_element(':'resource $xmlwriter, string $qualifiedName | bool','xmlwriter_start_dtd_entity(':'resource $xmlwriter, string $name, bool $isparam | bool','xmlwriter_start_dtd(':'resource $xmlwriter, string $qualifiedName [, string $publicId [, string $systemId]] | bool','xmlwriter_start_element_ns(':'resource $xmlwriter, string $prefix, string $name, string $uri | bool','xmlwriter_start_element(':'resource $xmlwriter, string $name | bool','xmlwriter_start_pi(':'resource $xmlwriter, string $target | bool','xmlwriter_text(':'resource $xmlwriter, string $content | bool','xmlwriter_write_attribute_ns(':'resource $xmlwriter, string $prefix, string $name, string $uri, string $content | bool','xmlwriter_write_attribute(':'resource $xmlwriter, string $name, string $value | bool','xmlwriter_write_cdata(':'resource $xmlwriter, string $content | bool','xmlwriter_write_comment(':'resource $xmlwriter, string $content | bool','xmlwriter_write_dtd_attlist(':'resource $xmlwriter, string $name, string $content | bool','xmlwriter_write_dtd_element(':'resource $xmlwriter, string $name, string $content | bool','xmlwriter_write_dtd_entity(':'resource $xmlwriter, string $name, string $content, bool $pe, string $pubid, string $sysid, string $ndataid | bool','xmlwriter_write_dtd(':'resource $xmlwriter, string $name [, string $publicId [, string $systemId [, string $subset]]] | bool','xmlwriter_write_element_ns(':'resource $xmlwriter, string $prefix, string $name, string $uri [, string $content] | bool','xmlwriter_write_element(':'resource $xmlwriter, string $name [, string $content] | bool','xmlwriter_write_pi(':'resource $xmlwriter, string $target, string $content | bool','xmlwriter_write_raw(':'resource $xmlwriter, string $content | bool',}
let php_builtin['functions']['zip']={'zip_close(':'resource $zip | void','zip_entry_close(':'resource $zip_entry | bool','zip_entry_compressedsize(':'resource $zip_entry | int','zip_entry_compressionmethod(':'resource $zip_entry | string','zip_entry_filesize(':'resource $zip_entry | int','zip_entry_name(':'resource $zip_entry | string','zip_entry_open(':'resource $zip, resource $zip_entry [, string $mode] | bool','zip_entry_read(':'resource $zip_entry [, int $length = 1024] | string','zip_open(':'string $filename | resource','zip_read(':'resource $zip | resource',}
let php_builtin['classes']['spl']={'appenditerator':{'name':'AppendIterator','methods':{'__construct':{'signature':'Traversable $iterator','return_type':''},'append':{'signature':'Iterator $iterator | void','return_type':'void'},'current':{'signature':'void | mixed','return_type':'mixed'},'getArrayIterator':{'signature':'void | void','return_type':'void'},'getInnerIterator':{'signature':'void | Traversable','return_type':'Traversable'},'getIteratorIndex':{'signature':'void | int','return_type':'int'},'key':{'signature':'void | scalar','return_type':'scalar'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},},},'arrayiterator':{'name':'ArrayIterator','methods':{'append':{'signature':'mixed $value | void','return_type':'void'},'asort':{'signature':'void | void','return_type':'void'},'__construct':{'signature':'[ mixed $array = array() [, int $flags = 0]]','return_type':''},'count':{'signature':'void | int','return_type':'int'},'current':{'signature':'void | mixed','return_type':'mixed'},'getArrayCopy':{'signature':'void | array','return_type':'array'},'getFlags':{'signature':'void | void','return_type':'void'},'key':{'signature':'void | mixed','return_type':'mixed'},'ksort':{'signature':'void | void','return_type':'void'},'natcasesort':{'signature':'void | void','return_type':'void'},'natsort':{'signature':'void | void','return_type':'void'},'next':{'signature':'void | void','return_type':'void'},'offsetExists':{'signature':'string $index | void','return_type':'void'},'offsetGet':{'signature':'string $index | mixed','return_type':'mixed'},'offsetSet':{'signature':'string $index, string $newval | void','return_type':'void'},'offsetUnset':{'signature':'string $index | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'seek':{'signature':'int $position | void','return_type':'void'},'serialize':{'signature':'void | string','return_type':'string'},'setFlags':{'signature':'string $flags | void','return_type':'void'},'uasort':{'signature':'string $cmp_function | void','return_type':'void'},'uksort':{'signature':'string $cmp_function | void','return_type':'void'},'unserialize':{'signature':'string $serialized | string','return_type':'string'},'valid':{'signature':'void | bool','return_type':'bool'},},},'arrayobject':{'name':'ArrayObject','constants':{'STD_PROP_LIST':'1','ARRAY_AS_PROPS':'2',},'methods':{'__construct':{'signature':'[ mixed $input = [] [, int $flags = 0 [, string $iterator_class = "ArrayIterator"]]]','return_type':''},'append':{'signature':'mixed $value | void','return_type':'void'},'asort':{'signature':'void | void','return_type':'void'},'count':{'signature':'void | int','return_type':'int'},'exchangeArray':{'signature':'mixed $input | array','return_type':'array'},'getArrayCopy':{'signature':'void | array','return_type':'array'},'getFlags':{'signature':'void | int','return_type':'int'},'getIterator':{'signature':'void | ArrayIterator','return_type':'ArrayIterator'},'getIteratorClass':{'signature':'void | string','return_type':'string'},'ksort':{'signature':'void | void','return_type':'void'},'natcasesort':{'signature':'void | void','return_type':'void'},'natsort':{'signature':'void | void','return_type':'void'},'offsetExists':{'signature':'mixed $index | bool','return_type':'bool'},'offsetGet':{'signature':'mixed $index | mixed','return_type':'mixed'},'offsetSet':{'signature':'mixed $index, mixed $newval | void','return_type':'void'},'offsetUnset':{'signature':'mixed $index | void','return_type':'void'},'serialize':{'signature':'void | void','return_type':'void'},'setFlags':{'signature':'int $flags | void','return_type':'void'},'setIteratorClass':{'signature':'string $iterator_class | void','return_type':'void'},'uasort':{'signature':'callable $cmp_function | void','return_type':'void'},'uksort':{'signature':'callable $cmp_function | void','return_type':'void'},'unserialize':{'signature':'string $serialized | void','return_type':'void'},},},'badfunctioncallexception':{'name':'BadFunctionCallException','properties': {'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},'badmethodcallexception':{'name':'BadMethodCallException','properties': {'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},'cachingiterator':{'name':'CachingIterator','constants':{'CALL_TOSTRING':'1','CATCH_GET_CHILD':'16','TOSTRING_USE_KEY':'2','TOSTRING_USE_CURRENT':'4','TOSTRING_USE_INNER':'8','FULL_CACHE':'256',},'methods':{'__construct':{'signature':'Iterator $iterator [, string $flags = self::CALL_TOSTRING]','return_type':''},'count':{'signature':'void | int','return_type':'int'},'current':{'signature':'void | void','return_type':'void'},'getCache':{'signature':'void | void','return_type':'void'},'getFlags':{'signature':'void | void','return_type':'void'},'getInnerIterator':{'signature':'void | Iterator','return_type':'Iterator'},'hasNext':{'signature':'void | void','return_type':'void'},'key':{'signature':'void | scalar','return_type':'scalar'},'next':{'signature':'void | void','return_type':'void'},'offsetExists':{'signature':'string $index | void','return_type':'void'},'offsetGet':{'signature':'string $index | void','return_type':'void'},'offsetSet':{'signature':'string $index, string $newval | void','return_type':'void'},'offsetUnset':{'signature':'string $index | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'setFlags':{'signature':'bitmask $flags | void','return_type':'void'},'__toString':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | void','return_type':'void'},},},'callbackfilteriterator':{'name':'CallbackFilterIterator','methods':{'__construct':{'signature':'Iterator $iterator','return_type':''},'accept':{'signature':'void | bool','return_type':'bool'},'current':{'signature':'void | mixed','return_type':'mixed'},'getInnerIterator':{'signature':'void | Iterator','return_type':'Iterator'},'key':{'signature':'void | mixed','return_type':'mixed'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},},},'directoryiterator':{'name':'DirectoryIterator','methods':{'__construct':{'signature':'string $path','return_type':''},'current':{'signature':'void | DirectoryIterator','return_type':'DirectoryIterator'},'getATime':{'signature':'void | int','return_type':'int'},'getBasename':{'signature':'[ string $suffix] | string','return_type':'string'},'getCTime':{'signature':'void | int','return_type':'int'},'getExtension':{'signature':'void | string','return_type':'string'},'getFilename':{'signature':'void | string','return_type':'string'},'getGroup':{'signature':'void | int','return_type':'int'},'getInode':{'signature':'void | int','return_type':'int'},'getMTime':{'signature':'void | int','return_type':'int'},'getOwner':{'signature':'void | int','return_type':'int'},'getPath':{'signature':'void | string','return_type':'string'},'getPathname':{'signature':'void | string','return_type':'string'},'getPerms':{'signature':'void | int','return_type':'int'},'getSize':{'signature':'void | int','return_type':'int'},'getType':{'signature':'void | string','return_type':'string'},'isDir':{'signature':'void | bool','return_type':'bool'},'isDot':{'signature':'void | bool','return_type':'bool'},'isExecutable':{'signature':'void | bool','return_type':'bool'},'isFile':{'signature':'void | bool','return_type':'bool'},'isLink':{'signature':'void | bool','return_type':'bool'},'isReadable':{'signature':'void | bool','return_type':'bool'},'isWritable':{'signature':'void | bool','return_type':'bool'},'key':{'signature':'void | string','return_type':'string'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'seek':{'signature':'int $position | void','return_type':'void'},'__toString':{'signature':'void | string','return_type':'string'},'valid':{'signature':'void | bool','return_type':'bool'},},},'domainexception':{'name':'DomainException','properties': {'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},'emptyiterator':{'name':'EmptyIterator','methods':{'current':{'signature':'void | void','return_type':'void'},'key':{'signature':'void | void','return_type':'void'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | void','return_type':'void'},},},'filesystemiterator':{'name':'FilesystemIterator','constants':{'CURRENT_AS_PATHNAME':'32','CURRENT_AS_FILEINFO':'0','CURRENT_AS_SELF':'16','CURRENT_MODE_MASK':'240','KEY_AS_PATHNAME':'0','KEY_AS_FILENAME':'256','FOLLOW_SYMLINKS':'512','KEY_MODE_MASK':'3840','NEW_CURRENT_AND_KEY':'256','SKIP_DOTS':'4096','UNIX_PATHS':'8192',},'methods':{'__construct':{'signature':'string $path [, int $flags = FilesystemIterator::KEY_AS_PATHNAME | FilesystemIterator::CURRENT_AS_FILEINFO | FilesystemIterator::SKIP_DOTS]','return_type':''},'current':{'signature':'void | DirectoryIterator','return_type':'DirectoryIterator'},'getFlags':{'signature':'void | int','return_type':'int'},'key':{'signature':'void | string','return_type':'string'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'setFlags':{'signature':'[ int $flags] | void','return_type':'void'},'getATime':{'signature':'void | int','return_type':'int'},'getBasename':{'signature':'[ string $suffix] | string','return_type':'string'},'getCTime':{'signature':'void | int','return_type':'int'},'getExtension':{'signature':'void | string','return_type':'string'},'getFilename':{'signature':'void | string','return_type':'string'},'getGroup':{'signature':'void | int','return_type':'int'},'getInode':{'signature':'void | int','return_type':'int'},'getMTime':{'signature':'void | int','return_type':'int'},'getOwner':{'signature':'void | int','return_type':'int'},'getPath':{'signature':'void | string','return_type':'string'},'getPathname':{'signature':'void | string','return_type':'string'},'getPerms':{'signature':'void | int','return_type':'int'},'getSize':{'signature':'void | int','return_type':'int'},'getType':{'signature':'void | string','return_type':'string'},'isDir':{'signature':'void | bool','return_type':'bool'},'isDot':{'signature':'void | bool','return_type':'bool'},'isExecutable':{'signature':'void | bool','return_type':'bool'},'isFile':{'signature':'void | bool','return_type':'bool'},'isLink':{'signature':'void | bool','return_type':'bool'},'isReadable':{'signature':'void | bool','return_type':'bool'},'isWritable':{'signature':'void | bool','return_type':'bool'},'seek':{'signature':'int $position | void','return_type':'void'},'__toString':{'signature':'void | string','return_type':'string'},'valid':{'signature':'void | bool','return_type':'bool'},},},'filteriterator':{'name':'FilterIterator','methods':{'accept':{'signature':'void | bool','return_type':'bool'},'__construct':{'signature':'Iterator $iterator','return_type':''},'current':{'signature':'void | mixed','return_type':'mixed'},'getInnerIterator':{'signature':'void | Iterator','return_type':'Iterator'},'key':{'signature':'void | mixed','return_type':'mixed'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},},},'globiterator':{'name':'GlobIterator','methods':{'__construct':{'signature':'string $path [, int $flags = FilesystemIterator::KEY_AS_PATHNAME | FilesystemIterator::CURRENT_AS_FILEINFO | FilesystemIterator::SKIP_DOTS]','return_type':''},'count':{'signature':'void | int','return_type':'int'},'current':{'signature':'void | mixed','return_type':'mixed'},'getFlags':{'signature':'void | int','return_type':'int'},'key':{'signature':'void | string','return_type':'string'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'setFlags':{'signature':'[ int $flags] | void','return_type':'void'},},},'infiniteiterator':{'name':'InfiniteIterator','methods':{'__construct':{'signature':'Traversable $iterator','return_type':''},'next':{'signature':'void | void','return_type':'void'},'current':{'signature':'void | mixed','return_type':'mixed'},'getInnerIterator':{'signature':'void | Traversable','return_type':'Traversable'},'key':{'signature':'void | scalar','return_type':'scalar'},'rewind':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},},},'invalidargumentexception':{'name':'InvalidArgumentException','properties': {'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},'iteratoriterator':{'name':'IteratorIterator','methods':{'__construct':{'signature':'Traversable $iterator','return_type':''},'current':{'signature':'void | mixed','return_type':'mixed'},'getInnerIterator':{'signature':'void | Traversable','return_type':'Traversable'},'key':{'signature':'void | scalar','return_type':'scalar'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},},},'lengthexception':{'name':'LengthException','properties': {'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},'limititerator':{'name':'LimitIterator','methods':{'__construct':{'signature':'Iterator $iterator [, int $offset = 0 [, int $count = -1]]','return_type':''},'current':{'signature':'void | mixed','return_type':'mixed'},'getInnerIterator':{'signature':'void | Iterator','return_type':'Iterator'},'getPosition':{'signature':'void | int','return_type':'int'},'key':{'signature':'void | mixed','return_type':'mixed'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'seek':{'signature':'int $position | int','return_type':'int'},'valid':{'signature':'void | bool','return_type':'bool'},},},'logicexception':{'name':'LogicException','properties': {'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},'multipleiterator':{'name':'MultipleIterator','constants':{'MIT_NEED_ANY':'0','MIT_NEED_ALL':'1','MIT_KEYS_NUMERIC':'0','MIT_KEYS_ASSOC':'2',},'methods':{'__construct':{'signature':'[ int $flags = MultipleIterator::MIT_NEED_ALL|MultipleIterator::MIT_KEYS_NUMERIC]','return_type':''},'attachIterator':{'signature':'Iterator $iterator [, string $infos] | void','return_type':'void'},'containsIterator':{'signature':'Iterator $iterator | void','return_type':'void'},'countIterators':{'signature':'void | void','return_type':'void'},'current':{'signature':'void | array','return_type':'array'},'detachIterator':{'signature':'Iterator $iterator | void','return_type':'void'},'getFlags':{'signature':'void | void','return_type':'void'},'key':{'signature':'void | array','return_type':'array'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'setFlags':{'signature':'int $flags | void','return_type':'void'},'valid':{'signature':'void | void','return_type':'void'},},},'norewinditerator':{'name':'NoRewindIterator','methods':{'__construct':{'signature':'Traversable $iterator','return_type':''},'current':{'signature':'void | mixed','return_type':'mixed'},'getInnerIterator':{'signature':'void | Traversable','return_type':'Traversable'},'key':{'signature':'void | scalar','return_type':'scalar'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},},},'outofboundsexception':{'name':'OutOfBoundsException','properties': {'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},'outofrangeexception':{'name':'OutOfRangeException','properties': {'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},'overflowexception':{'name':'OverflowException','properties': {'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},'parentiterator':{'name':'ParentIterator','methods':{'accept':{'signature':'void | bool','return_type':'bool'},'__construct':{'signature':'RecursiveIterator $iterator','return_type':''},'getChildren':{'signature':'void | ParentIterator','return_type':'ParentIterator'},'hasChildren':{'signature':'void | bool','return_type':'bool'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},},},'rangeexception':{'name':'RangeException','properties': {'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},'recursivearrayiterator':{'name':'RecursiveArrayIterator','methods':{'getChildren':{'signature':'void | RecursiveArrayIterator','return_type':'RecursiveArrayIterator'},'hasChildren':{'signature':'void | bool','return_type':'bool'},'append':{'signature':'mixed $value | void','return_type':'void'},'asort':{'signature':'void | void','return_type':'void'},'__construct':{'signature':'[ mixed $array = array() [, int $flags = 0]]','return_type':''},'count':{'signature':'void | int','return_type':'int'},'current':{'signature':'void | mixed','return_type':'mixed'},'getArrayCopy':{'signature':'void | array','return_type':'array'},'getFlags':{'signature':'void | void','return_type':'void'},'key':{'signature':'void | mixed','return_type':'mixed'},'ksort':{'signature':'void | void','return_type':'void'},'natcasesort':{'signature':'void | void','return_type':'void'},'natsort':{'signature':'void | void','return_type':'void'},'next':{'signature':'void | void','return_type':'void'},'offsetExists':{'signature':'string $index | void','return_type':'void'},'offsetGet':{'signature':'string $index | mixed','return_type':'mixed'},'offsetSet':{'signature':'string $index, string $newval | void','return_type':'void'},'offsetUnset':{'signature':'string $index | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'seek':{'signature':'int $position | void','return_type':'void'},'serialize':{'signature':'void | string','return_type':'string'},'setFlags':{'signature':'string $flags | void','return_type':'void'},'uasort':{'signature':'string $cmp_function | void','return_type':'void'},'uksort':{'signature':'string $cmp_function | void','return_type':'void'},'unserialize':{'signature':'string $serialized | string','return_type':'string'},'valid':{'signature':'void | bool','return_type':'bool'},},},'recursivecachingiterator':{'name':'RecursiveCachingIterator','methods':{'__construct':{'signature':'Iterator $iterator [, string $flags = self::CALL_TOSTRING]','return_type':''},'getChildren':{'signature':'void | RecursiveCachingIterator','return_type':'RecursiveCachingIterator'},'hasChildren':{'signature':'void | bool','return_type':'bool'},'count':{'signature':'void | int','return_type':'int'},'current':{'signature':'void | void','return_type':'void'},'getCache':{'signature':'void | void','return_type':'void'},'getFlags':{'signature':'void | void','return_type':'void'},'getInnerIterator':{'signature':'void | Iterator','return_type':'Iterator'},'hasNext':{'signature':'void | void','return_type':'void'},'key':{'signature':'void | scalar','return_type':'scalar'},'next':{'signature':'void | void','return_type':'void'},'offsetExists':{'signature':'string $index | void','return_type':'void'},'offsetGet':{'signature':'string $index | void','return_type':'void'},'offsetSet':{'signature':'string $index, string $newval | void','return_type':'void'},'offsetUnset':{'signature':'string $index | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'setFlags':{'signature':'bitmask $flags | void','return_type':'void'},'__toString':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | void','return_type':'void'},},},'recursivecallbackfilteriterator':{'name':'RecursiveCallbackFilterIterator','methods':{'__construct':{'signature':'RecursiveIterator $iterator, string $callback','return_type':''},'getChildren':{'signature':'void | RecursiveCallbackFilterIterator','return_type':'RecursiveCallbackFilterIterator'},'hasChildren':{'signature':'void | void','return_type':'void'},'accept':{'signature':'void | string','return_type':'string'},},},'recursivedirectoryiterator':{'name':'RecursiveDirectoryIterator','methods':{'__construct':{'signature':'string $path [, int $flags = FilesystemIterator::KEY_AS_PATHNAME | FilesystemIterator::CURRENT_AS_FILEINFO | FilesystemIterator::SKIP_DOTS]','return_type':''},'getChildren':{'signature':'void | mixed','return_type':'mixed'},'getSubPath':{'signature':'void | string','return_type':'string'},'getSubPathname':{'signature':'void | string','return_type':'string'},'hasChildren':{'signature':'[ bool $allow_links = false] | bool','return_type':'bool'},'key':{'signature':'void | string','return_type':'string'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'current':{'signature':'void | mixed','return_type':'mixed'},'getFlags':{'signature':'void | int','return_type':'int'},'setFlags':{'signature':'[ int $flags] | void','return_type':'void'},},},'recursivefilteriterator':{'name':'RecursiveFilterIterator','methods':{'__construct':{'signature':'Iterator $iterator','return_type':''},'getChildren':{'signature':'void | void','return_type':'void'},'hasChildren':{'signature':'void | void','return_type':'void'},'accept':{'signature':'void | bool','return_type':'bool'},'current':{'signature':'void | mixed','return_type':'mixed'},'getInnerIterator':{'signature':'void | Iterator','return_type':'Iterator'},'key':{'signature':'void | mixed','return_type':'mixed'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},},},'recursiveiteratoriterator':{'name':'RecursiveIteratorIterator','constants':{'LEAVES_ONLY':'0','SELF_FIRST':'1','CHILD_FIRST':'2','CATCH_GET_CHILD':'16',},'methods':{'beginChildren':{'signature':'void | void','return_type':'void'},'beginIteration':{'signature':'void | void','return_type':'void'},'callGetChildren':{'signature':'void | RecursiveIterator','return_type':'RecursiveIterator'},'callHasChildren':{'signature':'void | bool','return_type':'bool'},'__construct':{'signature':'Traversable $iterator [, int $mode = RecursiveIteratorIterator::LEAVES_ONLY [, int $flags = 0]]','return_type':''},'current':{'signature':'void | mixed','return_type':'mixed'},'endChildren':{'signature':'void | void','return_type':'void'},'endIteration':{'signature':'void | void','return_type':'void'},'getDepth':{'signature':'void | int','return_type':'int'},'getInnerIterator':{'signature':'void | Iterator','return_type':'Iterator'},'getMaxDepth':{'signature':'void | mixed','return_type':'mixed'},'getSubIterator':{'signature':'[ int $level] | RecursiveIterator','return_type':'RecursiveIterator'},'key':{'signature':'void | mixed','return_type':'mixed'},'next':{'signature':'void | void','return_type':'void'},'nextElement':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'setMaxDepth':{'signature':'[ string $max_depth = -1] | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},},},'recursiveregexiterator':{'name':'RecursiveRegexIterator','methods':{'__construct':{'signature':'RecursiveIterator $iterator, string $regex [, int $mode = self::MATCH [, int $flags = 0 [, int $preg_flags = 0]]]','return_type':''},'getChildren':{'signature':'void | RecursiveIterator','return_type':'RecursiveIterator'},'hasChildren':{'signature':'void | bool','return_type':'bool'},'accept':{'signature':'void | bool','return_type':'bool'},'getFlags':{'signature':'void | int','return_type':'int'},'getMode':{'signature':'void | int','return_type':'int'},'getPregFlags':{'signature':'void | int','return_type':'int'},'getRegex':{'signature':'void | string','return_type':'string'},'setFlags':{'signature':'int $flags | void','return_type':'void'},'setMode':{'signature':'int $mode | void','return_type':'void'},'setPregFlags':{'signature':'int $preg_flags | void','return_type':'void'},},},'recursivetreeiterator':{'name':'RecursiveTreeIterator','constants':{'BYPASS_CURRENT':'4','BYPASS_KEY':'8','PREFIX_LEFT':'0','PREFIX_MID_HAS_NEXT':'1','PREFIX_MID_LAST':'2','PREFIX_END_HAS_NEXT':'3','PREFIX_END_LAST':'4','PREFIX_RIGHT':'5',},'methods':{'beginChildren':{'signature':'void | void','return_type':'void'},'beginIteration':{'signature':'void | void','return_type':'void'},'callGetChildren':{'signature':'void | RecursiveIterator','return_type':'RecursiveIterator'},'callHasChildren':{'signature':'void | bool','return_type':'bool'},'__construct':{'signature':'Traversable $iterator [, int $mode = RecursiveIteratorIterator::LEAVES_ONLY [, int $flags = 0]]','return_type':''},'current':{'signature':'void | mixed','return_type':'mixed'},'endChildren':{'signature':'void | void','return_type':'void'},'endIteration':{'signature':'void | void','return_type':'void'},'getEntry':{'signature':'void | string','return_type':'string'},'getPostfix':{'signature':'void | void','return_type':'void'},'getPrefix':{'signature':'void | string','return_type':'string'},'key':{'signature':'void | mixed','return_type':'mixed'},'next':{'signature':'void | void','return_type':'void'},'nextElement':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'setPrefixPart':{'signature':'int $part, string $value | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},'getDepth':{'signature':'void | int','return_type':'int'},'getInnerIterator':{'signature':'void | iterator','return_type':'iterator'},'getMaxDepth':{'signature':'void | mixed','return_type':'mixed'},'getSubIterator':{'signature':'[ int $level] | RecursiveIterator','return_type':'RecursiveIterator'},'setMaxDepth':{'signature':'[ string $max_depth = -1] | void','return_type':'void'},},},'regexiterator':{'name':'RegexIterator','constants':{'MATCH':'0','GET_MATCH':'1','ALL_MATCHES':'2','SPLIT':'3','REPLACE':'4','USE_KEY':'1',},'methods':{'__construct':{'signature':'Iterator $iterator','return_type':''},'accept':{'signature':'void | bool','return_type':'bool'},'getFlags':{'signature':'void | int','return_type':'int'},'getMode':{'signature':'void | int','return_type':'int'},'getPregFlags':{'signature':'void | int','return_type':'int'},'getRegex':{'signature':'void | string','return_type':'string'},'setFlags':{'signature':'int $flags | void','return_type':'void'},'setMode':{'signature':'int $mode | void','return_type':'void'},'setPregFlags':{'signature':'int $preg_flags | void','return_type':'void'},'current':{'signature':'void | mixed','return_type':'mixed'},'getInnerIterator':{'signature':'void | Iterator','return_type':'Iterator'},'key':{'signature':'void | mixed','return_type':'mixed'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},},},'runtimeexception':{'name':'RuntimeException','properties': {'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},'spldoublylinkedlist':{'name':'SplDoublyLinkedList','methods':{'__construct':{'signature':'void','return_type':''},'bottom':{'signature':'void | mixed','return_type':'mixed'},'count':{'signature':'void | int','return_type':'int'},'current':{'signature':'void | mixed','return_type':'mixed'},'getIteratorMode':{'signature':'void | int','return_type':'int'},'isEmpty':{'signature':'void | bool','return_type':'bool'},'key':{'signature':'void | mixed','return_type':'mixed'},'next':{'signature':'void | void','return_type':'void'},'offsetExists':{'signature':'mixed $index | bool','return_type':'bool'},'offsetGet':{'signature':'mixed $index | mixed','return_type':'mixed'},'offsetSet':{'signature':'mixed $index, mixed $newval | void','return_type':'void'},'offsetUnset':{'signature':'mixed $index | void','return_type':'void'},'pop':{'signature':'void | mixed','return_type':'mixed'},'prev':{'signature':'void | void','return_type':'void'},'push':{'signature':'mixed $value | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'serialize':{'signature':'void | string','return_type':'string'},'setIteratorMode':{'signature':'int $mode | void','return_type':'void'},'shift':{'signature':'void | mixed','return_type':'mixed'},'top':{'signature':'void | mixed','return_type':'mixed'},'unserialize':{'signature':'string $serialized | void','return_type':'void'},'unshift':{'signature':'mixed $value | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},},},'splfileinfo':{'name':'SplFileInfo','methods':{'__construct':{'signature':'string $file_name','return_type':''},'getATime':{'signature':'void | int','return_type':'int'},'getBasename':{'signature':'[ string $suffix] | string','return_type':'string'},'getCTime':{'signature':'void | int','return_type':'int'},'getExtension':{'signature':'void | string','return_type':'string'},'getFileInfo':{'signature':'[ string $class_name] | SplFileInfo','return_type':'SplFileInfo'},'getFilename':{'signature':'void | string','return_type':'string'},'getGroup':{'signature':'void | int','return_type':'int'},'getInode':{'signature':'void | int','return_type':'int'},'getLinkTarget':{'signature':'void | string','return_type':'string'},'getMTime':{'signature':'void | int','return_type':'int'},'getOwner':{'signature':'void | int','return_type':'int'},'getPath':{'signature':'void | string','return_type':'string'},'getPathInfo':{'signature':'[ string $class_name] | SplFileInfo','return_type':'SplFileInfo'},'getPathname':{'signature':'void | string','return_type':'string'},'getPerms':{'signature':'void | int','return_type':'int'},'getRealPath':{'signature':'void | string','return_type':'string'},'getSize':{'signature':'void | int','return_type':'int'},'getType':{'signature':'void | string','return_type':'string'},'isDir':{'signature':'void | bool','return_type':'bool'},'isExecutable':{'signature':'void | bool','return_type':'bool'},'isFile':{'signature':'void | bool','return_type':'bool'},'isLink':{'signature':'void | bool','return_type':'bool'},'isReadable':{'signature':'void | bool','return_type':'bool'},'isWritable':{'signature':'void | bool','return_type':'bool'},'openFile':{'signature':'[ string $open_mode = r [, bool $use_include_path = false [, resource $context = NULL]]] | SplFileObject','return_type':'SplFileObject'},'setFileClass':{'signature':'[ string $class_name] | void','return_type':'void'},'setInfoClass':{'signature':'[ string $class_name] | void','return_type':'void'},'__toString':{'signature':'void | void','return_type':'void'},},},'splfileobject':{'name':'SplFileObject','constants':{'DROP_NEW_LINE':'1','READ_AHEAD':'2','SKIP_EMPTY':'4','READ_CSV':'8',},'methods':{'__construct':{'signature':'string $file_name','return_type':''},'current':{'signature':'void | string|array','return_type':'string|array'},'eof':{'signature':'void | bool','return_type':'bool'},'fflush':{'signature':'void | bool','return_type':'bool'},'fgetc':{'signature':'void | string','return_type':'string'},'fgetcsv':{'signature':'[ string $delimiter = "," [, string $enclosure = "\"" [, string $escape = "\\"]]] | array','return_type':'array'},'fgets':{'signature':'void | string','return_type':'string'},'fgetss':{'signature':'[ string $allowable_tags] | string','return_type':'string'},'flock':{'signature':'int $operation [, int &$wouldblock] | bool','return_type':'bool'},'fpassthru':{'signature':'void | int','return_type':'int'},'fputcsv':{'signature':'array $fields [, string $delimiter = '','' [, string $enclosure = ''"'']] | int','return_type':'int'},'fscanf':{'signature':'string $format [, mixed &$...] | mixed','return_type':'mixed'},'fseek':{'signature':'int $offset [, int $whence = SEEK_SET] | int','return_type':'int'},'fstat':{'signature':'void | array','return_type':'array'},'ftell':{'signature':'void | int','return_type':'int'},'ftruncate':{'signature':'int $size | bool','return_type':'bool'},'fwrite':{'signature':'string $str [, int $length] | int','return_type':'int'},'getChildren':{'signature':'void | void','return_type':'void'},'getCsvControl':{'signature':'void | array','return_type':'array'},'getFlags':{'signature':'void | int','return_type':'int'},'getMaxLineLen':{'signature':'void | int','return_type':'int'},'hasChildren':{'signature':'void | bool','return_type':'bool'},'key':{'signature':'void | int','return_type':'int'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'seek':{'signature':'int $line_pos | void','return_type':'void'},'setCsvControl':{'signature':'[ string $delimiter = "," [, string $enclosure = "\"" [, string $escape = "\\"]]] | void','return_type':'void'},'setFlags':{'signature':'int $flags | void','return_type':'void'},'setMaxLineLen':{'signature':'int $max_len | void','return_type':'void'},'__toString':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},'getATime':{'signature':'void | int','return_type':'int'},'getBasename':{'signature':'[ string $suffix] | string','return_type':'string'},'getCTime':{'signature':'void | int','return_type':'int'},'getExtension':{'signature':'void | string','return_type':'string'},'getFileInfo':{'signature':'[ string $class_name] | SplFileInfo','return_type':'SplFileInfo'},'getFilename':{'signature':'void | string','return_type':'string'},'getGroup':{'signature':'void | int','return_type':'int'},'getInode':{'signature':'void | int','return_type':'int'},'getLinkTarget':{'signature':'void | string','return_type':'string'},'getMTime':{'signature':'void | int','return_type':'int'},'getOwner':{'signature':'void | int','return_type':'int'},'getPath':{'signature':'void | string','return_type':'string'},'getPathInfo':{'signature':'[ string $class_name] | SplFileInfo','return_type':'SplFileInfo'},'getPathname':{'signature':'void | string','return_type':'string'},'getPerms':{'signature':'void | int','return_type':'int'},'getRealPath':{'signature':'void | string','return_type':'string'},'getSize':{'signature':'void | int','return_type':'int'},'getType':{'signature':'void | string','return_type':'string'},'isDir':{'signature':'void | bool','return_type':'bool'},'isExecutable':{'signature':'void | bool','return_type':'bool'},'isFile':{'signature':'void | bool','return_type':'bool'},'isLink':{'signature':'void | bool','return_type':'bool'},'isReadable':{'signature':'void | bool','return_type':'bool'},'isWritable':{'signature':'void | bool','return_type':'bool'},'openFile':{'signature':'[ string $open_mode = r [, bool $use_include_path = false [, resource $context = NULL]]] | SplFileObject','return_type':'SplFileObject'},'setFileClass':{'signature':'[ string $class_name] | void','return_type':'void'},'setInfoClass':{'signature':'[ string $class_name] | void','return_type':'void'},},},'splfixedarray':{'name':'SplFixedArray','methods':{'__construct':{'signature':'[ int $size = 0]','return_type':''},'count':{'signature':'void | int','return_type':'int'},'current':{'signature':'void | mixed','return_type':'mixed'},'getSize':{'signature':'void | int','return_type':'int'},'key':{'signature':'void | int','return_type':'int'},'next':{'signature':'void | void','return_type':'void'},'offsetExists':{'signature':'int $index | bool','return_type':'bool'},'offsetGet':{'signature':'int $index | mixed','return_type':'mixed'},'offsetSet':{'signature':'int $index, mixed $newval | void','return_type':'void'},'offsetUnset':{'signature':'int $index | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'setSize':{'signature':'int $size | int','return_type':'int'},'toArray':{'signature':'void | array','return_type':'array'},'valid':{'signature':'void | bool','return_type':'bool'},'__wakeup':{'signature':'void | void','return_type':'void'},},'static_methods':{'fromArray':{'signature':'array $array [, bool $save_indexes = true] | SplFixedArray','return_type':'SplFixedArray'},},},'splheap':{'name':'SplHeap','methods':{'__construct':{'signature':'void','return_type':''},'compare':{'signature':'mixed $value1, mixed $value2 | int','return_type':'int'},'count':{'signature':'void | int','return_type':'int'},'current':{'signature':'void | mixed','return_type':'mixed'},'extract':{'signature':'void | mixed','return_type':'mixed'},'insert':{'signature':'mixed $value | void','return_type':'void'},'isEmpty':{'signature':'void | bool','return_type':'bool'},'key':{'signature':'void | mixed','return_type':'mixed'},'next':{'signature':'void | void','return_type':'void'},'recoverFromCorruption':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'top':{'signature':'void | mixed','return_type':'mixed'},'valid':{'signature':'void | bool','return_type':'bool'},},},'splmaxheap':{'name':'SplMaxHeap','methods':{'compare':{'signature':'mixed $value1, mixed $value2 | int','return_type':'int'},'count':{'signature':'void | int','return_type':'int'},'current':{'signature':'void | mixed','return_type':'mixed'},'extract':{'signature':'void | mixed','return_type':'mixed'},'insert':{'signature':'mixed $value | void','return_type':'void'},'isEmpty':{'signature':'void | bool','return_type':'bool'},'key':{'signature':'void | mixed','return_type':'mixed'},'next':{'signature':'void | void','return_type':'void'},'recoverFromCorruption':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'top':{'signature':'void | mixed','return_type':'mixed'},'valid':{'signature':'void | bool','return_type':'bool'},},},'splminheap':{'name':'SplMinHeap','methods':{'compare':{'signature':'mixed $value1, mixed $value2 | int','return_type':'int'},'count':{'signature':'void | int','return_type':'int'},'current':{'signature':'void | mixed','return_type':'mixed'},'extract':{'signature':'void | mixed','return_type':'mixed'},'insert':{'signature':'mixed $value | void','return_type':'void'},'isEmpty':{'signature':'void | bool','return_type':'bool'},'key':{'signature':'void | mixed','return_type':'mixed'},'next':{'signature':'void | void','return_type':'void'},'recoverFromCorruption':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'top':{'signature':'void | mixed','return_type':'mixed'},'valid':{'signature':'void | bool','return_type':'bool'},},},'splobjectstorage':{'name':'SplObjectStorage','methods':{'addAll':{'signature':'SplObjectStorage $storage | void','return_type':'void'},'attach':{'signature':'object $object [, mixed $data = NULL] | void','return_type':'void'},'contains':{'signature':'object $object | bool','return_type':'bool'},'count':{'signature':'void | int','return_type':'int'},'current':{'signature':'void | object','return_type':'object'},'detach':{'signature':'object $object | void','return_type':'void'},'getHash':{'signature':'object $object | string','return_type':'string'},'getInfo':{'signature':'void | mixed','return_type':'mixed'},'key':{'signature':'void | int','return_type':'int'},'next':{'signature':'void | void','return_type':'void'},'offsetExists':{'signature':'object $object | bool','return_type':'bool'},'offsetGet':{'signature':'object $object | mixed','return_type':'mixed'},'offsetSet':{'signature':'object $object [, mixed $data = NULL] | void','return_type':'void'},'offsetUnset':{'signature':'object $object | void','return_type':'void'},'removeAll':{'signature':'SplObjectStorage $storage | void','return_type':'void'},'removeAllExcept':{'signature':'SplObjectStorage $storage | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'serialize':{'signature':'void | string','return_type':'string'},'setInfo':{'signature':'mixed $data | void','return_type':'void'},'unserialize':{'signature':'string $serialized | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},},},'splpriorityqueue':{'name':'SplPriorityQueue','methods':{'__construct':{'signature':'void','return_type':''},'compare':{'signature':'mixed $priority1, mixed $priority2 | int','return_type':'int'},'count':{'signature':'void | int','return_type':'int'},'current':{'signature':'void | mixed','return_type':'mixed'},'extract':{'signature':'void | mixed','return_type':'mixed'},'insert':{'signature':'mixed $value, mixed $priority | void','return_type':'void'},'isEmpty':{'signature':'void | bool','return_type':'bool'},'key':{'signature':'void | mixed','return_type':'mixed'},'next':{'signature':'void | void','return_type':'void'},'recoverFromCorruption':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'setExtractFlags':{'signature':'int $flags | void','return_type':'void'},'top':{'signature':'void | mixed','return_type':'mixed'},'valid':{'signature':'void | bool','return_type':'bool'},},},'splqueue':{'name':'SplQueue','methods':{'__construct':{'signature':'void','return_type':''},'dequeue':{'signature':'void | mixed','return_type':'mixed'},'enqueue':{'signature':'mixed $value | void','return_type':'void'},'setIteratorMode':{'signature':'int $mode | void','return_type':'void'},'bottom':{'signature':'void | mixed','return_type':'mixed'},'count':{'signature':'void | int','return_type':'int'},'current':{'signature':'void | mixed','return_type':'mixed'},'getIteratorMode':{'signature':'void | int','return_type':'int'},'isEmpty':{'signature':'void | bool','return_type':'bool'},'key':{'signature':'void | mixed','return_type':'mixed'},'next':{'signature':'void | void','return_type':'void'},'offsetExists':{'signature':'mixed $index | bool','return_type':'bool'},'offsetGet':{'signature':'mixed $index | mixed','return_type':'mixed'},'offsetSet':{'signature':'mixed $index, mixed $newval | void','return_type':'void'},'offsetUnset':{'signature':'mixed $index | void','return_type':'void'},'pop':{'signature':'void | mixed','return_type':'mixed'},'prev':{'signature':'void | void','return_type':'void'},'push':{'signature':'mixed $value | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'serialize':{'signature':'void | string','return_type':'string'},'shift':{'signature':'void | mixed','return_type':'mixed'},'top':{'signature':'void | mixed','return_type':'mixed'},'unserialize':{'signature':'string $serialized | void','return_type':'void'},'unshift':{'signature':'mixed $value | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},},},'splstack':{'name':'SplStack','methods':{'__construct':{'signature':'void','return_type':''},'setIteratorMode':{'signature':'int $mode | void','return_type':'void'},'bottom':{'signature':'void | mixed','return_type':'mixed'},'count':{'signature':'void | int','return_type':'int'},'current':{'signature':'void | mixed','return_type':'mixed'},'getIteratorMode':{'signature':'void | int','return_type':'int'},'isEmpty':{'signature':'void | bool','return_type':'bool'},'key':{'signature':'void | mixed','return_type':'mixed'},'next':{'signature':'void | void','return_type':'void'},'offsetExists':{'signature':'mixed $index | bool','return_type':'bool'},'offsetGet':{'signature':'mixed $index | mixed','return_type':'mixed'},'offsetSet':{'signature':'mixed $index, mixed $newval | void','return_type':'void'},'offsetUnset':{'signature':'mixed $index | void','return_type':'void'},'pop':{'signature':'void | mixed','return_type':'mixed'},'prev':{'signature':'void | void','return_type':'void'},'push':{'signature':'mixed $value | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'serialize':{'signature':'void | string','return_type':'string'},'shift':{'signature':'void | mixed','return_type':'mixed'},'top':{'signature':'void | mixed','return_type':'mixed'},'unserialize':{'signature':'string $serialized | void','return_type':'void'},'unshift':{'signature':'mixed $value | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},},},'spltempfileobject':{'name':'SplTempFileObject','methods':{'__construct':{'signature':'string $filename [, string $open_mode = "r" [, bool $use_include_path = false [, resource $context]]]','return_type':''},'current':{'signature':'void | string|array','return_type':'string|array'},'eof':{'signature':'void | bool','return_type':'bool'},'fflush':{'signature':'void | bool','return_type':'bool'},'fgetc':{'signature':'void | string','return_type':'string'},'fgetcsv':{'signature':'[ string $delimiter = "," [, string $enclosure = "\"" [, string $escape = "\\"]]] | array','return_type':'array'},'fgets':{'signature':'void | string','return_type':'string'},'fgetss':{'signature':'[ string $allowable_tags] | string','return_type':'string'},'flock':{'signature':'int $operation [, int &$wouldblock] | bool','return_type':'bool'},'fpassthru':{'signature':'void | int','return_type':'int'},'fputcsv':{'signature':'array $fields [, string $delimiter = '','' [, string $enclosure = ''"'']] | int','return_type':'int'},'fscanf':{'signature':'string $format [, mixed &$...] | mixed','return_type':'mixed'},'fseek':{'signature':'int $offset [, int $whence = SEEK_SET] | int','return_type':'int'},'fstat':{'signature':'void | array','return_type':'array'},'ftell':{'signature':'void | int','return_type':'int'},'ftruncate':{'signature':'int $size | bool','return_type':'bool'},'fwrite':{'signature':'string $str [, int $length] | int','return_type':'int'},'getChildren':{'signature':'void | void','return_type':'void'},'getCsvControl':{'signature':'void | array','return_type':'array'},'getFlags':{'signature':'void | int','return_type':'int'},'getMaxLineLen':{'signature':'void | int','return_type':'int'},'hasChildren':{'signature':'void | bool','return_type':'bool'},'key':{'signature':'void | int','return_type':'int'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'seek':{'signature':'int $line_pos | void','return_type':'void'},'setCsvControl':{'signature':'[ string $delimiter = "," [, string $enclosure = "\"" [, string $escape = "\\"]]] | void','return_type':'void'},'setFlags':{'signature':'int $flags | void','return_type':'void'},'setMaxLineLen':{'signature':'int $max_len | void','return_type':'void'},'__toString':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},},},'underflowexception':{'name':'UnderflowException','properties': {'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},'unexpectedvalueexception':{'name':'UnexpectedValueException','properties': {'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},}
let php_builtin['classes']['predefined_interfaces_and_classes']={'closure':{'name':'Closure','methods':{'__construct':{'signature':'void','return_type':''},'bindTo':{'signature':'object $newthis [, mixed $newscope = ''static''] | Closure','return_type':'Closure'},},'static_methods':{'bind':{'signature':'Closure $closure, object $newthis [, mixed $newscope = ''static''] | Closure','return_type':'Closure'},},},'generator':{'name':'Generator','methods':{'current':{'signature':'void | mixed','return_type':'mixed'},'key':{'signature':'void | mixed','return_type':'mixed'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'send':{'signature':'mixed $value | mixed','return_type':'mixed'},'throw':{'signature':'Exception $exception | mixed','return_type':'mixed'},'valid':{'signature':'void | bool','return_type':'bool'},'__wakeup':{'signature':'void | void','return_type':'void'},},},}
let php_builtin['classes']['curl']={'curlfile':{'name':'CURLFile','properties': {'name':{'initializer':'','type':''},'mime':{'initializer':'','type':''},'postname':{'initializer':'','type':''},},'methods':{'__construct':{'signature':'string $filename [, string $mimetype [, string $postname]]','return_type':''},'getFilename':{'signature':'void | string','return_type':'string'},'getMimeType':{'signature':'void | string','return_type':'string'},'getPostFilename':{'signature':'void | string','return_type':'string'},'setMimeType':{'signature':'string $mime | void','return_type':'void'},'setPostFilename':{'signature':'string $postname | void','return_type':'void'},'__wakeup':{'signature':'void | void','return_type':'void'},},},}
let php_builtin['classes']['date_time']={'dateinterval':{'name':'DateInterval','properties': {'y':{'initializer':'','type':'integer'},'m':{'initializer':'','type':'integer'},'d':{'initializer':'','type':'integer'},'h':{'initializer':'','type':'integer'},'i':{'initializer':'','type':'integer'},'s':{'initializer':'','type':'integer'},'invert':{'initializer':'','type':'integer'},'days':{'initializer':'','type':'mixed'},},'methods':{'__construct':{'signature':'string $interval_spec','return_type':''},'format':{'signature':'string $format | string','return_type':'string'},},'static_methods':{'createFromDateString':{'signature':'string $time | DateInterval','return_type':'DateInterval'},},},'dateperiod':{'name':'DatePeriod','constants':{'EXCLUDE_START_DATE':'1',},'methods':{'__construct':{'signature':'string $isostr [, int $options]','return_type':''},},},'datetime':{'name':'DateTime','constants':{'ATOM':'"Y-m-d\TH:i:sP"','COOKIE':'"l, d-M-y H:i:s T"','ISO8601':'"Y-m-d\TH:i:sO"','RFC822':'"D, d M y H:i:s O"','RFC850':'"l, d-M-y H:i:s T"','RFC1036':'"D, d M y H:i:s O"','RFC1123':'"D, d M Y H:i:s O"','RFC2822':'"D, d M Y H:i:s O"','RFC3339':'"Y-m-d\TH:i:sP"','RSS':'"D, d M Y H:i:s O"','W3C':'"Y-m-d\TH:i:sP"',},'methods':{'__construct':{'signature':'[ string $time = "now" [, DateTimeZone $timezone = NULL]]','return_type':''},'add':{'signature':'DateInterval $interval | DateTime','return_type':'DateTime'},'modify':{'signature':'string $modify | DateTime','return_type':'DateTime'},'setDate':{'signature':'int $year, int $month, int $day | DateTime','return_type':'DateTime'},'setISODate':{'signature':'int $year, int $week [, int $day = 1] | DateTime','return_type':'DateTime'},'setTime':{'signature':'int $hour, int $minute [, int $second = 0] | DateTime','return_type':'DateTime'},'setTimestamp':{'signature':'int $unixtimestamp | DateTime','return_type':'DateTime'},'setTimezone':{'signature':'DateTimeZone $timezone | DateTime','return_type':'DateTime'},'sub':{'signature':'DateInterval $interval | DateTime','return_type':'DateTime'},'diff':{'signature':'DateTimeInterface $datetime2 [, bool $absolute = false] | DateInterval','return_type':'DateInterval'},'format':{'signature':'string $format | string','return_type':'string'},'getOffset':{'signature':'void | int','return_type':'int'},'getTimestamp':{'signature':'void | int','return_type':'int'},'getTimezone':{'signature':'void | DateTimeZone','return_type':'DateTimeZone'},'__wakeup':{'signature':'void','return_type':''},},'static_methods':{'createFromFormat':{'signature':'string $format, string $time [, DateTimeZone $timezone] | DateTime','return_type':'DateTime'},'getLastErrors':{'signature':'void | array','return_type':'array'},'__set_state':{'signature':'array $array | DateTime','return_type':'DateTime'},},},'datetimeimmutable':{'name':'DateTimeImmutable','methods':{'__construct':{'signature':'[ string $time = "now" [, DateTimeZone $timezone = NULL]]','return_type':''},'add':{'signature':'DateInterval $interval | DateTimeImmutable','return_type':'DateTimeImmutable'},'modify':{'signature':'string $modify | DateTimeImmutable','return_type':'DateTimeImmutable'},'setDate':{'signature':'int $year, int $month, int $day | DateTimeImmutable','return_type':'DateTimeImmutable'},'setISODate':{'signature':'int $year, int $week [, int $day = 1] | DateTimeImmutable','return_type':'DateTimeImmutable'},'setTime':{'signature':'int $hour, int $minute [, int $second = 0] | DateTimeImmutable','return_type':'DateTimeImmutable'},'setTimestamp':{'signature':'int $unixtimestamp | DateTimeImmutable','return_type':'DateTimeImmutable'},'setTimezone':{'signature':'DateTimeZone $timezone | DateTimeImmutable','return_type':'DateTimeImmutable'},'sub':{'signature':'DateInterval $interval | DateTimeImmutable','return_type':'DateTimeImmutable'},'diff':{'signature':'DateTimeInterface $datetime2 [, bool $absolute = false] | DateInterval','return_type':'DateInterval'},'format':{'signature':'string $format | string','return_type':'string'},'getOffset':{'signature':'void | int','return_type':'int'},'getTimestamp':{'signature':'void | int','return_type':'int'},'getTimezone':{'signature':'void | DateTimeZone','return_type':'DateTimeZone'},'__wakeup':{'signature':'void','return_type':''},},'static_methods':{'createFromFormat':{'signature':'string $format, string $time [, DateTimeZone $timezone] | DateTimeImmutable','return_type':'DateTimeImmutable'},'getLastErrors':{'signature':'void | array','return_type':'array'},'__set_state':{'signature':'array $array | DateTimeImmutable','return_type':'DateTimeImmutable'},},},'datetimezone':{'name':'DateTimeZone','constants':{'AFRICA':'1','AMERICA':'2','ANTARCTICA':'4','ARCTIC':'8','ASIA':'16','ATLANTIC':'32','AUSTRALIA':'64','EUROPE':'128','INDIAN':'256','PACIFIC':'512','UTC':'1024','ALL':'2047','ALL_WITH_BC':'4095','PER_COUNTRY':'4096',},'methods':{'__construct':{'signature':'string $timezone','return_type':''},'getLocation':{'signature':'void | array','return_type':'array'},'getName':{'signature':'void | string','return_type':'string'},'getOffset':{'signature':'DateTime $datetime | int','return_type':'int'},'getTransitions':{'signature':'[ int $timestamp_begin [, int $timestamp_end]] | array','return_type':'array'},},'static_methods':{'listAbbreviations':{'signature':'void | array','return_type':'array'},'listIdentifiers':{'signature':'[ int $what = DateTimeZone::ALL [, string $country = NULL]] | array','return_type':'array'},},},}
let php_builtin['classes']['directories']={'directory':{'name':'Directory','properties': {'path':{'initializer':'','type':'string'},'handle':{'initializer':'','type':'resource'},},'methods':{'close':{'signature':'[ resource $dir_handle] | void','return_type':'void'},'read':{'signature':'[ resource $dir_handle] | string','return_type':'string'},'rewind':{'signature':'[ resource $dir_handle] | void','return_type':'void'},},},}
let php_builtin['classes']['dom']={'domattr':{'name':'DOMAttr','properties': {'name':{'initializer':'','type':'string'},'ownerElement':{'initializer':'','type':'DOMElement'},'schemaTypeInfo':{'initializer':'','type':'bool'},'specified':{'initializer':'','type':'bool'},'value':{'initializer':'','type':'string'},},'methods':{'__construct':{'signature':'string $name [, string $value]','return_type':''},'isId':{'signature':'void | bool','return_type':'bool'},'appendChild':{'signature':'DOMNode $newnode | DOMNode','return_type':'DOMNode'},'C14N':{'signature':'[ bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | string','return_type':'string'},'C14NFile':{'signature':'string $uri [, bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | int','return_type':'int'},'cloneNode':{'signature':'[ bool $deep] | DOMNode','return_type':'DOMNode'},'getLineNo':{'signature':'void | int','return_type':'int'},'getNodePath':{'signature':'void | string','return_type':'string'},'hasAttributes':{'signature':'void | bool','return_type':'bool'},'hasChildNodes':{'signature':'void | bool','return_type':'bool'},'insertBefore':{'signature':'DOMNode $newnode [, DOMNode $refnode] | DOMNode','return_type':'DOMNode'},'isDefaultNamespace':{'signature':'string $namespaceURI | bool','return_type':'bool'},'isSameNode':{'signature':'DOMNode $node | bool','return_type':'bool'},'isSupported':{'signature':'string $feature, string $version | bool','return_type':'bool'},'lookupNamespaceURI':{'signature':'string $prefix | string','return_type':'string'},'lookupPrefix':{'signature':'string $namespaceURI | string','return_type':'string'},'normalize':{'signature':'void | void','return_type':'void'},'removeChild':{'signature':'DOMNode $oldnode | DOMNode','return_type':'DOMNode'},'replaceChild':{'signature':'DOMNode $newnode, DOMNode $oldnode | DOMNode','return_type':'DOMNode'},},},'domcdatasection':{'name':'DOMCdataSection','methods':{'__construct':{'signature':'string $value','return_type':''},'isWhitespaceInElementContent':{'signature':'void | bool','return_type':'bool'},'splitText':{'signature':'int $offset | DOMText','return_type':'DOMText'},},},'domcharacterdata':{'name':'DOMCharacterData','properties': {'data':{'initializer':'','type':'string'},'length':{'initializer':'','type':'int'},},'methods':{'appendData':{'signature':'string $data | void','return_type':'void'},'deleteData':{'signature':'int $offset, int $count | void','return_type':'void'},'insertData':{'signature':'int $offset, string $data | void','return_type':'void'},'replaceData':{'signature':'int $offset, int $count, string $data | void','return_type':'void'},'substringData':{'signature':'int $offset, int $count | string','return_type':'string'},'appendChild':{'signature':'DOMNode $newnode | DOMNode','return_type':'DOMNode'},'C14N':{'signature':'[ bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | string','return_type':'string'},'C14NFile':{'signature':'string $uri [, bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | int','return_type':'int'},'cloneNode':{'signature':'[ bool $deep] | DOMNode','return_type':'DOMNode'},'getLineNo':{'signature':'void | int','return_type':'int'},'getNodePath':{'signature':'void | string','return_type':'string'},'hasAttributes':{'signature':'void | bool','return_type':'bool'},'hasChildNodes':{'signature':'void | bool','return_type':'bool'},'insertBefore':{'signature':'DOMNode $newnode [, DOMNode $refnode] | DOMNode','return_type':'DOMNode'},'isDefaultNamespace':{'signature':'string $namespaceURI | bool','return_type':'bool'},'isSameNode':{'signature':'DOMNode $node | bool','return_type':'bool'},'isSupported':{'signature':'string $feature, string $version | bool','return_type':'bool'},'lookupNamespaceURI':{'signature':'string $prefix | string','return_type':'string'},'lookupPrefix':{'signature':'string $namespaceURI | string','return_type':'string'},'normalize':{'signature':'void | void','return_type':'void'},'removeChild':{'signature':'DOMNode $oldnode | DOMNode','return_type':'DOMNode'},'replaceChild':{'signature':'DOMNode $newnode, DOMNode $oldnode | DOMNode','return_type':'DOMNode'},},},'domcomment':{'name':'DOMComment','methods':{'__construct':{'signature':'[ string $value]','return_type':''},'appendData':{'signature':'string $data | void','return_type':'void'},'deleteData':{'signature':'int $offset, int $count | void','return_type':'void'},'insertData':{'signature':'int $offset, string $data | void','return_type':'void'},'replaceData':{'signature':'int $offset, int $count, string $data | void','return_type':'void'},'substringData':{'signature':'int $offset, int $count | string','return_type':'string'},'appendChild':{'signature':'DOMNode $newnode | DOMNode','return_type':'DOMNode'},'C14N':{'signature':'[ bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | string','return_type':'string'},'C14NFile':{'signature':'string $uri [, bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | int','return_type':'int'},'cloneNode':{'signature':'[ bool $deep] | DOMNode','return_type':'DOMNode'},'getLineNo':{'signature':'void | int','return_type':'int'},'getNodePath':{'signature':'void | string','return_type':'string'},'hasAttributes':{'signature':'void | bool','return_type':'bool'},'hasChildNodes':{'signature':'void | bool','return_type':'bool'},'insertBefore':{'signature':'DOMNode $newnode [, DOMNode $refnode] | DOMNode','return_type':'DOMNode'},'isDefaultNamespace':{'signature':'string $namespaceURI | bool','return_type':'bool'},'isSameNode':{'signature':'DOMNode $node | bool','return_type':'bool'},'isSupported':{'signature':'string $feature, string $version | bool','return_type':'bool'},'lookupNamespaceURI':{'signature':'string $prefix | string','return_type':'string'},'lookupPrefix':{'signature':'string $namespaceURI | string','return_type':'string'},'normalize':{'signature':'void | void','return_type':'void'},'removeChild':{'signature':'DOMNode $oldnode | DOMNode','return_type':'DOMNode'},'replaceChild':{'signature':'DOMNode $newnode, DOMNode $oldnode | DOMNode','return_type':'DOMNode'},},},'domdocument':{'name':'DOMDocument','properties': {'actualEncoding':{'initializer':'','type':'string'},'config':{'initializer':'','type':'DOMConfiguration'},'doctype':{'initializer':'','type':'DOMDocumentType'},'documentElement':{'initializer':'','type':'DOMElement'},'documentURI':{'initializer':'','type':'string'},'encoding':{'initializer':'','type':'string'},'formatOutput':{'initializer':'','type':'bool'},'implementation':{'initializer':'','type':'DOMImplementation'},'preserveWhiteSpace':{'initializer':'true','type':'bool'},'recover':{'initializer':'','type':'bool'},'resolveExternals':{'initializer':'','type':'bool'},'standalone':{'initializer':'','type':'bool'},'strictErrorChecking':{'initializer':'true','type':'bool'},'substituteEntities':{'initializer':'','type':'bool'},'validateOnParse':{'initializer':'false','type':'bool'},'version':{'initializer':'','type':'string'},'xmlEncoding':{'initializer':'','type':'string'},'xmlStandalone':{'initializer':'','type':'bool'},'xmlVersion':{'initializer':'','type':'string'},},'methods':{'__construct':{'signature':'[ string $version [, string $encoding]]','return_type':''},'createAttribute':{'signature':'string $name | DOMAttr','return_type':'DOMAttr'},'createAttributeNS':{'signature':'string $namespaceURI, string $qualifiedName | DOMAttr','return_type':'DOMAttr'},'createCDATASection':{'signature':'string $data | DOMCDATASection','return_type':'DOMCDATASection'},'createComment':{'signature':'string $data | DOMComment','return_type':'DOMComment'},'createDocumentFragment':{'signature':'void | DOMDocumentFragment','return_type':'DOMDocumentFragment'},'createElement':{'signature':'string $name [, string $value] | DOMElement','return_type':'DOMElement'},'createElementNS':{'signature':'string $namespaceURI, string $qualifiedName [, string $value] | DOMElement','return_type':'DOMElement'},'createEntityReference':{'signature':'string $name | DOMEntityReference','return_type':'DOMEntityReference'},'createProcessingInstruction':{'signature':'string $target [, string $data] | DOMProcessingInstruction','return_type':'DOMProcessingInstruction'},'createTextNode':{'signature':'string $content | DOMText','return_type':'DOMText'},'getElementById':{'signature':'string $elementId | DOMElement','return_type':'DOMElement'},'getElementsByTagName':{'signature':'string $name | DOMNodeList','return_type':'DOMNodeList'},'getElementsByTagNameNS':{'signature':'string $namespaceURI, string $localName | DOMNodeList','return_type':'DOMNodeList'},'importNode':{'signature':'DOMNode $importedNode [, bool $deep] | DOMNode','return_type':'DOMNode'},'load':{'signature':'string $filename [, int $options = 0] | mixed','return_type':'mixed'},'loadHTML':{'signature':'string $source [, int $options = 0] | bool','return_type':'bool'},'loadHTMLFile':{'signature':'string $filename [, int $options = 0] | bool','return_type':'bool'},'loadXML':{'signature':'string $source [, int $options = 0] | mixed','return_type':'mixed'},'normalizeDocument':{'signature':'void | void','return_type':'void'},'registerNodeClass':{'signature':'string $baseclass, string $extendedclass | bool','return_type':'bool'},'relaxNGValidate':{'signature':'string $filename | bool','return_type':'bool'},'relaxNGValidateSource':{'signature':'string $source | bool','return_type':'bool'},'save':{'signature':'string $filename [, int $options] | int','return_type':'int'},'saveHTML':{'signature':'[ DOMNode $node = NULL] | string','return_type':'string'},'saveHTMLFile':{'signature':'string $filename | int','return_type':'int'},'saveXML':{'signature':'[ DOMNode $node [, int $options]] | string','return_type':'string'},'schemaValidate':{'signature':'string $filename [, int $flags] | bool','return_type':'bool'},'schemaValidateSource':{'signature':'string $source [, int $flags] | bool','return_type':'bool'},'validate':{'signature':'void | bool','return_type':'bool'},'xinclude':{'signature':'[ int $options] | int','return_type':'int'},'appendChild':{'signature':'DOMNode $newnode | DOMNode','return_type':'DOMNode'},'C14N':{'signature':'[ bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | string','return_type':'string'},'C14NFile':{'signature':'string $uri [, bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | int','return_type':'int'},'cloneNode':{'signature':'[ bool $deep] | DOMNode','return_type':'DOMNode'},'getLineNo':{'signature':'void | int','return_type':'int'},'getNodePath':{'signature':'void | string','return_type':'string'},'hasAttributes':{'signature':'void | bool','return_type':'bool'},'hasChildNodes':{'signature':'void | bool','return_type':'bool'},'insertBefore':{'signature':'DOMNode $newnode [, DOMNode $refnode] | DOMNode','return_type':'DOMNode'},'isDefaultNamespace':{'signature':'string $namespaceURI | bool','return_type':'bool'},'isSameNode':{'signature':'DOMNode $node | bool','return_type':'bool'},'isSupported':{'signature':'string $feature, string $version | bool','return_type':'bool'},'lookupNamespaceURI':{'signature':'string $prefix | string','return_type':'string'},'lookupPrefix':{'signature':'string $namespaceURI | string','return_type':'string'},'normalize':{'signature':'void | void','return_type':'void'},'removeChild':{'signature':'DOMNode $oldnode | DOMNode','return_type':'DOMNode'},'replaceChild':{'signature':'DOMNode $newnode, DOMNode $oldnode | DOMNode','return_type':'DOMNode'},},},'domdocumentfragment':{'name':'DOMDocumentFragment','methods':{'appendXML':{'signature':'string $data | bool','return_type':'bool'},'appendChild':{'signature':'DOMNode $newnode | DOMNode','return_type':'DOMNode'},'C14N':{'signature':'[ bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | string','return_type':'string'},'C14NFile':{'signature':'string $uri [, bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | int','return_type':'int'},'cloneNode':{'signature':'[ bool $deep] | DOMNode','return_type':'DOMNode'},'getLineNo':{'signature':'void | int','return_type':'int'},'getNodePath':{'signature':'void | string','return_type':'string'},'hasAttributes':{'signature':'void | bool','return_type':'bool'},'hasChildNodes':{'signature':'void | bool','return_type':'bool'},'insertBefore':{'signature':'DOMNode $newnode [, DOMNode $refnode] | DOMNode','return_type':'DOMNode'},'isDefaultNamespace':{'signature':'string $namespaceURI | bool','return_type':'bool'},'isSameNode':{'signature':'DOMNode $node | bool','return_type':'bool'},'isSupported':{'signature':'string $feature, string $version | bool','return_type':'bool'},'lookupNamespaceURI':{'signature':'string $prefix | string','return_type':'string'},'lookupPrefix':{'signature':'string $namespaceURI | string','return_type':'string'},'normalize':{'signature':'void | void','return_type':'void'},'removeChild':{'signature':'DOMNode $oldnode | DOMNode','return_type':'DOMNode'},'replaceChild':{'signature':'DOMNode $newnode, DOMNode $oldnode | DOMNode','return_type':'DOMNode'},},},'domdocumenttype':{'name':'DOMDocumentType','properties': {'publicId':{'initializer':'','type':'string'},'systemId':{'initializer':'','type':'string'},'name':{'initializer':'','type':'string'},'entities':{'initializer':'','type':'DOMNamedNodeMap'},'notations':{'initializer':'','type':'DOMNamedNodeMap'},'internalSubset':{'initializer':'','type':'string'},},'methods':{'appendChild':{'signature':'DOMNode $newnode | DOMNode','return_type':'DOMNode'},'C14N':{'signature':'[ bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | string','return_type':'string'},'C14NFile':{'signature':'string $uri [, bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | int','return_type':'int'},'cloneNode':{'signature':'[ bool $deep] | DOMNode','return_type':'DOMNode'},'getLineNo':{'signature':'void | int','return_type':'int'},'getNodePath':{'signature':'void | string','return_type':'string'},'hasAttributes':{'signature':'void | bool','return_type':'bool'},'hasChildNodes':{'signature':'void | bool','return_type':'bool'},'insertBefore':{'signature':'DOMNode $newnode [, DOMNode $refnode] | DOMNode','return_type':'DOMNode'},'isDefaultNamespace':{'signature':'string $namespaceURI | bool','return_type':'bool'},'isSameNode':{'signature':'DOMNode $node | bool','return_type':'bool'},'isSupported':{'signature':'string $feature, string $version | bool','return_type':'bool'},'lookupNamespaceURI':{'signature':'string $prefix | string','return_type':'string'},'lookupPrefix':{'signature':'string $namespaceURI | string','return_type':'string'},'normalize':{'signature':'void | void','return_type':'void'},'removeChild':{'signature':'DOMNode $oldnode | DOMNode','return_type':'DOMNode'},'replaceChild':{'signature':'DOMNode $newnode, DOMNode $oldnode | DOMNode','return_type':'DOMNode'},},},'domelement':{'name':'DOMElement','properties': {'schemaTypeInfo':{'initializer':'','type':'bool'},'tagName':{'initializer':'','type':'string'},},'methods':{'__construct':{'signature':'string $name [, string $value [, string $namespaceURI]]','return_type':''},'getAttribute':{'signature':'string $name | string','return_type':'string'},'getAttributeNode':{'signature':'string $name | DOMAttr','return_type':'DOMAttr'},'getAttributeNodeNS':{'signature':'string $namespaceURI, string $localName | DOMAttr','return_type':'DOMAttr'},'getAttributeNS':{'signature':'string $namespaceURI, string $localName | string','return_type':'string'},'getElementsByTagName':{'signature':'string $name | DOMNodeList','return_type':'DOMNodeList'},'getElementsByTagNameNS':{'signature':'string $namespaceURI, string $localName | DOMNodeList','return_type':'DOMNodeList'},'hasAttribute':{'signature':'string $name | bool','return_type':'bool'},'hasAttributeNS':{'signature':'string $namespaceURI, string $localName | bool','return_type':'bool'},'removeAttribute':{'signature':'string $name | bool','return_type':'bool'},'removeAttributeNode':{'signature':'DOMAttr $oldnode | bool','return_type':'bool'},'removeAttributeNS':{'signature':'string $namespaceURI, string $localName | bool','return_type':'bool'},'setAttribute':{'signature':'string $name, string $value | DOMAttr','return_type':'DOMAttr'},'setAttributeNode':{'signature':'DOMAttr $attr | DOMAttr','return_type':'DOMAttr'},'setAttributeNodeNS':{'signature':'DOMAttr $attr | DOMAttr','return_type':'DOMAttr'},'setAttributeNS':{'signature':'string $namespaceURI, string $qualifiedName, string $value | void','return_type':'void'},'setIdAttribute':{'signature':'string $name, bool $isId | void','return_type':'void'},'setIdAttributeNode':{'signature':'DOMAttr $attr, bool $isId | void','return_type':'void'},'setIdAttributeNS':{'signature':'string $namespaceURI, string $localName, bool $isId | void','return_type':'void'},'appendChild':{'signature':'DOMNode $newnode | DOMNode','return_type':'DOMNode'},'C14N':{'signature':'[ bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | string','return_type':'string'},'C14NFile':{'signature':'string $uri [, bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | int','return_type':'int'},'cloneNode':{'signature':'[ bool $deep] | DOMNode','return_type':'DOMNode'},'getLineNo':{'signature':'void | int','return_type':'int'},'getNodePath':{'signature':'void | string','return_type':'string'},'hasAttributes':{'signature':'void | bool','return_type':'bool'},'hasChildNodes':{'signature':'void | bool','return_type':'bool'},'insertBefore':{'signature':'DOMNode $newnode [, DOMNode $refnode] | DOMNode','return_type':'DOMNode'},'isDefaultNamespace':{'signature':'string $namespaceURI | bool','return_type':'bool'},'isSameNode':{'signature':'DOMNode $node | bool','return_type':'bool'},'isSupported':{'signature':'string $feature, string $version | bool','return_type':'bool'},'lookupNamespaceURI':{'signature':'string $prefix | string','return_type':'string'},'lookupPrefix':{'signature':'string $namespaceURI | string','return_type':'string'},'normalize':{'signature':'void | void','return_type':'void'},'removeChild':{'signature':'DOMNode $oldnode | DOMNode','return_type':'DOMNode'},'replaceChild':{'signature':'DOMNode $newnode, DOMNode $oldnode | DOMNode','return_type':'DOMNode'},},},'domentity':{'name':'DOMEntity','properties': {'publicId':{'initializer':'','type':'string'},'systemId':{'initializer':'','type':'string'},'notationName':{'initializer':'','type':'string'},'actualEncoding':{'initializer':'','type':'string'},'encoding':{'initializer':'','type':'string'},'version':{'initializer':'','type':'string'},},'methods':{'appendChild':{'signature':'DOMNode $newnode | DOMNode','return_type':'DOMNode'},'C14N':{'signature':'[ bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | string','return_type':'string'},'C14NFile':{'signature':'string $uri [, bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | int','return_type':'int'},'cloneNode':{'signature':'[ bool $deep] | DOMNode','return_type':'DOMNode'},'getLineNo':{'signature':'void | int','return_type':'int'},'getNodePath':{'signature':'void | string','return_type':'string'},'hasAttributes':{'signature':'void | bool','return_type':'bool'},'hasChildNodes':{'signature':'void | bool','return_type':'bool'},'insertBefore':{'signature':'DOMNode $newnode [, DOMNode $refnode] | DOMNode','return_type':'DOMNode'},'isDefaultNamespace':{'signature':'string $namespaceURI | bool','return_type':'bool'},'isSameNode':{'signature':'DOMNode $node | bool','return_type':'bool'},'isSupported':{'signature':'string $feature, string $version | bool','return_type':'bool'},'lookupNamespaceURI':{'signature':'string $prefix | string','return_type':'string'},'lookupPrefix':{'signature':'string $namespaceURI | string','return_type':'string'},'normalize':{'signature':'void | void','return_type':'void'},'removeChild':{'signature':'DOMNode $oldnode | DOMNode','return_type':'DOMNode'},'replaceChild':{'signature':'DOMNode $newnode, DOMNode $oldnode | DOMNode','return_type':'DOMNode'},},},'domentityreference':{'name':'DOMEntityReference','methods':{'__construct':{'signature':'string $name','return_type':''},'appendChild':{'signature':'DOMNode $newnode | DOMNode','return_type':'DOMNode'},'C14N':{'signature':'[ bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | string','return_type':'string'},'C14NFile':{'signature':'string $uri [, bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | int','return_type':'int'},'cloneNode':{'signature':'[ bool $deep] | DOMNode','return_type':'DOMNode'},'getLineNo':{'signature':'void | int','return_type':'int'},'getNodePath':{'signature':'void | string','return_type':'string'},'hasAttributes':{'signature':'void | bool','return_type':'bool'},'hasChildNodes':{'signature':'void | bool','return_type':'bool'},'insertBefore':{'signature':'DOMNode $newnode [, DOMNode $refnode] | DOMNode','return_type':'DOMNode'},'isDefaultNamespace':{'signature':'string $namespaceURI | bool','return_type':'bool'},'isSameNode':{'signature':'DOMNode $node | bool','return_type':'bool'},'isSupported':{'signature':'string $feature, string $version | bool','return_type':'bool'},'lookupNamespaceURI':{'signature':'string $prefix | string','return_type':'string'},'lookupPrefix':{'signature':'string $namespaceURI | string','return_type':'string'},'normalize':{'signature':'void | void','return_type':'void'},'removeChild':{'signature':'DOMNode $oldnode | DOMNode','return_type':'DOMNode'},'replaceChild':{'signature':'DOMNode $newnode, DOMNode $oldnode | DOMNode','return_type':'DOMNode'},},},'domexception':{'name':'DOMException','properties': {'code':{'initializer':'','type':'int'},},'methods':{'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},'domimplementation':{'name':'DOMImplementation','methods':{'__construct':{'signature':'void','return_type':''},'createDocument':{'signature':'[ string $namespaceURI = NULL [, string $qualifiedName = NULL [, DOMDocumentType $doctype = NULL]]] | DOMDocument','return_type':'DOMDocument'},'createDocumentType':{'signature':'[ string $qualifiedName = NULL [, string $publicId = NULL [, string $systemId = NULL]]] | DOMDocumentType','return_type':'DOMDocumentType'},'hasFeature':{'signature':'string $feature, string $version | bool','return_type':'bool'},},},'domnamednodemap':{'name':'DOMNamedNodeMap','properties': {'length':{'initializer':'','type':'int'},},'methods':{'getNamedItem':{'signature':'string $name | DOMNode','return_type':'DOMNode'},'getNamedItemNS':{'signature':'string $namespaceURI, string $localName | DOMNode','return_type':'DOMNode'},'item':{'signature':'int $index | DOMNode','return_type':'DOMNode'},},},'domnode':{'name':'DOMNode','properties': {'nodeName':{'initializer':'','type':'string'},'nodeValue':{'initializer':'','type':'string'},'nodeType':{'initializer':'','type':'int'},'parentNode':{'initializer':'','type':'DOMNode'},'childNodes':{'initializer':'','type':'DOMNodeList'},'firstChild':{'initializer':'','type':'DOMNode'},'lastChild':{'initializer':'','type':'DOMNode'},'previousSibling':{'initializer':'','type':'DOMNode'},'nextSibling':{'initializer':'','type':'DOMNode'},'attributes':{'initializer':'','type':'DOMNamedNodeMap'},'ownerDocument':{'initializer':'','type':'DOMDocument'},'namespaceURI':{'initializer':'','type':'string'},'prefix':{'initializer':'','type':'string'},'localName':{'initializer':'','type':'string'},'baseURI':{'initializer':'','type':'string'},'textContent':{'initializer':'','type':'string'},},'methods':{'appendChild':{'signature':'DOMNode $newnode | DOMNode','return_type':'DOMNode'},'C14N':{'signature':'[ bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | string','return_type':'string'},'C14NFile':{'signature':'string $uri [, bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | int','return_type':'int'},'cloneNode':{'signature':'[ bool $deep] | DOMNode','return_type':'DOMNode'},'getLineNo':{'signature':'void | int','return_type':'int'},'getNodePath':{'signature':'void | string','return_type':'string'},'hasAttributes':{'signature':'void | bool','return_type':'bool'},'hasChildNodes':{'signature':'void | bool','return_type':'bool'},'insertBefore':{'signature':'DOMNode $newnode [, DOMNode $refnode] | DOMNode','return_type':'DOMNode'},'isDefaultNamespace':{'signature':'string $namespaceURI | bool','return_type':'bool'},'isSameNode':{'signature':'DOMNode $node | bool','return_type':'bool'},'isSupported':{'signature':'string $feature, string $version | bool','return_type':'bool'},'lookupNamespaceURI':{'signature':'string $prefix | string','return_type':'string'},'lookupPrefix':{'signature':'string $namespaceURI | string','return_type':'string'},'normalize':{'signature':'void | void','return_type':'void'},'removeChild':{'signature':'DOMNode $oldnode | DOMNode','return_type':'DOMNode'},'replaceChild':{'signature':'DOMNode $newnode, DOMNode $oldnode | DOMNode','return_type':'DOMNode'},},},'domnodelist':{'name':'DOMNodeList','properties': {'length':{'initializer':'','type':'int'},},'methods':{'item':{'signature':'int $index | DOMNode','return_type':'DOMNode'},},},'domnotation':{'name':'DOMNotation','properties': {'publicId':{'initializer':'','type':'string'},'systemId':{'initializer':'','type':'string'},},'methods':{'appendChild':{'signature':'DOMNode $newnode | DOMNode','return_type':'DOMNode'},'C14N':{'signature':'[ bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | string','return_type':'string'},'C14NFile':{'signature':'string $uri [, bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | int','return_type':'int'},'cloneNode':{'signature':'[ bool $deep] | DOMNode','return_type':'DOMNode'},'getLineNo':{'signature':'void | int','return_type':'int'},'getNodePath':{'signature':'void | string','return_type':'string'},'hasAttributes':{'signature':'void | bool','return_type':'bool'},'hasChildNodes':{'signature':'void | bool','return_type':'bool'},'insertBefore':{'signature':'DOMNode $newnode [, DOMNode $refnode] | DOMNode','return_type':'DOMNode'},'isDefaultNamespace':{'signature':'string $namespaceURI | bool','return_type':'bool'},'isSameNode':{'signature':'DOMNode $node | bool','return_type':'bool'},'isSupported':{'signature':'string $feature, string $version | bool','return_type':'bool'},'lookupNamespaceURI':{'signature':'string $prefix | string','return_type':'string'},'lookupPrefix':{'signature':'string $namespaceURI | string','return_type':'string'},'normalize':{'signature':'void | void','return_type':'void'},'removeChild':{'signature':'DOMNode $oldnode | DOMNode','return_type':'DOMNode'},'replaceChild':{'signature':'DOMNode $newnode, DOMNode $oldnode | DOMNode','return_type':'DOMNode'},},},'domprocessinginstruction':{'name':'DOMProcessingInstruction','properties': {'target':{'initializer':'','type':'string'},'data':{'initializer':'','type':'string'},},'methods':{'__construct':{'signature':'string $name [, string $value]','return_type':''},'appendChild':{'signature':'DOMNode $newnode | DOMNode','return_type':'DOMNode'},'C14N':{'signature':'[ bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | string','return_type':'string'},'C14NFile':{'signature':'string $uri [, bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | int','return_type':'int'},'cloneNode':{'signature':'[ bool $deep] | DOMNode','return_type':'DOMNode'},'getLineNo':{'signature':'void | int','return_type':'int'},'getNodePath':{'signature':'void | string','return_type':'string'},'hasAttributes':{'signature':'void | bool','return_type':'bool'},'hasChildNodes':{'signature':'void | bool','return_type':'bool'},'insertBefore':{'signature':'DOMNode $newnode [, DOMNode $refnode] | DOMNode','return_type':'DOMNode'},'isDefaultNamespace':{'signature':'string $namespaceURI | bool','return_type':'bool'},'isSameNode':{'signature':'DOMNode $node | bool','return_type':'bool'},'isSupported':{'signature':'string $feature, string $version | bool','return_type':'bool'},'lookupNamespaceURI':{'signature':'string $prefix | string','return_type':'string'},'lookupPrefix':{'signature':'string $namespaceURI | string','return_type':'string'},'normalize':{'signature':'void | void','return_type':'void'},'removeChild':{'signature':'DOMNode $oldnode | DOMNode','return_type':'DOMNode'},'replaceChild':{'signature':'DOMNode $newnode, DOMNode $oldnode | DOMNode','return_type':'DOMNode'},},},'domtext':{'name':'DOMText','properties': {'wholeText':{'initializer':'','type':'string'},},'methods':{'__construct':{'signature':'[ string $value]','return_type':''},'isWhitespaceInElementContent':{'signature':'void | bool','return_type':'bool'},'splitText':{'signature':'int $offset | DOMText','return_type':'DOMText'},'appendChild':{'signature':'DOMNode $newnode | DOMNode','return_type':'DOMNode'},'C14N':{'signature':'[ bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | string','return_type':'string'},'C14NFile':{'signature':'string $uri [, bool $exclusive [, bool $with_comments [, array $xpath [, array $ns_prefixes]]]] | int','return_type':'int'},'cloneNode':{'signature':'[ bool $deep] | DOMNode','return_type':'DOMNode'},'getLineNo':{'signature':'void | int','return_type':'int'},'getNodePath':{'signature':'void | string','return_type':'string'},'hasAttributes':{'signature':'void | bool','return_type':'bool'},'hasChildNodes':{'signature':'void | bool','return_type':'bool'},'insertBefore':{'signature':'DOMNode $newnode [, DOMNode $refnode] | DOMNode','return_type':'DOMNode'},'isDefaultNamespace':{'signature':'string $namespaceURI | bool','return_type':'bool'},'isSameNode':{'signature':'DOMNode $node | bool','return_type':'bool'},'isSupported':{'signature':'string $feature, string $version | bool','return_type':'bool'},'lookupNamespaceURI':{'signature':'string $prefix | string','return_type':'string'},'lookupPrefix':{'signature':'string $namespaceURI | string','return_type':'string'},'normalize':{'signature':'void | void','return_type':'void'},'removeChild':{'signature':'DOMNode $oldnode | DOMNode','return_type':'DOMNode'},'replaceChild':{'signature':'DOMNode $newnode, DOMNode $oldnode | DOMNode','return_type':'DOMNode'},},},'domxpath':{'name':'DOMXPath','properties': {'document':{'initializer':'','type':'DOMDocument'},},'methods':{'__construct':{'signature':'DOMDocument $doc','return_type':''},'evaluate':{'signature':'string $expression [, DOMNode $contextnode [, bool $registerNodeNS = true]] | mixed','return_type':'mixed'},'query':{'signature':'string $expression [, DOMNode $contextnode [, bool $registerNodeNS = true]] | DOMNodeList','return_type':'DOMNodeList'},'registerNamespace':{'signature':'string $prefix, string $namespaceURI | bool','return_type':'bool'},'registerPhpFunctions':{'signature':'[ mixed $restrict] | void','return_type':'void'},},},}
let php_builtin['classes']['predefined_exceptions']={'errorexception':{'name':'ErrorException','properties': {'severity':{'initializer':'','type':'int'},'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'__construct':{'signature':'[ string $message = "" [, int $code = 0 [, int $severity = 1 [, string $filename = __FILE__ [, int $lineno = __LINE__ [, Exception $previous = NULL]]]]]]','return_type':''},'getSeverity':{'signature':'void | int','return_type':'int'},'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},'exception':{'name':'Exception','properties': {'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'__construct':{'signature':'[ string $message = "" [, int $code = 0 [, Exception $previous = NULL]]]','return_type':''},'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},}
let php_builtin['classes']['libxml']={'libxmlerror':{'name':'libXMLError','properties': {'level':{'initializer':'','type':'int'},'code':{'initializer':'','type':'int'},'column':{'initializer':'','type':'int'},'message':{'initializer':'','type':'string'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},},}
let php_builtin['classes']['mysqli']={'mysqli_driver':{'name':'mysqli_driver','properties': {'client_info':{'initializer':'','type':'string'},'client_version':{'initializer':'','type':'string'},'driver_version':{'initializer':'','type':'string'},'embedded':{'initializer':'','type':'string'},'reconnect':{'initializer':'','type':'bool'},'report_mode':{'initializer':'','type':'int'},},'methods':{'embedded_server_end':{'signature':'void | void','return_type':'void'},'embedded_server_start':{'signature':'bool $start, array $arguments, array $groups | bool','return_type':'bool'},},},'mysqli_result':{'name':'mysqli_result','properties': {'current_field':{'initializer':'','type':'int'},'field_count':{'initializer':'','type':'int'},'lengths':{'initializer':'','type':'array'},'num_rows':{'initializer':'','type':'int'},},'methods':{'data_seek':{'signature':'int $offset | bool','return_type':'bool'},'fetch_all':{'signature':'[ int $resulttype = MYSQLI_NUM] | mixed','return_type':'mixed'},'fetch_array':{'signature':'[ int $resulttype = MYSQLI_BOTH] | mixed','return_type':'mixed'},'fetch_assoc':{'signature':'void | array','return_type':'array'},'fetch_field_direct':{'signature':'int $fieldnr | object','return_type':'object'},'fetch_field':{'signature':'void | object','return_type':'object'},'fetch_fields':{'signature':'void | array','return_type':'array'},'fetch_object':{'signature':'[ string $class_name [, array $params]] | object','return_type':'object'},'fetch_row':{'signature':'void | mixed','return_type':'mixed'},'field_seek':{'signature':'int $fieldnr | bool','return_type':'bool'},'free':{'signature':'void | void','return_type':'void'},},},'mysqli_sql_exception':{'name':'mysqli_sql_exception','properties': {'sqlstate':{'initializer':'','type':'string'},'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},},'mysqli_stmt':{'name':'mysqli_stmt','properties': {'affected_rows':{'initializer':'','type':'int'},'errno':{'initializer':'','type':'int'},'error_list':{'initializer':'','type':'array'},'error':{'initializer':'','type':'string'},'field_count':{'initializer':'','type':'int'},'insert_id':{'initializer':'','type':'int'},'num_rows':{'initializer':'','type':'int'},'param_count':{'initializer':'','type':'int'},'sqlstate':{'initializer':'','type':'string'},},'methods':{'attr_get':{'signature':'int $attr | int','return_type':'int'},'attr_set':{'signature':'int $attr, int $mode | bool','return_type':'bool'},'bind_param':{'signature':'string $types, mixed &$var1 [, mixed &$...] | bool','return_type':'bool'},'bind_result':{'signature':'mixed &$var1 [, mixed &$...] | bool','return_type':'bool'},'close':{'signature':'void | bool','return_type':'bool'},'data_seek':{'signature':'int $offset | void','return_type':'void'},'execute':{'signature':'void | bool','return_type':'bool'},'fetch':{'signature':'void | bool','return_type':'bool'},'free_result':{'signature':'void | void','return_type':'void'},'get_result':{'signature':'void | mysqli_result','return_type':'mysqli_result'},'get_warnings':{'signature':'mysqli_stmt $stmt | object','return_type':'object'},'prepare':{'signature':'string $query | mixed','return_type':'mixed'},'reset':{'signature':'void | bool','return_type':'bool'},'result_metadata':{'signature':'void | mysqli_result','return_type':'mysqli_result'},'send_long_data':{'signature':'int $param_nr, string $data | bool','return_type':'bool'},'store_result':{'signature':'void | bool','return_type':'bool'},},},'mysqli_warning':{'name':'mysqli_warning','properties': {'message':{'initializer':'','type':''},'sqlstate':{'initializer':'','type':''},'errno':{'initializer':'','type':''},},'methods':{'__construct':{'signature':'void','return_type':''},'next':{'signature':'void | void','return_type':'void'},},},'mysqli':{'name':'mysqli','properties': {'affected_rows':{'initializer':'','type':'int'},'client_info':{'initializer':'','type':'string'},'client_version':{'initializer':'','type':'int'},'connect_errno':{'initializer':'','type':'string'},'connect_error':{'initializer':'','type':'string'},'errno':{'initializer':'','type':'int'},'error_list':{'initializer':'','type':'array'},'error':{'initializer':'','type':'string'},'field_count':{'initializer':'','type':'int'},'host_info':{'initializer':'','type':'string'},'protocol_version':{'initializer':'','type':'string'},'server_info':{'initializer':'','type':'string'},'server_version':{'initializer':'','type':'int'},'info':{'initializer':'','type':'string'},'insert_id':{'initializer':'','type':'mixed'},'sqlstate':{'initializer':'','type':'string'},'thread_id':{'initializer':'','type':'int'},'warning_count':{'initializer':'','type':'int'},},'methods':{'__construct':{'signature':'[ string $host = ini_get("mysqli.default_host") [, string $username = ini_get("mysqli.default_user") [, string $passwd = ini_get("mysqli.default_pw") [, string $dbname = "" [, int $port = ini_get("mysqli.default_port") [, string $socket = ini_get("mysqli.default_socket")]]]]]]','return_type':''},'autocommit':{'signature':'bool $mode | bool','return_type':'bool'},'change_user':{'signature':'string $user, string $password, string $database | bool','return_type':'bool'},'character_set_name':{'signature':'void | string','return_type':'string'},'close':{'signature':'void | bool','return_type':'bool'},'commit':{'signature':'[ int $flags [, string $name]] | bool','return_type':'bool'},'debug':{'signature':'string $message | bool','return_type':'bool'},'dump_debug_info':{'signature':'void | bool','return_type':'bool'},'get_charset':{'signature':'void | object','return_type':'object'},'get_client_info':{'signature':'void | string','return_type':'string'},'get_connection_stats':{'signature':'void | bool','return_type':'bool'},'get_warnings':{'signature':'void | mysqli_warning','return_type':'mysqli_warning'},'init':{'signature':'void | mysqli','return_type':'mysqli'},'kill':{'signature':'int $processid | bool','return_type':'bool'},'more_results':{'signature':'void | bool','return_type':'bool'},'multi_query':{'signature':'string $query | bool','return_type':'bool'},'next_result':{'signature':'void | bool','return_type':'bool'},'options':{'signature':'int $option, mixed $value | bool','return_type':'bool'},'ping':{'signature':'void | bool','return_type':'bool'},'prepare':{'signature':'string $query | mysqli_stmt','return_type':'mysqli_stmt'},'query':{'signature':'string $query [, int $resultmode = MYSQLI_STORE_RESULT] | mixed','return_type':'mixed'},'real_connect':{'signature':'[ string $host [, string $username [, string $passwd [, string $dbname [, int $port [, string $socket [, int $flags]]]]]]] | bool','return_type':'bool'},'escape_string':{'signature':'string $escapestr | string','return_type':'string'},'real_query':{'signature':'string $query | bool','return_type':'bool'},'reap_async_query':{'signature':'void | mysqli_result','return_type':'mysqli_result'},'refresh':{'signature':'int $options | bool','return_type':'bool'},'rollback':{'signature':'[ int $flags [, string $name]] | bool','return_type':'bool'},'rpl_query_type':{'signature':'string $query | int','return_type':'int'},'select_db':{'signature':'string $dbname | bool','return_type':'bool'},'send_query':{'signature':'string $query | bool','return_type':'bool'},'set_charset':{'signature':'string $charset | bool','return_type':'bool'},'set_local_infile_handler':{'signature':'mysqli $link, callable $read_func | bool','return_type':'bool'},'ssl_set':{'signature':'string $key, string $cert, string $ca, string $capath, string $cipher | bool','return_type':'bool'},'stat':{'signature':'void | string','return_type':'string'},'stmt_init':{'signature':'void | mysqli_stmt','return_type':'mysqli_stmt'},'store_result':{'signature':'void | mysqli_result','return_type':'mysqli_result'},'use_result':{'signature':'void | mysqli_result','return_type':'mysqli_result'},},'static_methods':{'poll':{'signature':'array &$read, array &$error, array &$reject, int $sec [, int $usec] | int','return_type':'int'},},},}
let php_builtin['classes']['pdo']={'pdo':{'name':'PDO','constants':{'FETCH_ORI_ABS':'','ATTR_PERSISTENT':'','CLASS_CONSTANT':'','ATTR_DEFAULT_FETCH_MODE':'','FETCH_PROPS_LATE':'','FETCH_KEY_PAIR':'','FB_ATTR_DATE_FORMAT':'','FB_ATTR_TIME_FORMAT':'','FB_ATTR_TIMESTAMP_FORMAT':'','MYSQL_ATTR_READ_DEFAULT_FILE':'','MYSQL_ATTR_READ_DEFAULT_GROUP':'','ATTR_AUTOCOMMIT':'','FOURD_ATTR_CHARSET':'','FOURD_ATTR_PREFERRED_IMAGE_TYPES':'','PARAM_LOB':'','PARAM_BOOL':'','PARAM_NULL':'','PARAM_INT':'','PARAM_STR':'','PARAM_STMT':'','PARAM_INPUT_OUTPUT':'','FETCH_LAZY':'','FETCH_ASSOC':'','FETCH_NAMED':'','FETCH_NUM':'','FETCH_BOTH':'','FETCH_OBJ':'','FETCH_BOUND':'','FETCH_COLUMN':'','FETCH_CLASS':'','FETCH_INTO':'','FETCH_FUNC':'','FETCH_GROUP':'','FETCH_UNIQUE':'','FETCH_CLASSTYPE':'','FETCH_SERIALIZE':'','ATTR_PREFETCH':'','ATTR_TIMEOUT':'','ATTR_ERRMODE':'','ATTR_SERVER_VERSION':'','ATTR_CLIENT_VERSION':'','ATTR_SERVER_INFO':'','ATTR_CONNECTION_STATUS':'','ATTR_CASE':'','ATTR_CURSOR_NAME':'','ATTR_CURSOR':'','CURSOR_FWDONLY':'','CURSOR_SCROLL':'','ATTR_DRIVER_NAME':'','ATTR_ORACLE_NULLS':'','ATTR_STATEMENT_CLASS':'','ATTR_FETCH_CATALOG_NAMES':'','ATTR_FETCH_TABLE_NAMES':'','ATTR_STRINGIFY_FETCHES':'','ATTR_MAX_COLUMN_LEN':'','ATTR_EMULATE_PREPARES':'','ERRMODE_SILENT':'','ERRMODE_WARNING':'','ERRMODE_EXCEPTION':'','CASE_NATURAL':'','CASE_LOWER':'','CASE_UPPER':'','NULL_NATURAL':'','NULL_EMPTY_STRING':'','NULL_TO_STRING':'','FETCH_ORI_NEXT':'','FETCH_ORI_PRIOR':'','FETCH_ORI_FIRST':'','FETCH_ORI_LAST':'','FETCH_ORI_REL':'','ERR_NONE':'','PARAM_EVT_ALLOC':'','PARAM_EVT_FREE':'','PARAM_EVT_EXEC_PRE':'','PARAM_EVT_EXEC_POST':'','PARAM_EVT_FETCH_PRE':'','PARAM_EVT_FETCH_POST':'','PARAM_EVT_NORMALIZE':'','MYSQL_ATTR_INIT_COMMAND':'','MYSQL_ATTR_USE_BUFFERED_QUERY':'','MYSQL_ATTR_LOCAL_INFILE':'','MYSQL_ATTR_MAX_BUFFER_SIZE':'','MYSQL_ATTR_DIRECT_QUERY':'','MYSQL_ATTR_FOUND_ROWS':'','MYSQL_ATTR_IGNORE_SPACE':'','MYSQL_ATTR_COMPRESS':'','MYSQL_ATTR_SSL_CA':'','MYSQL_ATTR_SSL_CAPATH':'','MYSQL_ATTR_SSL_CERT':'','MYSQL_ATTR_SSL_CIPHER':'','MYSQL_ATTR_SSL_KEY':'','SQLSRV_TXN_READ_UNCOMMITTED':'','SQLSRV_TXN_READ_COMMITTED':'','SQLSRV_TXN_REPEATABLE_READ':'','SQLSRV_TXN_SNAPSHOT':'','SQLSRV_TXN_SERIALIZABLE':'','SQLSRV_ENCODING_BINARY':'','SQLSRV_ENCODING_SYSTEM':'','SQLSRV_ENCODING_UTF8':'','SQLSRV_ENCODING_DEFAULT':'','SQLSRV_ATTR_QUERY_TIMEOUT':'','SQLSRV_ATTR_DIRECT_QUERY':'',},'methods':{'__construct':{'signature':'string $dsn [, string $username [, string $password [, array $driver_options]]]','return_type':''},'beginTransaction':{'signature':'void | bool','return_type':'bool'},'commit':{'signature':'void | bool','return_type':'bool'},'errorCode':{'signature':'void | mixed','return_type':'mixed'},'errorInfo':{'signature':'void | array','return_type':'array'},'exec':{'signature':'string $statement | int','return_type':'int'},'getAttribute':{'signature':'int $attribute | mixed','return_type':'mixed'},'inTransaction':{'signature':'void | bool','return_type':'bool'},'lastInsertId':{'signature':'[ string $name = NULL] | string','return_type':'string'},'prepare':{'signature':'string $statement [, array $driver_options = array()] | PDOStatement','return_type':'PDOStatement'},'query':{'signature':'string $statement | PDOStatement','return_type':'PDOStatement'},'quote':{'signature':'string $string [, int $parameter_type = PDO::PARAM_STR] | string','return_type':'string'},'rollBack':{'signature':'void | bool','return_type':'bool'},'setAttribute':{'signature':'int $attribute, mixed $value | bool','return_type':'bool'},},'static_methods':{'getAvailableDrivers':{'signature':'void | array','return_type':'array'},},},'pdoexception':{'name':'PDOException','properties': {'errorInfo':{'initializer':'','type':'array'},'code':{'initializer':'','type':'int'},'message':{'initializer':'','type':'string'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},'pdostatement':{'name':'PDOStatement','properties': {'queryString':{'initializer':'','type':'string'},},'methods':{'bindColumn':{'signature':'mixed $column, mixed &$param [, int $type [, int $maxlen [, mixed $driverdata]]] | bool','return_type':'bool'},'bindParam':{'signature':'mixed $parameter, mixed &$variable [, int $data_type = PDO::PARAM_STR [, int $length [, mixed $driver_options]]] | bool','return_type':'bool'},'bindValue':{'signature':'mixed $parameter, mixed $value [, int $data_type = PDO::PARAM_STR] | bool','return_type':'bool'},'closeCursor':{'signature':'void | bool','return_type':'bool'},'columnCount':{'signature':'void | int','return_type':'int'},'debugDumpParams':{'signature':'void | void','return_type':'void'},'errorCode':{'signature':'void | string','return_type':'string'},'errorInfo':{'signature':'void | array','return_type':'array'},'execute':{'signature':'[ array $input_parameters] | bool','return_type':'bool'},'fetch':{'signature':'[ int $fetch_style [, int $cursor_orientation = PDO::FETCH_ORI_NEXT [, int $cursor_offset = 0]]] | mixed','return_type':'mixed'},'fetchAll':{'signature':'[ int $fetch_style [, mixed $fetch_argument [, array $ctor_args = array()]]] | array','return_type':'array'},'fetchColumn':{'signature':'[ int $column_number = 0] | string','return_type':'string'},'fetchObject':{'signature':'[ string $class_name = "stdClass" [, array $ctor_args]] | mixed','return_type':'mixed'},'getAttribute':{'signature':'int $attribute | mixed','return_type':'mixed'},'getColumnMeta':{'signature':'int $column | array','return_type':'array'},'nextRowset':{'signature':'void | bool','return_type':'bool'},'rowCount':{'signature':'void | int','return_type':'int'},'setAttribute':{'signature':'int $attribute, mixed $value | bool','return_type':'bool'},'setFetchMode':{'signature':'int $mode | bool','return_type':'bool'},},},}
let php_builtin['classes']['phar']={'phar':{'name':'Phar','methods':{'addEmptyDir':{'signature':'string $dirname | void','return_type':'void'},'addFile':{'signature':'string $file [, string $localname] | void','return_type':'void'},'addFromString':{'signature':'string $localname, string $contents | void','return_type':'void'},'buildFromDirectory':{'signature':'string $base_dir [, string $regex] | array','return_type':'array'},'buildFromIterator':{'signature':'Iterator $iter [, string $base_directory] | array','return_type':'array'},'compress':{'signature':'int $compression [, string $extension] | object','return_type':'object'},'compressAllFilesBZIP2':{'signature':'void | bool','return_type':'bool'},'compressAllFilesGZ':{'signature':'void | bool','return_type':'bool'},'compressFiles':{'signature':'int $compression | void','return_type':'void'},'__construct':{'signature':'string $fname [, int $flags [, string $alias]]','return_type':''},'convertToData':{'signature':'[ int $format = 9021976 [, int $compression = 9021976 [, string $extension]]] | PharData','return_type':'PharData'},'convertToExecutable':{'signature':'[ int $format = 9021976 [, int $compression = 9021976 [, string $extension]]] | Phar','return_type':'Phar'},'copy':{'signature':'string $oldfile, string $newfile | bool','return_type':'bool'},'count':{'signature':'void | int','return_type':'int'},'decompress':{'signature':'[ string $extension] | object','return_type':'object'},'decompressFiles':{'signature':'void | bool','return_type':'bool'},'delMetadata':{'signature':'void | bool','return_type':'bool'},'delete':{'signature':'string $entry | bool','return_type':'bool'},'extractTo':{'signature':'string $pathto [, string|array $files [, bool $overwrite = false]] | bool','return_type':'bool'},'getMetadata':{'signature':'void | mixed','return_type':'mixed'},'getModified':{'signature':'void | bool','return_type':'bool'},'getSignature':{'signature':'void | array','return_type':'array'},'getStub':{'signature':'void | string','return_type':'string'},'getVersion':{'signature':'void | string','return_type':'string'},'hasMetadata':{'signature':'void | bool','return_type':'bool'},'isBuffering':{'signature':'void | bool','return_type':'bool'},'isCompressed':{'signature':'void | mixed','return_type':'mixed'},'isFileFormat':{'signature':'int $format | bool','return_type':'bool'},'isWritable':{'signature':'void | bool','return_type':'bool'},'offsetExists':{'signature':'string $offset | bool','return_type':'bool'},'offsetGet':{'signature':'string $offset | int','return_type':'int'},'offsetSet':{'signature':'string $offset, string $value | void','return_type':'void'},'offsetUnset':{'signature':'string $offset | bool','return_type':'bool'},'setAlias':{'signature':'string $alias | bool','return_type':'bool'},'setDefaultStub':{'signature':'[ string $index [, string $webindex]] | bool','return_type':'bool'},'setMetadata':{'signature':'mixed $metadata | void','return_type':'void'},'setSignatureAlgorithm':{'signature':'int $sigtype [, string $privatekey] | void','return_type':'void'},'setStub':{'signature':'string $stub [, int $len = -1] | bool','return_type':'bool'},'startBuffering':{'signature':'void | void','return_type':'void'},'stopBuffering':{'signature':'void | void','return_type':'void'},'uncompressAllFiles':{'signature':'void | bool','return_type':'bool'},},'static_methods':{'apiVersion':{'signature':'void | string','return_type':'string'},'canCompress':{'signature':'[ int $type = 0] | bool','return_type':'bool'},'canWrite':{'signature':'void | bool','return_type':'bool'},'createDefaultStub':{'signature':'[ string $indexfile [, string $webindexfile]] | string','return_type':'string'},'getSupportedCompression':{'signature':'void | array','return_type':'array'},'getSupportedSignatures':{'signature':'void | array','return_type':'array'},'interceptFileFuncs':{'signature':'void | void','return_type':'void'},'isValidPharFilename':{'signature':'string $filename [, bool $executable = true] | bool','return_type':'bool'},'loadPhar':{'signature':'string $filename [, string $alias] | bool','return_type':'bool'},'mapPhar':{'signature':'[ string $alias [, int $dataoffset = 0]] | bool','return_type':'bool'},'mount':{'signature':'string $pharpath, string $externalpath | void','return_type':'void'},'mungServer':{'signature':'array $munglist | void','return_type':'void'},'running':{'signature':'[ bool $retphar = true] | string','return_type':'string'},'unlinkArchive':{'signature':'string $archive | bool','return_type':'bool'},'webPhar':{'signature':'[ string $alias [, string $index = "index.php" [, string $f404 [, array $mimetypes [, callable $rewrites]]]]] | void','return_type':'void'},},},'phardata':{'name':'PharData','methods':{'addEmptyDir':{'signature':'string $dirname | void','return_type':'void'},'addFile':{'signature':'string $file [, string $localname] | void','return_type':'void'},'addFromString':{'signature':'string $localname, string $contents | void','return_type':'void'},'buildFromDirectory':{'signature':'string $base_dir [, string $regex] | array','return_type':'array'},'buildFromIterator':{'signature':'Iterator $iter [, string $base_directory] | array','return_type':'array'},'compress':{'signature':'int $compression [, string $extension] | object','return_type':'object'},'compressFiles':{'signature':'int $compression | void','return_type':'void'},'__construct':{'signature':'string $fname [, int $flags [, string $alias]]','return_type':''},'convertToData':{'signature':'[ int $format = 9021976 [, int $compression = 9021976 [, string $extension]]] | PharData','return_type':'PharData'},'convertToExecutable':{'signature':'[ int $format = 9021976 [, int $compression = 9021976 [, string $extension]]] | Phar','return_type':'Phar'},'copy':{'signature':'string $oldfile, string $newfile | bool','return_type':'bool'},'decompress':{'signature':'[ string $extension] | object','return_type':'object'},'decompressFiles':{'signature':'void | bool','return_type':'bool'},'delMetadata':{'signature':'void | bool','return_type':'bool'},'delete':{'signature':'string $entry | bool','return_type':'bool'},'extractTo':{'signature':'string $pathto [, string|array $files [, bool $overwrite = false]] | bool','return_type':'bool'},'isWritable':{'signature':'void | bool','return_type':'bool'},'offsetSet':{'signature':'string $offset, string $value | void','return_type':'void'},'offsetUnset':{'signature':'string $offset | bool','return_type':'bool'},'setAlias':{'signature':'string $alias | bool','return_type':'bool'},'setDefaultStub':{'signature':'[ string $index [, string $webindex]] | bool','return_type':'bool'},'setMetadata':{'signature':'mixed $metadata | void','return_type':'void'},'setSignatureAlgorithm':{'signature':'int $sigtype [, string $privatekey] | void','return_type':'void'},'setStub':{'signature':'string $stub [, int $len = -1] | bool','return_type':'bool'},'compressAllFilesBZIP2':{'signature':'void | bool','return_type':'bool'},'compressAllFilesGZ':{'signature':'void | bool','return_type':'bool'},'count':{'signature':'void | int','return_type':'int'},'getMetadata':{'signature':'void | mixed','return_type':'mixed'},'getModified':{'signature':'void | bool','return_type':'bool'},'getSignature':{'signature':'void | array','return_type':'array'},'getStub':{'signature':'void | string','return_type':'string'},'getVersion':{'signature':'void | string','return_type':'string'},'hasMetadata':{'signature':'void | bool','return_type':'bool'},'isBuffering':{'signature':'void | bool','return_type':'bool'},'isCompressed':{'signature':'void | mixed','return_type':'mixed'},'isFileFormat':{'signature':'int $format | bool','return_type':'bool'},'offsetExists':{'signature':'string $offset | bool','return_type':'bool'},'offsetGet':{'signature':'string $offset | int','return_type':'int'},'startBuffering':{'signature':'void | void','return_type':'void'},'stopBuffering':{'signature':'void | void','return_type':'void'},'uncompressAllFiles':{'signature':'void | bool','return_type':'bool'},},'static_methods':{'apiVersion':{'signature':'void | string','return_type':'string'},'canCompress':{'signature':'[ int $type = 0] | bool','return_type':'bool'},'canWrite':{'signature':'void | bool','return_type':'bool'},'createDefaultStub':{'signature':'[ string $indexfile [, string $webindexfile]] | string','return_type':'string'},'getSupportedCompression':{'signature':'void | array','return_type':'array'},'getSupportedSignatures':{'signature':'void | array','return_type':'array'},'interceptFileFuncs':{'signature':'void | void','return_type':'void'},'isValidPharFilename':{'signature':'string $filename [, bool $executable = true] | bool','return_type':'bool'},'loadPhar':{'signature':'string $filename [, string $alias] | bool','return_type':'bool'},'mapPhar':{'signature':'[ string $alias [, int $dataoffset = 0]] | bool','return_type':'bool'},'mount':{'signature':'string $pharpath, string $externalpath | void','return_type':'void'},'mungServer':{'signature':'array $munglist | void','return_type':'void'},'running':{'signature':'[ bool $retphar = true] | string','return_type':'string'},'unlinkArchive':{'signature':'string $archive | bool','return_type':'bool'},'webPhar':{'signature':'[ string $alias [, string $index = "index.php" [, string $f404 [, array $mimetypes [, callable $rewrites]]]]] | void','return_type':'void'},},},'pharexception':{'name':'PharException','properties': {'message':{'initializer':'','type':'string'},'code':{'initializer':'','type':'int'},'file':{'initializer':'','type':'string'},'line':{'initializer':'','type':'int'},},'methods':{'getMessage':{'signature':'void | string','return_type':'string'},'getPrevious':{'signature':'void | Exception','return_type':'Exception'},'getCode':{'signature':'void | mixed','return_type':'mixed'},'getFile':{'signature':'void | string','return_type':'string'},'getLine':{'signature':'void | int','return_type':'int'},'getTrace':{'signature':'void | array','return_type':'array'},'getTraceAsString':{'signature':'void | string','return_type':'string'},'__toString':{'signature':'void | string','return_type':'string'},'__clone':{'signature':'void | void','return_type':'void'},},},'pharfileinfo':{'name':'PharFileInfo','methods':{'chmod':{'signature':'int $permissions | void','return_type':'void'},'compress':{'signature':'int $compression | bool','return_type':'bool'},'__construct':{'signature':'string $entry','return_type':''},'decompress':{'signature':'void | bool','return_type':'bool'},'delMetadata':{'signature':'void | bool','return_type':'bool'},'getCRC32':{'signature':'void | int','return_type':'int'},'getCompressedSize':{'signature':'void | int','return_type':'int'},'getMetadata':{'signature':'void | mixed','return_type':'mixed'},'getPharFlags':{'signature':'void | int','return_type':'int'},'hasMetadata':{'signature':'void | bool','return_type':'bool'},'isCRCChecked':{'signature':'void | bool','return_type':'bool'},'isCompressed':{'signature':'[ int $compression_type = 9021976] | bool','return_type':'bool'},'isCompressedBZIP2':{'signature':'void | bool','return_type':'bool'},'isCompressedGZ':{'signature':'void | bool','return_type':'bool'},'setCompressedBZIP2':{'signature':'void | bool','return_type':'bool'},'setCompressedGZ':{'signature':'void | bool','return_type':'bool'},'setMetadata':{'signature':'mixed $metadata | void','return_type':'void'},'setUncompressed':{'signature':'void | bool','return_type':'bool'},},},}
let php_builtin['classes']['streams']={'php_user_filter':{'name':'php_user_filter','properties': {'filtername':{'initializer':'','type':''},'params':{'initializer':'','type':''},},'methods':{'filter':{'signature':'resource $in, resource $out, int &$consumed, bool $closing | int','return_type':'int'},'onClose':{'signature':'void | void','return_type':'void'},'onCreate':{'signature':'void | bool','return_type':'bool'},},},}
let php_builtin['classes']['sessions']={'sessionhandler':{'name':'SessionHandler','methods':{'close':{'signature':'void | bool','return_type':'bool'},'destroy':{'signature':'string $session_id | bool','return_type':'bool'},'gc':{'signature':'int $maxlifetime | bool','return_type':'bool'},'open':{'signature':'string $save_path, string $session_id | bool','return_type':'bool'},'read':{'signature':'string $session_id | string','return_type':'string'},'write':{'signature':'string $session_id, string $session_data | bool','return_type':'bool'},},},'sessionhandlerinterface':{'name':'SessionHandlerInterface','methods':{'close':{'signature':'void | bool','return_type':'bool'},'destroy':{'signature':'string $session_id | bool','return_type':'bool'},'gc':{'signature':'string $maxlifetime | bool','return_type':'bool'},'open':{'signature':'string $save_path, string $name | bool','return_type':'bool'},'read':{'signature':'string $session_id | string','return_type':'string'},'write':{'signature':'string $session_id, string $session_data | bool','return_type':'bool'},},},}
let php_builtin['classes']['simplexml']={'simplexmlelement':{'name':'SimpleXMLElement','methods':{'__construct':{'signature':'string $data [, int $options = 0 [, bool $data_is_url = false [, string $ns = "" [, bool $is_prefix = false]]]]','return_type':''},'addAttribute':{'signature':'string $name [, string $value [, string $namespace]] | void','return_type':'void'},'addChild':{'signature':'string $name [, string $value [, string $namespace]] | SimpleXMLElement','return_type':'SimpleXMLElement'},'asXML':{'signature':'[ string $filename] | mixed','return_type':'mixed'},'attributes':{'signature':'[ string $ns = NULL [, bool $is_prefix = false]] | SimpleXMLElement','return_type':'SimpleXMLElement'},'children':{'signature':'[ string $ns [, bool $is_prefix = false]] | SimpleXMLElement','return_type':'SimpleXMLElement'},'count':{'signature':'void | int','return_type':'int'},'getDocNamespaces':{'signature':'[ bool $recursive = false [, bool $from_root = true]] | array','return_type':'array'},'getName':{'signature':'void | string','return_type':'string'},'getNamespaces':{'signature':'[ bool $recursive = false] | array','return_type':'array'},'registerXPathNamespace':{'signature':'string $prefix, string $ns | bool','return_type':'bool'},'__toString':{'signature':'void | string','return_type':'string'},'xpath':{'signature':'string $path | array','return_type':'array'},},},'simplexmliterator':{'name':'SimpleXMLIterator','methods':{'current':{'signature':'void | mixed','return_type':'mixed'},'getChildren':{'signature':'void | SimpleXMLIterator','return_type':'SimpleXMLIterator'},'hasChildren':{'signature':'void | bool','return_type':'bool'},'key':{'signature':'void | mixed','return_type':'mixed'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | bool','return_type':'bool'},'__construct':{'signature':'string $data [, int $options = 0 [, bool $data_is_url = false [, string $ns = "" [, bool $is_prefix = false]]]]','return_type':''},'addAttribute':{'signature':'string $name [, string $value [, string $namespace]] | void','return_type':'void'},'addChild':{'signature':'string $name [, string $value [, string $namespace]] | SimpleXMLElement','return_type':'SimpleXMLElement'},'asXML':{'signature':'[ string $filename] | mixed','return_type':'mixed'},'attributes':{'signature':'[ string $ns = NULL [, bool $is_prefix = false]] | SimpleXMLElement','return_type':'SimpleXMLElement'},'children':{'signature':'[ string $ns [, bool $is_prefix = false]] | SimpleXMLElement','return_type':'SimpleXMLElement'},'count':{'signature':'void | int','return_type':'int'},'getDocNamespaces':{'signature':'[ bool $recursive = false [, bool $from_root = true]] | array','return_type':'array'},'getName':{'signature':'void | string','return_type':'string'},'getNamespaces':{'signature':'[ bool $recursive = false] | array','return_type':'array'},'registerXPathNamespace':{'signature':'string $prefix, string $ns | bool','return_type':'bool'},'__toString':{'signature':'void | string','return_type':'string'},'xpath':{'signature':'string $path | array','return_type':'array'},},},}
let php_builtin['classes']['spl_types']={'splbool':{'name':'SplBool','constants':{'__default':'false','false':'false','true':'true',},'methods':{'getConstList':{'signature':'[ bool $include_default = false] | array','return_type':'array'},},},'splenum':{'name':'SplEnum','constants':{'__default':'null',},'methods':{'getConstList':{'signature':'[ bool $include_default = false] | array','return_type':'array'},'__construct':{'signature':'[ mixed $initial_value [, bool $strict]]','return_type':''},},},'splfloat':{'name':'SplFloat','constants':{'__default':'0',},'methods':{'__construct':{'signature':'[ mixed $initial_value [, bool $strict]]','return_type':''},},},'splint':{'name':'SplInt','constants':{'__default':'0',},'methods':{'__construct':{'signature':'[ mixed $initial_value [, bool $strict]]','return_type':''},},},'splstring':{'name':'SplString','constants':{'__default':'0',},'methods':{'__construct':{'signature':'[ mixed $initial_value [, bool $strict]]','return_type':''},},},'spltype':{'name':'SplType','constants':{'__default':'null',},'methods':{'__construct':{'signature':'[ mixed $initial_value [, bool $strict]]','return_type':''},},},}
let php_builtin['classes']['xmlreader']={'xmlreader':{'name':'XMLReader','constants':{'NONE':'0','ELEMENT':'1','ATTRIBUTE':'2','TEXT':'3','CDATA':'4','ENTITY_REF':'5','ENTITY':'6','PI':'7','COMMENT':'8','DOC':'9','DOC_TYPE':'10','DOC_FRAGMENT':'11','NOTATION':'12','WHITESPACE':'13','SIGNIFICANT_WHITESPACE':'14','END_ELEMENT':'15','END_ENTITY':'16','XML_DECLARATION':'17','LOADDTD':'1','DEFAULTATTRS':'2','VALIDATE':'3','SUBST_ENTITIES':'4',},'properties': {'attributeCount':{'initializer':'','type':'int'},'baseURI':{'initializer':'','type':'string'},'depth':{'initializer':'','type':'int'},'hasAttributes':{'initializer':'','type':'bool'},'hasValue':{'initializer':'','type':'bool'},'isDefault':{'initializer':'','type':'bool'},'isEmptyElement':{'initializer':'','type':'bool'},'localName':{'initializer':'','type':'string'},'name':{'initializer':'','type':'string'},'namespaceURI':{'initializer':'','type':'string'},'nodeType':{'initializer':'','type':'int'},'prefix':{'initializer':'','type':'string'},'value':{'initializer':'','type':'string'},'xmlLang':{'initializer':'','type':'string'},},'methods':{'close':{'signature':'void | bool','return_type':'bool'},'expand':{'signature':'[ DOMNode $basenode] | DOMNode','return_type':'DOMNode'},'getAttribute':{'signature':'string $name | string','return_type':'string'},'getAttributeNo':{'signature':'int $index | string','return_type':'string'},'getAttributeNs':{'signature':'string $localName, string $namespaceURI | string','return_type':'string'},'getParserProperty':{'signature':'int $property | bool','return_type':'bool'},'isValid':{'signature':'void | bool','return_type':'bool'},'lookupNamespace':{'signature':'string $prefix | bool','return_type':'bool'},'moveToAttribute':{'signature':'string $name | bool','return_type':'bool'},'moveToAttributeNo':{'signature':'int $index | bool','return_type':'bool'},'moveToAttributeNs':{'signature':'string $localName, string $namespaceURI | bool','return_type':'bool'},'moveToElement':{'signature':'void | bool','return_type':'bool'},'moveToFirstAttribute':{'signature':'void | bool','return_type':'bool'},'moveToNextAttribute':{'signature':'void | bool','return_type':'bool'},'next':{'signature':'[ string $localname] | bool','return_type':'bool'},'open':{'signature':'string $URI [, string $encoding [, int $options = 0]] | bool','return_type':'bool'},'read':{'signature':'void | bool','return_type':'bool'},'readInnerXML':{'signature':'void | string','return_type':'string'},'readOuterXML':{'signature':'void | string','return_type':'string'},'readString':{'signature':'void | string','return_type':'string'},'setParserProperty':{'signature':'int $property, bool $value | bool','return_type':'bool'},'setRelaxNGSchema':{'signature':'string $filename | bool','return_type':'bool'},'setRelaxNGSchemaSource':{'signature':'string $source | bool','return_type':'bool'},'setSchema':{'signature':'string $filename | bool','return_type':'bool'},'xml':{'signature':'string $source [, string $encoding [, int $options = 0]] | bool','return_type':'bool'},},},}
let php_builtin['classes']['xmlwriter'] = {'xmlwriter':{'name':'XMLWriter','methods':{'endAttribute':{'signature':'void | bool','return_type':'bool'},'endCData':{'signature':'void | bool','return_type':'bool'},'endComment':{'signature':'void | bool','return_type':'bool'},'endDocument':{'signature':'void | bool','return_type':'bool'},'endDTDAttlist':{'signature':'void | bool','return_type':'bool'},'endDTDElement':{'signature':'void | bool','return_type':'bool'},'endDTDEntity':{'signature':'void | bool','return_type':'bool'},'endDTD':{'signature':'void | bool','return_type':'bool'},'endElement':{'signature':'void | bool','return_type':'bool'},'endPI':{'signature':'void | bool','return_type':'bool'},'flush':{'signature':'[bool $empty = true] | bool','return_type':'bool'},'fullEndElement':{'signature':'void | bool','return_type':'bool'},'openMemory':{'signature':'void | bool','return_type':'bool'},'openURI':{'signature':'string $uri | bool','return_type':'bool'},'outputMemory':{'signature':'[bool $flush = true] | bool','return_type':'bool'},'setIndentString':{'signature':'string $indentString | bool','return_type':'bool'},'setIndent':{'signature':'bool $indent | bool','return_type':'bool'},'startAttributeNS':{'signature':'string $prefix, string $name, string $uri | bool','return_type':'bool'},'startAttribute':{'signature':'string $name | bool','return_type':'bool'},'startCData':{'signature':'void | bool','return_type':'bool'},'startComment':{'signature':'void | bool','return_type':'bool'},'startDocument':{'signature':'[string $version = 1.0 [, string $encoding = NULL [, string $standalone ]]] | bool','return_type':'bool'},'startDTDAttlist':{'signature':'string $name | bool','return_type':'bool'},'startDTDElement':{'signature':'string $qualifiedName | bool','return_type':'bool'},'startDTDEntity':{'signature':'string $name, bool $isparam | bool','return_type':'bool'},'startDTD':{'signature':'string $qualifiedName [, string $publicId [, string $systemId ]] | bool','return_type':'bool'},'startElementNS':{'signature':'string $prefix, string $name, string $uri | bool','return_type':'bool'},'startElement':{'signature':'string $name | bool','return_type':'bool'},'startPI':{'signature':'string $target | bool','return_type':'bool'},'text':{'signature':'string $content | bool','return_type':'bool'},'writeAttributeNS':{'signature':'string $prefix, string $name, string $uri, string $content | bool','return_type':'bool'},'writeAttribute':{'signature':'string $name, string $value | bool','return_type':'bool'},'writeCData':{'signature':'string $content | bool','return_type':'bool'},'writeComment':{'signature':'string $content | bool','return_type':'bool'},'writeDTDAttlist':{'signature':'string $name, string $content | bool','return_type':'bool'},'writeDTDElement':{'signature':'string $name, string $content | bool','return_type':'bool'},'writeDTDEntity':{'signature':'string $name, string $content, bool $pe, string $pubid, string $sysid, string $ndataid | bool','return_type':'bool'},'writeDTD':{'signature':'string $name [, string $publicId [, string $systemId [, string $subset ]]] | bool','return_type':'bool'},'writeElementNS':{'signature':'string $prefix, string $name, string $uri [, string $content ] | bool','return_type':'bool'},'writeElement':{'signature':'string $name [, string $content ] | bool','return_type':'bool'},'writePI':{'signature':'string $target, string $content | bool','return_type':'bool'},'writeRaw':{'signature':'string $content | bool','return_type':'bool'},},},}
let php_builtin['classes']['zip']={'ziparchive':{'name':'ZipArchive','properties': {'status':{'initializer':'','type':'int'},'statusSys':{'initializer':'','type':'int'},'numFiles':{'initializer':'','type':'int'},'filename':{'initializer':'','type':'string'},'comment':{'initializer':'','type':'string'},},'methods':{'addEmptyDir':{'signature':'string $dirname | bool','return_type':'bool'},'addFile':{'signature':'string $filename [, string $localname = NULL [, int $start = 0 [, int $length = 0]]] | bool','return_type':'bool'},'addFromString':{'signature':'string $localname, string $contents | bool','return_type':'bool'},'addGlob':{'signature':'string $pattern [, int $flags = 0 [, array $options = array()]] | bool','return_type':'bool'},'addPattern':{'signature':'string $pattern [, string $path = ''.'' [, array $options = array()]] | bool','return_type':'bool'},'close':{'signature':'void | bool','return_type':'bool'},'deleteIndex':{'signature':'int $index | bool','return_type':'bool'},'deleteName':{'signature':'string $name | bool','return_type':'bool'},'extractTo':{'signature':'string $destination [, mixed $entries] | bool','return_type':'bool'},'getArchiveComment':{'signature':'[ int $flags] | string','return_type':'string'},'getCommentIndex':{'signature':'int $index [, int $flags] | string','return_type':'string'},'getCommentName':{'signature':'string $name [, int $flags] | string','return_type':'string'},'getFromIndex':{'signature':'int $index [, int $length = 0 [, int $flags]] | string','return_type':'string'},'getFromName':{'signature':'string $name [, int $length = 0 [, int $flags]] | string','return_type':'string'},'getNameIndex':{'signature':'int $index [, int $flags] | string','return_type':'string'},'getStatusString':{'signature':'void | string','return_type':'string'},'getStream':{'signature':'string $name | resource','return_type':'resource'},'locateName':{'signature':'string $name [, int $flags] | int','return_type':'int'},'open':{'signature':'string $filename [, int $flags] | mixed','return_type':'mixed'},'renameIndex':{'signature':'int $index, string $newname | bool','return_type':'bool'},'renameName':{'signature':'string $name, string $newname | bool','return_type':'bool'},'setArchiveComment':{'signature':'string $comment | bool','return_type':'bool'},'setCommentIndex':{'signature':'int $index, string $comment | bool','return_type':'bool'},'setCommentName':{'signature':'string $name, string $comment | bool','return_type':'bool'},'statIndex':{'signature':'int $index [, int $flags] | array','return_type':'array'},'statName':{'signature':'string $name [, int $flags] | array','return_type':'array'},'unchangeAll':{'signature':'void | bool','return_type':'bool'},'unchangeArchive':{'signature':'void | bool','return_type':'bool'},'unchangeIndex':{'signature':'int $index | bool','return_type':'bool'},'unchangeName':{'signature':'string $name | bool','return_type':'bool'},},},}
let php_builtin['interfaces']['predefined_interfaces_and_classes']={'arrayaccess':{'name':'ArrayAccess','methods':{'offsetExists':{'signature':'mixed $offset | boolean','return_type':'boolean'},'offsetGet':{'signature':'mixed $offset | mixed','return_type':'mixed'},'offsetSet':{'signature':'mixed $offset, mixed $value | void','return_type':'void'},'offsetUnset':{'signature':'mixed $offset | void','return_type':'void'},},},'iterator':{'name':'Iterator','methods':{'current':{'signature':'void | mixed','return_type':'mixed'},'key':{'signature':'void | scalar','return_type':'scalar'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | boolean','return_type':'boolean'},},},'iteratoraggregate':{'name':'IteratorAggregate','methods':{'getIterator':{'signature':'void | Traversable','return_type':'Traversable'},},},'serializable':{'name':'Serializable','methods':{'serialize':{'signature':'void | string','return_type':'string'},'unserialize':{'signature':'string $serialized | void','return_type':'void'},},},'traversable':{'name':'Traversable',},}
let php_builtin['interfaces']['spl']={'countable':{'name':'Countable','methods':{'count':{'signature':'void | int','return_type':'int'},},},'outeriterator':{'name':'OuterIterator','methods':{'getInnerIterator':{'signature':'void | Iterator','return_type':'Iterator'},'current':{'signature':'void | mixed','return_type':'mixed'},'key':{'signature':'void | scalar','return_type':'scalar'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | boolean','return_type':'boolean'},},},'recursiveiterator':{'name':'RecursiveIterator','methods':{'getChildren':{'signature':'void | RecursiveIterator','return_type':'RecursiveIterator'},'hasChildren':{'signature':'void | bool','return_type':'bool'},'current':{'signature':'void | mixed','return_type':'mixed'},'key':{'signature':'void | scalar','return_type':'scalar'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | boolean','return_type':'boolean'},},},'seekableiterator':{'name':'SeekableIterator','methods':{'seek':{'signature':'int $position | void','return_type':'void'},'current':{'signature':'void | mixed','return_type':'mixed'},'key':{'signature':'void | scalar','return_type':'scalar'},'next':{'signature':'void | void','return_type':'void'},'rewind':{'signature':'void | void','return_type':'void'},'valid':{'signature':'void | boolean','return_type':'boolean'},},},'splobserver':{'name':'SplObserver','methods':{'update':{'signature':'SplSubject $subject | void','return_type':'void'},},},'splsubject':{'name':'SplSubject','methods':{'attach':{'signature':'SplObserver $observer | void','return_type':'void'},'detach':{'signature':'SplObserver $observer | void','return_type':'void'},'notify':{'signature':'void | void','return_type':'void'},},},}
let php_builtin['interfaces']['date_time']={'datetimeinterface':{'name':'DateTimeInterface','methods':{'diff':{'signature':'DateTimeInterface $datetime2 [, bool $absolute = false] | DateInterval','return_type':'DateInterval'},'format':{'signature':'string $format | string','return_type':'string'},'getOffset':{'signature':'void | int','return_type':'int'},'getTimestamp':{'signature':'void | int','return_type':'int'},'getTimezone':{'signature':'void | DateTimeZone','return_type':'DateTimeZone'},'__wakeup':{'signature':'void','return_type':''},},},}
let php_builtin['interfaces']['json']={'jsonserializable':{'name':'JsonSerializable','methods':{'jsonSerialize':{'signature':'void | mixed','return_type':'mixed'},},},}
let php_builtin['constants']['common']={'TRUE':'','FALSE':'','NULL':'','E_NOTICE':'','E_DEPRECATED':'','E_RECOVERABLE_ERROR':'','E_ALL':'','E_STRICT':'','E_WARNING':'','E_ERROR':'','E_PARSE':'','E_CORE_ERROR':'','E_CORE_WARNING':'','E_COMPILE_ERROR':'','E_COMPILE_WARNING':'','E_USER_ERROR':'','E_USER_WARNING':'','E_USER_NOTICE':'','E_USER_DEPRECATED':'','__COMPILER_HALT_OFFSET__':'','__FILE__':'','__LINE__':'','__DIR__':'','__FUNCTION__':'','__CLASS__':'','__TRAIT__':'','__METHOD__':'','__NAMESPACE__':'',}
let php_builtin['constants']['arrays']={'CASE_LOWER':'','CASE_UPPER':'','SORT_ASC':'','SORT_DESC':'','SORT_REGULAR':'','SORT_NUMERIC':'','SORT_STRING':'','SORT_LOCALE_STRING':'','SORT_NATURAL':'','SORT_FLAG_CASE':'','COUNT_NORMAL':'','COUNT_RECURSIVE':'','EXTR_OVERWRITE':'','EXTR_SKIP':'','EXTR_PREFIX_SAME':'','EXTR_PREFIX_ALL':'','EXTR_PREFIX_INVALID':'','EXTR_PREFIX_IF_EXISTS':'','EXTR_IF_EXISTS':'','EXTR_REFS':'',}
let php_builtin['constants']['calendar']={'CAL_GREGORIAN':'','CAL_JULIAN':'','CAL_JEWISH':'','CAL_FRENCH':'','CAL_NUM_CALS':'','CAL_DOW_DAYNO':'','CAL_DOW_SHORT':'','CAL_DOW_LONG':'','CAL_MONTH_GREGORIAN_SHORT':'','CAL_MONTH_GREGORIAN_LONG':'','CAL_MONTH_JULIAN_SHORT':'','CAL_MONTH_JULIAN_LONG':'','CAL_MONTH_JEWISH':'','CAL_MONTH_FRENCH':'','CAL_EASTER_DEFAULT':'','CAL_EASTER_ROMAN':'','CAL_EASTER_ALWAYS_GREGORIAN':'','CAL_EASTER_ALWAYS_JULIAN':'','CAL_JEWISH_ADD_ALAFIM_GERESH':'','CAL_JEWISH_ADD_ALAFIM':'','CAL_JEWISH_ADD_GERESHAYIM':'',}
let php_builtin['constants']['curl']={'CURLOPT_POSTFIELDS':'','CURLOPT_CAINFO':'','CURLOPT_AUTOREFERER':'','CURLOPT_COOKIESESSION':'','CURLOPT_DNS_USE_GLOBAL_CACHE':'','CURLOPT_DNS_CACHE_TIMEOUT':'','CURLOPT_FTP_SSL':'','CURLFTPSSL_TRY':'','CURLFTPSSL_ALL':'','CURLFTPSSL_CONTROL':'','CURLFTPSSL_NONE':'','CURLOPT_PRIVATE':'','CURLOPT_FTPSSLAUTH':'','CURLOPT_PORT':'','CURLOPT_FILE':'','CURLOPT_INFILE':'','CURLOPT_INFILESIZE':'','CURLOPT_URL':'','CURLOPT_PROXY':'','CURLOPT_VERBOSE':'','CURLOPT_HEADER':'','CURLOPT_HTTPHEADER':'','CURLOPT_NOPROGRESS':'','CURLOPT_NOBODY':'','CURLOPT_FAILONERROR':'','CURLOPT_UPLOAD':'','CURLOPT_POST':'','CURLOPT_FTPLISTONLY':'','CURLOPT_FTPAPPEND':'','CURLOPT_FTP_CREATE_MISSING_DIRS':'','CURLOPT_NETRC':'','CURLOPT_FOLLOWLOCATION':'','CURLOPT_FTPASCII':'','CURLOPT_PUT':'','CURLOPT_MUTE':'','CURLOPT_USERPWD':'','CURLOPT_PROXYUSERPWD':'','CURLOPT_RANGE':'','CURLOPT_TIMEOUT':'','CURLOPT_TIMEOUT_MS':'','CURLOPT_TCP_NODELAY':'','CURLOPT_PROGRESSFUNCTION':'','CURLOPT_REFERER':'','CURLOPT_USERAGENT':'','CURLOPT_FTPPORT':'','CURLOPT_FTP_USE_EPSV':'','CURLOPT_LOW_SPEED_LIMIT':'','CURLOPT_LOW_SPEED_TIME':'','CURLOPT_RESUME_FROM':'','CURLOPT_COOKIE':'','CURLOPT_SSLCERT':'','CURLOPT_SSLCERTPASSWD':'','CURLOPT_WRITEHEADER':'','CURLOPT_SSL_VERIFYHOST':'','CURLOPT_COOKIEFILE':'','CURLOPT_SSLVERSION':'','CURLOPT_TIMECONDITION':'','CURLOPT_TIMEVALUE':'','CURLOPT_CUSTOMREQUEST':'','CURLOPT_STDERR':'','CURLOPT_TRANSFERTEXT':'','CURLOPT_RETURNTRANSFER':'','CURLOPT_QUOTE':'','CURLOPT_POSTQUOTE':'','CURLOPT_INTERFACE':'','CURLOPT_KRB4LEVEL':'','CURLOPT_HTTPPROXYTUNNEL':'','CURLOPT_FILETIME':'','CURLOPT_WRITEFUNCTION':'','CURLOPT_READFUNCTION':'','CURLOPT_PASSWDFUNCTION':'','CURLOPT_HEADERFUNCTION':'','CURLOPT_MAXREDIRS':'','CURLOPT_MAXCONNECTS':'','CURLOPT_CLOSEPOLICY':'','CURLOPT_FRESH_CONNECT':'','CURLOPT_FORBID_REUSE':'','CURLOPT_RANDOM_FILE':'','CURLOPT_EGDSOCKET':'','CURLOPT_CONNECTTIMEOUT':'','CURLOPT_CONNECTTIMEOUT_MS':'','CURLOPT_SSL_VERIFYPEER':'','CURLOPT_CAPATH':'','CURLOPT_COOKIEJAR':'','CURLOPT_SSL_CIPHER_LIST':'','CURLOPT_BINARYTRANSFER':'','CURLOPT_NOSIGNAL':'','CURLOPT_PROXYTYPE':'','CURLOPT_BUFFERSIZE':'','CURLOPT_HTTPGET':'','CURLOPT_HTTP_VERSION':'','CURLOPT_SSLKEY':'','CURLOPT_SSLKEYTYPE':'','CURLOPT_SSLKEYPASSWD':'','CURLOPT_SSLENGINE':'','CURLOPT_SSLENGINE_DEFAULT':'','CURLOPT_SSLCERTTYPE':'','CURLOPT_CRLF':'','CURLOPT_ENCODING':'','CURLOPT_PROXYPORT':'','CURLOPT_UNRESTRICTED_AUTH':'','CURLOPT_FTP_USE_EPRT':'','CURLOPT_HTTP200ALIASES':'','CURLOPT_HTTPAUTH':'','CURLAUTH_BASIC':'','CURLAUTH_DIGEST':'','CURLAUTH_GSSNEGOTIATE':'','CURLAUTH_NTLM':'','CURLAUTH_ANY':'','CURLAUTH_ANYSAFE':'','CURLOPT_PROXYAUTH':'','CURLOPT_MAX_RECV_SPEED_LARGE':'','CURLOPT_MAX_SEND_SPEED_LARGE':'','CURLCLOSEPOLICY_LEAST_RECENTLY_USED':'','CURLCLOSEPOLICY_LEAST_TRAFFIC':'','CURLCLOSEPOLICY_SLOWEST':'','CURLCLOSEPOLICY_CALLBACK':'','CURLCLOSEPOLICY_OLDEST':'','CURLINFO_PRIVATE':'','CURLINFO_EFFECTIVE_URL':'','CURLINFO_HTTP_CODE':'','CURLINFO_HEADER_OUT':'','CURLINFO_HEADER_SIZE':'','CURLINFO_REQUEST_SIZE':'','CURLINFO_TOTAL_TIME':'','CURLINFO_NAMELOOKUP_TIME':'','CURLINFO_CONNECT_TIME':'','CURLINFO_PRETRANSFER_TIME':'','CURLINFO_SIZE_UPLOAD':'','CURLINFO_SIZE_DOWNLOAD':'','CURLINFO_SPEED_DOWNLOAD':'','CURLINFO_SPEED_UPLOAD':'','CURLINFO_FILETIME':'','CURLINFO_SSL_VERIFYRESULT':'','CURLINFO_CONTENT_LENGTH_DOWNLOAD':'','CURLINFO_CONTENT_LENGTH_UPLOAD':'','CURLINFO_STARTTRANSFER_TIME':'','CURLINFO_CONTENT_TYPE':'','CURLINFO_REDIRECT_TIME':'','CURLINFO_REDIRECT_COUNT':'','CURL_TIMECOND_IFMODSINCE':'','CURL_TIMECOND_IFUNMODSINCE':'','CURL_TIMECOND_LASTMOD':'','CURL_VERSION_IPV6':'','CURL_VERSION_KERBEROS4':'','CURL_VERSION_SSL':'','CURL_VERSION_LIBZ':'','CURLVERSION_NOW':'','CURLE_OK':'','CURLE_UNSUPPORTED_PROTOCOL':'','CURLE_FAILED_INIT':'','CURLE_URL_MALFORMAT':'','CURLE_URL_MALFORMAT_USER':'','CURLE_COULDNT_RESOLVE_PROXY':'','CURLE_COULDNT_RESOLVE_HOST':'','CURLE_COULDNT_CONNECT':'','CURLE_FTP_WEIRD_SERVER_REPLY':'','CURLE_FTP_ACCESS_DENIED':'','CURLE_FTP_USER_PASSWORD_INCORRECT':'','CURLE_FTP_WEIRD_PASS_REPLY':'','CURLE_FTP_WEIRD_USER_REPLY':'','CURLE_FTP_WEIRD_PASV_REPLY':'','CURLE_FTP_WEIRD_227_FORMAT':'','CURLE_FTP_CANT_GET_HOST':'','CURLE_FTP_CANT_RECONNECT':'','CURLE_FTP_COULDNT_SET_BINARY':'','CURLE_PARTIAL_FILE':'','CURLE_FTP_COULDNT_RETR_FILE':'','CURLE_FTP_WRITE_ERROR':'','CURLE_FTP_QUOTE_ERROR':'','CURLE_HTTP_NOT_FOUND':'','CURLE_WRITE_ERROR':'','CURLE_MALFORMAT_USER':'','CURLE_FTP_COULDNT_STOR_FILE':'','CURLE_READ_ERROR':'','CURLE_OUT_OF_MEMORY':'','CURLE_OPERATION_TIMEOUTED':'','CURLE_FTP_COULDNT_SET_ASCII':'','CURLE_FTP_PORT_FAILED':'','CURLE_FTP_COULDNT_USE_REST':'','CURLE_FTP_COULDNT_GET_SIZE':'','CURLE_HTTP_RANGE_ERROR':'','CURLE_HTTP_POST_ERROR':'','CURLE_SSL_CONNECT_ERROR':'','CURLE_FTP_BAD_DOWNLOAD_RESUME':'','CURLE_FILE_COULDNT_READ_FILE':'','CURLE_LDAP_CANNOT_BIND':'','CURLE_LDAP_SEARCH_FAILED':'','CURLE_LIBRARY_NOT_FOUND':'','CURLE_FUNCTION_NOT_FOUND':'','CURLE_ABORTED_BY_CALLBACK':'','CURLE_BAD_FUNCTION_ARGUMENT':'','CURLE_BAD_CALLING_ORDER':'','CURLE_HTTP_PORT_FAILED':'','CURLE_BAD_PASSWORD_ENTERED':'','CURLE_TOO_MANY_REDIRECTS':'','CURLE_UNKNOWN_TELNET_OPTION':'','CURLE_TELNET_OPTION_SYNTAX':'','CURLE_OBSOLETE':'','CURLE_SSL_PEER_CERTIFICATE':'','CURLE_GOT_NOTHING':'','CURLE_SSL_ENGINE_NOTFOUND':'','CURLE_SSL_ENGINE_SETFAILED':'','CURLE_SEND_ERROR':'','CURLE_RECV_ERROR':'','CURLE_SHARE_IN_USE':'','CURLE_SSL_CERTPROBLEM':'','CURLE_SSL_CIPHER':'','CURLE_SSL_CACERT':'','CURLE_BAD_CONTENT_ENCODING':'','CURLE_LDAP_INVALID_URL':'','CURLE_FILESIZE_EXCEEDED':'','CURLE_FTP_SSL_FAILED':'','CURLFTPAUTH_DEFAULT':'','CURLFTPAUTH_SSL':'','CURLFTPAUTH_TLS':'','CURLPROXY_HTTP':'','CURLPROXY_SOCKS5':'','CURL_NETRC_OPTIONAL':'','CURL_NETRC_IGNORED':'','CURL_NETRC_REQUIRED':'','CURL_HTTP_VERSION_NONE':'','CURL_HTTP_VERSION_1_0':'','CURL_HTTP_VERSION_1_1':'','CURLM_CALL_MULTI_PERFORM':'','CURLM_OK':'','CURLM_BAD_HANDLE':'','CURLM_BAD_EASY_HANDLE':'','CURLM_OUT_OF_MEMORY':'','CURLM_INTERNAL_ERROR':'','CURLMSG_DONE':'','CURLOPT_KEYPASSWD':'','CURLOPT_SSH_AUTH_TYPES':'','CURLOPT_SSH_HOST_PUBLIC_KEY_MD5':'','CURLOPT_SSH_PRIVATE_KEYFILE':'','CURLOPT_SSH_PUBLIC_KEYFILE':'','CURLMOPT_PIPELINING':'','CURLMOPT_MAXCONNECTS':'','CURLSSH_AUTH_ANY':'','CURLSSH_AUTH_DEFAULT':'','CURLSSH_AUTH_HOST':'','CURLSSH_AUTH_KEYBOARD':'','CURLSSH_AUTH_NONE':'','CURLSSH_AUTH_PASSWORD':'','CURLSSH_AUTH_PUBLICKEY':'','CURL_WRAPPERS_ENABLED':'','CURLPAUSE_ALL':'','CURLPAUSE_CONT':'','CURLPAUSE_RECV':'','CURLPAUSE_RECV_CONT':'','CURLPAUSE_SEND':'','CURLPAUSE_SEND_CONT':'','CURLM_XXX':'','CURLOPT_CERTINFO':'','CURLOPT_CONNECT_ONLY':'','CURLINFO_':'','CURLOPT_PROTOCOLS':'','CURLOPT_REDIR_PROTOCOLS':'','CURLOPT_IPRESOLVE':'','CURL_IPRESOLVE_WHATEVER':'','CURL_IPRESOLVE_V4':'','CURL_IPRESOLVE_V6':'','CURLOPT_SHARE':'','CURLSHOPT_SHARE':'','CURLSHOPT_UNSHARE':'','CURL_LOCK_DATA_COOKIE':'','CURL_LOCK_DATA_DNS':'','CURL_LOCK_DATA_SSL_SESSION':'',}
let php_builtin['constants']['date_time']={'DATE_ATOM':'','DATE_COOKIE':'','DATE_ISO8601':'','DATE_RFC822':'','DATE_RFC850':'','DATE_RFC1036':'','DATE_RFC1123':'','DATE_RFC2822':'','DATE_RFC3339':'','DATE_RSS':'','DATE_W3C':'','SUNFUNCS_RET_TIMESTAMP':'','SUNFUNCS_RET_STRING':'','SUNFUNCS_RET_DOUBLE':'','LC_TIME':'',}
let php_builtin['constants']['libxml']={'LIBXML_ERR_WARNING':'','LIBXML_ERR_ERROR':'','LIBXML_ERR_FATAL':'','LIBXML_NONET':'','LIBXML_COMPACT':'','LIBXML_DTDATTR':'','LIBXML_DTDLOAD':'','LIBXML_DTDVALID':'','LIBXML_HTML_NOIMPLIED':'','LIBXML_HTML_NODEFDTD':'','LIBXML_NOBLANKS':'','LIBXML_NOCDATA':'','LIBXML_NOEMPTYTAG':'','LIBXML_NOENT':'','LIBXML_NOERROR':'','LIBXML_NOWARNING':'','LIBXML_NOXMLDECL':'','LIBXML_NSCLEAN':'','LIBXML_PARSEHUGE':'','LIBXML_PEDANTIC':'','LIBXML_XINCLUDE':'','LIBXML_ERR_NONE':'','LIBXML_VERSION':'','LIBXML_DOTTED_VERSION':'','LIBXML_SCHEMA_CREATE':'',}
let php_builtin['constants']['mysqli']={'MYSQLI_REPORT_OFF':'','MYSQLI_REPORT_ALL':'','MYSQLI_REPORT_STRICT':'','MYSQLI_REPORT_ERROR':'','MYSQLI_REPORT_INDEX':'','MYSQLI_ASSOC':'','MYSQLI_NUM':'','MYSQLI_BOTH':'','PHP_INT_MAX':'','MYSQLI_READ_DEFAULT_GROUP':'','MYSQLI_READ_DEFAULT_FILE':'','MYSQLI_OPT_CONNECT_TIMEOUT':'','MYSQLI_OPT_LOCAL_INFILE':'','MYSQLI_INIT_COMMAND':'','MYSQLI_CLIENT_SSL':'','MYSQLI_CLIENT_COMPRESS':'','MYSQLI_CLIENT_INTERACTIVE':'','MYSQLI_CLIENT_IGNORE_SPACE':'','MYSQLI_CLIENT_NO_SCHEMA':'','MYSQLI_CLIENT_MULTI_QUERIES':'','MYSQLI_STORE_RESULT':'','MYSQLI_USE_RESULT':'','MYSQLI_NOT_NULL_FLAG':'','MYSQLI_PRI_KEY_FLAG':'','MYSQLI_UNIQUE_KEY_FLAG':'','MYSQLI_MULTIPLE_KEY_FLAG':'','MYSQLI_BLOB_FLAG':'','MYSQLI_UNSIGNED_FLAG':'','MYSQLI_ZEROFILL_FLAG':'','MYSQLI_AUTO_INCREMENT_FLAG':'','MYSQLI_TIMESTAMP_FLAG':'','MYSQLI_SET_FLAG':'','MYSQLI_NUM_FLAG':'','MYSQLI_PART_KEY_FLAG':'','MYSQLI_GROUP_FLAG':'','MYSQLI_TYPE_DECIMAL':'','MYSQLI_TYPE_NEWDECIMAL':'','MYSQLI_TYPE_BIT':'','MYSQLI_TYPE_TINY':'','MYSQLI_TYPE_SHORT':'','MYSQLI_TYPE_LONG':'','MYSQLI_TYPE_FLOAT':'','MYSQLI_TYPE_DOUBLE':'','MYSQLI_TYPE_NULL':'','MYSQLI_TYPE_TIMESTAMP':'','MYSQLI_TYPE_LONGLONG':'','MYSQLI_TYPE_INT24':'','MYSQLI_TYPE_DATE':'','MYSQLI_TYPE_TIME':'','MYSQLI_TYPE_DATETIME':'','MYSQLI_TYPE_YEAR':'','MYSQLI_TYPE_NEWDATE':'','MYSQLI_TYPE_INTERVAL':'','MYSQLI_TYPE_ENUM':'','MYSQLI_TYPE_SET':'','MYSQLI_TYPE_TINY_BLOB':'','MYSQLI_TYPE_MEDIUM_BLOB':'','MYSQLI_TYPE_LONG_BLOB':'','MYSQLI_TYPE_BLOB':'','MYSQLI_TYPE_VAR_STRING':'','MYSQLI_TYPE_STRING':'','MYSQLI_TYPE_CHAR':'','MYSQLI_TYPE_GEOMETRY':'','MYSQLI_NEED_DATA':'','MYSQLI_NO_DATA':'','MYSQLI_DATA_TRUNCATED':'','MYSQLI_ENUM_FLAG':'','MYSQLI_BINARY_FLAG':'','MYSQLI_CURSOR_TYPE_FOR_UPDATE':'','MYSQLI_CURSOR_TYPE_NO_CURSOR':'','MYSQLI_CURSOR_TYPE_READ_ONLY':'','MYSQLI_CURSOR_TYPE_SCROLLABLE':'','MYSQLI_STMT_ATTR_CURSOR_TYPE':'','MYSQLI_STMT_ATTR_PREFETCH_ROWS':'','MYSQLI_STMT_ATTR_UPDATE_MAX_LENGTH':'','MYSQLI_SET_CHARSET_NAME':'','MYSQLI_DEBUG_TRACE_ENABLED':'','MYSQLI_SERVER_QUERY_NO_GOOD_INDEX_USED':'','MYSQLI_SERVER_QUERY_NO_INDEX_USED':'','MYSQLI_REFRESH_GRANT':'','MYSQLI_REFRESH_LOG':'','MYSQLI_REFRESH_TABLES':'','MYSQLI_REFRESH_HOSTS':'','MYSQLI_REFRESH_STATUS':'','MYSQLI_REFRESH_THREADS':'','MYSQLI_REFRESH_SLAVE':'','MYSQLI_REFRESH_MASTER':'','MYSQLI_TRANS_COR_AND_CHAIN':'','MYSQLI_TRANS_COR_AND_NO_CHAIN':'','MYSQLI_TRANS_COR_RELEASE':'','MYSQLI_TRANS_COR_NO_RELEASE':'','MYSQL_READ_DEFAULT_FILE':'','MYSQLI_SERVER_PUBLIC_KEY':'','MYSQLI_NO_CHANGE_USER_ON_PCONNECT':'','MYSQLI_ASYNC':'','MYSQLI_OPT_INT_AND_FLOAT_NATIVE':'','MYSQLI_CLIENT_FOUND_ROWS':'','MULTI_STATEMENT':'','MYSQLI_RPL_MASTER':'','MYSQLI_RPL_SLAVE':'','MYSQLI_RPL_ADMIN':'',}
let php_builtin['constants']['spl']={'READ_AHEAD':'','MIT_NEED_ALL':'','MIT_KEYS_ASSOC':'','CALL_TOSTRING':'','CATCH_GET_CHILD':'','RIT_LEAVES_ONLY':'','LOCK_SH':'','LOCK_EX':'','LOCK_UN':'','LOCK_NB':'','SEEK_SET':'','SEEK_CUR':'','SEEK_END':'','PHP_INT_MAX':'',}
let php_builtin['constants']['unknow']={'PHP_INI_ALL':'','PHP_INI_PERDIR':'','PHP_INI_SYSTEM':'','PHP_INI_USER':'','COUNTER_FLAG_PERSIST':'','COUNTER_FLAG_SAVE':'','COUNTER_FLAG_NO_OVERWRITE':'','COUNTER_META_NAME':'','COUNTER_META_IS_PERISTENT':'','COUNTER_RESET_NEVER':'','COUNTER_RESET_PER_LOAD':'','COUNTER_RESET_PER_REQUEST':'','PDO_PLACEHOLDER_NAMED':'','PDO_PLACEHOLDER_POSITIONAL':'','PDO_PLACEHOLDER_NONE':'','PDO_CASE_NATURAL':'','PDO_CASE_UPPER':'','PDO_CASE_LOWER':'','PDO_ATTR_CASE':'','PHP_COUNTER_API':'','PHPAPI':'','COMPILE_DL_COUNTER':'','ZEND_GET_MODULE':'','HAVE_COUNTER':'','COUNTER_G':'','TSRMLS_DC':'','TSRMLS_FETCH':'','STANDARD_MODULE_HEADER':'','STANDARD_MODULE_HEADER_EX':'','STANDARD_MODULE_PROPERTIES':'','STANDARD_MODULE_PROPERTIES_EX':'','ZEND_MODULE_API_NO':'','ZEND_DEBUG':'','USING_ZTS':'','NO_VERSION_YET':'','NO_MODULE_GLOBALS':'','PHP_MODULE_GLOBALS':'','IGNORE_PATH':'','USE_PATH':'','IGNORE_URL':'','IGNORE_URL_WIN':'','ENFORCE_SAFE_MODE':'','REPORT_ERRORS':'','STREAM_MUST_SEEK':'','STREAM_WILL_CAST':'',}
let php_builtin['constants']['directories']={'DIRECTORY_SEPARATOR':'','PATH_SEPARATOR':'','SCANDIR_SORT_ASCENDING':'','SCANDIR_SORT_DESCENDING':'','SCANDIR_SORT_NONE':'',}
let php_builtin['constants']['dom']={'XML_ELEMENT_NODE':'','XML_ATTRIBUTE_NODE':'','XML_TEXT_NODE':'','XML_CDATA_SECTION_NODE':'','XML_ENTITY_REF_NODE':'','XML_ENTITY_NODE':'','XML_PI_NODE':'','XML_COMMENT_NODE':'','XML_DOCUMENT_NODE':'','XML_DOCUMENT_TYPE_NODE':'','XML_DOCUMENT_FRAG_NODE':'','XML_NOTATION_NODE':'','XML_HTML_DOCUMENT_NODE':'','XML_DTD_NODE':'','XML_ELEMENT_DECL_NODE':'','XML_ATTRIBUTE_DECL_NODE':'','XML_ENTITY_DECL_NODE':'','XML_NAMESPACE_DECL_NODE':'','XML_ATTRIBUTE_CDATA':'','XML_ATTRIBUTE_ID':'','XML_ATTRIBUTE_IDREF':'','XML_ATTRIBUTE_IDREFS':'','XML_ATTRIBUTE_ENTITY':'','XML_ATTRIBUTE_NMTOKEN':'','XML_ATTRIBUTE_NMTOKENS':'','XML_ATTRIBUTE_ENUMERATION':'','XML_ATTRIBUTE_NOTATION':'','DOM_PHP_ERR':'','DOM_INDEX_SIZE_ERR':'','DOMSTRING_SIZE_ERR':'','DOM_HIERARCHY_REQUEST_ERR':'','DOM_WRONG_DOCUMENT_ERR':'','DOM_INVALID_CHARACTER_ERR':'','DOM_NO_DATA_ALLOWED_ERR':'','DOM_NO_MODIFICATION_ALLOWED_ERR':'','DOM_NOT_FOUND_ERR':'','DOM_NOT_SUPPORTED_ERR':'','DOM_INUSE_ATTRIBUTE_ERR':'','DOM_INVALID_STATE_ERR':'','DOM_SYNTAX_ERR':'','DOM_INVALID_MODIFICATION_ERR':'','DOM_NAMESPACE_ERR':'','DOM_INVALID_ACCESS_ERR':'','DOM_VALIDATION_ERR':'','DOM_NOT_FOUND_ERROR':'','DOM_NOT_FOUND':'',}
let php_builtin['constants']['command_line_usage']={'PHP_SAPI':'','STDIN':'','STDOUT':'','STDERR':'',}
let php_builtin['constants']['handling_file_uploads']={'UPLOAD_ERR_OK':'','UPLOAD_ERR_INI_SIZE':'','UPLOAD_ERR_FORM_SIZE':'','UPLOAD_ERR_PARTIAL':'','UPLOAD_ERR_NO_FILE':'','UPLOAD_ERR_NO_TMP_DIR':'','UPLOAD_ERR_CANT_WRITE':'','UPLOAD_ERR_EXTENSION':'',}
let php_builtin['constants']['fileinfo']={'FILEINFO_NONE':'','FILEINFO_SYMLINK':'','FILEINFO_MIME_TYPE':'','FILEINFO_MIME_ENCODING':'','FILEINFO_MIME':'','FILEINFO_COMPRESS':'','FILEINFO_DEVICES':'','FILEINFO_CONTINUE':'','FILEINFO_PRESERVE_ATIME':'','FILEINFO_RAW':'',}
let php_builtin['constants']['filesystem']={'SEEK_SET':'','SEEK_CUR':'','SEEK_END':'','LOCK_SH':'','LOCK_EX':'','LOCK_UN':'','LOCK_NB':'','GLOB_BRACE':'','GLOB_ONLYDIR':'','GLOB_MARK':'','GLOB_NOSORT':'','GLOB_NOCHECK':'','GLOB_NOESCAPE':'','GLOB_AVAILABLE_FLAGS':'','PATHINFO_DIRNAME':'','PATHINFO_BASENAME':'','PATHINFO_EXTENSION':'','PATHINFO_FILENAME':'','FILE_USE_INCLUDE_PATH':'','FILE_NO_DEFAULT_CONTEXT':'','FILE_APPEND':'','FILE_IGNORE_NEW_LINES':'','FILE_SKIP_EMPTY_LINES':'','FILE_BINARY':'','FILE_TEXT':'','INI_SCANNER_NORMAL':'','INI_SCANNER_RAW':'','FNM_NOESCAPE':'','FNM_PATHNAME':'','FNM_PERIOD':'','FNM_CASEFOLD':'','GLOB_ERR':'',}
let php_builtin['constants']['filter']={'FILTER_FLAG_NO_ENCODE_QUOTES':'','INPUT_POST':'','INPUT_GET':'','INPUT_COOKIE':'','INPUT_ENV':'','INPUT_SERVER':'','INPUT_SESSION':'','INPUT_REQUEST':'','FILTER_FLAG_NONE':'','FILTER_REQUIRE_SCALAR':'','FILTER_REQUIRE_ARRAY':'','FILTER_FORCE_ARRAY':'','FILTER_NULL_ON_FAILURE':'','FILTER_VALIDATE_INT':'','FILTER_VALIDATE_BOOLEAN':'','FILTER_VALIDATE_FLOAT':'','FILTER_VALIDATE_REGEXP':'','FILTER_VALIDATE_URL':'','FILTER_VALIDATE_EMAIL':'','FILTER_VALIDATE_IP':'','FILTER_DEFAULT':'','FILTER_UNSAFE_RAW':'','FILTER_SANITIZE_STRING':'','FILTER_SANITIZE_STRIPPED':'','FILTER_SANITIZE_ENCODED':'','FILTER_SANITIZE_SPECIAL_CHARS':'','FILTER_SANITIZE_EMAIL':'','FILTER_SANITIZE_URL':'','FILTER_SANITIZE_NUMBER_INT':'','FILTER_SANITIZE_NUMBER_FLOAT':'','FILTER_SANITIZE_MAGIC_QUOTES':'','FILTER_CALLBACK':'','FILTER_FLAG_ALLOW_OCTAL':'','FILTER_FLAG_ALLOW_HEX':'','FILTER_FLAG_STRIP_LOW':'','FILTER_FLAG_STRIP_HIGH':'','FILTER_FLAG_ENCODE_LOW':'','FILTER_FLAG_ENCODE_HIGH':'','FILTER_FLAG_ENCODE_AMP':'','FILTER_FLAG_EMPTY_STRING_NULL':'','FILTER_FLAG_ALLOW_FRACTION':'','FILTER_FLAG_ALLOW_THOUSAND':'','FILTER_FLAG_ALLOW_SCIENTIFIC':'','FILTER_FLAG_PATH_REQUIRED':'','FILTER_FLAG_QUERY_REQUIRED':'','FILTER_FLAG_IPV4':'','FILTER_FLAG_IPV6':'','FILTER_FLAG_NO_RES_RANGE':'','FILTER_FLAG_NO_PRIV_RANGE':'','FILTER_SANITIZE_RAW':'','FILTER_SANITIZE_FULL_SPECIAL_CHARS':'','ENT_QUOTES':'',}
let php_builtin['constants']['php_options_info']={'ASSERT_CALLBACK':'','RUSAGE_CHILDREN':'','PHP_SAPI':'','PHP_OS':'','CREDITS_DOCS':'','CREDITS_GENERAL':'','CREDITS_GROUP':'','CREDITS_MODULES':'','CREDITS_FULLPAGE':'','PHP_VERSION_ID':'','PHP_VERSION':'','PATH_SEPARATOR':'','CREDITS_SAPI':'','CREDITS_QA':'','CREDITS_ALL':'','INFO_GENERAL':'','INFO_CREDITS':'','INFO_CONFIGURATION':'','INFO_MODULES':'','INFO_ENVIRONMENT':'','INFO_VARIABLES':'','INFO_LICENSE':'','INFO_ALL':'','ASSERT_ACTIVE':'','ASSERT_BAIL':'','ASSERT_WARNING':'','ASSERT_QUIET_EVAL':'','PHP_WINDOWS_VERSION_MAJOR':'','PHP_WINDOWS_VERSION_MINOR':'','PHP_WINDOWS_VERSION_BUILD':'','PHP_WINDOWS_VERSION_PLATFORM':'','PHP_WINDOWS_VERSION_SP_MAJOR':'','PHP_WINDOWS_VERSION_SP_MINOR':'','PHP_WINDOWS_VERSION_SUITEMASK':'','PHP_WINDOWS_VERSION_PRODUCTTYPE':'','PHP_WINDOWS_NT_DOMAIN_CONTROLLER':'','PHP_WINDOWS_NT_SERVER':'','PHP_WINDOWS_NT_WORKSTATION':'',}
let php_builtin['constants']['strings']={'CRYPT_SALT_LENGTH':'','CRYPT_STD_DES':'','CRYPT_EXT_DES':'','CRYPT_MD5':'','CRYPT_BLOWFISH':'','CRYPT_SHA256':'','CRYPT_SHA512':'','HTML_ENTITIES':'','HTML_SPECIALCHARS':'','ENT_COMPAT':'','ENT_QUOTES':'','ENT_NOQUOTES':'','ENT_HTML401':'','ENT_XML1':'','ENT_XHTML':'','ENT_HTML5':'','ENT_IGNORE':'','ENT_SUBSTITUTE':'','ENT_DISALLOWED':'','CHAR_MAX':'','LC_MONETARY':'','AM_STR':'','PM_STR':'','D_T_FMT':'','D_FMT':'','T_FMT':'','T_FMT_AMPM':'','ERA':'','ERA_YEAR':'','ERA_D_T_FMT':'','ERA_D_FMT':'','ERA_T_FMT':'','INT_CURR_SYMBOL':'','CURRENCY_SYMBOL':'','CRNCYSTR':'','MON_DECIMAL_POINT':'','MON_THOUSANDS_SEP':'','MON_GROUPING':'','POSITIVE_SIGN':'','NEGATIVE_SIGN':'','INT_FRAC_DIGITS':'','FRAC_DIGITS':'','P_CS_PRECEDES':'','P_SEP_BY_SPACE':'','N_CS_PRECEDES':'','N_SEP_BY_SPACE':'','P_SIGN_POSN':'','N_SIGN_POSN':'','DECIMAL_POINT':'','RADIXCHAR':'','THOUSANDS_SEP':'','THOUSEP':'','GROUPING':'','YESEXPR':'','NOEXPR':'','YESSTR':'','NOSTR':'','CODESET':'','LC_ALL':'','LC_COLLATE':'','LC_CTYPE':'','LC_NUMERIC':'','LC_TIME':'','LC_MESSAGES':'','PHP_INT_MAX':'','STR_PAD_RIGHT':'','STR_PAD_LEFT':'','STR_PAD_BOTH':'',}
let php_builtin['constants']['error_handling']={'DEBUG_BACKTRACE_PROVIDE_OBJECT':'','DEBUG_BACKTRACE_IGNORE_ARGS':'',}
let php_builtin['constants']['math']={'PHP_INT_MAX':'','M_PI':'','PHP_ROUND_HALF_UP':'','PHP_ROUND_HALF_DOWN':'','PHP_ROUND_HALF_EVEN':'','PHP_ROUND_HALF_ODD':'','M_E':'','M_LOG2E':'','M_LOG10E':'','M_LN2':'','M_LN10':'','M_PI_2':'','M_PI_4':'','M_1_PI':'','M_2_PI':'','M_SQRTPI':'','M_2_SQRTPI':'','M_SQRT2':'','M_SQRT3':'','M_SQRT1_2':'','M_LNPI':'','M_EULER':'','NAN':'','INF':'',}
let php_builtin['constants']['network']={'LOG_EMERG':'','LOG_ALERT':'','LOG_CRIT':'','LOG_ERR':'','LOG_WARNING':'','LOG_NOTICE':'','LOG_INFO':'','LOG_DEBUG':'','LOG_KERN':'','LOG_USER':'','LOG_MAIL':'','LOG_DAEMON':'','LOG_AUTH':'','LOG_SYSLOG':'','LOG_LPR':'','LOG_NEWS':'','LOG_CRON':'','LOG_AUTHPRIV':'','LOG_LOCAL0':'','LOG_LOCAL1':'','LOG_LOCAL2':'','LOG_LOCAL3':'','LOG_LOCAL4':'','LOG_LOCAL5':'','LOG_LOCAL6':'','LOG_LOCAL7':'','LOG_PID':'','LOG_CONS':'','LOG_ODELAY':'','LOG_NDELAY':'','LOG_NOWAIT':'','LOG_PERROR':'','DNS_A':'','DNS_CNAME':'','DNS_HINFO':'','DNS_MX':'','DNS_NS':'','DNS_PTR':'','DNS_SOA':'','DNS_TXT':'','DNS_AAAA':'','DNS_SRV':'','DNS_NAPTR':'','DNS_A6':'','DNS_ALL':'','DNS_ANY':'','SID':'','LOG_UUCP':'',}
let php_builtin['constants']['urls']={'PHP_QUERY_RFC1738':'','PHP_QUERY_RFC3986':'','PHP_URL_SCHEME':'','PHP_URL_HOST':'','PHP_URL_PORT':'','PHP_URL_USER':'','PHP_URL_PASS':'','PHP_URL_PATH':'','PHP_URL_QUERY':'','PHP_URL_FRAGMENT':'',}
let php_builtin['constants']['gd']={'IMAGETYPE_GIF':'','IMAGETYPE_JPEG':'','IMAGETYPE_PNG':'','IMAGETYPE_SWF':'','IMAGETYPE_PSD':'','IMAGETYPE_BMP':'','IMAGETYPE_TIFF_II':'','IMAGETYPE_TIFF_MM':'','IMAGETYPE_JPC':'','IMAGETYPE_JP2':'','IMAGETYPE_JPX':'','IMAGETYPE_JB2':'','IMAGETYPE_SWC':'','IMAGETYPE_IFF':'','IMAGETYPE_WBMP':'','IMAGETYPE_XBM':'','IMAGETYPE_ICO':'','IMG_CROP_THRESHOLD':'','IMG_ARC_PIE':'','IMG_ARC_CHORD':'','IMG_ARC_NOFILL':'','IMG_ARC_EDGED':'','IMG_FILTER_NEGATE':'','IMG_FILTER_GRAYSCALE':'','IMG_FILTER_BRIGHTNESS':'','IMG_FILTER_CONTRAST':'','IMG_FILTER_COLORIZE':'','IMG_FILTER_EDGEDETECT':'','IMG_FILTER_EMBOSS':'','IMG_FILTER_GAUSSIAN_BLUR':'','IMG_FILTER_SELECTIVE_BLUR':'','IMG_FILTER_MEAN_REMOVAL':'','IMG_FILTER_SMOOTH':'','IMG_FILTER_PIXELATE':'','IMG_FLIP_HORIZONTAL':'','IMG_FLIP_VERTICAL':'','IMG_FLIP_BOTH':'','IMG_GD2_RAW':'','IMG_GD2_COMPRESSED':'','IMG_EFFECT_REPLACE':'','IMG_EFFECT_ALPHABLEND':'','IMG_EFFECT_NORMAL':'','IMG_EFFECT_OVERLAY':'','PNG_NO_FILTER':'','PNG_ALL_FILTERS':'','IMG_NEAREST_NEIGHBOUR':'','IMG_BILINEAR_FIXED':'','IMG_BICUBIC':'','IMG_BICUBIC_FIXED':'','IMG_COLOR_BRUSHED':'','IMG_COLOR_STYLEDBRUSHED':'','IMG_BELL':'','IMG_BESSEL':'','IMG_BLACKMAN':'','IMG_BOX':'','IMG_BSPLINE':'','IMG_CATMULLROM':'','IMG_GAUSSIAN':'','IMG_GENERALIZED_CUBIC':'','IMG_HERMITE':'','IMG_HAMMING':'','IMG_HANNING':'','IMG_MITCHELL':'','IMG_POWER':'','IMG_QUADRATIC':'','IMG_SINC':'','IMG_WEIGHTED4':'','IMG_TRIANGLE':'','IMG_COLOR_STYLED':'','IMG_COLOR_TRANSPARENT':'','IMG_COLOR_TILED':'','IMG_GIF':'','IMG_JPG':'','IMG_PNG':'','IMG_WBMP':'','IMG_XPM':'','GD_VERSION':'','GD_MAJOR_VERSION':'','GD_MINOR_VERSION':'','GD_RELEASE_VERSION':'','GD_EXTRA_VERSION':'','GD_BUNDLED':'','IMG_JPEG':'','IMG_ARC_ROUNDED':'','IMAGETYPE_JPEG2000':'','PNG_FILTER_NONE':'','PNG_FILTER_SUB':'','PNG_FILTER_UP':'','PNG_FILTER_AVG':'','PNG_FILTER_PAETH':'',}
let php_builtin['constants']['json']={'JSON_BIGINT_AS_STRING':'','JSON_HEX_QUOT':'','JSON_HEX_TAG':'','JSON_HEX_AMP':'','JSON_HEX_APOS':'','JSON_NUMERIC_CHECK':'','JSON_PRETTY_PRINT':'','JSON_UNESCAPED_SLASHES':'','JSON_FORCE_OBJECT':'','JSON_UNESCAPED_UNICODE':'','JSON_ERROR_NONE':'','JSON_ERROR_DEPTH':'','JSON_ERROR_STATE_MISMATCH':'','JSON_ERROR_CTRL_CHAR':'','JSON_ERROR_SYNTAX':'','JSON_ERROR_UTF8':'','JSON_ERROR_RECURSION':'','JSON_ERROR_INF_OR_NAN':'','NAN':'','INF':'','JSON_ERROR_UNSUPPORTED_TYPE':'','JSON_PARTIAL_OUTPUT_ON_ERROR':'',}
let php_builtin['constants']['multibyte_string']={'MB_CASE_UPPER':'','MB_CASE_LOWER':'','MB_CASE_TITLE':'','MB_OVERLOAD_MAIL':'','MB_OVERLOAD_STRING':'','MB_OVERLOAD_REGEX':'',}
let php_builtin['constants']['mssql']={'SQLTEXT':'','SQLVARCHAR':'','SQLCHAR':'','SQLINT1':'','SQLINT2':'','SQLINT4':'','SQLBIT':'','SQLFLT4':'','SQLFLT8':'','SQLFLTN':'','MSSQL_ASSOC':'','MSSQL_NUM':'','MSSQL_BOTH':'',}
let php_builtin['constants']['mysql']={'MYSQL_CLIENT_SSL':'','MYSQL_CLIENT_COMPRESS':'','MYSQL_CLIENT_IGNORE_SPACE':'','MYSQL_CLIENT_INTERACTIVE':'','MYSQL_ASSOC':'','MYSQL_NUM':'','MYSQL_BOTH':'','MYSQL_PORT':'',}
let php_builtin['constants']['output_control']={'PHP_OUTPUT_HANDLER_STDFLAGS':'','PHP_OUTPUT_HANDLER_CLEANABLE':'','PHP_OUTPUT_HANDLER_FLUSHABLE':'','PHP_OUTPUT_HANDLER_REMOVABLE':'','PHP_OUTPUT_HANDLER_START':'','PHP_OUTPUT_HANDLER_WRITE':'','PHP_OUTPUT_HANDLER_FLUSH':'','PHP_OUTPUT_HANDLER_CLEAN':'','PHP_OUTPUT_HANDLER_FINAL':'','PHP_OUTPUT_HANDLER_CONT':'','PHP_OUTPUT_HANDLER_END':'',}
let php_builtin['constants']['password_hashing']={'PASSWORD_DEFAULT':'','PASSWORD_BCRYPT':'','CRYPT_BLOWFISH':'',}
let php_builtin['constants']['postgresql']={'PGSQL_CONNECT_FORCE_NEW':'','PGSQL_CONNECTION_OK':'','PGSQL_CONNECTION_BAD':'','PGSQL_CONV_IGNORE_DEFAULT':'','PGSQL_CONV_FORCE_NULL':'','PGSQL_CONV_IGNORE_NOT_NULL':'','PGSQL_DML_NO_CONV':'','PGSQL_DML_ESCAPE':'','PGSQL_DML_EXEC':'','PGSQL_DML_ASYNC':'','PGSQL_DML_STRING':'','PGSQL_ASSOC':'','PGSQL_NUM':'','PGSQL_BOTH':'','PGSQL_CONV_OPTS':'','INV_READ':'','INV_WRITE':'','INV_ARCHIVE':'','PGSQL_SEEK_SET':'','PGSQL_SEEK_CUR':'','PGSQL_SEEK_END':'','PGSQL_DIAG_SEVERITY':'','PGSQL_DIAG_SQLSTATE':'','PGSQL_DIAG_MESSAGE_PRIMARY':'','PGSQL_DIAG_MESSAGE_DETAIL':'','PGSQL_DIAG_MESSAGE_HINT':'','PGSQL_DIAG_STATEMENT_POSITION':'','PGSQL_DIAG_INTERNAL_POSITION':'','PGSQL_DIAG_INTERNAL_QUERY':'','PGSQL_DIAG_CONTEXT':'','PGSQL_DIAG_SOURCE_FILE':'','PGSQL_DIAG_SOURCE_LINE':'','PGSQL_DIAG_SOURCE_FUNCTION':'','PGSQL_STATUS_LONG':'','PGSQL_STATUS_STRING':'','PGSQL_EMPTY_QUERY':'','PGSQL_COMMAND_OK':'','PGSQL_TUPLES_OK':'','PGSQL_COPY_OUT':'','PGSQL_COPY_IN':'','PGSQL_BAD_RESPONSE':'','PGSQL_NONFATAL_ERROR':'','PGSQL_FATAL_ERROR':'','PGSQL_ERRORS_TERSE':'','PGSQL_ERRORS_DEFAULT':'','PGSQL_ERRORS_VERBOSE':'','PGSQL_TRANSACTION_IDLE':'','PGSQL_TRANSACTION_ACTIVE':'','PGSQL_TRANSACTION_INTRANS':'','PGSQL_TRANSACTION_INERROR':'','PGSQL_TRANSACTION_UNKNOWN':'','PG_DIAG_STATEMENT_POSITION':'','PG_DIAG_INTERNAL_QUERY':'',}
let php_builtin['constants']['pcre']={'PREG_GREP_INVERT':'','PREG_NO_ERROR':'','PREG_INTERNAL_ERROR':'','PREG_BACKTRACK_LIMIT_ERROR':'','PREG_RECURSION_LIMIT_ERROR':'','PREG_BAD_UTF8_ERROR':'','PREG_BAD_UTF8_OFFSET_ERROR':'','PREG_PATTERN_ORDER':'','PREG_SET_ORDER':'','PREG_OFFSET_CAPTURE':'','PREG_SPLIT_NO_EMPTY':'','PREG_SPLIT_DELIM_CAPTURE':'','PREG_SPLIT_OFFSET_CAPTURE':'','PCRE_VERSION':'',}
let php_builtin['constants']['program_execution']={'STDIN':'',}
let php_builtin['constants']['sessions']={'SID':'','PHP_SESSION_DISABLED':'','PHP_SESSION_NONE':'','PHP_SESSION_ACTIVE':'','UPLOAD_ERR_EXTENSION':'',}
let php_builtin['constants']['variable_handling']={'PHP_INT_MAX':'',}
let php_builtin['constants']['misc']={'WAIT_IO_COMPLETION':'','CONNECTION_ABORTED':'','CONNECTION_NORMAL':'','CONNECTION_TIMEOUT':'',}
let php_builtin['constants']['streams']={'STREAM_FILTER_READ':'','STREAM_FILTER_WRITE':'','STREAM_FILTER_ALL':'','PHP_INT_MAX':'','STREAM_CLIENT_CONNECT':'','STREAM_CLIENT_ASYNC_CONNECT':'','STREAM_CLIENT_PERSISTENT':'','STREAM_CRYPTO_METHOD_TLS_CLIENT':'','STREAM_CRYPTO_METHOD_TLS_SERVER':'','STREAM_PF_INET':'','STREAM_PF_INET6':'','STREAM_PF_UNIX':'','STREAM_SOCK_DGRAM':'','STREAM_SOCK_RAW':'','STREAM_SOCK_RDM':'','STREAM_SOCK_SEQPACKET':'','STREAM_SOCK_STREAM':'','STREAM_IPPROTO_ICMP':'','STREAM_IPPROTO_IP':'','STREAM_IPPROTO_RAW':'','STREAM_IPPROTO_TCP':'','STREAM_IPPROTO_UDP':'','STREAM_OOB':'','STREAM_PEEK':'','AF_INET':'','STREAM_SERVER_BIND':'','STREAM_SHUT_RD':'','STREAM_SHUT_WR':'','STREAM_SHUT_RDWR':'','STREAM_IS_URL':'','PSFS_PASS_ON':'','PSFS_FEED_ME':'','PSFS_ERR_FATAL':'','PSFS_FLAG_NORMAL':'','PSFS_FLAG_FLUSH_INC':'','PSFS_FLAG_FLUSH_CLOSE':'','STREAM_USE_PATH':'','STREAM_REPORT_ERRORS':'','STREAM_SERVER_LISTEN':'','STREAM_NOTIFY_RESOLVE':'','STREAM_NOTIFY_CONNECT':'','STREAM_NOTIFY_AUTH_REQUIRED':'','STREAM_NOTIFY_SEVERITY_ERR':'','STREAM_NOTIFY_MIME_TYPE_IS':'','STREAM_NOTIFY_FILE_SIZE_IS':'','STREAM_NOTIFY_REDIRECTED':'','STREAM_NOTIFY_PROGRESS':'','STREAM_NOTIFY_COMPLETED':'','STREAM_NOTIFY_FAILURE':'','STREAM_NOTIFY_AUTH_RESULT':'','STREAM_NOTIFY_SEVERITY_INFO':'','STREAM_NOTIFY_SEVERITY_WARN':'','STREAM_CAST_FOR_SELECT':'','STREAM_CAST_AS_STREAM':'','STREAM_META_TOUCH':'','STREAM_META_OWNER':'','STREAM_META_OWNER_NAME':'','STREAM_META_GROUP':'','STREAM_META_GROUP_NAME':'','STREAM_META_ACCESS':'','STREAM_MKDIR_RECURSIVE':'','LOCK_EX':'','LOCK_UN':'','LOCK_SH':'','LOCK_NB':'','SEEK_SET':'','SEEK_CUR':'','SEEK_END':'','STREAM_OPTION_BLOCKING':'','STREAM_OPTION_READ_TIMEOUT':'','STREAM_OPTION_WRITE_BUFFER':'','STREAM_BUFFER_NONE':'','STREAM_BUFFER_FULL':'',}
let php_builtin['constants']['iconv']={'ICONV_IMPL':'','ICONV_VERSION':'','ICONV_MIME_DECODE_STRICT':'','ICONV_MIME_DECODE_CONTINUE_ON_ERROR':'',}
let php_builtin['constants']['phpini_directives']={'PATH_SEPARATOR':'','PHP_INI_SYSTEM':'',}
let php_builtin['constants']['types']={'NAN':'','PHP_INT_SIZE':'','PHP_INT_MAX':'',}
let php_builtin['constants']['pdo']={'PDO_PARAM_BOOL':'',}
let php_builtin['constants']['list_of_reserved_words']={'PHP_VERSION':'','PHP_MAJOR_VERSION':'','PHP_MINOR_VERSION':'','PHP_RELEASE_VERSION':'','PHP_VERSION_ID':'','PHP_EXTRA_VERSION':'','PHP_ZTS':'','PHP_DEBUG':'','PHP_MAXPATHLEN':'','PHP_OS':'','PHP_SAPI':'','PHP_EOL':'','PHP_INT_MAX':'','PHP_INT_SIZE':'','DEFAULT_INCLUDE_PATH':'','PEAR_INSTALL_DIR':'','PEAR_EXTENSION_DIR':'','PHP_EXTENSION_DIR':'','PHP_PREFIX':'','PHP_BINDIR':'','PHP_BINARY':'','PHP_MANDIR':'','PHP_LIBDIR':'','PHP_DATADIR':'','PHP_SYSCONFDIR':'','PHP_LOCALSTATEDIR':'','PHP_CONFIG_FILE_PATH':'','PHP_CONFIG_FILE_SCAN_DIR':'','PHP_SHLIB_SUFFIX':'',}
let php_builtin['constants']['php_type_comparison_tables']={'NAN':'',}

" Built in functions
let g:php_builtin_functions = {}
for [ext, data] in items(php_builtin['functions'])
	call extend(g:php_builtin_functions, data)
endfor

" Built in class
let g:php_builtin_classes = {}
for [ext, data] in items(php_builtin['classes'])
	call extend(g:php_builtin_classes, data)
endfor

" Built in interfaces
let g:php_builtin_interfaces = {}
for [ext, data] in items(php_builtin['interfaces'])
	call extend(g:php_builtin_interfaces, data)
endfor

" Built in constants
let g:php_constants = {}
for [ext, data] in items(php_builtin['constants'])
	call extend(g:php_constants, data)
endfor

" When the classname not found or found but the tags doesn't contain that
" class we will try to complete any method of any builtin class. To speed up
" that lookup we compile a 'ClassName::MethodName':'info' dictionary from the
" builtin class information
let g:php_builtin_object_functions = {}

" When completing for 'everything imaginable' (no class context, not a
" variable) we need a list of built-in classes in a format of {'classname':''}
" for performance reasons we precompile this too
let g:php_builtin_classnames = {}

" In order to reduce file size, empty keys are omitted from class structures.
" To make the structure of in-memory hashes normalized we will add them in runtime
let required_class_hash_keys = ['constants', 'properties', 'static_properties', 'methods', 'static_methods']

for [classname, class_info] in items(g:php_builtin_classes)
	for property_name in required_class_hash_keys
		if !has_key(class_info, property_name)
			let class_info[property_name] = {}
		endif
	endfor

	let g:php_builtin_classnames[classname] = ''
	for [method_name, method_info] in items(class_info.methods)
		let g:php_builtin_object_functions[classname.'::'.method_name.'('] = method_info.signature
	endfor
	for [method_name, method_info] in items(class_info.static_methods)
		let g:php_builtin_object_functions[classname.'::'.method_name.'('] = method_info.signature
	endfor
endfor

let g:php_builtin_interfacenames = {}
for [interfacename, info] in items(g:php_builtin_interfaces)
	for property_name in required_class_hash_keys
		if !has_key(class_info, property_name)
			let class_info[property_name] = {}
		endif
	endfor

	let g:php_builtin_interfacenames[interfacename] = ''
	for [method_name, method_info] in items(class_info.methods)
		let g:php_builtin_object_functions[interfacename.'::'.method_name.'('] = method_info.signature
	endfor
	for [method_name, method_info] in items(class_info.static_methods)
		let g:php_builtin_object_functions[interfacename.'::'.method_name.'('] = method_info.signature
	endfor
endfor


" Add control structures (they are outside regular pattern of PHP functions)
let php_control = {
			\ 'include(': 'string filename | resource',
			\ 'include_once(': 'string filename | resource',
			\ 'require(': 'string filename | resource',
			\ 'require_once(': 'string filename | resource',
			\ }
call extend(g:php_builtin_functions, php_control)


" Built-in variables " {{{
let g:php_builtin_vars ={
			\ '$GLOBALS':'',
			\ '$_SERVER':'',
			\ '$_GET':'',
			\ '$_POST':'',
			\ '$_COOKIE':'',
			\ '$_FILES':'',
			\ '$_ENV':'',
			\ '$_REQUEST':'',
			\ '$_SESSION':'',
			\ '$HTTP_SERVER_VARS':'',
			\ '$HTTP_ENV_VARS':'',
			\ '$HTTP_COOKIE_VARS':'',
			\ '$HTTP_GET_VARS':'',
			\ '$HTTP_POST_VARS':'',
			\ '$HTTP_POST_FILES':'',
			\ '$HTTP_SESSION_VARS':'',
			\ '$php_errormsg':'',
			\ '$this':'',
			\ }
" }}}
endfunction
" }}}

" vim: foldmethod=marker:noexpandtab:ts=8:sts=4
