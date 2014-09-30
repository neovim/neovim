" Script to extract tables from Unicode .txt files, to be used in src/mbyte.c.
" The format of the UnicodeData.txt file is explained here:
" http://www.unicode.org/Public/5.1.0/ucd/UCD.html
" For the other files see the header.
"
" Usage: Vim -S <this-file>
"
" Author: Bram Moolenaar
" Last Update: 2010 Jan 12

" Parse lines of UnicodeData.txt.  Creates a list of lists in s:dataprops.
func! ParseDataToProps()
  let s:dataprops = []
  let lnum = 1
  while lnum <= line('$')
    let l = split(getline(lnum), '\s*;\s*', 1)
    if len(l) != 15
      echoerr 'Found ' . len(l) . ' items in line ' . lnum . ', expected 15'
      return
    endif
    call add(s:dataprops, l)
    let lnum += 1
  endwhile
endfunc

" Parse lines of CaseFolding.txt.  Creates a list of lists in s:foldprops.
func! ParseFoldProps()
  let s:foldprops = []
  let lnum = 1
  while lnum <= line('$')
    let line = getline(lnum)
    if line !~ '^#' && line !~ '^\s*$'
      let l = split(line, '\s*;\s*', 1)
      if len(l) != 4
	echoerr 'Found ' . len(l) . ' items in line ' . lnum . ', expected 4'
	return
      endif
      call add(s:foldprops, l)
    endif
    let lnum += 1
  endwhile
endfunc

" Parse lines of EastAsianWidth.txt.  Creates a list of lists in s:widthprops.
func! ParseWidthProps()
  let s:widthprops = []
  let lnum = 1
  while lnum <= line('$')
    let line = getline(lnum)
    if line !~ '^#' && line !~ '^\s*$'
      let l = split(line, '\s*;\s*', 1)
      if len(l) != 2
	echoerr 'Found ' . len(l) . ' items in line ' . lnum . ', expected 2'
	return
      endif
      call add(s:widthprops, l)
    endif
    let lnum += 1
  endwhile
endfunc

" Build the toLower or toUpper table in a new buffer.
" Uses s:dataprops.
func! BuildCaseTable(name, index)
  let start = -1
  let end = -1
  let step = 0
  let add = -1
  let ranges = []
  for p in s:dataprops
    if p[a:index] != ''
      let n = ('0x' . p[0]) + 0
      let nl = ('0x' . p[a:index]) + 0
      if start >= 0 && add == nl - n && (step == 0 || n - end == step)
	" continue with same range.
	let step = n - end
	let end = n
      else
	if start >= 0
	  " produce previous range
	  call Range(ranges, start, end, step, add)
	endif
	let start = n
	let end = n
	let step = 0
	let add = nl - n
      endif
    endif
  endfor
  if start >= 0
    call Range(ranges, start, end, step, add)
  endif

  " New buffer to put the result in.
  new
  exe "file to" . a:name
  call setline(1, "static convertStruct to" . a:name . "[] =")
  call setline(2, "{")
  call append('$', ranges)
  call setline('$', getline('$')[:-2])  " remove last comma
  call setline(line('$') + 1, "};")
  wincmd p
endfunc

" Build the foldCase table in a new buffer.
" Uses s:foldprops.
func! BuildFoldTable()
  let start = -1
  let end = -1
  let step = 0
  let add = -1
  let ranges = []
  for p in s:foldprops
    if p[1] == 'C' || p[1] == 'S'
      let n = ('0x' . p[0]) + 0
      let nl = ('0x' . p[2]) + 0
      if start >= 0 && add == nl - n && (step == 0 || n - end == step)
	" continue with same range.
	let step = n - end
	let end = n
      else
	if start >= 0
	  " produce previous range
	  call Range(ranges, start, end, step, add)
	endif
	let start = n
	let end = n
	let step = 0
	let add = nl - n
      endif
    endif
  endfor
  if start >= 0
    call Range(ranges, start, end, step, add)
  endif

  " New buffer to put the result in.
  new
  file foldCase
  call setline(1, "static convertStruct foldCase[] =")
  call setline(2, "{")
  call append('$', ranges)
  call setline('$', getline('$')[:-2])  " remove last comma
  call setline(line('$') + 1, "};")
  wincmd p
endfunc

func! Range(ranges, start, end, step, add)
  let s = printf("\t{0x%x,0x%x,%d,%d},", a:start, a:end, a:step == 0 ? -1 : a:step, a:add)
  call add(a:ranges, s)
endfunc

" Build the combining table.
" Uses s:dataprops.
func! BuildCombiningTable()
  let start = -1
  let end = -1
  let ranges = []
  for p in s:dataprops
    if p[2] == 'Mn' || p[2] == 'Mc' || p[2] == 'Me'
      let n = ('0x' . p[0]) + 0
      if start >= 0 && end + 1 == n
	" continue with same range.
	let end = n
      else
	if start >= 0
	  " produce previous range
	  call add(ranges, printf("\t{0x%04x, 0x%04x},", start, end))
	endif
	let start = n
	let end = n
      endif
    endif
  endfor
  if start >= 0
    call add(ranges, printf("\t{0x%04x, 0x%04x},", start, end))
  endif

  " New buffer to put the result in.
  new
  file combining
  call setline(1, "    static struct interval combining[] =")
  call setline(2, "    {")
  call append('$', ranges)
  call setline('$', getline('$')[:-2])  " remove last comma
  call setline(line('$') + 1, "    };")
  wincmd p
endfunc

" Build the double width or ambiguous width table in a new buffer.
" Uses s:widthprops and s:dataprops.
func! BuildWidthTable(pattern, tableName)
  let start = -1
  let end = -1
  let ranges = []
  let dataidx = 0
  for p in s:widthprops
    if p[1][0] =~ a:pattern
      if p[0] =~ '\.\.'
	" It is a range.  we don't check for composing char then.
	let rng = split(p[0], '\.\.')
	if len(rng) != 2
	  echoerr "Cannot parse range: '" . p[0] . "' in width table"
	endif
	let n = ('0x' . rng[0]) + 0
	let n_last =  ('0x' . rng[1]) + 0
      else
	let n = ('0x' . p[0]) + 0
	let n_last = n
      endif
      " Find this char in the data table.
      while 1
	let dn = ('0x' . s:dataprops[dataidx][0]) + 0
	if dn >= n
	  break
	endif
	let dataidx += 1
      endwhile
      if dn != n && n_last == n
	echoerr "Cannot find character " . n . " in data table"
      endif
      " Only use the char when it's not a composing char.
      " But use all chars from a range.
      let dp = s:dataprops[dataidx]
      if n_last > n || (dp[2] != 'Mn' && dp[2] != 'Mc' && dp[2] != 'Me')
	if start >= 0 && end + 1 == n
	  " continue with same range.
	else
	  if start >= 0
	    " produce previous range
	    call add(ranges, printf("\t{0x%04x, 0x%04x},", start, end))
	  endif
	  let start = n
	endif
	let end = n_last
      endif
    endif
  endfor
  if start >= 0
    call add(ranges, printf("\t{0x%04x, 0x%04x},", start, end))
  endif

  " New buffer to put the result in.
  new
  exe "file " . a:tableName
  call setline(1, "    static struct interval " . a:tableName . "[] =")
  call setline(2, "    {")
  call append('$', ranges)
  call setline('$', getline('$')[:-2])  " remove last comma
  call setline(line('$') + 1, "    };")
  wincmd p
endfunc



" Edit the Unicode text file.  Requires the netrw plugin.
edit http://unicode.org/Public/UNIDATA/UnicodeData.txt

" Parse each line, create a list of lists.
call ParseDataToProps()

" Build the toLower table.
call BuildCaseTable("Lower", 13)

" Build the toUpper table.
call BuildCaseTable("Upper", 12)

" Build the ranges of composing chars.
call BuildCombiningTable()

" Edit the case folding text file.  Requires the netrw plugin.
edit http://www.unicode.org/Public/UNIDATA/CaseFolding.txt

" Parse each line, create a list of lists.
call ParseFoldProps()

" Build the foldCase table.
call BuildFoldTable()

" Edit the width text file.  Requires the netrw plugin.
edit http://www.unicode.org/Public/UNIDATA/EastAsianWidth.txt

" Parse each line, create a list of lists.
call ParseWidthProps()

" Build the double width table.
call BuildWidthTable('[WF]', 'doublewidth')

" Build the ambiguous width table.
call BuildWidthTable('A', 'ambiguous')
