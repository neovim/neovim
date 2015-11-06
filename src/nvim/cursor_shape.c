#include <assert.h>
#include <stdint.h>
#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/cursor_shape.h"
#include "nvim/misc2.h"
#include "nvim/ex_getln.h"
#include "nvim/charset.h"
#include "nvim/strings.h"
#include "nvim/syntax.h"

/*
 * Handling of cursor and mouse pointer shapes in various modes.
 */

static cursorentry_T shape_table[SHAPE_IDX_COUNT] =
{
  /* The values will be filled in from the 'guicursor' and 'mouseshape'
   * defaults when Vim starts.
   * Adjust the SHAPE_IDX_ defines when making changes! */
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "n", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "v", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "i", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "r", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "c", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "ci", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "cr", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "o", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0, 700L, 400L, 250L, 0, 0, "ve", SHAPE_CURSOR+SHAPE_MOUSE},
  {0, 0, 0,   0L,   0L,   0L, 0, 0, "e", SHAPE_MOUSE},
  {0, 0, 0,   0L,   0L,   0L, 0, 0, "s", SHAPE_MOUSE},
  {0, 0, 0,   0L,   0L,   0L, 0, 0, "sd", SHAPE_MOUSE},
  {0, 0, 0,   0L,   0L,   0L, 0, 0, "vs", SHAPE_MOUSE},
  {0, 0, 0,   0L,   0L,   0L, 0, 0, "vd", SHAPE_MOUSE},
  {0, 0, 0,   0L,   0L,   0L, 0, 0, "m", SHAPE_MOUSE},
  {0, 0, 0,   0L,   0L,   0L, 0, 0, "ml", SHAPE_MOUSE},
  {0, 0, 0, 100L, 100L, 100L, 0, 0, "sm", SHAPE_CURSOR},
};

/*
 * Parse the 'guicursor' option ("what" is SHAPE_CURSOR) or 'mouseshape'
 * ("what" is SHAPE_MOUSE).
 * Returns error message for an illegal option, NULL otherwise.
 */
char_u *parse_shape_opt(int what)
{
  char_u      *modep;
  char_u      *colonp;
  char_u      *commap;
  char_u      *slashp;
  char_u      *p, *endp;
  int idx = 0;                          /* init for GCC */
  int all_idx;
  int len;
  int i;
  int found_ve = false;                 /* found "ve" flag */
  int round;

  /*
   * First round: check for errors; second round: do it for real.
   */
  for (round = 1; round <= 2; ++round) {
    /*
     * Repeat for all comma separated parts.
     */
    modep = p_guicursor;
    while (*modep != NUL) {
      colonp = vim_strchr(modep, ':');
      if (colonp == NULL)
        return (char_u *)N_("E545: Missing colon");
      if (colonp == modep)
        return (char_u *)N_("E546: Illegal mode");
      commap = vim_strchr(modep, ',');

      /*
       * Repeat for all mode's before the colon.
       * For the 'a' mode, we loop to handle all the modes.
       */
      all_idx = -1;
      assert(modep < colonp);
      while (modep < colonp || all_idx >= 0) {
        if (all_idx < 0) {
          /* Find the mode. */
          if (modep[1] == '-' || modep[1] == ':')
            len = 1;
          else
            len = 2;

          if (len == 1 && TOLOWER_ASC(modep[0]) == 'a') {
            all_idx = SHAPE_IDX_COUNT - 1;
          } else {
            for (idx = 0; idx < SHAPE_IDX_COUNT; ++idx)
              if (STRNICMP(modep, shape_table[idx].name, len) == 0)
                break;
            if (idx == SHAPE_IDX_COUNT
                    || (shape_table[idx].used_for & what) == 0)
              return (char_u *)N_("E546: Illegal mode");
            if (len == 2 && modep[0] == 'v' && modep[1] == 'e')
              found_ve = true;
          }
          modep += len + 1;
        }

        if (all_idx >= 0)
          idx = all_idx--;
        else if (round == 2) {
          {
            /* Set the defaults, for the missing parts */
            shape_table[idx].shape = SHAPE_BLOCK;
            shape_table[idx].blinkwait = 700L;
            shape_table[idx].blinkon = 400L;
            shape_table[idx].blinkoff = 250L;
          }
        }

        /* Parse the part after the colon */
        for (p = colonp + 1; *p && *p != ','; ) {
          {
            /*
             * First handle the ones with a number argument.
             */
            i = *p;
            len = 0;
            if (STRNICMP(p, "ver", 3) == 0)
              len = 3;
            else if (STRNICMP(p, "hor", 3) == 0)
              len = 3;
            else if (STRNICMP(p, "blinkwait", 9) == 0)
              len = 9;
            else if (STRNICMP(p, "blinkon", 7) == 0)
              len = 7;
            else if (STRNICMP(p, "blinkoff", 8) == 0)
              len = 8;
            if (len != 0) {
              p += len;
              if (!ascii_isdigit(*p))
                return (char_u *)N_("E548: digit expected");
              int n = getdigits_int(&p);
              if (len == 3) {               /* "ver" or "hor" */
                if (n == 0)
                  return (char_u *)N_("E549: Illegal percentage");
                if (round == 2) {
                  if (TOLOWER_ASC(i) == 'v')
                    shape_table[idx].shape = SHAPE_VER;
                  else
                    shape_table[idx].shape = SHAPE_HOR;
                  shape_table[idx].percentage = n;
                }
              } else if (round == 2) {
                if (len == 9)
                  shape_table[idx].blinkwait = n;
                else if (len == 7)
                  shape_table[idx].blinkon = n;
                else
                  shape_table[idx].blinkoff = n;
              }
            } else if (STRNICMP(p, "block", 5) == 0) {
              if (round == 2)
                shape_table[idx].shape = SHAPE_BLOCK;
              p += 5;
            } else {          /* must be a highlight group name then */
              endp = vim_strchr(p, '-');
              if (commap == NULL) {                       /* last part */
                if (endp == NULL)
                  endp = p + STRLEN(p);                  /* find end of part */
              } else if (endp > commap || endp == NULL) {
                endp = commap;
              }
              slashp = vim_strchr(p, '/');
              if (slashp != NULL && slashp < endp) {
                /* "group/langmap_group" */
                i = syn_check_group(p, (int)(slashp - p));
                p = slashp + 1;
              }
              if (round == 2) {
                shape_table[idx].id = syn_check_group(p,
                    (int)(endp - p));
                shape_table[idx].id_lm = shape_table[idx].id;
                if (slashp != NULL && slashp < endp)
                  shape_table[idx].id = i;
              }
              p = endp;
            }
          }           /* if (what != SHAPE_MOUSE) */

          if (*p == '-')
            ++p;
        }
      }
      modep = p;
      if (*modep == ',')
        ++modep;
    }
  }

  /* If the 's' flag is not given, use the 'v' cursor for 's' */
  if (!found_ve) {
    {
      shape_table[SHAPE_IDX_VE].shape = shape_table[SHAPE_IDX_V].shape;
      shape_table[SHAPE_IDX_VE].percentage =
        shape_table[SHAPE_IDX_V].percentage;
      shape_table[SHAPE_IDX_VE].blinkwait =
        shape_table[SHAPE_IDX_V].blinkwait;
      shape_table[SHAPE_IDX_VE].blinkon =
        shape_table[SHAPE_IDX_V].blinkon;
      shape_table[SHAPE_IDX_VE].blinkoff =
        shape_table[SHAPE_IDX_V].blinkoff;
      shape_table[SHAPE_IDX_VE].id = shape_table[SHAPE_IDX_V].id;
      shape_table[SHAPE_IDX_VE].id_lm = shape_table[SHAPE_IDX_V].id_lm;
    }
  }

  return NULL;
}
