#ifndef NVIM_REGEXP_H
#define NVIM_REGEXP_H

/* Second argument for vim_regcomp(). */
#define RE_MAGIC        1       /* 'magic' option */
#define RE_STRING       2       /* match in string instead of buffer text */
#define RE_STRICT       4       /* don't allow [abc] without ] */

/* values for reg_do_extmatch */
#define REX_SET        1       /* to allow \z\(...\), */
#define REX_USE        2       /* to allow \z\1 et al. */

/* regexp.c */
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "regexp.h.generated.h"
#endif

#endif /* NVIM_REGEXP_H */
