" HTML folding script, :h ft-html-plugin
" Latest Change: 2025 May 10
" Original Author: Aliaksei Budavei <0x000c70@gmail.com>

function! htmlfold#MapBalancedTags() abort
  " Describe only _a capturable-name prefix_ for start and end patterns of
  " a tag so that start tags with attributes spanning across lines can also be
  " matched with a single call of "getline()".
  let tag = '\m\c</\=\([0-9A-Za-z-]\+\)'
  let names = []
  let pairs = []
  let ends = []
  let pos = getpos('.')

  try
    call cursor(1, 1)
    let [lnum, cnum] = searchpos(tag, 'cnW')

    " Pair up nearest non-inlined tags in scope.
    while lnum > 0
      let name_attr = synIDattr(synID(lnum, cnum, 0), 'name')

      if name_attr ==# 'htmlTag' || name_attr ==# 'htmlScriptTag'
	let name = get(matchlist(getline(lnum), tag, (cnum - 1)), 1, '')

	if !empty(name)
	  call insert(names, tolower(name), 0)
	  call insert(pairs, [lnum, -1], 0)
	endif
      elseif name_attr ==# 'htmlEndTag'
	let name = get(matchlist(getline(lnum), tag, (cnum - 1)), 1, '')

	if !empty(name)
	  let idx = index(names, tolower(name))

	  if idx >= 0
	    " Dismiss inlined balanced tags and opened-only tags.
	    if pairs[idx][0] != lnum
	      let pairs[idx][1] = lnum
	      call add(ends, lnum)
	    endif

	    " Claim a pair.
	    let names[: idx] = repeat([''], (idx + 1))
	  endif
	endif
      endif

      " Advance the cursor, at "<", past "</a", "<a>", etc.
      call cursor(lnum, (cnum + 3))
      let [lnum, cnum] = searchpos(tag, 'cnW')
    endwhile
  finally
    call setpos('.', pos)
  endtry

  if empty(ends)
    return {}
  endif

  let folds = {}
  let pending_end = ends[0]
  let level = 0

  while !empty(pairs)
    let [start, end] = remove(pairs, -1)

    if end < 0
      continue
    endif

    if start >= pending_end
      " Mark a sibling tag.
      call remove(ends, 0)

      while start >= ends[0]
	" Mark a parent tag.
	call remove(ends, 0)
	let level -= 1
      endwhile

      let pending_end = ends[0]
    else
      " Mark a child tag.
      let level += 1
    endif

    " Flatten the innermost inlined folds.
    let folds[start] = get(folds, start, ('>' . level))
    let folds[end] = get(folds, end, ('<' . level))
  endwhile

  return folds
endfunction

" See ":help vim9-mix".
if !has("vim9script")
  finish
endif

def! g:htmlfold#MapBalancedTags(): dict<string>
  # Describe only _a capturable-name prefix_ for start and end patterns of
  # a tag so that start tags with attributes spanning across lines can also be
  # matched with a single call of "getline()".
  const tag: string = '\m\c</\=\([0-9A-Za-z-]\+\)'
  var names: list<string> = []
  var pairs: list<list<number>> = []
  var ends: list<number> = []
  const pos: list<number> = getpos('.')

  try
    cursor(1, 1)
    var [lnum: number, cnum: number] = searchpos(tag, 'cnW')

    # Pair up nearest non-inlined tags in scope.
    while lnum > 0
      const name_attr: string = synIDattr(synID(lnum, cnum, 0), 'name')

      if name_attr ==# 'htmlTag' || name_attr ==# 'htmlScriptTag'
	const name: string = get(matchlist(getline(lnum), tag, (cnum - 1)), 1, '')

	if !empty(name)
	  insert(names, tolower(name), 0)
	  insert(pairs, [lnum, -1], 0)
	endif
      elseif name_attr ==# 'htmlEndTag'
	const name: string = get(matchlist(getline(lnum), tag, (cnum - 1)), 1, '')

	if !empty(name)
	  const idx: number = index(names, tolower(name))

	  if idx >= 0
	    # Dismiss inlined balanced tags and opened-only tags.
	    if pairs[idx][0] != lnum
	      pairs[idx][1] = lnum
	      add(ends, lnum)
	    endif

	    # Claim a pair.
	    names[: idx] = repeat([''], (idx + 1))
	  endif
	endif
      endif

      # Advance the cursor, at "<", past "</a", "<a>", etc.
      cursor(lnum, (cnum + 3))
      [lnum, cnum] = searchpos(tag, 'cnW')
    endwhile
  finally
    setpos('.', pos)
  endtry

  if empty(ends)
    return {}
  endif

  var folds: dict<string> = {}
  var pending_end: number = ends[0]
  var level: number = 0

  while !empty(pairs)
    const [start: number, end: number] = remove(pairs, -1)

    if end < 0
      continue
    endif

    if start >= pending_end
      # Mark a sibling tag.
      remove(ends, 0)

      while start >= ends[0]
	# Mark a parent tag.
	remove(ends, 0)
	level -= 1
      endwhile

      pending_end = ends[0]
    else
      # Mark a child tag.
      level += 1
    endif

    # Flatten the innermost inlined folds.
    folds[start] = get(folds, start, ('>' .. level))
    folds[end] = get(folds, end, ('<' .. level))
  endwhile

  return folds
enddef

" vim: fdm=syntax sw=2 ts=8 noet
