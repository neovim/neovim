" Author: Antony Lee <anntzer.lee@gmail.com>
" Description: Helper functions for reStructuredText syntax folding
" Last Modified: 2018-01-07

function s:CacheRstFold()
  let closure = {'header_types': {}, 'max_level': 0, 'levels': {}}
  function closure.Process(match) dict
    let curline = getcurpos()[1]
    if has_key(self.levels, curline - 1)
      " For over+under-lined headers, the regex will match both at the
      " overline and at the title itself; in that case, skip the second match.
      return
    endif
    let lines = split(a:match, '\n')
    let key = repeat(lines[-1][0], len(lines))
    if !has_key(self.header_types, key)
      let self.max_level += 1
      let self.header_types[key] = self.max_level
    endif
    let self.levels[curline] = self.header_types[key]
  endfunction
  let save_cursor = getcurpos()
  silent keeppatterns %s/\v^%(%(([=`:.'"~^_*+#-])\1+\n)?.{1,2}\n([=`:.'"~^_*+#-])\2+)|%(%(([=`:.''"~^_*+#-])\3{2,}\n)?.{3,}\n([=`:.''"~^_*+#-])\4{2,})$/\=closure.Process(submatch(0))/gn
  call setpos('.', save_cursor)
  let b:RstFoldCache = closure.levels
endfunction

function RstFold#GetRstFold()
  if !has_key(b:, 'RstFoldCache')
    call s:CacheRstFold()
  endif
  if has_key(b:RstFoldCache, v:lnum)
    return '>' . b:RstFoldCache[v:lnum]
  else
    return '='
  endif
endfunction

function RstFold#GetRstFoldText()
  if !has_key(b:, 'RstFoldCache')
    call s:CacheRstFold()
  endif
  let indent = repeat('  ', b:RstFoldCache[v:foldstart] - 1)
  let thisline = getline(v:foldstart)
  " For over+under-lined headers, skip the overline.
  let text = thisline =~ '^\([=`:.''"~^_*+#-]\)\1\+$' ? getline(v:foldstart + 1) : thisline
  return indent . text
endfunction
