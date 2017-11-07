" VHDL indent ('93 syntax)
" Language:    VHDL
" Maintainer:  Gerald Lai <laigera+vim?gmail.com>
" Version:     1.62
" Last Change: 2017 Oct 17
" URL:         http://www.vim.org/scripts/script.php?script_id=1450

" only load this indent file when no other was loaded
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

" setup indent options for local VHDL buffer
setlocal indentexpr=GetVHDLindent()
setlocal indentkeys=!^F,o,O,0(,0)
setlocal indentkeys+==~begin,=~end\ ,=~end\	,=~is,=~select,=~when
setlocal indentkeys+==~if,=~then,=~elsif,=~else
setlocal indentkeys+==~case,=~loop,=~for,=~generate,=~record,=~units,=~process,=~block,=~function,=~component,=~procedure
setlocal indentkeys+==~architecture,=~configuration,=~entity,=~package

" constants
" not a comment
let s:NC = '\%(--.*\)\@<!'
" end of string
let s:ES = '\s*\%(--.*\)\=$'
" no "end" keyword in front
let s:NE = '\%(\<end\s\+\)\@<!'

" option to disable alignment of generic/port mappings
if !exists("g:vhdl_indent_genportmap")
  let g:vhdl_indent_genportmap = 1
endif

" option to disable alignment of right-hand side assignment "<=" statements
if !exists("g:vhdl_indent_rhsassign")
  let g:vhdl_indent_rhsassign = 1
endif

" only define indent function once
if exists("*GetVHDLindent")
  finish
endif

function GetVHDLindent()
  " store current line & string
  let curn = v:lnum
  let curs = getline(curn)

  " find previous line that is not a comment
  let prevn = prevnonblank(curn - 1)
  let prevs = getline(prevn)
  while prevn > 0 && prevs =~ '^\s*--'
    let prevn = prevnonblank(prevn - 1)
    let prevs = getline(prevn)
  endwhile
  let prevs_noi = substitute(prevs, '^\s*', '', '')

  " default indent starts as previous non-comment line's indent
  let ind = prevn > 0 ? indent(prevn) : 0
  " backup default
  let ind2 = ind

  " indent:   special; kill string so it would not affect other filters
  " keywords: "report" + string
  " where:    anywhere in current or previous line
  let s0 = s:NC.'\<report\>\s*".*"'
  if curs =~? s0
    let curs = ""
  endif
  if prevs =~? s0
    let prevs = ""
  endif

  " indent:   previous line's comment position, otherwise follow next non-comment line if possible
  " keyword:  "--"
  " where:    start of current line
  if curs =~ '^\s*--'
    let pn = curn - 1
    let ps = getline(pn)
    if curs =~ '^\s*--\s' && ps =~ '--'
      return indent(pn) + stridx(substitute(ps, '^\s*', '', ''), '--')
    else
      " find nextnonblank line that is not a comment
      let nn = nextnonblank(curn + 1)
      let ns = getline(nn)
      while nn > 0 && ns =~ '^\s*--'
        let nn = nextnonblank(nn + 1)
        let ns = getline(nn)
      endwhile
      let n = indent(nn)
      return n != -1 ? n : ind
    endif
  endif

  " ****************************************************************************************
  " indent:   align generic variables & port names
  " keywords: "procedure" + name, "generic", "map", "port" + "(", provided current line is part of mapping
  " where:    anywhere in previous 2 lines
  " find following previous non-comment line
  let pn = prevnonblank(prevn - 1)
  let ps = getline(pn)
  while pn > 0 && ps =~ '^\s*--'
    let pn = prevnonblank(pn - 1)
    let ps = getline(pn)
  endwhile
  if (curs =~ '^\s*)' || curs =~? '^\s*\%(\<\%(procedure\|generic\|map\|port\)\>.*\)\@<!\w\+\s*\w*\s*\((.*)\)*\s*\%(=>\s*\S\+\|:[^=]\@=\s*\%(\%(in\|out\|inout\|buffer\|linkage\)\>\|\s\+\)\)') && (prevs =~? s:NC.'\<\%(procedure\s\+\S\+\|generic\|map\|port\)\s*(\%(\s*\w\)\=' || (ps =~? s:NC.'\<\%(procedure\|generic\|map\|port\)'.s:ES && prevs =~ '^\s*('))
    " align closing ")" with opening "("
    if curs =~ '^\s*)'
      return ind2 + stridx(prevs_noi, '(')
    endif
    let m = matchend(prevs_noi, '(\s*\ze\w')
    if m != -1
      return ind2 + m
    else
      if g:vhdl_indent_genportmap
        return ind2 + stridx(prevs_noi, '(') + shiftwidth()
      else
        return ind2 + shiftwidth()
      endif
    endif
  endif

  " indent:   align conditional/select statement
  " keywords: variable + "<=" without ";" ending
  " where:    start of previous line
  if prevs =~? '^\s*\S\+\s*<=[^;]*'.s:ES
    if g:vhdl_indent_rhsassign
      return ind2 + matchend(prevs_noi, '<=\s*\ze.')
    else
      return ind2 + shiftwidth()
    endif
  endif

  " indent:   backtrace previous non-comment lines for next smaller or equal size indent
  " keywords: "end" + "record", "units"
  " where:    start of previous line
  " keyword:  ")"
  " where:    start of previous line
  " keyword:  without "<=" + ";" ending
  " where:    anywhere in previous line
  " keyword:  "=>" + ")" ending, provided current line does not begin with ")"
  " where:    anywhere in previous line
  " _note_:   indent allowed to leave this filter
  let m = 0
  if prevs =~? '^\s*end\s\+\%(record\|units\)\>'
    let m = 3
  elseif prevs =~ '^\s*)'
    let m = 1
  elseif prevs =~ s:NC.'\%(<=.*\)\@<!;'.s:ES || (curs !~ '^\s*)' && prevs =~ s:NC.'=>.*'.s:NC.')'.s:ES)
    let m = 2
  endif

  if m > 0
    let pn = prevnonblank(prevn - 1)
    let ps = getline(pn)
    while pn > 0
      let t = indent(pn)
      if ps !~ '^\s*--' && (t < ind || (t == ind && m == 3))
        " make sure one of these is true
        " keywords: variable + "<=" without ";" ending
        " where:    start of previous non-comment line
        " keywords: "procedure", "generic", "map", "port"
        " where:    anywhere in previous non-comment line
        " keyword:  "("
        " where:    start of previous non-comment line
        if m < 3 && ps !~? '^\s*\S\+\s*<=[^;]*'.s:ES
          if ps =~? s:NC.'\<\%(procedure\|generic\|map\|port\)\>' || ps =~ '^\s*('
            let ind = t
          endif
          break
        endif
        let ind = t
        if m > 1
          " find following previous non-comment line
          let ppn = prevnonblank(pn - 1)
          let pps = getline(ppn)
          while ppn > 0 && pps =~ '^\s*--'
            let ppn = prevnonblank(ppn - 1)
            let pps = getline(ppn)
          endwhile
          " indent:   follow
          " keyword:  "select"
          " where:    end of following previous non-comment line
          " keyword:  "type"
          " where:    start of following previous non-comment line
          if m == 2
            let s1 = s:NC.'\<select'.s:ES
            if ps !~? s1 && pps =~? s1
              let ind = indent(ppn)
            endif
          elseif m == 3
            let s1 = '^\s*type\>'
            if ps !~? s1 && pps =~? s1
              let ind = indent(ppn)
            endif
          endif
        endif
        break
      endif
      let pn = prevnonblank(pn - 1)
      let ps = getline(pn)
    endwhile
  endif

  " indent:   follow indent of previous opening statement, otherwise -sw
  " keyword:  "begin"
  " where:    anywhere in current line
  if curs =~? s:NC.'\<begin\>'
    " find previous opening statement of
    " keywords: "architecture", "block", "entity", "function", "generate", "procedure", "process"
    let s2 = s:NC.s:NE.'\<\%(architecture\|block\|entity\|function\|generate\|procedure\|process\)\>'

    let pn = prevnonblank(curn - 1)
    let ps = getline(pn)
    while pn > 0 && (ps =~ '^\s*--' || ps !~? s2)
      let pn = prevnonblank(pn - 1)
      let ps = getline(pn)

      if (ps =~? s:NC.'\<begin\>')
        return indent(pn) - shiftwidth()
      endif
    endwhile

    if (pn == 0)
      return ind - shiftwidth()
    else
      return indent(pn)
    endif
  endif

  " indent:   +sw if previous line is previous opening statement
  " keywords: "record", "units"
  " where:    anywhere in current line
  if curs =~? s:NC.s:NE.'\<\%(record\|units\)\>'
    " find previous opening statement of
    " keyword: "type"
    let s3 = s:NC.s:NE.'\<type\>'
    if curs !~? s3.'.*'.s:NC.'\<\%(record\|units\)\>.*'.s:ES && prevs =~? s3
      let ind = ind + shiftwidth()
    endif
    return ind
  endif

  " ****************************************************************************************
  " indent:   0
  " keywords: "architecture", "configuration", "entity", "library", "package"
  " where:    start of current line
  if curs =~? '^\s*\%(architecture\|configuration\|entity\|library\|package\)\>'
    return 0
  endif

  " indent:   maintain indent of previous opening statement
  " keyword:  "is"
  " where:    start of current line
  " find previous opening statement of
  " keywords: "architecture", "block", "configuration", "entity", "function", "package", "procedure", "process", "type"
  if curs =~? '^\s*\<is\>' && prevs =~? s:NC.s:NE.'\<\%(architecture\|block\|configuration\|entity\|function\|package\|procedure\|process\|type\)\>'
    return ind2
  endif

  " indent:   maintain indent of previous opening statement
  " keyword:  "then"
  " where:    start of current line
  " find previous opening statement of
  " keywords: "elsif", "if"
  if curs =~? '^\s*\<then\>' && prevs =~? s:NC.'\%(\<elsif\>\|'.s:NE.'\<if\>\)'
    return ind2
  endif

  " indent:   maintain indent of previous opening statement
  " keyword:  "generate"
  " where:    start of current line
  " find previous opening statement of
  " keywords: "for", "if"
  if curs =~? '^\s*\<generate\>' && prevs =~? s:NC.s:NE.'\%(\%(\<wait\s\+\)\@<!\<for\|\<if\)\>'
    return ind2
  endif

  " indent:   +sw
  " keywords: "block", "process"
  " removed:  "begin", "case", "elsif", "if", "loop", "record", "units", "while"
  " where:    anywhere in previous line
  if prevs =~? s:NC.s:NE.'\<\%(block\|process\)\>'
    return ind + shiftwidth()
  endif

  " indent:   +sw
  " keywords: "architecture", "configuration", "entity", "package"
  " removed:  "component", "for", "when", "with"
  " where:    start of previous line
  if prevs =~? '^\s*\%(architecture\|configuration\|entity\|package\)\>'
    return ind + shiftwidth()
  endif

  " indent:   +sw
  " keyword:  "select"
  " removed:  "generate", "is", "=>"
  " where:    end of previous line
  if prevs =~? s:NC.'\<select'.s:ES
    return ind + shiftwidth()
  endif

  " indent:   +sw
  " keyword:  "begin", "loop", "record", "units"
  " where:    anywhere in previous line
  " keyword:  "component", "else", "for"
  " where:    start of previous line
  " keyword:  "generate", "is", "then", "=>"
  " where:    end of previous line
  " _note_:   indent allowed to leave this filter
  if prevs =~? s:NC.'\%(\<begin\>\|'.s:NE.'\<\%(loop\|record\|units\)\>\)' || prevs =~? '^\s*\%(component\|else\|for\)\>' || prevs =~? s:NC.'\%('.s:NE.'\<generate\|\<\%(is\|then\)\|=>\)'.s:ES
    let ind = ind + shiftwidth()
  endif

  " ****************************************************************************************
  " indent:   -sw
  " keywords: "when", provided previous line does not begin with "when", does not end with "is"
  " where:    start of current line
  let s4 = '^\s*when\>'
  if curs =~? s4
    if prevs =~? s:NC.'\<is'.s:ES
      return ind
    elseif prevs !~? s4
      return ind - shiftwidth()
    else
      return ind2
    endif
  endif

  " indent:   -sw
  " keywords: "else", "elsif", "end" + "block", "for", "function", "generate", "if", "loop", "procedure", "process", "record", "units"
  " where:    start of current line
  let s5 = 'block\|for\|function\|generate\|if\|loop\|procedure\|process\|record\|units'
  if curs =~? '^\s*\%(else\|elsif\|end\s\+\%('.s5.'\)\)\>'
    if prevs =~? '^\s*\%(elsif\|'.s5.'\)'
      return ind
    else
      return ind - shiftwidth()
    endif
  endif

  " indent:   backtrace previous non-comment lines
  " keyword:  "end" + "case", "component"
  " where:    start of current line
  let m = 0
  if curs =~? '^\s*end\s\+case\>'
    let m = 1
  elseif curs =~? '^\s*end\s\+component\>'
    let m = 2
  endif

  if m > 0
    " find following previous non-comment line
    let pn = prevn
    let ps = getline(pn)
    while pn > 0
      if ps !~ '^\s*--'
        "indent:   -2sw
        "keywords: "end" + "case"
        "where:    start of previous non-comment line
        "indent:   -sw
        "keywords: "when"
        "where:    start of previous non-comment line
        "indent:   follow
        "keywords: "case"
        "where:    start of previous non-comment line
        if m == 1
          if ps =~? '^\s*end\s\+case\>'
            return indent(pn) - 2 * shiftwidth()
          elseif ps =~? '^\s*when\>'
            return indent(pn) - shiftwidth()
          elseif ps =~? '^\s*case\>'
            return indent(pn)
          endif
        "indent:   follow
        "keyword:  "component"
        "where:    start of previous non-comment line
        elseif m == 2
          if ps =~? '^\s*component\>'
            return indent(pn)
          endif
        endif
      endif
      let pn = prevnonblank(pn - 1)
      let ps = getline(pn)
    endwhile
    return ind - shiftwidth()
  endif

  " indent:   -sw
  " keyword:  ")"
  " where:    start of current line
  if curs =~ '^\s*)'
    return ind - shiftwidth()
  endif

  " indent:   0
  " keywords: "end" + "architecture", "configuration", "entity", "package"
  " where:    start of current line
  if curs =~? '^\s*end\s\+\%(architecture\|configuration\|entity\|package\)\>'
    return 0
  endif

  " indent:   -sw
  " keywords: "end" + identifier, ";"
  " where:    start of current line
  "if curs =~? '^\s*end\s\+\w\+\>'
  if curs =~? '^\s*end\%(\s\|;'.s:ES.'\)'
    return ind - shiftwidth()
  endif

  " ****************************************************************************************
  " indent:   maintain indent of previous opening statement
  " keywords: without "procedure", "generic", "map", "port" + ":" but not ":=" + "in", "out", "inout", "buffer", "linkage", variable & ":="
  " where:    start of current line
  if curs =~? '^\s*\%(\<\%(procedure\|generic\|map\|port\)\>.*\)\@<!\w\+\s*\w*\s*:[^=]\@=\s*\%(\%(in\|out\|inout\|buffer\|linkage\)\>\|\w\+\s\+:=\)'
    return ind2
  endif

  " ****************************************************************************************
  " indent:     maintain indent of previous opening statement, corner case which
  "             does not end in ;, but is part of a mapping
  " keywords:   without "procedure", "generic", "map", "port" + ":" but not ":=", never + ;$ and
  "             prevline without "procedure", "generic", "map", "port" + ":" but not ":=" + eventually ;$
  " where:      start of current line
  if curs =~? '^\s*\%(\<\%(procedure\|generic\|map\|port\)\>.*\)\@<!\w\+\s*\w*\s*:[^=].*[^;].*$'
    if prevs =~? '^\s*\%(\<\%(procedure\|generic\|map\|port\)\>.*\)\@<!\w\+\s*\w*\s*:[^=].*;.*$'
      return ind2
    endif
  endif

  " return leftover filtered indent
  return ind
endfunction
