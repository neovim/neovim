/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved    by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

#ifndef SRC_ARABIC_H_
#define SRC_ARABIC_H_

/*
 * Arabic characters are categorized into following types:
 *
 * Isolated	- iso-8859-6 form	  char denoted with	a_*
 * Initial	- unicode form-B start	  char denoted with	a_i_*
 * Medial	- unicode form-B middle   char denoted with	a_m_*
 * Final	- unicode form-B final	  char denoted with	a_f_*
 * Stand-Alone	- unicode form-B isolated char denoted with	a_s_* (NOT USED)
 *
 * --
 *
 * Author: Nadim Shaikli & Isam Bayazidi
 * - (based on Unicode)
 *
 */

/*
 * Arabic ISO-10646-1 character set definition
 */

/*
 * Arabic ISO-8859-6 (subset of 10646; 0600 - 06FF)
 */
#define a_COMMA                         0x060C
#define a_SEMICOLON                     0x061B
#define a_QUESTION                      0x061F
#define a_HAMZA                         0x0621
#define a_ALEF_MADDA                    0x0622
#define a_ALEF_HAMZA_ABOVE              0x0623
#define a_WAW_HAMZA                     0x0624
#define a_ALEF_HAMZA_BELOW              0x0625
#define a_YEH_HAMZA                     0x0626
#define a_ALEF                          0x0627
#define a_BEH                           0x0628
#define a_TEH_MARBUTA                   0x0629
#define a_TEH                           0x062a
#define a_THEH                          0x062b
#define a_JEEM                          0x062c
#define a_HAH                           0x062d
#define a_KHAH                          0x062e
#define a_DAL                           0x062f
#define a_THAL                          0x0630
#define a_REH                           0x0631
#define a_ZAIN                          0x0632
#define a_SEEN                          0x0633
#define a_SHEEN                         0x0634
#define a_SAD                           0x0635
#define a_DAD                           0x0636
#define a_TAH                           0x0637
#define a_ZAH                           0x0638
#define a_AIN                           0x0639
#define a_GHAIN                         0x063a
#define a_TATWEEL                       0x0640
#define a_FEH                           0x0641
#define a_QAF                           0x0642
#define a_KAF                           0x0643
#define a_LAM                           0x0644
#define a_MEEM                          0x0645
#define a_NOON                          0x0646
#define a_HEH                           0x0647
#define a_WAW                           0x0648
#define a_ALEF_MAKSURA                  0x0649
#define a_YEH                           0x064a

#define a_FATHATAN                      0x064b
#define a_DAMMATAN                      0x064c
#define a_KASRATAN                      0x064d
#define a_FATHA                         0x064e
#define a_DAMMA                         0x064f
#define a_KASRA                         0x0650
#define a_SHADDA                        0x0651
#define a_SUKUN                         0x0652

#define a_MADDA_ABOVE                   0x0653
#define a_HAMZA_ABOVE                   0x0654
#define a_HAMZA_BELOW                   0x0655

#define a_ZERO                          0x0660
#define a_ONE                           0x0661
#define a_TWO                           0x0662
#define a_THREE                         0x0663
#define a_FOUR                          0x0664
#define a_FIVE                          0x0665
#define a_SIX                           0x0666
#define a_SEVEN                         0x0667
#define a_EIGHT                         0x0668
#define a_NINE                          0x0669
#define a_PERCENT                       0x066a
#define a_DECIMAL                       0x066b
#define a_THOUSANDS                     0x066c
#define a_STAR                          0x066d
#define a_MINI_ALEF                     0x0670
/* Rest of 8859-6 does not relate to Arabic */

/*
 * Arabic Presentation Form-B (subset of 10646; FE70 - FEFF)
 *
 *  s -> isolated
 *  i -> initial
 *  m -> medial
 *  f -> final
 *
 */
#define a_s_FATHATAN                    0xfe70
#define a_m_TATWEEL_FATHATAN            0xfe71
#define a_s_DAMMATAN                    0xfe72

#define a_s_KASRATAN                    0xfe74

#define a_s_FATHA                       0xfe76
#define a_m_FATHA                       0xfe77
#define a_s_DAMMA                       0xfe78
#define a_m_DAMMA                       0xfe79
#define a_s_KASRA                       0xfe7a
#define a_m_KASRA                       0xfe7b
#define a_s_SHADDA                      0xfe7c
#define a_m_SHADDA                      0xfe7d
#define a_s_SUKUN                       0xfe7e
#define a_m_SUKUN                       0xfe7f

#define a_s_HAMZA                       0xfe80
#define a_s_ALEF_MADDA                  0xfe81
#define a_f_ALEF_MADDA                  0xfe82
#define a_s_ALEF_HAMZA_ABOVE            0xfe83
#define a_f_ALEF_HAMZA_ABOVE            0xfe84
#define a_s_WAW_HAMZA                   0xfe85
#define a_f_WAW_HAMZA                   0xfe86
#define a_s_ALEF_HAMZA_BELOW            0xfe87
#define a_f_ALEF_HAMZA_BELOW            0xfe88
#define a_s_YEH_HAMZA                   0xfe89
#define a_f_YEH_HAMZA                   0xfe8a
#define a_i_YEH_HAMZA                   0xfe8b
#define a_m_YEH_HAMZA                   0xfe8c
#define a_s_ALEF                        0xfe8d
#define a_f_ALEF                        0xfe8e
#define a_s_BEH                         0xfe8f
#define a_f_BEH                         0xfe90
#define a_i_BEH                         0xfe91
#define a_m_BEH                         0xfe92
#define a_s_TEH_MARBUTA                 0xfe93
#define a_f_TEH_MARBUTA                 0xfe94
#define a_s_TEH                         0xfe95
#define a_f_TEH                         0xfe96
#define a_i_TEH                         0xfe97
#define a_m_TEH                         0xfe98
#define a_s_THEH                        0xfe99
#define a_f_THEH                        0xfe9a
#define a_i_THEH                        0xfe9b
#define a_m_THEH                        0xfe9c
#define a_s_JEEM                        0xfe9d
#define a_f_JEEM                        0xfe9e
#define a_i_JEEM                        0xfe9f
#define a_m_JEEM                        0xfea0
#define a_s_HAH                         0xfea1
#define a_f_HAH                         0xfea2
#define a_i_HAH                         0xfea3
#define a_m_HAH                         0xfea4
#define a_s_KHAH                        0xfea5
#define a_f_KHAH                        0xfea6
#define a_i_KHAH                        0xfea7
#define a_m_KHAH                        0xfea8
#define a_s_DAL                         0xfea9
#define a_f_DAL                         0xfeaa
#define a_s_THAL                        0xfeab
#define a_f_THAL                        0xfeac
#define a_s_REH                         0xfead
#define a_f_REH                         0xfeae
#define a_s_ZAIN                        0xfeaf
#define a_f_ZAIN                        0xfeb0
#define a_s_SEEN                        0xfeb1
#define a_f_SEEN                        0xfeb2
#define a_i_SEEN                        0xfeb3
#define a_m_SEEN                        0xfeb4
#define a_s_SHEEN                       0xfeb5
#define a_f_SHEEN                       0xfeb6
#define a_i_SHEEN                       0xfeb7
#define a_m_SHEEN                       0xfeb8
#define a_s_SAD                         0xfeb9
#define a_f_SAD                         0xfeba
#define a_i_SAD                         0xfebb
#define a_m_SAD                         0xfebc
#define a_s_DAD                         0xfebd
#define a_f_DAD                         0xfebe
#define a_i_DAD                         0xfebf
#define a_m_DAD                         0xfec0
#define a_s_TAH                         0xfec1
#define a_f_TAH                         0xfec2
#define a_i_TAH                         0xfec3
#define a_m_TAH                         0xfec4
#define a_s_ZAH                         0xfec5
#define a_f_ZAH                         0xfec6
#define a_i_ZAH                         0xfec7
#define a_m_ZAH                         0xfec8
#define a_s_AIN                         0xfec9
#define a_f_AIN                         0xfeca
#define a_i_AIN                         0xfecb
#define a_m_AIN                         0xfecc
#define a_s_GHAIN                       0xfecd
#define a_f_GHAIN                       0xfece
#define a_i_GHAIN                       0xfecf
#define a_m_GHAIN                       0xfed0
#define a_s_FEH                         0xfed1
#define a_f_FEH                         0xfed2
#define a_i_FEH                         0xfed3
#define a_m_FEH                         0xfed4
#define a_s_QAF                         0xfed5
#define a_f_QAF                         0xfed6
#define a_i_QAF                         0xfed7
#define a_m_QAF                         0xfed8
#define a_s_KAF                         0xfed9
#define a_f_KAF                         0xfeda
#define a_i_KAF                         0xfedb
#define a_m_KAF                         0xfedc
#define a_s_LAM                         0xfedd
#define a_f_LAM                         0xfede
#define a_i_LAM                         0xfedf
#define a_m_LAM                         0xfee0
#define a_s_MEEM                        0xfee1
#define a_f_MEEM                        0xfee2
#define a_i_MEEM                        0xfee3
#define a_m_MEEM                        0xfee4
#define a_s_NOON                        0xfee5
#define a_f_NOON                        0xfee6
#define a_i_NOON                        0xfee7
#define a_m_NOON                        0xfee8
#define a_s_HEH                         0xfee9
#define a_f_HEH                         0xfeea
#define a_i_HEH                         0xfeeb
#define a_m_HEH                         0xfeec
#define a_s_WAW                         0xfeed
#define a_f_WAW                         0xfeee
#define a_s_ALEF_MAKSURA                0xfeef
#define a_f_ALEF_MAKSURA                0xfef0
#define a_s_YEH                         0xfef1
#define a_f_YEH                         0xfef2
#define a_i_YEH                         0xfef3
#define a_m_YEH                         0xfef4
#define a_s_LAM_ALEF_MADDA_ABOVE        0xfef5
#define a_f_LAM_ALEF_MADDA_ABOVE        0xfef6
#define a_s_LAM_ALEF_HAMZA_ABOVE        0xfef7
#define a_f_LAM_ALEF_HAMZA_ABOVE        0xfef8
#define a_s_LAM_ALEF_HAMZA_BELOW        0xfef9
#define a_f_LAM_ALEF_HAMZA_BELOW        0xfefa
#define a_s_LAM_ALEF                    0xfefb
#define a_f_LAM_ALEF                    0xfefc

#define a_BYTE_ORDER_MARK               0xfeff

/* Range of Arabic characters that might be shaped. */
#define ARABIC_CHAR(c)          ((c) >= a_HAMZA && (c) <= a_MINI_ALEF)

#endif  // SRC_ARABIC_H_
