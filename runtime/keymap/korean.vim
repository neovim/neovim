" Maintainer: Jang Whemoon <palindrom615@gmail.com>
" Last Change: Nov 24, 2020
"
"
"
" Unlike Japanese or Chinese, modern Korean texts do not depends on conversion
" to Hanja (Chinese character). Thus, general Korean text totally can be
" covered without help of IME but this keymap. 
" 
" BUT, simply mapping each letter of Hangul with sequence of alphabet 1 by 1
" can fail to combine Hangul jamo (conconants and vowels) right.
" For example, sequentially pressing `ㅅㅓㅇㅜㄹㄷㅐㅎㅏㄱㅛ` can not only be
" combined as `서울대학교`, but also `성ㅜㄹ댛ㅏㄱ교`, which is totally 
" nonsense. 
" Though combining Hangul is deterministic with law that each letter must be 
" one of (consonant + vowel) or (consonant + vowel + consonant), there is no
" way to apply such law without implementing input engine.
"
" Thus, user of this keymap should wait until previous hangul letter is
" completed before typing next one. To reduce such inconvenience, I suggest to
" set `timeoutlen` with their own value. (default value is 1000ms)

source <sfile>:p:h/korean-dubeolsik_utf-8.vim
