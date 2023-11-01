#include "termkey.h"
#include "termkey-internal.h"

#include <ctype.h>
#include <errno.h>
#ifndef _WIN32
# include <poll.h>
# include <unistd.h>
# include <strings.h>
#endif
#include <string.h>

#include <stdio.h>

#ifdef _MSC_VER
# define strcaseeq(a,b) (_stricmp(a,b) == 0)
#else
# define strcaseeq(a,b) (strcasecmp(a,b) == 0)
#endif

void termkey_check_version(int major, int minor)
{
  if(major != TERMKEY_VERSION_MAJOR) {
    fprintf(stderr, "libtermkey major version mismatch; %d (wants) != %d (library)\n",
        major, TERMKEY_VERSION_MAJOR);
    exit(1);
  }

  if(minor > TERMKEY_VERSION_MINOR) {
    fprintf(stderr, "libtermkey minor version mismatch; %d (wants) > %d (library)\n",
        minor, TERMKEY_VERSION_MINOR);
    exit(1);
  }

  // Happy
}

static struct TermKeyDriver *drivers[] = {
  &termkey_driver_ti,
  &termkey_driver_csi,
  NULL,
};

// Forwards for the "protected" methods
// static void eat_bytes(TermKey *tk, size_t count);
static void emit_codepoint(TermKey *tk, long codepoint, TermKeyKey *key);
static TermKeyResult peekkey_simple(TermKey *tk, TermKeyKey *key, int force, size_t *nbytes);
static TermKeyResult peekkey_mouse(TermKey *tk, TermKeyKey *key, size_t *nbytes);

static TermKeySym register_c0(TermKey *tk, TermKeySym sym, unsigned char ctrl, const char *name);
static TermKeySym register_c0_full(TermKey *tk, TermKeySym sym, int modifier_set, int modifier_mask, unsigned char ctrl, const char *name);

static struct {
  TermKeySym sym;
  const char *name;
} keynames[] = {
  { TERMKEY_SYM_NONE,      "NONE" },
  { TERMKEY_SYM_BACKSPACE, "Backspace" },
  { TERMKEY_SYM_TAB,       "Tab" },
  { TERMKEY_SYM_ENTER,     "Enter" },
  { TERMKEY_SYM_ESCAPE,    "Escape" },
  { TERMKEY_SYM_SPACE,     "Space" },
  { TERMKEY_SYM_DEL,       "DEL" },
  { TERMKEY_SYM_UP,        "Up" },
  { TERMKEY_SYM_DOWN,      "Down" },
  { TERMKEY_SYM_LEFT,      "Left" },
  { TERMKEY_SYM_RIGHT,     "Right" },
  { TERMKEY_SYM_BEGIN,     "Begin" },
  { TERMKEY_SYM_FIND,      "Find" },
  { TERMKEY_SYM_INSERT,    "Insert" },
  { TERMKEY_SYM_DELETE,    "Delete" },
  { TERMKEY_SYM_SELECT,    "Select" },
  { TERMKEY_SYM_PAGEUP,    "PageUp" },
  { TERMKEY_SYM_PAGEDOWN,  "PageDown" },
  { TERMKEY_SYM_HOME,      "Home" },
  { TERMKEY_SYM_END,       "End" },
  { TERMKEY_SYM_CANCEL,    "Cancel" },
  { TERMKEY_SYM_CLEAR,     "Clear" },
  { TERMKEY_SYM_CLOSE,     "Close" },
  { TERMKEY_SYM_COMMAND,   "Command" },
  { TERMKEY_SYM_COPY,      "Copy" },
  { TERMKEY_SYM_EXIT,      "Exit" },
  { TERMKEY_SYM_HELP,      "Help" },
  { TERMKEY_SYM_MARK,      "Mark" },
  { TERMKEY_SYM_MESSAGE,   "Message" },
  { TERMKEY_SYM_MOVE,      "Move" },
  { TERMKEY_SYM_OPEN,      "Open" },
  { TERMKEY_SYM_OPTIONS,   "Options" },
  { TERMKEY_SYM_PRINT,     "Print" },
  { TERMKEY_SYM_REDO,      "Redo" },
  { TERMKEY_SYM_REFERENCE, "Reference" },
  { TERMKEY_SYM_REFRESH,   "Refresh" },
  { TERMKEY_SYM_REPLACE,   "Replace" },
  { TERMKEY_SYM_RESTART,   "Restart" },
  { TERMKEY_SYM_RESUME,    "Resume" },
  { TERMKEY_SYM_SAVE,      "Save" },
  { TERMKEY_SYM_SUSPEND,   "Suspend" },
  { TERMKEY_SYM_UNDO,      "Undo" },
  { TERMKEY_SYM_KP0,       "KP0" },
  { TERMKEY_SYM_KP1,       "KP1" },
  { TERMKEY_SYM_KP2,       "KP2" },
  { TERMKEY_SYM_KP3,       "KP3" },
  { TERMKEY_SYM_KP4,       "KP4" },
  { TERMKEY_SYM_KP5,       "KP5" },
  { TERMKEY_SYM_KP6,       "KP6" },
  { TERMKEY_SYM_KP7,       "KP7" },
  { TERMKEY_SYM_KP8,       "KP8" },
  { TERMKEY_SYM_KP9,       "KP9" },
  { TERMKEY_SYM_KPENTER,   "KPEnter" },
  { TERMKEY_SYM_KPPLUS,    "KPPlus" },
  { TERMKEY_SYM_KPMINUS,   "KPMinus" },
  { TERMKEY_SYM_KPMULT,    "KPMult" },
  { TERMKEY_SYM_KPDIV,     "KPDiv" },
  { TERMKEY_SYM_KPCOMMA,   "KPComma" },
  { TERMKEY_SYM_KPPERIOD,  "KPPeriod" },
  { TERMKEY_SYM_KPEQUALS,  "KPEquals" },
  { 0, NULL },
};

// Mouse event names
static const char *evnames[] = { "Unknown", "Press", "Drag", "Release" };

#define CHARAT(i) (tk->buffer[tk->buffstart + (i)])

#ifdef DEBUG
/* Some internal debugging functions */

static void print_buffer(TermKey *tk)
{
  int i;
  for(i = 0; i < tk->buffcount && i < 20; i++)
    fprintf(stderr, "%02x ", CHARAT(i));
  if(tk->buffcount > 20)
    fprintf(stderr, "...");
}

static void print_key(TermKey *tk, TermKeyKey *key)
{
  switch(key->type) {
  case TERMKEY_TYPE_UNICODE:
    fprintf(stderr, "Unicode codepoint=U+%04lx utf8='%s'", key->code.codepoint, key->utf8);
    break;
  case TERMKEY_TYPE_FUNCTION:
    fprintf(stderr, "Function F%d", key->code.number);
    break;
  case TERMKEY_TYPE_KEYSYM:
    fprintf(stderr, "Keysym sym=%d(%s)", key->code.sym, termkey_get_keyname(tk, key->code.sym));
    break;
  case TERMKEY_TYPE_MOUSE:
    {
      TermKeyMouseEvent ev;
      int button, line, col;
      termkey_interpret_mouse(tk, key, &ev, &button, &line, &col);
      fprintf(stderr, "Mouse ev=%d button=%d pos=(%d,%d)\n", ev, button, line, col);
    }
    break;
  case TERMKEY_TYPE_POSITION:
    {
      int line, col;
      termkey_interpret_position(tk, key, &line, &col);
      fprintf(stderr, "Position report pos=(%d,%d)\n", line, col);
    }
    break;
  case TERMKEY_TYPE_MODEREPORT:
    {
      int initial, mode, value;
      termkey_interpret_modereport(tk, key, &initial, &mode, &value);
      fprintf(stderr, "Mode report mode=%s %d val=%d\n", initial == '?' ? "DEC" : "ANSI", mode, value);
    }
    break;
  case TERMKEY_TYPE_DCS:
    fprintf(stderr, "Device Control String");
    break;
  case TERMKEY_TYPE_OSC:
    fprintf(stderr, "Operating System Control");
    break;
  case TERMKEY_TYPE_UNKNOWN_CSI:
    fprintf(stderr, "unknown CSI\n");
    break;
  }

  int m = key->modifiers;
  fprintf(stderr, " mod=%s%s%s+%02x",
      (m & TERMKEY_KEYMOD_CTRL  ? "C" : ""),
      (m & TERMKEY_KEYMOD_ALT   ? "A" : ""),
      (m & TERMKEY_KEYMOD_SHIFT ? "S" : ""),
      m & ~(TERMKEY_KEYMOD_CTRL|TERMKEY_KEYMOD_ALT|TERMKEY_KEYMOD_SHIFT));
}

static const char *res2str(TermKeyResult res)
{
  static char errorbuffer[256];

  switch(res) {
  case TERMKEY_RES_KEY:
    return "TERMKEY_RES_KEY";
  case TERMKEY_RES_EOF:
    return "TERMKEY_RES_EOF";
  case TERMKEY_RES_AGAIN:
    return "TERMKEY_RES_AGAIN";
  case TERMKEY_RES_NONE:
    return "TERMKEY_RES_NONE";
  case TERMKEY_RES_ERROR:
    snprintf(errorbuffer, sizeof errorbuffer, "TERMKEY_RES_ERROR(errno=%d)\n", errno);
    return (const char*)errorbuffer;
  }

  return "unknown";
}
#endif

/* Similar to snprintf(str, size, "%s", src) except it turns CamelCase into
 * space separated values
 */
static int snprint_cameltospaces(char *str, size_t size, const char *src)
{
  int prev_lower = 0;
  size_t l = 0;
  while(*src && l < size - 1) {
    if(isupper(*src) && prev_lower) {
      if(str)
        str[l++] = ' ';
      if(l >= size - 1)
        break;
    }
    prev_lower = islower(*src);
    str[l++] = tolower(*src++);
  }
  str[l] = 0;
  /* For consistency with snprintf, return the number of bytes that would have
   * been written, excluding '\0' */
  while(*src) {
    if(isupper(*src) && prev_lower) {
      l++;
    }
    prev_lower = islower(*src);
    src++; l++;
  }
  return l;
}

/* Similar to strcmp(str, strcamel, n) except that:
 *    it compares CamelCase in strcamel with space separated values in str;
 *    it takes char**s and updates them
 * n counts bytes of strcamel, not str
 */
static int strpncmp_camel(const char **strp, const char **strcamelp, size_t n)
{
  const char *str = *strp, *strcamel = *strcamelp;
  int prev_lower = 0;

  for( ; (*str || *strcamel) && n; n--) {
    char b = tolower(*strcamel);
    if(isupper(*strcamel) && prev_lower) {
      if(*str != ' ')
        break;
      str++;
      if(*str != b)
        break;
    }
    else
      if(*str != b)
        break;

    prev_lower = islower(*strcamel);

    str++;
    strcamel++;
  }

  *strp = str;
  *strcamelp = strcamel;
  return *str - *strcamel;
}

static TermKey *termkey_alloc(void)
{
  TermKey *tk = malloc(sizeof(TermKey));
  if(!tk)
    return NULL;

  /* Default all the object fields but don't allocate anything */

  tk->fd         = -1;
  tk->flags      = 0;
  tk->canonflags = 0;

  tk->buffer    = NULL;
  tk->buffstart = 0;
  tk->buffcount = 0;
  tk->buffsize  = 256; /* bytes */
  tk->hightide  = 0;

#ifdef HAVE_TERMIOS
  tk->restore_termios_valid = 0;
#endif

  tk->ti_getstr_hook = NULL;
  tk->ti_getstr_hook_data = NULL;

  tk->waittime = 50; /* msec */

  tk->is_closed = 0;
  tk->is_started = 0;

  tk->nkeynames = 64;
  tk->keynames  = NULL;

  for(int i = 0; i < 32; i++)
    tk->c0[i].sym = TERMKEY_SYM_NONE;

  tk->drivers = NULL;

  tk->method.emit_codepoint = &emit_codepoint;
  tk->method.peekkey_simple = &peekkey_simple;
  tk->method.peekkey_mouse  = &peekkey_mouse;

  return tk;
}

static int termkey_init(TermKey *tk, const char *term)
{
  tk->buffer = malloc(tk->buffsize);
  if(!tk->buffer)
    return 0;

  tk->keynames = malloc(sizeof(tk->keynames[0]) * tk->nkeynames);
  if(!tk->keynames)
    goto abort_free_buffer;

  int i;
  for(i = 0; i < tk->nkeynames; i++)
    tk->keynames[i] = NULL;

  for(i = 0; keynames[i].name; i++)
    if(termkey_register_keyname(tk, keynames[i].sym, keynames[i].name) == -1)
      goto abort_free_keynames;

  register_c0(tk, TERMKEY_SYM_TAB,    0x09, NULL);
  register_c0(tk, TERMKEY_SYM_ENTER,  0x0d, NULL);
  register_c0(tk, TERMKEY_SYM_ESCAPE, 0x1b, NULL);

  struct TermKeyDriverNode *tail = NULL;

  for(i = 0; drivers[i]; i++) {
    void *info = (*drivers[i]->new_driver)(tk, term);
    if(!info)
      continue;

#ifdef DEBUG
    fprintf(stderr, "Loading the %s driver...\n", drivers[i]->name);
#endif

    struct TermKeyDriverNode *thisdrv = malloc(sizeof(*thisdrv));
    if(!thisdrv)
      goto abort_free_drivers;

    thisdrv->driver = drivers[i];
    thisdrv->info = info;
    thisdrv->next = NULL;

    if(!tail)
      tk->drivers = thisdrv;
    else
      tail->next = thisdrv;

    tail = thisdrv;

#ifdef DEBUG
    fprintf(stderr, "Loaded %s driver\n", drivers[i]->name);
#endif
  }

  if(!tk->drivers) {
    errno = ENOENT;
    goto abort_free_keynames;
  }

  return 1;

abort_free_drivers:
  for(struct TermKeyDriverNode *p = tk->drivers; p; ) {
    (*p->driver->free_driver)(p->info);
    struct TermKeyDriverNode *next = p->next;
    free(p);
    p = next;
  }

abort_free_keynames:
  free(tk->keynames);

abort_free_buffer:
  free(tk->buffer);

  return 0;
}

TermKey *termkey_new(int fd, int flags)
{
  TermKey *tk = termkey_alloc();
  if(!tk)
    return NULL;

  tk->fd = fd;

  if(!(flags & (TERMKEY_FLAG_RAW|TERMKEY_FLAG_UTF8))) {
    char *e;

    /* Most OSes will set .UTF-8. Some will set .utf8. Try to be fairly
     * generous in parsing these
     */
    if(((e = getenv("LANG")) || (e = getenv("LC_MESSAGES")) || (e = getenv("LC_ALL"))) &&
       (e = strchr(e, '.')) && e++ &&
       (strcaseeq(e, "UTF-8") || strcaseeq(e, "UTF8")))
      flags |= TERMKEY_FLAG_UTF8;
    else
      flags |= TERMKEY_FLAG_RAW;
  }

  termkey_set_flags(tk, flags);

  const char *term = getenv("TERM");

  if(!termkey_init(tk, term))
    goto abort;

  if(!(flags & TERMKEY_FLAG_NOSTART) && !termkey_start(tk))
    goto abort;

  return tk;

abort:
  free(tk);
  return NULL;
}

TermKey *termkey_new_abstract(const char *term, int flags)
{
  TermKey *tk = termkey_alloc();
  if(!tk)
    return NULL;

  tk->fd = -1;

  termkey_set_flags(tk, flags);

  if(!termkey_init(tk, term)) {
    free(tk);
    return NULL;
  }

  if(!(flags & TERMKEY_FLAG_NOSTART) && !termkey_start(tk))
    goto abort;

  return tk;

abort:
  free(tk);
  return NULL;
}

void termkey_free(TermKey *tk)
{
  free(tk->buffer); tk->buffer = NULL;
  free(tk->keynames); tk->keynames = NULL;

  struct TermKeyDriverNode *p;
  for(p = tk->drivers; p; ) {
    (*p->driver->free_driver)(p->info);
    struct TermKeyDriverNode *next = p->next;
    free(p);
    p = next;
  }

  free(tk);
}

void termkey_destroy(TermKey *tk)
{
  if(tk->is_started)
    termkey_stop(tk);

  termkey_free(tk);
}

void termkey_hook_terminfo_getstr(TermKey *tk, TermKey_Terminfo_Getstr_Hook *hookfn, void *data)
{
  tk->ti_getstr_hook = hookfn;
  tk->ti_getstr_hook_data = data;
}

int termkey_start(TermKey *tk)
{
  if(tk->is_started)
    return 1;

#ifdef HAVE_TERMIOS
  if(tk->fd != -1 && !(tk->flags & TERMKEY_FLAG_NOTERMIOS)) {
    struct termios termios;
    if(tcgetattr(tk->fd, &termios) == 0) {
      tk->restore_termios = termios;
      tk->restore_termios_valid = 1;

      termios.c_iflag &= ~(IXON|INLCR|ICRNL);
      termios.c_lflag &= ~(ICANON|ECHO
#ifdef IEXTEN
          | IEXTEN
#endif
      );
      termios.c_cc[VMIN] = 1;
      termios.c_cc[VTIME] = 0;

      if(tk->flags & TERMKEY_FLAG_CTRLC)
        /* want no signal keys at all, so just disable ISIG */
        termios.c_lflag &= ~ISIG;
      else {
        /* Disable Ctrl-\==VQUIT and Ctrl-D==VSUSP but leave Ctrl-C as SIGINT */
        termios.c_cc[VQUIT] = _POSIX_VDISABLE;
        termios.c_cc[VSUSP] = _POSIX_VDISABLE;
        /* Some OSes have Ctrl-Y==VDSUSP */
#ifdef VDSUSP
        termios.c_cc[VDSUSP] = _POSIX_VDISABLE;
#endif
      }

#ifdef DEBUG
      fprintf(stderr, "Setting termios(3) flags\n");
#endif
      tcsetattr(tk->fd, TCSANOW, &termios);
    }
  }
#endif

  struct TermKeyDriverNode *p;
  for(p = tk->drivers; p; p = p->next)
    if(p->driver->start_driver)
      if(!(*p->driver->start_driver)(tk, p->info))
        return 0;

#ifdef DEBUG
  fprintf(stderr, "Drivers started; termkey instance %p is ready\n", tk);
#endif

  tk->is_started = 1;
  return 1;
}

int termkey_stop(TermKey *tk)
{
  if(!tk->is_started)
    return 1;

  struct TermKeyDriverNode *p;
  for(p = tk->drivers; p; p = p->next)
    if(p->driver->stop_driver)
      (*p->driver->stop_driver)(tk, p->info);

#ifdef HAVE_TERMIOS
  if(tk->restore_termios_valid)
    tcsetattr(tk->fd, TCSANOW, &tk->restore_termios);
#endif

  tk->is_started = 0;

  return 1;
}

int termkey_is_started(TermKey *tk)
{
  return tk->is_started;
}

int termkey_get_fd(TermKey *tk)
{
  return tk->fd;
}

int termkey_get_flags(TermKey *tk)
{
  return tk->flags;
}

void termkey_set_flags(TermKey *tk, int newflags)
{
  tk->flags = newflags;

  if(tk->flags & TERMKEY_FLAG_SPACESYMBOL)
    tk->canonflags |= TERMKEY_CANON_SPACESYMBOL;
  else
    tk->canonflags &= ~TERMKEY_CANON_SPACESYMBOL;
}

void termkey_set_waittime(TermKey *tk, int msec)
{
  tk->waittime = msec;
}

int termkey_get_waittime(TermKey *tk)
{
  return tk->waittime;
}

int termkey_get_canonflags(TermKey *tk)
{
  return tk->canonflags;
}

void termkey_set_canonflags(TermKey *tk, int flags)
{
  tk->canonflags = flags;

  if(tk->canonflags & TERMKEY_CANON_SPACESYMBOL)
    tk->flags |= TERMKEY_FLAG_SPACESYMBOL;
  else
    tk->flags &= ~TERMKEY_FLAG_SPACESYMBOL;
}

size_t termkey_get_buffer_size(TermKey *tk)
{
  return tk->buffsize;
}

int termkey_set_buffer_size(TermKey *tk, size_t size)
{
  unsigned char *buffer = realloc(tk->buffer, size);
  if(!buffer)
    return 0;

  tk->buffer = buffer;
  tk->buffsize = size;

  return 1;
}

size_t termkey_get_buffer_remaining(TermKey *tk)
{
  /* Return the total number of free bytes in the buffer, because that's what
   * is available to the user. */
  return tk->buffsize - tk->buffcount;
}

static void eat_bytes(TermKey *tk, size_t count)
{
  if(count >= tk->buffcount) {
    tk->buffstart = 0;
    tk->buffcount = 0;
    return;
  }

  tk->buffstart += count;
  tk->buffcount -= count;
}

static inline unsigned int utf8_seqlen(long codepoint)
{
  if(codepoint < 0x0000080) return 1;
  if(codepoint < 0x0000800) return 2;
  if(codepoint < 0x0010000) return 3;
  if(codepoint < 0x0200000) return 4;
  if(codepoint < 0x4000000) return 5;
  return 6;
}

static void fill_utf8(TermKeyKey *key)
{
  long codepoint = key->code.codepoint;
  int nbytes = utf8_seqlen(codepoint);

  key->utf8[nbytes] = 0;

  // This is easier done backwards
  int b = nbytes;
  while(b > 1) {
    b--;
    key->utf8[b] = 0x80 | (codepoint & 0x3f);
    codepoint >>= 6;
  }

  switch(nbytes) {
    case 1: key->utf8[0] =        (codepoint & 0x7f); break;
    case 2: key->utf8[0] = 0xc0 | (codepoint & 0x1f); break;
    case 3: key->utf8[0] = 0xe0 | (codepoint & 0x0f); break;
    case 4: key->utf8[0] = 0xf0 | (codepoint & 0x07); break;
    case 5: key->utf8[0] = 0xf8 | (codepoint & 0x03); break;
    case 6: key->utf8[0] = 0xfc | (codepoint & 0x01); break;
  }
}

#define UTF8_INVALID 0xFFFD
static TermKeyResult parse_utf8(const unsigned char *bytes, size_t len, long *cp, size_t *nbytep)
{
  unsigned int nbytes;

  unsigned char b0 = bytes[0];

  if(b0 < 0x80) {
    // Single byte ASCII
    *cp = b0;
    *nbytep = 1;
    return TERMKEY_RES_KEY;
  }
  else if(b0 < 0xc0) {
    // Starts with a continuation byte - that's not right
    *cp = UTF8_INVALID;
    *nbytep = 1;
    return TERMKEY_RES_KEY;
  }
  else if(b0 < 0xe0) {
    nbytes = 2;
    *cp = b0 & 0x1f;
  }
  else if(b0 < 0xf0) {
    nbytes = 3;
    *cp = b0 & 0x0f;
  }
  else if(b0 < 0xf8) {
    nbytes = 4;
    *cp = b0 & 0x07;
  }
  else if(b0 < 0xfc) {
    nbytes = 5;
    *cp = b0 & 0x03;
  }
  else if(b0 < 0xfe) {
    nbytes = 6;
    *cp = b0 & 0x01;
  }
  else {
    *cp = UTF8_INVALID;
    *nbytep = 1;
    return TERMKEY_RES_KEY;
  }

  for(unsigned int b = 1; b < nbytes; b++) {
    unsigned char cb;

    if(b >= len)
      return TERMKEY_RES_AGAIN;

    cb = bytes[b];
    if(cb < 0x80 || cb >= 0xc0) {
      *cp = UTF8_INVALID;
      *nbytep = b;
      return TERMKEY_RES_KEY;
    }

    *cp <<= 6;
    *cp |= cb & 0x3f;
  }

  // Check for overlong sequences
  if(nbytes > utf8_seqlen(*cp))
    *cp = UTF8_INVALID;

  // Check for UTF-16 surrogates or invalid *cps
  if((*cp >= 0xD800 && *cp <= 0xDFFF) ||
     *cp == 0xFFFE ||
     *cp == 0xFFFF)
    *cp = UTF8_INVALID;

  *nbytep = nbytes;
  return TERMKEY_RES_KEY;
}

static void emit_codepoint(TermKey *tk, long codepoint, TermKeyKey *key)
{
  if(codepoint == 0) {
    // ASCII NUL = Ctrl-Space
    key->type = TERMKEY_TYPE_KEYSYM;
    key->code.sym = TERMKEY_SYM_SPACE;
    key->modifiers = TERMKEY_KEYMOD_CTRL;
  }
  else if(codepoint < 0x20) {
    // C0 range
    key->code.codepoint = 0;
    key->modifiers = 0;

    if(!(tk->flags & TERMKEY_FLAG_NOINTERPRET) && tk->c0[codepoint].sym != TERMKEY_SYM_UNKNOWN) {
      key->code.sym = tk->c0[codepoint].sym;
      key->modifiers |= tk->c0[codepoint].modifier_set;
    }

    if(!key->code.sym) {
      key->type = TERMKEY_TYPE_UNICODE;
      /* Generically modified Unicode ought not report the SHIFT state, or else
       * we get into complications trying to report Shift-; vs : and so on...
       * In order to be able to represent Ctrl-Shift-A as CTRL modified
       * unicode A, we need to call Ctrl-A simply 'a', lowercase
       */
      if(codepoint+0x40 >= 'A' && codepoint+0x40 <= 'Z')
        // it's a letter - use lowercase instead
        key->code.codepoint = codepoint + 0x60;
      else
        key->code.codepoint = codepoint + 0x40;
      key->modifiers = TERMKEY_KEYMOD_CTRL;
    }
    else {
      key->type = TERMKEY_TYPE_KEYSYM;
    }
  }
  else if(codepoint == 0x7f && !(tk->flags & TERMKEY_FLAG_NOINTERPRET)) {
    // ASCII DEL
    key->type = TERMKEY_TYPE_KEYSYM;
    key->code.sym = TERMKEY_SYM_DEL;
    key->modifiers = 0;
  }
  else if(codepoint >= 0x20 && codepoint < 0x80) {
    // ASCII lowbyte range
    key->type = TERMKEY_TYPE_UNICODE;
    key->code.codepoint = codepoint;
    key->modifiers = 0;
  }
  else if(codepoint >= 0x80 && codepoint < 0xa0) {
    // UTF-8 never starts with a C1 byte. So we can be sure of these
    key->type = TERMKEY_TYPE_UNICODE;
    key->code.codepoint = codepoint - 0x40;
    key->modifiers = TERMKEY_KEYMOD_CTRL|TERMKEY_KEYMOD_ALT;
  }
  else {
    // UTF-8 codepoint
    key->type = TERMKEY_TYPE_UNICODE;
    key->code.codepoint = codepoint;
    key->modifiers = 0;
  }

  termkey_canonicalise(tk, key);

  if(key->type == TERMKEY_TYPE_UNICODE)
    fill_utf8(key);
}

void termkey_canonicalise(TermKey *tk, TermKeyKey *key)
{
  int flags = tk->canonflags;

  if(flags & TERMKEY_CANON_SPACESYMBOL) {
    if(key->type == TERMKEY_TYPE_UNICODE && key->code.codepoint == 0x20) {
      key->type     = TERMKEY_TYPE_KEYSYM;
      key->code.sym = TERMKEY_SYM_SPACE;
    }
  }
  else {
    if(key->type == TERMKEY_TYPE_KEYSYM && key->code.sym == TERMKEY_SYM_SPACE) {
      key->type           = TERMKEY_TYPE_UNICODE;
      key->code.codepoint = 0x20;
      fill_utf8(key);
    }
  }

  if(flags & TERMKEY_CANON_DELBS) {
    if(key->type == TERMKEY_TYPE_KEYSYM && key->code.sym == TERMKEY_SYM_DEL) {
      key->code.sym = TERMKEY_SYM_BACKSPACE;
    }
  }
}

static TermKeyResult peekkey(TermKey *tk, TermKeyKey *key, int force, size_t *nbytep)
{
  int again = 0;

  if(!tk->is_started) {
    errno = EINVAL;
    return TERMKEY_RES_ERROR;
  }

#ifdef DEBUG
  fprintf(stderr, "getkey(force=%d): buffer ", force);
  print_buffer(tk);
  fprintf(stderr, "\n");
#endif

  if(tk->hightide) {
    tk->buffstart += tk->hightide;
    tk->buffcount -= tk->hightide;
    tk->hightide = 0;
  }

  TermKeyResult ret;
  struct TermKeyDriverNode *p;
  for(p = tk->drivers; p; p = p->next) {
    ret = (p->driver->peekkey)(tk, p->info, key, force, nbytep);

#ifdef DEBUG
    fprintf(stderr, "Driver %s yields %s\n", p->driver->name, res2str(ret));
#endif

    switch(ret) {
    case TERMKEY_RES_KEY:
#ifdef DEBUG
      print_key(tk, key); fprintf(stderr, "\n");
#endif
      // Slide the data down to stop it running away
      {
        size_t halfsize = tk->buffsize / 2;

        if(tk->buffstart > halfsize) {
          memcpy(tk->buffer, tk->buffer + halfsize, halfsize);
          tk->buffstart -= halfsize;
        }
      }

      /* fallthrough */
    case TERMKEY_RES_EOF:
    case TERMKEY_RES_ERROR:
      return ret;

    case TERMKEY_RES_AGAIN:
      if(!force)
        again = 1;

      /* fallthrough */
    case TERMKEY_RES_NONE:
      break;
    }
  }

  if(again)
    return TERMKEY_RES_AGAIN;

  ret = peekkey_simple(tk, key, force, nbytep);

#ifdef DEBUG
  fprintf(stderr, "getkey_simple(force=%d) yields %s\n", force, res2str(ret));
  if(ret == TERMKEY_RES_KEY) {
    print_key(tk, key); fprintf(stderr, "\n");
  }
#endif

  return ret;
}

static TermKeyResult peekkey_simple(TermKey *tk, TermKeyKey *key, int force, size_t *nbytep)
{
  if(tk->buffcount == 0)
    return tk->is_closed ? TERMKEY_RES_EOF : TERMKEY_RES_NONE;

  unsigned char b0 = CHARAT(0);

  if(b0 == 0x1b) {
    // Escape-prefixed value? Might therefore be Alt+key
    if(tk->buffcount == 1) {
      // This might be an <Esc> press, or it may want to be part of a longer
      // sequence
      if(!force)
        return TERMKEY_RES_AGAIN;

      (*tk->method.emit_codepoint)(tk, b0, key);
      *nbytep = 1;
      return TERMKEY_RES_KEY;
    }

    // Try another key there
    tk->buffstart++;
    tk->buffcount--;

    // Run the full driver
    TermKeyResult metakey_result = peekkey(tk, key, force, nbytep);

    tk->buffstart--;
    tk->buffcount++;

    switch(metakey_result) {
      case TERMKEY_RES_KEY:
        key->modifiers |= TERMKEY_KEYMOD_ALT;
        (*nbytep)++;
        break;

      case TERMKEY_RES_NONE:
      case TERMKEY_RES_EOF:
      case TERMKEY_RES_AGAIN:
      case TERMKEY_RES_ERROR:
        break;
    }

    return metakey_result;
  }
  else if(b0 < 0xa0) {
    // Single byte C0, G0 or C1 - C1 is never UTF-8 initial byte
    (*tk->method.emit_codepoint)(tk, b0, key);
    *nbytep = 1;
    return TERMKEY_RES_KEY;
  }
  else if(tk->flags & TERMKEY_FLAG_UTF8) {
    // Some UTF-8
    long codepoint;
    TermKeyResult res = parse_utf8(tk->buffer + tk->buffstart, tk->buffcount, &codepoint, nbytep);

    if(res == TERMKEY_RES_AGAIN && force) {
      /* There weren't enough bytes for a complete UTF-8 sequence but caller
       * demands an answer. About the best thing we can do here is eat as many
       * bytes as we have, and emit a UTF8_INVALID. If the remaining bytes
       * arrive later, they'll be invalid too.
       */
      codepoint = UTF8_INVALID;
      *nbytep = tk->buffcount;
      res = TERMKEY_RES_KEY;
    }

    key->type = TERMKEY_TYPE_UNICODE;
    key->modifiers = 0;
    (*tk->method.emit_codepoint)(tk, codepoint, key);
    return res;
  }
  else {
    // Non UTF-8 case - just report the raw byte
    key->type = TERMKEY_TYPE_UNICODE;
    key->code.codepoint = b0;
    key->modifiers = 0;

    key->utf8[0] = key->code.codepoint;
    key->utf8[1] = 0;

    *nbytep = 1;

    return TERMKEY_RES_KEY;
  }
}

static TermKeyResult peekkey_mouse(TermKey *tk, TermKeyKey *key, size_t *nbytep)
{
  if(tk->buffcount < 3)
    return TERMKEY_RES_AGAIN;

  key->type = TERMKEY_TYPE_MOUSE;
  key->code.mouse[0] = CHARAT(0) - 0x20;
  key->code.mouse[1] = CHARAT(1) - 0x20;
  key->code.mouse[2] = CHARAT(2) - 0x20;
  key->code.mouse[3] = 0;

  key->modifiers     = (key->code.mouse[0] & 0x1c) >> 2;
  key->code.mouse[0] &= ~0x1c;

  *nbytep = 3;
  return TERMKEY_RES_KEY;
}

TermKeyResult termkey_getkey(TermKey *tk, TermKeyKey *key)
{
  size_t nbytes = 0;
  TermKeyResult ret = peekkey(tk, key, 0, &nbytes);

  if(ret == TERMKEY_RES_KEY)
    eat_bytes(tk, nbytes);

  if(ret == TERMKEY_RES_AGAIN)
    /* Call peekkey() again in force mode to obtain whatever it can */
    (void)peekkey(tk, key, 1, &nbytes);
    /* Don't eat it yet though */

  return ret;
}

TermKeyResult termkey_getkey_force(TermKey *tk, TermKeyKey *key)
{
  size_t nbytes = 0;
  TermKeyResult ret = peekkey(tk, key, 1, &nbytes);

  if(ret == TERMKEY_RES_KEY)
    eat_bytes(tk, nbytes);

  return ret;
}

#ifndef _WIN32
TermKeyResult termkey_waitkey(TermKey *tk, TermKeyKey *key)
{
  if(tk->fd == -1) {
    errno = EBADF;
    return TERMKEY_RES_ERROR;
  }

  while(1) {
    TermKeyResult ret = termkey_getkey(tk, key);

    switch(ret) {
      case TERMKEY_RES_KEY:
      case TERMKEY_RES_EOF:
      case TERMKEY_RES_ERROR:
        return ret;

      case TERMKEY_RES_NONE:
        ret = termkey_advisereadable(tk);
        if(ret == TERMKEY_RES_ERROR)
          return ret;
        break;

      case TERMKEY_RES_AGAIN:
        {
          if(tk->is_closed)
            // We're closed now. Never going to get more bytes so just go with
            // what we have
            return termkey_getkey_force(tk, key);

          struct pollfd fd;

retry:
          fd.fd = tk->fd;
          fd.events = POLLIN;

          int pollret = poll(&fd, 1, tk->waittime);
          if(pollret == -1) {
            if(errno == EINTR && !(tk->flags & TERMKEY_FLAG_EINTR))
              goto retry;

            return TERMKEY_RES_ERROR;
          }

          if(fd.revents & (POLLIN|POLLHUP|POLLERR))
            ret = termkey_advisereadable(tk);
          else
            ret = TERMKEY_RES_NONE;

          if(ret == TERMKEY_RES_ERROR)
            return ret;
          if(ret == TERMKEY_RES_NONE)
            return termkey_getkey_force(tk, key);
        }
        break;
    }
  }

  /* UNREACHABLE */
}
#endif

TermKeyResult termkey_advisereadable(TermKey *tk)
{
  ssize_t len;

  if(tk->fd == -1) {
    errno = EBADF;
    return TERMKEY_RES_ERROR;
  }

  if(tk->buffstart) {
    memmove(tk->buffer, tk->buffer + tk->buffstart, tk->buffcount);
    tk->buffstart = 0;
  }

  /* Not expecting it ever to be greater but doesn't hurt to handle that */
  if(tk->buffcount >= tk->buffsize) {
    errno = ENOMEM;
    return TERMKEY_RES_ERROR;
  }

retry:
  len = read(tk->fd, tk->buffer + tk->buffcount, tk->buffsize - tk->buffcount);

  if(len == -1) {
    if(errno == EAGAIN)
      return TERMKEY_RES_NONE;
    else if(errno == EINTR && !(tk->flags & TERMKEY_FLAG_EINTR))
      goto retry;
    else
      return TERMKEY_RES_ERROR;
  }
  else if(len < 1) {
    tk->is_closed = 1;
    return TERMKEY_RES_NONE;
  }
  else {
    tk->buffcount += len;
    return TERMKEY_RES_AGAIN;
  }
}

size_t termkey_push_bytes(TermKey *tk, const char *bytes, size_t len)
{
  if(tk->buffstart) {
    memmove(tk->buffer, tk->buffer + tk->buffstart, tk->buffcount);
    tk->buffstart = 0;
  }

  /* Not expecting it ever to be greater but doesn't hurt to handle that */
  if(tk->buffcount >= tk->buffsize) {
    errno = ENOMEM;
    return (size_t)-1;
  }

  if(len > tk->buffsize - tk->buffcount)
    len = tk->buffsize - tk->buffcount;

  // memcpy(), not strncpy() in case of null bytes in input
  memcpy(tk->buffer + tk->buffcount, bytes, len);
  tk->buffcount += len;

  return len;
}

TermKeySym termkey_register_keyname(TermKey *tk, TermKeySym sym, const char *name)
{
  if(!sym)
    sym = tk->nkeynames;

  if(sym >= tk->nkeynames) {
    const char **new_keynames = realloc(tk->keynames, sizeof(new_keynames[0]) * (sym + 1));
    if(!new_keynames)
      return -1;

    tk->keynames = new_keynames;

    // Fill in the hole
    for(int i = tk->nkeynames; i < sym; i++)
      tk->keynames[i] = NULL;

    tk->nkeynames = sym + 1;
  }

  tk->keynames[sym] = name;

  return sym;
}

const char *termkey_get_keyname(TermKey *tk, TermKeySym sym)
{
  if(sym == TERMKEY_SYM_UNKNOWN)
    return "UNKNOWN";

  if(sym < tk->nkeynames)
    return tk->keynames[sym];

  return "UNKNOWN";
}

static const char *termkey_lookup_keyname_format(TermKey *tk, const char *str, TermKeySym *sym, TermKeyFormat format)
{
  /* We store an array, so we can't do better than a linear search. Doesn't
   * matter because user won't be calling this too often */

  for(*sym = 0; *sym < tk->nkeynames; (*sym)++) {
    const char *thiskey = tk->keynames[*sym];
    if(!thiskey)
      continue;
    size_t len = strlen(thiskey);
    if(format & TERMKEY_FORMAT_LOWERSPACE) {
      const char *thisstr = str;
      if(strpncmp_camel(&thisstr, &thiskey, len) == 0)
          return thisstr;
    }
    else {
      if(strncmp(str, thiskey, len) == 0)
        return (char *)str + len;
    }
  }

  return NULL;
}

const char *termkey_lookup_keyname(TermKey *tk, const char *str, TermKeySym *sym)
{
  return termkey_lookup_keyname_format(tk, str, sym, 0);
}

TermKeySym termkey_keyname2sym(TermKey *tk, const char *keyname)
{
  TermKeySym sym;
  const char *endp = termkey_lookup_keyname(tk, keyname, &sym);
  if(!endp || endp[0])
    return TERMKEY_SYM_UNKNOWN;
  return sym;
}

static TermKeySym register_c0(TermKey *tk, TermKeySym sym, unsigned char ctrl, const char *name)
{
  return register_c0_full(tk, sym, 0, 0, ctrl, name);
}

static TermKeySym register_c0_full(TermKey *tk, TermKeySym sym, int modifier_set, int modifier_mask, unsigned char ctrl, const char *name)
{
  if(ctrl >= 0x20) {
    errno = EINVAL;
    return -1;
  }

  if(name)
    sym = termkey_register_keyname(tk, sym, name);

  tk->c0[ctrl].sym = sym;
  tk->c0[ctrl].modifier_set = modifier_set;
  tk->c0[ctrl].modifier_mask = modifier_mask;

  return sym;
}

/* Previous name for this function
 * No longer declared in termkey.h but it remains in the compiled library for
 * backward-compatibility reasons.
 */
size_t termkey_snprint_key(TermKey *tk, char *buffer, size_t len, TermKeyKey *key, TermKeyFormat format)
{
  return termkey_strfkey(tk, buffer, len, key, format);
}

static struct modnames {
  const char *shift, *alt, *ctrl;
}
modnames[] = {
  { "S",     "A",    "C" },    // 0
  { "Shift", "Alt",  "Ctrl" }, // LONGMOD
  { "S",     "M",    "C" },    // ALTISMETA
  { "Shift", "Meta", "Ctrl" }, // ALTISMETA+LONGMOD
  { "s",     "a",    "c" },    // LOWERMOD
  { "shift", "alt",  "ctrl" }, // LOWERMOD+LONGMOD
  { "s",     "m",    "c" },    // LOWERMOD+ALTISMETA
  { "shift", "meta", "ctrl" }, // LOWERMOD+ALTISMETA+LONGMOD
};

size_t termkey_strfkey(TermKey *tk, char *buffer, size_t len, TermKeyKey *key, TermKeyFormat format)
{
  size_t pos = 0;
  size_t l = 0;

  struct modnames *mods = &modnames[!!(format & TERMKEY_FORMAT_LONGMOD) +
                                    !!(format & TERMKEY_FORMAT_ALTISMETA) * 2 +
                                    !!(format & TERMKEY_FORMAT_LOWERMOD) * 4];

  int wrapbracket = (format & TERMKEY_FORMAT_WRAPBRACKET) &&
                    (key->type != TERMKEY_TYPE_UNICODE || key->modifiers != 0);

  char sep = (format & TERMKEY_FORMAT_SPACEMOD) ? ' ' : '-';

  if(format & TERMKEY_FORMAT_CARETCTRL &&
     key->type == TERMKEY_TYPE_UNICODE &&
     key->modifiers == TERMKEY_KEYMOD_CTRL) {
    long codepoint = key->code.codepoint;

    // Handle some of the special cases first
    if(codepoint >= 'a' && codepoint <= 'z') {
      l = snprintf(buffer + pos, len - pos, wrapbracket ? "<^%c>" : "^%c", (char)codepoint - 0x20);
      if(l <= 0) return pos;
      pos += l;
      return pos;
    }
    else if((codepoint >= '@' && codepoint < 'A') ||
            (codepoint > 'Z' && codepoint <= '_')) {
      l = snprintf(buffer + pos, len - pos, wrapbracket ? "<^%c>" : "^%c", (char)codepoint);
      if(l <= 0) return pos;
      pos += l;
      return pos;
    }
  }

  if(wrapbracket) {
    l = snprintf(buffer + pos, len - pos, "<");
    if(l <= 0) return pos;
    pos += l;
  }

  if(key->modifiers & TERMKEY_KEYMOD_ALT) {
    l = snprintf(buffer + pos, len - pos, "%s%c", mods->alt, sep);
    if(l <= 0) return pos;
    pos += l;
  }

  if(key->modifiers & TERMKEY_KEYMOD_CTRL) {
    l = snprintf(buffer + pos, len - pos, "%s%c", mods->ctrl, sep);
    if(l <= 0) return pos;
    pos += l;
  }

  if(key->modifiers & TERMKEY_KEYMOD_SHIFT) {
    l = snprintf(buffer + pos, len - pos, "%s%c", mods->shift, sep);
    if(l <= 0) return pos;
    pos += l;
  }

  switch(key->type) {
  case TERMKEY_TYPE_UNICODE:
    if(!key->utf8[0]) // In case of user-supplied key structures
      fill_utf8(key);
    l = snprintf(buffer + pos, len - pos, "%s", key->utf8);
    break;
  case TERMKEY_TYPE_KEYSYM:
    {
      const char *name = termkey_get_keyname(tk, key->code.sym);
      if(format & TERMKEY_FORMAT_LOWERSPACE)
        l = snprint_cameltospaces(buffer + pos, len - pos, name);
      else
        l = snprintf(buffer + pos, len - pos, "%s", name);
    }
    break;
  case TERMKEY_TYPE_FUNCTION:
    l = snprintf(buffer + pos, len - pos, "%c%d",
        (format & TERMKEY_FORMAT_LOWERSPACE ? 'f' : 'F'), key->code.number);
    break;
  case TERMKEY_TYPE_MOUSE:
    {
      TermKeyMouseEvent ev;
      int button;
      int line, col;
      termkey_interpret_mouse(tk, key, &ev, &button, &line, &col);

      l = snprintf(buffer + pos, len - pos, "Mouse%s(%d)",
          evnames[ev], button);

      if(format & TERMKEY_FORMAT_MOUSE_POS) {
        if(l <= 0) return pos;
        pos += l;

        l = snprintf(buffer + pos, len - pos, " @ (%u,%u)", col, line);
      }
    }
    break;
  case TERMKEY_TYPE_POSITION:
    l = snprintf(buffer + pos, len - pos, "Position");
    break;
  case TERMKEY_TYPE_MODEREPORT:
    {
      int initial, mode, value;
      termkey_interpret_modereport(tk, key, &initial, &mode, &value);
      if(initial)
        l = snprintf(buffer + pos, len - pos, "Mode(%c%d=%d)", initial, mode, value);
      else
        l = snprintf(buffer + pos, len - pos, "Mode(%d=%d)", mode, value);
    }
  case TERMKEY_TYPE_DCS:
    l = snprintf(buffer + pos, len - pos, "DCS");
    break;
  case TERMKEY_TYPE_OSC:
    l = snprintf(buffer + pos, len - pos, "OSC");
    break;
  case TERMKEY_TYPE_UNKNOWN_CSI:
    l = snprintf(buffer + pos, len - pos, "CSI %c", key->code.number & 0xff);
    break;
  }

  if(l <= 0) return pos;
  pos += l;

  if(wrapbracket) {
    l = snprintf(buffer + pos, len - pos, ">");
    if(l <= 0) return pos;
    pos += l;
  }

  return pos;
}

const char *termkey_strpkey(TermKey *tk, const char *str, TermKeyKey *key, TermKeyFormat format)
{
  struct modnames *mods = &modnames[!!(format & TERMKEY_FORMAT_LONGMOD) +
                                    !!(format & TERMKEY_FORMAT_ALTISMETA) * 2 +
                                    !!(format & TERMKEY_FORMAT_LOWERMOD) * 4];

  key->modifiers = 0;

  if((format & TERMKEY_FORMAT_CARETCTRL) && str[0] == '^' && str[1]) {
    str = termkey_strpkey(tk, str+1, key, format & ~TERMKEY_FORMAT_CARETCTRL);

    if(!str ||
       key->type != TERMKEY_TYPE_UNICODE ||
       key->code.codepoint < '@' || key->code.codepoint > '_' ||
       key->modifiers != 0)
      return NULL;

    if(key->code.codepoint >= 'A' && key->code.codepoint <= 'Z')
      key->code.codepoint += 0x20;
    key->modifiers = TERMKEY_KEYMOD_CTRL;
    fill_utf8(key);
    return (char *)str;
  }

  const char *sep_at;

  while((sep_at = strchr(str, (format & TERMKEY_FORMAT_SPACEMOD) ? ' ' : '-'))) {
    size_t n = sep_at - str;

    if(n == strlen(mods->alt) && strncmp(mods->alt, str, n) == 0)
      key->modifiers |= TERMKEY_KEYMOD_ALT;
    else if(n == strlen(mods->ctrl) && strncmp(mods->ctrl, str, n) == 0)
      key->modifiers |= TERMKEY_KEYMOD_CTRL;
    else if(n == strlen(mods->shift) && strncmp(mods->shift, str, n) == 0)
      key->modifiers |= TERMKEY_KEYMOD_SHIFT;

    else
      break;

    str = sep_at + 1;
  }

  size_t nbytes;
  ssize_t snbytes;
  const char *endstr;
  int button;
  char event_name[32];

  if((endstr = termkey_lookup_keyname_format(tk, str, &key->code.sym, format))) {
    key->type = TERMKEY_TYPE_KEYSYM;
    str = endstr;
  }
  else if(sscanf(str, "F%d%zn", &key->code.number, &snbytes) == 1) {
    key->type = TERMKEY_TYPE_FUNCTION;
    str += snbytes;
  }
  else if(sscanf(str, "Mouse%31[^(](%d)%zn", event_name, &button, &snbytes) == 2) {
    str += snbytes;
    key->type = TERMKEY_TYPE_MOUSE;

    TermKeyMouseEvent ev = TERMKEY_MOUSE_UNKNOWN;
    for(size_t i = 0; i < sizeof(evnames)/sizeof(evnames[0]); i++) {
      if(strcmp(evnames[i], event_name) == 0) {
        ev = TERMKEY_MOUSE_UNKNOWN + i;
        break;
      }
    }

    int code;
    switch(ev) {
    case TERMKEY_MOUSE_PRESS:
    case TERMKEY_MOUSE_DRAG:
      code = button - 1;
      if(ev == TERMKEY_MOUSE_DRAG) {
        code |= 0x20;
      }
      break;
    case TERMKEY_MOUSE_RELEASE:
      code = 3;
      break;
    default:
      code = 128;
      break;
    }
    key->code.mouse[0] = code;

    unsigned int line = 0, col = 0;
    if((format & TERMKEY_FORMAT_MOUSE_POS) && sscanf(str, " @ (%u,%u)%zn", &col, &line, &snbytes) == 2) {
      str += snbytes;
    }
    termkey_key_set_linecol(key, col, line);
  }
  // Unicode must be last
  else if(parse_utf8((unsigned const char *)str, strlen(str), &key->code.codepoint, &nbytes) == TERMKEY_RES_KEY) {
    key->type = TERMKEY_TYPE_UNICODE;
    fill_utf8(key);
    str += nbytes;
  }
  else
    return NULL;

  termkey_canonicalise(tk, key);

  return (char *)str;
}

int termkey_keycmp(TermKey *tk, const TermKeyKey *key1p, const TermKeyKey *key2p)
{
  /* Copy the key structs since we'll be modifying them */
  TermKeyKey key1 = *key1p, key2 = *key2p;

  termkey_canonicalise(tk, &key1);
  termkey_canonicalise(tk, &key2);

  if(key1.type != key2.type)
    return key1.type - key2.type;

  switch(key1.type) {
    case TERMKEY_TYPE_UNICODE:
      if(key1.code.codepoint != key2.code.codepoint)
        return key1.code.codepoint - key2.code.codepoint;
      break;
    case TERMKEY_TYPE_KEYSYM:
      if(key1.code.sym != key2.code.sym)
        return key1.code.sym - key2.code.sym;
      break;
    case TERMKEY_TYPE_FUNCTION:
    case TERMKEY_TYPE_UNKNOWN_CSI:
      if(key1.code.number != key2.code.number)
        return key1.code.number - key2.code.number;
      break;
    case TERMKEY_TYPE_MOUSE:
      {
        int cmp = strncmp(key1.code.mouse, key2.code.mouse, 4);
        if(cmp != 0)
          return cmp;
      }
      break;
    case TERMKEY_TYPE_POSITION:
      {
        int line1, col1, line2, col2;
        termkey_interpret_position(tk, &key1, &line1, &col1);
        termkey_interpret_position(tk, &key2, &line2, &col2);
        if(line1 != line2)
          return line1 - line2;
        return col1 - col2;
      }
      break;
    case TERMKEY_TYPE_DCS:
    case TERMKEY_TYPE_OSC:
      return key1p - key2p;
    case TERMKEY_TYPE_MODEREPORT:
      {
        int initial1, initial2, mode1, mode2, value1, value2;
        termkey_interpret_modereport(tk, &key1, &initial1, &mode1, &value1);
        termkey_interpret_modereport(tk, &key2, &initial2, &mode2, &value2);
        if(initial1 != initial2)
          return initial1 - initial2;
        if(mode1 != mode2)
          return mode1 - mode2;
        return value1 - value2;
      }
  }

  return key1.modifiers - key2.modifiers;
}
