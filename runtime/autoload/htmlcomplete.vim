" Vim completion script
" Language:	HTML and XHTML
" Maintainer:	Mikolaj Machowski ( mikmach AT wp DOT pl )
" Last Change:	2019 Sep 27

" Distinguish between HTML versions.
" To use with other HTML versions add another "elseif" condition to match
" proper DOCTYPE.
function! htmlcomplete#DetectOmniFlavor()
  if &filetype == 'xhtml'
    let b:html_omni_flavor = 'xhtml10s'
  else
    let b:html_omni_flavor = 'html401t'
  endif
  let i = 1
  let line = ""
  while i < 10 && i < line("$")
    let line = getline(i)
    if line =~ '<!DOCTYPE.*\<DTD '
      break
    endif
    let i += 1
  endwhile
  if line =~ '<!DOCTYPE.*\<DTD '  " doctype line found above
    if line =~ ' HTML 3\.2'
      let b:html_omni_flavor = 'html32'
    elseif line =~ ' XHTML 1\.1'
      let b:html_omni_flavor = 'xhtml11'
    else    " two-step detection with strict/frameset/transitional
      if line =~ ' XHTML 1\.0'
	let b:html_omni_flavor = 'xhtml10'
      elseif line =~ ' HTML 4\.01'
	let b:html_omni_flavor = 'html401'
      elseif line =~ ' HTML 4.0\>'
	let b:html_omni_flavor = 'html40'
      endif
      if line =~ '\<Transitional\>'
	let b:html_omni_flavor .= 't'
      elseif line =~ '\<Frameset\>'
	let b:html_omni_flavor .= 'f'
      else
	let b:html_omni_flavor .= 's'
      endif
    endif
  endif
endfunction

function! htmlcomplete#CompleteTags(findstart, base)
  if a:findstart
    " locate the start of the word
    let line = getline('.')
    let start = col('.') - 1
	let curline = line('.')
	let compl_begin = col('.') - 2
    while start >= 0 && line[start - 1] =~ '\(\k\|[!:.-]\)'
		let start -= 1
    endwhile
	" Handling of entities {{{
	if start >= 0 && line[start - 1] =~ '&'
		let b:entitiescompl = 1
		let b:compl_context = ''
		return start
	endif
	" }}}
	" Handling of <style> tag {{{
	let stylestart = searchpair('<style\>', '', '<\/style\>', "bnW")
	let styleend   = searchpair('<style\>', '', '<\/style\>', "nW")
	if stylestart != 0 && styleend != 0
		if stylestart <= curline && styleend >= curline
			let start = col('.') - 1
			let b:csscompl = 1
			while start >= 0 && line[start - 1] =~ '\(\k\|-\)'
				let start -= 1
			endwhile
		endif
	endif
	" }}}
	" Handling of <script> tag {{{
	let scriptstart = searchpair('<script\>', '', '<\/script\>', "bnW")
	let scriptend   = searchpair('<script\>', '', '<\/script\>', "nW")
	if scriptstart != 0 && scriptend != 0
		if scriptstart <= curline && scriptend >= curline
			let start = col('.') - 1
			let b:jscompl = 1
			let b:jsrange = [scriptstart, scriptend]
			while start >= 0 && line[start - 1] =~ '\k'
				let start -= 1
			endwhile
			" We are inside of <script> tag. But we should also get contents
			" of all linked external files and (secondary, less probably) other <script> tags
			" This logic could possible be done in separate function - may be
			" reused in events scripting (also with option could be reused for
			" CSS
			let b:js_extfiles = []
			let l = line('.')
			let c = col('.')
			call cursor(1,1)
			while search('<\@<=script\>', 'W') && line('.') <= l
				if synIDattr(synID(line('.'),col('.')-1,0),"name") !~? 'comment'
					let sname = matchstr(getline('.'), '<script[^>]*src\s*=\s*\([''"]\)\zs.\{-}\ze\1')
					if filereadable(sname)
						let b:js_extfiles += readfile(sname)
					endif
				endif
			endwhile
			call cursor(1,1)
			let js_scripttags = []
			while search('<script\>', 'W') && line('.') < l
				if matchstr(getline('.'), '<script[^>]*src') == ''
					let js_scripttag = getline(line('.'), search('</script>', 'W'))
					let js_scripttags += js_scripttag
				endif
			endwhile
			let b:js_extfiles += js_scripttags
			call cursor(l,c)
			unlet! l c
		endif
	endif
	" }}}
	if !exists("b:csscompl") && !exists("b:jscompl")
		let b:compl_context = getline('.')[0:(compl_begin)]
		if b:compl_context !~ '<[^>]*$'
			" Look like we may have broken tag. Check previous lines.
			let i = 1
			while 1
				let context_line = getline(curline-i)
				if context_line =~ '<[^>]*$'
					" Yep, this is this line
					let context_lines = getline(curline-i, curline-1) + [b:compl_context]
					let b:compl_context = join(context_lines, ' ')
					break
				elseif context_line =~ '>[^<]*$' || i == curline
					" We are in normal tag line, no need for completion at all
					" OR reached first line without tag at all
					let b:compl_context = ''
					break
				endif
				let i += 1
			endwhile
			" Make sure we don't have counter
			unlet! i
		endif
		let b:compl_context = matchstr(b:compl_context, '.*\zs<.*')

		" Return proper start for on-events. Without that beginning of
		" completion will be badly reported
		if b:compl_context =~? 'on[a-z]*\s*=\s*\(''[^'']*\|"[^"]*\)$'
			let start = col('.') - 1
			while start >= 0 && line[start - 1] =~ '\k'
				let start -= 1
			endwhile
		endif
		" If b:compl_context begins with <? we are inside of PHP code. It
		" wasn't closed so PHP completion passed it to HTML
		if &filetype =~? 'php' && b:compl_context =~ '^<?'
			let b:phpcompl = 1
			let start = col('.') - 1
			while start >= 0 && line[start - 1] =~ '[a-zA-Z_0-9\x7f-\xff$]'
				let start -= 1
			endwhile
		endif
	else
		let b:compl_context = getline('.')[0:compl_begin]
	endif
    return start
  else
	" Initialize base return lists
    let res = []
    let res2 = []
	" a:base is very short - we need context
	let context = b:compl_context
	" Check if we should do CSS completion inside of <style> tag
	" or JS completion inside of <script> tag or PHP completion in case of <?
	" tag AND &ft==php
	if exists("b:csscompl")
		unlet! b:csscompl
		let context = b:compl_context
		unlet! b:compl_context
		return csscomplete#CompleteCSS(0, context)
	elseif exists("b:jscompl")
		unlet! b:jscompl
		return javascriptcomplete#CompleteJS(0, a:base)
	elseif exists("b:phpcompl")
		unlet! b:phpcompl
		let context = b:compl_context
		return phpcomplete#CompletePHP(0, a:base)
	else
		if len(b:compl_context) == 0 && !exists("b:entitiescompl")
			return []
		endif
		let context = matchstr(b:compl_context, '.\zs.*')
	endif
	unlet! b:compl_context
	" Entities completion {{{
	if exists("b:entitiescompl")
		unlet! b:entitiescompl

		if !exists("b:html_doctype")
			call htmlcomplete#CheckDoctype()
		endif
		if !exists("b:html_omni")
			"runtime! autoload/xml/xhtml10s.vim
			call htmlcomplete#LoadData()
		endif

	    let entities =  b:html_omni['vimxmlentities']

		if len(a:base) == 1
			for m in entities
				if m =~ '^'.a:base
					call add(res, m.';')
				endif
			endfor
			return res
		else
			for m in entities
				if m =~? '^'.a:base
					call add(res, m.';')
				elseif m =~? a:base
					call add(res2, m.';')
				endif
			endfor

			return res + res2
		endif


	endif
	" }}}
	if context =~ '>'
		" Generally if context contains > it means we are outside of tag and
		" should abandon action - with one exception: <style> span { bo
		if context =~ 'style[^>]\{-}>[^<]\{-}$'
			return csscomplete#CompleteCSS(0, context)
		elseif context =~ 'script[^>]\{-}>[^<]\{-}$'
			let b:jsrange = [line('.'), search('<\/script\>', 'nW')]
			return javascriptcomplete#CompleteJS(0, context)
		else
			return []
		endif
	endif

	" If context contains > it means we are already outside of tag and we
	" should abandon action
	" If context contains white space it is attribute.
	" It can be also value of attribute.
	" We have to get first word to offer proper completions
	if context =~ '^\s*$'
		" empty or whitespace line
		let tag = ''
	else
		let tag = split(context)[0]
		" Detect if tag is uppercase to return in proper case,
		" we need to make it lowercase for processing
		if tag =~ '^[A-Z]*$'
			let uppercase_tag = 1
			let tag = tolower(tag)
		else
			let uppercase_tag = 0
		endif
	endif
	" Get last word, it should be attr name
	let attr = matchstr(context, '.*\s\zs.*')
	" Possible situations where any prediction would be difficult:
	" 1. Events attributes
	if context =~ '\s'
		" Sort out style, class, and on* cases
		if context =~? "\\(on[a-z]*\\|id\\|style\\|class\\)\\s*=\\s*[\"']"
			" Id, class completion {{{
			if context =~? "\\(id\\|class\\)\\s*=\\s*[\"'][a-zA-Z0-9_ -]*$"
				if context =~? "class\\s*=\\s*[\"'][a-zA-Z0-9_ -]*$"
					let search_for = "class"
				elseif context =~? "id\\s*=\\s*[\"'][a-zA-Z0-9_ -]*$"
					let search_for = "id"
				endif
				" Handle class name completion
				" 1. Find lines of <link stylesheet>
				" 1a. Check file for @import
				" 2. Extract filename(s?) of stylesheet,
				call cursor(1,1)
				let head = getline(search('<head\>'), search('<\/head>'))
				let headjoined = join(copy(head), ' ')
				if headjoined =~ '<style'
					" Remove possibly confusing CSS operators
					let stylehead = substitute(headjoined, '+>\*[,', ' ', 'g')
					if search_for == 'class'
						let styleheadlines = split(stylehead)
						let headclasslines = filter(copy(styleheadlines), "v:val =~ '\\([a-zA-Z0-9:]\\+\\)\\?\\.[a-zA-Z0-9_-]\\+'")
					else
						let stylesheet = split(headjoined, '[{}]')
						" Get all lines which fit id syntax
						let classlines = filter(copy(stylesheet), "v:val =~ '#[a-zA-Z0-9_-]\\+'")
						" Filter out possible color definitions
						call filter(classlines, "v:val !~ ':\\s*#[a-zA-Z0-9_-]\\+'")
						" Filter out complex border definitions
						call filter(classlines, "v:val !~ '\\(none\\|hidden\\|dotted\\|dashed\\|solid\\|double\\|groove\\|ridge\\|inset\\|outset\\)\\s*#[a-zA-Z0-9_-]\\+'")
						let templines = join(classlines, ' ')
						let headclasslines = split(templines)
						call filter(headclasslines, "v:val =~ '#[a-zA-Z0-9_-]\\+'")
					endif
					let internal = 1
				else
					let internal = 0
				endif
				let styletable = []
				let secimportfiles = []
				let filestable = filter(copy(head), "v:val =~ '\\(@import\\|link.*stylesheet\\)'")
				for line in filestable
					if line =~ "@import"
						let styletable += [matchstr(line, "import\\s\\+\\(url(\\)\\?[\"']\\?\\zs\\f\\+\\ze")]
					elseif line =~ "<link"
						let styletable += [matchstr(line, "href\\s*=\\s*[\"']\\zs\\f\\+\\ze")]
					endif
				endfor
				for file in styletable
					if filereadable(file)
						let stylesheet = readfile(file)
						let secimport = filter(copy(stylesheet), "v:val =~ '@import'")
						if len(secimport) > 0
							for line in secimport
								let secfile = matchstr(line, "import\\s\\+\\(url(\\)\\?[\"']\\?\\zs\\f\\+\\ze")
								let secfile = fnamemodify(file, ":p:h").'/'.secfile
								let secimportfiles += [secfile]
							endfor
						endif
					endif
				endfor
				let cssfiles = styletable + secimportfiles
				let classes = []
				for file in cssfiles
				  	let classlines = []
					if filereadable(file)
						let stylesheet = readfile(file)
						let stylefile = join(stylesheet, ' ')
						let stylefile = substitute(stylefile, '+>\*[,', ' ', 'g')
						if search_for == 'class'
							let stylesheet = split(stylefile)
							let classlines = filter(copy(stylesheet), "v:val =~ '\\([a-zA-Z0-9:]\\+\\)\\?\\.[a-zA-Z0-9_-]\\+'")
						else
							let stylesheet = split(stylefile, '[{}]')
							" Get all lines which fit id syntax
							let classlines = filter(copy(stylesheet), "v:val =~ '#[a-zA-Z0-9_-]\\+'")
							" Filter out possible color definitions
							call filter(classlines, "v:val !~ ':\\s*#[a-zA-Z0-9_-]\\+'")
							" Filter out complex border definitions
							call filter(classlines, "v:val !~ '\\(none\\|hidden\\|dotted\\|dashed\\|solid\\|double\\|groove\\|ridge\\|inset\\|outset\\)\\s*#[a-zA-Z0-9_-]\\+'")
							let templines = join(classlines, ' ')
							let stylelines = split(templines)
							let classlines = filter(stylelines, "v:val =~ '#[a-zA-Z0-9_-]\\+'")

						endif
					endif
					" We gathered classes definitions from all external files
					let classes += classlines
				endfor
				if internal == 1
					let classes += headclasslines
				endif

				if search_for == 'class'
					let elements = {}
					for element in classes
						if element =~ '^\.'
							let class = matchstr(element, '^\.\zs[a-zA-Z][a-zA-Z0-9_-]*\ze')
							let class = substitute(class, ':.*', '', '')
							if has_key(elements, 'common')
								let elements['common'] .= ' '.class
							else
								let elements['common'] = class
							endif
						else
							let class = matchstr(element, '[a-zA-Z1-6]*\.\zs[a-zA-Z][a-zA-Z0-9_-]*\ze')
							let tagname = tolower(matchstr(element, '[a-zA-Z1-6]*\ze.'))
							if tagname != ''
								if has_key(elements, tagname)
									let elements[tagname] .= ' '.class
								else
									let elements[tagname] = class
								endif
							endif
						endif
					endfor

					if has_key(elements, tag) && has_key(elements, 'common')
						let values = split(elements[tag]." ".elements['common'])
					elseif has_key(elements, tag) && !has_key(elements, 'common')
						let values = split(elements[tag])
					elseif !has_key(elements, tag) && has_key(elements, 'common')
						let values = split(elements['common'])
					else
						return []
					endif

				elseif search_for == 'id'
					" Find used IDs
					" 1. Catch whole file
					let filelines = getline(1, line('$'))
					" 2. Find lines with possible id
					let used_id_lines = filter(filelines, 'v:val =~ "id\\s*=\\s*[\"''][a-zA-Z0-9_-]\\+"')
					" 3a. Join all filtered lines
					let id_string = join(used_id_lines, ' ')
					" 3b. And split them to be sure each id is in separate item
					let id_list = split(id_string, 'id\s*=\s*')
					" 4. Extract id values
					let used_id = map(id_list, 'matchstr(v:val, "[\"'']\\zs[a-zA-Z0-9_-]\\+\\ze")')
					let joined_used_id = ','.join(used_id, ',').','

					let allvalues = map(classes, 'matchstr(v:val, ".*#\\zs[a-zA-Z0-9_-]\\+")')

					let values = []

					for element in classes
						if joined_used_id !~ ','.element.','
							let values += [element]
						endif

					endfor

				endif

				" We need special version of sbase
				let classbase = matchstr(context, ".*[\"']")
				let classquote = matchstr(classbase, '.$')

				let entered_class = matchstr(attr, ".*=\\s*[\"']\\zs.*")

				for m in sort(values)
					if m =~? '^'.entered_class
						call add(res, m . classquote)
					elseif m =~? entered_class
						call add(res2, m . classquote)
					endif
				endfor

				return res + res2

			elseif context =~? "style\\s*=\\s*[\"'][^\"']*$"
				return csscomplete#CompleteCSS(0, context)

			endif
			" }}}
			" Complete on-events {{{
			if context =~? 'on[a-z]*\s*=\s*\(''[^'']*\|"[^"]*\)$'
				" We have to:
				" 1. Find external files
				let b:js_extfiles = []
				let l = line('.')
				let c = col('.')
				call cursor(1,1)
				while search('<\@<=script\>', 'W') && line('.') <= l
					if synIDattr(synID(line('.'),col('.')-1,0),"name") !~? 'comment'
						let sname = matchstr(getline('.'), '<script[^>]*src\s*=\s*\([''"]\)\zs.\{-}\ze\1')
						if filereadable(sname)
							let b:js_extfiles += readfile(sname)
						endif
					endif
				endwhile
				" 2. Find at least one <script> tag
				call cursor(1,1)
				let js_scripttags = []
				while search('<script\>', 'W') && line('.') < l
					if matchstr(getline('.'), '<script[^>]*src') == ''
						let js_scripttag = getline(line('.'), search('</script>', 'W'))
						let js_scripttags += js_scripttag
					endif
				endwhile
				let b:js_extfiles += js_scripttags

				" 3. Proper call for javascriptcomplete#CompleteJS
				call cursor(l,c)
				let js_context = matchstr(a:base, '\k\+$')
				let js_shortcontext = substitute(a:base, js_context.'$', '', '')
				let b:compl_context = context
				let b:jsrange = [l, l]
				unlet! l c
				return javascriptcomplete#CompleteJS(0, js_context)

			endif

			" }}}
			let stripbase = matchstr(context, ".*\\(on[a-zA-Z]*\\|style\\|class\\)\\s*=\\s*[\"']\\zs.*")
			" Now we have context stripped from all chars up to style/class.
			" It may fail with some strange style value combinations.
			if stripbase !~ "[\"']"
				return []
			endif
		endif
		" Value of attribute completion {{{
		" If attr contains =\s*[\"'] we catched value of attribute
		if attr =~ "=\s*[\"']" || attr =~ "=\s*$"
			" Let do attribute specific completion
			let attrname = matchstr(attr, '.*\ze\s*=')
			let entered_value = matchstr(attr, ".*=\\s*[\"']\\?\\zs.*")
			let values = []
			" Load data {{{
			if !exists("b:html_doctype")
				call htmlcomplete#CheckDoctype()
			endif
			if !exists("b:html_omni")
				"runtime! autoload/xml/xhtml10s.vim
				call htmlcomplete#LoadData()
			endif
			" }}}
			if attrname == 'href'
				" Now we are looking for local anchors defined by name or id
				if entered_value =~ '^#'
					let file = join(getline(1, line('$')), ' ')
					" Split it be sure there will be one id/name element in
					" item, it will be also first word [a-zA-Z0-9_-] in element
					let oneelement = split(file, "\\(meta \\)\\@<!\\(name\\|id\\)\\s*=\\s*[\"']")
					for i in oneelement
						let values += ['#'.matchstr(i, "^[a-zA-Z][a-zA-Z0-9%_-]*")]
					endfor
				endif
			else
				if has_key(b:html_omni, tag) && has_key(b:html_omni[tag][1], attrname)
					let values = b:html_omni[tag][1][attrname]
				else
					return []
				endif
			endif

			if len(values) == 0
				return []
			endif

			" We need special version of sbase
			let attrbase = matchstr(context, ".*[\"']")
			let attrquote = matchstr(attrbase, '.$')
			if attrquote !~ "['\"]"
				let attrquoteopen = '"'
				let attrquote = '"'
			else
				let attrquoteopen = ''
			endif

			for m in values
				" This if is needed to not offer all completions as-is
				" alphabetically but sort them. Those beginning with entered
				" part will be as first choices
				if m =~ '^'.entered_value
					call add(res, attrquoteopen . m . attrquote)
				elseif m =~ entered_value
					call add(res2, attrquoteopen . m . attrquote)
				endif
			endfor

			return res + res2

		endif
		" }}}
		" Attribute completion {{{
		" Shorten context to not include last word
		let sbase = matchstr(context, '.*\ze\s.*')

		" Load data {{{
		if !exists("b:html_doctype")
			call htmlcomplete#CheckDoctype()
		endif
		if !exists("b:html_omni")
			call htmlcomplete#LoadData()
		endif
		" }}}

		if has_key(b:html_omni, tag)
			let attrs = keys(b:html_omni[tag][1])
		else
			return []
		endif

		for m in sort(attrs)
			if m =~ '^'.attr
				call add(res, m)
			elseif m =~ attr
				call add(res2, m)
			endif
		endfor
		let menu = res + res2
		if has_key(b:html_omni, 'vimxmlattrinfo')
			let final_menu = []
			for i in range(len(menu))
				let item = menu[i]
				if has_key(b:html_omni['vimxmlattrinfo'], item)
					let m_menu = b:html_omni['vimxmlattrinfo'][item][0]
					let m_info = b:html_omni['vimxmlattrinfo'][item][1]
				else
					let m_menu = ''
					let m_info = ''
				endif
				if len(b:html_omni[tag][1][item]) > 0 && b:html_omni[tag][1][item][0] =~ '^\(BOOL\|'.item.'\)$'
					let item = item
					let m_menu = 'Bool'
				else
					let item .= '="'
				endif
				let final_menu += [{'word':item, 'menu':m_menu, 'info':m_info}]
			endfor
		else
			let final_menu = []
			for i in range(len(menu))
				let item = menu[i]
				if len(b:html_omni[tag][1][item]) > 0 && b:html_omni[tag][1][item][0] =~ '^\(BOOL\|'.item.'\)$'
					let item = item
				else
					let item .= '="'
				endif
				let final_menu += [item]
			endfor
			return final_menu

		endif
		return final_menu

	endif
	" }}}
	" Close tag {{{
	let b:unaryTagsStack = "base meta link hr br param img area input col"
	if context =~ '^\/'
		if context =~ '^\/.'
			return []
		else
			let opentag = xmlcomplete#GetLastOpenTag("b:unaryTagsStack")
			return [opentag.">"]
		endif
	endif
	" }}}
	" Load data {{{
	if !exists("b:html_doctype")
		call htmlcomplete#CheckDoctype()
	endif
	if !exists("b:html_omni")
		"runtime! autoload/xml/xhtml10s.vim
		call htmlcomplete#LoadData()
	endif
	" }}}
	" Tag completion {{{
	" Deal with tag completion.
	let opentag = tolower(xmlcomplete#GetLastOpenTag("b:unaryTagsStack"))
	" MM: TODO: GLOT works always the same but with some weird situation it
	" behaves as intended in HTML but screws in PHP
	if opentag == '' || &filetype == 'php' && !has_key(b:html_omni, opentag)
		" Hack for sometimes failing GetLastOpenTag.
		" As far as I tested fail isn't GLOT fault but problem
		" of invalid document - not properly closed tags and other mish-mash.
		" Also when document is empty. Return list of *all* tags.
	    let tags = keys(b:html_omni)
		call filter(tags, 'v:val !~ "^vimxml"')
	else
		if has_key(b:html_omni, opentag)
			let tags = b:html_omni[opentag][0]
		else
			return []
		endif
	endif
	" }}}

	if exists("uppercase_tag") && uppercase_tag == 1
		let context = tolower(context)
	endif
	" Handle XML keywords: DOCTYPE
	if opentag == ''
		let tags += [
				\ '!DOCTYPE html PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">',
				\ '!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0//EN" "http://www.w3.org/TR/REC-html40/strict.dtd">',
				\ '!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">',
				\ '!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Frameset//EN" "http://www.w3.org/TR/REC-html40/frameset.dtd">',
				\ '!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">',
				\ '!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">',
				\ '!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">',
				\ '!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">',
				\ '!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">',
				\ '!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">',
				\ '!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/1999/xhtml">'
				\ ]
	endif

	for m in sort(tags)
		if m =~ '^'.context
			call add(res, m)
		elseif m =~ context
			call add(res2, m)
		endif
	endfor
	let menu = res + res2
	if has_key(b:html_omni, 'vimxmltaginfo')
		let final_menu = []
		for i in range(len(menu))
			let item = menu[i]
			if has_key(b:html_omni['vimxmltaginfo'], item)
				let m_menu = b:html_omni['vimxmltaginfo'][item][0]
				let m_info = b:html_omni['vimxmltaginfo'][item][1]
			else
				let m_menu = ''
				let m_info = ''
			endif
			if &filetype == 'html' && exists("uppercase_tag") && uppercase_tag == 1 && item !~ 'DOCTYPE'
				let item = toupper(item)
			endif
			if item =~ 'DOCTYPE'
				let abbr = 'DOCTYPE '.matchstr(item, 'DTD \zsX\?HTML .\{-}\ze\/\/')
			else
				let abbr = item
			endif
			let final_menu += [{'abbr':abbr, 'word':item, 'menu':m_menu, 'info':m_info}]
		endfor
	else
		let final_menu = menu
	endif
	return final_menu

	" }}}
  endif
endfunction

function! htmlcomplete#LoadData() " {{{
	if !exists("b:html_omni_flavor")
		if &filetype == 'html'
			let b:html_omni_flavor = 'html401t'
		else
			let b:html_omni_flavor = 'xhtml10s'
		endif
	endif
	" With that if we still have bloated memory but create new buffer
	" variables only by linking to existing g:variable, not sourcing whole
	" file.
	if exists('g:xmldata_'.b:html_omni_flavor)
		exe 'let b:html_omni = g:xmldata_'.b:html_omni_flavor
	else
		exe 'runtime! autoload/xml/'.b:html_omni_flavor.'.vim'
		exe 'let b:html_omni = g:xmldata_'.b:html_omni_flavor
	endif
endfunction
" }}}
function! htmlcomplete#CheckDoctype() " {{{
	if exists('b:html_omni_flavor')
		let old_flavor = b:html_omni_flavor
	else
		let old_flavor = ''
	endif
	let i = 1
	while i < 10 && i < line("$")
		let line = getline(i)
		if line =~ '<!DOCTYPE.*\<DTD HTML 3\.2'
			let b:html_omni_flavor = 'html32'
			let b:html_doctype = 1
			break
		elseif line =~ '<!DOCTYPE.*\<DTD HTML 4\.0 Transitional'
			let b:html_omni_flavor = 'html40t'
			let b:html_doctype = 1
			break
		elseif line =~ '<!DOCTYPE.*\<DTD HTML 4\.0 Frameset'
			let b:html_omni_flavor = 'html40f'
			let b:html_doctype = 1
			break
		elseif line =~ '<!DOCTYPE.*\<DTD HTML 4\.0'
			let b:html_omni_flavor = 'html40s'
			let b:html_doctype = 1
			break
		elseif line =~ '<!DOCTYPE.*\<DTD HTML 4\.01 Transitional'
			let b:html_omni_flavor = 'html401t'
			let b:html_doctype = 1
			break
		elseif line =~ '<!DOCTYPE.*\<DTD HTML 4\.01 Frameset'
			let b:html_omni_flavor = 'html401f'
			let b:html_doctype = 1
			break
		elseif line =~ '<!DOCTYPE.*\<DTD HTML 4\.01'
			let b:html_omni_flavor = 'html401s'
			let b:html_doctype = 1
			break
		elseif line =~ '<!DOCTYPE.*\<DTD XHTML 1\.0 Transitional'
			let b:html_omni_flavor = 'xhtml10t'
			let b:html_doctype = 1
			break
		elseif line =~ '<!DOCTYPE.*\<DTD XHTML 1\.0 Frameset'
			let b:html_omni_flavor = 'xhtml10f'
			let b:html_doctype = 1
			break
		elseif line =~ '<!DOCTYPE.*\<DTD XHTML 1\.0 Strict'
			let b:html_omni_flavor = 'xhtml10s'
			let b:html_doctype = 1
			break
		elseif line =~ '<!DOCTYPE.*\<DTD XHTML 1\.1'
			let b:html_omni_flavor = 'xhtml11'
			let b:html_doctype = 1
			break
		endif
		let i += 1
	endwhile
	if !exists("b:html_doctype")
		return
	else
		" Tie g:xmldata with b:html_omni this way we need to sourca data file only
		" once, not every time per buffer.
		if old_flavor == b:html_omni_flavor
			return
		else
			if exists('g:xmldata_'.b:html_omni_flavor)
				exe 'let b:html_omni = g:xmldata_'.b:html_omni_flavor
			else
				exe 'runtime! autoload/xml/'.b:html_omni_flavor.'.vim'
				exe 'let b:html_omni = g:xmldata_'.b:html_omni_flavor
			endif
			return
		endif
	endif
endfunction
" }}}
" vim:set foldmethod=marker:
