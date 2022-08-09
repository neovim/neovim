" Vim indent file
" Language:    SystemVerilog
" Maintainer:  kocha <kocha.lsifrontend@gmail.com>
" Last Change: 05-Feb-2017 by Bilal Wasim
"              03-Aug-2022 Improved indent

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=SystemVerilogIndent()
setlocal indentkeys=!^F,o,O,0),0},=begin,=end,=join,=endcase,=join_any,=join_none
setlocal indentkeys+==endmodule,=endfunction,=endtask,=endspecify
setlocal indentkeys+==endclass,=endpackage,=endsequence,=endclocking
setlocal indentkeys+==endinterface,=endgroup,=endprogram,=endproperty,=endchecker
setlocal indentkeys+==`else,=`elsif,=`endif

let b:undo_indent = "setl inde< indk<"

" Only define the function once.
if exists("*SystemVerilogIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

let s:multiple_comment = 0
let s:open_statement = 0

function SystemVerilogIndent()

  if exists('b:systemverilog_indent_width')
    let offset = b:systemverilog_indent_width
  else
    let offset = shiftwidth()
  endif
  if exists('b:systemverilog_indent_modules')
    let indent_modules = offset
  else
    let indent_modules = 0
  endif

  if exists('b:systemverilog_indent_ifdef_off')
    let indent_ifdef = 0
  else
    let indent_ifdef = 1
  endif

  " Find a non-blank line above the current line.
  let lnum = prevnonblank(v:lnum - 1)

  " At the start of the file use zero indent.
  if lnum == 0
    return 0
  endif

  let lnum2 = prevnonblank(lnum - 1)
  let curr_line  = getline(v:lnum)
  let last_line  = getline(lnum)
  let last_line2 = getline(lnum2)
  let ind  = indent(lnum)
  let ind2 = indent(lnum - 1)
  " Define the condition of an open statement
  "   Exclude the match of //, /* or */
  let sv_openstat = '\(\<or\>\|\([*/]\)\@<![*(,{><+-/%^&|!=?:]\([*/]\)\@!\)'
  " Define the condition when the statement ends with a one-line comment
  let sv_comment = '\(//.*\|/\*.*\*/\s*\)'
  if exists('b:systemverilog_indent_verbose')
    let vverb_str = 'INDENT VERBOSE: '. v:lnum .":"
    let vverb = 1
  else
    let vverb = 0
  endif

  " Multiple-line comment count
  if curr_line =~ '^\s*/\*' && curr_line !~ '/\*.\{-}\*/'
    let s:multiple_comment += 1
    if vverb | echom vverb_str "Start of multiple-line commnt" | endif
  elseif curr_line =~ '\*/\s*$' && curr_line !~ '/\*.\{-}\*/'
    let s:multiple_comment -= 1
    if vverb | echom vverb_str "End of multiple-line commnt" | endif
    return ind
  endif
  " Maintain indentation during commenting.
  if s:multiple_comment > 0
    return ind
  endif

  " Indent after if/else/for/case/always/initial/specify/fork blocks
  if last_line =~ '^\s*\(end\)\=\s*`\@<!\<\(if\|else\)\>' ||
    \ last_line =~ '^\s*\<\(for\|while\|repeat\|case\%[[zx]]\|do\|foreach\|forever\|randcase\)\>' ||
    \ last_line =~ '^\s*\<\(always\|always_comb\|always_ff\|always_latch\)\>' ||
    \ last_line =~ '^\s*\<\(initial\|specify\|fork\|final\)\>'
    if last_line !~ '\(;\|\<end\>\|\*/\)\s*' . sv_comment . '*$' ||
      \ last_line =~ '\(//\|/\*\).*\(;\|\<end\>\)\s*' . sv_comment . '*$'
      let ind = ind + offset
      if vverb | echom vverb_str "Indent after a block statement." | endif
    endif
  " Indent after function/task/class/package/sequence/clocking/
  " interface/covergroup/property/checkerprogram blocks
  elseif last_line =~ '^\s*\<\(function\|task\|class\|package\)\>' ||
    \ last_line =~ '^\s*\<\(sequence\|clocking\|interface\)\>' ||
    \ last_line =~ '^\s*\(\w\+\s*:\)\=\s*\<covergroup\>' ||
    \ last_line =~ '^\s*\<\(property\|checker\|program\)\>' ||
    \ ( last_line =~ '^\s*\<virtual\>' && last_line =~ '\<\(function\|task\|class\|interface\)\>' ) ||
    \ ( last_line =~ '^\s*\<pure\>' &&  last_line =~ '\<virtual\>' && last_line =~ '\<\(function\|task\)\>' )
    if last_line !~ '\<end\>\s*' . sv_comment . '*$' ||
      \ last_line =~ '\(//\|/\*\).*\(;\|\<end\>\)\s*' . sv_comment . '*$'
      let ind = ind + offset
      if vverb
        echom vverb_str "Indent after function/task/class block statement."
      endif
    endif

  " Indent after module/function/task/specify/fork blocks
  elseif last_line =~ '^\s*\(\<extern\>\s*\)\=\<module\>'
    let ind = ind + indent_modules
    if vverb && indent_modules
      echom vverb_str "Indent after module statement."
    endif
    if last_line =~ '[(,]\s*' . sv_comment . '*$' &&
      \ last_line !~ '\(//\|/\*\).*[(,]\s*' . sv_comment . '*$'
      let ind = ind + offset
      if vverb
        echom vverb_str "Indent after a multiple-line module statement."
      endif
    endif

  " Indent after a 'begin' statement
  elseif last_line =~ '\(\<begin\>\)\(\s*:\s*\w\+\)*' . sv_comment . '*$' &&
    \ last_line !~ '\(//\|/\*\).*\(\<begin\>\)' &&
    \ ( last_line2 !~ sv_openstat . '\s*' . sv_comment . '*$' ||
    \ last_line2 =~ '^\s*[^=!]\+\s*:\s*' . sv_comment . '*$' )
    let ind = ind + offset
    if vverb | echom vverb_str "Indent after begin statement." | endif

  " Indent after a '{' or a '('
  elseif last_line =~ '[{(]' . sv_comment . '*$' &&
    \ last_line !~ '\(//\|/\*\).*[{(]' &&
    \ ( last_line2 !~ sv_openstat . '\s*' . sv_comment . '*$' ||
    \ last_line2 =~ '^\s*[^=!]\+\s*:\s*' . sv_comment . '*$' )
    let ind = ind + offset
    if vverb | echom vverb_str "Indent after begin statement." | endif

  " Ignore de-indent for the end of one-line block
  elseif ( last_line !~ '\<begin\>' ||
    \ last_line =~ '\(//\|/\*\).*\<begin\>' ) &&
    \ last_line2 =~ '\<\(`\@<!if\|`\@<!else\|for\|always\|initial\|do\|foreach\|forever\|final\)\>.*' .
      \ sv_comment . '*$' &&
    \ last_line2 !~ '\(//\|/\*\).*\<\(`\@<!if\|`\@<!else\|for\|always\|initial\|do\|foreach\|forever\|final\)\>' &&
    \ last_line2 !~ sv_openstat . '\s*' . sv_comment . '*$' &&
    \ ( last_line2 !~ '\<begin\>' ||
    \ last_line2 =~ '\(//\|/\*\).*\<begin\>' ) &&
    \ last_line2 =~ ')*\s*;\s*' . sv_comment . '*$'
    if vverb
      echom vverb_str "Ignore de-indent after the end of one-line statement."
    endif

  " De-indent for the end of one-line block
  elseif ( last_line !~ '\<begin\>' ||
    \ last_line =~ '\(//\|/\*\).*\<begin\>' ) &&
    \ last_line2 =~ '\<\(`\@<!if\|`\@<!else\|for\|always\|initial\|do\|foreach\|forever\|final\)\>.*' .
      \ sv_comment . '*$' &&
    \ last_line2 !~ '\(//\|/\*\).*\<\(`\@<!if\|`\@<!else\|for\|always\|initial\|do\|foreach\|forever\|final\)\>' &&
    \ last_line2 !~ sv_openstat . '\s*' . sv_comment . '*$' &&
    \ last_line2 !~ '\(;\|\<end\>\|\*/\)\s*' . sv_comment . '*$' &&
    \ ( last_line2 !~ '\<begin\>' ||
    \ last_line2 =~ '\(//\|/\*\).*\<begin\>' )
    let ind = ind - offset
    if vverb
      echom vverb_str "De-indent after the end of one-line statement."
    endif

  " Multiple-line statement (including case statement)
  " Open statement
  "   Ident the first open line
  elseif  last_line =~ sv_openstat . '\s*' . sv_comment . '*$' &&
   \ last_line !~ '\(//\|/\*\).*' . sv_openstat . '\s*$' &&
   \ last_line2 !~ sv_openstat . '\s*' . sv_comment . '*$'
    let ind = ind + offset
    let s:open_statement = 1
    if vverb | echom vverb_str "Indent after an open statement." | endif

  " `ifdef or `ifndef or `elsif or `else
  elseif last_line =~ '^\s*`\<\(ifn\?def\|elsif\|else\)\>' && indent_ifdef
    let ind = ind + offset
    if vverb
      echom vverb_str "Indent after a `ifdef or `ifndef or `elsif or `else statement."
    endif

  endif

  " Re-indent current line

  " De-indent on the end of the block
  " join/end/endcase/endfunction/endtask/endspecify
  if curr_line =~ '^\s*\<\(join\|join_any\|join_none\|\|end\|endcase\)\>' ||
      \ curr_line =~ '^\s*\<\(endfunction\|endtask\|endspecify\|endclass\)\>' ||
      \ curr_line =~ '^\s*\<\(endpackage\|endsequence\|endclocking\|endinterface\)\>' ||
      \ curr_line =~ '^\s*\<\(endgroup\|endproperty\|endchecker\|endprogram\)\>'
    let ind = ind - offset
    if vverb | echom vverb_str "De-indent the end of a block." | endif
    if s:open_statement == 1
      let ind = ind - offset
      let s:open_statement = 0
      if vverb | echom vverb_str "De-indent the close statement." | endif
    endif
  elseif curr_line =~ '^\s*\<endmodule\>'
    let ind = ind - indent_modules
    if vverb && indent_modules
      echom vverb_str "De-indent the end of a module."
    endif

  " De-indent on a stand-alone 'begin'
  elseif curr_line =~ '^\s*\<begin\>'
    if last_line !~ '^\s*\<\(function\|task\|specify\|module\|class\|package\)\>' ||
      \ last_line !~ '^\s*\<\(sequence\|clocking\|interface\|covergroup\)\>' ||
      \ last_line !~ '^\s*\<\(property\|checker\|program\)\>' &&
      \ last_line !~ '^\s*\()*\s*;\|)\+\)\s*' . sv_comment . '*$' &&
      \ ( last_line =~
      \ '\<\(`\@<!if\|`\@<!else\|for\|case\%[[zx]]\|always\|initial\|do\|foreach\|forever\|randcase\|final\)\>' ||
      \ last_line =~ ')\s*' . sv_comment . '*$' ||
      \ last_line =~ sv_openstat . '\s*' . sv_comment . '*$' )
      let ind = ind - offset
      if vverb
        echom vverb_str "De-indent a stand alone begin statement."
      endif
      if s:open_statement == 1
        let ind = ind - offset
        let s:open_statement = 0
        if vverb | echom vverb_str "De-indent the close statement." | endif
      endif
    endif

  " " Close statement
  " "   De-indent for an optional close parenthesis and a semicolon, and only
  " "   if there exists precedent non-whitespace char
  " elseif last_line =~ ')*\s*;\s*' . sv_comment . '*$' &&
  "   \ last_line !~ '^\s*)*\s*;\s*' . sv_comment . '*$' &&
  "   \ last_line !~ '\(//\|/\*\).*\S)*\s*;\s*' . sv_comment . '*$' &&
  "   \ ( last_line2 =~ sv_openstat . '\s*' . sv_comment . '*$' &&
  "   \ last_line2 !~ ';\s*//.*$') &&
  "   \ last_line2 !~ '^\s*' . sv_comment . '$'
  "   let ind = ind - offset
  "   if vverb | echom vverb_str "De-indent after a close statement." | endif

  " " De-indent after the end of multiple-line statement
  " elseif curr_line =~ '^\s*)' &&
  "  \ ( last_line =~ sv_openstat . '\s*' . sv_comment . '*$' ||
  "  \ last_line !~ sv_openstat . '\s*' . sv_comment . '*$' &&
  "  \ last_line2 =~ sv_openstat . '\s*' . sv_comment . '*$' )
  "   let ind = ind - offset
  "   if vverb
  "     echom vverb_str "De-indent the end of a multiple statement."
  "   endif

  " De-indent `elsif or `else or `endif
  elseif curr_line =~ '^\s*`\<\(elsif\|else\|endif\)\>' && indent_ifdef
    let ind = ind - offset
    if vverb | echom vverb_str "De-indent `elsif or `else or `endif statement." | endif
    if b:systemverilog_open_statement == 1
      let ind = ind - offset
      let b:systemverilog_open_statement = 0
      if vverb | echom vverb_str "De-indent the open statement." | endif
    endif
  endif

  " Return the indentation
  return ind
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim:sw=2

