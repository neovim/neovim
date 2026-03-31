" Language:    OCaml
" Maintainer:  David Baelde        <firstname.name@ens-lyon.org>
"              Mike Leary          <leary@nwlink.com>
"              Markus Mottl        <markus.mottl@gmail.com>
"              Pierre Vittet       <pierre-vittet@pvittet.com>
"              Stefano Zacchiroli  <zack@bononia.it>
"              Vincent Aravantinos <firstname.name@imag.fr>
"              Riley Bruins <ribru17@gmail.com> ('commentstring')
" URL:         https://github.com/ocaml/vim-ocaml
" Last Change:
"              2013 Oct 27 - Added commentstring (MM)
"              2013 Jul 26 - load default compiler settings (MM)
"              2013 Jul 24 - removed superfluous efm-setting (MM)
"              2013 Jul 22 - applied fixes supplied by Hirotaka Hamada (MM)
"              2024 May 23 - added space in commentstring (RB)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin=1

" Use standard compiler settings unless user wants otherwise
if !exists("current_compiler")
  :compiler ocaml
endif

" some macro
if exists('*fnameescape')
  function! s:Fnameescape(s)
    return fnameescape(a:s)
  endfun
else
  function! s:Fnameescape(s)
    return escape(a:s," \t\n*?[{`$\\%#'\"|!<")
  endfun
endif

" Error handling -- helps moving where the compiler wants you to go
let s:cposet=&cpoptions
set cpo&vim

" Comment string
setlocal comments=sr:(*\ ,mb:\ ,ex:*)
setlocal comments^=sr:(**,mb:\ \ ,ex:*)
setlocal commentstring=(*\ %s\ *)

" Add mappings, unless the user didn't want this.
if !exists("no_plugin_maps") && !exists("no_ocaml_maps")
  " (un)commenting
  if !hasmapto('<Plug>Comment')
    nmap <buffer> <LocalLeader>c <Plug>LUncomOn
    xmap <buffer> <LocalLeader>c <Plug>BUncomOn
    nmap <buffer> <LocalLeader>C <Plug>LUncomOff
    xmap <buffer> <LocalLeader>C <Plug>BUncomOff
  endif

  nnoremap <buffer> <Plug>LUncomOn gI(* <End> *)<ESC>
  nnoremap <buffer> <Plug>LUncomOff :s/^(\* \(.*\) \*)/\1/<CR>:noh<CR>
  xnoremap <buffer> <Plug>BUncomOn <ESC>:'<,'><CR>`<O<ESC>0i(*<ESC>`>o<ESC>0i*)<ESC>`<
  xnoremap <buffer> <Plug>BUncomOff <ESC>:'<,'><CR>`<dd`>dd`<

  nmap <buffer> <LocalLeader>s <Plug>OCamlSwitchEdit
  nmap <buffer> <LocalLeader>S <Plug>OCamlSwitchNewWin

  nmap <buffer> <LocalLeader>t <Plug>OCamlPrintType
  xmap <buffer> <LocalLeader>t <Plug>OCamlPrintType
endif

" Let % jump between structure elements (due to Issac Trotts)
let b:mw =         '\<let\>:\<and\>:\(\<in\>\|;;\)'
let b:mw = b:mw . ',\<if\>:\<then\>:\<else\>'
let b:mw = b:mw . ',\<\(for\|while\)\>:\<do\>:\<done\>'
let b:mw = b:mw . ',\<\(object\|sig\|struct\|begin\)\>:\<end\>'
let b:mw = b:mw . ',\<\(match\|try\)\>:\<with\>'
let b:match_words = b:mw

let b:match_ignorecase=0

function! s:OcpGrep(bang,args) abort
  let grepprg = &l:grepprg
  let grepformat = &l:grepformat
  let shellpipe = &shellpipe
  try
    let &l:grepprg = "ocp-grep -c never"
    setlocal grepformat=%f:%l:%m
    if &shellpipe ==# '2>&1| tee' || &shellpipe ==# '|& tee'
      let &shellpipe = "| tee"
    endif
    execute 'grep! '.a:args
    if empty(a:bang) && !empty(getqflist())
      return 'cfirst'
    else
      return ''
    endif
  finally
    let &l:grepprg = grepprg
    let &l:grepformat = grepformat
    let &shellpipe = shellpipe
  endtry
endfunction
command! -bar -bang -complete=file -nargs=+ Ocpgrep exe s:OcpGrep(<q-bang>, <q-args>)

" switching between interfaces (.mli) and implementations (.ml)
if !exists("g:did_ocaml_switch")
  let g:did_ocaml_switch = 1
  nnoremap <Plug>OCamlSwitchEdit :<C-u>call OCaml_switch(0)<CR>
  nnoremap <Plug>OCamlSwitchNewWin :<C-u>call OCaml_switch(1)<CR>
  fun OCaml_switch(newwin)
    if (match(bufname(""), "\\.mli$") >= 0)
      let fname = s:Fnameescape(substitute(bufname(""), "\\.mli$", ".ml", ""))
      if (a:newwin == 1)
        exec "new " . fname
      else
        exec "arge " . fname
      endif
    elseif (match(bufname(""), "\\.ml$") >= 0)
      let fname = s:Fnameescape(bufname("")) . "i"
      if (a:newwin == 1)
        exec "new " . fname
      else
        exec "arge " . fname
      endif
    endif
  endfun
endif

" Folding support

" Get the modeline because folding depends on indentation
let lnum = search('^\s*(\*:o\?caml:', 'n')
let s:modeline = lnum? getline(lnum): ""

" Get the indentation params
let s:m = matchstr(s:modeline,'default\s*=\s*\d\+')
if s:m != ""
  let s:idef = matchstr(s:m,'\d\+')
elseif exists("g:omlet_indent")
  let s:idef = g:omlet_indent
else
  let s:idef = 2
endif
let s:m = matchstr(s:modeline,'struct\s*=\s*\d\+')
if s:m != ""
  let s:i = matchstr(s:m,'\d\+')
elseif exists("g:omlet_indent_struct")
  let s:i = g:omlet_indent_struct
else
  let s:i = s:idef
endif

" Set the folding method
if exists("g:ocaml_folding")
  setlocal foldmethod=expr
  setlocal foldexpr=OMLetFoldLevel(v:lnum)
endif

let b:undo_ftplugin = "setlocal efm< foldmethod< foldexpr<"
	\ . "| unlet! b:mw b:match_words b:match_ignorecase"


" - Only definitions below, executed once -------------------------------------

if exists("*OMLetFoldLevel")
  let &cpoptions = s:cposet
  unlet s:cposet
  finish
endif

function s:topindent(lnum)
  let l = a:lnum
  while l > 0
    if getline(l) =~ '\s*\%(\<struct\>\|\<sig\>\|\<object\>\)'
      return indent(l)
    endif
    let l = l-1
  endwhile
  return -s:i
endfunction

function OMLetFoldLevel(l)

  " This is for not merging blank lines around folds to them
  if getline(a:l) !~ '\S'
    return -1
  endif

  " We start folds for modules, classes, and every toplevel definition
  if getline(a:l) =~ '^\s*\%(\<val\>\|\<module\>\|\<class\>\|\<type\>\|\<method\>\|\<initializer\>\|\<inherit\>\|\<exception\>\|\<external\>\)'
    exe 'return ">' (indent(a:l)/s:i)+1 '"'
  endif

  " Toplevel let are detected thanks to the indentation
  if getline(a:l) =~ '^\s*let\>' && indent(a:l) == s:i+s:topindent(a:l)
    exe 'return ">' (indent(a:l)/s:i)+1 '"'
  endif

  " We close fold on end which are associated to struct, sig or object.
  " We use syntax information to do that.
  if getline(a:l) =~ '^\s*end\>' && synIDattr(synID(a:l, indent(a:l)+1, 0), "name") != "ocamlKeyword"
    return (indent(a:l)/s:i)+1
  endif

  " Folds end on ;;
  if getline(a:l) =~ '^\s*;;'
    exe 'return "<' (indent(a:l)/s:i)+1 '"'
  endif

  " Comments around folds aren't merged to them.
  if synIDattr(synID(a:l, indent(a:l)+1, 0), "name") == "ocamlComment"
    return -1
  endif

  return '='
endfunction

" Vim support for OCaml .annot files
"
" Last Change: 2007 Jul 17
" Maintainer:  Vincent Aravantinos <vincent.aravantinos@gmail.com>
" License:     public domain
"
" Originally inspired by 'ocaml-dtypes.vim' by Stefano Zacchiroli.
" The source code is quite radically different for we not use python anymore.
" However this plugin should have the exact same behaviour, that's why the
" following lines are the quite exact copy of Stefano's original plugin :
"
" <<
" Executing Ocaml_print_type(<mode>) function will display in the Vim bottom
" line(s) the type of an ocaml value getting it from the corresponding .annot
" file (if any).  If Vim is in visual mode, <mode> should be "visual" and the
" selected ocaml value correspond to the highlighted text, otherwise (<mode>
" can be anything else) it corresponds to the literal found at the current
" cursor position.
"
" Typing '<LocalLeader>t' (LocalLeader defaults to '\', see :h LocalLeader)
" will cause " Ocaml_print_type function to be invoked with the right
" argument depending on the current mode (visual or not).
" >>
"
" If you find something not matching this behaviour, please signal it.
"
" Differences are:
"   - no need for python support
"     + plus : more portable
"     + minus: no more lazy parsing, it looks very fast however
"
"   - ocamlbuild support, ie.
"     + the plugin finds the _build directory and looks for the
"       corresponding file inside;
"     + if the user decides to change the name of the _build directory thanks
"       to the '-build-dir' option of ocamlbuild, the plugin will manage in
"       most cases to find it out (most cases = if the source file has a unique
"       name among your whole project);
"     + if ocamlbuild is not used, the usual behaviour holds; ie. the .annot
"       file should be in the same directory as the source file;
"     + for vim plugin programmers:
"       the variable 'b:_build_dir' contains the inferred path to the build
"       directory, even if this one is not named '_build'.
"
" Bonus :
"   - latin1 accents are handled
"   - lists are handled, even on multiple lines, you don't need the visual mode
"     (the cursor must be on the first bracket)
"   - parenthesized expressions, arrays, and structures (ie. '(...)', '[|...|]',
"     and '{...}') are handled the same way

  " Copied from Stefano's original plugin :
  " <<
  "      .annot ocaml file representation
  "
  "      File format (copied verbatim from caml-types.el)
  "
  "      file ::= block *
  "      block ::= position <SP> position <LF> annotation *
  "      position ::= filename <SP> num <SP> num <SP> num
  "      annotation ::= keyword open-paren <LF> <SP> <SP> data <LF> close-paren
  "
  "      <SP> is a space character (ASCII 0x20)
  "      <LF> is a line-feed character (ASCII 0x0A)
  "      num is a sequence of decimal digits
  "      filename is a string with the lexical conventions of O'Caml
  "      open-paren is an open parenthesis (ASCII 0x28)
  "      close-paren is a closed parenthesis (ASCII 0x29)
  "      data is any sequence of characters where <LF> is always followed by
  "           at least two space characters.
  "
  "      - in each block, the two positions are respectively the start and the
  "        end of the range described by the block.
  "      - in a position, the filename is the name of the file, the first num
  "        is the line number, the second num is the offset of the beginning
  "        of the line, the third num is the offset of the position itself.
  "      - the char number within the line is the difference between the third
  "        and second nums.
  "
  "      For the moment, the only possible keyword is \"type\"."
  " >>


" 1. Finding the annotation file even if we use ocamlbuild

    " In:  two strings representing paths
    " Out: one string representing the common prefix between the two paths
  function! s:Find_common_path (p1,p2)
    let temp = a:p2
    while matchstr(a:p1,temp) == ''
      let temp = substitute(temp,'/[^/]*$','','')
    endwhile
    return temp
  endfun

    " After call:
    "
    "  Following information have been put in s:annot_file_list, using
    "  annot_file_name name as key:
    " - annot_file_path :
    "                       path to the .annot file corresponding to the
    "                       source file (dealing with ocamlbuild stuff)
    " - _build_path:
    "                       path to the build directory even if this one is
    "                       not named '_build'
    " - date_of_last annot:
    "                       Set to 0 until we load the file. It contains the
    "                       date at which the file has been loaded.
  function! s:Locate_annotation()
    let annot_file_name = s:Fnameescape(expand('%:t:r')).'.annot'
    if !exists ("s:annot_file_list[annot_file_name]")
      silent exe 'cd' s:Fnameescape(expand('%:p:h'))
      " 1st case : the annot file is in the same directory as the buffer (no ocamlbuild)
      let annot_file_path = findfile(annot_file_name,'.')
      if annot_file_path != ''
        let annot_file_path = getcwd().'/'.annot_file_path
        let _build_path = ''
      else
        " 2nd case : the buffer and the _build directory are in the same directory
        "      ..
        "     /  \
        "    /    \
        " _build  .ml
        "
        let _build_path = finddir('_build','.')
        if _build_path != ''
          let _build_path = getcwd().'/'._build_path
          let annot_file_path           = findfile(annot_file_name,'_build')
          if annot_file_path != ''
            let annot_file_path = getcwd().'/'.annot_file_path
          endif
        else
          " 3rd case : the _build directory is in a directory higher in the file hierarchy
          "            (it can't be deeper by ocamlbuild requirements)
          "      ..
          "     /  \
          "    /    \
          " _build  ...
          "           \
          "            \
          "           .ml
          "
          let _build_path = finddir('_build',';')
          if _build_path != ''
            let project_path                = substitute(_build_path,'/_build$','','')
            let path_relative_to_project    = s:Fnameescape(substitute(expand('%:p:h'),project_path.'/','',''))
            let annot_file_path           = findfile(annot_file_name,project_path.'/_build/'.path_relative_to_project)
          else
            let annot_file_path = findfile(annot_file_name,'**')
            "4th case : what if the user decided to change the name of the _build directory ?
            "           -> we relax the constraints, it should work in most cases
            if annot_file_path != ''
              " 4a. we suppose the renamed _build directory is in the current directory
              let _build_path = matchstr(annot_file_path,'^[^/]*')
              if annot_file_path != ''
                let annot_file_path = getcwd().'/'.annot_file_path
                let _build_path     = getcwd().'/'._build_path
              endif
            else
              let annot_file_name = ''
              "(Pierre Vittet: I have commented 4b because this was crashing
              "my vim (it produced infinite loop))
              "
              " 4b. anarchy : the renamed _build directory may be higher in the hierarchy
              " this will work if the file for which we are looking annotations has a unique name in the whole project
              " if this is not the case, it may still work, but no warranty here
              "let annot_file_path = findfile(annot_file_name,'**;')
              "let project_path      = s:Find_common_path(annot_file_path,expand('%:p:h'))
              "let _build_path       = matchstr(annot_file_path,project_path.'/[^/]*')
            endif
          endif
        endif
      endif

      if annot_file_path == ''
        throw 'E484: no annotation file found'
      endif

      silent exe 'cd' '-'
      let s:annot_file_list[annot_file_name]= [annot_file_path, _build_path, 0]
    endif
  endfun

  " This variable contains a dictionary of lists. Each element of the dictionary
  " represents an annotation system. An annotation system is a list with:
  " - annotation file name as its key
  " - annotation file path as first element of the contained list
  " - build path as second element of the contained list
  " - annot_file_last_mod (contain the date of .annot file) as third element
  let s:annot_file_list = {}

" 2. Finding the type information in the annotation file

  " a. The annotation file is opened in vim as a buffer that
  " should be (almost) invisible to the user.

      " After call:
      " The current buffer is now the one containing the .annot file.
      " We manage to keep all this hidden to the user's eye.
    function! s:Enter_annotation_buffer(annot_file_path)
      let s:current_pos = getpos('.')
      let s:current_hidden = &l:hidden
      set hidden
      let s:current_buf = bufname('%')
      if bufloaded(a:annot_file_path)
        silent exe 'keepj keepalt' 'buffer' s:Fnameescape(a:annot_file_path)
      else
        silent exe 'keepj keepalt' 'view' s:Fnameescape(a:annot_file_path)
      endif
      call setpos(".", [0, 0 , 0 , 0])
    endfun

      " After call:
      "   The original buffer has been restored in the exact same state as before.
    function! s:Exit_annotation_buffer()
      silent exe 'keepj keepalt' 'buffer' s:Fnameescape(s:current_buf)
      let &l:hidden = s:current_hidden
      call setpos('.',s:current_pos)
    endfun

      " After call:
      "   The annot file is loaded and assigned to a buffer.
      "   This also handles the modification date of the .annot file, eg. after a
      "   compilation (return an updated annot_file_list).
    function! s:Load_annotation(annot_file_name)
      let annot = s:annot_file_list[a:annot_file_name]
      let annot_file_path = annot[0]
      let annot_file_last_mod = 0
      if exists("annot[2]")
        let annot_file_last_mod = annot[2]
      endif
      if bufloaded(annot_file_path) && annot_file_last_mod < getftime(annot_file_path)
        " if there is a more recent file
        let nr = bufnr(annot_file_path)
        silent exe 'keepj keepalt' 'bunload' nr
      endif
      if !bufloaded(annot_file_path)
        call s:Enter_annotation_buffer(annot_file_path)
        setlocal nobuflisted
        setlocal bufhidden=hide
        setlocal noswapfile
        setlocal buftype=nowrite
        call s:Exit_annotation_buffer()
        let annot[2] = getftime(annot_file_path)
        " List updated with the new date
        let s:annot_file_list[a:annot_file_name] = annot
      endif
    endfun

  "b. 'search' and 'match' work to find the type information

      "In:  - lin1,col1: position of expression first char
      "     - lin2,col2: position of expression last char
      "Out: - the pattern to be looked for to find the block
      " Must be called in the source buffer (use of line2byte)
    function! s:Block_pattern(lin1,lin2,col1,col2)
      let start_num1 = a:lin1
      let start_num2 = line2byte(a:lin1) - 1
      let start_num3 = start_num2 + a:col1
      let path       = '"\(\\"\|[^"]\)\+"'
      let start_pos  = path.' '.start_num1.' '.start_num2.' '.start_num3
      let end_num1   = a:lin2
      let end_num2   = line2byte(a:lin2) - 1
      let end_num3   = end_num2 + a:col2
      let end_pos    = path.' '.end_num1.' '.end_num2.' '.end_num3
      return '^'.start_pos.' '.end_pos."$"
      " rq: the '^' here is not totally correct regarding the annot file "grammar"
      " but currently the annotation file respects this, and it's a little bit faster with the '^';
      " can be removed safely.
    endfun

      "In: (the cursor position should be at the start of an annotation)
      "Out: the type information
      " Must be called in the annotation buffer (use of search)
    function! s:Match_data()
      " rq: idem as previously, in the following, the '^' at start of patterns is not necessary
      keepj while search('^type($','ce',line(".")) == 0
        keepj if search('^.\{-}($','e') == 0
          throw "no_annotation"
        endif
        keepj if searchpair('(','',')') == 0
          throw "malformed_annot_file"
        endif
      endwhile
      let begin = line(".") + 1
      keepj if searchpair('(','',')') == 0
        throw "malformed_annot_file"
      endif
      let end = line(".") - 1
      return join(getline(begin,end),"\n")
    endfun

      "In:  the pattern to look for in order to match the block
      "Out: the type information (calls s:Match_data)
      " Should be called in the annotation buffer
    function! s:Extract_type_data(block_pattern, annot_file_name)
      let annot_file_path = s:annot_file_list[a:annot_file_name][0]
      call s:Enter_annotation_buffer(annot_file_path)
      try
        if search(a:block_pattern,'e') == 0
          throw "no_annotation"
        endif
        call cursor(line(".") + 1,1)
        let annotation = s:Match_data()
      finally
        call s:Exit_annotation_buffer()
      endtry
      return annotation
    endfun

  "c. link this stuff with what the user wants
  " ie. get the expression selected/under the cursor

    let s:ocaml_word_char = '\w|[\xc0-\xff]|'''

      "In:  the current mode (eg. "visual", "normal", etc.)
      "Out: the borders of the expression we are looking for the type
    function! s:Match_borders(mode)
      if a:mode == "visual"
        let cur = getpos(".")
        normal `<
        let col1 = col(".")
        let lin1 = line(".")
        normal `>
        let col2 = col(".")
        let lin2 = line(".")
        call cursor(cur[1],cur[2])
        return [lin1,lin2,col1-1,col2]
      else
        let cursor_line = line(".")
        let cursor_col  = col(".")
        let line = getline('.')
        if line[cursor_col-1:cursor_col] == '[|'
          let [lin2,col2] = searchpairpos('\[|','','|\]','n')
          return [cursor_line,lin2,cursor_col-1,col2+1]
        elseif     line[cursor_col-1] == '['
          let [lin2,col2] = searchpairpos('\[','','\]','n')
          return [cursor_line,lin2,cursor_col-1,col2]
        elseif line[cursor_col-1] == '('
          let [lin2,col2] = searchpairpos('(','',')','n')
          return [cursor_line,lin2,cursor_col-1,col2]
        elseif line[cursor_col-1] == '{'
          let [lin2,col2] = searchpairpos('{','','}','n')
          return [cursor_line,lin2,cursor_col-1,col2]
        else
          let [lin1,col1] = searchpos('\v%('.s:ocaml_word_char.'|\.)*','ncb')
          let [lin2,col2] = searchpos('\v%('.s:ocaml_word_char.'|\.)*','nce')
          if col1 == 0 || col2 == 0
            throw "no_expression"
          endif
          return [cursor_line,cursor_line,col1-1,col2]
        endif
      endif
    endfun

      "In:  the current mode (eg. "visual", "normal", etc.)
      "Out: the type information (calls s:Extract_type_data)
    function! s:Get_type(mode, annot_file_name)
      let [lin1,lin2,col1,col2] = s:Match_borders(a:mode)
      return s:Extract_type_data(s:Block_pattern(lin1,lin2,col1,col2), a:annot_file_name)
    endfun

      "In: A string destined to be printed in the 'echo buffer'. It has line
      "break and 2 space at each line beginning.
      "Out: A string destined to be yanked, without space and double space.
    function s:unformat_ocaml_type(res)
      "Remove end of line.
      let res = substitute (a:res, "\n", "", "g" )
      "remove double space
      let res =substitute(res , "  ", " ", "g")
      "remove space at beginning of string.
      let res = substitute(res, "^ *", "", "g")
      return res
    endfunction

  "d. main
      "In:         the current mode (eg. "visual", "normal", etc.)
      "After call: the type information is displayed
    if !exists("*Ocaml_get_type")
      function Ocaml_get_type(mode)
        let annot_file_name = s:Fnameescape(expand('%:t:r')).'.annot'
        call s:Locate_annotation()
        call s:Load_annotation(annot_file_name)
        let res = s:Get_type(a:mode, annot_file_name)
        " Copy result in the unnamed buffer
        let @" = s:unformat_ocaml_type(res)
        return res
      endfun
    endif

    if !exists("*Ocaml_get_type_or_not")
      function Ocaml_get_type_or_not(mode)
        let t=reltime()
        try
          let res = Ocaml_get_type(a:mode)
          return res
        catch
          return ""
        endtry
      endfun
    endif

    if !exists("*Ocaml_print_type")
      function Ocaml_print_type(mode)
        if expand("%:e") == "mli"
          echohl ErrorMsg | echo "No annotations for interface (.mli) files" | echohl None
          return
        endif
        try
          echo Ocaml_get_type(a:mode)
        catch /E484:/
          echohl ErrorMsg | echo "No type annotations (.annot) file found" | echohl None
        catch /no_expression/
          echohl ErrorMsg | echo "No expression found under the cursor" | echohl None
        catch /no_annotation/
          echohl ErrorMsg | echo "No type annotation found for the given text" | echohl None
        catch /malformed_annot_file/
          echohl ErrorMsg | echo "Malformed .annot file" | echohl None
        endtry
      endfun
    endif

" Maps
  nnoremap <silent> <Plug>OCamlPrintType :<C-U>call Ocaml_print_type("normal")<CR>
  xnoremap <silent> <Plug>OCamlPrintType :<C-U>call Ocaml_print_type("visual")<CR>`<

let &cpoptions = s:cposet
unlet s:cposet

" vim:sw=2 fdm=indent
