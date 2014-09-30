" Vim syntax file
" Language:         xmodmap(1) definition file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-04-19

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword xmodmapTodo       contained TODO FIXME XXX NOTE

syn region  xmodmapComment    display oneline start='^!' end='$'
                              \ contains=xmodmapTodo,@Spell

syn case ignore
syn match   xmodmapInt        display '\<\d\+\>'
syn match   xmodmapHex        display '\<0x\x\+\>'
syn match   xmodmapOctal      display '\<0\o\+\>'
syn match   xmodmapOctalError display '\<0\o*[89]\d*'
syn case match

syn match   xmodmapKeySym     display '\<[A-Za-z]\>'

" #include <X11/keysymdef.h>
syn keyword xmodmapKeySym     XK_VoidSymbol XK_BackSpace XK_Tab XK_Linefeed
                              \ XK_Clear XK_Return XK_Pause XK_Scroll_Lock
                              \ XK_Sys_Req XK_Escape XK_Delete XK_Multi_key
                              \ XK_Codeinput XK_SingleCandidate
                              \ XK_MultipleCandidate XK_PreviousCandidate
                              \ XK_Kanji XK_Muhenkan XK_Henkan_Mode
                              \ XK_Henkan XK_Romaji XK_Hiragana XK_Katakana
                              \ XK_Hiragana_Katakana XK_Zenkaku XK_Hankaku
                              \ XK_Zenkaku_Hankaku XK_Touroku XK_Massyo
                              \ XK_Kana_Lock XK_Kana_Shift XK_Eisu_Shift
                              \ XK_Eisu_toggle XK_Kanji_Bangou XK_Zen_Koho
                              \ XK_Mae_Koho XK_Home XK_Left XK_Up XK_Right
                              \ XK_Down XK_Prior XK_Page_Up XK_Next
                              \ XK_Page_Down XK_End XK_Begin XK_Select
                              \ XK_Print XK_Execute XK_Insert XK_Undo XK_Redo
                              \ XK_Menu XK_Find XK_Cancel XK_Help XK_Break
                              \ XK_Mode_switch XK_script_switch XK_Num_Lock
                              \ XK_KP_Space XK_KP_Tab XK_KP_Enter XK_KP_F1
                              \ XK_KP_F2 XK_KP_F3 XK_KP_F4 XK_KP_Home
                              \ XK_KP_Left XK_KP_Up XK_KP_Right XK_KP_Down
                              \ XK_KP_Prior XK_KP_Page_Up XK_KP_Next
                              \ XK_KP_Page_Down XK_KP_End XK_KP_Begin
                              \ XK_KP_Insert XK_KP_Delete XK_KP_Equal
                              \ XK_KP_Multiply XK_KP_Add XK_KP_Separator
                              \ XK_KP_Subtract XK_KP_Decimal XK_KP_Divide
                              \ XK_KP_0 XK_KP_1 XK_KP_2 XK_KP_3 XK_KP_4
                              \ XK_KP_5 XK_KP_6 XK_KP_7 XK_KP_8 XK_KP_9 XK_F1
                              \ XK_F2 XK_F3 XK_F4 XK_F5 XK_F6 XK_F7 XK_F8
                              \ XK_F9 XK_F10 XK_F11 XK_L1 XK_F12 XK_L2 XK_F13
                              \ XK_L3 XK_F14 XK_L4 XK_F15 XK_L5 XK_F16 XK_L6
                              \ XK_F17 XK_L7 XK_F18 XK_L8 XK_F19 XK_L9 XK_F20
                              \ XK_L10 XK_F21 XK_R1 XK_F22 XK_R2 XK_F23
                              \ XK_R3 XK_F24 XK_R4 XK_F25 XK_R5 XK_F26
                              \ XK_R6 XK_F27 XK_R7 XK_F28 XK_R8 XK_F29
                              \ XK_R9 XK_F30 XK_R10 XK_F31 XK_R11 XK_F32
                              \ XK_R12 XK_F33 XK_R13 XK_F34 XK_R14 XK_F35
                              \ XK_R15 XK_Shift_L XK_Shift_R XK_Control_L
                              \ XK_Control_R XK_Caps_Lock XK_Shift_Lock
                              \ XK_Meta_L XK_Meta_R XK_Alt_L XK_Alt_R
                              \ XK_Super_L XK_Super_R XK_Hyper_L XK_Hyper_R
                              \ XK_dead_hook XK_dead_horn XK_3270_Duplicate
                              \ XK_3270_FieldMark XK_3270_Right2 XK_3270_Left2
                              \ XK_3270_BackTab XK_3270_EraseEOF
                              \ XK_3270_EraseInput XK_3270_Reset
                              \ XK_3270_Quit XK_3270_PA1 XK_3270_PA2
                              \ XK_3270_PA3 XK_3270_Test XK_3270_Attn
                              \ XK_3270_CursorBlink XK_3270_AltCursor
                              \ XK_3270_KeyClick XK_3270_Jump
                              \ XK_3270_Ident XK_3270_Rule XK_3270_Copy
                              \ XK_3270_Play XK_3270_Setup XK_3270_Record
                              \ XK_3270_ChangeScreen XK_3270_DeleteWord
                              \ XK_3270_ExSelect XK_3270_CursorSelect
                              \ XK_3270_PrintScreen XK_3270_Enter XK_space
                              \ XK_exclam XK_quotedbl XK_numbersign XK_dollar
                              \ XK_percent XK_ampersand XK_apostrophe
                              \ XK_quoteright XK_parenleft XK_parenright
                              \ XK_asterisk XK_plus XK_comma XK_minus
                              \ XK_period XK_slash XK_0 XK_1 XK_2 XK_3
                              \ XK_4 XK_5 XK_6 XK_7 XK_8 XK_9 XK_colon
                              \ XK_semicolon XK_less XK_equal XK_greater
                              \ XK_question XK_at XK_A XK_B XK_C XK_D XK_E
                              \ XK_F XK_G XK_H XK_I XK_J XK_K XK_L XK_M XK_N
                              \ XK_O XK_P XK_Q XK_R XK_S XK_T XK_U XK_V XK_W
                              \ XK_X XK_Y XK_Z XK_bracketleft XK_backslash
                              \ XK_bracketright XK_asciicircum XK_underscore
                              \ XK_grave XK_quoteleft XK_a XK_b XK_c XK_d
                              \ XK_e XK_f XK_g XK_h XK_i XK_j XK_k XK_l
                              \ XK_m XK_n XK_o XK_p XK_q XK_r XK_s XK_t XK_u
                              \ XK_v XK_w XK_x XK_y XK_z XK_braceleft XK_bar
                              \ XK_braceright XK_asciitilde XK_nobreakspace
                              \ XK_exclamdown XK_cent XK_sterling XK_currency
                              \ XK_yen XK_brokenbar XK_section XK_diaeresis
                              \ XK_copyright XK_ordfeminine XK_guillemotleft
                              \ XK_notsign XK_hyphen XK_registered XK_macron
                              \ XK_degree XK_plusminus XK_twosuperior
                              \ XK_threesuperior XK_acute XK_mu XK_paragraph
                              \ XK_periodcentered XK_cedilla XK_onesuperior
                              \ XK_masculine XK_guillemotright XK_onequarter
                              \ XK_onehalf XK_threequarters XK_questiondown
                              \ XK_Agrave XK_Aacute XK_Acircumflex XK_Atilde
                              \ XK_Adiaeresis XK_Aring XK_AE XK_Ccedilla
                              \ XK_Egrave XK_Eacute XK_Ecircumflex
                              \ XK_Ediaeresis XK_Igrave XK_Iacute
                              \ XK_Icircumflex XK_Idiaeresis XK_ETH XK_Eth
                              \ XK_Ntilde XK_Ograve XK_Oacute XK_Ocircumflex
                              \ XK_Otilde XK_Odiaeresis XK_multiply
                              \ XK_Ooblique XK_Ugrave XK_Uacute XK_Ucircumflex
                              \ XK_Udiaeresis XK_Yacute XK_THORN XK_Thorn
                              \ XK_ssharp XK_agrave XK_aacute XK_acircumflex
                              \ XK_atilde XK_adiaeresis XK_aring XK_ae
                              \ XK_ccedilla XK_egrave XK_eacute XK_ecircumflex
                              \ XK_ediaeresis XK_igrave XK_iacute
                              \ XK_icircumflex XK_idiaeresis XK_eth XK_ntilde
                              \ XK_ograve XK_oacute XK_ocircumflex XK_otilde
                              \ XK_odiaeresis XK_division XK_oslash XK_ugrave
                              \ XK_uacute XK_ucircumflex XK_udiaeresis
                              \ XK_yacute XK_thorn XK_ydiaeresis XK_Aogonek
                              \ XK_breve XK_Lstroke XK_Lcaron XK_Sacute
                              \ XK_Scaron XK_Scedilla XK_Tcaron XK_Zacute
                              \ XK_Zcaron XK_Zabovedot XK_aogonek XK_ogonek
                              \ XK_lstroke XK_lcaron XK_sacute XK_caron
                              \ XK_scaron XK_scedilla XK_tcaron XK_zacute
                              \ XK_doubleacute XK_zcaron XK_zabovedot
                              \ XK_Racute XK_Abreve XK_Lacute XK_Cacute
                              \ XK_Ccaron XK_Eogonek XK_Ecaron XK_Dcaron
                              \ XK_Dstroke XK_Nacute XK_Ncaron XK_Odoubleacute
                              \ XK_Rcaron XK_Uring XK_Udoubleacute
                              \ XK_Tcedilla XK_racute XK_abreve XK_lacute
                              \ XK_cacute XK_ccaron XK_eogonek XK_ecaron
                              \ XK_dcaron XK_dstroke XK_nacute XK_ncaron
                              \ XK_odoubleacute XK_udoubleacute XK_rcaron
                              \ XK_uring XK_tcedilla XK_abovedot XK_Hstroke
                              \ XK_Hcircumflex XK_Iabovedot XK_Gbreve
                              \ XK_Jcircumflex XK_hstroke XK_hcircumflex
                              \ XK_idotless XK_gbreve XK_jcircumflex
                              \ XK_Cabovedot XK_Ccircumflex XK_Gabovedot
                              \ XK_Gcircumflex XK_Ubreve XK_Scircumflex
                              \ XK_cabovedot XK_ccircumflex XK_gabovedot
                              \ XK_gcircumflex XK_ubreve XK_scircumflex XK_kra
                              \ XK_kappa XK_Rcedilla XK_Itilde XK_Lcedilla
                              \ XK_Emacron XK_Gcedilla XK_Tslash XK_rcedilla
                              \ XK_itilde XK_lcedilla XK_emacron XK_gcedilla
                              \ XK_tslash XK_ENG XK_eng XK_Amacron XK_Iogonek
                              \ XK_Eabovedot XK_Imacron XK_Ncedilla XK_Omacron
                              \ XK_Kcedilla XK_Uogonek XK_Utilde XK_Umacron
                              \ XK_amacron XK_iogonek XK_eabovedot XK_imacron
                              \ XK_ncedilla XK_omacron XK_kcedilla XK_uogonek
                              \ XK_utilde XK_umacron XK_Babovedot XK_babovedot
                              \ XK_Dabovedot XK_Wgrave XK_Wacute XK_dabovedot
                              \ XK_Ygrave XK_Fabovedot XK_fabovedot
                              \ XK_Mabovedot XK_mabovedot XK_Pabovedot
                              \ XK_wgrave XK_pabovedot XK_wacute XK_Sabovedot
                              \ XK_ygrave XK_Wdiaeresis XK_wdiaeresis
                              \ XK_sabovedot XK_Wcircumflex XK_Tabovedot
                              \ XK_Ycircumflex XK_wcircumflex
                              \ XK_tabovedot XK_ycircumflex XK_OE XK_oe
                              \ XK_Ydiaeresis XK_overline XK_kana_fullstop
                              \ XK_kana_openingbracket XK_kana_closingbracket
                              \ XK_kana_comma XK_kana_conjunctive
                              \ XK_kana_middledot XK_kana_WO XK_kana_a
                              \ XK_kana_i XK_kana_u XK_kana_e XK_kana_o
                              \ XK_kana_ya XK_kana_yu XK_kana_yo
                              \ XK_kana_tsu XK_kana_tu XK_prolongedsound
                              \ XK_kana_A XK_kana_I XK_kana_U XK_kana_E
                              \ XK_kana_O XK_kana_KA XK_kana_KI XK_kana_KU
                              \ XK_kana_KE XK_kana_KO XK_kana_SA XK_kana_SHI
                              \ XK_kana_SU XK_kana_SE XK_kana_SO XK_kana_TA
                              \ XK_kana_CHI XK_kana_TI XK_kana_TSU
                              \ XK_kana_TU XK_kana_TE XK_kana_TO XK_kana_NA
                              \ XK_kana_NI XK_kana_NU XK_kana_NE XK_kana_NO
                              \ XK_kana_HA XK_kana_HI XK_kana_FU XK_kana_HU
                              \ XK_kana_HE XK_kana_HO XK_kana_MA XK_kana_MI
                              \ XK_kana_MU XK_kana_ME XK_kana_MO XK_kana_YA
                              \ XK_kana_YU XK_kana_YO XK_kana_RA XK_kana_RI
                              \ XK_kana_RU XK_kana_RE XK_kana_RO XK_kana_WA
                              \ XK_kana_N XK_voicedsound XK_semivoicedsound
                              \ XK_kana_switch XK_Farsi_0 XK_Farsi_1
                              \ XK_Farsi_2 XK_Farsi_3 XK_Farsi_4 XK_Farsi_5
                              \ XK_Farsi_6 XK_Farsi_7 XK_Farsi_8 XK_Farsi_9
                              \ XK_Arabic_percent XK_Arabic_superscript_alef
                              \ XK_Arabic_tteh XK_Arabic_peh XK_Arabic_tcheh
                              \ XK_Arabic_ddal XK_Arabic_rreh XK_Arabic_comma
                              \ XK_Arabic_fullstop XK_Arabic_0 XK_Arabic_1
                              \ XK_Arabic_2 XK_Arabic_3 XK_Arabic_4
                              \ XK_Arabic_5 XK_Arabic_6 XK_Arabic_7
                              \ XK_Arabic_8 XK_Arabic_9 XK_Arabic_semicolon
                              \ XK_Arabic_question_mark XK_Arabic_hamza
                              \ XK_Arabic_maddaonalef XK_Arabic_hamzaonalef
                              \ XK_Arabic_hamzaonwaw XK_Arabic_hamzaunderalef
                              \ XK_Arabic_hamzaonyeh XK_Arabic_alef
                              \ XK_Arabic_beh XK_Arabic_tehmarbuta
                              \ XK_Arabic_teh XK_Arabic_theh XK_Arabic_jeem
                              \ XK_Arabic_hah XK_Arabic_khah XK_Arabic_dal
                              \ XK_Arabic_thal XK_Arabic_ra XK_Arabic_zain
                              \ XK_Arabic_seen XK_Arabic_sheen
                              \ XK_Arabic_sad XK_Arabic_dad XK_Arabic_tah
                              \ XK_Arabic_zah XK_Arabic_ain XK_Arabic_ghain
                              \ XK_Arabic_tatweel XK_Arabic_feh XK_Arabic_qaf
                              \ XK_Arabic_kaf XK_Arabic_lam XK_Arabic_meem
                              \ XK_Arabic_noon XK_Arabic_ha XK_Arabic_heh
                              \ XK_Arabic_waw XK_Arabic_alefmaksura
                              \ XK_Arabic_yeh XK_Arabic_fathatan
                              \ XK_Arabic_dammatan XK_Arabic_kasratan
                              \ XK_Arabic_fatha XK_Arabic_damma
                              \ XK_Arabic_kasra XK_Arabic_shadda
                              \ XK_Arabic_sukun XK_Arabic_madda_above
                              \ XK_Arabic_hamza_above XK_Arabic_hamza_below
                              \ XK_Arabic_jeh XK_Arabic_veh XK_Arabic_keheh
                              \ XK_Arabic_gaf XK_Arabic_noon_ghunna
                              \ XK_Arabic_heh_doachashmee XK_Farsi_yeh
                              \ XK_Arabic_yeh_baree XK_Arabic_heh_goal
                              \ XK_Arabic_switch XK_Cyrillic_GHE_bar
                              \ XK_Cyrillic_ghe_bar XK_Cyrillic_ZHE_descender
                              \ XK_Cyrillic_zhe_descender
                              \ XK_Cyrillic_KA_descender
                              \ XK_Cyrillic_ka_descender
                              \ XK_Cyrillic_KA_vertstroke
                              \ XK_Cyrillic_ka_vertstroke
                              \ XK_Cyrillic_EN_descender
                              \ XK_Cyrillic_en_descender
                              \ XK_Cyrillic_U_straight XK_Cyrillic_u_straight
                              \ XK_Cyrillic_U_straight_bar
                              \ XK_Cyrillic_u_straight_bar
                              \ XK_Cyrillic_HA_descender
                              \ XK_Cyrillic_ha_descender
                              \ XK_Cyrillic_CHE_descender
                              \ XK_Cyrillic_che_descender
                              \ XK_Cyrillic_CHE_vertstroke
                              \ XK_Cyrillic_che_vertstroke XK_Cyrillic_SHHA
                              \ XK_Cyrillic_shha XK_Cyrillic_SCHWA
                              \ XK_Cyrillic_schwa XK_Cyrillic_I_macron
                              \ XK_Cyrillic_i_macron XK_Cyrillic_O_bar
                              \ XK_Cyrillic_o_bar XK_Cyrillic_U_macron
                              \ XK_Cyrillic_u_macron XK_Serbian_dje
                              \ XK_Macedonia_gje XK_Cyrillic_io
                              \ XK_Ukrainian_ie XK_Ukranian_je
                              \ XK_Macedonia_dse XK_Ukrainian_i XK_Ukranian_i
                              \ XK_Ukrainian_yi XK_Ukranian_yi XK_Cyrillic_je
                              \ XK_Serbian_je XK_Cyrillic_lje XK_Serbian_lje
                              \ XK_Cyrillic_nje XK_Serbian_nje XK_Serbian_tshe
                              \ XK_Macedonia_kje XK_Ukrainian_ghe_with_upturn
                              \ XK_Byelorussian_shortu XK_Cyrillic_dzhe
                              \ XK_Serbian_dze XK_numerosign
                              \ XK_Serbian_DJE XK_Macedonia_GJE
                              \ XK_Cyrillic_IO XK_Ukrainian_IE XK_Ukranian_JE
                              \ XK_Macedonia_DSE XK_Ukrainian_I XK_Ukranian_I
                              \ XK_Ukrainian_YI XK_Ukranian_YI XK_Cyrillic_JE
                              \ XK_Serbian_JE XK_Cyrillic_LJE XK_Serbian_LJE
                              \ XK_Cyrillic_NJE XK_Serbian_NJE XK_Serbian_TSHE
                              \ XK_Macedonia_KJE XK_Ukrainian_GHE_WITH_UPTURN
                              \ XK_Byelorussian_SHORTU XK_Cyrillic_DZHE
                              \ XK_Serbian_DZE XK_Cyrillic_yu
                              \ XK_Cyrillic_a XK_Cyrillic_be XK_Cyrillic_tse
                              \ XK_Cyrillic_de XK_Cyrillic_ie XK_Cyrillic_ef
                              \ XK_Cyrillic_ghe XK_Cyrillic_ha XK_Cyrillic_i
                              \ XK_Cyrillic_shorti XK_Cyrillic_ka
                              \ XK_Cyrillic_el XK_Cyrillic_em XK_Cyrillic_en
                              \ XK_Cyrillic_o XK_Cyrillic_pe XK_Cyrillic_ya
                              \ XK_Cyrillic_er XK_Cyrillic_es XK_Cyrillic_te
                              \ XK_Cyrillic_u XK_Cyrillic_zhe XK_Cyrillic_ve
                              \ XK_Cyrillic_softsign XK_Cyrillic_yeru
                              \ XK_Cyrillic_ze XK_Cyrillic_sha XK_Cyrillic_e
                              \ XK_Cyrillic_shcha XK_Cyrillic_che
                              \ XK_Cyrillic_hardsign XK_Cyrillic_YU
                              \ XK_Cyrillic_A XK_Cyrillic_BE XK_Cyrillic_TSE
                              \ XK_Cyrillic_DE XK_Cyrillic_IE XK_Cyrillic_EF
                              \ XK_Cyrillic_GHE XK_Cyrillic_HA XK_Cyrillic_I
                              \ XK_Cyrillic_SHORTI XK_Cyrillic_KA
                              \ XK_Cyrillic_EL XK_Cyrillic_EM XK_Cyrillic_EN
                              \ XK_Cyrillic_O XK_Cyrillic_PE XK_Cyrillic_YA
                              \ XK_Cyrillic_ER XK_Cyrillic_ES XK_Cyrillic_TE
                              \ XK_Cyrillic_U XK_Cyrillic_ZHE XK_Cyrillic_VE
                              \ XK_Cyrillic_SOFTSIGN XK_Cyrillic_YERU
                              \ XK_Cyrillic_ZE XK_Cyrillic_SHA XK_Cyrillic_E
                              \ XK_Cyrillic_SHCHA XK_Cyrillic_CHE
                              \ XK_Cyrillic_HARDSIGN XK_Greek_ALPHAaccent
                              \ XK_Greek_EPSILONaccent XK_Greek_ETAaccent
                              \ XK_Greek_IOTAaccent XK_Greek_IOTAdieresis
                              \ XK_Greek_OMICRONaccent XK_Greek_UPSILONaccent
                              \ XK_Greek_UPSILONdieresis
                              \ XK_Greek_OMEGAaccent XK_Greek_accentdieresis
                              \ XK_Greek_horizbar XK_Greek_alphaaccent
                              \ XK_Greek_epsilonaccent XK_Greek_etaaccent
                              \ XK_Greek_iotaaccent XK_Greek_iotadieresis
                              \ XK_Greek_iotaaccentdieresis
                              \ XK_Greek_omicronaccent XK_Greek_upsilonaccent
                              \ XK_Greek_upsilondieresis
                              \ XK_Greek_upsilonaccentdieresis
                              \ XK_Greek_omegaaccent XK_Greek_ALPHA
                              \ XK_Greek_BETA XK_Greek_GAMMA XK_Greek_DELTA
                              \ XK_Greek_EPSILON XK_Greek_ZETA XK_Greek_ETA
                              \ XK_Greek_THETA XK_Greek_IOTA XK_Greek_KAPPA
                              \ XK_Greek_LAMDA XK_Greek_LAMBDA XK_Greek_MU
                              \ XK_Greek_NU XK_Greek_XI XK_Greek_OMICRON
                              \ XK_Greek_PI XK_Greek_RHO XK_Greek_SIGMA
                              \ XK_Greek_TAU XK_Greek_UPSILON XK_Greek_PHI
                              \ XK_Greek_CHI XK_Greek_PSI XK_Greek_OMEGA
                              \ XK_Greek_alpha XK_Greek_beta XK_Greek_gamma
                              \ XK_Greek_delta XK_Greek_epsilon XK_Greek_zeta
                              \ XK_Greek_eta XK_Greek_theta XK_Greek_iota
                              \ XK_Greek_kappa XK_Greek_lamda XK_Greek_lambda
                              \ XK_Greek_mu XK_Greek_nu XK_Greek_xi
                              \ XK_Greek_omicron XK_Greek_pi XK_Greek_rho
                              \ XK_Greek_sigma XK_Greek_finalsmallsigma
                              \ XK_Greek_tau XK_Greek_upsilon XK_Greek_phi
                              \ XK_Greek_chi XK_Greek_psi XK_Greek_omega
                              \ XK_Greek_switch XK_leftradical
                              \ XK_topleftradical XK_horizconnector
                              \ XK_topintegral XK_botintegral
                              \ XK_vertconnector XK_topleftsqbracket
                              \ XK_botleftsqbracket XK_toprightsqbracket
                              \ XK_botrightsqbracket XK_topleftparens
                              \ XK_botleftparens XK_toprightparens
                              \ XK_botrightparens XK_leftmiddlecurlybrace
                              \ XK_rightmiddlecurlybrace
                              \ XK_topleftsummation XK_botleftsummation
                              \ XK_topvertsummationconnector
                              \ XK_botvertsummationconnector
                              \ XK_toprightsummation XK_botrightsummation
                              \ XK_rightmiddlesummation XK_lessthanequal
                              \ XK_notequal XK_greaterthanequal XK_integral
                              \ XK_therefore XK_variation XK_infinity
                              \ XK_nabla XK_approximate XK_similarequal
                              \ XK_ifonlyif XK_implies XK_identical XK_radical
                              \ XK_includedin XK_includes XK_intersection
                              \ XK_union XK_logicaland XK_logicalor
                              \ XK_partialderivative XK_function XK_leftarrow
                              \ XK_uparrow XK_rightarrow XK_downarrow XK_blank
                              \ XK_soliddiamond XK_checkerboard XK_ht XK_ff
                              \ XK_cr XK_lf XK_nl XK_vt XK_lowrightcorner
                              \ XK_uprightcorner XK_upleftcorner
                              \ XK_lowleftcorner XK_crossinglines
                              \ XK_horizlinescan1 XK_horizlinescan3
                              \ XK_horizlinescan5 XK_horizlinescan7
                              \ XK_horizlinescan9 XK_leftt XK_rightt XK_bott
                              \ XK_topt XK_vertbar XK_emspace XK_enspace
                              \ XK_em3space XK_em4space XK_digitspace
                              \ XK_punctspace XK_thinspace XK_hairspace
                              \ XK_emdash XK_endash XK_signifblank XK_ellipsis
                              \ XK_doubbaselinedot XK_onethird XK_twothirds
                              \ XK_onefifth XK_twofifths XK_threefifths
                              \ XK_fourfifths XK_onesixth XK_fivesixths
                              \ XK_careof XK_figdash XK_leftanglebracket
                              \ XK_decimalpoint XK_rightanglebracket
                              \ XK_marker XK_oneeighth XK_threeeighths
                              \ XK_fiveeighths XK_seveneighths XK_trademark
                              \ XK_signaturemark XK_trademarkincircle
                              \ XK_leftopentriangle XK_rightopentriangle
                              \ XK_emopencircle XK_emopenrectangle
                              \ XK_leftsinglequotemark XK_rightsinglequotemark
                              \ XK_leftdoublequotemark XK_rightdoublequotemark
                              \ XK_prescription XK_minutes XK_seconds
                              \ XK_latincross XK_hexagram XK_filledrectbullet
                              \ XK_filledlefttribullet XK_filledrighttribullet
                              \ XK_emfilledcircle XK_emfilledrect
                              \ XK_enopencircbullet XK_enopensquarebullet
                              \ XK_openrectbullet XK_opentribulletup
                              \ XK_opentribulletdown XK_openstar
                              \ XK_enfilledcircbullet XK_enfilledsqbullet
                              \ XK_filledtribulletup XK_filledtribulletdown
                              \ XK_leftpointer XK_rightpointer XK_club
                              \ XK_diamond XK_heart XK_maltesecross
                              \ XK_dagger XK_doubledagger XK_checkmark
                              \ XK_ballotcross XK_musicalsharp XK_musicalflat
                              \ XK_malesymbol XK_femalesymbol XK_telephone
                              \ XK_telephonerecorder XK_phonographcopyright
                              \ XK_caret XK_singlelowquotemark
                              \ XK_doublelowquotemark XK_cursor
                              \ XK_leftcaret XK_rightcaret XK_downcaret
                              \ XK_upcaret XK_overbar XK_downtack XK_upshoe
                              \ XK_downstile XK_underbar XK_jot XK_quad
                              \ XK_uptack XK_circle XK_upstile XK_downshoe
                              \ XK_rightshoe XK_leftshoe XK_lefttack
                              \ XK_righttack XK_hebrew_doublelowline
                              \ XK_hebrew_aleph XK_hebrew_bet XK_hebrew_beth
                              \ XK_hebrew_gimel XK_hebrew_gimmel
                              \ XK_hebrew_dalet XK_hebrew_daleth
                              \ XK_hebrew_he XK_hebrew_waw XK_hebrew_zain
                              \ XK_hebrew_zayin XK_hebrew_chet XK_hebrew_het
                              \ XK_hebrew_tet XK_hebrew_teth XK_hebrew_yod
                              \ XK_hebrew_finalkaph XK_hebrew_kaph
                              \ XK_hebrew_lamed XK_hebrew_finalmem
                              \ XK_hebrew_mem XK_hebrew_finalnun XK_hebrew_nun
                              \ XK_hebrew_samech XK_hebrew_samekh
                              \ XK_hebrew_ayin XK_hebrew_finalpe XK_hebrew_pe
                              \ XK_hebrew_finalzade XK_hebrew_finalzadi
                              \ XK_hebrew_zade XK_hebrew_zadi XK_hebrew_qoph
                              \ XK_hebrew_kuf XK_hebrew_resh XK_hebrew_shin
                              \ XK_hebrew_taw XK_hebrew_taf XK_Hebrew_switch
                              \ XK_Thai_kokai XK_Thai_khokhai XK_Thai_khokhuat
                              \ XK_Thai_khokhwai XK_Thai_khokhon
                              \ XK_Thai_khorakhang XK_Thai_ngongu
                              \ XK_Thai_chochan XK_Thai_choching
                              \ XK_Thai_chochang XK_Thai_soso XK_Thai_chochoe
                              \ XK_Thai_yoying XK_Thai_dochada XK_Thai_topatak
                              \ XK_Thai_thothan XK_Thai_thonangmontho
                              \ XK_Thai_thophuthao XK_Thai_nonen
                              \ XK_Thai_dodek XK_Thai_totao XK_Thai_thothung
                              \ XK_Thai_thothahan XK_Thai_thothong
                              \ XK_Thai_nonu XK_Thai_bobaimai XK_Thai_popla
                              \ XK_Thai_phophung XK_Thai_fofa XK_Thai_phophan
                              \ XK_Thai_fofan XK_Thai_phosamphao XK_Thai_moma
                              \ XK_Thai_yoyak XK_Thai_rorua XK_Thai_ru
                              \ XK_Thai_loling XK_Thai_lu XK_Thai_wowaen
                              \ XK_Thai_sosala XK_Thai_sorusi XK_Thai_sosua
                              \ XK_Thai_hohip XK_Thai_lochula XK_Thai_oang
                              \ XK_Thai_honokhuk XK_Thai_paiyannoi
                              \ XK_Thai_saraa XK_Thai_maihanakat
                              \ XK_Thai_saraaa XK_Thai_saraam XK_Thai_sarai
                              \ XK_Thai_saraii XK_Thai_saraue XK_Thai_sarauee
                              \ XK_Thai_sarau XK_Thai_sarauu XK_Thai_phinthu
                              \ XK_Thai_maihanakat_maitho XK_Thai_baht
                              \ XK_Thai_sarae XK_Thai_saraae XK_Thai_sarao
                              \ XK_Thai_saraaimaimuan XK_Thai_saraaimaimalai
                              \ XK_Thai_lakkhangyao XK_Thai_maiyamok
                              \ XK_Thai_maitaikhu XK_Thai_maiek XK_Thai_maitho
                              \ XK_Thai_maitri XK_Thai_maichattawa
                              \ XK_Thai_thanthakhat XK_Thai_nikhahit
                              \ XK_Thai_leksun XK_Thai_leknung XK_Thai_leksong
                              \ XK_Thai_leksam XK_Thai_leksi XK_Thai_lekha
                              \ XK_Thai_lekhok XK_Thai_lekchet XK_Thai_lekpaet
                              \ XK_Thai_lekkao XK_Hangul XK_Hangul_Start
                              \ XK_Hangul_End XK_Hangul_Hanja XK_Hangul_Jamo
                              \ XK_Hangul_Romaja XK_Hangul_Codeinput
                              \ XK_Hangul_Jeonja XK_Hangul_Banja
                              \ XK_Hangul_PreHanja XK_Hangul_PostHanja
                              \ XK_Hangul_SingleCandidate
                              \ XK_Hangul_MultipleCandidate
                              \ XK_Hangul_PreviousCandidate XK_Hangul_Special
                              \ XK_Hangul_switch XK_Hangul_Kiyeog
                              \ XK_Hangul_SsangKiyeog XK_Hangul_KiyeogSios
                              \ XK_Hangul_Nieun XK_Hangul_NieunJieuj
                              \ XK_Hangul_NieunHieuh XK_Hangul_Dikeud
                              \ XK_Hangul_SsangDikeud XK_Hangul_Rieul
                              \ XK_Hangul_RieulKiyeog XK_Hangul_RieulMieum
                              \ XK_Hangul_RieulPieub XK_Hangul_RieulSios
                              \ XK_Hangul_RieulTieut XK_Hangul_RieulPhieuf
                              \ XK_Hangul_RieulHieuh XK_Hangul_Mieum
                              \ XK_Hangul_Pieub XK_Hangul_SsangPieub
                              \ XK_Hangul_PieubSios XK_Hangul_Sios
                              \ XK_Hangul_SsangSios XK_Hangul_Ieung
                              \ XK_Hangul_Jieuj XK_Hangul_SsangJieuj
                              \ XK_Hangul_Cieuc XK_Hangul_Khieuq
                              \ XK_Hangul_Tieut XK_Hangul_Phieuf
                              \ XK_Hangul_Hieuh XK_Hangul_A XK_Hangul_AE
                              \ XK_Hangul_YA XK_Hangul_YAE XK_Hangul_EO
                              \ XK_Hangul_E XK_Hangul_YEO XK_Hangul_YE
                              \ XK_Hangul_O XK_Hangul_WA XK_Hangul_WAE
                              \ XK_Hangul_OE XK_Hangul_YO XK_Hangul_U
                              \ XK_Hangul_WEO XK_Hangul_WE XK_Hangul_WI
                              \ XK_Hangul_YU XK_Hangul_EU XK_Hangul_YI
                              \ XK_Hangul_I XK_Hangul_J_Kiyeog
                              \ XK_Hangul_J_SsangKiyeog XK_Hangul_J_KiyeogSios
                              \ XK_Hangul_J_Nieun XK_Hangul_J_NieunJieuj
                              \ XK_Hangul_J_NieunHieuh XK_Hangul_J_Dikeud
                              \ XK_Hangul_J_Rieul XK_Hangul_J_RieulKiyeog
                              \ XK_Hangul_J_RieulMieum XK_Hangul_J_RieulPieub
                              \ XK_Hangul_J_RieulSios XK_Hangul_J_RieulTieut
                              \ XK_Hangul_J_RieulPhieuf XK_Hangul_J_RieulHieuh
                              \ XK_Hangul_J_Mieum XK_Hangul_J_Pieub
                              \ XK_Hangul_J_PieubSios XK_Hangul_J_Sios
                              \ XK_Hangul_J_SsangSios XK_Hangul_J_Ieung
                              \ XK_Hangul_J_Jieuj XK_Hangul_J_Cieuc
                              \ XK_Hangul_J_Khieuq XK_Hangul_J_Tieut
                              \ XK_Hangul_J_Phieuf XK_Hangul_J_Hieuh
                              \ XK_Hangul_RieulYeorinHieuh
                              \ XK_Hangul_SunkyeongeumMieum
                              \ XK_Hangul_SunkyeongeumPieub XK_Hangul_PanSios
                              \ XK_Hangul_KkogjiDalrinIeung
                              \ XK_Hangul_SunkyeongeumPhieuf
                              \ XK_Hangul_YeorinHieuh XK_Hangul_AraeA
                              \ XK_Hangul_AraeAE XK_Hangul_J_PanSios
                              \ XK_Hangul_J_KkogjiDalrinIeung
                              \ XK_Hangul_J_YeorinHieuh XK_Korean_Won
                              \ XK_Armenian_eternity XK_Armenian_ligature_ew
                              \ XK_Armenian_full_stop XK_Armenian_verjaket
                              \ XK_Armenian_parenright XK_Armenian_parenleft
                              \ XK_Armenian_guillemotright
                              \ XK_Armenian_guillemotleft XK_Armenian_em_dash
                              \ XK_Armenian_dot XK_Armenian_mijaket
                              \ XK_Armenian_separation_mark XK_Armenian_but
                              \ XK_Armenian_comma XK_Armenian_en_dash
                              \ XK_Armenian_hyphen XK_Armenian_yentamna
                              \ XK_Armenian_ellipsis XK_Armenian_exclam
                              \ XK_Armenian_amanak XK_Armenian_accent
                              \ XK_Armenian_shesht XK_Armenian_question
                              \ XK_Armenian_paruyk XK_Armenian_AYB
                              \ XK_Armenian_ayb XK_Armenian_BEN
                              \ XK_Armenian_ben XK_Armenian_GIM
                              \ XK_Armenian_gim XK_Armenian_DA XK_Armenian_da
                              \ XK_Armenian_YECH XK_Armenian_yech
                              \ XK_Armenian_ZA XK_Armenian_za XK_Armenian_E
                              \ XK_Armenian_e XK_Armenian_AT XK_Armenian_at
                              \ XK_Armenian_TO XK_Armenian_to
                              \ XK_Armenian_ZHE XK_Armenian_zhe
                              \ XK_Armenian_INI XK_Armenian_ini
                              \ XK_Armenian_LYUN XK_Armenian_lyun
                              \ XK_Armenian_KHE XK_Armenian_khe
                              \ XK_Armenian_TSA XK_Armenian_tsa
                              \ XK_Armenian_KEN XK_Armenian_ken XK_Armenian_HO
                              \ XK_Armenian_ho XK_Armenian_DZA XK_Armenian_dza
                              \ XK_Armenian_GHAT XK_Armenian_ghat
                              \ XK_Armenian_TCHE XK_Armenian_tche
                              \ XK_Armenian_MEN XK_Armenian_men XK_Armenian_HI
                              \ XK_Armenian_hi XK_Armenian_NU XK_Armenian_nu
                              \ XK_Armenian_SHA XK_Armenian_sha XK_Armenian_VO
                              \ XK_Armenian_vo XK_Armenian_CHA XK_Armenian_cha
                              \ XK_Armenian_PE XK_Armenian_pe XK_Armenian_JE
                              \ XK_Armenian_je XK_Armenian_RA XK_Armenian_ra
                              \ XK_Armenian_SE XK_Armenian_se XK_Armenian_VEV
                              \ XK_Armenian_vev XK_Armenian_TYUN
                              \ XK_Armenian_tyun XK_Armenian_RE
                              \ XK_Armenian_re XK_Armenian_TSO
                              \ XK_Armenian_tso XK_Armenian_VYUN
                              \ XK_Armenian_vyun XK_Armenian_PYUR
                              \ XK_Armenian_pyur XK_Armenian_KE XK_Armenian_ke
                              \ XK_Armenian_O XK_Armenian_o XK_Armenian_FE
                              \ XK_Armenian_fe XK_Armenian_apostrophe
                              \ XK_Armenian_section_sign XK_Georgian_an
                              \ XK_Georgian_ban XK_Georgian_gan
                              \ XK_Georgian_don XK_Georgian_en XK_Georgian_vin
                              \ XK_Georgian_zen XK_Georgian_tan
                              \ XK_Georgian_in XK_Georgian_kan XK_Georgian_las
                              \ XK_Georgian_man XK_Georgian_nar XK_Georgian_on
                              \ XK_Georgian_par XK_Georgian_zhar
                              \ XK_Georgian_rae XK_Georgian_san
                              \ XK_Georgian_tar XK_Georgian_un
                              \ XK_Georgian_phar XK_Georgian_khar
                              \ XK_Georgian_ghan XK_Georgian_qar
                              \ XK_Georgian_shin XK_Georgian_chin
                              \ XK_Georgian_can XK_Georgian_jil
                              \ XK_Georgian_cil XK_Georgian_char
                              \ XK_Georgian_xan XK_Georgian_jhan
                              \ XK_Georgian_hae XK_Georgian_he XK_Georgian_hie
                              \ XK_Georgian_we XK_Georgian_har XK_Georgian_hoe
                              \ XK_Georgian_fi XK_Ccedillaabovedot
                              \ XK_Xabovedot XK_Qabovedot XK_IE XK_UO
                              \ XK_Zstroke XK_ccedillaabovedot XK_xabovedot
                              \ XK_qabovedot XK_ie XK_uo XK_zstroke XK_SCHWA
                              \ XK_schwa XK_Lbelowdot XK_Lstrokebelowdot
                              \ XK_lbelowdot XK_lstrokebelowdot XK_Gtilde
                              \ XK_gtilde XK_Abelowdot XK_abelowdot
                              \ XK_Ahook XK_ahook XK_Acircumflexacute
                              \ XK_acircumflexacute XK_Acircumflexgrave
                              \ XK_acircumflexgrave XK_Acircumflexhook
                              \ XK_acircumflexhook XK_Acircumflextilde
                              \ XK_acircumflextilde XK_Acircumflexbelowdot
                              \ XK_acircumflexbelowdot XK_Abreveacute
                              \ XK_abreveacute XK_Abrevegrave XK_abrevegrave
                              \ XK_Abrevehook XK_abrevehook XK_Abrevetilde
                              \ XK_abrevetilde XK_Abrevebelowdot
                              \ XK_abrevebelowdot XK_Ebelowdot XK_ebelowdot
                              \ XK_Ehook XK_ehook XK_Etilde XK_etilde
                              \ XK_Ecircumflexacute XK_ecircumflexacute
                              \ XK_Ecircumflexgrave XK_ecircumflexgrave
                              \ XK_Ecircumflexhook XK_ecircumflexhook
                              \ XK_Ecircumflextilde XK_ecircumflextilde
                              \ XK_Ecircumflexbelowdot XK_ecircumflexbelowdot
                              \ XK_Ihook XK_ihook XK_Ibelowdot XK_ibelowdot
                              \ XK_Obelowdot XK_obelowdot XK_Ohook XK_ohook
                              \ XK_Ocircumflexacute XK_ocircumflexacute
                              \ XK_Ocircumflexgrave XK_ocircumflexgrave
                              \ XK_Ocircumflexhook XK_ocircumflexhook
                              \ XK_Ocircumflextilde XK_ocircumflextilde
                              \ XK_Ocircumflexbelowdot XK_ocircumflexbelowdot
                              \ XK_Ohornacute XK_ohornacute XK_Ohorngrave
                              \ XK_ohorngrave XK_Ohornhook XK_ohornhook
                              \ XK_Ohorntilde XK_ohorntilde XK_Ohornbelowdot
                              \ XK_ohornbelowdot XK_Ubelowdot XK_ubelowdot
                              \ XK_Uhook XK_uhook XK_Uhornacute XK_uhornacute
                              \ XK_Uhorngrave XK_uhorngrave XK_Uhornhook
                              \ XK_uhornhook XK_Uhorntilde XK_uhorntilde
                              \ XK_Uhornbelowdot XK_uhornbelowdot XK_Ybelowdot
                              \ XK_ybelowdot XK_Yhook XK_yhook XK_Ytilde
                              \ XK_ytilde XK_Ohorn XK_ohorn XK_Uhorn XK_uhorn
                              \ XK_combining_tilde XK_combining_grave
                              \ XK_combining_acute XK_combining_hook
                              \ XK_combining_belowdot XK_EcuSign XK_ColonSign
                              \ XK_CruzeiroSign XK_FFrancSign XK_LiraSign
                              \ XK_MillSign XK_NairaSign XK_PesetaSign
                              \ XK_RupeeSign XK_WonSign XK_NewSheqelSign
                              \ XK_DongSign XK_EuroSign

" #include <X11/Sunkeysym.h>
syn keyword xmodmapKeySym     SunXK_Sys_Req SunXK_Print_Screen SunXK_Compose
                              \ SunXK_AltGraph SunXK_PageUp SunXK_PageDown
                              \ SunXK_Undo SunXK_Again SunXK_Find SunXK_Stop
                              \ SunXK_Props SunXK_Front SunXK_Copy SunXK_Open
                              \ SunXK_Paste SunXK_Cut SunXK_PowerSwitch
                              \ SunXK_AudioLowerVolume SunXK_AudioMute
                              \ SunXK_AudioRaiseVolume SunXK_VideoDegauss
                              \ SunXK_VideoLowerBrightness
                              \ SunXK_VideoRaiseBrightness
                              \ SunXK_PowerSwitchShift

" #include <X11/XF86keysym.h>
syn keyword xmodmapKeySym     XF86XK_ModeLock XF86XK_Standby
                              \ XF86XK_AudioLowerVolume XF86XK_AudioMute
                              \ XF86XK_AudioRaiseVolume XF86XK_AudioPlay
                              \ XF86XK_AudioStop XF86XK_AudioPrev
                              \ XF86XK_AudioNext XF86XK_HomePage
                              \ XF86XK_Mail XF86XK_Start XF86XK_Search
                              \ XF86XK_AudioRecord XF86XK_Calculator
                              \ XF86XK_Memo XF86XK_ToDoList XF86XK_Calendar
                              \ XF86XK_PowerDown XF86XK_ContrastAdjust
                              \ XF86XK_RockerUp XF86XK_RockerDown
                              \ XF86XK_RockerEnter XF86XK_Back XF86XK_Forward
                              \ XF86XK_Stop XF86XK_Refresh XF86XK_PowerOff
                              \ XF86XK_WakeUp XF86XK_Eject XF86XK_ScreenSaver
                              \ XF86XK_WWW XF86XK_Sleep XF86XK_Favorites
                              \ XF86XK_AudioPause XF86XK_AudioMedia
                              \ XF86XK_MyComputer XF86XK_VendorHome
                              \ XF86XK_LightBulb XF86XK_Shop XF86XK_History
                              \ XF86XK_OpenURL XF86XK_AddFavorite
                              \ XF86XK_HotLinks XF86XK_BrightnessAdjust
                              \ XF86XK_Finance XF86XK_Community
                              \ XF86XK_AudioRewind XF86XK_XF86BackForward
                              \ XF86XK_Launch0 XF86XK_Launch1 XF86XK_Launch2
                              \ XF86XK_Launch3 XF86XK_Launch4 XF86XK_Launch5
                              \ XF86XK_Launch6 XF86XK_Launch7 XF86XK_Launch8
                              \ XF86XK_Launch9 XF86XK_LaunchA XF86XK_LaunchB
                              \ XF86XK_LaunchC XF86XK_LaunchD XF86XK_LaunchE
                              \ XF86XK_LaunchF XF86XK_ApplicationLeft
                              \ XF86XK_ApplicationRight XF86XK_Book
                              \ XF86XK_CD XF86XK_Calculater XF86XK_Clear
                              \ XF86XK_Close XF86XK_Copy XF86XK_Cut
                              \ XF86XK_Display XF86XK_DOS XF86XK_Documents
                              \ XF86XK_Excel XF86XK_Explorer XF86XK_Game
                              \ XF86XK_Go XF86XK_iTouch XF86XK_LogOff
                              \ XF86XK_Market XF86XK_Meeting XF86XK_MenuKB
                              \ XF86XK_MenuPB XF86XK_MySites XF86XK_New
                              \ XF86XK_News XF86XK_OfficeHome XF86XK_Open
                              \ XF86XK_Option XF86XK_Paste XF86XK_Phone
                              \ XF86XK_Q XF86XK_Reply XF86XK_Reload
                              \ XF86XK_RotateWindows XF86XK_RotationPB
                              \ XF86XK_RotationKB XF86XK_Save XF86XK_ScrollUp
                              \ XF86XK_ScrollDown XF86XK_ScrollClick
                              \ XF86XK_Send XF86XK_Spell XF86XK_SplitScreen
                              \ XF86XK_Support XF86XK_TaskPane XF86XK_Terminal
                              \ XF86XK_Tools XF86XK_Travel XF86XK_UserPB
                              \ XF86XK_User1KB XF86XK_User2KB XF86XK_Video
                              \ XF86XK_WheelButton XF86XK_Word XF86XK_Xfer
                              \ XF86XK_ZoomIn XF86XK_ZoomOut XF86XK_Away
                              \ XF86XK_Messenger XF86XK_WebCam
                              \ XF86XK_MailForward XF86XK_Pictures
                              \ XF86XK_Music XF86XK_Switch_VT_1
                              \ XF86XK_Switch_VT_2 XF86XK_Switch_VT_3
                              \ XF86XK_Switch_VT_4 XF86XK_Switch_VT_5
                              \ XF86XK_Switch_VT_6 XF86XK_Switch_VT_7
                              \ XF86XK_Switch_VT_8 XF86XK_Switch_VT_9
                              \ XF86XK_Switch_VT_10 XF86XK_Switch_VT_11
                              \ XF86XK_Switch_VT_12 XF86XK_Ungrab
                              \ XF86XK_ClearGrab XF86XK_Next_VMode
                              \ XF86XK_Prev_VMode

syn keyword xmodmapKeyword    keycode keysym clear add remove pointer

hi def link xmodmapComment    Comment
hi def link xmodmapTodo       Todo
hi def link xmodmapInt        Number
hi def link xmodmapHex        Number
hi def link xmodmapOctal      Number
hi def link xmodmapOctalError Error
hi def link xmodmapKeySym     Constant
hi def link xmodmapKeyword    Keyword

let b:current_syntax = "xmodmap"

let &cpo = s:cpo_save
unlet s:cpo_save
