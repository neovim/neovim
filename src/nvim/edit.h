#ifndef NVIM_EDIT_H
#define NVIM_EDIT_H

#include "nvim/vim.h"

/*
 * Array indexes used for cptext argument of ins_compl_add().
 */
#define CPT_ABBR        0   // "abbr"
#define CPT_MENU        1   // "menu"
#define CPT_KIND        2   // "kind"
#define CPT_INFO        3   // "info"
#define CPT_USER_DATA   4   // "user data"
#define CPT_COUNT       5   // Number of entries

/*
 * Structure used to store one match for insert completion.
 */
typedef struct compl_S compl_T;
struct compl_S {
  compl_T     *cp_next;
  compl_T     *cp_prev;
  char_u      *cp_str;          /* matched text */
  char cp_icase;                /* TRUE or FALSE: ignore case */
  char_u      *(cp_text[CPT_COUNT]);    /* text for the menu */
  char_u      *cp_fname;        /* file containing the match, allocated when
                                 * cp_flags has FREE_FNAME */
  int cp_flags;                 /* ORIGINAL_TEXT, CONT_S_IPOS or FREE_FNAME */
  int cp_number;                /* sequence number */
};

#define ORIGINAL_TEXT   (1)   /* the original text when the expansion begun */
#define FREE_FNAME      (2)

typedef int (*IndentGetter)(void);

/* Values for in_cinkeys() */
#define KEY_OPEN_FORW   0x101
#define KEY_OPEN_BACK   0x102
#define KEY_COMPLETE    0x103   /* end of completion */

/* Values for change_indent() */
#define INDENT_SET      1       /* set indent */
#define INDENT_INC      2       /* increase indent */
#define INDENT_DEC      3       /* decrease indent */

/* flags for beginline() */
#define BL_WHITE        1       /* cursor on first non-white in the line */
#define BL_SOL          2       /* use 'sol' option */
#define BL_FIX          4       /* don't leave cursor on a NUL */

/* flags for insertchar() */
#define INSCHAR_FORMAT  1       /* force formatting */
#define INSCHAR_DO_COM  2       /* format comments */
#define INSCHAR_CTRLV   4       /* char typed just after CTRL-V */
#define INSCHAR_NO_FEX  8       /* don't use 'formatexpr' */
#define INSCHAR_COM_LIST 16     /* format comments with list/2nd line indent */

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "edit.h.generated.h"
#endif
#endif  // NVIM_EDIT_H
