" Script to generate test/old/testdir/opt_test.vim from src/nvim/options.lua
" and runtime/doc/options.txt

set cpo&vim

" Only do this when build with the +eval feature.
if 1

try

set nomore

const K_KENTER = -16715

" Get global-local options.
" "key" is full-name of the option.
" "value" is the local value to switch back to the global value.
b options.txt
call cursor(1, 1)
let global_locals = {}
while search("^'[^']*'.*\\n.*|global-local", 'W')
  let fullname = getline('.')->matchstr("^'\\zs[^']*")
  let global_locals[fullname] = ''
endwhile
call extend(global_locals, #{
      \ scrolloff: -1,
      \ sidescrolloff: -1,
      \ undolevels: -123456,
      \})

" Get local-noglobal options.
" "key" is full-name of the option.
" "value" is no used.
b options.txt
call cursor(1, 1)
let local_noglobals = {}
while search("^'[^']*'.*\\n.*|local-noglobal", 'W')
  let fullname = getline('.')->matchstr("^'\\zs[^']*")
  let local_noglobals[fullname] = v:true
endwhile

" Options to skip `setglobal` tests.
" "key" is full-name of the option.
" "value" is the reason.
let skip_setglobal_reasons = #{
      \ iminsert: 'The global value is always overwritten by the local value',
      \ imsearch: 'The global value is always overwritten by the local value',
      \}

" Script header.
" The test values contains multibyte characters.
let script = [
      \ '" DO NOT EDIT: Generated with gen_opt_test.vim',
      \ '" Used by test_options_all.vim.',
      \ '',
      \ 'scriptencoding utf-8',
      \ ]

let options = luaeval('loadfile("../../../src/nvim/options.lua")().options')

" font name that works everywhere (hopefully)
let fontname = has('win32') ? 'fixedsys' : 'fixed'

" Two lists with values: values that work and values that fail.
" When not listed, "othernum" or "otherstring" is used.
" When both lists are empty, skip tests for the option.
" For boolean options, if non-empty a fixed test will be run, otherwise skipped.
let test_values = {
      "\ Nvim-only options
      \ 'channel': [[], []],
      \ 'inccommand': [['', 'nosplit', 'split'], ['xxx']],
      \ 'mousescroll': [['ver:1', 'hor:2', 'ver:1,hor:2', 'hor:1,ver:2'],
      \		['xxx', 'ver:1,xxx', 'hor:2,xxx']],
      \ 'redrawdebug': [[''], ['xxx']],
      \ 'shada': [['', '''50', '"30'], ['xxx']],
      \ 'termpastefilter': [['BS', 'HT', 'FF', 'ESC', 'DEL', 'C0', 'C1', 'C0,C1'],
      \		['xxx', 'C0,C1,xxx']],
      \ 'winborder': [['rounded', 'none', 'single', 'solid'], ['xxx', 'none,solid']],
      \ 'winhighlight': [['', 'a:b', 'a:', 'a:b,c:d'],
      \		['a', ':', ':b', 'a:b:c', 'a:/', '/:b', ',', 'a:b,,', 'a:b,c']],
      \
      "\ Options for which Nvim has different allowed values
      \ 'backspace': [[2, '', 'indent', 'eol', 'start', 'nostop',
      \		'eol,start', 'indent,eol,nostop'],
      \		[-1, 4, 'xxx']],
      \ 'buftype': [['', 'nofile', 'nowrite', 'acwrite', 'quickfix', 'help',
      \		'prompt'],
      \		['xxx', 'help,nofile']],
      \ 'clipboard': [['', 'unnamed'], ['xxx', '\ze*', 'exclude:\\%(']],
      \ 'completeopt': [['', 'menu', 'menuone', 'longest', 'preview', 'popup',
      \		'noinsert', 'noselect', 'fuzzy', 'preinsert', 'menu,longest'],
      \		['xxx', 'menu,,,longest,']],
      \ 'encoding': [['utf8'], []],
      \ 'foldcolumn': [[0, 1, 4, 'auto', 'auto:1', 'auto:9'], [-1, 13, 999]],
      \ 'foldlevel': [[0, 100], [-1, '']],
      \ 'highlight': [[&highlight], []],
      \ 'iminsert': [[0, 1], [-1, 2, 3, 999]],
      \ 'imsearch': [[-1, 0, 1], [-2, 2, 3, 999]],
      \ 'signcolumn': [['auto', 'no', 'yes', 'number', 'yes:1', 'auto:1-9'],
      \		['', 'xxx', 'no,yes', 'auto:0-9', 'auto:9-1', 'auto:1-@']],
      \ 'writedelay': [[0, 100], [-1, '']],
      \
      "\ boolean options
      \ 'termguicolors': [
      \		has('vtp') && !has('vcon') && !has('gui_running') ? [] : [1],
      \		[]],
      \
      "\ number options
      \ 'chistory': [[1, 2, 10, 50], [1000, -1]],
      \ 'cmdheight': [[0, 1, 2, 10], [-1]],
      \ 'cmdwinheight': [[1, 2, 10], [-1, 0]],
      \ 'columns': [[12, 80, 10000], [-1, 0, 10]],
      \ 'conceallevel': [[0, 1, 2, 3], [-1, 4, 99]],
      "\ 'foldcolumn': [[0, 1, 4, 12], [-1, 13, 999]],
      \ 'helpheight': [[0, 10, 100], [-1]],
      \ 'history': [[0, 1, 100, 10000], [-1, 10001]],
      "\ 'iminsert': [[0, 1, 2], [-1, 3, 999]],
      "\ 'imsearch': [[-1, 0, 1, 2], [-2, 3, 999]],
      "\ 'imstyle': [[0, 1], [-1, 2, 999]],
      \ 'lhistory': [[1, 2, 10, 50], [1000, -1]],
      \ 'lines': [[2, 24, 1000], [-1, 0, 1]],
      \ 'linespace': [[-1, 0, 2, 4, 999], ['']],
      \ 'numberwidth': [[1, 4, 8, 10, 11, 20], [-1, 0, 21]],
      \ 'regexpengine': [[0, 1, 2], [-1, 3, 999]],
      \ 'report': [[0, 1, 2, 9999], [-1]],
      \ 'scroll': [[0, 1, 2, 15], [-1, 999]],
      \ 'scrolljump': [[-100, -1, 0, 1, 2, 15], [-101, 999]],
      \ 'scrolloff': [[0, 1, 8, 999], [-1]],
      \ 'shiftwidth': [[0, 1, 8, 999], [-1]],
      \ 'sidescroll': [[0, 1, 8, 999], [-1]],
      \ 'sidescrolloff': [[0, 1, 8, 999], [-1]],
      \ 'tabstop': [[1, 4, 8, 12, 9999], [-1, 0, 10000]],
      \ 'textwidth': [[0, 1, 8, 99], [-1]],
      \ 'timeoutlen': [[0, 8, 99999], [-1]],
      \ 'titlelen': [[0, 1, 8, 9999], [-1]],
      \ 'updatecount': [[0, 1, 8, 9999], [-1]],
      \ 'updatetime': [[0, 1, 8, 9999], [-1]],
      \ 'verbose': [[-1, 0, 1, 8, 9999], ['']],
      \ 'wildchar': [[-1, 0, 100, 'x', '^Y', '^@', '<Esc>', '<t_xx>', '<', '^'],
      \		['', 'xxx', '<xxx>', '<t_xxx>', '<Esc', '<t_xx', '<C-C>',
      \		'<NL>', '<CR>', K_KENTER]],
      \ 'wildcharm': [[-1, 0, 100, 'x', '^Y', '^@', '<Esc>', '<', '^'],
      \		['', 'xxx', '<xxx>', '<t_xxx>', '<Esc', '<t_xx', '<C-C>',
      \		'<NL>', '<CR>', K_KENTER]],
      \ 'winheight': [[1, 10, 999], [-1, 0]],
      \ 'winminheight': [[0, 1], [-1]],
      \ 'winminwidth': [[0, 1, 10], [-1]],
      \ 'winwidth': [[1, 10, 999], [-1, 0]],
      \
      "\ string options
      \ 'ambiwidth': [['single', 'double'], ['xxx']],
      \ 'background': [['light', 'dark'], ['xxx']],
      "\ 'backspace': [[0, 1, 2, 3, '', 'indent', 'eol', 'start', 'nostop',
      "\ "		'eol,start', 'indent,eol,nostop'],
      "\ "		[-1, 4, 'xxx']],
      \ 'backupcopy': [['yes', 'no', 'auto'], ['', 'xxx', 'yes,no']],
      \ 'backupext': [['xxx'], [&patchmode, '*']],
      \ 'belloff': [['', 'all', 'backspace', 'cursor', 'complete', 'copy',
      \		'ctrlg', 'error', 'esc', 'ex', 'hangul', 'insertmode', 'lang',
      \		'mess', 'showmatch', 'operator', 'register', 'shell', 'spell',
      \		'term', 'wildmode', 'copy,error,shell'],
      \		['xxx']],
      \ 'breakindentopt': [['', 'min:3', 'shift:4', 'shift:-2', 'sbr', 'list:5',
      \		'list:-1', 'column:10', 'column:-5', 'min:1,sbr,shift:2'],
      \		['xxx', 'min', 'min:x', 'min:-1', 'shift:x', 'sbr:1', 'list:x',
      \		'column:x']],
      \ 'browsedir': [['', 'last', 'buffer', 'current', './Xdir\ with\ space'],
      \		['xxx']],
      \ 'bufhidden': [['', 'hide', 'unload', 'delete', 'wipe'],
      \		['xxx', 'hide,wipe']],
      "\ 'buftype': [['', 'nofile', 'nowrite', 'acwrite', 'quickfix', 'help',
      "\ "		'terminal', 'prompt', 'popup'],
      "\ "		['xxx', 'help,nofile']],
      \ 'casemap': [['', 'internal', 'keepascii', 'internal,keepascii'],
      \		['xxx']],
      \ 'cedit': [['', '^Y', '^@', '<Esc>', '<t_xx>'],
      \		['xxx', 'f', '<xxx>', '<t_xxx>', '<Esc', '<t_xx']],
      "\ 'clipboard': [['', 'unnamed', 'unnamedplus', 'autoselect',
      "\ "		'autoselectplus', 'autoselectml', 'html', 'exclude:vimdisplay',
      "\ "		'autoselect,unnamed', 'unnamed,exclude:.*'],
      "\ "		['xxx', 'exclude:\\ze*', 'exclude:\\%(']],
      \ 'colorcolumn': [['', '8', '+2', '1,+1,+3'], ['xxx', '-a', '1,', '1;']],
      \ 'comments': [['', 'b:#', 'b:#,:%'], ['xxx', '-']],
      \ 'commentstring': [['', '/*\ %s\ */'], ['xxx']],
      \ 'complete': [['', '.', 'w', 'b', 'u', 'U', 'i', 'd', ']', 't',
      \		'k', 'kspell', 'k/tmp/dir\\\ with\\\ space/*',
      \		's', 's/tmp/dir\\\ with\\\ space/*',
      \		'w,b,k/tmp/dir\\\ with\\\ space/*,s'],
      \		['xxx']],
      \ 'completefuzzycollect': [['', 'keyword', 'files', 'whole_line',
      \		'keyword,whole_line', 'files,whole_line', 'keyword,files,whole_line'],
      \		['xxx', 'keyword,,,whole_line,']],
      \ 'completeitemalign': [['abbr,kind,menu', 'menu,abbr,kind'],
      \		['', 'xxx', 'abbr', 'abbr,menu', 'abbr,menu,kind,abbr',
      \		'abbr1234,kind,menu']],
      "\ 'completeopt': [['', 'menu', 'menuone', 'longest', 'preview', 'popup',
      "\ "		'popuphidden', 'noinsert', 'noselect', 'fuzzy', 'preinsert', 'menu,longest'],
      "\ "		['xxx', 'menu,,,longest,']],
      "\ 'completepopup': [['', 'height:13', 'width:20', 'highlight:That',
      "\ "		'align:item', 'align:menu', 'border:on', 'border:off',
      "\ "		'width:10,height:234,highlight:Mine'],
      "\ "		['xxx', 'xxx:99', 'height:yes', 'width:no', 'align:xxx',
      "\ "		'border:maybe', 'border:1', 'border:']],
      \ 'completeslash': [['', 'slash', 'backslash'], ['xxx']],
      \ 'concealcursor': [['', 'n', 'v', 'i', 'c', 'nvic'], ['xxx']],
      "\ 'cryptmethod': [['', 'zip'], ['xxx']],
      "\ 'cscopequickfix': [['', 's-', 'g-', 'd-', 'c-', 't-', 'e-', 'f-', 'i-',
      "\ "		'a-', 's-,c+,e0'],
      "\ "		['xxx', 's,g,d']],
      \ 'cursorlineopt': [['both', 'line', 'number', 'screenline',
      \		'line,number'],
      \		['', 'xxx', 'line,screenline']],
      \ 'debug': [['', 'msg', 'throw', 'beep'], ['xxx']],
      \ 'diffanchors': [['', "'a", '/foo/', "'a-1,'>,/foo,xxx/,'b,123",
      \		'1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20',
      \		'1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,'],
      \		[',',  '12,,34', 'xxx', '123,xxx',
      \		'1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21']],
      \ 'diffopt': [['', 'filler', 'context:0', 'context:999', 'iblank',
      \		'icase', 'iwhite', 'iwhiteall', 'horizontal', 'vertical',
      \		'closeoff', 'hiddenoff', 'foldcolumn:0', 'foldcolumn:12',
      \		'followwrap', 'internal', 'indent-heuristic', 'algorithm:myers',
      \		'icase,iwhite', 'algorithm:minimal', 'algorithm:patience',
      \		'anchor', 'algorithm:histogram', 'inline:none', 'inline:simple',
      \		'inline:char', 'inline:word', 'inline:char,inline:word', 'linematch:5'],
      \		['xxx', 'foldcolumn:', 'foldcolumn:x', 'foldcolumn:xxx',
      \		'linematch:', 'linematch:x', 'linematch:xxx', 'algorithm:',
      \		'algorithm:xxx', 'context:', 'context:x', 'context:xxx',
      \		'inline:xxx']],
      \ 'display': [['', 'lastline', 'truncate', 'uhex', 'lastline,uhex'],
      \		['xxx']],
      \ 'eadirection': [['both', 'ver', 'hor'], ['xxx', 'ver,hor']],
      "\ 'encoding': [['latin1'], ['xxx', '']],
      \ 'eventignore': [['', 'WinEnter', 'WinLeave,winenter', 'all,WinEnter', 'all,-WinLeave'],
      \		['xxx']],
      \ 'eventignorewin': [['', 'WinEnter', 'WinLeave,winenter', 'all,WinEnter', 'all,-WinLeave'],
      \		['xxx', 'WinNew']],
      \ 'fileencoding': [['', 'latin1', 'xxx'], []],
      \ 'fileformat': [['dos', 'unix', 'mac'], ['xxx']],
      \ 'fileformats': [['', 'dos', 'dos,unix'], ['xxx']],
      \ 'fillchars': [['', 'stl:x', 'stlnc:x', 'vert:x', 'fold:x', 'foldopen:x',
      \		'foldclose:x', 'foldsep:x', 'diff:x', 'eob:x', 'lastline:x',
      \		'trunc:_', 'trunc:_,eob:x,trunc:_',
      \		'stl:\ ,vert:\|,fold:\\,trunc:…,diff:x'],
      \		['xxx', 'vert:', 'trunc:', "trunc:\b"]],
      \ 'foldclose': [['', 'all'], ['xxx']],
      \ 'foldmarker': [['((,))'], ['', 'xxx', '{{{,']],
      \ 'foldmethod': [['manual', 'indent', 'expr', 'marker', 'syntax', 'diff'],
      \		['', 'xxx', 'expr,diff']],
      \ 'foldopen': [['', 'all', 'block', 'hor', 'insert', 'jump', 'mark',
      \		'percent', 'quickfix', 'search', 'tag', 'undo', 'hor,jump'],
      \		['xxx']],
      \ 'formatoptions': [['', 't', 'c', 'r', 'o', '/', 'q', 'w', 'a', 'n', '2',
      \		'v', 'b', 'l', 'm', 'M', 'B', '1', ']', 'j', 'p', 'vt', 'v,t'],
      \		['xxx']],
      \ 'guicursor': [['', 'n:block-Cursor'], ['xxx']],
      \ 'guifont': [['', fontname], []],
      "\ 'guifontset': [['', fontname], []],
      \ 'guifontwide': [['', fontname], []],
      \ 'guioptions': [['', '!', 'a', 'P', 'A', 'c', 'd', 'e', 'f', 'i', 'm',
      \		'M', 'g', 't', 'T', 'r', 'R', 'l', 'L', 'b', 'h', 'v', 'p', 'F',
      \		'k', '!abvR'],
      \		['xxx', 'a,b']],
      \ 'helplang': [['', 'de', 'de,it'], ['xxx']],
      "\ 'highlight': [['', 'e:Error'], ['xxx']],
      "\ 'imactivatekey': [['', 'S-space'], ['xxx']],
      \ 'isexpand': [['', '.,->', '/,/*,\\,'], [',,', '\\,,']],
      \ 'isfname': [['', '@', '@,48-52'], ['xxx', '@48']],
      \ 'isident': [['', '@', '@,48-52'], ['xxx', '@48']],
      \ 'iskeyword': [['', '@', '@,48-52'], ['xxx', '@48']],
      \ 'isprint': [['', '@', '@,48-52'], ['xxx', '@48']],
      \ 'jumpoptions': [['', 'stack'], ['xxx']],
      \ 'keymap': [['', 'accents'], ['/']],
      \ 'keymodel': [['', 'startsel', 'stopsel', 'startsel,stopsel'], ['xxx']],
      "\ 'keyprotocol': [['', 'xxx:none', 'yyy:mok2', 'zzz:kitty'],
      "\ "		['xxx', ':none', 'xxx:', 'x:non', 'y:mok3', 'z:kittty']],
      \ 'langmap': [['', 'xX', 'aA,bB'], ['xxx']],
      \ 'lispoptions': [['', 'expr:0', 'expr:1'], ['xxx', 'expr:x', 'expr:']],
      \ 'listchars': [['', 'eol:x', 'tab:xy', 'tab:xyz', 'space:x',
      \		'multispace:xxxy', 'lead:x', 'leadmultispace:xxxy', 'trail:x',
      \		'extends:x', 'precedes:x', 'conceal:x', 'nbsp:x', 'eol:\\x24',
      \		'eol:\\u21b5', 'eol:\\U000021b5', 'eol:x,space:y'],
      \		['xxx', 'eol:']],
      \ 'matchpairs': [['', '(:)', '(:),<:>'], ['xxx']],
      \ 'maxsearchcount': [[1, 10, 100, 1000], [0, -1, 10000]],
      \ 'messagesopt': [['hit-enter,history:1', 'hit-enter,history:10000',
      \		'history:100,wait:100', 'history:0,wait:0',
      \		'hit-enter,history:1,wait:1'],
      \		['xxx', 'history:500', 'hit-enter,history:-1',
      \		'hit-enter,history:10001', 'history:0,wait:10001',
      \		'hit-enter', 'history:10,wait:99999999999999999999',
      \		'history:99999999999999999999,wait:10', 'wait:10',
      \		'history:-10', 'history:10,wait:-10']],
      \ 'mkspellmem': [['10000,100,12'], ['', 'xxx', '10000,100']],
      \ 'mouse': [['', 'n', 'v', 'i', 'c', 'h', 'a', 'r', 'nvi'],
      \		['xxx', 'n,v,i']],
      \ 'mousemodel': [['extend', 'popup', 'popup_setpos'], ['xxx']],
      \ 'mouseshape': [['', 'n:arrow'], ['xxx']],
      \ 'nrformats': [['', 'alpha', 'octal', 'hex', 'bin', 'unsigned', 'blank',
      \		'alpha,hex,bin'],
      \		['xxx']],
      \ 'patchmode': [['', 'xxx', '.x'], [&backupext, '*']],
      "\ 'previewpopup': [['', 'height:13', 'width:20', 'highlight:That',
      "\ "		'align:item', 'align:menu', 'border:on', 'border:off',
      "\ "		'width:10,height:234,highlight:Mine'],
      "\ "		['xxx', 'xxx:99', 'height:yes', 'width:no', 'align:xxx',
      "\ "		'border:maybe', 'border:1', 'border:']],
      "\ 'printmbfont': [['', 'r:some', 'b:some', 'i:some', 'o:some', 'c:yes',
      "\ "		'c:no', 'a:yes', 'a:no', 'b:Bold,c:yes'],
      "\ "		['xxx', 'xxx,c:yes', 'xxx:', 'xxx:,c:yes']],
      "\ 'printoptions': [['', 'header:0', 'left:10pc,top:5pc'],
      "\ "		['xxx', 'header:-1']],
      "\ 'renderoptions': [[''], ['xxx']],
      \ 'rightleftcmd': [['search'], ['xxx']],
      \ 'rulerformat': [['', 'xxx'], ['%-', '%(', '%15(%%']],
      \ 'scrollopt': [['', 'ver', 'hor', 'jump', 'ver,hor'], ['xxx']],
      \ 'selection': [['old', 'inclusive', 'exclusive'], ['', 'xxx']],
      \ 'selectmode': [['', 'mouse', 'key', 'cmd', 'key,cmd'], ['xxx']],
      \ 'sessionoptions': [['', 'blank', 'curdir', 'sesdir',
      \		'help,options,slash'],
      \		['xxx', 'curdir,sesdir']],
      \ 'showcmdloc': [['last', 'statusline', 'tabline'], ['xxx']],
      "\ 'signcolumn': [['', 'auto', 'no', 'yes', 'number'], ['xxx', 'no,yes']],
      \ 'spellfile': [['', 'file.en.add', 'xxx.en.add,yyy.gb.add,zzz.ja.add',
      \		'/tmp/dir\ with\ space/en.utf-8.add',
      \		'/tmp/dir\\,with\\,comma/en.utf-8.add'],
      \		['xxx', '/tmp/file', '/tmp/dir*with:invalid?char/file.en.add',
      \		',file.en.add', 'xxx,yyy.en.add', 'xxx.en.add,yyy,zzz.ja.add']],
      \ 'spelllang': [['', 'xxx', 'sr@latin'], ['not&lang', "that\\\rthere"]],
      \ 'spelloptions': [['', 'camel'], ['xxx']],
      \ 'spellsuggest': [['', 'best', 'double', 'fast', '100', 'timeout:100',
      \		'timeout:-1', 'file:/tmp/file', 'expr:Func()', 'double,33'],
      \		['xxx', '-1', 'timeout:', 'best,double', 'double,fast']],
      \ 'splitkeep': [['cursor', 'screen', 'topline'], ['xxx']],
      \ 'statusline': [['', 'xxx'], ['%$', '%{', '%{%', '%{%}', '%(', '%)']],
      "\ 'swapsync': [['', 'sync', 'fsync'], ['xxx']],
      \ 'switchbuf': [['', 'useopen', 'usetab', 'split', 'vsplit', 'newtab',
      \		'uselast', 'split,newtab'],
      \		['xxx']],
      \ 'tabclose': [['', 'left', 'uselast', 'left,uselast'], ['xxx']],
      \ 'tabline': [['', 'xxx'], ['%$', '%{', '%{%', '%{%}', '%(', '%)']],
      \ 'tagcase': [['followic', 'followscs', 'ignore', 'match', 'smart'],
      \		['', 'xxx', 'smart,match']],
      \ 'termencoding': [has('gui_gtk') ? [] : ['', 'utf-8'], ['xxx']],
      "\ 'termwinkey': [['', 'f', '^Y', '^@', '<Esc>', '<t_xx>', "\u3042", '<',
      "\ "		'^'],
      "\ "		['<xxx>', '<t_xxx>', '<Esc', '<t_xx']],
      "\ 'termwinsize': [['', '24x80', '0x80', '32x0', '0x0'],
      "\ "		['xxx', '80', '8ax9', '24x80b']],
      "\ 'termwintype': [['', 'winpty', 'conpty'], ['xxx']],
      "\ 'titlestring': [['', 'xxx', '%('], []],
      "\ 'toolbar': [['', 'icons', 'text', 'horiz', 'tooltips', 'icons,text'],
      "\ "		['xxx']],
      "\ 'toolbariconsize': [['', 'tiny', 'small', 'medium', 'large', 'huge',
      "\ "		'giant'],
      "\ "		['xxx']],
      "\ 'ttymouse': [['', 'xterm'], ['xxx']],
      \ 'varsofttabstop': [['8', '4,8,16,32'], ['xxx', '-1', '4,-1,20', '1,']],
      \ 'vartabstop': [['8', '4,8,16,32'], ['xxx', '-1', '4,-1,20', '1,']],
      \ 'verbosefile': [['', './Xfile'], []],
      \ 'viewoptions': [['', 'cursor', 'folds', 'options', 'localoptions',
      \		'slash', 'unix', 'curdir', 'unix,slash'], ['xxx']],
      \ 'viminfo': [['', '''50', '"30', "'100,<50,s10,h"], ['xxx', 'h']],
      \ 'virtualedit': [['', 'block', 'insert', 'all', 'onemore', 'none',
      \		'NONE', 'all,block'],
      \		['xxx']],
      \ 'whichwrap': [['', 'b', 's', 'h', 'l', '<', '>', '~', '[', ']', 'b,s',
      \		'bs'],
      \		['xxx']],
      \ 'wildmode': [['', 'full', 'longest', 'list', 'lastused', 'list:full',
      \		'noselect', 'noselect,full', 'noselect:lastused,full',
      \		'full,longest', 'full,full,full,full'],
      \		['xxx', 'a4', 'full,full,full,full,full']],
      \ 'wildoptions': [['', 'tagfile', 'pum', 'fuzzy'], ['xxx']],
      \ 'winaltkeys': [['no', 'yes', 'menu'], ['', 'xxx']],
      \
      "\ skipped options
      "\ 'luadll': [[], []],
      "\ 'perldll': [[], []],
      "\ 'pythondll': [[], []],
      "\ 'pythonthreedll': [[], []],
      \ 'pyxversion': [[], []],
      "\ 'rubydll': [[], []],
      "\ 'tcldll': [[], []],
      \ 'term': [[], []],
      \ 'ttytype': [[], []],
      \
      "\ default behaviours
      \ 'othernum': [[-1, 0, 100], ['']],
      \ 'otherstring': [['', 'xxx'], []],
      \}

" Two lists with values: values that pre- and post-processing in test.
" Clear out t_WS: we don't want to resize the actual terminal.
let test_prepost = {
      \ 'browsedir': [["call mkdir('Xdir with space', 'D')"], []],
      \ 'columns': [[
      \		'set t_WS=',
      \		'let save_columns = &columns'
      \		], [
      \		'let &columns = save_columns',
      \		'set t_WS&'
      \		]],
      \ 'lines': [[
      \		'set t_WS=',
      \		'let save_lines = &lines'
      \		], [
      \		'let &lines = save_lines',
      \		'set t_WS&'
      \		]],
      \ 'verbosefile': [[], ['call delete("Xfile")']],
      \}

const invalid_options = test_values->keys()
      \->filter({-> v:val !~# '^other' && !exists($"&{v:val}")})
if !empty(invalid_options)
  throw $"Invalid option name in test_values: '{invalid_options->join("', '")}'"
endif

for option in options
  let fullname = option.full_name
  let shortname = get(option, 'abbreviation', fullname)

  if !exists('+' .. fullname)
    continue
  endif

  let [valid_values, invalid_values] = test_values[
	\ has_key(test_values, fullname) ? fullname
	\ : option.type == 'number' ? 'othernum'
	\ : 'otherstring']

  if empty(valid_values) && empty(invalid_values)
    continue
  endif

  call add(script, $"func Test_opt_set_{fullname}()")
  call add(script, $"if exists('+{fullname}') && execute('set!') =~# '\\n..{fullname}\\([=\\n]\\|$\\)'")
  call add(script, $"let l:saved = [&g:{fullname}, &l:{fullname}]")
  call add(script, 'endif')

  let [pre_processing, post_processing] = get(test_prepost, fullname, [[], []])
  let script += pre_processing

  if option.type == 'boolean'
    for opt in [fullname, shortname]
      for cmd in ['set', 'setlocal', 'setglobal']
	call add(script, $'{cmd} {opt}')
	call add(script, $'{cmd} no{opt}')
	call add(script, $'{cmd} inv{opt}')
	call add(script, $'{cmd} {opt}!')
      endfor
    endfor
  else  " P_NUM || P_STRING
    " Normal tests
    for opt in [fullname, shortname]
      for cmd in ['set', 'setlocal', 'setglobal']
	for val in valid_values
	  if local_noglobals->has_key(fullname) && cmd ==# 'setglobal'
	    " Skip `:setglobal {option}={val}` for local-noglobal option.
	    " It has no effect.
	    let pre = '" Skip local-noglobal: '
	  else
	    let pre = ''
	  endif
	  call add(script, $'{pre}{cmd} {opt}={val}')
	endfor
      endfor
      " Testing to clear the local value and switch back to the global value.
      if global_locals->has_key(fullname)
	let switchback_val = global_locals[fullname]
	call add(script, $'setlocal {opt}={switchback_val}')
	call add(script, $'call assert_equal(&g:{fullname}, &{fullname})')
      endif
    endfor

    " Failure tests
    " Setting an option can only fail when it's implemented.
    call add(script, $"if exists('+{fullname}')")
    for opt in [fullname, shortname]
      for cmd in ['set', 'setlocal', 'setglobal']
	for val in invalid_values
	  if val is# global_locals->get(fullname, {}) && cmd ==# 'setlocal'
	    " Skip setlocal switchback-value to global-local option. It will
	    " not result in failure.
	    let pre = '" Skip global-local: '
	  elseif local_noglobals->has_key(fullname) && cmd ==# 'setglobal'
	    " Skip setglobal to local-noglobal option. It will not result in
	    " failure.
	    let pre = '" Skip local-noglobal: '
	  elseif skip_setglobal_reasons->has_key(fullname) && cmd ==# 'setglobal'
	    " Skip setglobal to reasoned option. It will not result in failure.
	    let reason = skip_setglobal_reasons[fullname]
	    let pre = $'" Skip {reason}: '
	  else
	    let pre = ''
	  endif
	  let cmdline = $'{cmd} {opt}={val}'
	  call add(script, $"{pre}silent! call assert_fails({string(cmdline)})")
	endfor
      endfor
    endfor
    call add(script, "endif")
  endif

  " Cannot change 'termencoding' in GTK
  if fullname != 'termencoding' || !has('gui_gtk')
    call add(script, $'set {fullname}&')
    call add(script, $'set {shortname}&')
    call add(script, $"if exists('l:saved')")
    call add(script, $"let [&g:{fullname}, &l:{fullname}] = l:saved")
    call add(script, 'endif')
  endif

  let script += post_processing
  call add(script, 'endfunc')
endfor

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

endif

qa!

" vim:sw=2:ts=8:noet:nosta:
