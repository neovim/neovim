#ifndef NVIM_ARABIC_H
#define NVIM_ARABIC_H

#include <stdbool.h>

#include "nvim/func_attr.h"

// Arabic ISO-8859-6 (subset of 10646; 0600 - 06FF)
#define a_COMMA                     0x060C
#define a_SEMICOLON                 0x061B
#define a_QUESTION                  0x061F
#define a_HAMZA                     0x0621
#define a_ALEF_MADDA                0x0622
#define a_ALEF_HAMZA_ABOVE          0x0623
#define a_WAW_HAMZA                 0x0624
#define a_ALEF_HAMZA_BELOW          0x0625
#define a_YEH_HAMZA                 0x0626
#define a_ALEF                      0x0627
#define a_BEH                       0x0628
#define a_TEH_MARBUTA               0x0629
#define a_TEH                       0x062a
#define a_THEH                      0x062b
#define a_JEEM                      0x062c
#define a_HAH                       0x062d
#define a_KHAH                      0x062e
#define a_DAL                       0x062f
#define a_THAL                      0x0630
#define a_REH                       0x0631
#define a_ZAIN                      0x0632
#define a_SEEN                      0x0633
#define a_SHEEN                     0x0634
#define a_SAD                       0x0635
#define a_DAD                       0x0636
#define a_TAH                       0x0637
#define a_ZAH                       0x0638
#define a_AIN                       0x0639
#define a_GHAIN                     0x063a
#define a_TATWEEL                   0x0640
#define a_FEH                       0x0641
#define a_QAF                       0x0642
#define a_KAF                       0x0643
#define a_LAM                       0x0644
#define a_MEEM                      0x0645
#define a_NOON                      0x0646
#define a_HEH                       0x0647
#define a_WAW                       0x0648
#define a_ALEF_MAKSURA              0x0649
#define a_YEH                       0x064a

#define a_FATHATAN                  0x064b
#define a_DAMMATAN                  0x064c
#define a_KASRATAN                  0x064d
#define a_FATHA                     0x064e
#define a_DAMMA                     0x064f
#define a_KASRA                     0x0650
#define a_SHADDA                    0x0651
#define a_SUKUN                     0x0652

#define a_MADDA_ABOVE               0x0653
#define a_HAMZA_ABOVE               0x0654
#define a_HAMZA_BELOW               0x0655

#define a_ZERO                      0x0660
#define a_ONE                       0x0661
#define a_TWO                       0x0662
#define a_THREE                     0x0663
#define a_FOUR                      0x0664
#define a_FIVE                      0x0665
#define a_SIX                       0x0666
#define a_SEVEN                     0x0667
#define a_EIGHT                     0x0668
#define a_NINE                      0x0669
#define a_PERCENT                   0x066a
#define a_DECIMAL                   0x066b
#define a_THOUSANDS                 0x066c
#define a_STAR                      0x066d
#define a_MINI_ALEF                 0x0670
// Rest of 8859-6 does not relate to Arabic

static inline bool arabic_char(int c)
  REAL_FATTR_CONST REAL_FATTR_ALWAYS_INLINE;

/// Whether c belongs to the range of Arabic characters that might be shaped.
static inline bool arabic_char(int c)
{
    return c >= a_HAMZA && c <= a_MINI_ALEF;
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "arabic.h.generated.h"
#endif
#endif  // NVIM_ARABIC_H
