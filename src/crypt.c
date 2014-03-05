/*
 * Optional encryption support.
 * Mohsin Ahmed, mosh@sasi.com, 98-09-24
 * Based on zip/crypt sources.
 *
 * NOTE FOR USA: Since 2000 exporting this code from the USA is allowed to
 * most countries.  There are a few exceptions, but that still should not be a
 * problem since this code was originally created in Europe and India.
 *
 * Blowfish addition originally made by Mohsin Ahmed,
 * http://www.cs.albany.edu/~mosh 2010-03-14
 * Based on blowfish by Bruce Schneier (http://www.schneier.com/blowfish.html)
 * and sha256 by Christophe Devine.
 */
#include "vim.h"
#include "misc2.h"
#include "blowfish.h"
#include "ex_getln.h"
#include "message.h"
#include "option.h"

/* from zip.h */

typedef unsigned short ush;     /* unsigned 16-bit value */
typedef unsigned long ulg;      /* unsigned 32-bit value */

static void make_crc_tab(void);

static ulg crc_32_tab[256];

/*
 * Fill the CRC table.
 */
static void make_crc_tab(void)                 {
  ulg s,t,v;
  static int done = FALSE;

  if (done)
    return;
  for (t = 0; t < 256; t++) {
    v = t;
    for (s = 0; s < 8; s++)
      v = (v >> 1) ^ ((v & 1) * (ulg)0xedb88320L);
    crc_32_tab[t] = v;
  }
  done = TRUE;
}

#define CRC32(c, b) (crc_32_tab[((int)(c) ^ (b)) & 0xff] ^ ((c) >> 8))

static ulg keys[3]; /* keys defining the pseudo-random sequence */

/*
 * Return the next byte in the pseudo-random sequence.
 */
#define DECRYPT_BYTE_ZIP(t) { \
    ush temp; \
 \
    temp = (ush)keys[2] | 2; \
    t = (int)(((unsigned)(temp * (temp ^ 1U)) >> 8) & 0xff); \
}

/*
 * Update the encryption keys with the next byte of plain text.
 */
#define UPDATE_KEYS_ZIP(c) { \
    keys[0] = CRC32(keys[0], (c)); \
    keys[1] += keys[0] & 0xff; \
    keys[1] = keys[1] * 134775813L + 1; \
    keys[2] = CRC32(keys[2], (int)(keys[1] >> 24)); \
}

static int crypt_busy = 0;
static ulg saved_keys[3];
static int saved_crypt_method;

/*
 * Return int value for crypt method string:
 * 0 for "zip", the old method.  Also for any non-valid value.
 * 1 for "blowfish".
 */
int crypt_method_from_string(char_u *s)
{
  return *s == 'b' ? 1 : 0;
}

/*
 * Get the crypt method for buffer "buf" as a number.
 */
int get_crypt_method(buf_T *buf)
{
  return crypt_method_from_string(*buf->b_p_cm == NUL ? p_cm : buf->b_p_cm);
}

/*
 * Set the crypt method for buffer "buf" to "method" using the int value as
 * returned by crypt_method_from_string().
 */
void set_crypt_method(buf_T *buf, int method)
{
  free_string_option(buf->b_p_cm);
  buf->b_p_cm = vim_strsave((char_u *)(method == 0 ? "zip" : "blowfish"));
}

/*
 * Prepare for initializing encryption.  If already doing encryption then save
 * the state.
 * Must always be called symmetrically with crypt_pop_state().
 */
void crypt_push_state(void)          {
  if (crypt_busy == 1) {
    /* save the state */
    if (use_crypt_method == 0) {
      saved_keys[0] = keys[0];
      saved_keys[1] = keys[1];
      saved_keys[2] = keys[2];
    } else
      bf_crypt_save();
    saved_crypt_method = use_crypt_method;
  } else if (crypt_busy > 1)
    EMSG2(_(e_intern2), "crypt_push_state()");
  ++crypt_busy;
}

/*
 * End encryption.  If doing encryption before crypt_push_state() then restore
 * the saved state.
 * Must always be called symmetrically with crypt_push_state().
 */
void crypt_pop_state(void)          {
  --crypt_busy;
  if (crypt_busy == 1) {
    use_crypt_method = saved_crypt_method;
    if (use_crypt_method == 0) {
      keys[0] = saved_keys[0];
      keys[1] = saved_keys[1];
      keys[2] = saved_keys[2];
    } else
      bf_crypt_restore();
  }
}

/*
 * Encrypt "from[len]" into "to[len]".
 * "from" and "to" can be equal to encrypt in place.
 */
void crypt_encode(char_u *from, size_t len, char_u *to)
{
  size_t i;
  int ztemp, t;

  if (use_crypt_method == 0)
    for (i = 0; i < len; ++i) {
      ztemp = from[i];
      DECRYPT_BYTE_ZIP(t);
      UPDATE_KEYS_ZIP(ztemp);
      to[i] = t ^ ztemp;
    }
  else
    bf_crypt_encode(from, len, to);
}

/*
 * Decrypt "ptr[len]" in place.
 */
void crypt_decode(char_u *ptr, long len)
{
  char_u *p;

  if (use_crypt_method == 0)
    for (p = ptr; p < ptr + len; ++p) {
      ush temp;

      temp = (ush)keys[2] | 2;
      temp = (int)(((unsigned)(temp * (temp ^ 1U)) >> 8) & 0xff);
      UPDATE_KEYS_ZIP(*p ^= temp);
    }
  else
    bf_crypt_decode(ptr, len);
}

/*
 * Initialize the encryption keys and the random header according to
 * the given password.
 * If "passwd" is NULL or empty, don't do anything.
 */
void 
crypt_init_keys (
    char_u *passwd                 /* password string with which to modify keys */
)
{
  if (passwd != NULL && *passwd != NUL) {
    if (use_crypt_method == 0) {
      char_u *p;

      make_crc_tab();
      keys[0] = 305419896L;
      keys[1] = 591751049L;
      keys[2] = 878082192L;
      for (p = passwd; *p!= NUL; ++p) {
        UPDATE_KEYS_ZIP((int)*p);
      }
    } else
      bf_crypt_init_keys(passwd);
  }
}

/*
 * Free an allocated crypt key.  Clear the text to make sure it doesn't stay
 * in memory anywhere.
 */
void free_crypt_key(char_u *key)
{
  char_u *p;

  if (key != NULL) {
    for (p = key; *p != NUL; ++p)
      *p = 0;
    vim_free(key);
  }
}

/*
 * Ask the user for a crypt key.
 * When "store" is TRUE, the new key is stored in the 'key' option, and the
 * 'key' option value is returned: Don't free it.
 * When "store" is FALSE, the typed key is returned in allocated memory.
 * Returns NULL on failure.
 */
char_u *
get_crypt_key (
    int store,
    int twice                  /* Ask for the key twice. */
)
{
  char_u      *p1, *p2 = NULL;
  int round;

  for (round = 0;; ++round) {
    cmdline_star = TRUE;
    cmdline_row = msg_row;
    p1 = getcmdline_prompt(NUL, round == 0
        ? (char_u *)_("Enter encryption key: ")
        : (char_u *)_("Enter same key again: "), 0, EXPAND_NOTHING,
        NULL);
    cmdline_star = FALSE;

    if (p1 == NULL)
      break;

    if (round == twice) {
      if (p2 != NULL && STRCMP(p1, p2) != 0) {
        MSG(_("Keys don't match!"));
        free_crypt_key(p1);
        free_crypt_key(p2);
        p2 = NULL;
        round = -1;                     /* do it again */
        continue;
      }

      if (store) {
        set_option_value((char_u *)"key", 0L, p1, OPT_LOCAL);
        free_crypt_key(p1);
        p1 = curbuf->b_p_key;
      }
      break;
    }
    p2 = p1;
  }

  /* since the user typed this, no need to wait for return */
  if (msg_didout)
    msg_putchar('\n');
  need_wait_return = FALSE;
  msg_didout = FALSE;

  free_crypt_key(p2);
  return p1;
}

