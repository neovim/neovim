describe('parse_one_cmd errors', function()
  local t, itn
  do
    local _obj_0 = require('test.unit.viml.parser.helpers')(it)
    t, itn = _obj_0.t, _obj_0.itn
  end
  describe('NOFUNC commands errors', function()
    local _list_0 = {
      'intro',
      '<',
      'al',
      'as',
      'bN',
      'ba',
      'bf',
      'bl',
      'bm',
      'bp',
      'br',
      'brea',
      'buffers',
      'cN',
      'X',
      'xa',
      'wa',
      'viu',
      'unh',
      'undol',
      'undoj',
      'u',
      'try',
      'tr',
      'tp',
      'tn',
      'tl',
      'tf',
      'tabs',
      'tabr',
      'tabN',
      'tabp',
      'tabo',
      'tabn',
      'tabl',
      'tabfir',
      'tabc',
      'tags',
      'tN',
      'syncbind',
      'sw',
      'sus',
      'sun',
      'stopi',
      'startr',
      'startg',
      'star',
      'st',
      'spellr',
      'spelli',
      'spelld',
      'sh',
      'scrip',
      'sbr',
      'sbp',
      'sbn',
      'sbm',
      'sbl',
      'sbf',
      'sba',
      'sbN',
      'sal',
      'redraws',
      'redr',
      'red',
      'pw',
      'ptr',
      'ptn',
      'ptl',
      'ptf',
      'ptN',
      'pre',
      'pp',
      'po',
      'pc',
      'opt',
      'on',
      'ol',
      'noh',
      'nbc',
      'mes',
      'ls',
      'lw',
      'cw',
      'lr',
      'cr',
      'lpf',
      'cpf',
      'lNf',
      'cNf',
      'lp',
      'cp',
      'lN',
      'cN',
      'lop',
      'cope',
      'lol',
      'col',
      'lnew',
      'cnew',
      'lnf',
      'cnf',
      'lne',
      'cn',
      'lla',
      'cla',
      'll',
      'cc',
      'lfir',
      'cfir',
      'lcl',
      'ccl',
      'ju',
      'go',
      'foldo',
      'foldc',
      'fix',
      'fini',
      'fina',
      'files',
      'exu',
      'end',
      'endf',
      'endfo',
      'endt',
      'endw',
      'el',
      'difft',
      'diffo',
      'diffu',
      'debugg',
      'cq',
      'con',
      'comc',
      'clo',
      'che',
      'changes'
    }
    for _index_0 = 1, #_list_0 do
      local cmd = _list_0[_index_0]
      itn('\\ error: E488: Trailing characters: ' .. cmd .. ' !!a!!bc', cmd .. ' abc')
    end
  end)
  describe('commands with required argument', function()
    local _list_0 = {
      'norm',
      'luado',
      'perldo',
      'pydo',
      'py3do',
      'tcldo'
    }
    for _index_0 = 1, #_list_0 do
      local cmd = _list_0[_index_0]
      itn('\\ error: E471: Argument required: ' .. cmd .. '!!!', cmd)
    end
    local _list_1 = {
      'setf',
      'nbk'
    }
    for _index_0 = 1, #_list_1 do
      local cmd = _list_1[_index_0]
      itn('\\ error: E471: Argument required: !!!', cmd)
    end
  end)
  describe('invalid ++ff values', function()
    itn('\\ error: E474: Invalid ++ff argument: e++ff=!!u!!ix', 'e++ff=uix')
    itn('\\ error: E474: Invalid ++ff argument: e++ff=!!u!!ixtttt', 'e++ff=uixtttt')
    itn('\\ error: E474: Invalid ++ff argument: e++ff=!!d!!as', 'e++ff=das')
    itn('\\ error: E474: Invalid ++ff argument: e++ff=!!m!!as', 'e++ff=mas')
    return itn('\\ error: E474: Invalid ++ff argument: e++ff=!!t!!ty', 'e++ff=tty')
  end)
  describe(':call with non-call arguments', function()
    itn('\\ error: E129: :call accepts only function calls: call !!A!!bc', 'call Abc')
  end)
  describe(':autocmd', function()
    itn('autocmd GROUP * any().lit(abc) :\\ error: E492: Not an editor command: !!n!!ested',
    'au GROUP * *abc nested')
  end)
  itn('\\ error: E475: :behave command currently only supports mswin and xterm: !!m!!swi',
      'behave mswi')
  describe('debugging functions', function()
    itn('\\ error: E475: :profile command only accepts `func\', `file\', `start\', `pause\' and `continue\' as its first argument: !!f!!oo', 'profile foo')
    itn('\\ error: E750: Expected file name: start!!!', 'profile start')
    itn('\\ error: E475: Expecting function name or pattern: func!!!', 'breakadd func')
    itn('\\ error: E475: Expecting function name or pattern: func!!!', 'breakdel func')
    itn('\\ error: E475: Expecting function name or pattern: func13!!!', 'breakadd func13')
    itn('\\ error: E475: Expecting function name or pattern: func13!!!', 'breakdel func13')
    itn('\\ error: E475: Expecting function name or pattern: func!!!', 'profile func')
    itn('\\ error: E475: Expecting file name or pattern: file13!!!', 'breakadd file13')
    itn('\\ error: E475: Expecting file name or pattern: file13!!!', 'breakdel file13')
    itn('\\ error: E488: Trailing characters: here !!1!!23', 'breakadd here 123')
  end)
  describe(':cbuffer and friends', function()
    itn('\\ error: E474: Expected buffer number: 10!!a!!bc', 'caddbuffer10abc')
  end)
  describe(':clist and :llist', function()
    itn('\\ error: E488: Expected valid integer range: ,!!!', 'clist,')
    itn('\\ error: E488: Expected valid integer range: ,!!!', 'llist,')
  end)
  describe(':copy/:move/:t', function()
    itn('\\ error: E14: Invalid address: !!%!!', ':copy %')
  end)
  describe(':command', function()
    itn('\\ error: E183: User defined commands must start with an uppercase letter: command -BaR!!!', 'command -BaR')
    itn('\\ error: E183: User defined commands must start with an uppercase letter: command !!d!!ef', 'command def')
    itn('\\ error: E181: Invalid attribute: com-!!b!!ar-bang-buffer-register Abc', 'com-bar-bang-buffer-register Abc')
    itn('\\ error: E176: Invalid number of arguments: com-nargs=!!W!!TF Abc', 'com-nargs=WTF Abc')
    itn('\\ error: E176: Invalid number of arguments: com-nargs=!!W!! Abc', 'com-nargs=W Abc')
    itn('\\ error: E176: Invalid number of arguments: com-nargs=!!?!!Abc', 'com-nargs=?Abc')
    itn('\\ error: E176: Invalid number of arguments: com-nargs=!! !!Abc', 'com-nargs= Abc')
    itn('\\ error: E176: Invalid number of arguments: com-nargs!! !!Abc', 'com-nargs Abc')
    itn('\\ error: E177: Count cannot be specified twice: com-range=1 -count=!!1!! Abc', 'com-range=1 -count=1 Abc')
    itn('\\ error: E177: Count cannot be specified twice: com-count=1 -count=!!1!! Abc', 'com-count=1 -count=1 Abc')
    itn('\\ error: E177: Count cannot be specified twice: com-range=1 -range=!!1!! Abc', 'com-range=1 -range=1 Abc')
    itn('\\ error: E179: Argument required for -complete: com-complete!! !!Abc', 'com-complete Abc')
    itn('\\ error: E180: Invalid complete value: com-complete=!!x!!xx Abc', 'com-complete=xxx Abc')
    itn('\\ error: E468: Completion argument only allowed for custom completion: com-complete=dir!!,!!abc Abc', 'com-complete=dir,abc Abc')
    itn('\\ error: E467: Custom completion requires a function argument: com-complete=custom!! !!Abc', 'com-complete=custom Abc')
    itn('\\ error: E467: Custom completion requires a function argument: com-complete=customlist!! !!Abc', 'com-complete=customlist Abc')
  end)
  describe('yank, delete, put', function()
    itn('\\ error: E850: Invalid register name: yank !!=!!', 'yank =')
    itn('\\ error: E850: Invalid register name: delete !!=!!', 'delete =')
    itn('\\ error: E850: Invalid register name: delete !!%!!', 'delete %')
    itn('\\ error: E850: Invalid register name: put !!\x1B!!', 'put \x1B')
  end)
  describe(':delmarks', function()
    itn('\\ error: E471: You must specify register(s): !!!', 'delm')
    itn('\\ error: E474: :delmarks must be called either without bang or without arguments: !!a!!', 'delm!a')
    itn('\\ error: E475: Trying to construct range out of marks from different sets: 1-!!z!!', 'delm1-z')
    itn('\\ error: E475: Upper range bound is less then lower range bound: 9-!!0!!', 'delm9-0')
    itn('\\ error: E475: Unknown mark: !!-!!', 'delm-')
  end)
  describe(':digraphs', function()
    itn('\\ error: E474: Expected second digraph character, but got nothing: +!!!', 'dig+')
    itn('\\ error: E39: Number expected: ++!!!', 'dig++')
    itn('\\ error: E104: Escape not allowed in digraph: !!\x1B!!+10', 'dig\x1B+10')
    itn('\\ error: E104: Escape not allowed in digraph: +!!\x1B!!10', 'dig+\x1B10')
  end)
  describe(':doautocmd/:doautoall', function()
    itn('\\ error: E217: Can\'t execute autocommands for ALL events: !!*!!', 'do*')
    itn('\\ error: E217: Can\'t execute autocommands for ALL events: !!*!!', 'doautoall*')
  end)
  describe(':later/:earlier', function()
    itn('\\ error: E475: Expected numeric argument: !!x!!', 'later x')
    itn('\\ error: E475: Trailing characters: 10m!!x!!', 'earlier 10mx')
    itn('\\ error: E475: Expected \'s\', \'m\', \'h\', \'d\', \'f\' or nothing after number: 10!!x!!', 'later 10x')
  end)
  describe(':filetype', function()
    itn('\\ error: E475: Invalid syntax: expected `filetype[ [plugin|indent]... {on|off|detect}]\': !!x!!', 'filet x')
  end)
  describe(':history', function()
    itn('\\ error: E488: Expected history name or nothing: !!g!!arbage', 'his garbage')
    itn('\\ error: E488: Expected valid history lines range: ,!!!', 'his ,')
    itn('\\ error: E488: Trailing characters: ,0 !!a!!bc', 'his ,0 abc')
  end)
  describe(':mark', function()
    itn('\\ error: E471: Expected mark name: !!!', 'k')
    itn('\\ error: E471: Expected mark name: !!!', 'mark')
    itn('\\ error: E488: Trailing characters: g!!a!!rbage', 'mark garbage')
    itn('\\ error: E477: No ! allowed: k!!!!!', 'k!')
    itn('\\ error: E191: Argument must be a letter or forward/backward quote: !!-!!', 'k-')
    itn('\\ error: E191: Argument must be a letter or forward/backward quote: !!-!!', 'mark-')
  end)
  describe(':retab', function()
    itn('\\ error: E487: Argument must be positive: !!-!!2', 'retab-2')
  end)
  describe(':redir', function()
    itn('\\ error: E475: Expected `END\', `>[>] {file}\', `@{register}[>[>]]\' or `=> {variable}\': !!!', 'redir')
    itn('\\ error: E475: Expected `END\': e!!!', 'redir e')
    itn('\\ error: E475: Expected register name; one of A-Z, a-z, ", * and +: @!!?!!', 'redir@?')
    itn('\\ error: E488: Trailing characters: @g!!a!!rbage', 'redir @garbage')
    itn('\\ error: E475: Expected `>\' and variable name: =!! !!foo', 'redir = foo')
  end)
  describe(':[v]global', function()
    itn('\\ error: E477: No ! allowed: v!!!!!/abc/', 'v!/abc/')
    itn('\\ error: E148: Regular expression missing from global: g!!!!', 'g!')
  end)
  describe(':[l]vimgrep[add]', function()
    itn('\\ error: E683: File name missing or invalid pattern: vimgrep /abc/!!!', 'vimgrep /abc/')
    itn('\\ error: E683: File name missing or invalid pattern: lvimgrep /abc/!!!', 'lvimgrep /abc/')
    itn('\\ error: E683: File name missing or invalid pattern: vimgrepadd /abc/!!!', 'vimgrepadd /abc/')
    itn('\\ error: E683: File name missing or invalid pattern: lvimgrepadd /abc/!!!', 'lvimgrepadd /abc/')
  end)
  describe(':match', function()
    itn('\\ error: E475: Expected regular expression: match HlGroup!!!', 'match HlGroup')
  end)
  describe(':set/:setlocal/:setglobal', function()
    itn('\\ error: E521: Number required after =: aleph=!!a!!bc', 'set aleph=abc')
    itn('\\ error: E474: Only numbers are allowed: aleph=!!0!!xAR', 'set aleph=0xAR')
    itn('\\ error: E474: Only numbers are allowed: aleph=!!0!!F', 'set aleph=0F')
    itn('\\ error: E521: Number required after =: aleph=!!!', 'set aleph=')
    itn('\\ error: E518: Unknown option: !!x!!xx', 'set xxx')
    itn('\\ error: E474: Cannot set boolean options with `=\' or `:\': nu!!=!!yes', 'set nu=yes')
    itn('\\ error: E474: Expected `<\': <C-a!!!', 'set <C-a')
    itn('\\ error: E474: Cannot invert or unset non-boolean option: !!n!!ocb', 'set nocb')
    itn('\\ error: E474: Cannot invert or unset non-boolean option: !!i!!nvcb', 'set invcb')
    itn('\\ error: E521: Number required after =: al=!!<!!Tab>', 'set al=<Tab>')
    itn('\\ error: E474: Expected key definition: wcm=!!<!!C-a', 'set wcm=<C-a')
    itn('\\ error: E474: Expected `=\', `:\', `&\' or `<\': nocb!!-!!', 'set nocb-')
    itn('\\ error: E488: Trailing characters: cb!!-!!', 'set cb-')
  end)
  describe(':sleep', function()
    itn('\\ error: E475: Expected `m\' or nothing: !!x!!', 'sleep 1x')
  end)
  describe(':substitute', function()
    itn('\\ error: E146: Regular expressions can\'t be delimited by letters: s !!a!!bcadeag', 's abcadeag')
    itn('\\ error: E10: \\ should be followed by /, ? or &: s\\!!a!!bcag', 's\\abcag')
    itn('\\ error: E15: expected expr7 (value): s/a/\\=(b+!!)!!/', 's/a/\\=(b+)/')
    itn('\\ error: Zero count: s///!!0!!', 's///0')
    itn('\\ error: E475: Expected sort flag or non-ASCII regular expression delimiter: sort !!a!!', 'sort a')
    itn('\\ error: E474: Can only specify one kind of numeric sort: sort n!!o!!', 'sort no')
    itn('\\ error: E474: Can only specify one kind of numeric sort: sort n!!x!!', 'sort nx')
    itn('\\ error: E474: Can only specify one kind of numeric sort: sort o!!x!!', 'sort ox')
    itn('\\ error: E474: Can only specify one kind of numeric sort: sort o!!n!!', 'sort on')
    itn('\\ error: E474: Can only specify one kind of numeric sort: sort o!!n!!', 'sort on')
    itn('\\ error: E474: Can only specify one kind of numeric sort: sort x!!n!!', 'sort xn')
    itn('\\ error: E474: Can only specify one kind of numeric sort: sort x!!o!!', 'sort xo')
    itn('\\ error: E474: Can only specify one kind of numeric sort: sort n!!o!!', 'sort no')
    itn('\\ error: E682: Invalid search pattern or delimiter: sort /!!!', 'sort /')
    itn('\\ error: E682: Invalid search pattern or delimiter: sort /abc!!!', 'sort /abc')
    itn('\\ error: Zero count: !!0!!', '&0')
    itn('\\ error: Zero count: !!0!!', '~0')
  end)
  describe(':spell*', function()
    itn('\\ error: E471: Argument required: !!!', 'spe')
    itn('\\ error: E471: Argument required: !!!', 'spellw')
    itn('\\ error: E471: Argument required: !!!', 'spellu')
  end)
  describe(':syntime', function()
    itn('\\ error: E475: Expected one action of `on\', `off\', `clear\' or `report\': !!!', 'syntime')
    itn('\\ error: E475: Expected one action of `on\', `off\', `clear\' or `report\': !!x!!xx', 'syntime xxx')
  end)
  describe(':winsize/:winpos', function()
    itn('\\ error: E465: :winsize requires two number arguments: !!!', 'winsize')
    itn('\\ error: E466: :winpos requires two number arguments: 1!!!', 'winpos 1')
    itn('\\ error: E465: :winsize requires two number arguments: -10!!!', 'winsize-10')
  end)
  describe(':wincmd', function()
    itn('\\ error: E471: Argument required: wincmd!!!', 'wincmd')
    itn('\\ error: E474: Trailing characters: wincmd w!!+!!', 'wincmd w+')
    itn('\\ error: E474: Trailing characters: wincmd gw!!+!!', 'wincmd gw+')
    itn('\\ error: E474: Expected extended window action (see help tags starting with CTRL-W_g): wincmd g!!!', 'wincmd g')
    itn('\\ error: E474: Trailing characters: wincmd|!!e!!cho "abc"', 'wincmd|echo "abc"')
    itn('\\ error: E474: Trailing characters: wincmd g|!!e!!cho "abc"', 'wincmd g|echo "abc"')
  end)
  describe(':z', function()
    itn('\\ error: E144: non-numeric argument to :z: +!! !!10', 'z+ 10')
    itn('\\ error: E144: non-numeric argument to :z: ++--!!.!! 10', 'z ++--. 10')
  end)
  describe(':@/:*', function()
    itn('\\ error: E850: Invalid register name: !!^!!', '@^')
  end)
  describe(':(l)helpg', function()
    itn('\\ error: E471: Argument required: helpg!!!', 'helpg')
    itn('\\ error: E471: Argument required: lh!!!', 'lh')
  end)
  describe(':cstag', function()
    itn('\\ error: E562: Usage: cstag <ident>: !!!', 'cstag')
  end)
  describe(':helptags', function()
    itn('\\ error: E471: Argument required: helpt!!!', 'helpt')
  end)
  describe(':write', function()
    itn('\\ error: E494: Use w or w>>: w>!!a!!bc', 'w>abc')
  end)
  describe(':loadkeymap', function()
    itn('\\ error: E488: Trailing characters: loadkeymap!!-!!', 'loadkeymap-')
    itn('\\ error: E791: Empty RHS: -!!!', 'loadkeymap\n-')
    itn('\\ error: E791: Empty RHS: - !!!', 'loadkeymap\n- ')
    itn('\\ error: E791: Empty LHS: !! !!', 'loadkeymap\n ')
    itn('\\ error: E791: Empty LHS: !! !!-', 'loadkeymap\n -')
  end)
  describe(':menutranslate', function()
    itn('\\ error: E474: Expected string that is to be translated: menut!!!', 'menut')
    itn('\\ error: E474: Expected translated string: menut Foo!!!', 'menut Foo')
    itn('\\ error: E474: Expected translated string: menut Foo !!!', 'menut Foo ')
    itn('\\ error: E474: Expected no submenus: menut Foo!!.!!Bar Baz', 'menut Foo.Bar Baz')
    itn('\\ error: E474: Expected no submenus: menut FooBar Baz!!.!!Blah', 'menut FooBar Baz.Blah')
  end)
  describe(':cscope', function()
    itn('\\ error: E560: Usage: cs[cope] add file|dir [pre-path] [flags]: a!!!', 'cs a')
    itn('\\ error: E560: Usage: cs[cope] find c|d|e|f|g|i|s|t name: fin!!!', 'cs fin')
    itn('\\ error: E560: Usage: cs[cope] find c|d|e|f|g|i|s|t name: fin c!!!', 'cs fin c')
    itn('\\ error: E561: unknown cscope search type: fin !!x!! foo', 'cs fin x foo')
  end)
  describe(':highlight', function()
    itn('\\ error: E412: Not enough arguments to :highlight link: def link Foo!!!', 'hi def link Foo')
    itn('\\ error: E412: Not enough arguments to :highlight link: link Foo!!!', 'hi link Foo')
    itn('\\ error: E413: Too many arguments to :highlight link: def link Foo Bar !!B!!az', 'hi def link Foo Bar Baz')
    itn('\\ error: E413: Too many arguments to :highlight link: link Foo Bar !!B!!az', 'hi link Foo Bar Baz')
    itn('\\ error: E415: Unexpected equal sign: Foo !!=!!bold', 'hi Foo =bold')
    itn('\\ error: E416: Missing equal sign: Foo bold!!!', 'hi Foo bold')
    itn('\\ error: E475: Missing closing quote: Foo font=!!\'!!Comic Sans Ms', 'hi Foo font=\'Comic Sans Ms')
    itn('\\ error: E417: Missing argument: Foo cterm=!!!', 'hi Foo cterm=')
    itn('\\ error: E418: Illegal attribute name: Foo cterm=!!x!!xxunknownattrxxx', 'hi Foo cterm=xxxunknownattrxxx')
    itn('\\ error: E423: Unknown property name: Foo !!x!!xxunknownpropxxx=bold', 'hi Foo xxxunknownpropxxx=bold')
    itn('\\ error: E475: Missing closing quote: Foo font=!!\'!!F', 'hi Foo font=\'F | G\'')
  end)
  describe(':sign', function()
    itn('\\ error: E239: Non-printable character in sign text: sign define Foo text=!!\27!!', 'sign define Foo text=\27')
    itn('\\ error: E239: Sign text is too narrow: sign define Foo text=!!1!!', 'sign define Foo text=1')
    itn('\\ error: E239: Sign text is too wide: sign define Foo text=!!1!!23', 'sign define Foo text=123')
    itn('\\ error: E475: Unknown sign property: sign define Foo !!x!!xx=>>', 'sign define Foo xxx=>>')
    itn('\\ error: E474: Cannot use `*\' when identifier was already given: sign unplace 1 !!*!!', 'sign unplace 1 *')
    itn('\\ error: E474: Unknown property: sign place 1 !!f!!oo', 'sign place 1 foo')
    itn('\\ error: E474: Must provide either buffer= or file= as the last argument: sign place 1 line=10 name=Foo!!!', 'sign place 1 line=10 name=Foo')
    itn('\\ error: E474: Cannot use zero as sign id: sign place !!0!! line=10 name=Foo buffer=1', 'sign place 0 line=10 name=Foo buffer=1')
    itn('\\ error: E474: Cannot use line= and name= without a sign id: sign place line=!!1!!0 buffer=1', 'sign place line=10 buffer=1')
    itn('\\ error: E474: Cannot use line= and name= with :sign jump: sign jump 10 line=!!1!!0 buffer=1', 'sign jump 10 line=10 buffer=1')
    itn('\\ error: E474: Cannot use line= and name= with :sign unplace: sign unplace 10 line=!!1!!0 buffer=1', 'sign unplace 10 line=10 buffer=1')
    itn('\\ error: E474: Cannot use line= and name= with :sign jump: sign jump 10 name=!!1!!0 buffer=1', 'sign jump 10 name=10 buffer=1')
    itn('\\ error: E474: Cannot use line= and name= with :sign unplace: sign unplace 10 name=!!1!!0 buffer=1', 'sign unplace 10 name=10 buffer=1')
    itn('\\ error: E474: Missing sign name: sign place 10 line=10 buffer=1!!!', 'sign place 10 line=10 buffer=1')
    itn('\\ error: E488: buffer= argument must be the last one: sign place 10 buffer=1 !!l!!ine=10', 'sign place 10 buffer=1 line=10')
    itn('\\ error: E158: Buffer number can only be positive: sign place 10 line=10 name=Foo buffer=!!-!!10', 'sign place 10 line=10 name=Foo buffer=-10')
    itn('\\ error: E885: Can only use positive line numbers: sign place 1 line=!!-!!1', 'sign place 1 line=-1')
    itn('\\ error: E156: Missing sign name: sign define!!!', 'sign define')
    itn('\\ error: E471: Argument required: sign!!!', 'sign')
    itn('\\ error: E160: Unknown sign command: sig !!x!!xxunexistentsubcommandxxx', 'sig xxxunexistentsubcommandxxx')
    itn('\\ error: E471: Argument required: sign jump!!!', 'sign jump')
    itn('\\ error: E474: Must provide either buffer= or file= as the last argument: sign jump 10!!!', 'sign jump 10')
  end)
  describe(':syntax', function()
    itn('\\ error: E390: Expected match or ignore: syntax case!!!', 'syntax case')
    itn('\\ error: E390: Expected on or off: syntax conceal!!!', 'syntax conceal')
    itn('\\ error: E475: Expected group name followed by an argument: syntax cluster!!!', 'syntax cluster')
    itn('\\ error: E475: Expected group name followed by an argument: syntax cluster Foo!!!', 'syntax cluster Foo')
    itn('\\ error: E402: Expected offset anchor designator (`s\' or `e\'): syn match Foo /e/ms=!!x!!', 'syn match Foo /e/ms=x')
    itn('\\ error: E402: Garbage after pattern: syn match Foo /e/ms=s+10!!x!!', 'syn match Foo /e/ms=s+10x')
    itn('\\ error: E402: Garbage after pattern: syntax match Foo /e/!!x!!', 'syntax match Foo /e/x')
    itn('\\ error: E399: Expected group name: syn region Foo start=/a/ end=/b/ matchgroup=!!!', 'syn region Foo start=/a/ end=/b/ matchgroup=')
    itn('\\ error: E399: Expected syntax pattern: syn region Foo start=/a/ end=!!!', 'syn region Foo start=/a/ end=')
    itn('\\ error: E399: Expected syntax pattern: syn region Foo end=/e/ start=!!!', 'syn region Foo end=/e/ start=')
    itn('\\ error: E399: Expected syntax pattern: syn region Foo start=/a/ end=/e/ skip=!!!', 'syn region Foo start=/a/ end=/e/ skip=')
    itn('\\ error: E404: Expected `=number\': syntax sync lines!!=!!x', 'syntax sync lines=x')
    itn('\\ error: E404: Expected `=number\': syntax sync lines!!!', 'syntax sync lines')
    itn('\\ error: E404: Pattern end not found: syntax sync linecont !!/!!foo', 'syntax sync linecont /foo')
    itn('\\ error: E404: Unknown argument: syntax sync !!x!!xx', 'syntax sync xxx')
    itn('\\ error: E475: Expected group name: syntax keyword!!!', 'syntax keyword')
    itn('\\ error: E475: Expected keywords: syntax keyword Foo!!!', 'syntax keyword Foo')
    itn('\\ error: E475: Expected group name followed by an argument: syntax match!!!', 'syntax match')
    itn('\\ error: E475: Expected group name followed by an argument: syn match Foo!!!', 'syn match Foo')
    itn('\\ error: E475: Trailing characters: syntax match Foo /bar/ !!/!!bar/', 'syntax match Foo /bar/ /bar/')
    itn('\\ error: E406: Empty argument: syntax region Foo nextgroup=!!!', 'syntax region Foo nextgroup=')
    itn('\\ error: E401: Pattern delimiter not found: syn sync match Foo grouphere foo !!g!!ropthere bar /abc/', 'syn sync match Foo grouphere foo gropthere bar /abc/')
  end)
  describe(':edit patterns', function()
    itn('\\ error: E16: Invalid range: end is greater then start: e [z!!-!!a]', 'e [z-a]')
  end)
  describe('errors in expressions', function()
    -- Regression test: used to report wrong location of the quote paired with 
    -- missing.
    itn('\\ error: E114: Missing quote: call A3v(\'a3v_1\', \'a3v_2\', \'a3v_3\', \'a3v_4\', !!\'!!a3v_5)', 'call A3v(\'a3v_1\', \'a3v_2\', \'a3v_3\', \'a3v_4\', \'a3v_5)')
  end)
end)
return describe('parse_cmd_sequence errors', function()
  local t, itn
  do
    local _obj_0 = require('test.unit.viml.parser.helpers')(it)
    t, itn = _obj_0.t, _obj_0.itn
  end
  return describe('missing block ends', function()
    t([[
    if 1
    \ error: E171: Missing :endif:     endfor!!!
    \ error: E588: :endfor without :for:     endfor!!!
    ]], [[
    if 1
    endfor]])
    t('\n    if 1\n    endif\n    \\ error: E580: :endif without :if:     endif!!!\n    ', '\n    if 1\n    endif\n    endif')
    t('\n    if 1\n    endif\n    \\ error: E580: :endif without :if:     endif !!|!! if 1 | endif\n    if 1\n    endif\n    ', '\n    if 1\n    endif\n    endif | if 1 | endif')
    t('\n    \\ error: E606: :finally without :try:     finally!!!\n    \\ error: E602: :endtry without :try:     endtry!!!\n    ', '\n    finally\n    endtry\n    ')
    return t('\n    if 1\n      if 1\n        echo 1\n      else\n        echo 2\n      \\ error: E583: multiple :else:       else!!!\n        echo 3\n      \\ error: E583: multiple :else:       else!!!\n        echo 4\n      endif\n    endif\n    echo 6\n    for x in x\n      echo 7\n    \\ error: E733: Using :endwhile with :for:     endwhile!!!\n    echo 8\n    ', '\n    if 1\n      if 1\n        echo 1\n      else\n        echo 2\n      else\n        echo 3\n      else\n        echo 4\n      endif\n    endif\n    echo 6\n    for x in x\n      echo 7\n    endwhile\n    echo 8')
  end)
end)
