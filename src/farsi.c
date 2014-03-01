/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 */

#include "farsi.h"
#include "edit.h"
#include "ex_getln.h"

/*
 * farsi.c: functions for Farsi language
 *
 * Included by main.c, when FEAT_FKMAP is defined.
 */

static int toF_Xor_X_(int c);
static int F_is_TyE(int c);
static int F_is_TyC_TyD(int c);
static int F_is_TyB_TyC_TyD(int src, int offset);
static int toF_TyB(int c);
static void put_curr_and_l_to_X(int c);
static void put_and_redo(int c);
static void chg_c_toX_orX(void);
static void chg_c_to_X_orX_(void);
static void chg_c_to_X_or_X(void);
static void chg_l_to_X_orX_(void);
static void chg_l_toXor_X(void);
static void chg_r_to_Xor_X_(void);
static int toF_leading(int c);
static int toF_Rjoin(int c);
static int canF_Ljoin(int c);
static int canF_Rjoin(int c);
static int F_isterm(int c);
static int toF_ending(int c);
static void lrswapbuf(char_u *buf, int len);

/*
** Convert the given Farsi character into a _X or _X_ type
*/
static int toF_Xor_X_(int c)
{
  int tempc;

  switch (c) {
  case BE:
    return _BE;
  case PE:
    return _PE;
  case TE:
    return _TE;
  case SE:
    return _SE;
  case JIM:
    return _JIM;
  case CHE:
    return _CHE;
  case HE_J:
    return _HE_J;
  case XE:
    return _XE;
  case SIN:
    return _SIN;
  case SHIN:
    return _SHIN;
  case SAD:
    return _SAD;
  case ZAD:
    return _ZAD;
  case AYN:
    return _AYN;
  case AYN_:
    return _AYN_;
  case GHAYN:
    return _GHAYN;
  case GHAYN_:
    return _GHAYN_;
  case FE:
    return _FE;
  case GHAF:
    return _GHAF;
  case KAF:
    return _KAF;
  case GAF:
    return _GAF;
  case LAM:
    return _LAM;
  case MIM:
    return _MIM;
  case NOON:
    return _NOON;
  case YE:
  case YE_:
    return _YE;
  case YEE:
  case YEE_:
    return _YEE;
  case IE:
  case IE_:
    return _IE;
  case F_HE:
    tempc = _HE;

    if (p_ri && (curwin->w_cursor.col + 1
                 < (colnr_T)STRLEN(ml_get_curline()))) {
      inc_cursor();

      if (F_is_TyB_TyC_TyD(SRC_EDT, AT_CURSOR))
        tempc = _HE_;

      dec_cursor();
    }
    if (!p_ri && STRLEN(ml_get_curline())) {
      dec_cursor();

      if (F_is_TyB_TyC_TyD(SRC_EDT, AT_CURSOR))
        tempc = _HE_;

      inc_cursor();
    }

    return tempc;
  }
  return 0;
}

/*
** Convert the given Farsi character into Farsi capital character .
*/
int toF_TyA(int c)
{
  switch (c) {
  case ALEF_:
    return ALEF;
  case ALEF_U_H_:
    return ALEF_U_H;
  case _BE:
    return BE;
  case _PE:
    return PE;
  case _TE:
    return TE;
  case _SE:
    return SE;
  case _JIM:
    return JIM;
  case _CHE:
    return CHE;
  case _HE_J:
    return HE_J;
  case _XE:
    return XE;
  case _SIN:
    return SIN;
  case _SHIN:
    return SHIN;
  case _SAD:
    return SAD;
  case _ZAD:
    return ZAD;
  case _AYN:
  case AYN_:
  case _AYN_:
    return AYN;
  case _GHAYN:
  case GHAYN_:
  case _GHAYN_:
    return GHAYN;
  case _FE:
    return FE;
  case _GHAF:
    return GHAF;
  /* I am not sure what it is !!!	    case _KAF_H: */
  case _KAF:
    return KAF;
  case _GAF:
    return GAF;
  case _LAM:
    return LAM;
  case _MIM:
    return MIM;
  case _NOON:
    return NOON;
  case _YE:
  case YE_:
    return YE;
  case _YEE:
  case YEE_:
    return YEE;
  case TEE_:
    return TEE;
  case _IE:
  case IE_:
    return IE;
  case _HE:
  case _HE_:
    return F_HE;
  }
  return c;
}

/*
** Is the character under the cursor+offset in the given buffer a join type.
** That is a character that is combined with the others.
** Note: the offset is used only for command line buffer.
*/
static int F_is_TyB_TyC_TyD(int src, int offset)
{
  int c;

  if (src == SRC_EDT)
    c = gchar_cursor();
  else
    c = cmd_gchar(AT_CURSOR+offset);

  switch (c) {
  case _LAM:
  case _BE:
  case _PE:
  case _TE:
  case _SE:
  case _JIM:
  case _CHE:
  case _HE_J:
  case _XE:
  case _SIN:
  case _SHIN:
  case _SAD:
  case _ZAD:
  case _TA:
  case _ZA:
  case _AYN:
  case _AYN_:
  case _GHAYN:
  case _GHAYN_:
  case _FE:
  case _GHAF:
  case _KAF:
  case _KAF_H:
  case _GAF:
  case _MIM:
  case _NOON:
  case _YE:
  case _YEE:
  case _IE:
  case _HE_:
  case _HE:
    return TRUE;
  }
  return FALSE;
}

/*
** Is the Farsi character one of the terminating only type.
*/
static int F_is_TyE(int c)
{
  switch (c) {
  case ALEF_A:
  case ALEF_D_H:
  case DAL:
  case ZAL:
  case RE:
  case ZE:
  case JE:
  case WAW:
  case WAW_H:
  case HAMZE:
    return TRUE;
  }
  return FALSE;
}

/*
** Is the Farsi character one of the none leading type.
*/
static int F_is_TyC_TyD(int c)
{
  switch (c) {
  case ALEF_:
  case ALEF_U_H_:
  case _AYN_:
  case AYN_:
  case _GHAYN_:
  case GHAYN_:
  case _HE_:
  case YE_:
  case IE_:
  case TEE_:
  case YEE_:
    return TRUE;
  }
  return FALSE;
}

/*
** Convert a none leading Farsi char into a leading type.
*/
static int toF_TyB(int c)
{
  switch (c) {
  case ALEF_:     return ALEF;
  case ALEF_U_H_:     return ALEF_U_H;
  case _AYN_:     return _AYN;
  case AYN_:      return AYN;           /* exception - there are many of them */
  case _GHAYN_:   return _GHAYN;
  case GHAYN_:    return GHAYN;         /* exception - there are many of them */
  case _HE_:      return _HE;
  case YE_:       return YE;
  case IE_:       return IE;
  case TEE_:      return TEE;
  case YEE_:      return YEE;
  }
  return c;
}

/*
** Overwrite the current redo and cursor characters + left adjust
*/
static void put_curr_and_l_to_X(int c)
{
  int tempc;

  if (curwin->w_p_rl && p_ri)
    return;

  if ((curwin->w_cursor.col < (colnr_T)STRLEN(ml_get_curline()))) {
    if ((p_ri && curwin->w_cursor.col) || !p_ri) {
      if (p_ri)
        dec_cursor();
      else
        inc_cursor();

      if (F_is_TyC_TyD((tempc = gchar_cursor()))) {
        pchar_cursor(toF_TyB(tempc));
        AppendCharToRedobuff(K_BS);
        AppendCharToRedobuff(tempc);
      }

      if (p_ri)
        inc_cursor();
      else
        dec_cursor();
    }
  }

  put_and_redo(c);
}

static void put_and_redo(int c)
{
  pchar_cursor(c);
  AppendCharToRedobuff(K_BS);
  AppendCharToRedobuff(c);
}

/*
** Change the char. under the cursor to a X_ or X type
*/
static void chg_c_toX_orX(void)                 {
  int tempc, curc;

  switch ((curc = gchar_cursor())) {
  case _BE:
    tempc = BE;
    break;
  case _PE:
    tempc = PE;
    break;
  case _TE:
    tempc = TE;
    break;
  case _SE:
    tempc = SE;
    break;
  case _JIM:
    tempc = JIM;
    break;
  case _CHE:
    tempc = CHE;
    break;
  case _HE_J:
    tempc = HE_J;
    break;
  case _XE:
    tempc = XE;
    break;
  case _SIN:
    tempc = SIN;
    break;
  case _SHIN:
    tempc = SHIN;
    break;
  case _SAD:
    tempc = SAD;
    break;
  case _ZAD:
    tempc = ZAD;
    break;
  case _FE:
    tempc = FE;
    break;
  case _GHAF:
    tempc = GHAF;
    break;
  case _KAF_H:
  case _KAF:
    tempc = KAF;
    break;
  case _GAF:
    tempc = GAF;
    break;
  case _AYN:
    tempc = AYN;
    break;
  case _AYN_:
    tempc = AYN_;
    break;
  case _GHAYN:
    tempc = GHAYN;
    break;
  case _GHAYN_:
    tempc = GHAYN_;
    break;
  case _LAM:
    tempc = LAM;
    break;
  case _MIM:
    tempc = MIM;
    break;
  case _NOON:
    tempc = NOON;
    break;
  case _HE:
  case _HE_:
    tempc = F_HE;
    break;
  case _YE:
  case _IE:
  case _YEE:
    if (p_ri) {
      inc_cursor();
      if (F_is_TyB_TyC_TyD(SRC_EDT, AT_CURSOR))
        tempc = (curc == _YE ? YE_ :
                 (curc == _IE ? IE_ : YEE_));
      else
        tempc = (curc == _YE ? YE :
                 (curc == _IE ? IE : YEE));
      dec_cursor();
    } else   {
      if (curwin->w_cursor.col) {
        dec_cursor();
        if (F_is_TyB_TyC_TyD(SRC_EDT, AT_CURSOR))
          tempc = (curc == _YE ? YE_ :
                   (curc == _IE ? IE_ : YEE_));
        else
          tempc = (curc == _YE ? YE :
                   (curc == _IE ? IE : YEE));
        inc_cursor();
      } else
        tempc = (curc == _YE ? YE :
                 (curc == _IE ? IE : YEE));
    }
    break;
  default:
    tempc = 0;
  }

  if (tempc)
    put_and_redo(tempc);
}

/*
** Change the char. under the cursor to a _X_ or X_ type
*/

static void chg_c_to_X_orX_(void)                 {
  int tempc;

  switch (gchar_cursor()) {
  case ALEF:
    tempc = ALEF_;
    break;
  case ALEF_U_H:
    tempc = ALEF_U_H_;
    break;
  case _AYN:
    tempc = _AYN_;
    break;
  case AYN:
    tempc = AYN_;
    break;
  case _GHAYN:
    tempc = _GHAYN_;
    break;
  case GHAYN:
    tempc = GHAYN_;
    break;
  case _HE:
    tempc = _HE_;
    break;
  case YE:
    tempc = YE_;
    break;
  case IE:
    tempc = IE_;
    break;
  case TEE:
    tempc = TEE_;
    break;
  case YEE:
    tempc = YEE_;
    break;
  default:
    tempc = 0;
  }

  if (tempc)
    put_and_redo(tempc);
}

/*
** Change the char. under the cursor to a _X_ or _X type
*/
static void chg_c_to_X_or_X(void)                 {
  int tempc;

  tempc = gchar_cursor();

  if (curwin->w_cursor.col + 1 < (colnr_T)STRLEN(ml_get_curline())) {
    inc_cursor();

    if ((tempc == F_HE) && (F_is_TyB_TyC_TyD(SRC_EDT, AT_CURSOR))) {
      tempc = _HE_;

      dec_cursor();

      put_and_redo(tempc);
      return;
    }

    dec_cursor();
  }

  if ((tempc = toF_Xor_X_(tempc)) != 0)
    put_and_redo(tempc);
}

/*
** Change the character left to the cursor to a _X_ or X_ type
*/
static void chg_l_to_X_orX_(void)                 {
  int tempc;

  if (curwin->w_cursor.col != 0 &&
      (curwin->w_cursor.col + 1 == (colnr_T)STRLEN(ml_get_curline())))
    return;

  if (!curwin->w_cursor.col && p_ri)
    return;

  if (p_ri)
    dec_cursor();
  else
    inc_cursor();

  switch (gchar_cursor()) {
  case ALEF:
    tempc = ALEF_;
    break;
  case ALEF_U_H:
    tempc = ALEF_U_H_;
    break;
  case _AYN:
    tempc = _AYN_;
    break;
  case AYN:
    tempc = AYN_;
    break;
  case _GHAYN:
    tempc = _GHAYN_;
    break;
  case GHAYN:
    tempc = GHAYN_;
    break;
  case _HE:
    tempc = _HE_;
    break;
  case YE:
    tempc = YE_;
    break;
  case IE:
    tempc = IE_;
    break;
  case TEE:
    tempc = TEE_;
    break;
  case YEE:
    tempc = YEE_;
    break;
  default:
    tempc = 0;
  }

  if (tempc)
    put_and_redo(tempc);

  if (p_ri)
    inc_cursor();
  else
    dec_cursor();
}

/*
** Change the character left to the cursor to a X or _X type
*/

static void chg_l_toXor_X(void)                 {
  int tempc;

  if (curwin->w_cursor.col != 0 &&
      (curwin->w_cursor.col + 1 == (colnr_T)STRLEN(ml_get_curline())))
    return;

  if (!curwin->w_cursor.col && p_ri)
    return;

  if (p_ri)
    dec_cursor();
  else
    inc_cursor();

  switch (gchar_cursor()) {
  case ALEF_:
    tempc = ALEF;
    break;
  case ALEF_U_H_:
    tempc = ALEF_U_H;
    break;
  case _AYN_:
    tempc = _AYN;
    break;
  case AYN_:
    tempc = AYN;
    break;
  case _GHAYN_:
    tempc = _GHAYN;
    break;
  case GHAYN_:
    tempc = GHAYN;
    break;
  case _HE_:
    tempc = _HE;
    break;
  case YE_:
    tempc = YE;
    break;
  case IE_:
    tempc = IE;
    break;
  case TEE_:
    tempc = TEE;
    break;
  case YEE_:
    tempc = YEE;
    break;
  default:
    tempc = 0;
  }

  if (tempc)
    put_and_redo(tempc);

  if (p_ri)
    inc_cursor();
  else
    dec_cursor();
}

/*
** Change the character right to the cursor to a _X or _X_ type
*/

static void chg_r_to_Xor_X_(void)                 {
  int tempc, c;

  if (curwin->w_cursor.col) {
    if (!p_ri)
      dec_cursor();

    tempc = gchar_cursor();

    if ((c = toF_Xor_X_(tempc)) != 0)
      put_and_redo(c);

    if (!p_ri)
      inc_cursor();

  }
}

/*
** Map Farsi keyboard when in fkmap mode.
*/

int fkmap(int c)
{
  int tempc;
  static int revins;

  if (IS_SPECIAL(c))
    return c;

  if (VIM_ISDIGIT(c) || ((c == '.' || c == '+' || c == '-' ||
                          c == '^' || c == '%' || c == '#' ||
                          c == '=')  && revins)) {
    if (!revins) {
      if (curwin->w_cursor.col) {
        if (!p_ri)
          dec_cursor();

        chg_c_toX_orX ();
        chg_l_toXor_X ();

        if (!p_ri)
          inc_cursor();
      }
    }

    arrow_used = TRUE;
    (void)stop_arrow();

    if (!curwin->w_p_rl && revins)
      inc_cursor();

    ++revins;
    p_ri=1;
  } else   {
    if (revins) {
      arrow_used = TRUE;
      (void)stop_arrow();

      revins = 0;
      if (curwin->w_p_rl) {
        while ((F_isdigit(gchar_cursor())
                || (gchar_cursor() == F_PERIOD
                    || gchar_cursor() == F_PLUS
                    || gchar_cursor() == F_MINUS
                    || gchar_cursor() == F_MUL
                    || gchar_cursor() == F_DIVIDE
                    || gchar_cursor() == F_PERCENT
                    || gchar_cursor() == F_EQUALS))
               && gchar_cursor() != NUL)
          ++curwin->w_cursor.col;
      } else   {
        if (curwin->w_cursor.col)
          while ((F_isdigit(gchar_cursor())
                  || (gchar_cursor() == F_PERIOD
                      || gchar_cursor() == F_PLUS
                      || gchar_cursor() == F_MINUS
                      || gchar_cursor() == F_MUL
                      || gchar_cursor() == F_DIVIDE
                      || gchar_cursor() == F_PERCENT
                      || gchar_cursor() == F_EQUALS))
                 && --curwin->w_cursor.col)
            ;

        if (!F_isdigit(gchar_cursor()))
          ++curwin->w_cursor.col;
      }
    }
  }

  if (!revins) {
    if (curwin->w_p_rl)
      p_ri=0;
    if (!curwin->w_p_rl)
      p_ri=1;
  }

  if ((c < 0x100) && (isalpha(c) || c == '&' ||   c == '^' || c == ';' ||
                      c == '\''|| c == ',' || c == '[' ||
                      c == ']' || c == '{' || c == '}'    ))
    chg_r_to_Xor_X_();

  tempc = 0;

  switch (c) {
  case '`':
  case ' ':
  case '.':
  case '!':
  case '"':
  case '$':
  case '%':
  case '^':
  case '&':
  case '/':
  case '(':
  case ')':
  case '=':
  case '\\':
  case '?':
  case '+':
  case '-':
  case '_':
  case '*':
  case ':':
  case '#':
  case '~':
  case '@':
  case '<':
  case '>':
  case '{':
  case '}':
  case '|':
  case '0':
  case '1':
  case '2':
  case '3':
  case '4':
  case '5':
  case '6':
  case '7':
  case '8':
  case '9':
  case 'B':
  case 'E':
  case 'F':
  case 'H':
  case 'I':
  case 'K':
  case 'L':
  case 'M':
  case 'O':
  case 'P':
  case 'Q':
  case 'R':
  case 'T':
  case 'U':
  case 'W':
  case 'Y':
  case  NL:
  case  TAB:

    if (p_ri && c == NL && curwin->w_cursor.col) {
      /*
      ** If the char before the cursor is _X_ or X_ do not change
      ** the one under the cursor with X type.
      */

      dec_cursor();

      if (F_isalpha(gchar_cursor())) {
        inc_cursor();
        return NL;
      }

      inc_cursor();
    }

    if (!p_ri)
      if (!curwin->w_cursor.col) {
        switch (c) {
        case '0':   return FARSI_0;
        case '1':   return FARSI_1;
        case '2':   return FARSI_2;
        case '3':   return FARSI_3;
        case '4':   return FARSI_4;
        case '5':   return FARSI_5;
        case '6':   return FARSI_6;
        case '7':   return FARSI_7;
        case '8':   return FARSI_8;
        case '9':   return FARSI_9;
        case 'B':   return F_PSP;
        case 'E':   return JAZR_N;
        case 'F':   return ALEF_D_H;
        case 'H':   return ALEF_A;
        case 'I':   return TASH;
        case 'K':   return F_LQUOT;
        case 'L':   return F_RQUOT;
        case 'M':   return HAMZE;
        case 'O':   return '[';
        case 'P':   return ']';
        case 'Q':   return OO;
        case 'R':   return MAD_N;
        case 'T':   return OW;
        case 'U':   return MAD;
        case 'W':   return OW_OW;
        case 'Y':   return JAZR;
        case '`':   return F_PCN;
        case '!':   return F_EXCL;
        case '@':   return F_COMMA;
        case '#':   return F_DIVIDE;
        case '$':   return F_CURRENCY;
        case '%':   return F_PERCENT;
        case '^':   return F_MUL;
        case '&':   return F_BCOMMA;
        case '*':   return F_STAR;
        case '(':   return F_LPARENT;
        case ')':   return F_RPARENT;
        case '-':   return F_MINUS;
        case '_':   return F_UNDERLINE;
        case '=':   return F_EQUALS;
        case '+':   return F_PLUS;
        case '\\':  return F_BSLASH;
        case '|':   return F_PIPE;
        case ':':   return F_DCOLON;
        case '"':   return F_SEMICOLON;
        case '.':   return F_PERIOD;
        case '/':   return F_SLASH;
        case '<':   return F_LESS;
        case '>':   return F_GREATER;
        case '?':   return F_QUESTION;
        case ' ':   return F_BLANK;
        }
        break;
      }
    if (!p_ri)
      dec_cursor();

    switch ((tempc = gchar_cursor())) {
    case _BE:
    case _PE:
    case _TE:
    case _SE:
    case _JIM:
    case _CHE:
    case _HE_J:
    case _XE:
    case _SIN:
    case _SHIN:
    case _SAD:
    case _ZAD:
    case _FE:
    case _GHAF:
    case _KAF:
    case _KAF_H:
    case _GAF:
    case _LAM:
    case _MIM:
    case _NOON:
    case _HE:
    case _HE_:
    case _TA:
    case _ZA:
      put_curr_and_l_to_X(toF_TyA(tempc));
      break;
    case _AYN:
    case _AYN_:

      if (!p_ri)
        if (!curwin->w_cursor.col) {
          put_curr_and_l_to_X(AYN);
          break;
        }

      if (p_ri)
        inc_cursor();
      else
        dec_cursor();

      if (F_is_TyB_TyC_TyD(SRC_EDT, AT_CURSOR))
        tempc = AYN_;
      else
        tempc = AYN;

      if (p_ri)
        dec_cursor();
      else
        inc_cursor();

      put_curr_and_l_to_X(tempc);

      break;
    case _GHAYN:
    case _GHAYN_:

      if (!p_ri)
        if (!curwin->w_cursor.col) {
          put_curr_and_l_to_X(GHAYN);
          break;
        }

      if (p_ri)
        inc_cursor();
      else
        dec_cursor();

      if (F_is_TyB_TyC_TyD(SRC_EDT, AT_CURSOR))
        tempc = GHAYN_;
      else
        tempc = GHAYN;

      if (p_ri)
        dec_cursor();
      else
        inc_cursor();

      put_curr_and_l_to_X(tempc);
      break;
    case _YE:
    case _IE:
    case _YEE:
      if (!p_ri)
        if (!curwin->w_cursor.col) {
          put_curr_and_l_to_X((tempc == _YE ? YE :
                               (tempc == _IE ? IE : YEE)));
          break;
        }

      if (p_ri)
        inc_cursor();
      else
        dec_cursor();

      if (F_is_TyB_TyC_TyD(SRC_EDT, AT_CURSOR))
        tempc = (tempc == _YE ? YE_ :
                 (tempc == _IE ? IE_ : YEE_));
      else
        tempc = (tempc == _YE ? YE :
                 (tempc == _IE ? IE : YEE));

      if (p_ri)
        dec_cursor();
      else
        inc_cursor();

      put_curr_and_l_to_X(tempc);
      break;
    }

    if (!p_ri)
      inc_cursor();

    tempc = 0;

    switch (c) {
    case '0':   return FARSI_0;
    case '1':   return FARSI_1;
    case '2':   return FARSI_2;
    case '3':   return FARSI_3;
    case '4':   return FARSI_4;
    case '5':   return FARSI_5;
    case '6':   return FARSI_6;
    case '7':   return FARSI_7;
    case '8':   return FARSI_8;
    case '9':   return FARSI_9;
    case 'B':   return F_PSP;
    case 'E':   return JAZR_N;
    case 'F':   return ALEF_D_H;
    case 'H':   return ALEF_A;
    case 'I':   return TASH;
    case 'K':   return F_LQUOT;
    case 'L':   return F_RQUOT;
    case 'M':   return HAMZE;
    case 'O':   return '[';
    case 'P':   return ']';
    case 'Q':   return OO;
    case 'R':   return MAD_N;
    case 'T':   return OW;
    case 'U':   return MAD;
    case 'W':   return OW_OW;
    case 'Y':   return JAZR;
    case '`':   return F_PCN;
    case '!':   return F_EXCL;
    case '@':   return F_COMMA;
    case '#':   return F_DIVIDE;
    case '$':   return F_CURRENCY;
    case '%':   return F_PERCENT;
    case '^':   return F_MUL;
    case '&':   return F_BCOMMA;
    case '*':   return F_STAR;
    case '(':   return F_LPARENT;
    case ')':   return F_RPARENT;
    case '-':   return F_MINUS;
    case '_':   return F_UNDERLINE;
    case '=':   return F_EQUALS;
    case '+':   return F_PLUS;
    case '\\':  return F_BSLASH;
    case '|':   return F_PIPE;
    case ':':   return F_DCOLON;
    case '"':   return F_SEMICOLON;
    case '.':   return F_PERIOD;
    case '/':   return F_SLASH;
    case '<':   return F_LESS;
    case '>':   return F_GREATER;
    case '?':   return F_QUESTION;
    case ' ':   return F_BLANK;
    }
    break;

  case 'a':
    tempc = _SHIN;
    break;
  case 'A':
    tempc = WAW_H;
    break;
  case 'b':
    tempc = ZAL;
    break;
  case 'c':
    tempc = ZE;
    break;
  case 'C':
    tempc = JE;
    break;
  case 'd':
    tempc = _YE;
    break;
  case 'D':
    tempc = _YEE;
    break;
  case 'e':
    tempc = _SE;
    break;
  case 'f':
    tempc = _BE;
    break;
  case 'g':
    tempc = _LAM;
    break;
  case 'G':
    if (!curwin->w_cursor.col  &&  STRLEN(ml_get_curline())) {

      if (gchar_cursor() == _LAM)
        chg_c_toX_orX ();
      else if (p_ri)
        chg_c_to_X_or_X ();
    }

    if (!p_ri)
      if (!curwin->w_cursor.col)
        return ALEF_U_H;

    if (!p_ri)
      dec_cursor();

    if (gchar_cursor() == _LAM) {
      chg_c_toX_orX ();
      chg_l_toXor_X ();
      tempc = ALEF_U_H;
    } else if (F_is_TyB_TyC_TyD(SRC_EDT, AT_CURSOR))    {
      tempc = ALEF_U_H_;
      chg_l_toXor_X ();
    } else
      tempc = ALEF_U_H;

    if (!p_ri)
      inc_cursor();

    return tempc;
  case 'h':
    if (!curwin->w_cursor.col  &&  STRLEN(ml_get_curline())) {
      if (p_ri)
        chg_c_to_X_or_X ();

    }

    if (!p_ri)
      if (!curwin->w_cursor.col)
        return ALEF;

    if (!p_ri)
      dec_cursor();

    if (gchar_cursor() == _LAM) {
      chg_l_toXor_X();
      del_char(FALSE);
      AppendCharToRedobuff(K_BS);

      if (!p_ri)
        dec_cursor();

      tempc = LA;
    } else   {
      if (F_is_TyB_TyC_TyD(SRC_EDT, AT_CURSOR)) {
        tempc = ALEF_;
        chg_l_toXor_X ();
      } else
        tempc = ALEF;
    }

    if (!p_ri)
      inc_cursor();

    return tempc;
  case 'i':
    if (!curwin->w_cursor.col  &&  STRLEN(ml_get_curline())) {
      if (!p_ri && !F_is_TyE(tempc))
        chg_c_to_X_orX_ ();
      if (p_ri)
        chg_c_to_X_or_X ();

    }

    if (!p_ri && !curwin->w_cursor.col)
      return _HE;

    if (!p_ri)
      dec_cursor();

    if (F_is_TyB_TyC_TyD(SRC_EDT, AT_CURSOR))
      tempc = _HE_;
    else
      tempc = _HE;

    if (!p_ri)
      inc_cursor();
    break;
  case 'j':
    tempc = _TE;
    break;
  case 'J':
    if (!curwin->w_cursor.col  &&  STRLEN(ml_get_curline())) {
      if (p_ri)
        chg_c_to_X_or_X ();

    }

    if (!p_ri)
      if (!curwin->w_cursor.col)
        return TEE;

    if (!p_ri)
      dec_cursor();

    if (F_is_TyB_TyC_TyD(SRC_EDT, AT_CURSOR)) {
      tempc = TEE_;
      chg_l_toXor_X ();
    } else
      tempc = TEE;

    if (!p_ri)
      inc_cursor();

    return tempc;
  case 'k':
    tempc = _NOON;
    break;
  case 'l':
    tempc = _MIM;
    break;
  case 'm':
    tempc = _PE;
    break;
  case 'n':
  case 'N':
    tempc = DAL;
    break;
  case 'o':
    tempc = _XE;
    break;
  case 'p':
    tempc = _HE_J;
    break;
  case 'q':
    tempc = _ZAD;
    break;
  case 'r':
    tempc = _GHAF;
    break;
  case 's':
    tempc = _SIN;
    break;
  case 'S':
    tempc = _IE;
    break;
  case 't':
    tempc = _FE;
    break;
  case 'u':
    if (!curwin->w_cursor.col  &&  STRLEN(ml_get_curline())) {
      if (!p_ri && !F_is_TyE(tempc))
        chg_c_to_X_orX_ ();
      if (p_ri)
        chg_c_to_X_or_X ();

    }

    if (!p_ri && !curwin->w_cursor.col)
      return _AYN;

    if (!p_ri)
      dec_cursor();

    if (F_is_TyB_TyC_TyD(SRC_EDT, AT_CURSOR))
      tempc = _AYN_;
    else
      tempc = _AYN;

    if (!p_ri)
      inc_cursor();
    break;
  case 'v':
  case 'V':
    tempc = RE;
    break;
  case 'w':
    tempc = _SAD;
    break;
  case 'x':
  case 'X':
    tempc = _TA;
    break;
  case 'y':
    if (!curwin->w_cursor.col  &&  STRLEN(ml_get_curline())) {
      if (!p_ri && !F_is_TyE(tempc))
        chg_c_to_X_orX_ ();
      if (p_ri)
        chg_c_to_X_or_X ();

    }

    if (!p_ri && !curwin->w_cursor.col)
      return _GHAYN;

    if (!p_ri)
      dec_cursor();

    if (F_is_TyB_TyC_TyD(SRC_EDT, AT_CURSOR))
      tempc = _GHAYN_;
    else
      tempc = _GHAYN;

    if (!p_ri)
      inc_cursor();

    break;
  case 'z':
    tempc = _ZA;
    break;
  case 'Z':
    tempc = _KAF_H;
    break;
  case ';':
    tempc = _KAF;
    break;
  case '\'':
    tempc = _GAF;
    break;
  case ',':
    tempc = WAW;
    break;
  case '[':
    tempc = _JIM;
    break;
  case ']':
    tempc = _CHE;
    break;
  }

  if ((F_isalpha(tempc) || F_isdigit(tempc))) {
    if (!curwin->w_cursor.col  &&  STRLEN(ml_get_curline())) {
      if (!p_ri && !F_is_TyE(tempc))
        chg_c_to_X_orX_ ();
      if (p_ri)
        chg_c_to_X_or_X ();
    }

    if (curwin->w_cursor.col) {
      if (!p_ri)
        dec_cursor();

      if (F_is_TyE(tempc))
        chg_l_toXor_X ();
      else
        chg_l_to_X_orX_ ();

      if (!p_ri)
        inc_cursor();
    }
  }
  if (tempc)
    return tempc;
  return c;
}

/*
** Convert a none leading Farsi char into a leading type.
*/
static int toF_leading(int c)
{
  switch (c) {
  case ALEF_:     return ALEF;
  case ALEF_U_H_:     return ALEF_U_H;
  case BE:    return _BE;
  case PE:    return _PE;
  case TE:    return _TE;
  case SE:    return _SE;
  case JIM:   return _JIM;
  case CHE:   return _CHE;
  case HE_J:  return _HE_J;
  case XE:    return _XE;
  case SIN:   return _SIN;
  case SHIN:  return _SHIN;
  case SAD:   return _SAD;
  case ZAD:   return _ZAD;

  case AYN:
  case AYN_:
  case _AYN_: return _AYN;

  case GHAYN:
  case GHAYN_:
  case _GHAYN_:   return _GHAYN;

  case FE:    return _FE;
  case GHAF:  return _GHAF;
  case KAF:   return _KAF;
  case GAF:   return _GAF;
  case LAM:   return _LAM;
  case MIM:   return _MIM;
  case NOON:  return _NOON;

  case _HE_:
  case F_HE:      return _HE;

  case YE:
  case YE_:       return _YE;

  case IE_:
  case IE:        return _IE;

  case YEE:
  case YEE_:      return _YEE;
  }
  return c;
}

/*
** Convert a given Farsi char into right joining type.
*/
static int toF_Rjoin(int c)
{
  switch (c) {
  case ALEF:  return ALEF_;
  case ALEF_U_H:  return ALEF_U_H_;
  case BE:    return _BE;
  case PE:    return _PE;
  case TE:    return _TE;
  case SE:    return _SE;
  case JIM:   return _JIM;
  case CHE:   return _CHE;
  case HE_J:  return _HE_J;
  case XE:    return _XE;
  case SIN:   return _SIN;
  case SHIN:  return _SHIN;
  case SAD:   return _SAD;
  case ZAD:   return _ZAD;

  case AYN:
  case AYN_:
  case _AYN:  return _AYN_;

  case GHAYN:
  case GHAYN_:
  case _GHAYN_:   return _GHAYN_;

  case FE:    return _FE;
  case GHAF:  return _GHAF;
  case KAF:   return _KAF;
  case GAF:   return _GAF;
  case LAM:   return _LAM;
  case MIM:   return _MIM;
  case NOON:  return _NOON;

  case _HE:
  case F_HE:      return _HE_;

  case YE:
  case YE_:       return _YE;

  case IE_:
  case IE:        return _IE;

  case TEE:       return TEE_;

  case YEE:
  case YEE_:      return _YEE;
  }
  return c;
}

/*
** Can a given Farsi character join via its left edj.
*/
static int canF_Ljoin(int c)
{
  switch (c) {
  case _BE:
  case BE:
  case PE:
  case _PE:
  case TE:
  case _TE:
  case SE:
  case _SE:
  case JIM:
  case _JIM:
  case CHE:
  case _CHE:
  case HE_J:
  case _HE_J:
  case XE:
  case _XE:
  case SIN:
  case _SIN:
  case SHIN:
  case _SHIN:
  case SAD:
  case _SAD:
  case ZAD:
  case _ZAD:
  case _TA:
  case _ZA:
  case AYN:
  case _AYN:
  case _AYN_:
  case AYN_:
  case GHAYN:
  case GHAYN_:
  case _GHAYN_:
  case _GHAYN:
  case FE:
  case _FE:
  case GHAF:
  case _GHAF:
  case _KAF_H:
  case KAF:
  case _KAF:
  case GAF:
  case _GAF:
  case LAM:
  case _LAM:
  case MIM:
  case _MIM:
  case NOON:
  case _NOON:
  case IE:
  case _IE:
  case IE_:
  case YE:
  case _YE:
  case YE_:
  case YEE:
  case _YEE:
  case YEE_:
  case F_HE:
  case _HE:
  case _HE_:
    return TRUE;
  }
  return FALSE;
}

/*
** Can a given Farsi character join via its right edj.
*/
static int canF_Rjoin(int c)
{
  switch (c) {
  case ALEF:
  case ALEF_:
  case ALEF_U_H:
  case ALEF_U_H_:
  case DAL:
  case ZAL:
  case RE:
  case JE:
  case ZE:
  case TEE:
  case TEE_:
  case WAW:
  case WAW_H:
    return TRUE;
  }

  return canF_Ljoin(c);

}

/*
** is a given Farsi character a terminating type.
*/
static int F_isterm(int c)
{
  switch (c) {
  case ALEF:
  case ALEF_:
  case ALEF_U_H:
  case ALEF_U_H_:
  case DAL:
  case ZAL:
  case RE:
  case JE:
  case ZE:
  case WAW:
  case WAW_H:
  case TEE:
  case TEE_:
    return TRUE;
  }

  return FALSE;
}

/*
** Convert the given Farsi character into a ending type .
*/
static int toF_ending(int c)
{

  switch (c) {
  case _BE:
    return BE;
  case _PE:
    return PE;
  case _TE:
    return TE;
  case _SE:
    return SE;
  case _JIM:
    return JIM;
  case _CHE:
    return CHE;
  case _HE_J:
    return HE_J;
  case _XE:
    return XE;
  case _SIN:
    return SIN;
  case _SHIN:
    return SHIN;
  case _SAD:
    return SAD;
  case _ZAD:
    return ZAD;
  case _AYN:
    return AYN;
  case _AYN_:
    return AYN_;
  case _GHAYN:
    return GHAYN;
  case _GHAYN_:
    return GHAYN_;
  case _FE:
    return FE;
  case _GHAF:
    return GHAF;
  case _KAF_H:
  case _KAF:
    return KAF;
  case _GAF:
    return GAF;
  case _LAM:
    return LAM;
  case _MIM:
    return MIM;
  case _NOON:
    return NOON;
  case _YE:
    return YE_;
  case YE_:
    return YE;
  case _YEE:
    return YEE_;
  case YEE_:
    return YEE;
  case TEE:
    return TEE_;
  case _IE:
    return IE_;
  case IE_:
    return IE;
  case _HE:
  case _HE_:
    return F_HE;
  }
  return c;
}

/*
** Convert the Farsi 3342 standard into Farsi VIM.
*/
void conv_to_pvim(void)          {
  char_u      *ptr;
  int lnum, llen, i;

  for (lnum = 1; lnum <= curbuf->b_ml.ml_line_count; ++lnum) {
    ptr = ml_get((linenr_T)lnum);

    llen = (int)STRLEN(ptr);

    for ( i = 0; i < llen-1; i++) {
      if (canF_Ljoin(ptr[i]) && canF_Rjoin(ptr[i+1])) {
        ptr[i] = toF_leading(ptr[i]);
        ++i;

        while (canF_Rjoin(ptr[i]) && i < llen) {
          ptr[i] = toF_Rjoin(ptr[i]);
          if (F_isterm(ptr[i]) || !F_isalpha(ptr[i]))
            break;
          ++i;
        }
        if (!F_isalpha(ptr[i]) || !canF_Rjoin(ptr[i]))
          ptr[i-1] = toF_ending(ptr[i-1]);
      } else
        ptr[i] = toF_TyA(ptr[i]);
    }
  }

  /*
   * Following lines contains Farsi encoded character.
   */

  do_cmdline_cmd((char_u *)"%s/\202\231/\232/g");
  do_cmdline_cmd((char_u *)"%s/\201\231/\370\334/g");

  /* Assume the screen has been messed up: clear it and redraw. */
  redraw_later(CLEAR);
  MSG_ATTR(farsi_text_1, hl_attr(HLF_S));
}

/*
 * Convert the Farsi VIM into Farsi 3342 standard.
 */
void conv_to_pstd(void)          {
  char_u      *ptr;
  int lnum, llen, i;

  /*
   * Following line contains Farsi encoded character.
   */

  do_cmdline_cmd((char_u *)"%s/\232/\202\231/g");

  for (lnum = 1; lnum <= curbuf->b_ml.ml_line_count; ++lnum) {
    ptr = ml_get((linenr_T)lnum);

    llen = (int)STRLEN(ptr);

    for ( i = 0; i < llen; i++) {
      ptr[i] = toF_TyA(ptr[i]);

    }
  }

  /* Assume the screen has been messed up: clear it and redraw. */
  redraw_later(CLEAR);
  MSG_ATTR(farsi_text_2, hl_attr(HLF_S));
}

/*
 * left-right swap the characters in buf[len].
 */
static void lrswapbuf(char_u *buf, int len)
{
  char_u      *s, *e;
  int c;

  s = buf;
  e = buf + len - 1;

  while (e > s) {
    c = *s;
    *s = *e;
    *e = c;
    ++s;
    --e;
  }
}

/*
 * swap all the characters in reverse direction
 */
char_u *lrswap(char_u *ibuf)
{
  if (ibuf != NULL && *ibuf != NUL)
    lrswapbuf(ibuf, (int)STRLEN(ibuf));
  return ibuf;
}

/*
 * swap all the Farsi characters in reverse direction
 */
char_u *lrFswap(char_u *cmdbuf, int len)
{
  int i, cnt;

  if (cmdbuf == NULL)
    return cmdbuf;

  if (len == 0 && (len = (int)STRLEN(cmdbuf)) == 0)
    return cmdbuf;

  for (i = 0; i < len; i++) {
    for (cnt = 0; i + cnt < len
         && (F_isalpha(cmdbuf[i + cnt])
             || F_isdigit(cmdbuf[i + cnt])
             || cmdbuf[i + cnt] == ' '); ++cnt)
      ;

    lrswapbuf(cmdbuf + i, cnt);
    i += cnt;
  }
  return cmdbuf;
}

/*
 * Reverse the characters in the search path and substitute section
 * accordingly.
 * TODO: handle different separator characters.  Use skip_regexp().
 */
char_u *lrF_sub(char_u *ibuf)
{
  char_u      *p, *ep;
  int i, cnt;

  p = ibuf;

  /* Find the boundary of the search path */
  while (((p = vim_strchr(p + 1, '/')) != NULL) && p[-1] == '\\')
    ;

  if (p == NULL)
    return ibuf;

  /* Reverse the Farsi characters in the search path. */
  lrFswap(ibuf, (int)(p-ibuf));

  /* Now find the boundary of the substitute section */
  if ((ep = (char_u *)strrchr((char *)++p, '/')) != NULL)
    cnt = (int)(ep - p);
  else
    cnt = (int)STRLEN(p);

  /* Reverse the characters in the substitute section and take care of '\' */
  for (i = 0; i < cnt-1; i++)
    if (p[i] == '\\') {
      p[i] = p[i+1];
      p[++i] = '\\';
    }

  lrswapbuf(p, cnt);

  return ibuf;
}

/*
 * Map Farsi keyboard when in cmd_fkmap mode.
 */
int cmdl_fkmap(int c)
{
  int tempc;

  switch (c) {
  case '0':
  case '1':
  case '2':
  case '3':
  case '4':
  case '5':
  case '6':
  case '7':
  case '8':
  case '9':
  case '`':
  case ' ':
  case '.':
  case '!':
  case '"':
  case '$':
  case '%':
  case '^':
  case '&':
  case '/':
  case '(':
  case ')':
  case '=':
  case '\\':
  case '?':
  case '+':
  case '-':
  case '_':
  case '*':
  case ':':
  case '#':
  case '~':
  case '@':
  case '<':
  case '>':
  case '{':
  case '}':
  case '|':
  case 'B':
  case 'E':
  case 'F':
  case 'H':
  case 'I':
  case 'K':
  case 'L':
  case 'M':
  case 'O':
  case 'P':
  case 'Q':
  case 'R':
  case 'T':
  case 'U':
  case 'W':
  case 'Y':
  case  NL:
  case  TAB:

    switch ((tempc = cmd_gchar(AT_CURSOR))) {
    case _BE:
    case _PE:
    case _TE:
    case _SE:
    case _JIM:
    case _CHE:
    case _HE_J:
    case _XE:
    case _SIN:
    case _SHIN:
    case _SAD:
    case _ZAD:
    case _AYN:
    case _GHAYN:
    case _FE:
    case _GHAF:
    case _KAF:
    case _GAF:
    case _LAM:
    case _MIM:
    case _NOON:
    case _HE:
    case _HE_:
      cmd_pchar(toF_TyA(tempc), AT_CURSOR);
      break;
    case _AYN_:
      cmd_pchar(AYN_, AT_CURSOR);
      break;
    case _GHAYN_:
      cmd_pchar(GHAYN_, AT_CURSOR);
      break;
    case _IE:
      if (F_is_TyB_TyC_TyD(SRC_CMD, AT_CURSOR+1))
        cmd_pchar(IE_, AT_CURSOR);
      else
        cmd_pchar(IE, AT_CURSOR);
      break;
    case _YEE:
      if (F_is_TyB_TyC_TyD(SRC_CMD, AT_CURSOR+1))
        cmd_pchar(YEE_, AT_CURSOR);
      else
        cmd_pchar(YEE, AT_CURSOR);
      break;
    case _YE:
      if (F_is_TyB_TyC_TyD(SRC_CMD, AT_CURSOR+1))
        cmd_pchar(YE_, AT_CURSOR);
      else
        cmd_pchar(YE, AT_CURSOR);
    }

    switch (c) {
    case '0':   return FARSI_0;
    case '1':   return FARSI_1;
    case '2':   return FARSI_2;
    case '3':   return FARSI_3;
    case '4':   return FARSI_4;
    case '5':   return FARSI_5;
    case '6':   return FARSI_6;
    case '7':   return FARSI_7;
    case '8':   return FARSI_8;
    case '9':   return FARSI_9;
    case 'B':   return F_PSP;
    case 'E':   return JAZR_N;
    case 'F':   return ALEF_D_H;
    case 'H':   return ALEF_A;
    case 'I':   return TASH;
    case 'K':   return F_LQUOT;
    case 'L':   return F_RQUOT;
    case 'M':   return HAMZE;
    case 'O':   return '[';
    case 'P':   return ']';
    case 'Q':   return OO;
    case 'R':   return MAD_N;
    case 'T':   return OW;
    case 'U':   return MAD;
    case 'W':   return OW_OW;
    case 'Y':   return JAZR;
    case '`':   return F_PCN;
    case '!':   return F_EXCL;
    case '@':   return F_COMMA;
    case '#':   return F_DIVIDE;
    case '$':   return F_CURRENCY;
    case '%':   return F_PERCENT;
    case '^':   return F_MUL;
    case '&':   return F_BCOMMA;
    case '*':   return F_STAR;
    case '(':   return F_LPARENT;
    case ')':   return F_RPARENT;
    case '-':   return F_MINUS;
    case '_':   return F_UNDERLINE;
    case '=':   return F_EQUALS;
    case '+':   return F_PLUS;
    case '\\':  return F_BSLASH;
    case '|':   return F_PIPE;
    case ':':   return F_DCOLON;
    case '"':   return F_SEMICOLON;
    case '.':   return F_PERIOD;
    case '/':   return F_SLASH;
    case '<':   return F_LESS;
    case '>':   return F_GREATER;
    case '?':   return F_QUESTION;
    case ' ':   return F_BLANK;
    }

    break;

  case 'a':   return _SHIN;
  case 'A':   return WAW_H;
  case 'b':   return ZAL;
  case 'c':   return ZE;
  case 'C':   return JE;
  case 'd':   return _YE;
  case 'D':   return _YEE;
  case 'e':   return _SE;
  case 'f':   return _BE;
  case 'g':   return _LAM;
  case 'G':
    if (cmd_gchar(AT_CURSOR) == _LAM ) {
      cmd_pchar(LAM, AT_CURSOR);
      return ALEF_U_H;
    }

    if (F_is_TyB_TyC_TyD(SRC_CMD, AT_CURSOR))
      return ALEF_U_H_;
    else
      return ALEF_U_H;
  case 'h':
    if (cmd_gchar(AT_CURSOR) == _LAM ) {
      cmd_pchar(LA, AT_CURSOR);
      redrawcmdline();
      return K_IGNORE;
    }

    if (F_is_TyB_TyC_TyD(SRC_CMD, AT_CURSOR))
      return ALEF_;
    else
      return ALEF;
  case 'i':
    if (F_is_TyB_TyC_TyD(SRC_CMD, AT_CURSOR))
      return _HE_;
    else
      return _HE;
  case 'j':   return _TE;
  case 'J':
    if (F_is_TyB_TyC_TyD(SRC_CMD, AT_CURSOR))
      return TEE_;
    else
      return TEE;
  case 'k':   return _NOON;
  case 'l':   return _MIM;
  case 'm':   return _PE;
  case 'n':
  case 'N':   return DAL;
  case 'o':   return _XE;
  case 'p':   return _HE_J;
  case 'q':   return _ZAD;
  case 'r':   return _GHAF;
  case 's':   return _SIN;
  case 'S':   return _IE;
  case 't':   return _FE;
  case 'u':
    if (F_is_TyB_TyC_TyD(SRC_CMD, AT_CURSOR))
      return _AYN_;
    else
      return _AYN;
  case 'v':
  case 'V':   return RE;
  case 'w':   return _SAD;
  case 'x':
  case 'X':   return _TA;
  case 'y':
    if (F_is_TyB_TyC_TyD(SRC_CMD, AT_CURSOR))
      return _GHAYN_;
    else
      return _GHAYN;
  case 'z':
  case 'Z':   return _ZA;
  case ';':   return _KAF;
  case '\'':  return _GAF;
  case ',':   return WAW;
  case '[':   return _JIM;
  case ']':   return _CHE;
  }

  return c;
}

/*
 * F_isalpha returns TRUE if 'c' is a Farsi alphabet
 */
int F_isalpha(int c)
{
  return ( c >= TEE_ && c <= _YE)
         || (c >= ALEF_A && c <= YE)
         || (c >= _IE && c <= YE_);
}

/*
 * F_isdigit returns TRUE if 'c' is a Farsi digit
 */
int F_isdigit(int c)
{
  return c >= FARSI_0 && c <= FARSI_9;
}

/*
 * F_ischar returns TRUE if 'c' is a Farsi character.
 */
int F_ischar(int c)
{
  return c >= TEE_ && c <= YE_;
}

void farsi_fkey(cmdarg_T *cap)
{
  int c = cap->cmdchar;

  if (c == K_F8) {
    if (p_altkeymap) {
      if (curwin->w_farsi & W_R_L) {
        p_fkmap = 0;
        do_cmdline_cmd((char_u *)"set norl");
        MSG("");
      } else   {
        p_fkmap = 1;
        do_cmdline_cmd((char_u *)"set rl");
        MSG("");
      }

      curwin->w_farsi = curwin->w_farsi ^ W_R_L;
    }
  }

  if (c == K_F9) {
    if (p_altkeymap && curwin->w_p_rl) {
      curwin->w_farsi = curwin->w_farsi ^ W_CONV;
      if (curwin->w_farsi & W_CONV)
        conv_to_pvim();
      else
        conv_to_pstd();
    }
  }
}
