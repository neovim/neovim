#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <uv.h>

#include "nvim/charset.h"
#include "nvim/memory.h"
#include "nvim/tui/terminfo.h"
#include "nvim/tui/termkey/driver-ti.h"
#include "nvim/tui/termkey/termkey-internal.h"
#include "nvim/tui/termkey/termkey_defs.h"

#ifndef _WIN32
# include <unistd.h>
#else
# include <io.h>
#endif

#include "tui/termkey/driver-ti.c.generated.h"

#define streq(a, b) (!strcmp(a, b))

#define MAX_FUNCNAME 9

static struct {
  TerminfoKey ti_key;
  const char *funcname;
  TermKeyType type;
  TermKeySym sym;
  int mods;
} funcs[] = {
  // THIS LIST MUST REMAIN SORTED!
  // nvim note: entries commented out without further note are not recognized by nvim.
#define KDEF(x) kTermKey_##x, #x
  { KDEF(backspace), TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_BACKSPACE, 0 },
  { KDEF(beg),       TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_BEGIN,     0 },
  { KDEF(btab),      TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_TAB,       TERMKEY_KEYMOD_SHIFT },
  // { KDEF(cancel),    TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_CANCEL,    0 },
  { KDEF(clear),     TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_CLEAR,     0 },
  // { KDEF(close),     TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_CLOSE,     0 },
  // { KDEF(command),   TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_COMMAND,   0 },
  // { KDEF(copy),      TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_COPY,      0 },
  { KDEF(dc),        TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_DELETE,    0 },
  // { KDEF(down),      TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_DOWN,      0 },  // redundant, driver-csi
  { KDEF(end),       TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_END,       0 },
  // { KDEF(enter),     TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_ENTER,     0 },
  // { KDEF(exit),      TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_EXIT,      0 },
  { KDEF(find),      TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_FIND,      0 },
  // { KDEF(help),      TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_HELP,      0 },
  { KDEF(home),      TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_HOME,      0 },
  { KDEF(ic),        TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_INSERT,    0 },
  // { KDEF(left),      TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_LEFT,      0 }, // redundant: driver-csi
  // { KDEF(mark),      TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_MARK,      0 },
  // { KDEF(message),   TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_MESSAGE,   0 },
  // { KDEF(move),      TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_MOVE,      0 },
  // { KDEF(next),      TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_PAGEDOWN,  0 },  // use "npage" right below
  { KDEF(npage),     TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_PAGEDOWN,  0 },
  // { KDEF(open),      TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_OPEN,      0 },
  // { KDEF(options),   TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_OPTIONS,   0 },
  { KDEF(ppage),     TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_PAGEUP,    0 },
  // { KDEF(previous),  TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_PAGEUP,    0 },  // use "ppage" right above
  // { KDEF(print),     TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_PRINT,     0 },
  // { KDEF(redo),      TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_REDO,      0 },
  // { KDEF(reference), TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_REFERENCE, 0 },
  // { KDEF(refresh),   TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_REFRESH,   0 },
  // { KDEF(replace),   TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_REPLACE,   0 },
  // { KDEF(restart),   TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_RESTART,   0 },
  // { KDEF(resume),    TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_RESUME,    0 },
  // { KDEF(right),     TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_RIGHT,     0 }, // redundant, driver-csi
  // { KDEF(save),      TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_SAVE,      0 },
  { KDEF(select),    TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_SELECT,    0 },
  { KDEF(suspend),   TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_SUSPEND,   0 },
  { KDEF(undo),      TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_UNDO,      0 },
  // { KDEF(up),        TERMKEY_TYPE_KEYSYM, TERMKEY_SYM_UP,        0 }, // redundant, driver-ci
  { 0, NULL,         0,                   0,                     0 },
};

// To be efficient at lookups, we store the byte sequence => keyinfo mapping
// in a trie. This avoids a slow linear search through a flat list of
// sequences. Because it is likely most nodes will be very sparse, we optimise
// vector to store an extent map after the database is loaded.

typedef enum {
  TYPE_KEY,
  TYPE_ARR,
} trie_nodetype;

struct trie_node {
  trie_nodetype type;
};

struct trie_node_key {
  trie_nodetype type;
  struct keyinfo key;
};

struct trie_node_arr {
  trie_nodetype type;
  unsigned char min, max;  // INCLUSIVE endpoints of the extent range
  struct trie_node *arr[];  // dynamic size at allocation time
};

static int insert_seq(TermKeyTI *ti, const char *seq, struct trie_node *node);

static struct trie_node *new_node_key(TermKeyType type, TermKeySym sym, int modmask, int modset)
{
  struct trie_node_key *n = xmalloc(sizeof(*n));

  n->type = TYPE_KEY;

  n->key.type = type;
  n->key.sym = sym;
  n->key.modifier_mask = modmask;
  n->key.modifier_set = modset;

  return (struct trie_node *)n;
}

static struct trie_node *new_node_arr(unsigned char min, unsigned char max)
{
  struct trie_node_arr *n = xmalloc(sizeof(*n) + (max - min + 1) * sizeof(n->arr[0]));

  n->type = TYPE_ARR;
  n->min = min; n->max = max;

  int i;
  for (i = min; i <= max; i++) {
    n->arr[i - min] = NULL;
  }

  return (struct trie_node *)n;
}

static struct trie_node *lookup_next(struct trie_node *n, unsigned char b)
{
  switch (n->type) {
  case TYPE_KEY:
    fprintf(stderr, "ABORT: lookup_next within a TYPE_KEY node\n");
    abort();
  case TYPE_ARR: {
    struct trie_node_arr *nar = (struct trie_node_arr *)n;
    if (b < nar->min || b > nar->max) {
      return NULL;
    }
    return nar->arr[b - nar->min];
  }
  }

  return NULL;  // Never reached but keeps compiler happy
}

static void free_trie(struct trie_node *n)
{
  switch (n->type) {
  case TYPE_KEY:
    break;
  case TYPE_ARR: {
    struct trie_node_arr *nar = (struct trie_node_arr *)n;
    int i;
    for (i = nar->min; i <= nar->max; i++) {
      if (nar->arr[i - nar->min]) {
        free_trie(nar->arr[i - nar->min]);
      }
    }
    break;
  }
  }

  xfree(n);
}

static struct trie_node *compress_trie(struct trie_node *n)
{
  if (!n) {
    return NULL;
  }

  switch (n->type) {
  case TYPE_KEY:
    return n;
  case TYPE_ARR: {
    struct trie_node_arr *nar = (struct trie_node_arr *)n;
    unsigned char min, max;
    // Find the real bounds
    for (min = 0; !nar->arr[min]; min++) {
      if (min == 255 && !nar->arr[min]) {
        xfree(nar);
        return new_node_arr(1, 0);
      }
    }

    for (max = 0xff; !nar->arr[max]; max--) {}

    struct trie_node_arr *new = (struct trie_node_arr *)new_node_arr(min, max);
    int i;
    for (i = min; i <= max; i++) {
      new->arr[i - min] = compress_trie(nar->arr[i]);
    }

    xfree(nar);
    return (struct trie_node *)new;
  }
  }

  return n;
}

static bool try_load_terminfo_key(TermKeyTI *ti, bool fn_nr, int key, bool shift, const char *name,
                                  struct keyinfo *info)
{
  const char *value = NULL;

  if (ti->ti) {
    if (!fn_nr) {
      value = ti->ti->keys[key][shift ? 1 : 0];
    } else {
      assert(!shift);
      value = ti->ti->f_keys[key];
    }
  }

  if (ti->tk->ti_getstr_hook) {
    value = (ti->tk->ti_getstr_hook)(name, value, ti->tk->ti_getstr_hook_data);
  }

  if (!value || value == (char *)-1 || !value[0]) {
    return false;
  }

  struct trie_node *node = new_node_key(info->type, info->sym, info->modifier_mask,
                                        info->modifier_set);
  insert_seq(ti, value, node);

  return true;
}

static int load_terminfo(TermKeyTI *ti)
{
  int i;

  ti->root = new_node_arr(0, 0xff);
  if (!ti->root) {
    return 0;
  }

  // First the regular key strings
  for (i = 0; funcs[i].funcname; i++) {
    char name[MAX_FUNCNAME + 5 + 1];

    sprintf(name, "key_%s", funcs[i].funcname);  // NOLINT(runtime/printf)
    if (!try_load_terminfo_key(ti, false, (int)funcs[i].ti_key, false, name, &(struct keyinfo){
      .type = funcs[i].type,
      .sym = funcs[i].sym,
      .modifier_mask = funcs[i].mods,
      .modifier_set = funcs[i].mods,
    })) {
      continue;
    }

    // Maybe it has a shifted version
    sprintf(name, "key_s%s", funcs[i].funcname);  // NOLINT(runtime/printf)
    try_load_terminfo_key(ti, false, (int)funcs[i].ti_key, true, name, &(struct keyinfo){
      .type = funcs[i].type,
      .sym = funcs[i].sym,
      .modifier_mask = funcs[i].mods | TERMKEY_KEYMOD_SHIFT,
      .modifier_set = funcs[i].mods | TERMKEY_KEYMOD_SHIFT,
    });
  }

  // Now the F<digit> keys
  for (i = 1; i <= kTerminfoFuncKeyMax; i++) {
    char name[9];
    sprintf(name, "key_f%d", i);  // NOLINT(runtime/printf)
    if (!try_load_terminfo_key(ti, true, (i - 1), false, name, &(struct keyinfo){
      .type = TERMKEY_TYPE_FUNCTION,
      .sym = i,
      .modifier_mask = 0,
      .modifier_set = 0,
    })) {
      break;
    }
  }

  // Finally mouse mode
  // This is overriden in nvim: we only want driver-csi mouse support
  if (false) {
    const char *value = NULL;

    if (ti->ti) {
      // value = ti->ti->keys[kTermKey_mouse][0];
    }

    if (ti->tk->ti_getstr_hook) {
      value = (ti->tk->ti_getstr_hook)("key_mouse", value, ti->tk->ti_getstr_hook_data);
    }

    // Some terminfos (e.g. xterm-1006) claim a different key_mouse that won't
    // give X10 encoding. We'll only accept this if it's exactly "\e[M"
    if (value && streq(value, "\x1b[M")) {
      struct trie_node *node = new_node_key(TERMKEY_TYPE_MOUSE, 0, 0, 0);
      insert_seq(ti, value, node);
    }
  }

  // Take copies of these terminfo strings, in case we build multiple termkey
  // instances for multiple different termtypes, and it's different by the
  // time we want to use it
  const char *keypad_xmit = ti->ti
                            ? ti->ti->defs[kTerm_keypad_xmit]
                            : NULL;

  if (keypad_xmit) {
    ti->start_string = xstrdup(keypad_xmit);
  } else {
    ti->start_string = NULL;
  }

  const char *keypad_local = ti->ti
                             ? ti->ti->defs[kTerm_keypad_local]
                             : NULL;

  if (keypad_local) {
    ti->stop_string = xstrdup(keypad_local);
  } else {
    ti->stop_string = NULL;
  }

  ti->root = compress_trie(ti->root);

  return 1;
}

void *new_driver_ti(TermKey *tk, TerminfoEntry *term)
{
  TermKeyTI *ti = xmalloc(sizeof *ti);

  ti->tk = tk;
  ti->root = NULL;
  ti->start_string = NULL;
  ti->stop_string = NULL;

  ti->ti = term;

  // ti->ti may be NULL because reasons. That means the terminal wasn't
  // known. Lets keep going because if we get getstr hook that might invent
  // new strings for us

  return ti;
}

int start_driver_ti(TermKey *tk, void *info)
{
  TermKeyTI *ti = info;
  struct stat statbuf;
  char *start_string;
  size_t len;

  if (!ti->root) {
    load_terminfo(ti);
  }

  start_string = ti->start_string;

  if (tk->fd == -1 || !start_string) {
    return 1;
  }

  // The terminfo database will contain keys in application cursor key mode.
  // We may need to enable that mode

  // There's no point trying to write() to a pipe
  if (fstat(tk->fd, &statbuf) == -1) {
    return 0;
  }

#ifndef _WIN32
  if (S_ISFIFO(statbuf.st_mode)) {
    return 1;
  }
#endif

  // Can't call putp or tputs because they suck and don't give us fd control
  len = strlen(start_string);
  while (len) {
    ssize_t result = write(tk->fd, start_string, (unsigned)len);
    if (result < 0) {
      return 0;
    }
    size_t written = (size_t)result;
    start_string += written;
    len -= written;
  }
  return 1;
}

int stop_driver_ti(TermKey *tk, void *info)
{
  TermKeyTI *ti = info;
  struct stat statbuf;
  char *stop_string = ti->stop_string;
  size_t len;

  if (tk->fd == -1 || !stop_string) {
    return 1;
  }

  // There's no point trying to write() to a pipe
  if (fstat(tk->fd, &statbuf) == -1) {
    return 0;
  }

#ifndef _WIN32
  if (S_ISFIFO(statbuf.st_mode)) {
    return 1;
  }
#endif

  // The terminfo database will contain keys in application cursor key mode.
  // We may need to enable that mode

  // Can't call putp or tputs because they suck and don't give us fd control
  len = strlen(stop_string);
  while (len) {
    ssize_t result = write(tk->fd, stop_string, (unsigned)len);
    if (result < 0) {
      return 0;
    }
    size_t written = (size_t)result;
    stop_string += written;
    len -= written;
  }
  return 1;
}

void free_driver_ti(void *info)
{
  TermKeyTI *ti = info;

  free_trie(ti->root);

  if (ti->start_string) {
    xfree(ti->start_string);
  }

  if (ti->stop_string) {
    xfree(ti->stop_string);
  }

  xfree(ti);
}

#define CHARAT(i) (tk->buffer[tk->buffstart + (i)])

TermKeyResult peekkey_ti(TermKey *tk, void *info, TermKeyKey *key, int force, size_t *nbytep)
{
  TermKeyTI *ti = info;

  if (tk->buffcount == 0) {
    return tk->is_closed ? TERMKEY_RES_EOF : TERMKEY_RES_NONE;
  }

  struct trie_node *p = ti->root;

  unsigned pos = 0;
  while (pos < tk->buffcount) {
    p = lookup_next(p, CHARAT(pos));
    if (!p) {
      break;
    }

    pos++;

    if (p->type != TYPE_KEY) {
      continue;
    }

    struct trie_node_key *nk = (struct trie_node_key *)p;
    if (nk->key.type == TERMKEY_TYPE_MOUSE) {
      tk->buffstart += pos;
      tk->buffcount -= pos;

      TermKeyResult mouse_result = (*tk->method.peekkey_mouse)(tk, key, nbytep);

      tk->buffstart -= pos;
      tk->buffcount += pos;

      if (mouse_result == TERMKEY_RES_KEY) {
        *nbytep += pos;
      }

      return mouse_result;
    }

    key->type = nk->key.type;
    key->code.sym = nk->key.sym;
    key->modifiers = nk->key.modifier_set;
    *nbytep = pos;
    return TERMKEY_RES_KEY;
  }

  // If p is not NULL then we hadn't walked off the end yet, so we have a
  // partial match
  if (p && !force) {
    return TERMKEY_RES_AGAIN;
  }

  return TERMKEY_RES_NONE;
}

static int insert_seq(TermKeyTI *ti, const char *seq, struct trie_node *node)
{
  int pos = 0;
  struct trie_node *p = ti->root;

  // Unsigned because we'll be using it as an array subscript
  unsigned char b;

  while ((b = (unsigned char)seq[pos])) {
    struct trie_node *next = lookup_next(p, b);
    if (!next) {
      break;
    }
    p = next;
    pos++;
  }

  while ((b = (unsigned char)seq[pos])) {
    struct trie_node *next;
    if (seq[pos + 1]) {
      // Intermediate node
      next = new_node_arr(0, 0xff);
    } else {
      // Final key node
      next = node;
    }

    if (!next) {
      return 0;
    }

    switch (p->type) {
    case TYPE_ARR: {
      struct trie_node_arr *nar = (struct trie_node_arr *)p;
      if (b < nar->min || b > nar->max) {
        fprintf(stderr,
                "ASSERT FAIL: Trie insert at 0x%02x is outside of extent bounds (0x%02x..0x%02x)\n",
                b, nar->min, nar->max);
        abort();
      }
      nar->arr[b - nar->min] = next;
      p = next;
      break;
    }
    case TYPE_KEY:
      fprintf(stderr, "ASSERT FAIL: Tried to insert child node in TYPE_KEY\n");
      abort();
    }

    pos++;
  }

  return 1;
}
