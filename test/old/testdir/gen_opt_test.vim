" Script to generate testdir/opt_test.vim from options.lua

try

set nomore

const K_KENTER = -16715

" The terminal size is restored at the end.
let script = [
      \ '" DO NOT EDIT: Generated with gen_opt_test.vim',
      \ '" Used by test_options.vim.',
      \ '',
      \ 'let save_columns = &columns',
      \ 'let save_lines = &lines',
      \ ]

let options = luaeval('loadfile("../../../src/nvim/options.lua")().options')

" font name that works everywhere (hopefully)
let fontname = has('win32') ? 'fixedsys' : 'fixed'

" Two lists with values: values that work and values that fail.
" When not listed, "othernum" or "otherstring" is used.
let test_values = {
      "\ Nvim-only options
      \ 'channel': [[], []],
      \ 'inccommand': [['', 'nosplit', 'split'], ['xxx']],
      \ 'mousescroll': [['ver:1', 'hor:2', 'ver:1,hor:2', 'hor:1,ver:2'], ['xxx']],
      \ 'redrawdebug': [[''], ['xxx']],
      \ 'shada': [['', '''50', '"30'], ['xxx']],
      \ 'termpastefilter': [['BS', 'HT', 'FF', 'ESC', 'DEL', 'C0', 'C1', 'C0,C1'], ['xxx']],
      \ 'winhighlight': [['', 'Visual:Search'], ['xxx']],
      \
      "\ Options for which Nvim has different allowed values
      \ 'backspace': [[2, '', 'eol', 'eol,start', 'indent,eol,nostop'], ['4', 'xxx']],
      \ 'clipboard': [['', 'unnamed'], ['xxx', '\ze*', 'exclude:\\%(']],
      \ 'encoding': [['utf8'], []],
      \ 'foldcolumn': [[0, 1, 4], [-1, 13, 999]],
      \ 'foldlevel': [[0, 100], [-1, '']],
      \ 'highlight': [[nvim_get_option_info2('highlight', {}).default], []],
      \ 'signcolumn': [['auto', 'no'], ['xxx', 'no,yes']],
      \ 'writedelay': [[0, 100], [-1, '']],
      \
      \ 'cmdheight': [[0, 1, 2, 10], [-1]],
      \ 'cmdwinheight': [[1, 2, 10], [-1, 0]],
      \ 'columns': [[12, 80], [-1, 0, 10]],
      \ 'conceallevel': [[0, 1, 2, 3], [-1, 4, 99]],
      "\ 'foldcolumn': [[0, 1, 4, 12], [-1, 13, 999]],
      \ 'helpheight': [[0, 10, 100], [-1]],
      \ 'history': [[0, 1, 100], [-1, 10001]],
      \ 'iminsert': [[0, 1], [-1, 3, 999]],
      \ 'imsearch': [[-1, 0, 1], [-2, 3, 999]],
      "\ 'imstyle': [[0, 1], [-1, 2, 999]],
      \ 'lines': [[2, 24], [-1, 0, 1]],
      \ 'linespace': [[0, 2, 4], ['']],
      \ 'numberwidth': [[1, 4, 8, 10, 11, 20], [-1, 0, 21]],
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
      \ 'wildchar': [[-1, 0, 100, 'x', '^Y', '^@', '<Esc>', '<t_xx>', '<', '^'],
      \		['', 'xxx', '<xxx>', '<Esc', '<t_xx', '<C-C>', '<NL>', '<CR>', K_KENTER]],
      \ 'wildcharm': [[-1, 0, 100, 'x', '^Y', '^@', '<Esc>', '<', '^'],
      \		['', 'xxx', '<xxx>', '<Esc', '<t_xx', '<C-C>', '<NL>', '<CR>', K_KENTER]],
      \ 'winheight': [[1, 10, 999], [-1, 0]],
      \ 'winminheight': [[0, 1], [-1]],
      \ 'winminwidth': [[0, 1, 10], [-1]],
      \ 'winwidth': [[1, 10, 999], [-1, 0]],
      \
      \ 'ambiwidth': [['', 'single'], ['xxx']],
      \ 'background': [['', 'light', 'dark'], ['xxx']],
      "\ 'backspace': [[0, 2, 3, '', 'eol', 'eol,start', 'indent,eol,nostop'], ['4', 'xxx']],
      \ 'backupcopy': [['yes', 'auto'], ['', 'xxx', 'yes,no']],
      \ 'backupext': [['xxx'], ['']],
      \ 'belloff': [['', 'all', 'copy,error'], ['xxx']],
      \ 'breakindentopt': [['', 'min:3', 'sbr'], ['xxx', 'min', 'min:x']],
      \ 'browsedir': [['', 'last', '/'], ['xxx']],
      \ 'bufhidden': [['', 'hide', 'wipe'], ['xxx', 'hide,wipe']],
      \ 'buftype': [['', 'help', 'nofile'], ['xxx', 'help,nofile']],
      \ 'casemap': [['', 'internal'], ['xxx']],
      \ 'cedit': [['', '^Y', '^@', '<Esc>', '<t_xx>'],
      \		['xxx', 'f', '<xxx>', '<Esc', '<t_xx']],
      "\ 'clipboard': [['', 'unnamed', 'autoselect,unnamed', 'html', 'exclude:vimdisplay'], ['xxx', '\ze*', 'exclude:\\%(']],
      \ 'colorcolumn': [['', '8', '+2'], ['xxx']],
      \ 'comments': [['', 'b:#'], ['xxx']],
      \ 'commentstring': [['', '/*\ %s\ */'], ['xxx']],
      \ 'complete': [['', 'w,b'], ['xxx']],
      \ 'concealcursor': [['', 'n', 'nvic'], ['xxx']],
      \ 'completeopt': [['', 'menu', 'menu,longest'], ['xxx', 'menu,,,longest,']],
      \ 'completeitemalign': [['abbr,kind,menu'], ['xxx','abbr,menu','abbr,menu,kind,abbr', 'abbr', 'abbr1234,kind', '']],
      "\ 'completepopup': [['', 'height:13', 'highlight:That', 'width:10,height:234,highlight:Mine'], ['height:yes', 'width:no', 'xxx', 'xxx:99', 'border:maybe', 'border:1']],
      \ 'completeslash': [['', 'slash', 'backslash'], ['xxx']],
      "\ 'cryptmethod': [['', 'zip'], ['xxx']],
      "\ 'cscopequickfix': [['', 's-', 's-,c+,e0'], ['xxx', 's,g,d']],
      \ 'cursorlineopt': [['both', 'line', 'number', 'screenline', 'line,number'], ['', 'xxx', 'line,screenline']],
      \ 'debug': [['', 'msg', 'msg', 'beep'], ['xxx']],
      \ 'diffopt': [['', 'filler', 'icase,iwhite'], ['xxx', 'algorithm:xxx', 'algorithm:']],
      \ 'display': [['', 'lastline', 'lastline,uhex'], ['xxx']],
      \ 'eadirection': [['', 'both', 'ver'], ['xxx', 'ver,hor']],
      "\ 'encoding': [['latin1'], ['xxx', '']],
      \ 'eventignore': [['', 'WinEnter', 'WinLeave,winenter', 'all,WinEnter'], ['xxx']],
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
      \ 'guifont': [['', fontname], []],
      \ 'guifontwide': [['', fontname], []],
      "\ 'guifontset': [['', fontname], []],
      \ 'guioptions': [['', 'a'], ['Q']],
      \ 'helplang': [['', 'de', 'de,it'], ['xxx']],
      "\ 'highlight': [['', 'e:Error'], ['xxx']],
      "\ 'imactivatekey': [['', 'S-space'], ['xxx']],
      \ 'isfname': [['', '@', '@,48-52'], ['xxx', '@48']],
      \ 'isident': [['', '@', '@,48-52'], ['xxx', '@48']],
      \ 'iskeyword': [['', '@', '@,48-52'], ['xxx', '@48']],
      \ 'isprint': [['', '@', '@,48-52'], ['xxx', '@48']],
      \ 'jumpoptions': [['', 'stack'], ['xxx']],
      \ 'keymap': [['', 'accents'], ['xxx']],
      \ 'keymodel': [['', 'startsel', 'startsel,stopsel'], ['xxx']],
      "\ 'keyprotocol': [['', 'xxx:none', 'yyy:mok2', 'zzz:kitty'],
      "\ "		[':none', 'xxx:', 'x:non', 'y:mok3', 'z:kittty']],
      \ 'langmap': [['', 'xX', 'aA,bB'], ['xxx']],
      \ 'lispoptions': [['', 'expr:0', 'expr:1'], ['xxx']],
      \ 'listchars': [['', 'eol:x', 'eol:x,space:y'], ['xxx']],
      \ 'matchpairs': [['', '(:)', '(:),<:>'], ['xxx']],
      \ 'mkspellmem': [['10000,100,12'], ['', 'xxx']],
      \ 'mouse': [['', 'a', 'nvi'], ['xxx', 'n,v,i']],
      \ 'mousemodel': [['', 'popup'], ['xxx']],
      \ 'mouseshape': [['', 'n:arrow'], ['xxx']],
      \ 'nrformats': [['', 'alpha', 'alpha,hex,bin'], ['xxx']],
      "\ 'previewpopup': [['', 'height:13', 'width:10,height:234'], ['height:yes', 'xxx', 'xxx:99']],
      "\ 'printmbfont': [['', 'r:some', 'b:Bold,c:yes'], ['xxx']],
      "\ 'printoptions': [['', 'header:0', 'left:10pc,top:5pc'], ['xxx']],
      \ 'scrollopt': [['', 'ver', 'ver,hor'], ['xxx']],
      "\ 'renderoptions': [[''], ['xxx']],
      \ 'rightleftcmd': [['search'], ['xxx']],
      \ 'selection': [['old', 'inclusive'], ['', 'xxx']],
      \ 'selectmode': [['', 'mouse', 'key,cmd'], ['xxx']],
      \ 'sessionoptions': [['', 'blank', 'help,options,slash'], ['xxx']],
      \ 'showcmdloc': [['last', 'statusline', 'tabline'], ['xxx']],
      "\ 'signcolumn': [['', 'auto', 'no'], ['xxx', 'no,yes']],
      \ 'spellfile': [['', 'file.en.add', 'xxx.en.add,yyy.gb.add,zzz.ja.add',
      \		'/tmp/dir\ with\ space/en.utf-8.add',
      \		'/tmp/dir\\,with\\,comma/en.utf-8.add'],
      \		['xxx', '/tmp/file', ',file.en.add', 'xxx,yyy.en.add',
      \		'xxx.en.add,yyy,zzz.ja.add']],
      \ 'spelllang': [['', 'xxx', 'sr@latin'], ['not&lang', "that\\\rthere"]],
      \ 'spelloptions': [['', 'camel'], ['xxx']],
      \ 'spellsuggest': [['', 'best', 'double,33'], ['xxx']],
      \ 'splitkeep': [['cursor', 'screen', 'topline'], ['xxx']],
      "\ 'swapsync': [['', 'sync', 'fsync'], ['xxx']],
      \ 'switchbuf': [['', 'useopen', 'split,newtab'], ['xxx']],
      \ 'tabclose': [['', 'left', 'left,uselast'], ['xxx']],
      \ 'tagcase': [['smart', 'match'], ['', 'xxx', 'smart,match']],
      \ 'term': [[], []],
      \ 'termguicolors': [[], []],
      \ 'termencoding': [has('gui_gtk') ? [] : ['', 'utf-8'], ['xxx']],
      "\ 'termwinkey': [['', 'f', '^Y', '^@', '<Esc>', '<t_xx>', "\u3042", '<', '^'],
      "\ "		['<xxx>', '<Esc', '<t_xx']],
      "\ 'termwinsize': [['', '24x80', '0x80', '32x0', '0x0'], ['xxx', '80', '8ax9', '24x80b']],
      "\ 'termwintype': [['', 'winpty', 'conpty'], ['xxx']],
      "\ 'toolbar': [['', 'icons', 'text'], ['xxx']],
      "\ 'toolbariconsize': [['', 'tiny', 'huge'], ['xxx']],
      "\ 'ttymouse': [['', 'xterm'], ['xxx']],
      \ 'ttytype': [[], []],
      \ 'varsofttabstop': [['8', '4,8,16,32'], ['xxx', '-1', '4,-1,20']],
      \ 'vartabstop': [['8', '4,8,16,32'], ['xxx', '-1', '4,-1,20']],
      \ 'viewoptions': [['', 'cursor', 'unix,slash'], ['xxx']],
      \ 'viminfo': [['', '''50', '"30'], ['xxx']],
      \ 'virtualedit': [['', 'all', 'all,block'], ['xxx']],
      \ 'whichwrap': [['', 'b,s', 'bs'], ['xxx']],
      \ 'wildmode': [['', 'full', 'list:full', 'full,longest'], ['xxx', 'a4', 'full,full,full,full,full']],
      \ 'wildoptions': [['', 'tagfile', 'pum', 'fuzzy'], ['xxx']],
      \ 'winaltkeys': [['menu', 'no'], ['', 'xxx']],
      \
      "\ 'luadll': [[], []],
      "\ 'perldll': [[], []],
      "\ 'pythondll': [[], []],
      "\ 'pythonthreedll': [[], []],
      \ 'pyxversion': [[], []],
      "\ 'rubydll': [[], []],
      "\ 'tcldll': [[], []],
      \
      \ 'othernum': [[-1, 0, 100], ['']],
      \ 'otherstring': [['', 'xxx'], []],
      \}

const invalid_options = test_values->keys()
      \->filter({-> v:val !~# '^other' && !exists($"&{v:val}")})
if !empty(invalid_options)
  throw $"Invalid option name in test_values: '{invalid_options->join("', '")}'"
endif

for option in options
  let name = option.full_name
  let shortname = get(option, 'abbreviation', name)

  if get(option, 'immutable', v:false)
    continue
  endif

  if has_key(test_values, name)
    let a = test_values[name]
  elseif option.type == 'number'
    let a = test_values['othernum']
  else
    let a = test_values['otherstring']
  endif
  if len(a[0]) > 0 || len(a[1]) > 0
    if option.type == 'boolean'
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
	call add(script, "silent! call assert_fails('set " . name . "=" . val . "')")
	call add(script, "silent! call assert_fails('set " . shortname . "=" . val . "')")
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
    elseif name == 'laststatus'
      call add(script, 'set laststatus=1')
    elseif name == 'lines'
      call add(script, 'let &lines = save_lines')
    endif
  endif
endfor

call add(script, 'let &columns = save_columns')
call add(script, 'let &lines = save_lines')
call add(script, 'source unix.vim')

call writefile(script, 'opt_test.vim')

" Write error messages if error occurs.
catch
  " Append errors to test.log
  let error = $'Error: {v:exception} in {v:throwpoint}'
  echo error
  split test.log
  call append('$', error)
  write
endtry

qa!
