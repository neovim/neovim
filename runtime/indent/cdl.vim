" Description:	Comshare Dimension Definition Language (CDL)
" Author:	Raul Segura Acevedo <raulseguraaceved@netscape.net>
" Last Change:	Fri Nov 30 13:35:48  2001 CST

if exists("b:did_indent")
    "finish
endif
let b:did_indent = 1

setlocal indentexpr=CdlGetIndent(v:lnum)
setlocal indentkeys&
setlocal indentkeys+==~else,=~endif,=~then,;,),=

" Only define the function once.
if exists("*CdlGetIndent")
    "finish
endif

" find out if an "...=..." expresion is an assignment (or a conditional)
" it scans 'line' first, and then the previos lines
fun! CdlAsignment(lnum, line)
  let f = -1
  let lnum = a:lnum
  let line = a:line
  while lnum > 0 && f == -1
    " line without members [a] of [b]:[c]...
    let inicio = 0
    while 1
      " keywords that help to decide
      let inicio = matchend(line, '\c\<\(expr\|\a*if\|and\|or\|not\|else\|then\|memberis\|\k\+of\)\>\|[<>;]', inicio)
      if inicio < 0
	break
      endif
      " it's formula if there's a ';', 'elsE', 'theN', 'enDif' or 'expr'
      " conditional if there's a '<', '>', 'elseif', 'if', 'and', 'or', 'not',
      " 'memberis', 'childrenof' and other \k\+of funcions
      let f = line[inicio-1] =~? '[en;]' || strpart(line, inicio-4, 4) =~? 'ndif\|expr'
    endw
    let lnum = prevnonblank(lnum-1)
    let line = substitute(getline(lnum), '\c\(\[[^]]*]\(\s*of\s*\|:\)*\)\+', ' ', 'g')
  endw
  " if we hit the start of the file then f = -1, return 1 (formula)
  return f != 0
endf

fun! CdlGetIndent(lnum)
  let thisline = getline(a:lnum)
  if match(thisline, '^\s*\(\k\+\|\[[^]]*]\)\s*\(,\|;\s*$\)') >= 0
    " it's an attributes line
    return &sw
  elseif match(thisline, '^\c\s*\([{}]\|\/[*/]\|dimension\|schedule\|group\|hierarchy\|class\)') >= 0
    " it's a header or '{' or '}' or a comment
    return 0
  end

  let lnum = prevnonblank(a:lnum-1)
  " Hit the start of the file, use zero indent.
  if lnum == 0
    return 0
  endif

  " PREVIOUS LINE
  let ind = indent(lnum)
  let line = getline(lnum)
  let f = -1 " wether a '=' is a conditional or a asignment, -1 means we don't know yet
  " one 'closing' element at the beginning of the line has already reduced the
  "   indent, but 'else', 'elseif' & 'then' increment it for the next line
  " '=' at the beginning has already de right indent (increased for asignments)
  let inicio = matchend(line, '^\c\s*\(else\a*\|then\|endif\|/[*/]\|[);={]\)')
  if inicio > 0
    let c = line[inicio-1]
    " ')' and '=' don't change indent and are useless to set 'f'
    if c == '{'
      return &sw
    elseif c != ')' && c != '='
      let f = 1 " all but 'elseif' are followed by a formula
      if c ==? 'n' || c ==? 'e' " 'then', 'else'
	let ind = ind + &sw
      elseif strpart(line, inicio-6, 6) ==? 'elseif' " elseif, set f to conditional
	let ind = ind + &sw
	let f = 0
      end
    end
  end

  " remove members [a] of [b]:[c]... (inicio remainds valid)
  let line = substitute(line, '\c\(\[[^]]*]\(\s*of\s*\|:\)*\)\+', ' ', 'g')
  while 1
    " search for the next interesting element
    let inicio=matchend(line, '\c\<if\|endif\|[()=;]', inicio)
    if inicio < 0
      break
    end

    let c = line[inicio-1]
    " 'expr(...)' containing the formula
    if strpart(line, inicio-5, 5) ==? 'expr('
      let ind = 0
      let f = 1
    elseif c == ')' || c== ';' || strpart(line, inicio-5, 5) ==? 'endif'
      let ind = ind - &sw
    elseif c == '(' || c ==? 'f' " '(' or 'if'
      let ind = ind + &sw
    else " c == '='
      " if it is an asignment increase indent
      if f == -1 " we don't know yet, find out
	let f = CdlAsignment(lnum, strpart(line, 0, inicio))
      end
      if f == 1 " formula increase it
	let ind = ind + &sw
      end
    end
  endw

  " CURRENT LINE, if it starts with a closing element, decrease indent
  " or if it starts with '=' (asignment), increase indent
  if match(thisline, '^\c\s*\(else\|then\|endif\|[);]\)') >= 0
    let ind = ind - &sw
  elseif match(thisline, '^\s*=') >= 0
    if f == -1 " we don't know yet if is an asignment, find out
      let f = CdlAsignment(lnum, "")
    end
    if f == 1 " formula increase it
      let ind = ind + &sw
    end
  end

  return ind
endfun
