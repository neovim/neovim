-- Tests for spell checking with 'encoding' set to "utf-8".

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect
local write_file = helpers.write_file

describe("spell checking with 'encoding' set to utf-8", function()
  setup(function()
    clear()
    -- This file should be encoded in ISO8859-1.
    write_file('Xtest1.aff', 
      'SET ISO8859-1\n' ..
      'TRY esianrtolcdugmphbyfvkwjkqxz-\xeb\xe9\xe8\xea\xef\xee\xe4\xe0' ..
      '\xe2\xf6\xfc\xfb\'ESIANRTOLCDUGMPHBYFVKWJKQXZ\n' ..
      '\n' ..
      'FOL  \xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee' ..
      '\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xdf' ..
      '\xff\n' ..
      'LOW  \xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee' ..
      '\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xdf' ..
      '\xff\n' ..
      'UPP  \xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce' ..
      '\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf' ..
      '\xff\n' ..
      '\n' ..
      'SOFOFROM abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ\xe0' ..
      '\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef\xf0' ..
      '\xf1\xf2\xf3\xf4\xf5\xf6\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xdf\xff\xc0' ..
      '\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf\xd0' ..
      '\xd1\xd2\xd3\xd4\xd5\xd6\xd8\xd9\xda\xdb\xdc\xdd\xde\xbf\n' ..
      'SOFOTO   ebctefghejklnnepkrstevvkesebctefghejklnnepkrstevvkeseeeeee' ..
      'eceeeeeeeedneeeeeeeeeeepseeeeeeeeceeeeeeeedneeeeeeeeeeep?\n' ..
      '\n' ..
      'MIDWORD\t\'-\n' ..
      '\n' ..
      'KEP =\n' ..
      'RAR ?\n' ..
      'BAD !\n' ..
      '\n' ..
      '#NOSPLITSUGS\n' ..
      '\n' ..
      'PFX I N 1\n' ..
      'PFX I 0 in .\n' ..
      '\n' ..
      'PFX O Y 1\n' ..
      'PFX O 0 out .\n' ..
      '\n' ..
      'SFX S Y 2\n' ..
      'SFX S 0 s [^s]\n' ..
      'SFX S 0 es s\n' ..
      '\n' ..
      'SFX N N 3\n' ..
      'SFX N 0 en [^n]\n' ..
      'SFX N 0 nen n\n' ..
      'SFX N 0 n .\n' ..
      '\n' ..
      'REP 3\n' ..
      'REP g ch\n' ..
      'REP ch g\n' ..
      'REP svp s.v.p.\n' ..
      '\n' ..
      'MAP 9\n' ..
      'MAP a\xe0\xe1\xe2\xe3\xe4\xe5\n' ..
      'MAP e\xe8\xe9\xea\xeb\n' ..
      'MAP i\xec\xed\xee\xef\n' ..
      'MAP o\xf2\xf3\xf4\xf5\xf6\n' ..
      'MAP u\xf9\xfa\xfb\xfc\n' ..
      'MAP n\xf1\n' ..
      'MAP c\xe7\n' ..
      'MAP y\xff\xfd\n' ..
      'MAP s\xdf\n')
    write_file('Xtest1.dic',
      '123456\n' ..
      'test/NO\n' ..
      '# comment\n' ..
      'wrong\n' ..
      'Comment\n' ..
      'OK\n' ..
      'uk\n' ..
      'put/ISO\n' ..
      'the end\n' ..
      'deol\n' ..
      '\x64\xe9\xf4\x72\n')
    write_file('Xtest2.aff', 
      'SET ISO8859-1\n' ..
      '\n' ..
      'FOL  \xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee' ..
      '\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xdf' ..
      '\xff\n' ..
      'LOW  \xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee' ..
      '\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xdf' ..
      '\xff\n' ..
      'UPP  \xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce' ..
      '\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf' ..
      '\xff\n' ..
      '\n' ..
      'PFXPOSTPONE\n' ..
      '\n' ..
      'MIDWORD\t\'-\n' ..
      '\n' ..
      'KEP =\n' ..
      'RAR ?\n' ..
      'BAD !\n' ..
      '\n' ..
      '#NOSPLITSUGS\n' ..
      '\n' ..
      'PFX I N 1\n' ..
      'PFX I 0 in .\n' ..
      '\n' ..
      'PFX O Y 1\n' ..
      'PFX O 0 out [a-z]\n' ..
      '\n' ..
      'SFX S Y 2\n' ..
      'SFX S 0 s [^s]\n' ..
      'SFX S 0 es s\n' ..
      '\n' ..
      'SFX N N 3\n' ..
      'SFX N 0 en [^n]\n' ..
      'SFX N 0 nen n\n' ..
      'SFX N 0 n .\n' ..
      '\n' ..
      'REP 3\n' ..
      'REP g ch\n' ..
      'REP ch g\n' ..
      'REP svp s.v.p.\n' ..
      '\n' ..
      'MAP 9\n' ..
      'MAP a\xe0\xe1\xe2\xe3\xe4\xe5\n' ..
      'MAP e\xe8\xe9\xea\xeb\n' ..
      'MAP i\xec\xed\xee\xef\n' ..
      'MAP o\xf2\xf3\xf4\xf5\xf6\n' ..
      'MAP u\xf9\xfa\xfb\xfc\n' ..
      'MAP n\xf1\n' ..
      'MAP c\xe7\n' ..
      'MAP y\xff\xfd\n' ..
      'MAP s\xdf\n')
    write_file('Xtest3.aff', [[
      SET ISO8859-1
      
      COMPOUNDMIN 3
      COMPOUNDRULE m*
      NEEDCOMPOUND x
      ]])
    write_file('Xtest4.aff', 
      'SET ISO8859-1\n' ..
      '\n' ..
      'FOL  \xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee' ..
      '\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xdf' ..
      '\xff\n' ..
      'LOW  \xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee' ..
      '\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xdf' ..
      '\xff\n' ..
      'UPP  \xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce' ..
      '\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf' ..
      '\xff\n' ..
      '\n' ..
      'COMPOUNDRULE m+\n' ..
      'COMPOUNDRULE sm*e\n' ..
      'COMPOUNDRULE sm+\n' ..
      'COMPOUNDMIN 3\n' ..
      'COMPOUNDWORDMAX 3\n' ..
      'COMPOUNDFORBIDFLAG t\n' ..
      '\n' ..
      'COMPOUNDSYLMAX 5\n' ..
      'SYLLABLE a\xe1e\xe9i\xedo\xf3\xf6\xf5u\xfa\xfc\xfby/aa/au/ea/ee/ei/' ..
      'ie/oa/oe/oo/ou/uu/ui\n' ..
      '\n' ..
      'MAP 9\n' ..
      'MAP a\xe0\xe1\xe2\xe3\xe4\xe5\n' ..
      'MAP e\xe8\xe9\xea\xeb\n' ..
      'MAP i\xec\xed\xee\xef\n' ..
      'MAP o\xf2\xf3\xf4\xf5\xf6\n' ..
      'MAP u\xf9\xfa\xfb\xfc\n' ..
      'MAP n\xf1\n' ..
      'MAP c\xe7\n' ..
      'MAP y\xff\xfd\n' ..
      'MAP s\xdf\n' ..
      '\n' ..
      'NEEDAFFIX x\n' ..
      '\n' ..
      'PFXPOSTPONE\n' ..
      '\n' ..
      'MIDWORD \'-\n' ..
      '\n' ..
      'SFX q N 1\n' ..
      'SFX q   0    -ok .\n' ..
      '\n' ..
      'SFX a Y 2\n' ..
      'SFX a 0 s .\n' ..
      'SFX a 0 ize/t .\n' ..
      '\n' ..
      'PFX p N 1\n' ..
      'PFX p 0 pre .\n' ..
      '\n' ..
      'PFX P N 1\n' ..
      'PFX P 0 nou .\n')
    write_file('Xtest5.aff',
      'SET ISO8859-1\n' ..
      '\n' ..
      'FLAG long\n' ..
      '\n' ..
      'NEEDAFFIX !!\n' ..
      '\n' ..
      'COMPOUNDRULE ssmm*ee\n' ..
      '\n' ..
      'NEEDCOMPOUND xx\n' ..
      'COMPOUNDPERMITFLAG pp\n' ..
      '\n' ..
      'SFX 13 Y 1\n' ..
      'SFX 13 0 bork .\n' ..
      '\n' ..
      'SFX a1 Y 1\n' ..
      'SFX a1 0 a1 .\n' ..
      '\n' ..
      'SFX a\xe9 Y 1\n' ..
      'SFX a\xe9 0 a\xe9 .\n' ..
      '\n' ..
      'PFX zz Y 1\n' ..
      'PFX zz 0 pre/pp .\n' ..
      '\n' ..
      'PFX yy Y 1\n' ..
      'PFX yy 0 nou .\n')
    write_file('Xtest6.aff',
      'SET ISO8859-1\n' ..
      '\n' ..
      'FLAG caplong\n' ..
      '\n' ..
      'NEEDAFFIX A!\n' ..
      '\n' ..
      'COMPOUNDRULE sMm*Ee\n' ..
      '\n' ..
      'NEEDCOMPOUND Xx\n' ..
      '\n' ..
      'COMPOUNDPERMITFLAG p\n' ..
      '\n' ..
      'SFX N3 Y 1\n' ..
      'SFX N3 0 bork .\n' ..
      '\n' ..
      'SFX A1 Y 1\n' ..
      'SFX A1 0 a1 .\n' ..
      '\n' ..
      'SFX A\xe9 Y 1\n' ..
      'SFX A\xe9 0 a\xe9 .\n' ..
      '\n' ..
      'PFX Zz Y 1\n' ..
      'PFX Zz 0 pre/p .\n')
    write_file('Xtest7.aff',
      'SET ISO8859-1\n' ..
      '\n' ..
      'FOL  \xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee' ..
      '\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xdf' ..
      '\xff\n' ..
      'LOW  \xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee' ..
      '\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xdf' ..
      '\xff\n' ..
      'UPP  \xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce' ..
      '\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf' ..
      '\xff\n' ..
      '\n' ..
      'FLAG num\n' ..
      '\n' ..
      'NEEDAFFIX 9999\n' ..
      '\n' ..
      'COMPOUNDRULE 2,77*123\n' ..
      '\n' ..
      'NEEDCOMPOUND 1\n' ..
      'COMPOUNDPERMITFLAG 432\n' ..
      '\n' ..
      'SFX 61003 Y 1\n' ..
      'SFX 61003 0 meat .\n' ..
      '\n' ..
      'SFX 391 Y 1\n' ..
      'SFX 391 0 a1 .\n' ..
      '\n' ..
      'SFX 111 Y 1\n' ..
      'SFX 111 0 a\xe9'..
      ' .\n' ..
      '\n' ..
      'PFX 17 Y 1\n' ..
      'PFX 17 0 pre/432 .\n')
  end)

  it('is working', function()
    insert([[
      affstart_sal
      SET ISO8859-1
      TRY esianrtolcdugmphbyfvkwjkqxz-ëéèêïîäàâöüû'ESIANRTOLCDUGMPHBYFVKWJKQXZ
      
      FOL  àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþßÿ
      LOW  àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþßÿ
      UPP  ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞßÿ
      
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
      MAP yÿý
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
      
      test output:]])

    -- Don't want to depend on the locale from the environment.  The .aff and .dic.
    -- Text is in latin1, the test text is utf-8.
    execute('set enc=latin1')
    execute('e!')
    execute('set enc=utf-8')
    execute('set fenc=')

    -- Function to test .aff/.dic with list of good and bad words.
    source([[
      func TestOne(aff, dic)
        set spellfile=
        $put =''
        $put ='test '. a:aff . '-' . a:dic
	"  Generate a .spl file from a .dic and .aff file.
	exe '!cp -f Xtest'.a:aff.'.aff Xtest.aff'
	if str2nr(a:dic) <= 1
	  exe '1;/^' . a:dic . 'dicstart/+1,/^' . a:dic . 'dicend/-1w! Xtest.dic'
	else
	  exe '!cp -f Xtest'.a:dic.'.dic Xtest.dic'
	endif
        mkspell! Xtest Xtest
	"  Use that spell file.
        set spl=Xtest.utf-8.spl spell
	"  List all valid words.
        spelldump
        %yank
        quit
        $put
        $put ='-------'
	"  Find all bad words and suggestions for them.
        exe '1;/^' . a:aff . 'good:'
        normal 0f:]s
        let prevbad = ''
        while 1
          let [bad, a] = spellbadword()
          if bad == '' || bad == prevbad || bad == 'badend'
            break
          endif
          let prevbad = bad
          let lst = spellsuggest(bad, 3)
          normal mm
          $put =bad
          $put =string(lst)
          normal `m]s
        endwhile
      endfunc
    ]])

    execute([[call TestOne('1', '1')]])
    execute([[$put =soundfold('goobledygoook')]])
    execute([[$put =soundfold('kÃ³opÃ«rÃ¿nÃ´ven')]])
    execute([[$put =soundfold('oeverloos gezwets edale')]])


    -- And now with SAL instead of SOFO items; test automatic reloading.
    feed('gg')
    execute(':/^affstart_sal/+1,/^affend_sal/-1w! Xtest.aff')
    execute('mkspell! Xtest Xtest')
    execute([[$put =soundfold('goobledygoook')]])
    execute([[$put =soundfold('kÃ³opÃ«rÃ¿nÃ´ven')]])
    execute([[$put =soundfold('oeverloos gezwets edale')]])

    -- Also use an addition file.
    feed('gg')
    execute(':/^addstart/+1,/^addend/-1w! Xtest.utf-8.add')
    execute('mkspell! Xtest.utf-8.add.spl Xtest.utf-8.add')
    execute('set spellfile=Xtest.utf-8.add')
    execute('/^test2:')
    feed(']s')
    execute('let [str, a] = spellbadword()')
    execute('$put =str')
    execute('set spl=Xtest_us.utf-8.spl')
    execute('/^test2:')
    feed(']smm')
    execute('let [str, a] = spellbadword()')
    execute('$put =str')
    feed('`m]s')
    execute('let [str, a] = spellbadword()')
    execute('$put =str')
    execute('set spl=Xtest_gb.utf-8.spl')
    execute('/^test2:')
    feed(']smm')
    execute('let [str, a] = spellbadword()')
    execute('$put =str')
    feed('`m]s')
    execute('let [str, a] = spellbadword()')
    execute('$put =str')
    execute('set spl=Xtest_nz.utf-8.spl')
    execute('/^test2:')
    feed(']smm')
    execute('let [str, a] = spellbadword()')
    execute('$put =str')
    feed('`m]s')
    execute('let [str, a] = spellbadword()')
    execute('$put =str')
    execute('set spl=Xtest_ca.utf-8.spl')
    execute('/^test2:')
    feed(']smm')
    execute('let [str, a] = spellbadword()')
    execute('$put =str')
    feed('`m]s')
    execute('let [str, a] = spellbadword()')
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

    execute('0,/^test output:/-1 delete')

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
