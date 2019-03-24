" Test spell checking
" Note: this file uses latin1 encoding, but is used with utf-8 encoding.

if !has('spell')
  finish
endif

func TearDown()
  set nospell
  call delete('Xtest.aff')
  call delete('Xtest.dic')
  call delete('Xtest.latin1.add')
  call delete('Xtest.latin1.add.spl')
  call delete('Xtest.latin1.spl')
  call delete('Xtest.latin1.sug')
endfunc

func Test_wrap_search()
  new
  call setline(1, ['The', '', 'A plong line with two zpelling mistakes', '', 'End'])
  set spell wrapscan
  normal ]s
  call assert_equal('plong', expand('<cword>'))
  normal ]s
  call assert_equal('zpelling', expand('<cword>'))
  normal ]s
  call assert_equal('plong', expand('<cword>'))
  bwipe!
  set nospell
endfunc

func Test_curswant()
  new
  call setline(1, ['Another plong line', 'abcdefghijklmnopq'])
  set spell wrapscan
  normal 0]s
  call assert_equal('plong', expand('<cword>'))
  normal j
  call assert_equal(9, getcurpos()[2])
  normal 0[s
  call assert_equal('plong', expand('<cword>'))
  normal j
  call assert_equal(9, getcurpos()[2])

  normal 0]S
  call assert_equal('plong', expand('<cword>'))
  normal j
  call assert_equal(9, getcurpos()[2])
  normal 0[S
  call assert_equal('plong', expand('<cword>'))
  normal j
  call assert_equal(9, getcurpos()[2])

  normal 1G0
  call assert_equal('plong', spellbadword()[0])
  normal j
  call assert_equal(9, getcurpos()[2])

  bwipe!
  set nospell
endfunc

func Test_z_equal_on_invalid_utf8_word()
  split
  set spell
  call setline(1, "\xff")
  norm z=
  set nospell
  bwipe!
endfunc

" Test spellbadword() with argument
func Test_spellbadword()
  set spell

  call assert_equal(['bycycle', 'bad'],  spellbadword('My bycycle.'))
  call assert_equal(['another', 'caps'], spellbadword('A sentence. another sentence'))

  set spelllang=en
  call assert_equal(['', ''],            spellbadword('centre'))
  call assert_equal(['', ''],            spellbadword('center'))
  set spelllang=en_us
  call assert_equal(['centre', 'local'], spellbadword('centre'))
  call assert_equal(['', ''],            spellbadword('center'))
  set spelllang=en_gb
  call assert_equal(['', ''],            spellbadword('centre'))
  call assert_equal(['center', 'local'], spellbadword('center'))

  " Create a small word list to test that spellbadword('...')
  " can return ['...', 'rare'].
  e Xwords
  insert
foo
foobar/?
.
   w!
   mkspell! Xwords.spl Xwords
   set spelllang=Xwords.spl
   call assert_equal(['foobar', 'rare'], spellbadword('foo foobar'))

  " Typo should not be detected without the 'spell' option.
  set spelllang=en_gb nospell
  call assert_equal(['', ''], spellbadword('centre'))
  call assert_equal(['', ''], spellbadword('My bycycle.'))
  call assert_equal(['', ''], spellbadword('A sentence. another sentence'))

  call delete('Xwords.spl')
  call delete('Xwords')
  set spelllang&
  set spell&
endfunc

func Test_spellreall()
  new
  set spell
  call assert_fails('spellrepall', 'E752:')
  call setline(1, ['A speling mistake. The same speling mistake.',
        \                'Another speling mistake.'])
  call feedkeys(']s1z=', 'tx')
  call assert_equal('A spelling mistake. The same speling mistake.', getline(1))
  call assert_equal('Another speling mistake.', getline(2))
  spellrepall
  call assert_equal('A spelling mistake. The same spelling mistake.', getline(1))
  call assert_equal('Another spelling mistake.', getline(2))
  call assert_fails('spellrepall', 'E753:')
  set spell&
  bwipe!
endfunc

func Test_spellinfo()
  throw 'skipped: Nvim does not support enc=latin1'
  new

  set enc=latin1 spell spelllang=en
  call assert_match("^\nfile: .*/runtime/spell/en.latin1.spl\n$", execute('spellinfo'))

  set enc=cp1250 spell spelllang=en
  call assert_match("^\nfile: .*/runtime/spell/en.ascii.spl\n$", execute('spellinfo'))

  if has('multi_byte')
    set enc=utf-8 spell spelllang=en
    call assert_match("^\nfile: .*/runtime/spell/en.utf-8.spl\n$", execute('spellinfo'))
  endif

  set enc=latin1 spell spelllang=en_us,en_nz
  call assert_match("^\n" .
                 \  "file: .*/runtime/spell/en.latin1.spl\n" .
                 \  "file: .*/runtime/spell/en.latin1.spl\n$", execute('spellinfo'))

  set spell spelllang=
  call assert_fails('spellinfo', 'E756:')

  set nospell spelllang=en
  call assert_fails('spellinfo', 'E756:')

  set enc& spell& spelllang&
  bwipe
endfunc

func Test_zz_basic()
  call LoadAffAndDic(g:test_data_aff1, g:test_data_dic1)
  call RunGoodBad("wrong OK puts. Test the end",
        \ "bad: inputs comment ok Ok. test d\xE9\xF4l end the",
        \["Comment", "deol", "d\xE9\xF4r", "input", "OK", "output", "outputs", "outtest", "put", "puts",
        \  "test", "testen", "testn", "the end", "uk", "wrong"],
        \[
        \   ["bad", ["put", "uk", "OK"]],
        \   ["inputs", ["input", "puts", "outputs"]],
        \   ["comment", ["Comment", "outtest", "the end"]],
        \   ["ok", ["OK", "uk", "put"]],
        \   ["Ok", ["OK", "Uk", "Put"]],
        \   ["test", ["Test", "testn", "testen"]],
        \   ["d\xE9\xF4l", ["deol", "d\xE9\xF4r", "test"]],
        \   ["end", ["put", "uk", "test"]],
        \   ["the", ["put", "uk", "test"]],
        \ ]
        \ )

  call assert_equal("gebletegek", soundfold('goobledygoook'))
  call assert_equal("kepereneven", soundfold('kóopërÿnôven'))
  call assert_equal("everles gesvets etele", soundfold('oeverloos gezwets edale'))
endfunc

" Postponed prefixes
func Test_zz_prefixes()
  call LoadAffAndDic(g:test_data_aff2, g:test_data_dic1)
  call RunGoodBad("puts",
        \ "bad: inputs comment ok Ok end the. test d\xE9\xF4l",
        \ ["Comment", "deol", "d\xE9\xF4r", "OK", "put", "input", "output", "puts", "outputs", "test", "outtest", "testen", "testn", "the end", "uk", "wrong"],
        \ [
        \   ["bad", ["put", "uk", "OK"]],
        \   ["inputs", ["input", "puts", "outputs"]],
        \   ["comment", ["Comment"]],
        \   ["ok", ["OK", "uk", "put"]],
        \   ["Ok", ["OK", "Uk", "Put"]],
        \   ["end", ["put", "uk", "deol"]],
        \   ["the", ["put", "uk", "test"]],
        \   ["test", ["Test", "testn", "testen"]],
        \   ["d\xE9\xF4l", ["deol", "d\xE9\xF4r", "test"]],
        \ ])
endfunc

"Compound words
func Test_zz_compound()
  call LoadAffAndDic(g:test_data_aff3, g:test_data_dic3)
  call RunGoodBad("foo m\xEF foobar foofoobar barfoo barbarfoo",
        \ "bad: bar la foom\xEF barm\xEF m\xEFfoo m\xEFbar m\xEFm\xEF lala m\xEFla lam\xEF foola labar",
        \ ["foo", "m\xEF"],
        \ [
        \   ["bad", ["foo", "m\xEF"]],
        \   ["bar", ["barfoo", "foobar", "foo"]],
        \   ["la", ["m\xEF", "foo"]],
        \   ["foom\xEF", ["foo m\xEF", "foo", "foofoo"]],
        \   ["barm\xEF", ["barfoo", "m\xEF", "barbar"]],
        \   ["m\xEFfoo", ["m\xEF foo", "foo", "foofoo"]],
        \   ["m\xEFbar", ["foobar", "barbar", "m\xEF"]],
        \   ["m\xEFm\xEF", ["m\xEF m\xEF", "m\xEF"]],
        \   ["lala", []],
        \   ["m\xEFla", ["m\xEF", "m\xEF m\xEF"]],
        \   ["lam\xEF", ["m\xEF", "m\xEF m\xEF"]],
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

"Test affix flags with two characters
func Test_zz_affix()
  call LoadAffAndDic(g:test_data_aff5, g:test_data_dic5)
  call RunGoodBad("fooa1 fooa\xE9 bar prebar barbork prebarbork  startprebar start end startend  startmiddleend nouend",
        \ "bad: foo fooa2 prabar probarbirk middle startmiddle middleend endstart startprobar startnouend",
        \ ["bar", "barbork", "end", "fooa1", "fooa\xE9", "nouend", "prebar", "prebarbork", "start"],
        \ [
        \   ["bad", ["bar", "end", "fooa1"]],
        \   ["foo", ["fooa1", "fooa\xE9", "bar"]],
        \   ["fooa2", ["fooa1", "fooa\xE9", "bar"]],
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
  call RunGoodBad("meea1 meea\xE9 bar prebar barbork prebarbork  leadprebar lead end leadend  leadmiddleend",
        \  "bad: mee meea2 prabar probarbirk middle leadmiddle middleend endlead leadprobar",
        \ ["bar", "barbork", "end", "lead", "meea1", "meea\xE9", "prebar", "prebarbork"],
        \ [
        \   ["bad", ["bar", "end", "lead"]],
        \   ["mee", ["meea1", "meea\xE9", "bar"]],
        \   ["meea2", ["meea1", "meea\xE9", "lead"]],
        \   ["prabar", ["prebar", "bar", "leadbar"]],
        \   ["probarbirk", ["prebarbork"]],
        \   ["middle", []],
        \   ["leadmiddle", ["leadmiddleend", "leadmiddlebar"]],
        \   ["middleend", []],
        \   ["endlead", ["end lead", "lead", "end end"]],
        \   ["leadprobar", ["leadprebar", "lead prebar", "leadbar"]],
        \ ])

  call LoadAffAndDic(g:test_data_aff7, g:test_data_dic7)
  call RunGoodBad("meea1 meea\xE9 bar prebar barmeat prebarmeat  leadprebar lead tail leadtail  leadmiddletail",
        \ "bad: mee meea2 prabar probarmaat middle leadmiddle middletail taillead leadprobar",
        \ ["bar", "barmeat", "lead", "meea1", "meea\xE9", "prebar", "prebarmeat", "tail"],
        \ [
        \   ["bad", ["bar", "lead", "tail"]],
        \   ["mee", ["meea1", "meea\xE9", "bar"]],
        \   ["meea2", ["meea1", "meea\xE9", "lead"]],
        \   ["prabar", ["prebar", "bar", "leadbar"]],
        \   ["probarmaat", ["prebarmeat"]],
        \   ["middle", []],
        \   ["leadmiddle", ["leadmiddlebar"]],
        \   ["middletail", []],
        \   ["taillead", ["tail lead", "tail"]],
        \   ["leadprobar", ["leadprebar", "lead prebar", "leadbar"]],
        \ ])
endfunc

func Test_zz_NOSLITSUGS()
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
func Test_zz_Numbers()
  call LoadAffAndDic(g:test_data_aff9, g:test_data_dic9)
  call RunGoodBad("0b1011 0777 1234 0x01ff", "",
        \ ["bar", "foo"],
        \ [
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

"Test with SAL instead of SOFO items; test automatic reloading
func Test_zz_sal_and_addition()
  throw 'skipped: Nvim does not support enc=latin1'
  set enc=latin1
  set spellfile=
  call writefile(g:test_data_dic1, "Xtest.dic")
  call writefile(g:test_data_aff_sal, "Xtest.aff")
  mkspell! Xtest Xtest
  set spl=Xtest.latin1.spl spell
  call assert_equal('kbltykk', soundfold('goobledygoook'))
  call assert_equal('kprnfn', soundfold('kóopërÿnôven'))
  call assert_equal('*fls kswts tl', soundfold('oeverloos gezwets edale'))

  "also use an addition file
  call writefile(["/regions=usgbnz", "elequint/2", "elekwint/3"], "Xtest.latin1.add")
  mkspell! Xtest.latin1.add.spl Xtest.latin1.add

  bwipe!
  call setline(1, ["start: elequint test elekwint test elekwent asdf"])

  set spellfile=Xtest.latin1.add
  call assert_equal("elekwent", FirstSpellWord())

  set spl=Xtest_us.latin1.spl
  call assert_equal("elequint", FirstSpellWord())
  call assert_equal("elekwint", SecondSpellWord())

  set spl=Xtest_gb.latin1.spl
  call assert_equal("elekwint", FirstSpellWord())
  call assert_equal("elekwent", SecondSpellWord())

  set spl=Xtest_nz.latin1.spl
  call assert_equal("elequint", FirstSpellWord())
  call assert_equal("elekwent", SecondSpellWord())

  set spl=Xtest_ca.latin1.spl
  call assert_equal("elequint", FirstSpellWord())
  call assert_equal("elekwint", SecondSpellWord())
endfunc

func Test_region_error()
  messages clear
  call writefile(["/regions=usgbnz", "elequint/0"], "Xtest.latin1.add")
  mkspell! Xtest.latin1.add.spl Xtest.latin1.add
  call assert_match('Invalid region nr in Xtest.latin1.add line 2: 0', execute('messages'))
  call delete('Xtest.latin1.add')
  call delete('Xtest.latin1.add.spl')
endfunc

" Check using z= in new buffer (crash fixed by patch 7.4a.028).
func Test_zeq_crash()
  new
  set spell
  call feedkeys('iasdz=:\"', 'tx')

  bwipe!
endfunc

" Check handling a word longer than MAXWLEN.
func Test_spell_long_word()
  set enc=utf-8
  new
  call setline(1, "d\xCC\xB4\xCC\xBD\xCD\x88\xCD\x94a\xCC\xB5\xCD\x84\xCD\x84\xCC\xA8\xCD\x9Cr\xCC\xB5\xCC\x8E\xCD\x85\xCD\x85k\xCC\xB6\xCC\x89\xCC\x9D \xCC\xB6\xCC\x83\xCC\x8F\xCC\xA4\xCD\x8Ef\xCC\xB7\xCC\x81\xCC\x80\xCC\xA9\xCC\xB0\xCC\xAC\xCC\xA2\xCD\x95\xCD\x87\xCD\x8D\xCC\x9E\xCD\x99\xCC\xAD\xCC\xAB\xCC\x97\xCC\xBBo\xCC\xB6\xCC\x84\xCC\x95\xCC\x8C\xCC\x8B\xCD\x9B\xCD\x9C\xCC\xAFr\xCC\xB7\xCC\x94\xCD\x83\xCD\x97\xCC\x8C\xCC\x82\xCD\x82\xCD\x80\xCD\x91\xCC\x80\xCC\xBE\xCC\x82\xCC\x8F\xCC\xA3\xCD\x85\xCC\xAE\xCD\x8D\xCD\x99\xCC\xBC\xCC\xAB\xCC\xA7\xCD\x88c\xCC\xB7\xCD\x83\xCC\x84\xCD\x92\xCC\x86\xCC\x83\xCC\x88\xCC\x92\xCC\x94\xCC\xBE\xCC\x9D\xCC\xAF\xCC\x98\xCC\x9D\xCC\xBB\xCD\x8E\xCC\xBB\xCC\xB3\xCC\xA3\xCD\x8E\xCD\x99\xCC\xA5\xCC\xAD\xCC\x99\xCC\xB9\xCC\xAE\xCC\xA5\xCC\x9E\xCD\x88\xCC\xAE\xCC\x9E\xCC\xA9\xCC\x97\xCC\xBC\xCC\x99\xCC\xA5\xCD\x87\xCC\x97\xCD\x8E\xCD\x94\xCC\x99\xCC\x9D\xCC\x96\xCD\x94\xCC\xAB\xCC\xA7\xCC\xA5\xCC\x98\xCC\xBB\xCC\xAF\xCC\xABe\xCC\xB7\xCC\x8E\xCC\x82\xCD\x86\xCD\x9B\xCC\x94\xCD\x83\xCC\x85\xCD\x8A\xCD\x8C\xCC\x8B\xCD\x92\xCD\x91\xCC\x8F\xCC\x81\xCD\x95\xCC\xA2\xCC\xB9\xCC\xB2\xCD\x9C\xCC\xB1\xCC\xA6\xCC\xB3\xCC\xAF\xCC\xAE\xCC\x9C\xCD\x99s\xCC\xB8\xCC\x8C\xCC\x8E\xCC\x87\xCD\x81\xCD\x82\xCC\x86\xCD\x8C\xCD\x8C\xCC\x8B\xCC\x84\xCC\x8C\xCD\x84\xCD\x9B\xCD\x86\xCC\x93\xCD\x90\xCC\x85\xCC\x94\xCD\x98\xCD\x84\xCD\x92\xCD\x8B\xCC\x90\xCC\x83\xCC\x8F\xCD\x84\xCD\x81\xCD\x9B\xCC\x90\xCD\x81\xCC\x8F\xCC\xBD\xCC\x88\xCC\xBF\xCC\x88\xCC\x84\xCC\x8E\xCD\x99\xCD\x94\xCC\x99\xCD\x99\xCC\xB0\xCC\xA8\xCC\xA3\xCC\xA8\xCC\x96\xCC\x99\xCC\xAE\xCC\xBC\xCC\x99\xCD\x9A\xCC\xB2\xCC\xB1\xCC\x9F\xCC\xBB\xCC\xA6\xCD\x85\xCC\xAA\xCD\x89\xCC\x9D\xCC\x99\xCD\x96\xCC\xB1\xCC\xB1\xCC\x99\xCC\xA6\xCC\xA5\xCD\x95\xCC\xB2\xCC\xA0\xCD\x99 within")
  set spell spelllang=en
  redraw
  redraw!
  bwipe!
  set nospell
endfunc

func LoadAffAndDic(aff_contents, dic_contents)
  throw 'skipped: Nvim does not support enc=latin1'
  set enc=latin1
  set spellfile=
  call writefile(a:aff_contents, "Xtest.aff")
  call writefile(a:dic_contents, "Xtest.dic")
  " Generate a .spl file from a .dic and .aff file.
  mkspell! Xtest Xtest
  " use that spell file
  set spl=Xtest.latin1.spl spell
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
    let lst = spellsuggest(bad, 3)
    normal mm

    call add(result, [bad, lst])
    normal `m]s
  endwhile
  return result
endfunc

func RunGoodBad(good, bad, expected_words, expected_bad_words)
  bwipe!
  call setline(1, ["good: ", a:good,  a:bad, " badend "])
  let words = ListWords()
  call assert_equal(a:expected_words, words[1:-1])
  let bad_words = TestGoodBadBase()
  call assert_equal(a:expected_bad_words, bad_words)
  bwipe!
endfunc

let g:test_data_aff1 = [
      \"SET ISO8859-1",
      \"TRY esianrtolcdugmphbyfvkwjkqxz-\xEB\xE9\xE8\xEA\xEF\xEE\xE4\xE0\xE2\xF6\xFC\xFB'ESIANRTOLCDUGMPHBYFVKWJKQXZ",
      \"",
      \"FOL  \xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF",
      \"LOW  \xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xDF\xFF",
      \"UPP  \xC0\xC1\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xDF\xFF",
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
      \"MAP s\xDF",
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
      \"mee/391,111,9999",
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
