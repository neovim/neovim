" Vim completion script
" Language:	C
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2012 Jun 20

let s:cpo_save = &cpo
set cpo&vim

" This function is used for the 'omnifunc' option.
function! ccomplete#Complete(findstart, base)
  if a:findstart
    " Locate the start of the item, including ".", "->" and "[...]".
    let line = getline('.')
    let start = col('.') - 1
    let lastword = -1
    while start > 0
      if line[start - 1] =~ '\w'
	let start -= 1
      elseif line[start - 1] =~ '\.'
	if lastword == -1
	  let lastword = start
	endif
	let start -= 1
      elseif start > 1 && line[start - 2] == '-' && line[start - 1] == '>'
	if lastword == -1
	  let lastword = start
	endif
	let start -= 2
      elseif line[start - 1] == ']'
	" Skip over [...].
	let n = 0
	let start -= 1
	while start > 0
	  let start -= 1
	  if line[start] == '['
	    if n == 0
	      break
	    endif
	    let n -= 1
	  elseif line[start] == ']'  " nested []
	    let n += 1
	  endif
	endwhile
      else
	break
      endif
    endwhile

    " Return the column of the last word, which is going to be changed.
    " Remember the text that comes before it in s:prepended.
    if lastword == -1
      let s:prepended = ''
      return start
    endif
    let s:prepended = strpart(line, start, lastword - start)
    return lastword
  endif

  " Return list of matches.

  let base = s:prepended . a:base

  " Don't do anything for an empty base, would result in all the tags in the
  " tags file.
  if base == ''
    return []
  endif

  " init cache for vimgrep to empty
  let s:grepCache = {}

  " Split item in words, keep empty word after "." or "->".
  " "aa" -> ['aa'], "aa." -> ['aa', ''], "aa.bb" -> ['aa', 'bb'], etc.
  " We can't use split, because we need to skip nested [...].
  let items = []
  let s = 0
  while 1
    let e = match(base, '\.\|->\|\[', s)
    if e < 0
      if s == 0 || base[s - 1] != ']'
	call add(items, strpart(base, s))
      endif
      break
    endif
    if s == 0 || base[s - 1] != ']'
      call add(items, strpart(base, s, e - s))
    endif
    if base[e] == '.'
      let s = e + 1	" skip over '.'
    elseif base[e] == '-'
      let s = e + 2	" skip over '->'
    else
      " Skip over [...].
      let n = 0
      let s = e
      let e += 1
      while e < len(base)
	if base[e] == ']'
	  if n == 0
	    break
	  endif
	  let n -= 1
	elseif base[e] == '['  " nested [...]
	  let n += 1
	endif
	let e += 1
      endwhile
      let e += 1
      call add(items, strpart(base, s, e - s))
      let s = e
    endif
  endwhile

  " Find the variable items[0].
  " 1. in current function (like with "gd")
  " 2. in tags file(s) (like with ":tag")
  " 3. in current file (like with "gD")
  let res = []
  if searchdecl(items[0], 0, 1) == 0
    " Found, now figure out the type.
    " TODO: join previous line if it makes sense
    let line = getline('.')
    let col = col('.')
    if stridx(strpart(line, 0, col), ';') != -1
      " Handle multiple declarations on the same line.
      let col2 = col - 1
      while line[col2] != ';'
	let col2 -= 1
      endwhile
      let line = strpart(line, col2 + 1)
      let col -= col2
    endif
    if stridx(strpart(line, 0, col), ',') != -1
      " Handle multiple declarations on the same line in a function
      " declaration.
      let col2 = col - 1
      while line[col2] != ','
	let col2 -= 1
      endwhile
      if strpart(line, col2 + 1, col - col2 - 1) =~ ' *[^ ][^ ]*  *[^ ]'
	let line = strpart(line, col2 + 1)
	let col -= col2
      endif
    endif
    if len(items) == 1
      " Completing one word and it's a local variable: May add '[', '.' or
      " '->'.
      let match = items[0]
      let kind = 'v'
      if match(line, '\<' . match . '\s*\[') > 0
	let match .= '['
      else
	let res = s:Nextitem(strpart(line, 0, col), [''], 0, 1)
	if len(res) > 0
	  " There are members, thus add "." or "->".
	  if match(line, '\*[ \t(]*' . match . '\>') > 0
	    let match .= '->'
	  else
	    let match .= '.'
	  endif
	endif
      endif
      let res = [{'match': match, 'tagline' : '', 'kind' : kind, 'info' : line}]
    else
      " Completing "var.", "var.something", etc.
      let res = s:Nextitem(strpart(line, 0, col), items[1:], 0, 1)
    endif
  endif

  if len(items) == 1
    " Only one part, no "." or "->": complete from tags file.
    let tags = taglist('^' . base)

    " Remove members, these can't appear without something in front.
    call filter(tags, 'has_key(v:val, "kind") ? v:val["kind"] != "m" : 1')

    " Remove static matches in other files.
    call filter(tags, '!has_key(v:val, "static") || !v:val["static"] || bufnr("%") == bufnr(v:val["filename"])')

    call extend(res, map(tags, 's:Tag2item(v:val)'))
  endif

  if len(res) == 0
    " Find the variable in the tags file(s)
    let diclist = taglist('^' . items[0] . '$')

    " Remove members, these can't appear without something in front.
    call filter(diclist, 'has_key(v:val, "kind") ? v:val["kind"] != "m" : 1')

    let res = []
    for i in range(len(diclist))
      " New ctags has the "typeref" field.  Patched version has "typename".
      if has_key(diclist[i], 'typename')
	call extend(res, s:StructMembers(diclist[i]['typename'], items[1:], 1))
      elseif has_key(diclist[i], 'typeref')
	call extend(res, s:StructMembers(diclist[i]['typeref'], items[1:], 1))
      endif

      " For a variable use the command, which must be a search pattern that
      " shows the declaration of the variable.
      if diclist[i]['kind'] == 'v'
	let line = diclist[i]['cmd']
	if line[0] == '/' && line[1] == '^'
	  let col = match(line, '\<' . items[0] . '\>')
	  call extend(res, s:Nextitem(strpart(line, 2, col - 2), items[1:], 0, 1))
	endif
      endif
    endfor
  endif

  if len(res) == 0 && searchdecl(items[0], 1) == 0
    " Found, now figure out the type.
    " TODO: join previous line if it makes sense
    let line = getline('.')
    let col = col('.')
    let res = s:Nextitem(strpart(line, 0, col), items[1:], 0, 1)
  endif

  " If the last item(s) are [...] they need to be added to the matches.
  let last = len(items) - 1
  let brackets = ''
  while last >= 0
    if items[last][0] != '['
      break
    endif
    let brackets = items[last] . brackets
    let last -= 1
  endwhile

  return map(res, 's:Tagline2item(v:val, brackets)')
endfunc

function! s:GetAddition(line, match, memarg, bracket)
  " Guess if the item is an array.
  if a:bracket && match(a:line, a:match . '\s*\[') > 0
    return '['
  endif

  " Check if the item has members.
  if len(s:SearchMembers(a:memarg, [''], 0)) > 0
    " If there is a '*' before the name use "->".
    if match(a:line, '\*[ \t(]*' . a:match . '\>') > 0
      return '->'
    else
      return '.'
    endif
  endif
  return ''
endfunction

" Turn the tag info "val" into an item for completion.
" "val" is is an item in the list returned by taglist().
" If it is a variable we may add "." or "->".  Don't do it for other types,
" such as a typedef, by not including the info that s:GetAddition() uses.
function! s:Tag2item(val)
  let res = {'match': a:val['name']}

  let res['extra'] = s:Tagcmd2extra(a:val['cmd'], a:val['name'], a:val['filename'])

  let s = s:Dict2info(a:val)
  if s != ''
    let res['info'] = s
  endif

  let res['tagline'] = ''
  if has_key(a:val, "kind")
    let kind = a:val['kind']
    let res['kind'] = kind
    if kind == 'v'
      let res['tagline'] = "\t" . a:val['cmd']
      let res['dict'] = a:val
    elseif kind == 'f'
      let res['match'] = a:val['name'] . '('
    endif
  endif

  return res
endfunction

" Use all the items in dictionary for the "info" entry.
function! s:Dict2info(dict)
  let info = ''
  for k in sort(keys(a:dict))
    let info  .= k . repeat(' ', 10 - len(k))
    if k == 'cmd'
      let info .= substitute(matchstr(a:dict['cmd'], '/^\s*\zs.*\ze$/'), '\\\(.\)', '\1', 'g')
    else
      let info .= a:dict[k]
    endif
    let info .= "\n"
  endfor
  return info
endfunc

" Parse a tag line and return a dictionary with items like taglist()
function! s:ParseTagline(line)
  let l = split(a:line, "\t")
  let d = {}
  if len(l) >= 3
    let d['name'] = l[0]
    let d['filename'] = l[1]
    let d['cmd'] = l[2]
    let n = 2
    if l[2] =~ '^/'
      " Find end of cmd, it may contain Tabs.
      while n < len(l) && l[n] !~ '/;"$'
	let n += 1
	let d['cmd'] .= "  " . l[n]
      endwhile
    endif
    for i in range(n + 1, len(l) - 1)
      if l[i] == 'file:'
	let d['static'] = 1
      elseif l[i] !~ ':'
	let d['kind'] = l[i]
      else
	let d[matchstr(l[i], '[^:]*')] = matchstr(l[i], ':\zs.*')
      endif
    endfor
  endif

  return d
endfunction

" Turn a match item "val" into an item for completion.
" "val['match']" is the matching item.
" "val['tagline']" is the tagline in which the last part was found.
function! s:Tagline2item(val, brackets)
  let line = a:val['tagline']
  let add = s:GetAddition(line, a:val['match'], [a:val], a:brackets == '')
  let res = {'word': a:val['match'] . a:brackets . add }

  if has_key(a:val, 'info')
    " Use info from Tag2item().
    let res['info'] = a:val['info']
  else
    " Parse the tag line and add each part to the "info" entry.
    let s = s:Dict2info(s:ParseTagline(line))
    if s != ''
      let res['info'] = s
    endif
  endif

  if has_key(a:val, 'kind')
    let res['kind'] = a:val['kind']
  elseif add == '('
    let res['kind'] = 'f'
  else
    let s = matchstr(line, '\t\(kind:\)\=\zs\S\ze\(\t\|$\)')
    if s != ''
      let res['kind'] = s
    endif
  endif

  if has_key(a:val, 'extra')
    let res['menu'] = a:val['extra']
    return res
  endif

  " Isolate the command after the tag and filename.
  let s = matchstr(line, '[^\t]*\t[^\t]*\t\zs\(/^.*$/\|[^\t]*\)\ze\(;"\t\|\t\|$\)')
  if s != ''
    let res['menu'] = s:Tagcmd2extra(s, a:val['match'], matchstr(line, '[^\t]*\t\zs[^\t]*\ze\t'))
  endif
  return res
endfunction

" Turn a command from a tag line to something that is useful in the menu
function! s:Tagcmd2extra(cmd, name, fname)
  if a:cmd =~ '^/^'
    " The command is a search command, useful to see what it is.
    let x = matchstr(a:cmd, '^/^\s*\zs.*\ze$/')
    let x = substitute(x, '\<' . a:name . '\>', '@@', '')
    let x = substitute(x, '\\\(.\)', '\1', 'g')
    let x = x . ' - ' . a:fname
  elseif a:cmd =~ '^\d*$'
    " The command is a line number, the file name is more useful.
    let x = a:fname . ' - ' . a:cmd
  else
    " Not recognized, use command and file name.
    let x = a:cmd . ' - ' . a:fname
  endif
  return x
endfunction

" Find composing type in "lead" and match items[0] with it.
" Repeat this recursively for items[1], if it's there.
" When resolving typedefs "depth" is used to avoid infinite recursion.
" Return the list of matches.
function! s:Nextitem(lead, items, depth, all)

  " Use the text up to the variable name and split it in tokens.
  let tokens = split(a:lead, '\s\+\|\<')

  " Try to recognize the type of the variable.  This is rough guessing...
  let res = []
  for tidx in range(len(tokens))

    " Skip tokens starting with a non-ID character.
    if tokens[tidx] !~ '^\h'
      continue
    endif

    " Recognize "struct foobar" and "union foobar".
    " Also do "class foobar" when it's C++ after all (doesn't work very well
    " though).
    if (tokens[tidx] == 'struct' || tokens[tidx] == 'union' || tokens[tidx] == 'class') && tidx + 1 < len(tokens)
      let res = s:StructMembers(tokens[tidx] . ':' . tokens[tidx + 1], a:items, a:all)
      break
    endif

    " TODO: add more reserved words
    if index(['int', 'short', 'char', 'float', 'double', 'static', 'unsigned', 'extern'], tokens[tidx]) >= 0
      continue
    endif

    " Use the tags file to find out if this is a typedef.
    let diclist = taglist('^' . tokens[tidx] . '$')
    for tagidx in range(len(diclist))
      let item = diclist[tagidx]

      " New ctags has the "typeref" field.  Patched version has "typename".
      if has_key(item, 'typeref')
	call extend(res, s:StructMembers(item['typeref'], a:items, a:all))
	continue
      endif
      if has_key(item, 'typename')
	call extend(res, s:StructMembers(item['typename'], a:items, a:all))
	continue
      endif

      " Only handle typedefs here.
      if item['kind'] != 't'
	continue
      endif

      " Skip matches local to another file.
      if has_key(item, 'static') && item['static'] && bufnr('%') != bufnr(item['filename'])
	continue
      endif

      " For old ctags we recognize "typedef struct aaa" and
      " "typedef union bbb" in the tags file command.
      let cmd = item['cmd']
      let ei = matchend(cmd, 'typedef\s\+')
      if ei > 1
	let cmdtokens = split(strpart(cmd, ei), '\s\+\|\<')
	if len(cmdtokens) > 1
	  if cmdtokens[0] == 'struct' || cmdtokens[0] == 'union' || cmdtokens[0] == 'class'
	    let name = ''
	    " Use the first identifier after the "struct" or "union"
	    for ti in range(len(cmdtokens) - 1)
	      if cmdtokens[ti] =~ '^\w'
		let name = cmdtokens[ti]
		break
	      endif
	    endfor
	    if name != ''
	      call extend(res, s:StructMembers(cmdtokens[0] . ':' . name, a:items, a:all))
	    endif
	  elseif a:depth < 10
	    " Could be "typedef other_T some_T".
	    call extend(res, s:Nextitem(cmdtokens[0], a:items, a:depth + 1, a:all))
	  endif
	endif
      endif
    endfor
    if len(res) > 0
      break
    endif
  endfor

  return res
endfunction


" Search for members of structure "typename" in tags files.
" Return a list with resulting matches.
" Each match is a dictionary with "match" and "tagline" entries.
" When "all" is non-zero find all, otherwise just return 1 if there is any
" member.
function! s:StructMembers(typename, items, all)
  " Todo: What about local structures?
  let fnames = join(map(tagfiles(), 'escape(v:val, " \\#%")'))
  if fnames == ''
    return []
  endif

  let typename = a:typename
  let qflist = []
  let cached = 0
  if a:all == 0
    let n = '1'	" stop at first found match
    if has_key(s:grepCache, a:typename)
      let qflist = s:grepCache[a:typename]
      let cached = 1
    endif
  else
    let n = ''
  endif
  if !cached
    while 1
      exe 'silent! keepj noautocmd ' . n . 'vimgrep /\t' . typename . '\(\t\|$\)/j ' . fnames

      let qflist = getqflist()
      if len(qflist) > 0 || match(typename, "::") < 0
	break
      endif
      " No match for "struct:context::name", remove "context::" and try again.
      let typename = substitute(typename, ':[^:]*::', ':', '')
    endwhile

    if a:all == 0
      " Store the result to be able to use it again later.
      let s:grepCache[a:typename] = qflist
    endif
  endif

  " Put matching members in matches[].
  let matches = []
  for l in qflist
    let memb = matchstr(l['text'], '[^\t]*')
    if memb =~ '^' . a:items[0]
      " Skip matches local to another file.
      if match(l['text'], "\tfile:") < 0 || bufnr('%') == bufnr(matchstr(l['text'], '\t\zs[^\t]*'))
	let item = {'match': memb, 'tagline': l['text']}

	" Add the kind of item.
	let s = matchstr(l['text'], '\t\(kind:\)\=\zs\S\ze\(\t\|$\)')
	if s != ''
	  let item['kind'] = s
	  if s == 'f'
	    let item['match'] = memb . '('
	  endif
	endif

	call add(matches, item)
      endif
    endif
  endfor

  if len(matches) > 0
    " Skip over [...] items
    let idx = 1
    while 1
      if idx >= len(a:items)
	return matches		" No further items, return the result.
      endif
      if a:items[idx][0] != '['
	break
      endif
      let idx += 1
    endwhile

    " More items following.  For each of the possible members find the
    " matching following members.
    return s:SearchMembers(matches, a:items[idx :], a:all)
  endif

  " Failed to find anything.
  return []
endfunction

" For matching members, find matches for following items.
" When "all" is non-zero find all, otherwise just return 1 if there is any
" member.
function! s:SearchMembers(matches, items, all)
  let res = []
  for i in range(len(a:matches))
    let typename = ''
    if has_key(a:matches[i], 'dict')
      if has_key(a:matches[i].dict, 'typename')
	let typename = a:matches[i].dict['typename']
      elseif has_key(a:matches[i].dict, 'typeref')
	let typename = a:matches[i].dict['typeref']
      endif
      let line = "\t" . a:matches[i].dict['cmd']
    else
      let line = a:matches[i]['tagline']
      let e = matchend(line, '\ttypename:')
      if e < 0
	let e = matchend(line, '\ttyperef:')
      endif
      if e > 0
	" Use typename field
	let typename = matchstr(line, '[^\t]*', e)
      endif
    endif

    if typename != ''
      call extend(res, s:StructMembers(typename, a:items, a:all))
    else
      " Use the search command (the declaration itself).
      let s = match(line, '\t\zs/^')
      if s > 0
	let e = match(line, '\<' . a:matches[i]['match'] . '\>', s)
	if e > 0
	  call extend(res, s:Nextitem(strpart(line, s, e - s), a:items, 0, a:all))
	endif
      endif
    endif
    if a:all == 0 && len(res) > 0
      break
    endif
  endfor
  return res
endfunc

let &cpo = s:cpo_save
unlet s:cpo_save
