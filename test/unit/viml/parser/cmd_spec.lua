return describe('parse_one_cmd', function()
  local itn
  do
    local _obj_0 = require('test.unit.viml.parser.helpers')(it)
    itn = _obj_0.itn
  end
  describe('no commands', function()
    itn('1,2print', '1,2|')
    itn('1', '1')
    itn('1,2', '1,2')
    itn('/abc/', '/abc')
    itn('?abc?', '?abc')
    itn('/abc//def/')
    itn('?abc?/def/')
    itn('/abc//def/', '/abc//def')
    return itn('?abc?/def/', '?abc?/def')
  end)
  describe('modifier commands', function()
    itn('belowright 9join', 'bel 9join')
    itn('aboveleft join', 'aboveleft join')
    itn('aboveleft join', 'abo join')
    itn('belowright join', 'bel join')
    itn('botright join', 'bo join')
    itn('browse join', 'bro join')
    itn('confirm join', 'conf join')
    itn('hide join', 'hid join')
    itn('keepalt join', 'keepa join')
    itn('keeppatterns join', 'keepp join')
    itn('keepjumps join', 'keepj join')
    itn('keepmarks join', 'keepm join')
    itn('leftabove join', 'lefta join')
    itn('lockmarks join', 'loc   j')
    itn('noautocmd join', 'noa   j')
    itn('noswapfile edit', 'nos\te')
    itn('rightbelow join', 'rightb join')
    itn('sandbox join', 'san   j')
    itn('silent join', 'sil   j')
    itn('silent! join', 'sil!   j')
    itn('tab join', 'tab j')
    itn('tab 5 join', '5tab j')
    itn('topleft join', 'to j')
    itn('unsilent join', 'uns j')
    itn('verbose join', 'verb j')
    itn('verbose 1 join', '1verb j')
    itn('vertical join', 'vert j')
  end)
  describe('ranges', function()
    itn('1,2join', ':1,2join')
    itn('1,2join!', ':::::::1,2join!')
    itn('1,2,3,4join!', ':::::::1,2,3,4join!')
    itn('1join!', ':1      join!')
    itn('1,$join', ':%join')
    itn('\'<,\'>join', ':*join')
    itn('1+1;7+1+2+3join', ':1+1;7+1+2+3join')
    itn('\\&join', '\\&j')
    itn('\\/join', '\\/j')
    itn('\\?join', '\\?j')
    return itn('.-1-1-1join', '---join')
  end)
  describe('count and exflags', function()
    itn('join #', ':join #')
    itn('join 5 #', ':join 5 #')
    itn('join #', ':join#')
    itn('join 5 #', ':join5#')
    itn('join #', ':j#')
    itn('number #', ':num#')
    itn('print l', ':p l')
    itn('# #', ':##')
    itn('# l', ':#l')
    itn('= l', ':=l')
    itn('> l', ':>l')
    itn('number 5 #', ':num5#')
    itn('print 5 l', ':p 5l')
    itn('# 1 #', ':#1#')
    itn('> 3 l', ':>3l')
    return itn('< 3', ':<3')
  end)
  describe('NOFUNC commands', function()
    itn('intro', 'intro')
    itn('intro', ':intro')
    itn('<', ':<')
    itn('all', ':all')
    itn('5all', ':5all')
    itn('all 5', ':all5')
    itn('all 5', ':al5')
    itn('ascii', ':ascii')
    itn('bNext', ':bN')
    itn('bNext 5', ':bN5')
    itn('ball', ':ba')
    itn('bfirst', ':bf')
    itn('blast', ':bl')
    itn('bmodified!', ':bm!')
    itn('bnext', ':bn')
    itn('bprevious 5', ':bp5')
    itn('brewind', ':br')
    itn('break', ':brea')
    itn('breaklist', ':breakl')
    itn('buffers', ':buffers')
    itn('cNext', ':cN')
    itn('X', ':X')
    itn('xall', ':xa')
    itn('wall', ':wa')
    itn('viusage', ':viu')
    itn('version', ':ver')
    itn('unhide', ':unh')
    itn('undolist', ':undol')
    itn('undojoin', ':undoj')
    itn('undo 5', ':u5')
    itn('try', ':try')
    itn('trewind', ':tr')
    itn('tprevious', ':tp')
    itn('tnext', ':tn')
    itn('tlast', ':tl')
    itn('tfirst', ':tf')
    itn('tabs', ':tabs')
    itn('tabrewind', ':tabr')
    itn('tabNext', ':tabN')
    itn('5tabNext', ':5tabN')
    itn('5tabprevious', ':5tabp')
    itn('tabonly!', ':tabo!')
    itn('5tabnext', ':5tabn')
    itn('tablast', ':tabl')
    itn('tabfirst', ':tabfir')
    itn('tabclose! 1', ':tabc!1')
    itn('1tabclose!', ':1tabc!')
    itn('tags', ':tags')
    itn('5tNext!', ':5tN!')
    itn('syncbind', ':syncbind')
    itn('swapname', ':sw')
    itn('suspend!', ':sus!')
    itn('sunhide 5', ':sun5')
    itn('stopinsert', ':stopi')
    itn('startreplace!', ':startr!')
    itn('startgreplace!', ':startg!')
    itn('startinsert!', ':star!')
    itn('stop!', ':st!')
    itn('spellrepall', ':spellr')
    itn('spellinfo', ':spelli')
    itn('spelldump!', ':spelld!')
    itn('shell', ':sh')
    itn('scriptnames', ':scrip')
    itn('sbrewind', ':sbr')
    itn('sbprevious', ':sbp')
    itn('sbnext', ':sbn')
    itn('sbmodified 5', ':sbm 5')
    itn('sblast', ':sbl')
    itn('sbfirst', ':sbf')
    itn('sball 5', ':sba5')
    itn('5sball', ':5sba')
    itn('sbNext 5', ':sbN5')
    itn('5sbNext', ':5sbN')
    itn('sall! 5', ':sal!5')
    itn('5sall!', ':5sal!')
    itn('redrawstatus!', ':redraws!')
    itn('redraw!', ':redr!')
    itn('redo', ':red')
    itn('pwd', ':pw')
    itn('5ptrewind!', ':5ptr!')
    itn('5ptprevious!', ':5ptp!')
    itn('5ptnext!', ':5ptn!')
    itn('ptlast!', ':ptl!')
    itn('5ptfirst!', ':5ptf!')
    itn('5ptNext!', ':5ptN!')
    itn('preserve', ':pre')
    itn('5ppop!', ':5pp!')
    itn('5pop!', ':5po!')
    itn('pclose!', ':pc!')
    itn('options', ':opt')
    itn('only!', ':on!')
    itn('oldfiles', ':ol')
    itn('nohlsearch', ':noh')
    itn('nbclose', ':nbc')
    itn('messages', ':mes')
    itn('ls!', ':ls!')
    itn('lwindow 5', ':lw 5')
    itn('5lwindow', ':5lw')
    itn('cwindow 5', ':cw 5')
    itn('5cwindow', ':5cw')
    itn('lrewind 5', ':lr 5')
    itn('5lrewind', ':5lr')
    itn('crewind 5', ':cr 5')
    itn('5crewind', ':5cr')
    itn('lpfile 5', ':lpf 5')
    itn('5lpfile', ':5lpf')
    itn('cpfile 5', ':cpf 5')
    itn('5cpfile', ':5cpf')
    itn('lNfile 5', ':lNf 5')
    itn('5lNfile', ':5lNf')
    itn('cNfile 5', ':cNf 5')
    itn('5cNfile', ':5cNf')
    itn('lprevious 5', ':lp 5')
    itn('5lprevious', ':5lp')
    itn('cprevious 5', ':cp 5')
    itn('5cprevious', ':5cp')
    itn('lNext 5', ':lN 5')
    itn('5lNext', ':5lN')
    itn('cNext 5', ':cN 5')
    itn('5cNext', ':5cN')
    itn('lopen 5', ':lop 5')
    itn('5lopen', ':5lop')
    itn('copen 5', ':cope 5')
    itn('5copen', ':5cope')
    itn('lolder 5', ':lol 5')
    itn('5lolder', ':5lol')
    itn('colder 5', ':col 5')
    itn('5colder', ':5col')
    itn('lnewer 5', ':lnew 5')
    itn('5lnewer', ':5lnew')
    itn('cnewer 5', ':cnew 5')
    itn('5cnewer', ':5cnew')
    itn('5lnfile!', '5lnf!')
    itn('lnfile! 5', 'lnf! 5')
    itn('5cnfile!', '5cnf!')
    itn('cnfile! 5', 'cnf! 5')
    itn('5lnext!', '5lne!')
    itn('lnext! 5', 'lne! 5')
    itn('5cnext!', '5cn!')
    itn('cnext! 5', 'cn! 5')
    itn('5llast!', '5lla!')
    itn('llast! 5', 'lla! 5')
    itn('5clast!', '5cla!')
    itn('clast! 5', 'cla! 5')
    itn('5ll!', '5ll!')
    itn('ll! 5', 'll! 5')
    itn('5cc!', '5cc!')
    itn('cc! 5', 'cc! 5')
    itn('lfirst 5', ':lfir 5')
    itn('5lfirst', ':5lfir')
    itn('cfirst 5', ':cfir 5')
    itn('5cfirst', ':5cfir')
    itn('lclose 5', ':lcl 5')
    itn('5lclose', ':5lcl')
    itn('cclose 5', ':ccl 5')
    itn('5cclose', ':5ccl')
    itn('jumps', ':ju')
    itn('helpfind', ':helpf')
    itn('5goto 1', ':5go1')
    itn('5,1foldopen!', ':5,1foldo!')
    itn('5,1foldclose!', ':5,1foldc!')
    itn('5,1fold', ':5,1fold')
    itn('fixdel', 'fixdel')
    itn('fixdel', 'fix')
    itn('finish', 'fini')
    itn('finally', 'fina')
    itn('files!', 'files!')
    itn('exusage', 'exu')
    itn('endif', 'end')
    itn('endfunction', 'endf')
    itn('endfor', 'endfo')
    itn('endtry', 'endt')
    itn('endwhile', 'endw')
    itn('else', 'el')
    itn('enew', 'ene')
    itn('enew!', 'ene!')
    itn('diffthis', 'difft')
    itn('diffoff!', 'diffo!')
    itn('diffupdate!', 'diffu!')
    itn('0debuggreedy', '0debugg')
    itn('cquit!', 'cq!')
    itn('continue', 'con')
    itn('comclear', 'comc')
    itn('close!', 'clo!')
    itn('checkpath!', 'che!')
    itn('changes', ':changes')
    itn('quit', 'q')
    itn('quit!', 'q!')
    itn('qall', 'qa')
    itn('qall!', 'qa!')
    itn('quitall', 'quita')
    return itn('quitall!', 'quita!')
  end)
  describe('append/insert/change commands', function()
    itn('append\n.', 'a')
    itn('insert\n.', 'i')
    itn('change\n.', 'c')
    itn('append!\n.', 'a!')
    itn('insert!\n.', 'i!')
    itn('change!\n.', 'c!')
    itn('1,2append!\n.', '1,2a!')
    itn('1,2insert!\n.', '1,2i!')
    itn('1,2change!\n.', '1,2c!')
    itn('append\nabc\n.', 'a\nabc\n.')
    itn('insert\nabc\n.', 'i\nabc\n.')
    itn('change\nabc\n.', 'c\nabc\n.')
    itn('append\n  abc\n.', 'a\n  abc\n.')
    itn('insert\n  abc\n.', 'i\n  abc\n.')
    itn('change\n  abc\n.', 'c\n  abc\n.')
    itn('append\n  abc\n.', 'a\n  abc\n  .')
    itn('insert\n  abc\n.', 'i\n  abc\n  .')
    return itn('change\n  abc\n.', 'c\n  abc\n  .')
  end)
  describe(':*map/:*abbrev (but not *unmap/*unabbrev) commands', function()
    for trunc, full in pairs({
      map = 'map',
      ['map!'] = 'map!',
      nm = 'nmap',
      vm = 'vmap',
      xm = 'xmap',
      smap = 'smap',
      om = 'omap',
      im = 'imap',
      lm = 'lmap',
      cm = 'cmap',
      no = 'noremap',
      ['no!'] = 'noremap!',
      nn = 'nnoremap',
      vn = 'vnoremap',
      xn = 'xnoremap',
      snor = 'snoremap',
      ono = 'onoremap',
      ino = 'inoremap',
      ln = 'lnoremap',
      cno = 'cnoremap',
      ab = 'abbreviate',
      norea = 'noreabbrev',
      ca = 'cabbrev',
      cnorea = 'cnoreabbrev',
      ia = 'iabbrev',
      inorea = 'inoreabbrev'
    }) do
      itn(full .. ' <buffer><unique> a b', trunc .. ' <unique><buffer> a b')
      itn(full .. ' <buffer><unique> a b', trunc .. ' <unique> <buffer> a b')
      itn(full .. ' a b', trunc .. ' a b')
      itn(full .. ' a b', trunc .. ' a\t\t\tb')
      itn(full .. ' <nowait><silent> a b', trunc .. ' <nowait>\t<silent> a b')
      itn(full .. ' <special><script> a b', trunc .. ' <special>\t<script> a b')
      itn(full .. ' <expr><unique> a 1', trunc .. ' <unique>\t<expr> a 1')
      itn(full, trunc)
      itn(full .. ' <buffer>', trunc .. '<buffer>')
      itn(full .. ' a', trunc .. ' a')
      itn(full .. ' <buffer> a', trunc .. '<buffer>a')
      itn(full .. ' a b', trunc .. ' a b|next command')
    end
  end)
  describe(':*unmap/:*unabbrev commands', function()
    for trunc, full in pairs({
      unm = 'unmap',
      ['unm!'] = 'unmap!',
      vu = 'vunmap',
      xu = 'xunmap',
      sunm = 'sunmap',
      ou = 'ounmap',
      iu = 'iunmap',
      lun = 'lunmap',
      cu = 'cunmap',
      una = 'unabbreviate',
      cuna = 'cunabbrev',
      iuna = 'iunabbrev'
    }) do
      itn(full .. ' <buffer>', trunc .. '<buffer>')
      itn(full, trunc)
      itn(full .. ' <buffer> a   b', trunc .. '<buffer>a   b')
    end
  end)
  describe(':*mapclear/*abclear commands', function()
    for trunc, full in pairs({
      mapc = 'mapclear',
      ['mapc!'] = 'mapclear!',
      nmapc = 'nmapclear',
      vmapc = 'vmapclear',
      xmapc = 'xmapclear',
      smapc = 'smapclear',
      omapc = 'omapclear',
      imapc = 'imapclear',
      lmapc = 'lmapclear',
      cmapc = 'cmapclear',
      abc = 'abclear',
      iabc = 'iabclear',
      cabc = 'cabclear'
    }) do
      itn(full, trunc)
      itn(full, trunc .. ' \t ')
      itn(full .. ' <buffer>', trunc .. '<buffer>')
      itn(full .. ' <buffer>', trunc .. '\t<buffer>')
    end
  end)
  describe(':*menu commands', function()
    for trunc, full in pairs({
      me = 'menu',
      am = 'amenu',
      nme = 'nmenu',
      ome = 'omenu',
      vme = 'vmenu',
      sme = 'smenu',
      ime = 'imenu',
      cme = 'cmenu',
      noreme = 'noremenu',
      an = 'anoremenu',
      nnoreme = 'nnoremenu',
      onoreme = 'onoremenu',
      vnoreme = 'vnoremenu',
      snoreme = 'snoremenu',
      inoreme = 'inoremenu',
      cnoreme = 'cnoremenu',
      unme = 'unmenu',
      aun = 'aunmenu',
      cunme = 'cunmenu',
      iunme = 'iunmenu',
      nunme = 'nunmenu',
      ounme = 'ounmenu',
      vunme = 'vunmenu',
      xunme = 'xunmenu',
      sunme = 'sunmenu',
      tunme = 'tunmenu',
    }) do
      local unmenu = full:match('unmenu$')
      local un = function(s, s_un)
        if unmenu then
          return s_un or ''
        else
          return s
        end
      end
      itn(un('5' .. full, '\\ error: E481: No range allowed: !!5!!' .. trunc), '5' .. trunc)
      itn(full, trunc)
      itn(full .. un(' icon=abc.gif'), trunc .. '\ticon=abc.gif')
      itn(full .. ' enable', trunc .. '\tenable')
      itn(full .. ' disable', trunc .. '\tdisable')
      itn(full .. un(' .2') .. ' abc.def', trunc .. ' .2 abc.def')
      itn(full .. un(' 1.2') .. ' abc.def', trunc .. ' 1.2 abc.def')
      itn(full .. un(' 1.2') .. ' abc.def' .. un('<Tab>Desc'), trunc .. ' 1.2 abc.def\\\tDesc')
      itn(full .. un(' 1.2') .. ' abc.def' .. un('<Tab>Desc'), trunc .. ' 1.2 abc.def<tAb>Desc')
      itn(un(full .. ' abc.def def', '\\ error: E488: Trailing characters: abc.def !!d!!ef'), trunc .. ' abc.def def')
      if not unmenu then
        itn(full .. ' abc.def<Tab>def def', trunc .. ' abc.def<tAb>def def')
        itn(full .. ' abc.def<Tab>def def', trunc .. ' abc.def\\\tdef def')
        itn(full .. ' .2 abc.def ghi', trunc .. ' .2 abc.def ghi')
        itn(full .. ' 1.2 abc.def ghi', trunc .. ' 1.2 abc.def ghi')
        itn(full .. ' abc.def def', trunc .. ' abc.def def')
        itn(full .. ' abc.def<Tab>def def', trunc .. ' abc.def<tAb>def def')
        itn(full .. ' abc.def<Tab>def def', trunc .. ' abc.def\\\tdef def')
      end
    end
  end)
  describe('expression commands', function()
    itn('if 1', 'if1')
    itn('elseif 1', 'elsei1')
    itn('return 1', 'retu1')
    itn('return', 'retu')
    itn('throw 1', 'th1')
    itn('while 1', 'wh1')
    itn('call tr(1, 2, 3)', 'cal tr(1, 2, 3)')
    itn('call tr(1, 2, 3)', 'cal\ttr\t(1, 2, 3)')
    itn('call (function(\'tr\'))(1, 2, 3)')
    itn('1,2call tr(1, 2, 3)', '1,2cal\ttr\t\t\t(1, 2, 3)')
    for trunc, full in pairs({
      cex = 'cexpr',
      lex = 'lexpr',
      cgete = 'cgetexpr',
      lgete = 'lgetexpr',
      cadde = 'caddexpr',
      ladde = 'laddexpr'
    }) do
      itn(full .. ' 1', trunc .. '1')
    end
  end)
  describe('user commands', function()
    itn('Eq |abc|def', 'Eq|abc|def')
    return itn('1Eq! |abc\\|def', '1Eq!|abc\\|def')
  end)
  describe('language commands', function()
    itn('luado print ("abc\\|def|")', 'luad print ("abc\\|def|")')
    itn('pydo print ("abc\\|def|")', 'pyd print ("abc\\|def|")')
    itn('py3do print ("abc\\|def|")', 'py3d print ("abc\\|def|")')
    itn('rubydo print ("abc\\|def|")', 'rubyd print ("abc\\|def|")')
    itn('perldo print ("abc\\|def|")', 'perld print ("abc\\|def|")')
    itn('tcldo ::vim::command "echo 1\\|\\|2|"', 'tcld::vim::command "echo 1\\|\\|2|"')
    itn('1luado print ("abc\\|def|")', '1luad print ("abc\\|def|")')
    itn('1pydo print ("abc\\|def|")', '1pyd print ("abc\\|def|")')
    itn('1py3do print ("abc\\|def|")', '1py3d print ("abc\\|def|")')
    itn('1rubydo print ("abc\\|def|")', '1rubyd print ("abc\\|def|")')
    itn('1perldo print ("abc\\|def|")', '1perld print ("abc\\|def|")')
    return itn('1tcldo ::vim::command "echo 1\\|\\|2|"', '1tcld::vim::command "echo 1\\|\\|2|"')
  end)
  describe('name commands', function()
    itn('setfiletype abc', 'setf abc')
    itn('setfiletype abc def ghi')
    itn('setfiletype abc def ghi', 'setf abc def ghi')
    itn('augroup abc def ghi')
    itn('augroup abc def ghi', 'aug abc def ghi')
    itn('augroup', 'augroup   ')
    itn('normal! abc\\|def|', 'norm!abc\\|def|')
    itn('2normal! abc\\|def|', '2norm!abc\\|def|')
    itn('colorscheme abc def ghi', 'colo       abc def ghi')
    itn('colorscheme', 'colo')
    itn('compiler', 'comp')
    itn('compiler abc def', 'comp\tabc def')
    itn('echohl abc', 'echoh abc')
    itn('promptfind abc def')
    itn('promptfind abc def', 'promptf abc def')
    itn('promptrepl abc def')
    itn('promptrepl abc def', 'promptr abc def')
    itn('nbkey abc', 'nbkey abc')
    itn('hardcopy', 'ha')
    itn('hardcopy abc def', 'ha abc def')
    itn('hardcopy!', 'ha!')
    itn('hardcopy! abc def', 'ha! abc def')
    itn('compiler', 'comp')
    itn('compiler!', 'comp!')
    itn('compiler abc def', 'comp abc def')
    itn('compiler! abc def', 'comp! abc def')
    itn('colorscheme', 'colo')
    return itn('colorscheme abc def', 'colo abc def')
  end)
  describe('iterator commands and :debug', function()
    itn('bufdo if 1 | endif', 'bufd:if1|end')
    itn('windo if 1 | endif', 'wind:if1|end')
    itn('tabdo if 1 | endif', 'tabd:if1|end')
    itn('argdo if 1 | endif', 'argdo:if1|end')
    itn('folddoopen if 1 | endif', 'foldd:if1|end')
    itn('folddoclosed if 1 | endif', 'folddoc:if1|end')
    itn('debug if 1 | endif', 'debug:if1|end')
  end)
  describe('multiple expressions commands', function()
    for trunc, full in pairs({
      ec = 'echo',
      echon = 'echon',
      echom = 'echomsg',
      echoe = 'echoerr',
      exe = 'execute'
    }) do
      itn(full, trunc)
      itn(full .. ' "abclear"', trunc .. ' "abclear"')
      itn(full .. ' "abclear" "<buffer>"', trunc .. ' "abclear" "<buffer>"')
      itn(full .. ' "abclear" "<buffer>"', trunc .. ' "abclear""<buffer>"')
    end
  end)
  describe('lvals commands', function()
    for trunc, full in pairs({
      unlo = 'unlockvar',
      unl = 'unlet',
      ['unl!'] = 'unlet!'
    }) do
      itn(full .. ' abc', trunc .. ' abc')
      itn(full .. ' abc def', trunc .. ' abc def')
    end
    itn('lockvar abc', 'lockv abc')
    itn('lockvar! abc', 'lockvar!abc')
    itn('lockvar 5 abc', 'lockv5abc')
    itn('unlockvar abc', 'unlockv abc')
    itn('unlockvar! abc', 'unlockvar!abc')
    itn('unlockvar 5 abc', 'unlockv5abc')
    itn('delfunction Abc', 'delf Abc')
    return itn('delfunction {"abc"}', 'delf{"abc"}')
  end)
  describe(':let', function()
    itn('let a b c', 'let a   b\tc')
    itn('let', 'let')
    itn('let g:', 'let g:')
    itn('let [a, b, C] = [1, 2, 3]', 'let[a,b,C]=[1,2,3]')
    itn('let [a, b; C] = [1, 2, 3]')
    itn('let a = 1', 'let a\t=1')
    itn('let a .= 1', 'let a .= 1')
    itn('let a -= 1', 'let a -= 1')
    itn('let a += 1', 'let a+=\t1')
    return itn('let $A .= 1', 'let$A.=1')
  end)
  describe(':scriptencoding', function()
    itn('scriptencoding', 'scripte')
    itn('scriptencoding utf-8', 'scriptencoding UTF-8')
    itn('scriptencoding utf-8', 'scriptencoding UTF8')
    itn('scriptencoding utf-8', 'scriptencoding utf8')
    itn('scriptencoding utf-8', 'scriptencoding utf-8')
    return itn('scriptencoding ucs-2', 'scriptencoding ucs-2')
  end)
  describe('debugging functions', function()
    itn('breakadd func 13 lit(a)', 'breaka func13a')
    itn('breakdel func 13 lit(a)', 'breakd func13a')
    itn('breakadd file 13 any()', 'breaka file13*')
    itn('breakdel file 13 any()', 'breakd file13*')
    itn('breakadd file any()', 'breaka file*')
    itn('breakdel file any()', 'breakd file*')
    itn('profile file any()', 'prof file*')
    itn('profile func any()', 'prof func*')
    itn('profile file lit(13)', 'profile file13')
    itn('profdel file any()', 'profd file*')
    itn('profdel func any()', 'profd func*')
    itn('profdel file lit(13)', 'profdel file13')
    itn('breakadd here', 'breaka here')
    itn('breakdel here', 'breakd here')
    itn('profile start lit(profile.log)', 'prof start profile.log')
    itn('profile start lit(*)', 'prof start *')
    itn('profile pause', 'prof\tpause')
    itn('profile continue', 'prof   continue')
  end)
  describe(':display and :registers', function()
    itn('display +az', 'di+za')
    itn('registers +az', 'reg+za')
    itn('display +az', 'di\x1B+za')
    itn('registers az', 'reg\x1Bza')
    itn('display', 'di')
    itn('registers', 'reg')
  end)
  describe('patterns', function()
    itn('edit env(ABC).lit(/def/).any(recursive).lit(/).any().lit(.tar.).char().char()', 'e$ABC/def/**/*.tar.??')
    itn('edit cur()', 'e%')
    itn('edit args()', 'e##')
    itn('edit alt()', 'e#')
    itn('edit shell(echo abc).lit(/def)', 'e`echo abc`/def')
    itn('edit home().lit(/.vimrc)', 'e~/.vimrc')
  end)
end)
