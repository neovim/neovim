" Test for spell checking with 'encoding' set to utf-8

source check.vim
CheckFeature spell

scriptencoding utf-8

func TearDown()
  set nospell
  call delete('Xtest.aff')
  call delete('Xtest.dic')
  call delete('Xtest.utf-8.add')
  call delete('Xtest.utf-8.add.spl')
  call delete('Xtest.utf-8.spl')
  call delete('Xtest.utf-8.sug')
  " set 'encoding' to clear the word list
  set encoding=utf-8
endfunc

let g:test_data_aff1 = [
      \"SET ISO8859-1",
      \"TRY esianrtolcdugmphbyfvkwjkqxz-ëéèêïîäàâöüû'ESIANRTOLCDUGMPHBYFVKWJKQXZ",
      \"",
      \"FOL  àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþßÿ",
      \"LOW  àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþßÿ",
      \"UPP  ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞßÿ",
      \"",
      \"SOFOFROM abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ\xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF\xC0\xC1\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xBF",
      \"SOFOTO   ebctefghejklnnepkrstevvkesebctefghejklnnepkrstevvkeseeeeeeeceeeeeeeedneeeeeeeeeeepseeeeeeeeceeeeeeeedneeeeeeeeeeep?",
      \"",
      \"MIDWORD\t'-",
      \"",
      \"KEP =",
      \"RAR ?",
      \"BAD !",
      \"",
      \"PFX I N 1",
      \"PFX I 0 in .",
      \"",
      \"PFX O Y 1",
      \"PFX O 0 out .",
      \"",
      \"SFX S Y 2",
      \"SFX S 0 s [^s]",
      \"SFX S 0 es s",
      \"",
      \"SFX N N 3",
      \"SFX N 0 en [^n]",
      \"SFX N 0 nen n",
      \"SFX N 0 n .",
      \"",
      \"REP 3",
      \"REP g ch",
      \"REP ch g",
      \"REP svp s.v.p.",
      \"",
      \"MAP 9",
      \"MAP a\xE0\xE1\xE2\xE3\xE4\xE5",
      \"MAP e\xE8\xE9\xEA\xEB",
      \"MAP i\xEC\xED\xEE\xEF",
      \"MAP o\xF2\xF3\xF4\xF5\xF6",
      \"MAP u\xF9\xFA\xFB\xFC",
      \"MAP n\xF1",
      \"MAP c\xE7",
      \"MAP y\xFF\xFD",
      \"MAP s\xDF"
      \ ]
let g:test_data_dic1 = [
      \"123456",
      \"test/NO",
      \"# comment",
      \"wrong",
      \"Comment",
      \"OK",
      \"uk",
      \"put/ISO",
      \"the end",
      \"deol",
      \"d\xE9\xF4r",
      \ ]
let g:test_data_aff2 = [
      \"SET ISO8859-1",
      \"",
      \"FOL  \xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF",
      \"LOW  \xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF",
      \"UPP  \xC0\xC1\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xDF\xFF",
      \"",
      \"PFXPOSTPONE",
      \"",
      \"MIDWORD\t'-",
      \"",
      \"KEP =",
      \"RAR ?",
      \"BAD !",
      \"",
      \"PFX I N 1",
      \"PFX I 0 in .",
      \"",
      \"PFX O Y 1",
      \"PFX O 0 out [a-z]",
      \"",
      \"SFX S Y 2",
      \"SFX S 0 s [^s]",
      \"SFX S 0 es s",
      \"",
      \"SFX N N 3",
      \"SFX N 0 en [^n]",
      \"SFX N 0 nen n",
      \"SFX N 0 n .",
      \"",
      \"REP 3",
      \"REP g ch",
      \"REP ch g",
      \"REP svp s.v.p.",
      \"",
      \"MAP 9",
      \"MAP a\xE0\xE1\xE2\xE3\xE4\xE5",
      \"MAP e\xE8\xE9\xEA\xEB",
      \"MAP i\xEC\xED\xEE\xEF",
      \"MAP o\xF2\xF3\xF4\xF5\xF6",
      \"MAP u\xF9\xFA\xFB\xFC",
      \"MAP n\xF1",
      \"MAP c\xE7",
      \"MAP y\xFF\xFD",
      \"MAP s\xDF",
      \ ]
let g:test_data_aff3 = [
      \"SET ISO8859-1",
      \"",
      \"COMPOUNDMIN 3",
      \"COMPOUNDRULE m*",
      \"NEEDCOMPOUND x",
      \ ]
let g:test_data_dic3 = [
      \"1234",
      \"foo/m",
      \"bar/mx",
      \"m\xEF/m",
      \"la/mx",
      \ ]
let g:test_data_aff4 = [
      \"SET ISO8859-1",
      \"",
      \"FOL  \xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF",
      \"LOW  \xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF",
      \"UPP  \xC0\xC1\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xDF\xFF",
      \"",
      \"COMPOUNDRULE m+",
      \"COMPOUNDRULE sm*e",
      \"COMPOUNDRULE sm+",
      \"COMPOUNDMIN 3",
      \"COMPOUNDWORDMAX 3",
      \"COMPOUNDFORBIDFLAG t",
      \"",
      \"COMPOUNDSYLMAX 5",
      \"SYLLABLE a\xE1e\xE9i\xEDo\xF3\xF6\xF5u\xFA\xFC\xFBy/aa/au/ea/ee/ei/ie/oa/oe/oo/ou/uu/ui",
      \"",
      \"MAP 9",
      \"MAP a\xE0\xE1\xE2\xE3\xE4\xE5",
      \"MAP e\xE8\xE9\xEA\xEB",
      \"MAP i\xEC\xED\xEE\xEF",
      \"MAP o\xF2\xF3\xF4\xF5\xF6",
      \"MAP u\xF9\xFA\xFB\xFC",
      \"MAP n\xF1",
      \"MAP c\xE7",
      \"MAP y\xFF\xFD",
      \"MAP s\xDF",
      \"",
      \"NEEDAFFIX x",
      \"",
      \"PFXPOSTPONE",
      \"",
      \"MIDWORD '-",
      \"",
      \"SFX q N 1",
      \"SFX q   0    -ok .",
      \"",
      \"SFX a Y 2",
      \"SFX a 0 s .",
      \"SFX a 0 ize/t .",
      \"",
      \"PFX p N 1",
      \"PFX p 0 pre .",
      \"",
      \"PFX P N 1",
      \"PFX P 0 nou .",
      \ ]
let g:test_data_dic4 = [
      \"1234",
      \"word/mP",
      \"util/am",
      \"pro/xq",
      \"tomato/m",
      \"bork/mp",
      \"start/s",
      \"end/e",
      \ ]
let g:test_data_aff5 = [
      \"SET ISO8859-1",
      \"",
      \"FLAG long",
      \"",
      \"NEEDAFFIX !!",
      \"",
      \"COMPOUNDRULE ssmm*ee",
      \"",
      \"NEEDCOMPOUND xx",
      \"COMPOUNDPERMITFLAG pp",
      \"",
      \"SFX 13 Y 1",
      \"SFX 13 0 bork .",
      \"",
      \"SFX a1 Y 1",
      \"SFX a1 0 a1 .",
      \"",
      \"SFX a\xE9 Y 1",
      \"SFX a\xE9 0 a\xE9 .",
      \"",
      \"PFX zz Y 1",
      \"PFX zz 0 pre/pp .",
      \"",
      \"PFX yy Y 1",
      \"PFX yy 0 nou .",
      \ ]
let g:test_data_dic5 = [
      \"1234",
      \"foo/a1a\xE9!!",
      \"bar/zz13ee",
      \"start/ss",
      \"end/eeyy",
      \"middle/mmxx",
      \ ]
let g:test_data_aff6 = [
      \"SET ISO8859-1",
      \"",
      \"FLAG caplong",
      \"",
      \"NEEDAFFIX A!",
      \"",
      \"COMPOUNDRULE sMm*Ee",
      \"",
      \"NEEDCOMPOUND Xx",
      \"",
      \"COMPOUNDPERMITFLAG p",
      \"",
      \"SFX N3 Y 1",
      \"SFX N3 0 bork .",
      \"",
      \"SFX A1 Y 1",
      \"SFX A1 0 a1 .",
      \"",
      \"SFX A\xE9 Y 1",
      \"SFX A\xE9 0 a\xE9 .",
      \"",
      \"PFX Zz Y 1",
      \"PFX Zz 0 pre/p .",
      \ ]
let g:test_data_dic6 = [
      \"1234",
      \"mee/A1A\xE9A!",
      \"bar/ZzN3Ee",
      \"lead/s",
      \"end/Ee",
      \"middle/MmXx",
      \ ]
let g:test_data_aff7 = [
      \"SET ISO8859-1",
      \"",
      \"FLAG num",
      \"",
      \"NEEDAFFIX 9999",
      \"",
      \"COMPOUNDRULE 2,77*123",
      \"",
      \"NEEDCOMPOUND 1",
      \"COMPOUNDPERMITFLAG 432",
      \"",
      \"SFX 61003 Y 1",
      \"SFX 61003 0 meat .",
      \"",
      \"SFX 0 Y 1",
      \"SFX 0 0 zero .",
      \"",
      \"SFX 391 Y 1",
      \"SFX 391 0 a1 .",
      \"",
      \"SFX 111 Y 1",
      \"SFX 111 0 a\xE9 .",
      \"",
      \"PFX 17 Y 1",
      \"PFX 17 0 pre/432 .",
      \ ]
let g:test_data_dic7 = [
      \"1234",
      \"mee/0,391,111,9999",
      \"bar/17,61003,123",
      \"lead/2",
      \"tail/123",
      \"middle/77,1",
      \ ]
let g:test_data_aff8 = [
      \"SET ISO8859-1",
      \"",
      \"NOSPLITSUGS",
      \ ]
let g:test_data_dic8 = [
      \"1234",
      \"foo",
      \"bar",
      \"faabar",
      \ ]
let g:test_data_aff9 = [
      \ ]
let g:test_data_dic9 = [
      \"1234",
      \"foo",
      \"bar",
      \ ]
let g:test_data_aff10 = [
      \"COMPOUNDRULE se",
      \"COMPOUNDPERMITFLAG p",
      \"",
      \"SFX A Y 1",
      \"SFX A 0 able/Mp .",
      \"",
      \"SFX M Y 1",
      \"SFX M 0 s .",
      \ ]
let g:test_data_dic10 = [
      \"1234",
      \"drink/As",
      \"table/e",
      \ ]
let g:test_data_aff_sal = [
      \"SET ISO8859-1",
      \"TRY esianrtolcdugmphbyfvkwjkqxz-\xEB\xE9\xE8\xEA\xEF\xEE\xE4\xE0\xE2\xF6\xFC\xFB'ESIANRTOLCDUGMPHBYFVKWJKQXZ",
      \"",
      \"FOL  \xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF",
      \"LOW  \xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF",
      \"UPP  \xC0\xC1\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xDF\xFF",
      \"",
      \"MIDWORD\t'-",
      \"",
      \"KEP =",
      \"RAR ?",
      \"BAD !",
      \"",
      \"PFX I N 1",
      \"PFX I 0 in .",
      \"",
      \"PFX O Y 1",
      \"PFX O 0 out .",
      \"",
      \"SFX S Y 2",
      \"SFX S 0 s [^s]",
      \"SFX S 0 es s",
      \"",
      \"SFX N N 3",
      \"SFX N 0 en [^n]",
      \"SFX N 0 nen n",
      \"SFX N 0 n .",
      \"",
      \"REP 3",
      \"REP g ch",
      \"REP ch g",
      \"REP svp s.v.p.",
      \"",
      \"MAP 9",
      \"MAP a\xE0\xE1\xE2\xE3\xE4\xE5",
      \"MAP e\xE8\xE9\xEA\xEB",
      \"MAP i\xEC\xED\xEE\xEF",
      \"MAP o\xF2\xF3\xF4\xF5\xF6",
      \"MAP u\xF9\xFA\xFB\xFC",
      \"MAP n\xF1",
      \"MAP c\xE7",
      \"MAP y\xFF\xFD",
      \"MAP s\xDF",
      \"",
      \"SAL AH(AEIOUY)-^         *H",
      \"SAL AR(AEIOUY)-^         *R",
      \"SAL A(HR)^               *",
      \"SAL A^                   *",
      \"SAL AH(AEIOUY)-          H",
      \"SAL AR(AEIOUY)-          R",
      \"SAL A(HR)                _",
      \"SAL \xC0^                   *",
      \"SAL \xC5^                   *",
      \"SAL BB-                  _",
      \"SAL B                    B",
      \"SAL CQ-                  _",
      \"SAL CIA                  X",
      \"SAL CH                   X",
      \"SAL C(EIY)-              S",
      \"SAL CK                   K",
      \"SAL COUGH^               KF",
      \"SAL CC<                  C",
      \"SAL C                    K",
      \"SAL DG(EIY)              K",
      \"SAL DD-                  _",
      \"SAL D                    T",
      \"SAL \xC9<                   E",
      \"SAL EH(AEIOUY)-^         *H",
      \"SAL ER(AEIOUY)-^         *R",
      \"SAL E(HR)^               *",
      \"SAL ENOUGH^$             *NF",
      \"SAL E^                   *",
      \"SAL EH(AEIOUY)-          H",
      \"SAL ER(AEIOUY)-          R",
      \"SAL E(HR)                _",
      \"SAL FF-                  _",
      \"SAL F                    F",
      \"SAL GN^                  N",
      \"SAL GN$                  N",
      \"SAL GNS$                 NS",
      \"SAL GNED$                N",
      \"SAL GH(AEIOUY)-          K",
      \"SAL GH                   _",
      \"SAL GG9                  K",
      \"SAL G                    K",
      \"SAL H                    H",
      \"SAL IH(AEIOUY)-^         *H",
      \"SAL IR(AEIOUY)-^         *R",
      \"SAL I(HR)^               *",
      \"SAL I^                   *",
      \"SAL ING6                 N",
      \"SAL IH(AEIOUY)-          H",
      \"SAL IR(AEIOUY)-          R",
      \"SAL I(HR)                _",
      \"SAL J                    K",
      \"SAL KN^                  N",
      \"SAL KK-                  _",
      \"SAL K                    K",
      \"SAL LAUGH^               LF",
      \"SAL LL-                  _",
      \"SAL L                    L",
      \"SAL MB$                  M",
      \"SAL MM                   M",
      \"SAL M                    M",
      \"SAL NN-                  _",
      \"SAL N                    N",
      \"SAL OH(AEIOUY)-^         *H",
      \"SAL OR(AEIOUY)-^         *R",
      \"SAL O(HR)^               *",
      \"SAL O^                   *",
      \"SAL OH(AEIOUY)-          H",
      \"SAL OR(AEIOUY)-          R",
      \"SAL O(HR)                _",
      \"SAL PH                   F",
      \"SAL PN^                  N",
      \"SAL PP-                  _",
      \"SAL P                    P",
      \"SAL Q                    K",
      \"SAL RH^                  R",
      \"SAL ROUGH^               RF",
      \"SAL RR-                  _",
      \"SAL R                    R",
      \"SAL SCH(EOU)-            SK",
      \"SAL SC(IEY)-             S",
      \"SAL SH                   X",
      \"SAL SI(AO)-              X",
      \"SAL SS-                  _",
      \"SAL S                    S",
      \"SAL TI(AO)-              X",
      \"SAL TH                   @",
      \"SAL TCH--                _",
      \"SAL TOUGH^               TF",
      \"SAL TT-                  _",
      \"SAL T                    T",
      \"SAL UH(AEIOUY)-^         *H",
      \"SAL UR(AEIOUY)-^         *R",
      \"SAL U(HR)^               *",
      \"SAL U^                   *",
      \"SAL UH(AEIOUY)-          H",
      \"SAL UR(AEIOUY)-          R",
      \"SAL U(HR)                _",
      \"SAL V^                   W",
      \"SAL V                    F",
      \"SAL WR^                  R",
      \"SAL WH^                  W",
      \"SAL W(AEIOU)-            W",
      \"SAL X^                   S",
      \"SAL X                    KS",
      \"SAL Y(AEIOU)-            Y",
      \"SAL ZZ-                  _",
      \"SAL Z                    S",
      \ ]

func LoadAffAndDic(aff_contents, dic_contents)
  set spellfile=
  call writefile(a:aff_contents, "Xtest.aff")
  call writefile(a:dic_contents, "Xtest.dic")
  " Generate a .spl file from a .dic and .aff file.
  mkspell! Xtest Xtest
  " use that spell file
  set spl=Xtest.utf-8.spl spell
endfunc

func ListWords()
  spelldump
  %yank
  quit
  return split(@", "\n")
endfunc

func TestGoodBadBase()
  exe '1;/^good:'
  normal 0f:]s
  let prevbad = ''
  let result = []
  while 1
    let [bad, a] = spellbadword()
    if bad == '' || bad == prevbad || bad == 'badend'
      break
    endif
    let prevbad = bad
    let lst = bad->spellsuggest(3)
    normal mm

    call add(result, [bad, lst])
    normal `m]s
  endwhile
  return result
endfunc

func RunGoodBad(good, bad, expected_words, expected_bad_words)
  %bwipe!
  call setline(1, ['', "good: ", a:good,  a:bad, " badend "])
  let words = ListWords()
  call assert_equal(a:expected_words, words[1:-1])
  let bad_words = TestGoodBadBase()
  call assert_equal(a:expected_bad_words, bad_words)
  %bwipe!
endfunc

func Test_spell_basic()
  call LoadAffAndDic(g:test_data_aff1, g:test_data_dic1)
  call RunGoodBad("wrong OK puts. Test the end",
        \ "bad: inputs comment ok Ok. test d\u00E9\u00F4l end the",
        \["Comment", "deol", "d\u00E9\u00F4r", "input", "OK", "output", "outputs", "outtest", "put", "puts",
        \  "test", "testen", "testn", "the end", "uk", "wrong"],
        \[
        \   ["bad", ["put", "uk", "OK"]],
        \   ["inputs", ["input", "puts", "outputs"]],
        \   ["comment", ["Comment", "outtest", "the end"]],
        \   ["ok", ["OK", "uk", "put"]],
        \   ["Ok", ["OK", "Uk", "Put"]],
        \   ["test", ["Test", "testn", "testen"]],
        \   ["d\u00E9\u00F4l", ["deol", "d\u00E9\u00F4r", "test"]],
        \   ["end", ["put", "uk", "test"]],
        \   ["the", ["put", "uk", "test"]],
        \ ]
        \ )

  call assert_equal("gebletegek", soundfold('goobledygoook'))
  call assert_equal("kepereneven", 'kóopërÿnôven'->soundfold())
  call assert_equal("everles gesvets etele", soundfold('oeverloos gezwets edale'))
endfunc

" Postponed prefixes
func Test_spell_prefixes()
  call LoadAffAndDic(g:test_data_aff2, g:test_data_dic1)
  call RunGoodBad("puts",
        \ "bad: inputs comment ok Ok end the. test d\u00E9\u00F4l",
        \ ["Comment", "deol", "d\u00E9\u00F4r", "OK", "put", "input", "output", "puts", "outputs", "test", "outtest", "testen", "testn", "the end", "uk", "wrong"],
        \ [
        \   ["bad", ["put", "uk", "OK"]],
        \   ["inputs", ["input", "puts", "outputs"]],
        \   ["comment", ["Comment"]],
        \   ["ok", ["OK", "uk", "put"]],
        \   ["Ok", ["OK", "Uk", "Put"]],
        \   ["end", ["put", "uk", "deol"]],
        \   ["the", ["put", "uk", "test"]],
        \   ["test", ["Test", "testn", "testen"]],
        \   ["d\u00E9\u00F4l", ["deol", "d\u00E9\u00F4r", "test"]],
        \ ])
endfunc

"Compound words
func Test_spell_compound()
  call LoadAffAndDic(g:test_data_aff3, g:test_data_dic3)
  call RunGoodBad("foo m\u00EF foobar foofoobar barfoo barbarfoo",
        \ "bad: bar la foom\u00EF barm\u00EF m\u00EFfoo m\u00EFbar m\u00EFm\u00EF lala m\u00EFla lam\u00EF foola labar",
        \ ["foo", "m\u00EF"],
        \ [
        \   ["bad", ["foo", "m\u00EF"]],
        \   ["bar", ["barfoo", "foobar", "foo"]],
        \   ["la", ["m\u00EF", "foo"]],
        \   ["foom\u00EF", ["foo m\u00EF", "foo", "foofoo"]],
        \   ["barm\u00EF", ["barfoo", "m\u00EF", "barbar"]],
        \   ["m\u00EFfoo", ["m\u00EF foo", "foo", "foofoo"]],
        \   ["m\u00EFbar", ["foobar", "barbar", "m\u00EF"]],
        \   ["m\u00EFm\u00EF", ["m\u00EF m\u00EF", "m\u00EF"]],
        \   ["lala", []],
        \   ["m\u00EFla", ["m\u00EF", "m\u00EF m\u00EF"]],
        \   ["lam\u00EF", ["m\u00EF", "m\u00EF m\u00EF"]],
        \   ["foola", ["foo", "foobar", "foofoo"]],
        \   ["labar", ["barbar", "foobar"]],
        \ ])

  call LoadAffAndDic(g:test_data_aff4, g:test_data_dic4)
  call RunGoodBad("word util bork prebork start end wordutil wordutils pro-ok bork borkbork borkborkbork borkborkborkbork borkborkborkborkbork tomato tomatotomato startend startword startwordword startwordend startwordwordend startwordwordwordend prebork preborkbork preborkborkbork nouword",
        \ "bad: wordutilize pro borkborkborkborkborkbork tomatotomatotomato endstart endend startstart wordend wordstart preborkprebork  preborkpreborkbork startwordwordwordwordend borkpreborkpreborkbork utilsbork  startnouword",
        \ ["bork", "prebork", "end", "pro-ok", "start", "tomato", "util", "utilize", "utils", "word", "nouword"],
        \ [
        \   ["bad", ["end", "bork", "word"]],
        \   ["wordutilize", ["word utilize", "wordutils", "wordutil"]],
        \   ["pro", ["bork", "word", "end"]],
        \   ["borkborkborkborkborkbork", ["bork borkborkborkborkbork", "borkbork borkborkborkbork", "borkborkbork borkborkbork"]],
        \   ["tomatotomatotomato", ["tomato tomatotomato", "tomatotomato tomato", "tomato tomato tomato"]],
        \   ["endstart", ["end start", "start"]],
        \   ["endend", ["end end", "end"]],
        \   ["startstart", ["start start"]],
        \   ["wordend", ["word end", "word", "wordword"]],
        \   ["wordstart", ["word start", "bork start"]],
        \   ["preborkprebork", ["prebork prebork", "preborkbork", "preborkborkbork"]],
        \   ["preborkpreborkbork", ["prebork preborkbork", "preborkborkbork", "preborkborkborkbork"]],
        \   ["startwordwordwordwordend", ["startwordwordwordword end", "startwordwordwordword", "start wordwordwordword end"]],
        \   ["borkpreborkpreborkbork", ["bork preborkpreborkbork", "bork prebork preborkbork", "bork preborkprebork bork"]],
        \   ["utilsbork", ["utilbork", "utils bork", "util bork"]],
        \   ["startnouword", ["start nouword", "startword", "startborkword"]],
        \ ])

endfunc

" Test affix flags with two characters
func Test_spell_affix()
  call LoadAffAndDic(g:test_data_aff5, g:test_data_dic5)
  call RunGoodBad("fooa1 fooa\u00E9 bar prebar barbork prebarbork  startprebar start end startend  startmiddleend nouend",
        \ "bad: foo fooa2 prabar probarbirk middle startmiddle middleend endstart startprobar startnouend",
        \ ["bar", "barbork", "end", "fooa1", "fooa\u00E9", "nouend", "prebar", "prebarbork", "start"],
        \ [
        \   ["bad", ["bar", "end", "fooa1"]],
        \   ["foo", ["fooa1", "bar", "end"]],
        \   ["fooa2", ["fooa1", "fooa\u00E9", "bar"]],
        \   ["prabar", ["prebar", "bar", "bar bar"]],
        \   ["probarbirk", ["prebarbork"]],
        \   ["middle", []],
        \   ["startmiddle", ["startmiddleend", "startmiddlebar"]],
        \   ["middleend", []],
        \   ["endstart", ["end start", "start"]],
        \   ["startprobar", ["startprebar", "start prebar", "startbar"]],
        \   ["startnouend", ["start nouend", "startend"]],
        \ ])

  call LoadAffAndDic(g:test_data_aff6, g:test_data_dic6)
  call RunGoodBad("meea1 meea\u00E9 bar prebar barbork prebarbork  leadprebar lead end leadend  leadmiddleend",
        \  "bad: mee meea2 prabar probarbirk middle leadmiddle middleend endlead leadprobar",
        \ ["bar", "barbork", "end", "lead", "meea1", "meea\u00E9", "prebar", "prebarbork"],
        \ [
        \   ["bad", ["bar", "end", "lead"]],
        \   ["mee", ["meea1", "bar", "end"]],
        \   ["meea2", ["meea1", "meea\u00E9", "lead"]],
        \   ["prabar", ["prebar", "bar", "leadbar"]],
        \   ["probarbirk", ["prebarbork"]],
        \   ["middle", []],
        \   ["leadmiddle", ["leadmiddleend", "leadmiddlebar"]],
        \   ["middleend", []],
        \   ["endlead", ["end lead", "lead", "end end"]],
        \   ["leadprobar", ["leadprebar", "lead prebar", "leadbar"]],
        \ ])

  call LoadAffAndDic(g:test_data_aff7, g:test_data_dic7)
  call RunGoodBad("meea1 meezero meea\u00E9 bar prebar barmeat prebarmeat  leadprebar lead tail leadtail  leadmiddletail",
        \ "bad: mee meea2 prabar probarmaat middle leadmiddle middletail taillead leadprobar",
        \ ["bar", "barmeat", "lead", "meea1", "meea\u00E9", "meezero", "prebar", "prebarmeat", "tail"],
        \ [
        \   ["bad", ["bar", "lead", "tail"]],
        \   ["mee", ["meea1", "bar", "lead"]],
        \   ["meea2", ["meea1", "meea\u00E9", "lead"]],
        \   ["prabar", ["prebar", "bar", "leadbar"]],
        \   ["probarmaat", ["prebarmeat"]],
        \   ["middle", []],
        \   ["leadmiddle", ["leadmiddlebar"]],
        \   ["middletail", []],
        \   ["taillead", ["tail lead", "tail"]],
        \   ["leadprobar", ["leadprebar", "lead prebar", "leadbar"]],
        \ ])
endfunc

func Test_spell_NOSLITSUGS()
  call LoadAffAndDic(g:test_data_aff8, g:test_data_dic8)
  call RunGoodBad("foo bar faabar", "bad: foobar barfoo",
        \ ["bar", "faabar", "foo"],
        \ [
        \   ["bad", ["bar", "foo"]],
        \   ["foobar", ["faabar", "foo bar", "bar"]],
        \   ["barfoo", ["bar foo", "bar", "foo"]],
        \ ])
endfunc

" Numbers
func Test_spell_Numbers()
  call LoadAffAndDic(g:test_data_aff9, g:test_data_dic9)
  call RunGoodBad("0b1011 0777 1234 0x01ff", "",
        \ ["bar", "foo"],
        \ [
        \ ])
endfunc

" Affix flags
func Test_spell_affix_flags()
  call LoadAffAndDic(g:test_data_aff10, g:test_data_dic10)
  call RunGoodBad("drink drinkable drinkables drinktable drinkabletable",
	\ "bad: drinks drinkstable drinkablestable",
        \ ["drink", "drinkable", "drinkables", "table"],
        \ [['bad', []],
	\ ['drinks', ['drink']],
	\ ['drinkstable', ['drinktable', 'drinkable', 'drink table']],
        \ ['drinkablestable', ['drinkabletable', 'drinkables table', 'drinkable table']],
	\ ])
endfunc

function FirstSpellWord()
  call feedkeys("/^start:\n", 'tx')
  normal ]smm
  let [str, a] = spellbadword()
  return str
endfunc

function SecondSpellWord()
  normal `m]s
  let [str, a] = spellbadword()
  return str
endfunc

" Test with SAL instead of SOFO items; test automatic reloading
func Test_spell_sal_and_addition()
  set spellfile=
  call writefile(g:test_data_dic1, "Xtest.dic", 'D')
  call writefile(g:test_data_aff_sal, "Xtest.aff", 'D')
  mkspell! Xtest Xtest
  set spl=Xtest.utf-8.spl spell
  call assert_equal('kbltykk', soundfold('goobledygoook'))
  call assert_equal('kprnfn', soundfold('kóopërÿnôven'))
  call assert_equal('*fls kswts tl', soundfold('oeverloos gezwets edale'))

  "also use an addition file
  call writefile(["/regions=usgbnz", "elequint/2", "elekwint/3"], "Xtest.utf-8.add", 'D')
  mkspell! Xtest.utf-8.add.spl Xtest.utf-8.add

  bwipe!
  call setline(1, ["start: elequint test elekwint test elekwent asdf"])

  set spellfile=Xtest.utf-8.add
  call assert_equal("elekwent", FirstSpellWord())

  set spl=Xtest_us.utf-8.spl
  call assert_equal("elequint", FirstSpellWord())
  call assert_equal("elekwint", SecondSpellWord())

  set spl=Xtest_gb.utf-8.spl
  call assert_equal("elekwint", FirstSpellWord())
  call assert_equal("elekwent", SecondSpellWord())

  set spl=Xtest_nz.utf-8.spl
  call assert_equal("elequint", FirstSpellWord())
  call assert_equal("elekwent", SecondSpellWord())

  set spl=Xtest_ca.utf-8.spl
  call assert_equal("elequint", FirstSpellWord())
  call assert_equal("elekwint", SecondSpellWord())

  bwipe!
  set spellfile=
  set spl&
endfunc

func Test_spellfile_value()
  set spellfile=Xdir/Xtest.utf-8.add
  set spellfile=Xdir/Xtest.utf-8.add,Xtest_other.add
  set spellfile=
endfunc

func Test_no_crash_with_weird_text()
  new
  let lines =<< trim END
      r<sfile>
      


      
  END
  call setline(1, lines)
  try
    exe "%norm \<C-v>ez=>\<C-v>wzG"
  catch /E1280:/
    let caught = 'yes'
  endtry
  call assert_equal('yes', caught)

  bwipe!
endfunc

" Invalid bytes may cause trouble when creating the word list.
func Test_check_for_valid_word()
  call assert_fails("spellgood! 0\xac", 'E1280:')
endfunc

" This was going over the end of the word
func Test_word_index()
  new
  norm R0
  spellgood! ﬂ0
  sil norm z=

  bwipe!
  call delete('Xtmpfile')
endfunc

func Test_check_empty_line()
  " This was using freed memory
  enew
  spellgood! ﬂ
  norm z=
  norm yy
  sil! norm P]svc
  norm P]s

  bwipe!
endfunc

func Test_spell_suggest_too_long()
  " this was creating a word longer than MAXWLEN
  new
  call setline(1, 'a' .. repeat("\u0333", 150))
  norm! z=
  bwipe!
endfunc


" vim: shiftwidth=2 sts=2 expandtab
