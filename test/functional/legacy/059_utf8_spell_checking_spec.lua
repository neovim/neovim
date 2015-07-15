-- Tests for spell checking with 'encoding' set to "utf-8".

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe("spell checking with 'encoding' set to utf-8", function()
  setup(clear)

  it('is working', function()
    insert([=[
      1affstart
      SET ISO8859-1
      TRY esianrtolcdugmphbyfvkwjkqxz-ëéèêïîäàâöüû'ESIANRTOLCDUGMPHBYFVKWJKQXZ
      
      FOL  àáâãäåæçèéêëìíîïğñòóôõöøùúûüışßÿ
      LOW  àáâãäåæçèéêëìíîïğñòóôõöøùúûüışßÿ
      UPP  ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏĞÑÒÓÔÕÖØÙÚÛÜİŞßÿ
      
      SOFOFROM abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZàáâãäåæçèéêëìíîïğñòóôõöøùúûüışßÿÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏĞÑÒÓÔÕÖØÙÚÛÜİŞ¿
      SOFOTO   ebctefghejklnnepkrstevvkesebctefghejklnnepkrstevvkeseeeeeeeceeeeeeeedneeeeeeeeeeepseeeeeeeeceeeeeeeedneeeeeeeeeeep?
      
      MIDWORD	'-
      
      KEP =
      RAR ?
      BAD !
      
      #NOSPLITSUGS
      
      PFX I N 1
      PFX I 0 in .
      
      PFX O Y 1
      PFX O 0 out .
      
      SFX S Y 2
      SFX S 0 s [^s]
      SFX S 0 es s
      
      SFX N N 3
      SFX N 0 en [^n]
      SFX N 0 nen n
      SFX N 0 n .
      
      REP 3
      REP g ch
      REP ch g
      REP svp s.v.p.
      
      MAP 9
      MAP aàáâãäå
      MAP eèéêë
      MAP iìíîï
      MAP oòóôõö
      MAP uùúûü
      MAP nñ
      MAP cç
      MAP yÿı
      MAP sß
      1affend
      
      affstart_sal
      SET ISO8859-1
      TRY esianrtolcdugmphbyfvkwjkqxz-ëéèêïîäàâöüû'ESIANRTOLCDUGMPHBYFVKWJKQXZ
      
      FOL  àáâãäåæçèéêëìíîïğñòóôõöøùúûüışßÿ
      LOW  àáâãäåæçèéêëìíîïğñòóôõöøùúûüışßÿ
      UPP  ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏĞÑÒÓÔÕÖØÙÚÛÜİŞßÿ
      
      MIDWORD	'-
      
      KEP =
      RAR ?
      BAD !
      
      #NOSPLITSUGS
      
      PFX I N 1
      PFX I 0 in .
      
      PFX O Y 1
      PFX O 0 out .
      
      SFX S Y 2
      SFX S 0 s [^s]
      SFX S 0 es s
      
      SFX N N 3
      SFX N 0 en [^n]
      SFX N 0 nen n
      SFX N 0 n .
      
      REP 3
      REP g ch
      REP ch g
      REP svp s.v.p.
      
      MAP 9
      MAP aàáâãäå
      MAP eèéêë
      MAP iìíîï
      MAP oòóôõö
      MAP uùúûü
      MAP nñ
      MAP cç
      MAP yÿı
      MAP sß
      
      SAL AH(AEIOUY)-^         *H
      SAL AR(AEIOUY)-^         *R
      SAL A(HR)^               *
      SAL A^                   *
      SAL AH(AEIOUY)-          H
      SAL AR(AEIOUY)-          R
      SAL A(HR)                _
      SAL À^                   *
      SAL Å^                   *
      SAL BB-                  _
      SAL B                    B
      SAL CQ-                  _
      SAL CIA                  X
      SAL CH                   X
      SAL C(EIY)-              S
      SAL CK                   K
      SAL COUGH^               KF
      SAL CC<                  C
      SAL C                    K
      SAL DG(EIY)              K
      SAL DD-                  _
      SAL D                    T
      SAL É<                   E
      SAL EH(AEIOUY)-^         *H
      SAL ER(AEIOUY)-^         *R
      SAL E(HR)^               *
      SAL ENOUGH^$             *NF
      SAL E^                   *
      SAL EH(AEIOUY)-          H
      SAL ER(AEIOUY)-          R
      SAL E(HR)                _
      SAL FF-                  _
      SAL F                    F
      SAL GN^                  N
      SAL GN$                  N
      SAL GNS$                 NS
      SAL GNED$                N
      SAL GH(AEIOUY)-          K
      SAL GH                   _
      SAL GG9                  K
      SAL G                    K
      SAL H                    H
      SAL IH(AEIOUY)-^         *H
      SAL IR(AEIOUY)-^         *R
      SAL I(HR)^               *
      SAL I^                   *
      SAL ING6                 N
      SAL IH(AEIOUY)-          H
      SAL IR(AEIOUY)-          R
      SAL I(HR)                _
      SAL J                    K
      SAL KN^                  N
      SAL KK-                  _
      SAL K                    K
      SAL LAUGH^               LF
      SAL LL-                  _
      SAL L                    L
      SAL MB$                  M
      SAL MM                   M
      SAL M                    M
      SAL NN-                  _
      SAL N                    N
      SAL OH(AEIOUY)-^         *H
      SAL OR(AEIOUY)-^         *R
      SAL O(HR)^               *
      SAL O^                   *
      SAL OH(AEIOUY)-          H
      SAL OR(AEIOUY)-          R
      SAL O(HR)                _
      SAL PH                   F
      SAL PN^                  N
      SAL PP-                  _
      SAL P                    P
      SAL Q                    K
      SAL RH^                  R
      SAL ROUGH^               RF
      SAL RR-                  _
      SAL R                    R
      SAL SCH(EOU)-            SK
      SAL SC(IEY)-             S
      SAL SH                   X
      SAL SI(AO)-              X
      SAL SS-                  _
      SAL S                    S
      SAL TI(AO)-              X
      SAL TH                   @
      SAL TCH--                _
      SAL TOUGH^               TF
      SAL TT-                  _
      SAL T                    T
      SAL UH(AEIOUY)-^         *H
      SAL UR(AEIOUY)-^         *R
      SAL U(HR)^               *
      SAL U^                   *
      SAL UH(AEIOUY)-          H
      SAL UR(AEIOUY)-          R
      SAL U(HR)                _
      SAL V^                   W
      SAL V                    F
      SAL WR^                  R
      SAL WH^                  W
      SAL W(AEIOU)-            W
      SAL X^                   S
      SAL X                    KS
      SAL Y(AEIOU)-            Y
      SAL ZZ-                  _
      SAL Z                    S
      affend_sal
      
      2affstart
      SET ISO8859-1
      
      FOL  àáâãäåæçèéêëìíîïğñòóôõöøùúûüışßÿ
      LOW  àáâãäåæçèéêëìíîïğñòóôõöøùúûüışßÿ
      UPP  ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏĞÑÒÓÔÕÖØÙÚÛÜİŞßÿ
      
      PFXPOSTPONE
      
      MIDWORD	'-
      
      KEP =
      RAR ?
      BAD !
      
      #NOSPLITSUGS
      
      PFX I N 1
      PFX I 0 in .
      
      PFX O Y 1
      PFX O 0 out [a-z]
      
      SFX S Y 2
      SFX S 0 s [^s]
      SFX S 0 es s
      
      SFX N N 3
      SFX N 0 en [^n]
      SFX N 0 nen n
      SFX N 0 n .
      
      REP 3
      REP g ch
      REP ch g
      REP svp s.v.p.
      
      MAP 9
      MAP aàáâãäå
      MAP eèéêë
      MAP iìíîï
      MAP oòóôõö
      MAP uùúûü
      MAP nñ
      MAP cç
      MAP yÿı
      MAP sß
      2affend
      
      1dicstart
      123456
      test/NO
      # comment
      wrong
      Comment
      OK
      uk
      put/ISO
      the end
      deol
      déôr
      1dicend
      
      addstart
      /regions=usgbnz
      elequint/2
      elekwint/3
      addend
      
      1good: wrong OK puts. Test the end
      bad:  inputs comment ok Ok. test dÃ©Ã´l end the
      badend
      
      2good: puts
      bad: inputs comment ok Ok end the. test dÃ©Ã´l
      badend
      
      Test rules for compounding.
      
      3affstart
      SET ISO8859-1
      
      COMPOUNDMIN 3
      COMPOUNDRULE m*
      NEEDCOMPOUND x
      3affend
      
      3dicstart
      1234
      foo/m
      bar/mx
      mï/m
      la/mx
      3dicend
      
      3good: foo mÃ¯ foobar foofoobar barfoo barbarfoo
      bad: bar la foomÃ¯ barmÃ¯ mÃ¯foo mÃ¯bar mÃ¯mÃ¯ lala mÃ¯la lamÃ¯ foola labar
      badend
      
      
      Tests for compounding.
      
      4affstart
      SET ISO8859-1
      
      FOL  àáâãäåæçèéêëìíîïğñòóôõöøùúûüışßÿ
      LOW  àáâãäåæçèéêëìíîïğñòóôõöøùúûüışßÿ
      UPP  ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏĞÑÒÓÔÕÖØÙÚÛÜİŞßÿ
      
      COMPOUNDRULE m+
      COMPOUNDRULE sm*e
      COMPOUNDRULE sm+
      COMPOUNDMIN 3
      COMPOUNDWORDMAX 3
      COMPOUNDFORBIDFLAG t
      
      COMPOUNDSYLMAX 5
      SYLLABLE aáeéiíoóöõuúüûy/aa/au/ea/ee/ei/ie/oa/oe/oo/ou/uu/ui
      
      MAP 9
      MAP aàáâãäå
      MAP eèéêë
      MAP iìíîï
      MAP oòóôõö
      MAP uùúûü
      MAP nñ
      MAP cç
      MAP yÿı
      MAP sß
      
      NEEDAFFIX x
      
      PFXPOSTPONE
      
      MIDWORD '-
      
      SFX q N 1
      SFX q   0    -ok .
      
      SFX a Y 2
      SFX a 0 s .
      SFX a 0 ize/t .
      
      PFX p N 1
      PFX p 0 pre .
      
      PFX P N 1
      PFX P 0 nou .
      4affend
      
      4dicstart
      1234
      word/mP
      util/am
      pro/xq
      tomato/m
      bork/mp
      start/s
      end/e
      4dicend
      
      4good: word util bork prebork start end wordutil wordutils pro-ok
      	bork borkbork borkborkbork borkborkborkbork borkborkborkborkbork
      	tomato tomatotomato startend startword startwordword startwordend
      	startwordwordend startwordwordwordend prebork preborkbork
      	preborkborkbork
      	nouword
      bad: wordutilize pro borkborkborkborkborkbork tomatotomatotomato
      	endstart endend startstart wordend wordstart
      	preborkprebork  preborkpreborkbork
       	startwordwordwordwordend borkpreborkpreborkbork
      	utilsbork  startnouword
      badend
      
      test2:
      elequint test elekwint test elekwent asdf
      
      Test affix flags with two characters
      
      5affstart
      SET ISO8859-1
      
      FLAG long
      
      NEEDAFFIX !!
      
      COMPOUNDRULE ssmm*ee
      
      NEEDCOMPOUND xx
      COMPOUNDPERMITFLAG pp
      
      SFX 13 Y 1
      SFX 13 0 bork .
      
      SFX a1 Y 1
      SFX a1 0 a1 .
      
      SFX aé Y 1
      SFX aé 0 aé .
      
      PFX zz Y 1
      PFX zz 0 pre/pp .
      
      PFX yy Y 1
      PFX yy 0 nou .
      5affend
      
      5dicstart
      1234
      foo/a1aé!!
      bar/zz13ee
      start/ss
      end/eeyy
      middle/mmxx
      5dicend
      
      5good: fooa1 fooaÃ© bar prebar barbork prebarbork  startprebar
            start end startend  startmiddleend nouend
      bad: foo fooa2 prabar probarbirk middle startmiddle middleend endstart
      	startprobar startnouend
      badend
      
      6affstart
      SET ISO8859-1
      
      FLAG caplong
      
      NEEDAFFIX A!
      
      COMPOUNDRULE sMm*Ee
      
      NEEDCOMPOUND Xx
      
      COMPOUNDPERMITFLAG p
      
      SFX N3 Y 1
      SFX N3 0 bork .
      
      SFX A1 Y 1
      SFX A1 0 a1 .
      
      SFX Aé Y 1
      SFX Aé 0 aé .
      
      PFX Zz Y 1
      PFX Zz 0 pre/p .
      6affend
      
      6dicstart
      1234
      mee/A1AéA!
      bar/ZzN3Ee
      lead/s
      end/Ee
      middle/MmXx
      6dicend
      
      6good: meea1 meeaÃ© bar prebar barbork prebarbork  leadprebar
            lead end leadend  leadmiddleend
      bad: mee meea2 prabar probarbirk middle leadmiddle middleend endlead
      	leadprobar
      badend
      
      7affstart
      SET ISO8859-1
      
      FOL  àáâãäåæçèéêëìíîïğñòóôõöøùúûüışßÿ
      LOW  àáâãäåæçèéêëìíîïğñòóôõöøùúûüışßÿ
      UPP  ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏĞÑÒÓÔÕÖØÙÚÛÜİŞßÿ
      
      FLAG num
      
      NEEDAFFIX 9999
      
      COMPOUNDRULE 2,77*123
      
      NEEDCOMPOUND 1
      COMPOUNDPERMITFLAG 432
      
      SFX 61003 Y 1
      SFX 61003 0 meat .
      
      SFX 391 Y 1
      SFX 391 0 a1 .
      
      SFX 111 Y 1
      SFX 111 0 aé .
      
      PFX 17 Y 1
      PFX 17 0 pre/432 .
      7affend
      
      7dicstart
      1234
      mee/391,111,9999
      bar/17,61003,123
      lead/2
      tail/123
      middle/77,1
      7dicend
      
      7good: meea1 meeaÃ© bar prebar barmeat prebarmeat  leadprebar
            lead tail leadtail  leadmiddletail
      bad: mee meea2 prabar probarmaat middle leadmiddle middletail taillead
      	leadprobar
      badend
      
      test output:]=])

    execute('so small.vim')
    execute('so mbyte.vim')

    -- Don't want to depend on the locale from the environment.  The .aff and .dic.
    -- Text is in latin1, the test text is utf-8.
    execute('set enc=latin1')
    execute('e!')
    execute('set enc=utf-8')
    execute('set fenc=')

    -- Function to test .aff/.dic with list of good and bad words.
    execute('func TestOne(aff, dic)')
    feed('  set spellfile=<cr>')
    feed([[  $put =''<cr>]])
    feed([[  $put ='test '. a:aff . '-' . a:dic<cr>]])
    -- Generate a .spl file from a .dic and .aff file.
    feed([[  exe '1;/^' . a:aff . 'affstart/+1,/^' . a:aff . 'affend/-1w! Xtest.aff'<cr>]])
    feed([[  exe '1;/^' . a:dic . 'dicstart/+1,/^' . a:dic . 'dicend/-1w! Xtest.dic'<cr>]])
    feed('  mkspell! Xtest Xtest<cr>')
    -- Use that spell file.
    feed('  set spl=Xtest.utf-8.spl spell<cr>')
    -- List all valid words.
    feed('  spelldump<cr>')
    feed('  %yank<cr>')
    feed('  quit<cr>')
    feed('  $put<cr>')
    feed([[  $put ='-------'<cr>]])
    -- Find all bad words and suggestions for them.
    feed([[  exe '1;/^' . a:aff . 'good:'<cr>]])
    feed('  normal 0f:]s<cr>')
    feed([[  let prevbad = ''<cr>]])
    feed('  while 1<cr>')
    feed('    let [bad, a] = spellbadword()<cr>')
    feed([[    if bad == '' || bad == prevbad || bad == 'badend'<cr>]])
    feed('      break<cr>')
    feed('    endif<cr>')
    feed('    let prevbad = bad<cr>')
    feed('    let lst = spellsuggest(bad, 3)<cr>')
    feed('    normal mm<cr>')
    feed('    $put =bad<cr>')
    feed('    $put =string(lst)<cr>')
    feed('    normal `m]s<cr>')
    feed('  endwhile<cr>')
    feed('endfunc<cr>')

    execute([[call TestOne('1', '1')]])
    execute([[$put =soundfold('goobledygoook')]])
    execute([[$put =soundfold('kÃ³opÃ«rÃ¿nÃ´ven')]])
    execute([[$put =soundfold('oeverloos gezwets edale')]])


    -- And now with SAL instead of SOFO items; test automatic reloading.
    feed('gg:/^affstart_sal/+1,/^affend_sal/-1w! Xtest.aff<cr>')
    execute('mkspell! Xtest Xtest')
    execute([[$put =soundfold('goobledygoook')]])
    execute([[$put =soundfold('kÃ³opÃ«rÃ¿nÃ´ven')]])
    execute([[$put =soundfold('oeverloos gezwets edale')]])

    -- Also use an addition file.
    feed('gg:/^addstart/+1,/^addend/-1w! Xtest.utf-8.add<cr>')
    execute('mkspell! Xtest.utf-8.add.spl Xtest.utf-8.add')
    execute('set spellfile=Xtest.utf-8.add')
    execute('/^test2:')
    feed(']s:let [str, a] = spellbadword()<cr>')
    execute('$put =str')
    execute('set spl=Xtest_us.utf-8.spl')
    execute('/^test2:')
    feed(']smm:let [str, a] = spellbadword()<cr>')
    execute('$put =str')
    feed('`m]s:let [str, a] = spellbadword()<cr>')
    execute('$put =str')
    execute('set spl=Xtest_gb.utf-8.spl')
    execute('/^test2:')
    feed(']smm:let [str, a] = spellbadword()<cr>')
    execute('$put =str')
    feed('`m]s:let [str, a] = spellbadword()<cr>')
    execute('$put =str')
    execute('set spl=Xtest_nz.utf-8.spl')
    execute('/^test2:')
    feed(']smm:let [str, a] = spellbadword()<cr>')
    execute('$put =str')
    feed('`m]s:let [str, a] = spellbadword()<cr>')
    execute('$put =str')
    execute('set spl=Xtest_ca.utf-8.spl')
    execute('/^test2:')
    feed(']smm:let [str, a] = spellbadword()<cr>')
    execute('$put =str')
    feed('`m]s:let [str, a] = spellbadword()<cr>')
    execute('$put =str')
    execute('unlet str a')

    -- Postponed prefixes.
    execute([[call TestOne('2', '1')]])

    -- Compound words.
    execute([[call TestOne('3', '3')]])
    execute([[call TestOne('4', '4')]])
    execute([[call TestOne('5', '5')]])
    execute([[call TestOne('6', '6')]])
    execute([[call TestOne('7', '7')]])

    -- Clean up for valgrind.
    execute('delfunc TestOne')
    execute('set spl= enc=latin1')

    feed('gg:/^test output:/,$wq! test.out<cr>')

    -- Assert buffer contents.
    expect([=[
      test output:
      
      test 1-1
      # file: Xtest.utf-8.spl
      Comment
      deol
      dÃ©Ã´r
      input
      OK
      output
      outputs
      outtest
      put
      puts
      test
      testen
      testn
      the end
      uk
      wrong
      -------
      bad
      ['put', 'uk', 'OK']
      inputs
      ['input', 'puts', 'outputs']
      comment
      ['Comment', 'outtest', 'the end']
      ok
      ['OK', 'uk', 'put']
      Ok
      ['OK', 'Uk', 'Put']
      test
      ['Test', 'testn', 'testen']
      dÃ©Ã´l
      ['deol', 'dÃ©Ã´r', 'test']
      end
      ['put', 'uk', 'test']
      the
      ['put', 'uk', 'test']
      gebletegek
      kepereneven
      everles gesvets etele
      kbltykk
      kprnfn
      *fls kswts tl
      elekwent
      elequint
      elekwint
      elekwint
      elekwent
      elequint
      elekwent
      elequint
      elekwint
      
      test 2-1
      # file: Xtest.utf-8.spl
      Comment
      deol
      dÃ©Ã´r
      OK
      put
      input
      output
      puts
      outputs
      test
      outtest
      testen
      testn
      the end
      uk
      wrong
      -------
      bad
      ['put', 'uk', 'OK']
      inputs
      ['input', 'puts', 'outputs']
      comment
      ['Comment']
      ok
      ['OK', 'uk', 'put']
      Ok
      ['OK', 'Uk', 'Put']
      end
      ['put', 'uk', 'deol']
      the
      ['put', 'uk', 'test']
      test
      ['Test', 'testn', 'testen']
      dÃ©Ã´l
      ['deol', 'dÃ©Ã´r', 'test']
      
      test 3-3
      # file: Xtest.utf-8.spl
      foo
      mÃ¯
      -------
      bad
      ['foo', 'mÃ¯']
      bar
      ['barfoo', 'foobar', 'foo']
      la
      ['mÃ¯', 'foo']
      foomÃ¯
      ['foo mÃ¯', 'foo', 'foofoo']
      barmÃ¯
      ['barfoo', 'mÃ¯', 'barbar']
      mÃ¯foo
      ['mÃ¯ foo', 'foo', 'foofoo']
      mÃ¯bar
      ['foobar', 'barbar', 'mÃ¯']
      mÃ¯mÃ¯
      ['mÃ¯ mÃ¯', 'mÃ¯']
      lala
      []
      mÃ¯la
      ['mÃ¯', 'mÃ¯ mÃ¯']
      lamÃ¯
      ['mÃ¯', 'mÃ¯ mÃ¯']
      foola
      ['foo', 'foobar', 'foofoo']
      labar
      ['barbar', 'foobar']
      
      test 4-4
      # file: Xtest.utf-8.spl
      bork
      prebork
      end
      pro-ok
      start
      tomato
      util
      utilize
      utils
      word
      nouword
      -------
      bad
      ['end', 'bork', 'word']
      wordutilize
      ['word utilize', 'wordutils', 'wordutil']
      pro
      ['bork', 'word', 'end']
      borkborkborkborkborkbork
      ['bork borkborkborkborkbork', 'borkbork borkborkborkbork', 'borkborkbork borkborkbork']
      tomatotomatotomato
      ['tomato tomatotomato', 'tomatotomato tomato', 'tomato tomato tomato']
      endstart
      ['end start', 'start']
      endend
      ['end end', 'end']
      startstart
      ['start start']
      wordend
      ['word end', 'word', 'wordword']
      wordstart
      ['word start', 'bork start']
      preborkprebork
      ['prebork prebork', 'preborkbork', 'preborkborkbork']
      preborkpreborkbork
      ['prebork preborkbork', 'preborkborkbork', 'preborkborkborkbork']
      startwordwordwordwordend
      ['startwordwordwordword end', 'startwordwordwordword', 'start wordwordwordword end']
      borkpreborkpreborkbork
      ['bork preborkpreborkbork', 'bork prebork preborkbork', 'bork preborkprebork bork']
      utilsbork
      ['utilbork', 'utils bork', 'util bork']
      startnouword
      ['start nouword', 'startword', 'startborkword']
      
      test 5-5
      # file: Xtest.utf-8.spl
      bar
      barbork
      end
      fooa1
      fooaÃ©
      nouend
      prebar
      prebarbork
      start
      -------
      bad
      ['bar', 'end', 'fooa1']
      foo
      ['fooa1', 'fooaÃ©', 'bar']
      fooa2
      ['fooa1', 'fooaÃ©', 'bar']
      prabar
      ['prebar', 'bar', 'bar bar']
      probarbirk
      ['prebarbork']
      middle
      []
      startmiddle
      ['startmiddleend', 'startmiddlebar']
      middleend
      []
      endstart
      ['end start', 'start']
      startprobar
      ['startprebar', 'start prebar', 'startbar']
      startnouend
      ['start nouend', 'startend']
      
      test 6-6
      # file: Xtest.utf-8.spl
      bar
      barbork
      end
      lead
      meea1
      meeaÃ©
      prebar
      prebarbork
      -------
      bad
      ['bar', 'end', 'lead']
      mee
      ['meea1', 'meeaÃ©', 'bar']
      meea2
      ['meea1', 'meeaÃ©', 'lead']
      prabar
      ['prebar', 'bar', 'leadbar']
      probarbirk
      ['prebarbork']
      middle
      []
      leadmiddle
      ['leadmiddleend', 'leadmiddlebar']
      middleend
      []
      endlead
      ['end lead', 'lead', 'end end']
      leadprobar
      ['leadprebar', 'lead prebar', 'leadbar']
      
      test 7-7
      # file: Xtest.utf-8.spl
      bar
      barmeat
      lead
      meea1
      meeaÃ©
      prebar
      prebarmeat
      tail
      -------
      bad
      ['bar', 'lead', 'tail']
      mee
      ['meea1', 'meeaÃ©', 'bar']
      meea2
      ['meea1', 'meeaÃ©', 'lead']
      prabar
      ['prebar', 'bar', 'leadbar']
      probarmaat
      ['prebarmeat']
      middle
      []
      leadmiddle
      ['leadmiddlebar']
      middletail
      []
      taillead
      ['tail lead', 'tail']
      leadprobar
      ['leadprebar', 'lead prebar', 'leadbar']]=])
  end)
end)
