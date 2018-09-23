" Script to generate testdir/opt_test.vim from option.c

set cpo=&vim

" Only do this when build with the +eval feature.
if 1

set nomore

" The terminal size is restored at the end.
" Clear out t_WS, we don't want to resize the actual terminal.
let script = [
      \ 'let save_columns = &columns',
      \ 'let save_lines = &lines',
      \ 'let save_term = &term',
      \ 'set t_WS=',
      \ ]

/#define p_term
let end = line('.')

" Two lists with values: values that work and values that fail.
" When not listed, "othernum" or "otherstring" is used.
let test_values = {
      \ 'cmdheight': [[1, 2, 10], [-1, 0]],
      \ 'cmdwinheight': [[1, 2, 10], [-1, 0]],
      \ 'columns': [[12, 80], [-1, 0, 10]],
      \ 'conceallevel': [[0, 1, 2, 3], [-1, 4, 99]],
      \ 'foldcolumn': [[0, 1, 4, 12], [-1, 13, 999]],
      \ 'helpheight': [[0, 10, 100], [-1]],
      \ 'history': [[0, 1, 100], [-1, 10001]],
      \ 'iminsert': [[0, 1], [-1, 3, 999]],
      \ 'imsearch': [[-1, 0, 1], [-2, 3, 999]],
      \ 'lines': [[2, 24], [-1, 0, 1]],
      \ 'linespace': [[0, 2, 4], ['']],
      \ 'numberwidth': [[1, 4, 8, 10], [-1, 0, 11]],
      \ 'regexpengine': [[0, 1, 2], [-1, 3, 999]],
      \ 'report': [[0, 1, 2, 9999], [-1]],
      \ 'scroll': [[0, 1, 2, 20], [-1]],
      \ 'scrolljump': [[-50, -1, 0, 1, 2, 20], [999]],
      \ 'scrolloff': [[0, 1, 2, 20], [-1]],
      \ 'shiftwidth': [[0, 1, 8, 999], [-1]],
      \ 'sidescroll': [[0, 1, 8, 999], [-1]],
      \ 'sidescrolloff': [[0, 1, 8, 999], [-1]],
      \ 'tabstop': [[1, 4, 8, 12], [-1, 0]],
      \ 'textwidth': [[0, 1, 8, 99], [-1]],
      \ 'timeoutlen': [[0, 8, 99999], [-1]],
      \ 'titlelen': [[0, 1, 8, 9999], [-1]],
      \ 'updatecount': [[0, 1, 8, 9999], [-1]],
      \ 'updatetime': [[0, 1, 8, 9999], [-1]],
      \ 'verbose': [[-1, 0, 1, 8, 9999], []],
      \ 'wildcharm': [[-1, 0, 100], []],
      \ 'winheight': [[1, 10, 999], [-1, 0]],
      \ 'winminheight': [[0, 1], [-1]],
      \ 'winminwidth': [[0, 1, 10], [-1]],
      \ 'winwidth': [[1, 10, 999], [-1, 0]],
      \
      \ 'ambiwidth': [['', 'single'], ['xxx']],
      \ 'background': [['', 'light', 'dark'], ['xxx']],
      \ 'backspace': [[0, 2, '', 'eol', 'eol,start'], ['xxx']],
      \ 'backupcopy': [['yes', 'auto'], ['', 'xxx', 'yes,no']],
      \ 'backupext': [['xxx'], ['']],
      \ 'belloff': [['', 'all', 'copy,error'], ['xxx']],
      \ 'breakindentopt': [['', 'min:3', 'sbr'], ['xxx', 'min', 'min:x']],
      \ 'browsedir': [['', 'last', '/'], ['xxx']],
      \ 'bufhidden': [['', 'hide', 'wipe'], ['xxx', 'hide,wipe']],
      \ 'buftype': [['', 'help', 'nofile'], ['xxx', 'help,nofile']],
      \ 'casemap': [['', 'internal'], ['xxx']],
      \ 'cedit': [['', '\<Esc>'], ['xxx', 'f']],
      \ 'clipboard': [['', 'unnamed', 'autoselect,unnamed'], ['xxx']],
      \ 'colorcolumn': [['', '8', '+2'], ['xxx']],
      \ 'comments': [['', 'b:#'], ['xxx']],
      \ 'commentstring': [['', '/*%s*/'], ['xxx']],
      \ 'complete': [['', 'w,b'], ['xxx']],
      \ 'concealcursor': [['', 'n', 'nvic'], ['xxx']],
      \ 'completeopt': [['', 'menu', 'menu,longest'], ['xxx', 'menu,,,longest,']],
      \ 'cryptmethod': [['', 'zip'], ['xxx']],
      \ 'cscopequickfix': [['', 's-', 's-,c+,e0'], ['xxx', 's,g,d']],
      \ 'debug': [['', 'msg', 'msg', 'beep'], ['xxx']],
      \ 'diffopt': [['', 'filler', 'icase,iwhite'], ['xxx']],
      \ 'display': [['', 'lastline', 'lastline,uhex'], ['xxx']],
      \ 'eadirection': [['', 'both', 'ver'], ['xxx', 'ver,hor']],
      \ 'encoding': [['latin1'], ['xxx', '']],
      \ 'eventignore': [['', 'WinEnter', 'WinLeave,winenter'], ['xxx']],
      \ 'fileencoding': [['', 'latin1', 'xxx'], []],
      \ 'fileformat': [['', 'dos', 'unix'], ['xxx']],
      \ 'fileformats': [['', 'dos', 'dos,unix'], ['xxx']],
      \ 'fillchars': [['', 'vert:x'], ['xxx']],
      \ 'foldclose': [['', 'all'], ['xxx']],
      \ 'foldmethod': [['manual', 'indent'], ['', 'xxx', 'expr,diff']],
      \ 'foldopen': [['', 'all', 'hor,jump'], ['xxx']],
      \ 'foldmarker': [['((,))'], ['', 'xxx']],
      \ 'formatoptions': [['', 'vt', 'v,t'], ['xxx']],
      \ 'guicursor': [['', 'n:block-Cursor'], ['xxx']],
      \ 'guifont': [['', 'fixedsys'], []],
      \ 'guifontwide': [['', 'fixedsys'], []],
      \ 'helplang': [['', 'de', 'de,it'], ['xxx']],
      \ 'highlight': [['', 'e:Error'], ['xxx']],
      \ 'imactivatekey': [['', 'S-space'], ['xxx']],
      \ 'isfname': [['', '@', '@,48-52'], ['xxx', '@48']],
      \ 'isident': [['', '@', '@,48-52'], ['xxx', '@48']],
      \ 'iskeyword': [['', '@', '@,48-52'], ['xxx', '@48']],
      \ 'isprint': [['', '@', '@,48-52'], ['xxx', '@48']],
      \ 'keymap': [['', 'accents'], ['xxx']],
      \ 'keymodel': [['', 'startsel', 'startsel,stopsel'], ['xxx']],
      \ 'langmap': [['', 'xX', 'aA,bB'], ['xxx']],
      \ 'listchars': [['', 'eol:x', 'eol:x,space:y'], ['xxx']],
      \ 'matchpairs': [['', '(:)', '(:),<:>'], ['xxx']],
      \ 'mkspellmem': [['10000,100,12'], ['', 'xxx']],
      \ 'mouse': [['', 'a', 'nvi'], ['xxx', 'n,v,i']],
      \ 'mousemodel': [['', 'popup'], ['xxx']],
      \ 'mouseshape': [['', 'n:arrow'], ['xxx']],
      \ 'nrformats': [['', 'alpha', 'alpha,hex,bin'], ['xxx']],
      \ 'printmbfont': [['', 'r:some', 'b:Bold,c:yes'], ['xxx']],
      \ 'printoptions': [['', 'header:0', 'left:10pc,top:5pc'], ['xxx']],
      \ 'scrollopt': [['', 'ver', 'ver,hor'], ['xxx']],
      \ 'renderoptions': [['', 'type:directx'], ['xxx']],
      \ 'selection': [['old', 'inclusive'], ['', 'xxx']],
      \ 'selectmode': [['', 'mouse', 'key,cmd'], ['xxx']],
      \ 'sessionoptions': [['', 'blank', 'help,options,slash'], ['xxx']],
      \ 'signcolumn': [['', 'auto', 'no'], ['xxx', 'no,yes']],
      \ 'spellfile': [['', 'file.en.add'], ['xxx', '/tmp/file']],
      \ 'spellsuggest': [['', 'best', 'double,33'], ['xxx']],
      \ 'switchbuf': [['', 'useopen', 'split,newtab'], ['xxx']],
      \ 'tagcase': [['smart', 'match'], ['', 'xxx', 'smart,match']],
      \ 'term': [[], []],
      \ 'toolbar': [['', 'icons', 'text'], ['xxx']],
      \ 'toolbariconsize': [['', 'tiny', 'huge'], ['xxx']],
      \ 'ttymouse': [['', 'xterm'], ['xxx']],
      \ 'ttytype': [[], []],
      \ 'viewoptions': [['', 'cursor', 'unix,slash'], ['xxx']],
      \ 'viminfo': [['', '''50', '"30'], ['xxx']],
      \ 'virtualedit': [['', 'all', 'all,block'], ['xxx']],
      \ 'whichwrap': [['', 'b,s', 'bs'], ['xxx']],
      \ 'wildmode': [['', 'full', 'list:full', 'full,longest'], ['xxx']],
      \ 'wildoptions': [['', 'tagfile'], ['xxx']],
      \ 'winaltkeys': [['menu', 'no'], ['', 'xxx']],
      \
      \ 'luadll': [[], []],
      \ 'perldll': [[], []],
      \ 'pythondll': [[], []],
      \ 'pythonthreedll': [[], []],
      \ 'pyxversion': [[], []],
      \ 'rubydll': [[], []],
      \ 'tcldll': [[], []],
      \
      \ 'othernum': [[-1, 0, 100], ['']],
      \ 'otherstring': [['', 'xxx'], []],
      \}

1
/struct vimoption options
while 1
  /{"
  if line('.') > end
    break
  endif
  let line = getline('.')
  let name = substitute(line, '.*{"\([^"]*\)".*', '\1', '')
  let shortname = substitute(line, '.*"\([^"]*\)".*', '\1', '')

  if has_key(test_values, name)
    let a = test_values[name]
  elseif line =~ 'P_NUM'
    let a = test_values['othernum']
  else
    let a = test_values['otherstring']
  endif
  if len(a[0]) > 0 || len(a[1]) > 0
    if line =~ 'P_BOOL'
      call add(script, 'set ' . name)
      call add(script, 'set ' . shortname)
      call add(script, 'set no' . name)
      call add(script, 'set no' . shortname)
    else
      for val in a[0]
	call add(script, 'set ' . name . '=' . val)
	call add(script, 'set ' . shortname . '=' . val)
      endfor

      " setting an option can only fail when it's implemented.
      call add(script, "if exists('+" . name . "')")
      for val in a[1]
	call add(script, "call assert_fails('set " . name . "=" . val . "')")
	call add(script, "call assert_fails('set " . shortname . "=" . val . "')")
      endfor
      call add(script, "endif")
    endif

    call add(script, 'set ' . name . '&')
    call add(script, 'set ' . shortname . '&')
    if name == 'verbosefile'
      call add(script, 'call delete("xxx")')
    endif

    if name == 'more'
      call add(script, 'set nomore')
    elseif name == 'lines'
      call add(script, 'let &lines = save_lines')
    endif
  endif
endwhile

call add(script, 'let &term = save_term')
call add(script, 'let &columns = save_columns')
call add(script, 'let &lines = save_lines')

call writefile(script, 'opt_test.vim')

endif

qa!
