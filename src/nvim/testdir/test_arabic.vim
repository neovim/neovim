" Simplistic testing of Arabic mode.
" NOTE: This just checks if the code works. If you know Arabic please add
" functional tests that check the shaping works with real text.

if !has('arabic')
  finish
endif

source view_util.vim

" Return list of Unicode characters at line lnum.
" Combining characters are treated as a single item.
func s:get_chars(lnum)
  call cursor(a:lnum, 1)
  let chars = []
  let numchars = strchars(getline('.'), 1)
  for i in range(1, numchars)
    exe 'norm ' i . '|'
    let c = execute('ascii')
    let c = substitute(c, '\n\?<.\{-}Hex\s*', 'U+', 'g')
    let c = substitute(c, ',\s*Oct\(al\)\=\s\d*\(, Digr ..\)\=', '', 'g')
    call add(chars, c)
  endfor
  return chars
endfunc

func Test_arabic_toggle()
  set arabic
  call assert_equal(1, &rightleft)
  call assert_equal(1, &arabicshape)
  call assert_equal('arabic', &keymap)
  call assert_equal(1, &delcombine)

  set iminsert=1 imsearch=1
  set arabic&
  call assert_equal(0, &rightleft)
  call assert_equal(1, &arabicshape)
  call assert_equal('arabic', &keymap)
  call assert_equal(1, &delcombine)
  call assert_equal(0, &iminsert)
  call assert_equal(-1, &imsearch)

  set arabicshape& keymap= delcombine&
endfunc

func Test_arabic_input()
  new
  set arabic
  " Typing sghl in Arabic insert mode should show the
  " Arabic word 'Salaam' i.e. 'peace', spelled:
  " SEEN, LAM, ALEF, MEEM.
  " See: https://www.mediawiki.org/wiki/VisualEditor/Typing/Right-to-left
  call feedkeys('isghl!', 'tx')
  call assert_match("^ *!\uFEE1\uFEFC\uFEB3$", ScreenLines(1, &columns)[0])
  call assert_equal([
  \ 'U+0633',
  \ 'U+0644 U+0627',
  \ 'U+0645',
  \ 'U+21'], s:get_chars(1))

  " Without shaping, it should give individual Arabic letters.
  set noarabicshape
  call assert_match("^ *!\u0645\u0627\u0644\u0633$", ScreenLines(1, &columns)[0])
  call assert_equal([
  \ 'U+0633',
  \ 'U+0644',
  \ 'U+0627',
  \ 'U+0645',
  \ 'U+21'], s:get_chars(1))

  set arabic& arabicshape&
  bwipe!
endfunc

func Test_arabic_toggle_keymap()
  new
  set arabic
  call feedkeys("i12\<C-^>12\<C-^>12", 'tx')
  call assert_match("^ *٢١21٢١$", ScreenLines(1, &columns)[0])
  call assert_equal('١٢12١٢', getline('.'))
  set arabic&
  bwipe!
endfunc

func Test_delcombine()
  new
  set arabic
  call feedkeys("isghl\<BS>\<BS>", 'tx')
  call assert_match("^ *\uFEDE\uFEB3$", ScreenLines(1, &columns)[0])
  call assert_equal(['U+0633', 'U+0644'], s:get_chars(1))

  " Now the same with 'nodelcombine'
  set nodelcombine
  %d
  call feedkeys("isghl\<BS>\<BS>", 'tx')
  call assert_match("^ *\uFEB1$", ScreenLines(1, &columns)[0])
  call assert_equal(['U+0633'], s:get_chars(1))
  set arabic&
  bwipe!
endfunc

" Values from src/arabic.h (not all used yet)
let s:a_COMMA = "\u060C"
let s:a_SEMICOLON = "\u061B"
let s:a_QUESTION = "\u061F"
let s:a_HAMZA = "\u0621"
let s:a_ALEF_MADDA = "\u0622"
let s:a_ALEF_HAMZA_ABOVE = "\u0623"
let s:a_WAW_HAMZA = "\u0624"
let s:a_ALEF_HAMZA_BELOW = "\u0625"
let s:a_YEH_HAMZA = "\u0626"
let s:a_ALEF = "\u0627"
let s:a_BEH = "\u0628"
let s:a_TEH_MARBUTA = "\u0629"
let s:a_TEH = "\u062a"
let s:a_THEH = "\u062b"
let s:a_JEEM = "\u062c"
let s:a_HAH = "\u062d"
let s:a_KHAH = "\u062e"
let s:a_DAL = "\u062f"
let s:a_THAL = "\u0630"
let s:a_REH = "\u0631"
let s:a_ZAIN = "\u0632"
let s:a_SEEN = "\u0633"
let s:a_SHEEN = "\u0634"
let s:a_SAD = "\u0635"
let s:a_DAD = "\u0636"
let s:a_TAH = "\u0637"
let s:a_ZAH = "\u0638"
let s:a_AIN = "\u0639"
let s:a_GHAIN = "\u063a"
let s:a_TATWEEL = "\u0640"
let s:a_FEH = "\u0641"
let s:a_QAF = "\u0642"
let s:a_KAF = "\u0643"
let s:a_LAM = "\u0644"
let s:a_MEEM = "\u0645"
let s:a_NOON = "\u0646"
let s:a_HEH = "\u0647"
let s:a_WAW = "\u0648"
let s:a_ALEF_MAKSURA = "\u0649"
let s:a_YEH = "\u064a"

let s:a_FATHATAN = "\u064b"
let s:a_DAMMATAN = "\u064c"
let s:a_KASRATAN = "\u064d"
let s:a_FATHA = "\u064e"
let s:a_DAMMA = "\u064f"
let s:a_KASRA = "\u0650"
let s:a_SHADDA = "\u0651"
let s:a_SUKUN = "\u0652"

let s:a_MADDA_ABOVE = "\u0653"
let s:a_HAMZA_ABOVE = "\u0654"
let s:a_HAMZA_BELOW = "\u0655"

let s:a_ZERO = "\u0660"
let s:a_ONE = "\u0661"
let s:a_TWO = "\u0662"
let s:a_THREE = "\u0663"
let s:a_FOUR = "\u0664"
let s:a_FIVE = "\u0665"
let s:a_SIX = "\u0666"
let s:a_SEVEN = "\u0667"
let s:a_EIGHT = "\u0668"
let s:a_NINE = "\u0669"
let s:a_PERCENT = "\u066a"
let s:a_DECIMAL = "\u066b"
let s:a_THOUSANDS = "\u066c"
let s:a_STAR = "\u066d"
let s:a_MINI_ALEF = "\u0670"

let s:a_s_FATHATAN = "\ufe70"
let s:a_m_TATWEEL_FATHATAN = "\ufe71"
let s:a_s_DAMMATAN = "\ufe72"

let s:a_s_KASRATAN = "\ufe74"

let s:a_s_FATHA = "\ufe76"
let s:a_m_FATHA = "\ufe77"
let s:a_s_DAMMA = "\ufe78"
let s:a_m_DAMMA = "\ufe79"
let s:a_s_KASRA = "\ufe7a"
let s:a_m_KASRA = "\ufe7b"
let s:a_s_SHADDA = "\ufe7c"
let s:a_m_SHADDA = "\ufe7d"
let s:a_s_SUKUN = "\ufe7e"
let s:a_m_SUKUN = "\ufe7f"

let s:a_s_HAMZA = "\ufe80"
let s:a_s_ALEF_MADDA = "\ufe81"
let s:a_f_ALEF_MADDA = "\ufe82"
let s:a_s_ALEF_HAMZA_ABOVE = "\ufe83"
let s:a_f_ALEF_HAMZA_ABOVE = "\ufe84"
let s:a_s_WAW_HAMZA = "\ufe85"
let s:a_f_WAW_HAMZA = "\ufe86"
let s:a_s_ALEF_HAMZA_BELOW = "\ufe87"
let s:a_f_ALEF_HAMZA_BELOW = "\ufe88"
let s:a_s_YEH_HAMZA = "\ufe89"
let s:a_f_YEH_HAMZA = "\ufe8a"
let s:a_i_YEH_HAMZA = "\ufe8b"
let s:a_m_YEH_HAMZA = "\ufe8c"
let s:a_s_ALEF = "\ufe8d"
let s:a_f_ALEF = "\ufe8e"
let s:a_s_BEH = "\ufe8f"
let s:a_f_BEH = "\ufe90"
let s:a_i_BEH = "\ufe91"
let s:a_m_BEH = "\ufe92"
let s:a_s_TEH_MARBUTA = "\ufe93"
let s:a_f_TEH_MARBUTA = "\ufe94"
let s:a_s_TEH = "\ufe95"
let s:a_f_TEH = "\ufe96"
let s:a_i_TEH = "\ufe97"
let s:a_m_TEH = "\ufe98"
let s:a_s_THEH = "\ufe99"
let s:a_f_THEH = "\ufe9a"
let s:a_i_THEH = "\ufe9b"
let s:a_m_THEH = "\ufe9c"
let s:a_s_JEEM = "\ufe9d"
let s:a_f_JEEM = "\ufe9e"
let s:a_i_JEEM = "\ufe9f"
let s:a_m_JEEM = "\ufea0"
let s:a_s_HAH = "\ufea1"
let s:a_f_HAH = "\ufea2"
let s:a_i_HAH = "\ufea3"
let s:a_m_HAH = "\ufea4"
let s:a_s_KHAH = "\ufea5"
let s:a_f_KHAH = "\ufea6"
let s:a_i_KHAH = "\ufea7"
let s:a_m_KHAH = "\ufea8"
let s:a_s_DAL = "\ufea9"
let s:a_f_DAL = "\ufeaa"
let s:a_s_THAL = "\ufeab"
let s:a_f_THAL = "\ufeac"
let s:a_s_REH = "\ufead"
let s:a_f_REH = "\ufeae"
let s:a_s_ZAIN = "\ufeaf"
let s:a_f_ZAIN = "\ufeb0"
let s:a_s_SEEN = "\ufeb1"
let s:a_f_SEEN = "\ufeb2"
let s:a_i_SEEN = "\ufeb3"
let s:a_m_SEEN = "\ufeb4"
let s:a_s_SHEEN = "\ufeb5"
let s:a_f_SHEEN = "\ufeb6"
let s:a_i_SHEEN = "\ufeb7"
let s:a_m_SHEEN = "\ufeb8"
let s:a_s_SAD = "\ufeb9"
let s:a_f_SAD = "\ufeba"
let s:a_i_SAD = "\ufebb"
let s:a_m_SAD = "\ufebc"
let s:a_s_DAD = "\ufebd"
let s:a_f_DAD = "\ufebe"
let s:a_i_DAD = "\ufebf"
let s:a_m_DAD = "\ufec0"
let s:a_s_TAH = "\ufec1"
let s:a_f_TAH = "\ufec2"
let s:a_i_TAH = "\ufec3"
let s:a_m_TAH = "\ufec4"
let s:a_s_ZAH = "\ufec5"
let s:a_f_ZAH = "\ufec6"
let s:a_i_ZAH = "\ufec7"
let s:a_m_ZAH = "\ufec8"
let s:a_s_AIN = "\ufec9"
let s:a_f_AIN = "\ufeca"
let s:a_i_AIN = "\ufecb"
let s:a_m_AIN = "\ufecc"
let s:a_s_GHAIN = "\ufecd"
let s:a_f_GHAIN = "\ufece"
let s:a_i_GHAIN = "\ufecf"
let s:a_m_GHAIN = "\ufed0"
let s:a_s_FEH = "\ufed1"
let s:a_f_FEH = "\ufed2"
let s:a_i_FEH = "\ufed3"
let s:a_m_FEH = "\ufed4"
let s:a_s_QAF = "\ufed5"
let s:a_f_QAF = "\ufed6"
let s:a_i_QAF = "\ufed7"
let s:a_m_QAF = "\ufed8"
let s:a_s_KAF = "\ufed9"
let s:a_f_KAF = "\ufeda"
let s:a_i_KAF = "\ufedb"
let s:a_m_KAF = "\ufedc"
let s:a_s_LAM = "\ufedd"
let s:a_f_LAM = "\ufede"
let s:a_i_LAM = "\ufedf"
let s:a_m_LAM = "\ufee0"
let s:a_s_MEEM = "\ufee1"
let s:a_f_MEEM = "\ufee2"
let s:a_i_MEEM = "\ufee3"
let s:a_m_MEEM = "\ufee4"
let s:a_s_NOON = "\ufee5"
let s:a_f_NOON = "\ufee6"
let s:a_i_NOON = "\ufee7"
let s:a_m_NOON = "\ufee8"
let s:a_s_HEH = "\ufee9"
let s:a_f_HEH = "\ufeea"
let s:a_i_HEH = "\ufeeb"
let s:a_m_HEH = "\ufeec"
let s:a_s_WAW = "\ufeed"
let s:a_f_WAW = "\ufeee"
let s:a_s_ALEF_MAKSURA = "\ufeef"
let s:a_f_ALEF_MAKSURA = "\ufef0"
let s:a_s_YEH = "\ufef1"
let s:a_f_YEH = "\ufef2"
let s:a_i_YEH = "\ufef3"
let s:a_m_YEH = "\ufef4"
let s:a_s_LAM_ALEF_MADDA_ABOVE = "\ufef5"
let s:a_f_LAM_ALEF_MADDA_ABOVE = "\ufef6"
let s:a_s_LAM_ALEF_HAMZA_ABOVE = "\ufef7"
let s:a_f_LAM_ALEF_HAMZA_ABOVE = "\ufef8"
let s:a_s_LAM_ALEF_HAMZA_BELOW = "\ufef9"
let s:a_f_LAM_ALEF_HAMZA_BELOW = "\ufefa"
let s:a_s_LAM_ALEF = "\ufefb"
let s:a_f_LAM_ALEF = "\ufefc"

let s:a_BYTE_ORDER_MARK = "\ufeff"

func Test_shape_initial()
  new
  set arabicshape

  " Shaping arabic {testchar} non-arabic   Tests chg_c_a2i().
  " pair[0] = testchar, pair[1] = next-result, pair[2] = current-result
  for pair in [[s:a_YEH_HAMZA, s:a_f_GHAIN, s:a_i_YEH_HAMZA],
	\ [s:a_HAMZA, s:a_s_GHAIN, s:a_s_HAMZA],
	\ [s:a_ALEF_MADDA, s:a_s_GHAIN, s:a_s_ALEF_MADDA],
	\ [s:a_ALEF_HAMZA_ABOVE, s:a_s_GHAIN, s:a_s_ALEF_HAMZA_ABOVE],
	\ [s:a_WAW_HAMZA, s:a_s_GHAIN, s:a_s_WAW_HAMZA],
	\ [s:a_ALEF_HAMZA_BELOW, s:a_s_GHAIN, s:a_s_ALEF_HAMZA_BELOW],
	\ [s:a_ALEF, s:a_s_GHAIN, s:a_s_ALEF],
	\ [s:a_TEH_MARBUTA, s:a_s_GHAIN, s:a_s_TEH_MARBUTA],
	\ [s:a_DAL, s:a_s_GHAIN, s:a_s_DAL],
	\ [s:a_THAL, s:a_s_GHAIN, s:a_s_THAL],
	\ [s:a_REH, s:a_s_GHAIN, s:a_s_REH],
	\ [s:a_ZAIN, s:a_s_GHAIN, s:a_s_ZAIN],
	\ [s:a_TATWEEL, s:a_f_GHAIN, s:a_TATWEEL],
	\ [s:a_WAW, s:a_s_GHAIN, s:a_s_WAW],
	\ [s:a_ALEF_MAKSURA, s:a_s_GHAIN, s:a_s_ALEF_MAKSURA],
	\ [s:a_BEH, s:a_f_GHAIN, s:a_i_BEH],
	\ [s:a_TEH, s:a_f_GHAIN, s:a_i_TEH],
	\ [s:a_THEH, s:a_f_GHAIN, s:a_i_THEH],
	\ [s:a_JEEM, s:a_f_GHAIN, s:a_i_JEEM],
	\ [s:a_HAH, s:a_f_GHAIN, s:a_i_HAH],
	\ [s:a_KHAH, s:a_f_GHAIN, s:a_i_KHAH],
	\ [s:a_SEEN, s:a_f_GHAIN, s:a_i_SEEN],
	\ [s:a_SHEEN, s:a_f_GHAIN, s:a_i_SHEEN],
	\ [s:a_SAD, s:a_f_GHAIN, s:a_i_SAD],
	\ [s:a_DAD, s:a_f_GHAIN, s:a_i_DAD],
	\ [s:a_TAH, s:a_f_GHAIN, s:a_i_TAH],
	\ [s:a_ZAH, s:a_f_GHAIN, s:a_i_ZAH],
	\ [s:a_AIN, s:a_f_GHAIN, s:a_i_AIN],
	\ [s:a_GHAIN, s:a_f_GHAIN, s:a_i_GHAIN],
	\ [s:a_FEH, s:a_f_GHAIN, s:a_i_FEH],
	\ [s:a_QAF, s:a_f_GHAIN, s:a_i_QAF],
	\ [s:a_KAF, s:a_f_GHAIN, s:a_i_KAF],
	\ [s:a_LAM, s:a_f_GHAIN, s:a_i_LAM],
	\ [s:a_MEEM, s:a_f_GHAIN, s:a_i_MEEM],
	\ [s:a_NOON, s:a_f_GHAIN, s:a_i_NOON],
	\ [s:a_HEH, s:a_f_GHAIN, s:a_i_HEH],
	\ [s:a_YEH, s:a_f_GHAIN, s:a_i_YEH],
	\ ]
    call setline(1, s:a_GHAIN . pair[0] . ' ')
    call assert_equal([pair[1] . pair[2] . ' '], ScreenLines(1, 3))
  endfor

  set arabicshape&
  bwipe!
endfunc

func Test_shape_isolated()
  new
  set arabicshape

  " Shaping non-arabic {testchar} non-arabic   Tests chg_c_a2s().
  " pair[0] = testchar, pair[1] = current-result
  for pair in [[s:a_HAMZA, s:a_s_HAMZA],
	\ [s:a_ALEF_MADDA, s:a_s_ALEF_MADDA],
	\ [s:a_ALEF_HAMZA_ABOVE, s:a_s_ALEF_HAMZA_ABOVE],
	\ [s:a_WAW_HAMZA, s:a_s_WAW_HAMZA],
	\ [s:a_ALEF_HAMZA_BELOW, s:a_s_ALEF_HAMZA_BELOW],
	\ [s:a_YEH_HAMZA, s:a_s_YEH_HAMZA],
	\ [s:a_ALEF, s:a_s_ALEF],
	\ [s:a_TEH_MARBUTA, s:a_s_TEH_MARBUTA],
	\ [s:a_DAL, s:a_s_DAL],
	\ [s:a_THAL, s:a_s_THAL],
	\ [s:a_REH, s:a_s_REH],
	\ [s:a_ZAIN, s:a_s_ZAIN],
	\ [s:a_TATWEEL, s:a_TATWEEL],
	\ [s:a_WAW, s:a_s_WAW],
	\ [s:a_ALEF_MAKSURA, s:a_s_ALEF_MAKSURA],
	\ [s:a_BEH, s:a_s_BEH],
	\ [s:a_TEH, s:a_s_TEH],
	\ [s:a_THEH, s:a_s_THEH],
	\ [s:a_JEEM, s:a_s_JEEM],
	\ [s:a_HAH, s:a_s_HAH],
	\ [s:a_KHAH, s:a_s_KHAH],
	\ [s:a_SEEN, s:a_s_SEEN],
	\ [s:a_SHEEN, s:a_s_SHEEN],
	\ [s:a_SAD, s:a_s_SAD],
	\ [s:a_DAD, s:a_s_DAD],
	\ [s:a_TAH, s:a_s_TAH],
	\ [s:a_ZAH, s:a_s_ZAH],
	\ [s:a_AIN, s:a_s_AIN],
	\ [s:a_GHAIN, s:a_s_GHAIN],
	\ [s:a_FEH, s:a_s_FEH],
	\ [s:a_QAF, s:a_s_QAF],
	\ [s:a_KAF, s:a_s_KAF],
	\ [s:a_LAM, s:a_s_LAM],
	\ [s:a_MEEM, s:a_s_MEEM],
	\ [s:a_NOON, s:a_s_NOON],
	\ [s:a_HEH, s:a_s_HEH],
	\ [s:a_YEH, s:a_s_YEH],
	\ ]
    call setline(1, ' ' . pair[0] . ' ')
    call assert_equal([' ' . pair[1] . ' '], ScreenLines(1, 3))
  endfor

  set arabicshape&
  bwipe!
endfunc

func Test_shape_iso_to_medial()
  new
  set arabicshape

  " Shaping arabic {testchar} arabic   Tests chg_c_a2m().
  " pair[0] = testchar, pair[1] = next-result, pair[2] = current-result,
  " pair[3] = previous-result
  for pair in [[s:a_HAMZA, s:a_s_GHAIN, s:a_s_HAMZA, s:a_s_BEH],
	\[s:a_ALEF_MADDA, s:a_s_GHAIN, s:a_f_ALEF_MADDA, s:a_i_BEH],
	\[s:a_ALEF_HAMZA_ABOVE, s:a_s_GHAIN, s:a_f_ALEF_HAMZA_ABOVE, s:a_i_BEH],
	\[s:a_WAW_HAMZA, s:a_s_GHAIN, s:a_f_WAW_HAMZA, s:a_i_BEH],
	\[s:a_ALEF_HAMZA_BELOW, s:a_s_GHAIN, s:a_f_ALEF_HAMZA_BELOW, s:a_i_BEH],
	\[s:a_YEH_HAMZA, s:a_f_GHAIN, s:a_m_YEH_HAMZA, s:a_i_BEH],
	\[s:a_ALEF, s:a_s_GHAIN, s:a_f_ALEF, s:a_i_BEH],
	\[s:a_BEH, s:a_f_GHAIN, s:a_m_BEH, s:a_i_BEH],
	\[s:a_TEH_MARBUTA, s:a_s_GHAIN, s:a_f_TEH_MARBUTA, s:a_i_BEH],
	\[s:a_TEH, s:a_f_GHAIN, s:a_m_TEH, s:a_i_BEH],
	\[s:a_THEH, s:a_f_GHAIN, s:a_m_THEH, s:a_i_BEH],
	\[s:a_JEEM, s:a_f_GHAIN, s:a_m_JEEM, s:a_i_BEH],
	\[s:a_HAH, s:a_f_GHAIN, s:a_m_HAH, s:a_i_BEH],
	\[s:a_KHAH, s:a_f_GHAIN, s:a_m_KHAH, s:a_i_BEH],
	\[s:a_DAL, s:a_s_GHAIN, s:a_f_DAL, s:a_i_BEH],
	\[s:a_THAL, s:a_s_GHAIN, s:a_f_THAL, s:a_i_BEH],
	\[s:a_REH, s:a_s_GHAIN, s:a_f_REH, s:a_i_BEH],
	\[s:a_ZAIN, s:a_s_GHAIN, s:a_f_ZAIN, s:a_i_BEH],
	\[s:a_SEEN, s:a_f_GHAIN, s:a_m_SEEN, s:a_i_BEH],
	\[s:a_SHEEN, s:a_f_GHAIN, s:a_m_SHEEN, s:a_i_BEH],
	\[s:a_SAD, s:a_f_GHAIN, s:a_m_SAD, s:a_i_BEH],
	\[s:a_DAD, s:a_f_GHAIN, s:a_m_DAD, s:a_i_BEH],
	\[s:a_TAH, s:a_f_GHAIN, s:a_m_TAH, s:a_i_BEH],
	\[s:a_ZAH, s:a_f_GHAIN, s:a_m_ZAH, s:a_i_BEH],
	\[s:a_AIN, s:a_f_GHAIN, s:a_m_AIN, s:a_i_BEH],
	\[s:a_GHAIN, s:a_f_GHAIN, s:a_m_GHAIN, s:a_i_BEH],
	\[s:a_TATWEEL, s:a_f_GHAIN, s:a_TATWEEL, s:a_i_BEH],
	\[s:a_FEH, s:a_f_GHAIN, s:a_m_FEH, s:a_i_BEH],
	\[s:a_QAF, s:a_f_GHAIN, s:a_m_QAF, s:a_i_BEH],
	\[s:a_KAF, s:a_f_GHAIN, s:a_m_KAF, s:a_i_BEH],
	\[s:a_LAM, s:a_f_GHAIN, s:a_m_LAM, s:a_i_BEH],
	\[s:a_MEEM, s:a_f_GHAIN, s:a_m_MEEM, s:a_i_BEH],
	\[s:a_NOON, s:a_f_GHAIN, s:a_m_NOON, s:a_i_BEH],
	\[s:a_HEH, s:a_f_GHAIN, s:a_m_HEH, s:a_i_BEH],
	\[s:a_WAW, s:a_s_GHAIN, s:a_f_WAW, s:a_i_BEH],
	\[s:a_ALEF_MAKSURA, s:a_s_GHAIN, s:a_f_ALEF_MAKSURA, s:a_i_BEH],
	\[s:a_YEH, s:a_f_GHAIN, s:a_m_YEH, s:a_i_BEH],
	\ ]
    call setline(1, s:a_GHAIN . pair[0] . s:a_BEH)
    call assert_equal([pair[1] . pair[2] . pair[3]], ScreenLines(1, 3))
  endfor

  set arabicshape&
  bwipe!
endfunc

func Test_shape_final()
  new
  set arabicshape

  " Shaping arabic {testchar} arabic   Tests chg_c_a2f().
  " pair[0] = testchar,  pair[1] = current-result, pair[2] = previous-result
  for pair in [[s:a_HAMZA, s:a_s_HAMZA, s:a_s_BEH],
	\[s:a_ALEF_MADDA, s:a_f_ALEF_MADDA, s:a_i_BEH],
	\[s:a_ALEF_HAMZA_ABOVE, s:a_f_ALEF_HAMZA_ABOVE, s:a_i_BEH],
	\[s:a_WAW_HAMZA, s:a_f_WAW_HAMZA, s:a_i_BEH],
	\[s:a_ALEF_HAMZA_BELOW, s:a_f_ALEF_HAMZA_BELOW, s:a_i_BEH],
	\[s:a_YEH_HAMZA, s:a_f_YEH_HAMZA, s:a_i_BEH],
	\[s:a_ALEF, s:a_f_ALEF, s:a_i_BEH],
	\[s:a_BEH, s:a_f_BEH, s:a_i_BEH],
	\[s:a_TEH_MARBUTA, s:a_f_TEH_MARBUTA, s:a_i_BEH],
	\[s:a_TEH, s:a_f_TEH, s:a_i_BEH],
	\[s:a_THEH, s:a_f_THEH, s:a_i_BEH],
	\[s:a_JEEM, s:a_f_JEEM, s:a_i_BEH],
	\[s:a_HAH, s:a_f_HAH, s:a_i_BEH],
	\[s:a_KHAH, s:a_f_KHAH, s:a_i_BEH],
	\[s:a_DAL, s:a_f_DAL, s:a_i_BEH],
	\[s:a_THAL, s:a_f_THAL, s:a_i_BEH],
	\[s:a_REH, s:a_f_REH, s:a_i_BEH],
	\[s:a_ZAIN, s:a_f_ZAIN, s:a_i_BEH],
	\[s:a_SEEN, s:a_f_SEEN, s:a_i_BEH],
	\[s:a_SHEEN, s:a_f_SHEEN, s:a_i_BEH],
	\[s:a_SAD, s:a_f_SAD, s:a_i_BEH],
	\[s:a_DAD, s:a_f_DAD, s:a_i_BEH],
	\[s:a_TAH, s:a_f_TAH, s:a_i_BEH],
	\[s:a_ZAH, s:a_f_ZAH, s:a_i_BEH],
	\[s:a_AIN, s:a_f_AIN, s:a_i_BEH],
	\[s:a_GHAIN, s:a_f_GHAIN, s:a_i_BEH],
	\[s:a_TATWEEL, s:a_TATWEEL, s:a_i_BEH],
	\[s:a_FEH, s:a_f_FEH, s:a_i_BEH],
	\[s:a_QAF, s:a_f_QAF, s:a_i_BEH],
	\[s:a_KAF, s:a_f_KAF, s:a_i_BEH],
	\[s:a_LAM, s:a_f_LAM, s:a_i_BEH],
	\[s:a_MEEM, s:a_f_MEEM, s:a_i_BEH],
	\[s:a_NOON, s:a_f_NOON, s:a_i_BEH],
	\[s:a_HEH, s:a_f_HEH, s:a_i_BEH],
	\[s:a_WAW, s:a_f_WAW, s:a_i_BEH],
	\[s:a_ALEF_MAKSURA, s:a_f_ALEF_MAKSURA, s:a_i_BEH],
	\[s:a_YEH, s:a_f_YEH, s:a_i_BEH],
	\ ]
    call setline(1, ' ' . pair[0] . s:a_BEH)
    call assert_equal([' ' . pair[1] . pair[2]], ScreenLines(1, 3))
  endfor

  set arabicshape&
  bwipe!
endfunc

func Test_shape_combination_final()
  new
  set arabicshape

  " Shaping arabic {testchar} arabic   Tests chg_c_laa2f().
  " pair[0] = testchar,  pair[1] = current-result
  for pair in [[s:a_ALEF_MADDA, s:a_f_LAM_ALEF_MADDA_ABOVE],
	\ [s:a_ALEF_HAMZA_ABOVE, s:a_f_LAM_ALEF_HAMZA_ABOVE],
	\ [s:a_ALEF_HAMZA_BELOW, s:a_f_LAM_ALEF_HAMZA_BELOW],
	\ [s:a_ALEF, s:a_f_LAM_ALEF],
	\ ]
    " The test char is a composing char, put on s:a_LAM.
    call setline(1, ' ' . s:a_LAM . pair[0] . s:a_BEH)
    call assert_equal([' ' . pair[1] . s:a_i_BEH], ScreenLines(1, 3))
  endfor

  set arabicshape&
  bwipe!
endfunc

func Test_shape_combination_isolated()
  new
  set arabicshape

  " Shaping arabic {testchar} arabic   Tests chg_c_laa2i().
  " pair[0] = testchar,  pair[1] = current-result
  for pair in [[s:a_ALEF_MADDA, s:a_s_LAM_ALEF_MADDA_ABOVE],
	\ [s:a_ALEF_HAMZA_ABOVE, s:a_s_LAM_ALEF_HAMZA_ABOVE],
	\ [s:a_ALEF_HAMZA_BELOW, s:a_s_LAM_ALEF_HAMZA_BELOW],
	\ [s:a_ALEF, s:a_s_LAM_ALEF],
	\ ]
    " The test char is a composing char, put on s:a_LAM.
    call setline(1, ' ' . s:a_LAM . pair[0] . ' ')
    call assert_equal([' ' . pair[1] . ' '], ScreenLines(1, 3))
  endfor

  set arabicshape&
  bwipe!
endfunc
