-- Tests for spell checking with 'encoding' set to "utf-8".

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect
local write_file, eq, eval = helpers.write_file, helpers.eq, helpers.eval

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
    write_file('Xtest3.dic',
      '1234\nfoo/m\nbar/mx\n\x6d\xef\x2f\x6d\n\x6c\x61\x2f\x6d\x78\n')
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
    write_file('Xtest4.dic', [[
      1234
      word/mP
      util/am
      pro/xq
      tomato/m
      bork/mp
      start/s
      end/e
      ]])
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
    write_file('Xtest5.dic',
      '1234\nfoo/a1a\xe9!!\nbar/zz13ee\nstart/ss\nend/eeyy\nmiddle/mmxx\n')
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
    write_file('Xtest6.dic',
      '1234\nmee/A1A\xe9A!\nbar/ZzN3Ee\nlead/s\nend/Ee\nmiddle/MmXx\n')
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
    write_file('Xtest7.dic', [[
      1234
      mee/391,111,9999
      bar/17,61003,123
      lead/2
      tail/123
      middle/77,1
      ]])
    write_file('Xtest-sal.aff',
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
      'MAP s\xdf\n' ..
      '\n' ..
      'SAL AH(AEIOUY)-^         *H\n' ..
      'SAL AR(AEIOUY)-^         *R\n' ..
      'SAL A(HR)^               *\n' ..
      'SAL A^                   *\n' ..
      'SAL AH(AEIOUY)-          H\n' ..
      'SAL AR(AEIOUY)-          R\n' ..
      'SAL A(HR)                _\n' ..
      'SAL \xc0^                   *\n' ..
      'SAL \xc5^                   *\n' ..
      'SAL BB-                  _\n' ..
      'SAL B                    B\n' ..
      'SAL CQ-                  _\n' ..
      'SAL CIA                  X\n' ..
      'SAL CH                   X\n' ..
      'SAL C(EIY)-              S\n' ..
      'SAL CK                   K\n' ..
      'SAL COUGH^               KF\n' ..
      'SAL CC<                  C\n' ..
      'SAL C                    K\n' ..
      'SAL DG(EIY)              K\n' ..
      'SAL DD-                  _\n' ..
      'SAL D                    T\n' ..
      'SAL \xc9<                   E\n' ..
      'SAL EH(AEIOUY)-^         *H\n' ..
      'SAL ER(AEIOUY)-^         *R\n' ..
      'SAL E(HR)^               *\n' ..
      'SAL ENOUGH^$             *NF\n' ..
      'SAL E^                   *\n' ..
      'SAL EH(AEIOUY)-          H\n' ..
      'SAL ER(AEIOUY)-          R\n' ..
      'SAL E(HR)                _\n' ..
      'SAL FF-                  _\n' ..
      'SAL F                    F\n' ..
      'SAL GN^                  N\n' ..
      'SAL GN$                  N\n' ..
      'SAL GNS$                 NS\n' ..
      'SAL GNED$                N\n' ..
      'SAL GH(AEIOUY)-          K\n' ..
      'SAL GH                   _\n' ..
      'SAL GG9                  K\n' ..
      'SAL G                    K\n' ..
      'SAL H                    H\n' ..
      'SAL IH(AEIOUY)-^         *H\n' ..
      'SAL IR(AEIOUY)-^         *R\n' ..
      'SAL I(HR)^               *\n' ..
      'SAL I^                   *\n' ..
      'SAL ING6                 N\n' ..
      'SAL IH(AEIOUY)-          H\n' ..
      'SAL IR(AEIOUY)-          R\n' ..
      'SAL I(HR)                _\n' ..
      'SAL J                    K\n' ..
      'SAL KN^                  N\n' ..
      'SAL KK-                  _\n' ..
      'SAL K                    K\n' ..
      'SAL LAUGH^               LF\n' ..
      'SAL LL-                  _\n' ..
      'SAL L                    L\n' ..
      'SAL MB$                  M\n' ..
      'SAL MM                   M\n' ..
      'SAL M                    M\n' ..
      'SAL NN-                  _\n' ..
      'SAL N                    N\n' ..
      'SAL OH(AEIOUY)-^         *H\n' ..
      'SAL OR(AEIOUY)-^         *R\n' ..
      'SAL O(HR)^               *\n' ..
      'SAL O^                   *\n' ..
      'SAL OH(AEIOUY)-          H\n' ..
      'SAL OR(AEIOUY)-          R\n' ..
      'SAL O(HR)                _\n' ..
      'SAL PH                   F\n' ..
      'SAL PN^                  N\n' ..
      'SAL PP-                  _\n' ..
      'SAL P                    P\n' ..
      'SAL Q                    K\n' ..
      'SAL RH^                  R\n' ..
      'SAL ROUGH^               RF\n' ..
      'SAL RR-                  _\n' ..
      'SAL R                    R\n' ..
      'SAL SCH(EOU)-            SK\n' ..
      'SAL SC(IEY)-             S\n' ..
      'SAL SH                   X\n' ..
      'SAL SI(AO)-              X\n' ..
      'SAL SS-                  _\n' ..
      'SAL S                    S\n' ..
      'SAL TI(AO)-              X\n' ..
      'SAL TH                   @\n' ..
      'SAL TCH--                _\n' ..
      'SAL TOUGH^               TF\n' ..
      'SAL TT-                  _\n' ..
      'SAL T                    T\n' ..
      'SAL UH(AEIOUY)-^         *H\n' ..
      'SAL UR(AEIOUY)-^         *R\n' ..
      'SAL U(HR)^               *\n' ..
      'SAL U^                   *\n' ..
      'SAL UH(AEIOUY)-          H\n' ..
      'SAL UR(AEIOUY)-          R\n' ..
      'SAL U(HR)                _\n' ..
      'SAL V^                   W\n' ..
      'SAL V                    F\n' ..
      'SAL WR^                  R\n' ..
      'SAL WH^                  W\n' ..
      'SAL W(AEIOU)-            W\n' ..
      'SAL X^                   S\n' ..
      'SAL X                    KS\n' ..
      'SAL Y(AEIOU)-            Y\n' ..
      'SAL ZZ-                  _\n' ..
      'SAL Z                    S\n')
    write_file('Xtest.utf-8.add', [[
      /regions=usgbnz
      elequint/2
      elekwint/3
      ]])
  end)

  teardown(function()
    os.remove('Xtest-sal.aff')
    os.remove('Xtest.aff')
    os.remove('Xtest.dic')
    os.remove('Xtest.utf-8.add')
    os.remove('Xtest.utf-8.add.spl')
    os.remove('Xtest.utf-8.spl')
    os.remove('Xtest.utf-8.sug')
    os.remove('Xtest1.aff')
    os.remove('Xtest1.dic')
    os.remove('Xtest2.aff')
    os.remove('Xtest3.aff')
    os.remove('Xtest3.dic')
    os.remove('Xtest4.aff')
    os.remove('Xtest4.dic')
    os.remove('Xtest5.aff')
    os.remove('Xtest5.dic')
    os.remove('Xtest6.aff')
    os.remove('Xtest6.dic')
    os.remove('Xtest7.aff')
    os.remove('Xtest7.dic')
  end)

  -- Function to test .aff/.dic with list of good and bad words.  This was a
  -- Vim function in the original legacy test.
  local function test_one(aff, dic)
    -- Generate a .spl file from a .dic and .aff file.
    os.execute('cp -f Xtest'..aff..'.aff Xtest.aff')
    os.execute('cp -f Xtest'..dic..'.dic Xtest.dic')
    source([[
      set spellfile=
      function! SpellDumpNoShow()
        " spelling score depend on what happens to be drawn on screen
        spelldump
        %yank
        quit
      endfunction
      $put =''
      $put ='test ]]..aff..'-'..dic..[['
      mkspell! Xtest Xtest
      "  Use that spell file.
      set spl=Xtest.utf-8.spl spell
      "  List all valid words.
      call SpellDumpNoShow()
      $put
      $put ='-------'
      "  Find all bad words and suggestions for them.
      1;/^]]..aff..[[good:
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
      ]])
  end

  it('part 1-1', function()
    insert([[
      1good: wrong OK puts. Test the end
      bad:  inputs comment ok Ok. test déôl end the
      badend
      
      test2:
      elequint test elekwint test elekwent asdf
      ]])
    test_one(1, 1)
    execute([[$put =soundfold('goobledygoook')]])
    eq('gebletegek', eval('soundfold("goobledygoook")'))
    execute([[$put =soundfold('kóopërÿnôven')]])
    eq('kepereneven', eval('soundfold("kóopërÿnôven")'))
    execute([[$put =soundfold('oeverloos gezwets edale')]])
    -- And now with SAL instead of SOFO items; test automatic reloading.
    os.execute('cp -f Xtest-sal.aff Xtest.aff')
    execute('mkspell! Xtest Xtest')
    execute([[$put =soundfold('goobledygoook')]])
    execute([[$put =soundfold('kóopërÿnôven')]])
    execute([[$put =soundfold('oeverloos gezwets edale')]])
    -- Also use an addition file.
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
    execute('1,/^test 1-1/-1d')
    expect([[
      test 1-1
      # file: Xtest.utf-8.spl
      Comment
      deol
      déôr
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
      déôl
      ['deol', 'déôr', 'test']
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
      elekwint]])
  end)

  it('part 2-1', function()
    insert([[
      2good: puts
      bad: inputs comment ok Ok end the. test déôl
      badend
      ]])
    -- Postponed prefixes.
    test_one(2, 1)
    execute('1,/^test 2-1/-1d')
    expect([=[
      test 2-1
      # file: Xtest.utf-8.spl
      Comment
      deol
      déôr
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
      déôl
      ['deol', 'déôr', 'test']]=])
  end)

  it('part 3-3', function()
    insert([[
      Test rules for compounding.
      
      3good: foo mï foobar foofoobar barfoo barbarfoo
      bad: bar la foomï barmï mïfoo mïbar mïmï lala mïla lamï foola labar
      badend
      ]])
    test_one(3, 3)
    execute('1,/^test 3-3/-1d')
    expect([=[
      test 3-3
      # file: Xtest.utf-8.spl
      foo
      mï
      -------
      bad
      ['foo', 'mï']
      bar
      ['barfoo', 'foobar', 'foo']
      la
      ['mï', 'foo']
      foomï
      ['foo mï', 'foo', 'foofoo']
      barmï
      ['barfoo', 'mï', 'barbar']
      mïfoo
      ['mï foo', 'foo', 'foofoo']
      mïbar
      ['foobar', 'barbar', 'mï']
      mïmï
      ['mï mï', 'mï']
      lala
      []
      mïla
      ['mï', 'mï mï']
      lamï
      ['mï', 'mï mï']
      foola
      ['foo', 'foobar', 'foofoo']
      labar
      ['barbar', 'foobar']]=])
  end)

  it('part 4-4', function()
    insert([[
      Tests for compounding.
      
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
      ]])
    test_one(4, 4)
    execute('1,/^test 4-4/-1d')
    expect([=[
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
      ['start nouword', 'startword', 'startborkword']]=])
  end)

  it('part 5-5', function()
    insert([[
      Test affix flags with two characters
      
      5good: fooa1 fooaé bar prebar barbork prebarbork  startprebar
            start end startend  startmiddleend nouend
      bad: foo fooa2 prabar probarbirk middle startmiddle middleend endstart
      	startprobar startnouend
      badend
      ]])
    test_one(5, 5)
    execute('1,/^test 5-5/-1d')
    expect([=[
      test 5-5
      # file: Xtest.utf-8.spl
      bar
      barbork
      end
      fooa1
      fooaé
      nouend
      prebar
      prebarbork
      start
      -------
      bad
      ['bar', 'end', 'fooa1']
      foo
      ['fooa1', 'fooaé', 'bar']
      fooa2
      ['fooa1', 'fooaé', 'bar']
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
      ['start nouend', 'startend']]=])
  end)

  it('part 6-6', function()
    insert([[
      6good: meea1 meeaé bar prebar barbork prebarbork  leadprebar
            lead end leadend  leadmiddleend
      bad: mee meea2 prabar probarbirk middle leadmiddle middleend endlead
      	leadprobar
      badend
      ]])
    test_one(6, 6)
    execute('1,/^test 6-6/-1d')
    expect([=[
      test 6-6
      # file: Xtest.utf-8.spl
      bar
      barbork
      end
      lead
      meea1
      meeaé
      prebar
      prebarbork
      -------
      bad
      ['bar', 'end', 'lead']
      mee
      ['meea1', 'meeaé', 'bar']
      meea2
      ['meea1', 'meeaé', 'lead']
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
      ['leadprebar', 'lead prebar', 'leadbar']]=])
  end)

  it('part 7-7', function()
    insert([[
      7good: meea1 meeaé bar prebar barmeat prebarmeat  leadprebar
            lead tail leadtail  leadmiddletail
      bad: mee meea2 prabar probarmaat middle leadmiddle middletail taillead
      	leadprobar
      badend
      ]])
    -- Compound words.
    test_one(7, 7)
    -- Assert buffer contents.
    execute('1,/^test 7-7/-1d')
    expect([=[
      test 7-7
      # file: Xtest.utf-8.spl
      bar
      barmeat
      lead
      meea1
      meeaé
      prebar
      prebarmeat
      tail
      -------
      bad
      ['bar', 'lead', 'tail']
      mee
      ['meea1', 'meeaé', 'bar']
      meea2
      ['meea1', 'meeaé', 'lead']
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
