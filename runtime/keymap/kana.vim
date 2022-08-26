" This script was originally created by Rory McCann <ebelular at gmail dot com>.
" Dan Kenigsberg noticed some deficiencies and suggested this one instead.
"
" Maintainer: Rory McCann <ebelular at gmail dot com>
" Modified by: Edward L. Fox <edyfox at gmail dot com>
" Last Change: 2006 Apr 30
"
"
"
"  Kana.kmap (Japanese Phonograms)
"
"  Converted from Gaspar Sinai's yudit 2.7.6
"  GNU (C) Gaspar Sinai <gsinai@yudit.org>
"
"  WARNING
"  -------
"  This version of Kana.kmap is different from the one that has been used
"  with yudit-2.7.2 or earlier.  The main difference is that this kmap is
"  arranged in such a way that it complies with an authorized Japanese
"  transliteration.  As a result, backward compatibility is not guaranteed.
"
"  NOTE
"  ----
"  1.	In general, the transliteration is based on Japanese Government's
"	Cabinet	Notification 1 (Dec. 9, 1954).
"
"	Summary:
"
"	(1) To transliterate Japanese language, Table 1 should be used
"	   primarily.
"	(2) Table 2 may be used only when existing conventions such as
"	   international relationship should be respected.
"	(3) Other transliteration is acceptable only when neither Table 1
"	    nor Table 2 gives any specification of the sound in question
"
"	For details, refer to
"
"	    http://xembho.tripod.com/siryo/naikaku_kokuzi.html
"
"  2.	The specification instructed by the Cabinet Notification is rather
"	inadequate even for daily use.  At the present time there are thus
"	many unauthorized but widely accepted conventions used together with
"	the authorized transliteration.  This kmap contains some of them for
"	user's convenience (cf. Hiragana 3 and Katakana 3).
"
"  3.	For the unicode mapping relevant to this kmap, refer to	3075--30F5 of
"
"	    http://www.macchiato.com/unicode/charts.html
"
"  HISTORY
"  -------
"  2005-01-11	<danken@cs.technion.ac.il>
"	* Converted to Vim format.
"  2003-01-22	<kazunobu.kuriyama@nifty.com>
"
"	* Submitted to gsinai@yudit.org
"
" ============================================================================

scriptencoding utf-8

" ----------------------------------------------------------------------------
"  Kigou (Punctuation etc.)
" ----------------------------------------------------------------------------

let b:keymap_name = "kana"

loadkeymap
"0x20  0x3000
, 、
. 。
,, 〃


xx 〆
@ 〇
< 〈
> 〉
<< 《
>> 》
{ 「
} 」
{{ 『
}} 』
[.( 【
).] 】


[ 〔
] 〕
[( 〖
)] 〗


[[ 〚
]] 〛


.. ・
- ー


" ----------------------------------------------------------------------------
"  Hiragana 1 --- Table 1, Cabinet Notification No. 1 (Dec. 9, 1954)
" ----------------------------------------------------------------------------
a あ
i い
u う
e え
o お

ka か
ki き
ku く
ke け
ko こ

sa さ
si し
su す
se せ
so そ

ta た
ti ち
tu つ
te て
to と

na な
ni に
nu ぬ
ne ね
no の

ha は
hi ひ
hu ふ
he へ
ho ほ

ma ま
mi み
mu む
me め
mo も

ya や
yu ゆ
yo よ

ra ら
ri り
ru る
re れ
ro ろ

wa わ

ga が
gi ぎ
gu ぐ
ge げ
go ご

za ざ
zi じ
zu ず
ze ぜ
zo ぞ

da だ
de で
do ど

ba ば
bi び
bu ぶ
be べ
bo ぼ

pa ぱ
pi ぴ
pu ぷ
pe ぺ
po ぽ

kya きゃ
kyu きゅ
kyo きょ

sya しゃ
syu しゅ
syo しょ

tya ちゃ
tyu ちゅ
tyo ちょ

nya にゃ
nyu にゅ
nyo にょ

hya ひゃ
hyu ひゅ
hyo ひょ

mya みゃ
myu みゅ
myo みょ

rya りゃ
ryu りゅ
ryo りょ

gya ぎゃ
gyu ぎゅ
gyo ぎょ

zya じゃ
zyu じゅ
zyo じょ

bya びゃ
byu びゅ
byo びょ

pya ぴゃ
pyu ぴゅ
pyo ぴょ

n ん
n' ん


" ----------------------------------------------------------------------------
"  Hiragana 2 --- Table 2, Cabinet Notification No. 1 (Dec. 9, 1954)
" ----------------------------------------------------------------------------
sha しゃ
shi し
shu しゅ
sho しょ

tsu つ

cha ちゃ
chi ち
chu ちゅ
cho ちょ

fu ふ

ja じゃ
ji じ
ju じゅ
jo じょ

di ぢ
du づ
dya ぢゃ
dyu ぢゅ
dyo ぢょ

kwa くゎ
gwa ぐゎ

wo を


" ----------------------------------------------------------------------------
"  Hiragana 3 --- Conventional transliterations
" ----------------------------------------------------------------------------

" Small Hiragana: The prefix X is never pronounced.  It is used as something
" like an escape character.
xa ぁ
xi ぃ
xu ぅ
xe ぇ
xo ぉ

xtu っ

xya ゃ
xyu ゅ
xyo ょ

xwa ゎ

" Historic `wi' and `we'
wi ゐ
we ゑ

" Preceded by a small `tu'
kka っか
kki っき
kku っく
kke っけ
kko っこ

ssa っさ
ssi っし
ssu っす
sse っせ
sso っそ

tta った
tti っち
ttu っつ
tte って
tto っと

hha っは
hhi っひ
hhu っふ
hhe っへ
hho っほ

mma っま
mmi っみ
mmu っむ
mme っめ
mmo っも

yya っや
yyu っゆ
yyo っよ

rra っら
rri っり
rru っる
rre っれ
rro っろ

wwa っわ

gga っが
ggi っぎ
ggu っぐ
gge っげ
ggo っご

zza っざ
zzi っじ
zzu っず
zze っぜ
zzo っぞ

dda っだ
ddi っぢ
ddu っづ
dde っで
ddo っど

bba っば
bbi っび
bbu っぶ
bbe っべ
bbo っぼ

ppa っぱ
ppi っぴ
ppu っぷ
ppe っぺ
ppo っぽ

" Preceded by a small `tu' and followed by a small 'ya', 'yu' or 'yo'
kkya っきゃ
kkyu っきゅ
kkyo っきょ

ssya っしゃ
ssyu っしゅ
ssyo っしょ

ttya っちゃ
ttyu っちゅ
ttyo っちょ

hhya っひゃ
hhyu っひゅ
hhyo っひょ

mmya っみゃ
mmyu っみゅ
mmyo っみょ

rrya っりゃ
rryu っりゅ
rryo っりょ

ggya っぎゃ
ggyu っぎゅ
ggyo っぎょ

zzya っじゃ
zzyu っじゅ
zzyo っじょ

bbya っびゃ
bbyu っびゅ
bbyo っびょ

ppya っぴゃ
ppyu っぴゅ
ppyo っぴょ


" ----------------------------------------------------------------------------
"  Katakana 1 --- Table 1, Cabinet Notification No. 1 (Dec. 9, 1954)
" ----------------------------------------------------------------------------
A ア
I イ
U ウ
E エ
O オ

KA カ
KI キ
KU ク
KE ケ
KO コ

SA サ
SI シ
SU ス
SE セ
SO ソ

TA タ
TI チ
TU ツ
TE テ
TO ト

NA ナ
NI ニ
NU ヌ
NE ネ
NO ノ

HA ハ
HI ヒ
HU フ
HE ヘ
HO ホ

MA マ
MI ミ
MU ム
ME メ
MO モ

YA ヤ
YU ユ
YO ヨ

RA ラ
RI リ
RU ル
RE レ
RO ロ

WA ワ

GA ガ
GI ギ
GU グ
GE ゲ
GO ゴ

ZA ザ
ZI ジ
ZU ズ
ZE ゼ
ZO ゾ

DA ダ
DE デ
DO ド

BA バ
BI ビ
BU ブ
BE ベ
BO ボ

PA パ
PI ピ
PU プ
PE ペ
PO ポ

KYA キャ
KYU キュ
KYO キョ

SYA シャ
SYU シュ
SYO ショ

TYA チャ
TYU チュ
TYO チョ

NYA ニャ
NYU ニュ
NYO ニョ

HYA ヒャ
HYU ヒュ
HYO ヒョ

MYA ミャ
MYU ミュ
MYO ミョ

RYA リャ
RYU リュ
RYO リョ

GYA ギャ
GYU ギュ
GYO ギョ

ZYA ジャ
ZYU ジュ
ZYO ジョ

BYA ビャ
BYU ビュ
BYO ビョ

PYA ピャ
PYU ピュ
PYO ピョ

N ン
N' ン


" ----------------------------------------------------------------------------
"  Katakana 2 --- Table 2, Cabinet Notification No. 1 (Dec. 9, 1954)
" ----------------------------------------------------------------------------
SHA シャ
SHI シ
SHU シュ
SHO ショ

TSU ツ

CHA チャ
CHI チ
CHU チュ
CHO チョ

FU フ

JA ジャ
JI ジ
JU ジュ
JO ジョ

DI ヂ
DU ヅ
DYA ヂャ
DYU ヂュ
DYO ヂョ

KWA クヮ
GWA グヮ

WO ヲ


" ----------------------------------------------------------------------------
"  Katakana 3 --- Conventional transliterations
" ----------------------------------------------------------------------------

" Small Katakana: The prefix X is never pronounced.  It is used as something
" like an escape character.
XA ァ
XI ィ
XU ゥ
XE ェ
XO ォ

XTU ッ

XYA ャ
XYU ュ
XYO ョ

XWA ヮ

" Used only for counting someone or something
XKA ヵ
XKE ヶ

" Historic `wi' and `we'
WI ヰ
WE ヱ

" Used for the sound `v' of European languages
VA ヴァ
VI ヴィ
VU ヴ
VE ヴェ
VO ヴォ

VYU ヴュ

" Preceded by a small `tu'
KKA ッカ
KKI ッキ
KKU ック
KKE ッケ
KKO ッコ

SSA ッサ
SSI ッシ
SSU ッス
SSE ッセ
SSO ッソ

TTA ッタ
TTI ッチ
TTU ッツ
TTE ッテ
TTO ット

HHA ッハ
HHI ッヒ
HHU ッフ
HHE ッヘ
HHO ッホ

MMA ッマ
MMI ッミ
MMU ッム
MME ッメ
MMO ッモ

YYA ッヤ
YYU ッユ
YYO ッヨ

RRA ッラ
RRI ッリ
RRU ッル
RRE ッレ
RRO ッロ

WWA ッワ

GGA ッガ
GGI ッギ
GGU ッグ
GGE ッゲ
GGO ッゴ

ZZA ッザ
ZZI ッジ
ZZU ッズ
ZZE ッゼ
ZZO ッゾ

DDA ッダ
DDI ッヂ
DDU ッヅ
DDE ッデ
DDO ッド

BBA ッバ
BBI ッビ
BBU ッブ
BBE ッベ
BBO ッボ

PPA ッパ
PPI ッピ
PPU ップ
PPE ッペ
PPO ッポ

" Preceded by a small `tu' and followed by a small 'ya', 'yu' or 'yo'
KKYA ッキャ
KKYU ッキュ
KKYO ッキョ

SSYA ッシャ
SSYU ッシュ
SSYO ッショ

TTYA ッチャ
TTYU ッチュ
TTYO ッチョ

HHYA ッヒャ
HHYU ッヒュ
HHYO ッヒョ

MMYA ッミャ
MMYU ッミュ
MMYO ッミョ

RRYA ッリャ
RRYU ッリュ
RRYO ッリョ

GGYA ッギャ
GGYU ッギュ
GGYO ッギョ

ZZYA ッジャ
ZZYU ッジュ
ZZYO ッジョ

BBYA ッビャ
BBYU ッビュ
BBYO ッビョ

PPYA ッピャ
PPYU ッピュ
PPYO ッピョ


