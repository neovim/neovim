// message.c: functions for displaying messages on the command line

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <uv.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/channel.h"
#include "nvim/charset.h"
#include "nvim/drawscreen.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/event/defs.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/highlight_group.h"
#include "nvim/indent.h"
#include "nvim/input.h"
#include "nvim/keycodes.h"
#include "nvim/log.h"
#include "nvim/main.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/message.h"
#include "nvim/mouse.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"
#include "nvim/pos_defs.h"
#include "nvim/regexp.h"
#include "nvim/runtime.h"
#include "nvim/runtime_defs.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_compositor.h"
#include "nvim/ui_defs.h"
#include "nvim/vim_defs.h"

// Magic chars used in confirm dialog strings
enum {
  DLG_BUTTON_SEP = '\n',
  DLG_HOTKEY_CHAR = '&',
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "message.c.generated.h"
#endif
static char *confirm_msg = NULL;            // ":confirm" message
static char *confirm_buttons;               // ":confirm" buttons sent to cmdline as prompt

MessageHistoryEntry *msg_hist_last = NULL;          // Last message (extern for unittest)
static MessageHistoryEntry *msg_hist_first = NULL;  // First message
static MessageHistoryEntry *msg_hist_temp = NULL;   // First potentially temporary message
static int msg_hist_len = 0;
static int msg_hist_max = 500;  // The default max value is 500

// args in 'messagesopt' option
#define MESSAGES_OPT_HIT_ENTER "hit-enter"
#define MESSAGES_OPT_WAIT "wait:"
#define MESSAGES_OPT_HISTORY "history:"

// The default is "hit-enter,history:500"
static int msg_flags = kOptMoptFlagHitEnter | kOptMoptFlagHistory;
static int msg_wait = 0;

static FILE *verbose_fd = NULL;
static bool verbose_did_open = false;

// Extended msg state, currently used for external UIs with ext_messages
static const char *msg_ext_kind = NULL;
static Array *msg_ext_chunks = NULL;
static garray_T msg_ext_last_chunk = GA_INIT(sizeof(char), 40);
static sattr_T msg_ext_last_attr = -1;
static int msg_ext_last_hl_id;

static bool msg_ext_history = false;  ///< message was added to history

/// Like msg() but keep it silent when 'verbosefile' is set.
void verb_msg(const char *s)
{
  verbose_enter();
  msg_keep(s, 0, false, false);
  verbose_leave();
}

/// Displays the string 's' on the status line
/// When terminal not initialized (yet) printf("%s", ..) is used.
void msg(const char *s, const int hl_id)
  FUNC_ATTR_NONNULL_ARG(1)
{
  msg_keep(s, hl_id, false, false);
}

/// Similar to msg_outtrans_len, but support newlines and tabs.
void msg_multiline(String str, int hl_id, bool check_int, bool hist)
  FUNC_ATTR_NONNULL_ALL
{
  const char *s = str.data;
  const char *chunk = s;
  while ((size_t)(s - str.data) < str.size) {
    if (check_int && got_int) {
      return;
    }
    if (*s == '\n' || *s == TAB || *s == '\r') {
      // Print all chars before the delimiter
      msg_outtrans_len(chunk, (int)(s - chunk), hl_id, hist);
      msg_putchar_hl((uint8_t)(*s), hl_id);
      chunk = s + 1;
    }
    s++;
  }

  // Print the rest of the message
  msg_outtrans_len(chunk, (int)(str.size - (size_t)(chunk - str.data)), hl_id, hist);
}

// Avoid starting a new message for each chunk and adding message to history in msg_keep().
static bool is_multihl = false;

/// Print message chunks, each with their own highlight ID.
///
/// @param hl_msg Message chunks
/// @param kind Message kind (can be NULL to avoid setting kind)
/// @param history Whether to add message to history
/// @param err Whether to print message as an error
void msg_multihl(HlMessage hl_msg, const char *kind, bool history, bool err)
{
  msg_start();
  msg_ext_history = history;
  if (kind != NULL) {
    msg_ext_set_kind(kind);
  }
  is_multihl = true;
  msg_ext_skip_flush = true;
  for (uint32_t i = 0; i < kv_size(hl_msg); i++) {
    HlMessageChunk chunk = kv_A(hl_msg, i);
    if (err) {
      emsg_multiline(chunk.text.data, kind, chunk.hl_id, true);
    } else {
      msg_multiline(chunk.text, chunk.hl_id, true, false);
    }
    assert(kind == NULL || msg_ext_kind == kind);
  }
  if (history && kv_size(hl_msg)) {
    msg_hist_add_multihl(hl_msg, false);
  }
  msg_ext_skip_flush = false;
  is_multihl = false;
  msg_end();
}

void msg_keep(const char *s, int hl_id, bool keep, bool multiline)
  FUNC_ATTR_NONNULL_ALL
{
  static int entered = 0;

  if (keep && multiline) {
    // Not implemented. 'multiline' is only used by nvim-added messages,
    // which should avoid 'keep' behavior (just show the message at
    // the correct time already).
    abort();
  }

  // Skip messages not match ":filter pattern".
  // Don't filter when there is an error.
  if (!emsg_on_display && message_filtered(s)) {
    return;
  }

  if (hl_id == 0) {
    set_vim_var_string(VV_STATUSMSG, s, -1);
  }

  // It is possible that displaying a messages causes a problem (e.g.,
  // when redrawing the window), which causes another message, etc..    To
  // break this loop, limit the recursiveness to 3 levels.
  if (entered >= 3) {
    return;
  }
  entered++;

  // Add message to history unless it's a multihl message.
  if (!is_multihl) {
    msg_hist_add(s, -1, hl_id);
    msg_start();
  }

  if (multiline) {
    msg_multiline(cstr_as_string(s), hl_id, false, false);
  } else {
    msg_outtrans(s, hl_id, false);
  }
  if (!is_multihl) {
    msg_end();
  }

  need_fileinfo = false;

  entered--;
}

/// Shows a printf-style message with highlight id.
///
/// Note: Caller must check the resulting string is shorter than IOSIZE!!!
///
/// @see semsg
/// @see swmsg
///
/// @param s printf-style format message
void smsg(int hl_id, const char *s, ...)
  FUNC_ATTR_PRINTF(2, 3)
{
  va_list arglist;

  va_start(arglist, s);
  vim_vsnprintf(IObuff, IOSIZE, s, arglist);
  va_end(arglist);
  msg(IObuff, hl_id);
}

// Remember the last sourcing name/lnum used in an error message, so that it
// isn't printed each time when it didn't change.
static int last_sourcing_lnum = 0;
static char *last_sourcing_name = NULL;

/// Reset the last used sourcing name/lnum.  Makes sure it is displayed again
/// for the next error message;
void reset_last_sourcing(void)
{
  XFREE_CLEAR(last_sourcing_name);
  last_sourcing_lnum = 0;
}

/// @return  true if "SOURCING_NAME" differs from "last_sourcing_name".
static bool other_sourcing_name(void)
{
  if (SOURCING_NAME != NULL) {
    if (last_sourcing_name != NULL) {
      return strcmp(SOURCING_NAME, last_sourcing_name) != 0;
    }
    return true;
  }
  return false;
}

/// Get the message about the source, as used for an error message
///
/// @return [allocated] String with room for one more character. NULL when no
///                     message is to be given.
static char *get_emsg_source(void)
  FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (SOURCING_NAME != NULL && other_sourcing_name()) {
    char *sname = estack_sfile(ESTACK_NONE);
    char *tofree = sname;

    if (sname == NULL) {
      sname = SOURCING_NAME;
    }

    const char *const p = _("Error in %s:");
    const size_t buf_len = strlen(sname) + strlen(p) + 1;
    char *const buf = xmalloc(buf_len);
    snprintf(buf, buf_len, p, sname);
    xfree(tofree);
    return buf;
  }
  return NULL;
}

/// Get the message about the source lnum, as used for an error message.
///
/// @return [allocated] String with room for one more character. NULL when no
///                     message is to be given.
static char *get_emsg_lnum(void)
  FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT
{
  // lnum is 0 when executing a command from the command line
  // argument, we don't want a line number then
  if (SOURCING_NAME != NULL
      && (other_sourcing_name() || SOURCING_LNUM != last_sourcing_lnum)
      && SOURCING_LNUM != 0) {
    const char *const p = _("line %4" PRIdLINENR ":");
    const size_t buf_len = 20 + strlen(p);
    char *const buf = xmalloc(buf_len);
    snprintf(buf, buf_len, p, SOURCING_LNUM);
    return buf;
  }
  return NULL;
}

/// Display name and line number for the source of an error.
/// Remember the file name and line number, so that for the next error the info
/// is only displayed if it changed.
void msg_source(int hl_id)
{
  static bool recursive = false;

  // Bail out if something called here causes an error.
  if (recursive) {
    return;
  }
  recursive = true;

  char *p = get_emsg_source();
  if (p != NULL) {
    msg(p, hl_id);
    xfree(p);
  }
  p = get_emsg_lnum();
  if (p != NULL) {
    msg(p, HLF_N);
    xfree(p);
    last_sourcing_lnum = SOURCING_LNUM;      // only once for each line
  }

  // remember the last sourcing name printed, also when it's empty
  if (SOURCING_NAME == NULL || other_sourcing_name()) {
    XFREE_CLEAR(last_sourcing_name);
    if (SOURCING_NAME != NULL) {
      last_sourcing_name = xstrdup(SOURCING_NAME);
      if (!redirecting()) {
        msg_putchar_hl('\n', hl_id);
      }
    }
  }

  recursive = false;
}

/// @return  true if not giving error messages right now:
///            If "emsg_off" is set: no error messages at the moment.
///            If "msg" is in 'debug': do error message but without side effects.
///            If "emsg_skip" is set: never do error messages.
static int emsg_not_now(void)
{
  if ((emsg_off > 0 && vim_strchr(p_debug, 'm') == NULL
       && vim_strchr(p_debug, 't') == NULL)
      || emsg_skip > 0) {
    return true;
  }
  return false;
}

void emsg_multiline(const char *s, const char *kind, int hl_id, bool multiline)
{
  bool ignore = false;

  // Skip this if not giving error messages at the moment.
  if (emsg_not_now()) {
    return;
  }

  called_emsg++;

  // If "emsg_severe" is true: When an error exception is to be thrown,
  // prefer this message over previous messages for the same command.
  bool severe = emsg_severe;
  emsg_severe = false;

  if (!emsg_off || vim_strchr(p_debug, 't') != NULL) {
    // Cause a throw of an error exception if appropriate.  Don't display
    // the error message in this case.  (If no matching catch clause will
    // be found, the message will be displayed later on.)  "ignore" is set
    // when the message should be ignored completely (used for the
    // interrupt message).
    if (cause_errthrow(s, multiline, severe, &ignore)) {
      if (!ignore) {
        did_emsg++;
      }
      return;
    }

    if (in_assert_fails && emsg_assert_fails_msg == NULL) {
      emsg_assert_fails_msg = xstrdup(s);
      emsg_assert_fails_lnum = SOURCING_LNUM;
      xfree(emsg_assert_fails_context);
      emsg_assert_fails_context = xstrdup(SOURCING_NAME == NULL ? "" : SOURCING_NAME);
    }

    // set "v:errmsg", also when using ":silent! cmd"
    set_vim_var_string(VV_ERRMSG, s, -1);

    // When using ":silent! cmd" ignore error messages.
    // But do write it to the redirection file.
    if (emsg_silent != 0) {
      if (!emsg_noredir) {
        msg_start();
        char *p = get_emsg_source();
        if (p != NULL) {
          const size_t p_len = strlen(p);
          p[p_len] = '\n';
          redir_write(p, (ptrdiff_t)p_len + 1);
          xfree(p);
        }
        p = get_emsg_lnum();
        if (p != NULL) {
          const size_t p_len = strlen(p);
          p[p_len] = '\n';
          redir_write(p, (ptrdiff_t)p_len + 1);
          xfree(p);
        }
        redir_write(s, (ptrdiff_t)strlen(s));
      }

      // Log (silent) errors as debug messages.
      if (SOURCING_NAME != NULL && SOURCING_LNUM != 0) {
        DLOG("(:silent) %s (%s (line %" PRIdLINENR "))",
             s, SOURCING_NAME, SOURCING_LNUM);
      } else {
        DLOG("(:silent) %s", s);
      }

      return;
    }

    // Log editor errors as INFO.
    if (SOURCING_NAME != NULL && SOURCING_LNUM != 0) {
      ILOG("%s (%s (line %" PRIdLINENR "))", s, SOURCING_NAME, SOURCING_LNUM);
    } else {
      ILOG("%s", s);
    }

    ex_exitval = 1;

    // Reset msg_silent, an error causes messages to be switched back on.
    msg_silent = 0;
    cmd_silent = false;

    if (global_busy) {        // break :global command
      global_busy++;
    }

    if (p_eb) {
      beep_flush();           // also includes flush_buffers()
    } else {
      flush_buffers(FLUSH_MINIMAL);  // flush internal buffers
    }
    did_emsg++;               // flag for DoOneCmd()
  }

  emsg_on_display = true;     // remember there is an error message
  msg_ext_set_kind(kind);

  // Display name and line number for the source of the error.
  bool save_msg_skip_flush = msg_ext_skip_flush;
  msg_ext_skip_flush = true;
  msg_source(hl_id);

  // Display the error message itself.
  msg_keep(s, hl_id, false, multiline);
  msg_ext_skip_flush = save_msg_skip_flush;
}

/// emsg() - display an error message
///
/// Rings the bell, if appropriate, and calls message() to do the real work
/// When terminal not initialized (yet) fprintf(stderr, "%s", ..) is used.
void emsg(const char *s)
{
  emsg_multiline(s, "emsg", HLF_E, false);
}

void emsg_invreg(int name)
{
  semsg(_("E354: Invalid register name: '%s'"), transchar_buf(NULL, name));
}

/// Print an error message with unknown number of arguments
///
/// @return whether the message was displayed
void semsg(const char *const fmt, ...)
  FUNC_ATTR_PRINTF(1, 2)
{
  va_list ap;
  va_start(ap, fmt);
  semsgv(fmt, ap);
  va_end(ap);
}

#define MULTILINE_BUFSIZE 8192

void semsg_multiline(const char *kind, const char *const fmt, ...)
{
  va_list ap;

  static char errbuf[MULTILINE_BUFSIZE];
  if (emsg_not_now()) {
    return;
  }

  va_start(ap, fmt);
  vim_vsnprintf(errbuf, sizeof(errbuf), fmt, ap);
  va_end(ap);

  emsg_multiline(errbuf, kind, HLF_E, true);
}

/// Print an error message with unknown number of arguments
static void semsgv(const char *fmt, va_list ap)
{
  static char errbuf[IOSIZE];
  if (emsg_not_now()) {
    return;
  }

  vim_vsnprintf(errbuf, sizeof(errbuf), fmt, ap);

  emsg(errbuf);
}

/// Same as emsg(...), but abort on error when ABORT_ON_INTERNAL_ERROR is
/// defined. It is used for internal errors only, so that they can be
/// detected when fuzzing vim.
void iemsg(const char *s)
{
  if (emsg_not_now()) {
    return;
  }

  emsg(s);
#ifdef ABORT_ON_INTERNAL_ERROR
  set_vim_var_string(VV_ERRMSG, s, -1);
  msg_putchar('\n');  // avoid overwriting the error message
  ui_flush();
  abort();
#endif
}

/// Same as semsg(...) but abort on error when ABORT_ON_INTERNAL_ERROR is
/// defined. It is used for internal errors only, so that they can be
/// detected when fuzzing vim.
void siemsg(const char *s, ...)
{
  if (emsg_not_now()) {
    return;
  }

  va_list ap;
  va_start(ap, s);
  semsgv(s, ap);
  va_end(ap);
#ifdef ABORT_ON_INTERNAL_ERROR
  msg_putchar('\n');  // avoid overwriting the error message
  ui_flush();
  abort();
#endif
}

/// Give an "Internal error" message.
void internal_error(const char *where)
{
  siemsg(_(e_intern2), where);
}

static void msg_semsg_event(void **argv)
{
  char *s = argv[0];
  emsg(s);
  xfree(s);
}

void msg_schedule_semsg(const char *const fmt, ...)
  FUNC_ATTR_PRINTF(1, 2)
{
  va_list ap;
  va_start(ap, fmt);
  vim_vsnprintf(IObuff, IOSIZE, fmt, ap);
  va_end(ap);

  char *s = xstrdup(IObuff);
  loop_schedule_deferred(&main_loop, event_create(msg_semsg_event, s));
}

static void msg_semsg_multiline_event(void **argv)
{
  char *s = argv[0];
  emsg_multiline(s, "emsg", HLF_E, true);
  xfree(s);
}

void msg_schedule_semsg_multiline(const char *const fmt, ...)
{
  va_list ap;
  va_start(ap, fmt);
  vim_vsnprintf(IObuff, IOSIZE, fmt, ap);
  va_end(ap);

  char *s = xstrdup(IObuff);
  loop_schedule_deferred(&main_loop, event_create(msg_semsg_multiline_event, s));
}

void hl_msg_free(HlMessage hl_msg)
{
  for (size_t i = 0; i < kv_size(hl_msg); i++) {
    xfree(kv_A(hl_msg, i).text.data);
  }
  kv_destroy(hl_msg);
}

/// Add the message at the end of the history
///
/// @param[in]  len  Length of s or -1.
static void msg_hist_add(const char *s, int len, int hl_id)
{
  String text = { .size = len < 0 ? strlen(s) : (size_t)len };
  // Remove leading and trailing newlines.
  while (text.size > 0 && *s == '\n') {
    text.size--;
    s++;
  }
  while (text.size > 0 && s[text.size - 1] == '\n') {
    text.size--;
  }
  if (text.size == 0) {
    return;
  }
  text.data = xmemdupz(s, text.size);

  HlMessage msg = KV_INITIAL_VALUE;
  kv_push(msg, ((HlMessageChunk){ text, hl_id }));
  msg_hist_add_multihl(msg, false);
}

static void msg_hist_add_multihl(HlMessage msg, bool temp)
{
  if (msg_may_clear_temp) {
    msg_hist_clear_temp();
    msg_may_clear_temp = false;
  }

  if (msg_hist_off || msg_silent != 0) {
    hl_msg_free(msg);
    return;
  }

  // Allocate an entry and add the message at the end of the history.
  MessageHistoryEntry *entry = xmalloc(sizeof(MessageHistoryEntry));
  entry->msg = msg;
  entry->temp = temp;
  entry->kind = msg_ext_kind;
  entry->prev = msg_hist_last;
  entry->next = NULL;
  // NOTE: this does not encode if the message was actually appended to the
  // previous entry in the message history. However append is currently only
  // true for :echon, which is stored in the history as a temporary entry for
  // "g<" where it is guaranteed to be after the entry it was appended to.
  entry->append = msg_ext_append;

  if (msg_hist_first == NULL) {
    msg_hist_first = entry;
  }
  if (msg_hist_last != NULL) {
    msg_hist_last->next = entry;
  }
  if (msg_hist_temp == NULL) {
    msg_hist_temp = entry;
  }

  msg_hist_len += !temp;
  msg_hist_last = entry;
  msg_ext_history = true;
  msg_hist_clear(msg_hist_max);
}

static void msg_hist_free_msg(MessageHistoryEntry *entry)
{
  if (entry->next == NULL) {
    msg_hist_last = entry->prev;
  } else {
    entry->next->prev = entry->prev;
  }
  if (entry->prev == NULL) {
    msg_hist_first = entry->next;
  } else {
    entry->prev->next = entry->next;
  }
  if (entry == msg_hist_temp) {
    msg_hist_temp = entry->next;
  }
  hl_msg_free(entry->msg);
  xfree(entry);
}

/// Delete oldest messages from the history until there are "keep" messages.
void msg_hist_clear(int keep)
{
  while (msg_hist_len > keep || (keep == 0 && msg_hist_first != NULL)) {
    msg_hist_len -= !msg_hist_first->temp;
    msg_hist_free_msg(msg_hist_first);
  }
}

void msg_hist_clear_temp(void)
{
  while (msg_hist_temp != NULL) {
    MessageHistoryEntry *next = msg_hist_temp->next;
    if (msg_hist_temp->temp) {
      msg_hist_free_msg(msg_hist_temp);
    }
    msg_hist_temp = next;
  }
}

int messagesopt_changed(void)
{
  int messages_flags_new = 0;
  int messages_wait_new = 0;
  int messages_history_new = 0;

  char *p = p_mopt;
  while (*p != NUL) {
    if (strnequal(p, S_LEN(MESSAGES_OPT_HIT_ENTER))) {
      p += STRLEN_LITERAL(MESSAGES_OPT_HIT_ENTER);
      messages_flags_new |= kOptMoptFlagHitEnter;
    } else if (strnequal(p, S_LEN(MESSAGES_OPT_WAIT))
               && ascii_isdigit(p[STRLEN_LITERAL(MESSAGES_OPT_WAIT)])) {
      p += STRLEN_LITERAL(MESSAGES_OPT_WAIT);
      messages_wait_new = getdigits_int(&p, false, INT_MAX);
      messages_flags_new |= kOptMoptFlagWait;
    } else if (strnequal(p, S_LEN(MESSAGES_OPT_HISTORY))
               && ascii_isdigit(p[STRLEN_LITERAL(MESSAGES_OPT_HISTORY)])) {
      p += STRLEN_LITERAL(MESSAGES_OPT_HISTORY);
      messages_history_new = getdigits_int(&p, false, INT_MAX);
      messages_flags_new |= kOptMoptFlagHistory;
    }

    if (*p != ',' && *p != NUL) {
      return FAIL;
    }
    if (*p == ',') {
      p++;
    }
  }

  // Either "wait" or "hit-enter" is required
  if (!(messages_flags_new & (kOptMoptFlagHitEnter | kOptMoptFlagWait))) {
    return FAIL;
  }

  // "history" must be set
  if (!(messages_flags_new & kOptMoptFlagHistory)) {
    return FAIL;
  }

  assert(messages_history_new >= 0);
  // "history" must be <= 10000
  if (messages_history_new > 10000) {
    return FAIL;
  }

  assert(messages_wait_new >= 0);
  // "wait" must be <= 10000
  if (messages_wait_new > 10000) {
    return FAIL;
  }

  msg_flags = messages_flags_new;
  msg_wait = messages_wait_new;

  msg_hist_max = messages_history_new;
  msg_hist_clear(msg_hist_max);

  return OK;
}

/// :messages command implementation
void ex_messages(exarg_T *eap)
  FUNC_ATTR_NONNULL_ALL
{
  if (strcmp(eap->arg, "clear") == 0) {
    msg_hist_clear(eap->addr_count ? eap->line2 : 0);
    return;
  }

  if (*eap->arg != NUL) {
    emsg(_(e_invarg));
    return;
  }

  Array entries = ARRAY_DICT_INIT;
  MessageHistoryEntry *p = eap->skip ? msg_hist_temp : msg_hist_first;
  int skip = eap->addr_count ? (msg_hist_len - eap->line2) : 0;
  for (; p != NULL; p = p->next) {
    // Skip over count or temporary "g<" messages.
    if ((p->temp && !eap->skip) || skip-- > 0) {
      continue;
    }
    if (!msg_silent) {
      Array entry = ARRAY_DICT_INIT;
      ADD(entry, CSTR_TO_OBJ(p->kind));
      Array content = ARRAY_DICT_INIT;
      for (uint32_t i = 0; i < kv_size(p->msg); i++) {
        HlMessageChunk chunk = kv_A(p->msg, i);
        Array content_entry = ARRAY_DICT_INIT;
        ADD(content_entry, INTEGER_OBJ(chunk.hl_id ? syn_id2attr(chunk.hl_id) : 0));
        ADD(content_entry, STRING_OBJ(copy_string(chunk.text, NULL)));
        ADD(content_entry, INTEGER_OBJ(chunk.hl_id));
        ADD(content, ARRAY_OBJ(content_entry));
      }
      ADD(entry, ARRAY_OBJ(content));
      ADD(entry, BOOLEAN_OBJ(p->append));
      ADD(entries, ARRAY_OBJ(entry));
    }
    if (redirecting()) {
      msg_silent++;
      msg_multihl(p->msg, p->kind, false, false);
      msg_silent--;
    }
  }
  if (kv_size(entries) > 0) {
    ui_call_msg_history_show(entries, eap->skip != 0);
    api_free_array(entries);
  }
}

/// Return true if printing messages should currently be done.
bool messaging(void)
{
  // TODO(bfredl): with general support for "async" messages with p_ch,
  // this should be re-enabled.
  return !(p_lz && char_avail() && !KeyTyped);
}

void msgmore(int n)
{
  int pn;

  if (global_busy           // no messages now, wait until global is finished
      || !messaging()) {      // 'lazyredraw' set, don't do messages now
    return;
  }

  pn = abs(n);

  if (pn > p_report) {
    if (n > 0) {
      vim_snprintf(msg_buf, MSG_BUF_LEN,
                   NGETTEXT("%d more line", "%d more lines", pn),
                   pn);
    } else {
      vim_snprintf(msg_buf, MSG_BUF_LEN,
                   NGETTEXT("%d line less", "%d fewer lines", pn),
                   pn);
    }
    if (got_int) {
      xstrlcat(msg_buf, _(" (Interrupted)"), MSG_BUF_LEN);
    }
    msg(msg_buf, 0);
  }
}

void msg_ext_set_kind(const char *msg_kind)
{
  // Don't change the label of an existing batch:
  msg_ext_ui_flush();

  // TODO(bfredl): would be nice to avoid dynamic scoping, but that would
  // need refactoring the msg_ interface to not be "please pretend nvim is
  // a terminal for a moment"
  msg_ext_kind = msg_kind;
}

/// Prepare for outputting characters in the command line.
void msg_start(void)
{
  if (!msg_silent) {
    need_fileinfo = false;
  }

  msg_ext_ui_flush();

  redir_write("\n", 1);  // When redirecting, start a new line.
}

void msg_putchar(int c)
{
  msg_putchar_hl(c, 0);
}

void msg_putchar_hl(int c, int hl_id)
{
  char buf[MB_MAXCHAR + 1];

  if (IS_SPECIAL(c)) {
    buf[0] = (char)K_SPECIAL;
    buf[1] = (char)K_SECOND(c);
    buf[2] = (char)K_THIRD(c);
    buf[3] = NUL;
  } else {
    buf[utf_char2bytes(c, buf)] = NUL;
  }
  msg_puts_hl(buf, hl_id, false);
}

void msg_outnum(int n)
{
  char buf[20];

  snprintf(buf, sizeof(buf), "%d", n);
  msg_puts(buf);
}

void msg_home_replace(const char *fname)
{
  msg_home_replace_hl(fname, 0);
}

static void msg_home_replace_hl(const char *fname, int hl_id)
{
  char *name = home_replace_save(NULL, fname);
  msg_outtrans(name, hl_id, false);
  xfree(name);
}

/// Output "len" characters in "str" (including NULs) with translation
/// if "len" is -1, output up to a NUL character. Use highlight "hl_id".
///
/// @return  the number of characters it takes on the screen.
int msg_outtrans(const char *str, int hl_id, bool hist)
{
  return *str == NUL ? 0 : msg_outtrans_len(str, (int)strlen(str), hl_id, hist);
}

/// Output one character at "p".
/// Handles multi-byte characters.
///
/// @return  pointer to the next character.
const char *msg_outtrans_one(const char *p, int hl_id, bool hist)
{
  int l;

  if ((l = utfc_ptr2len(p)) > 1) {
    msg_outtrans_len(p, l, hl_id, hist);
    return p + l;
  }
  msg_puts_hl(transchar_byte_buf(NULL, (uint8_t)(*p)), hl_id, hist);
  return p + 1;
}

int msg_outtrans_len(const char *msgstr, int len, int hl_id, bool hist)
{
  int retval = 0;
  const char *str = msgstr;
  const char *plain_start = msgstr;
  char *s;
  int c;
  int save_got_int = got_int;

  // Only quit when got_int was set in here.
  got_int = false;

  if (hist) {
    msg_hist_add(str, len, hl_id);
  }

  // When drawing over the command line no need to clear it later or remove
  // the mode message.
  if (msg_silent == 0 && len > 0 && msg_col == 0) {
    clear_cmdline = false;
    mode_displayed = false;
  }

  // Go over the string.  Special characters are translated and printed.
  // Normal characters are printed several at a time.
  while (--len >= 0 && !got_int) {
    // Don't include composing chars after the end.
    int mb_l = utfc_ptr2len_len(str, len + 1);
    if (mb_l > 1) {
      c = utf_ptr2char(str);
      if (vim_isprintc(c)) {
        // Printable multi-byte char: count the cells.
        retval += utf_ptr2cells(str);
      } else {
        // Unprintable multi-byte char: print the printable chars so
        // far and the translation of the unprintable char.
        if (str > plain_start) {
          msg_puts_len(plain_start, str - plain_start, hl_id, hist);
        }
        plain_start = str + mb_l;
        msg_puts_hl(transchar_buf(NULL, c), hl_id == 0 ? HLF_8 : hl_id, false);
        retval += char2cells(c);
      }
      len -= mb_l - 1;
      str += mb_l;
    } else {
      s = transchar_byte_buf(NULL, (uint8_t)(*str));
      if (s[1] != NUL) {
        // Unprintable char: print the printable chars so far and the
        // translation of the unprintable char.
        if (str > plain_start) {
          msg_puts_len(plain_start, str - plain_start, hl_id, hist);
        }
        plain_start = str + 1;
        msg_puts_hl(s, hl_id == 0 ? HLF_8 : hl_id, false);
        retval += (int)strlen(s);
      } else {
        retval++;
      }
      str++;
    }
  }

  if ((str > plain_start || plain_start == msgstr) && !got_int) {
    // Print the printable chars at the end (or emit empty string).
    msg_puts_len(plain_start, str - plain_start, hl_id, hist);
  }

  got_int |= save_got_int;

  return retval;
}

void msg_make(const char *arg)
{
  int i;
  static const char *str = "eeffoc";
  static const char *rs = "Plon#dqg#vxjduB";

  arg = skipwhite(arg);
  for (i = 5; *arg && i >= 0; i--) {
    if (*arg++ != str[i]) {
      break;
    }
  }
  if (i < 0) {
    msg_putchar('\n');
    for (i = 0; rs[i]; i++) {
      msg_putchar(rs[i] - 3);
    }
  }
}

/// Output the string 'str' up to a NUL character.
/// Return the number of characters it takes on the screen.
///
/// If K_SPECIAL is encountered, then it is taken in conjunction with the
/// following character and shown as <F1>, <S-Up> etc.  Any other character
/// which is not printable shown in <> form.
/// If 'from' is true (lhs of a mapping), a space is shown as <Space>.
/// If a character is displayed in one of these special ways, is also
/// highlighted (its highlight name is '8' in the p_hl variable).
/// Otherwise characters are not highlighted.
/// This function is used to show mappings, where we want to see how to type
/// the character/string -- webb
///
/// @param from  true for LHS of a mapping
/// @param maxlen  screen columns, 0 for unlimited
int msg_outtrans_special(const char *strstart, bool from, int maxlen)
{
  if (strstart == NULL) {
    return 0;  // Do nothing.
  }
  const char *str = strstart;
  int retval = 0;
  int hl_id = HLF_8;

  while (*str != NUL) {
    const char *text;
    // Leading and trailing spaces need to be displayed in <> form.
    if ((str == strstart || str[1] == NUL) && *str == ' ') {
      text = "<Space>";
      str++;
    } else {
      text = str2special(&str, from, false);
    }
    if (text[0] != NUL && text[1] == NUL) {
      // single-byte character or illegal byte
      text = transchar_byte_buf(NULL, (uint8_t)text[0]);
    }
    const int len = vim_strsize(text);
    if (maxlen > 0 && retval + len >= maxlen) {
      break;
    }
    // Highlight special keys
    msg_puts_hl(text, (len > 1 && utfc_ptr2len(text) <= 1 ? hl_id : 0), false);
    retval += len;
  }
  return retval;
}

/// Convert string, replacing key codes with printables
///
/// Used for lhs or rhs of mappings.
///
/// @param[in]  str  String to convert.
/// @param[in]  replace_spaces  Convert spaces into `<Space>`, normally used for
///                             lhs of mapping and keytrans(), but not rhs.
/// @param[in]  replace_lt  Convert `<` into `<lt>`.
///
/// @return [allocated] Converted string.
char *str2special_save(const char *const str, const bool replace_spaces, const bool replace_lt)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_MALLOC
  FUNC_ATTR_NONNULL_RET
{
  garray_T ga;
  ga_init(&ga, 1, 40);

  const char *p = str;
  while (*p != NUL) {
    ga_concat(&ga, str2special(&p, replace_spaces, replace_lt));
  }
  ga_append(&ga, NUL);
  return (char *)ga.ga_data;
}

/// Convert string, replacing key codes with printables
///
/// Used for lhs or rhs of mappings.
///
/// @param[in]  str  String to convert.
/// @param[in]  replace_spaces  Convert spaces into `<Space>`, normally used for
///                             lhs of mapping and keytrans(), but not rhs.
/// @param[in]  replace_lt  Convert `<` into `<lt>`.
///
/// @return [allocated] Converted string.
char *str2special_arena(const char *str, bool replace_spaces, bool replace_lt, Arena *arena)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_MALLOC
  FUNC_ATTR_NONNULL_RET
{
  const char *p = str;
  size_t len = 0;
  while (*p) {
    len += strlen(str2special(&p, replace_spaces, replace_lt));
  }

  char *buf = arena_alloc(arena, len + 1, false);
  size_t pos = 0;
  p = str;
  while (*p) {
    const char *s = str2special(&p, replace_spaces, replace_lt);
    size_t s_len = strlen(s);
    memcpy(buf + pos, s, s_len);
    pos += s_len;
  }
  buf[pos] = NUL;
  return buf;
}

/// Convert character, replacing key with printable representation.
///
/// @param[in,out]  sp  String to convert. Is advanced to the next key code.
/// @param[in]  replace_spaces  Convert spaces into `<Space>`, normally used for
///                             lhs of mapping and keytrans(), but not rhs.
/// @param[in]  replace_lt  Convert `<` into `<lt>`.
///
/// @return Converted key code, in a static buffer. Buffer is always one and the
///         same, so save converted string somewhere before running str2special
///         for the second time.
///         On illegal byte return a string with only that byte.
const char *str2special(const char **const sp, const bool replace_spaces, const bool replace_lt)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET
{
  static char buf[7];

  {
    // Try to un-escape a multi-byte character.  Return the un-escaped
    // string if it is a multi-byte character.
    const char *const p = mb_unescape(sp);
    if (p != NULL) {
      return p;
    }
  }

  const char *str = *sp;
  int c = (uint8_t)(*str);
  int modifiers = 0;
  bool special = false;
  if (c == K_SPECIAL && str[1] != NUL && str[2] != NUL) {
    if ((uint8_t)str[1] == KS_MODIFIER) {
      modifiers = (uint8_t)str[2];
      str += 3;
      c = (uint8_t)(*str);
    }
    if (c == K_SPECIAL && str[1] != NUL && str[2] != NUL) {
      c = TO_SPECIAL((uint8_t)str[1], (uint8_t)str[2]);
      str += 2;
    }
    if (IS_SPECIAL(c) || modifiers) {  // Special key.
      special = true;
    }
  }

  if (!IS_SPECIAL(c) && MB_BYTE2LEN(c) > 1) {
    *sp = str;
    // Try to un-escape a multi-byte character after modifiers.
    const char *p = mb_unescape(sp);
    if (p != NULL) {
      // Since 'special' is true the multi-byte character 'c' will be
      // processed by get_special_key_name().
      c = utf_ptr2char(p);
    } else {
      // illegal byte
      *sp = str + 1;
    }
  } else {
    // single-byte character, NUL or illegal byte
    *sp = str + (*str == NUL ? 0 : 1);
  }

  // Make special keys and C0 control characters in <> form, also <M-Space>.
  if (special
      || c < ' '
      || (replace_spaces && c == ' ')
      || (replace_lt && c == '<')) {
    return get_special_key_name(c, modifiers);
  }
  buf[0] = (char)c;
  buf[1] = NUL;
  return buf;
}

/// Convert string, replacing key codes with printables
///
/// @param[in]  str  String to convert.
/// @param[out]  buf  Buffer to save results to.
/// @param[in]  len  Buffer length.
void str2specialbuf(const char *sp, char *buf, size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  while (*sp) {
    const char *s = str2special(&sp, false, false);
    const size_t s_len = strlen(s);
    if (len <= s_len) {
      break;
    }
    memcpy(buf, s, s_len);
    buf += s_len;
    len -= s_len;
  }
  *buf = NUL;
}

/// print line for :print or :list command
void msg_prt_line(const char *s, bool list)
{
  schar_T sc;
  int col = 0;
  int n_extra = 0;
  schar_T sc_extra = 0;
  schar_T sc_final = 0;
  const char *p_extra = NULL;  // init to make SASC shut up. ASCII only!
  int n;
  int hl_id = 0;
  const char *lead = NULL;
  bool in_multispace = false;
  int multispace_pos = 0;
  const char *trail = NULL;
  int l;

  if (curwin->w_p_list) {
    list = true;
  }

  if (list) {
    // find start of trailing whitespace
    if (curwin->w_p_lcs_chars.trail) {
      trail = s + strlen(s);
      while (trail > s && ascii_iswhite(trail[-1])) {
        trail--;
      }
    }
    // find end of leading whitespace
    if (curwin->w_p_lcs_chars.lead || curwin->w_p_lcs_chars.leadmultispace != NULL) {
      lead = s;
      while (ascii_iswhite(lead[0])) {
        lead++;
      }
      // in a line full of spaces all of them are treated as trailing
      if (*lead == NUL) {
        lead = NULL;
      }
    }
  }

  // output a space for an empty line, otherwise the line will be overwritten
  if (*s == NUL && !(list && curwin->w_p_lcs_chars.eol != NUL)) {
    msg_putchar(' ');
  }

  while (!got_int) {
    if (n_extra > 0) {
      n_extra--;
      if (n_extra == 0 && sc_final) {
        sc = sc_final;
      } else if (sc_extra) {
        sc = sc_extra;
      } else {
        assert(p_extra != NULL);
        sc = schar_from_ascii((unsigned char)(*p_extra++));
      }
    } else if ((l = utfc_ptr2len(s)) > 1) {
      col += utf_ptr2cells(s);
      char buf[MB_MAXBYTES + 1];
      if (l >= MB_MAXBYTES) {
        xstrlcpy(buf, "?", sizeof(buf));
      } else if (curwin->w_p_lcs_chars.nbsp != NUL && list
                 && (utf_ptr2char(s) == 160 || utf_ptr2char(s) == 0x202f)) {
        schar_get(buf, curwin->w_p_lcs_chars.nbsp);
      } else {
        memmove(buf, s, (size_t)l);
        buf[l] = NUL;
      }
      msg_puts(buf);
      s += l;
      continue;
    } else {
      hl_id = 0;
      int c = (uint8_t)(*s++);
      if (c >= 0x80) {  // Illegal byte
        col += utf_char2cells(c);
        msg_putchar(c);
        continue;
      }
      sc_extra = NUL;
      sc_final = NUL;
      if (list) {
        in_multispace = c == ' ' && (*s == ' '
                                     || (col > 0 && s[-2] == ' '));
        if (!in_multispace) {
          multispace_pos = 0;
        }
      }
      if (c == TAB && (!list || curwin->w_p_lcs_chars.tab1)) {
        // tab amount depends on current column
        n_extra = tabstop_padding(col, curbuf->b_p_ts,
                                  curbuf->b_p_vts_array) - 1;
        if (!list) {
          sc = schar_from_ascii(' ');
          sc_extra = schar_from_ascii(' ');
        } else {
          sc = (n_extra == 0 && curwin->w_p_lcs_chars.tab3)
               ? curwin->w_p_lcs_chars.tab3
               : curwin->w_p_lcs_chars.tab1;
          sc_extra = curwin->w_p_lcs_chars.tab2;
          sc_final = curwin->w_p_lcs_chars.tab3;
          hl_id = HLF_0;
        }
      } else if (c == NUL && list && curwin->w_p_lcs_chars.eol != NUL) {
        p_extra = "";
        n_extra = 1;
        sc = curwin->w_p_lcs_chars.eol;
        hl_id = HLF_AT;
        s--;
      } else if (c != NUL && (n = byte2cells(c)) > 1) {
        n_extra = n - 1;
        p_extra = transchar_byte_buf(NULL, c);
        sc = schar_from_ascii(*p_extra++);
        // Use special coloring to be able to distinguish <hex> from
        // the same in plain text.
        hl_id = HLF_0;
      } else if (c == ' ') {
        if (lead != NULL && s <= lead && in_multispace
            && curwin->w_p_lcs_chars.leadmultispace != NULL) {
          sc = curwin->w_p_lcs_chars.leadmultispace[multispace_pos++];
          if (curwin->w_p_lcs_chars.leadmultispace[multispace_pos] == NUL) {
            multispace_pos = 0;
          }
          hl_id = HLF_0;
        } else if (lead != NULL && s <= lead && curwin->w_p_lcs_chars.lead != NUL) {
          sc = curwin->w_p_lcs_chars.lead;
          hl_id = HLF_0;
        } else if (trail != NULL && s > trail) {
          sc = curwin->w_p_lcs_chars.trail;
          hl_id = HLF_0;
        } else if (in_multispace
                   && curwin->w_p_lcs_chars.multispace != NULL) {
          sc = curwin->w_p_lcs_chars.multispace[multispace_pos++];
          if (curwin->w_p_lcs_chars.multispace[multispace_pos] == NUL) {
            multispace_pos = 0;
          }
          hl_id = HLF_0;
        } else if (list && curwin->w_p_lcs_chars.space != NUL) {
          sc = curwin->w_p_lcs_chars.space;
          hl_id = HLF_0;
        } else {
          sc = schar_from_ascii(' ');  // SPACE!
        }
      } else {
        sc = schar_from_ascii(c);
      }
    }

    if (sc == NUL) {
      break;
    }

    // TODO(bfredl): this is such baloney. need msg_put_schar
    char buf[MAX_SCHAR_SIZE];
    schar_get(buf, sc);
    msg_puts_hl(buf, hl_id, false);
    col++;
  }
}

void msg_puts(const char *s)
{
  msg_puts_hl(s, 0, false);
}

void msg_puts_title(const char *s)
{
  msg_puts_hl(s, HLF_T, false);
}

/// Basic function for writing a message with highlight id.
void msg_puts_hl(const char *const s, const int hl_id, const bool hist)
{
  msg_puts_len(s, -1, hl_id, hist);
}

/// Write a message with highlight id.
///
/// @param[in]  str  NUL-terminated message string.
/// @param[in]  len  Length of the string or -1.
/// @param[in]  hl_id  Highlight id.
void msg_puts_len(const char *const str, const ptrdiff_t len, int hl_id, bool hist)
  FUNC_ATTR_NONNULL_ALL
{
  assert(len < 0 || memchr(str, 0, (size_t)len) == NULL);
  // If redirection is on, also write to the redirection file.
  redir_write(str, len);

  // Don't print anything when using ":silent cmd" or empty message.
  if (msg_silent != 0 || *str == NUL) {
    if (*str == NUL) {
      ui_call_msg_show(cstr_as_string("empty"), (Array)ARRAY_DICT_INIT, false, false, false);
    }
    return;
  }

  if (hist) {
    msg_hist_add(str, (int)len, hl_id);
  }

  // If there is no valid screen, use fprintf so we can see error messages.
  // If termcap is not active, we may be writing in an alternate console
  // window, cursor positioning may not work correctly (window size may be
  // different, e.g. for Win32 console) or we just don't know where the
  // cursor is.
  if (msg_use_printf()) {
    int saved_msg_col = msg_col;
    msg_puts_printf(str, len);
    if (headless_mode) {
      msg_col = saved_msg_col;
    }
  }
  if (!msg_use_printf() || (headless_mode && default_grid.chars)) {
    msg_puts_chunk(str, (int)len, hl_id, false);
  }

  need_fileinfo = false;
}

static void msg_ext_emit_chunk(void)
{
  if (msg_ext_chunks == NULL) {
    msg_ext_init_chunks();
  }
  // Color was changed or a message flushed, end current chunk.
  if (msg_ext_last_attr == -1) {
    return;  // no chunk
  }
  Array chunk = ARRAY_DICT_INIT;
  ADD(chunk, INTEGER_OBJ(msg_ext_last_attr));
  msg_ext_last_attr = -1;
  String text = ga_take_string(&msg_ext_last_chunk);
  ADD(chunk, STRING_OBJ(text));
  ADD(chunk, INTEGER_OBJ(msg_ext_last_hl_id));
  ADD(*msg_ext_chunks, ARRAY_OBJ(chunk));
}

static void msg_puts_chunk(const char *str, int maxlen, int hl_id, int recurse)
{
  int attr = hl_id ? syn_id2attr(hl_id) : 0;

  if (attr != msg_ext_last_attr) {
    msg_ext_emit_chunk();
    msg_ext_last_attr = attr;
    msg_ext_last_hl_id = hl_id;
  }

  // Concat pieces with the same highlight
  size_t len = maxlen < 0 ? strlen(str) : strnlen(str, (size_t)maxlen);
  ga_concat_len(&msg_ext_last_chunk, str, len);

  // Find last newline in the message and calculate the current message column
  const char *lastline = strrchr(str, '\n');
  maxlen -= (int)(lastline ? (lastline - str) : 0);
  const char *p = lastline ? lastline + 1 : str;
  int col = (int)(maxlen < 0 ? mb_string2cells(p) : mb_string2cells_len(p, (size_t)(maxlen)));
  msg_col = (lastline ? 0 : msg_col) + col;
}

/// @return  true when ":filter pattern" was used and "msg" does not match
///          "pattern".
bool message_filtered(const char *msg)
{
  if (cmdmod.cmod_filter_regmatch.regprog == NULL) {
    return false;
  }

  bool match = vim_regexec(&cmdmod.cmod_filter_regmatch, msg, 0);
  return cmdmod.cmod_filter_force ? match : !match;
}

/// @return  true when messages should be printed to stdout/stderr:
///          - "batch mode" ("silent mode", -es/-Es/-l)
///          - no UI and not embedded
int msg_use_printf(void)
{
  return !embedded_mode && !ui_active();
}

/// Print a message when there is no valid screen.
static void msg_puts_printf(const char *str, const ptrdiff_t maxlen)
{
  const char *s = str;
  char buf[7];
  char *p;

  if (on_print.type != kCallbackNone) {
    typval_T argv[1];
    argv[0].v_type = VAR_STRING;
    argv[0].v_lock = VAR_UNLOCKED;
    argv[0].vval.v_string = (char *)str;
    typval_T rettv = TV_INITIAL_VALUE;
    callback_call(&on_print, 1, argv, &rettv);
    tv_clear(&rettv);
    return;
  }

  while ((maxlen < 0 || s - str < maxlen) && *s != NUL) {
    int len = utf_ptr2len(s);
    if (!(silent_mode && p_verbose == 0)) {
      // NL --> CR NL translation (for Unix, not for "--version")
      p = &buf[0];
      if (*s == '\n' && !info_message) {
        *p++ = '\r';
      }
      memcpy(p, s, (size_t)len);
      *(p + len) = NUL;
      if (info_message) {
        printf("%s", buf);
      } else {
        fprintf(stderr, "%s", buf);
      }
    }

    int cw = utf_char2cells(utf_ptr2char(s));
    // primitive way to compute the current column
    if (*s == '\r' || *s == '\n') {
      msg_col = 0;
    } else {
      msg_col += cw;
    }
    s += len;
  }
}

/// end putting a message on the screen
void msg_end(void)
{
  // NOTE: ui_flush() used to be called here. This had to be removed, as it
  // inhibited substantial performance improvements. It is assumed that relevant
  // callers invoke ui_flush() before going into CPU busywork, or restricted
  // event processing after displaying a message to the user.
  msg_ext_ui_flush();
}

/// Clear "msg_ext_chunks" before flushing so that ui_flush() does not re-emit
/// the same message recursively.
static Array *msg_ext_init_chunks(void)
{
  Array *tofree = msg_ext_chunks;
  msg_ext_chunks = xcalloc(1, sizeof(*msg_ext_chunks));
  msg_col = 0;
  return tofree;
}

void msg_ext_ui_flush(void)
{
  if (msg_ext_skip_flush) {
    return;
  }

  msg_ext_emit_chunk();
  if (msg_ext_chunks->size > 0) {
    Array *tofree = msg_ext_init_chunks();
    ui_call_msg_show(cstr_as_string(msg_ext_kind), *tofree, msg_ext_overwrite, msg_ext_history,
                     msg_ext_append);
    if (msg_ext_history) {
      api_free_array(*tofree);
    } else {
      // Add to history as temporary message for "g<".
      HlMessage msg = KV_INITIAL_VALUE;
      for (size_t i = 0; i < kv_size(*tofree); i++) {
        Object *chunk = kv_A(*tofree, i).data.array.items;
        kv_push(msg, ((HlMessageChunk){ chunk[1].data.string, (int)chunk[2].data.integer }));
        xfree(chunk);
      }
      xfree(tofree->items);
      msg_hist_add_multihl(msg, true);
    }
    xfree(tofree);
    msg_ext_overwrite = false;
    msg_ext_history = false;
    msg_ext_append = false;
    msg_ext_kind = NULL;
  }
}

void msg_ext_flush_showmode(void)
{
  // Showmode messages doesn't interrupt normal message flow, so we use
  // separate event. Still reuse the same chunking logic, for simplicity.
  // This is called unconditionally; check if we are emitting, or have
  // emitted non-empty "content".
  static bool clear = false;
  if (msg_ext_last_attr != -1 || clear) {
    clear = msg_ext_last_attr != -1;
    msg_ext_emit_chunk();
    Array *tofree = msg_ext_init_chunks();
    ui_call_msg_showmode(*tofree);
    api_free_array(*tofree);
    xfree(tofree);
  }
}

/// May write a string to the redirection file.
///
/// @param maxlen  if -1, write the whole string, otherwise up to "maxlen" bytes.
static void redir_write(const char *const str, const ptrdiff_t maxlen)
{
  const char *s = str;
  static int cur_col = 0;

  if (maxlen == 0) {
    return;
  }

  // Don't do anything for displaying prompts and the like.
  if (redir_off) {
    return;
  }

  // If 'verbosefile' is set prepare for writing in that file.
  if (*p_vfile != NUL && verbose_fd == NULL) {
    verbose_open();
  }

  if (redirecting()) {
    // If the string doesn't start with CR or NL, go to msg_col
    if (*s != '\n' && *s != '\r') {
      while (cur_col < msg_col) {
        if (capture_ga) {
          ga_concat_len(capture_ga, " ", 1);
        }
        if (redir_reg) {
          write_reg_contents(redir_reg, " ", 1, true);
        } else if (redir_vname) {
          var_redir_str(" ", -1);
        } else if (redir_fd != NULL) {
          fputs(" ", redir_fd);
        }
        if (verbose_fd != NULL) {
          fputs(" ", verbose_fd);
        }
        cur_col++;
      }
    }

    size_t len = maxlen == -1 ? strlen(s) : (size_t)maxlen;
    if (capture_ga) {
      ga_concat_len(capture_ga, str, len);
    }
    if (redir_reg) {
      write_reg_contents(redir_reg, s, (ssize_t)len, true);
    }
    if (redir_vname) {
      var_redir_str(s, (int)maxlen);
    }

    // Write and adjust the current column.
    while (*s != NUL
           && (maxlen < 0 || (int)(s - str) < maxlen)) {
      if (!redir_reg && !redir_vname && !capture_ga) {
        if (redir_fd != NULL) {
          putc(*s, redir_fd);
        }
      }
      if (verbose_fd != NULL) {
        putc(*s, verbose_fd);
      }
      if (*s == '\r' || *s == '\n') {
        cur_col = 0;
      } else if (*s == '\t') {
        cur_col += (8 - cur_col % 8);
      } else {
        cur_col++;
      }
      s++;
    }

    if (msg_silent != 0) {      // should update msg_col
      msg_col = cur_col;
    }
  }
}

int redirecting(void)
{
  return redir_fd != NULL || *p_vfile != NUL
         || redir_reg || redir_vname || capture_ga != NULL;
}

// Save and restore message kind when emitting a verbose message.
static const char *pre_verbose_kind = NULL;
static const char *verbose_kind = "verbose";

/// Before giving verbose message.
/// Must always be called paired with verbose_leave()!
void verbose_enter(void)
{
  if (*p_vfile != NUL) {
    msg_silent++;
  }
  if (msg_ext_kind != verbose_kind) {
    pre_verbose_kind = msg_ext_kind;
  }
  msg_ext_set_kind("verbose");
}

/// After giving verbose message.
/// Must always be called paired with verbose_enter()!
void verbose_leave(void)
{
  if (*p_vfile != NUL) {
    if (--msg_silent < 0) {
      msg_silent = 0;
    }
  }
  if (pre_verbose_kind != NULL) {
    msg_ext_set_kind(pre_verbose_kind);
    pre_verbose_kind = NULL;
  }
}

/// Called when 'verbosefile' is set: stop writing to the file.
void verbose_stop(void)
{
  if (verbose_fd != NULL) {
    fclose(verbose_fd);
    verbose_fd = NULL;
  }
  verbose_did_open = false;
}

/// Open the file 'verbosefile'.
///
/// @return  FAIL or OK.
int verbose_open(void)
{
  if (verbose_fd == NULL && !verbose_did_open) {
    // Only give the error message once.
    verbose_did_open = true;

    verbose_fd = os_fopen(p_vfile, "a");
    if (verbose_fd == NULL) {
      semsg(_(e_notopen), p_vfile);
      return FAIL;
    }
  }
  return OK;
}

/// Give a (highlighted) warning message (for searching).
void give_warning(const char *message, bool hl)
  FUNC_ATTR_NONNULL_ARG(1)
{
  // Don't do this for ":silent".
  if (msg_silent != 0) {
    return;
  }

  set_vim_var_string(VV_WARNINGMSG, message, -1);

  if (msg_ext_kind == NULL) {
    msg_ext_set_kind("wmsg");
  }

  msg(message, hl ? HLF_W : 0);
}

/// Shows a warning, with optional highlighting.
///
/// @param hl enable highlighting
/// @param fmt printf-style format message
///
/// @see smsg
/// @see semsg
void swmsg(bool hl, const char *const fmt, ...)
  FUNC_ATTR_PRINTF(2, 3)
{
  va_list args;

  va_start(args, fmt);
  vim_vsnprintf(IObuff, IOSIZE, fmt, args);
  va_end(args);

  give_warning(IObuff, hl);
}

/// Advance msg cursor to column "col".
void msg_advance(int col)
{
  if (msg_silent != 0) {        // nothing to advance to
    msg_col = col;              // for redirection, may fill it up later
    return;
  }
  col = MIN(col, Columns - 1);  // not enough room
  while (msg_col < col) {
    msg_putchar(' ');
  }
}

/// Used for "confirm()" function, and the :confirm command prefix.
/// Versions which haven't got flexible dialogs yet, and console
/// versions, get this generic handler which uses the command line.
///
/// type  = one of:
///         VIM_QUESTION, VIM_INFO, VIM_WARNING, VIM_ERROR or VIM_GENERIC
/// title = title string (can be NULL for default)
/// (neither used in console dialogs at the moment)
///
/// Format of the "buttons" string:
/// "Button1Name\nButton2Name\nButton3Name"
/// The first button should normally be the default/accept
/// The second button should be the 'Cancel' button
/// Other buttons- use your imagination!
/// A '&' in a button name becomes a shortcut, so each '&' should be before a
/// different letter.
///
/// @param textfiel  IObuff for inputdialog(), NULL otherwise
/// @param ex_cmd  when true pressing : accepts default and starts Ex command
/// @returns 0 if cancelled, otherwise the nth button (1-indexed).
int do_dialog(int type, const char *title, const char *message, const char *buttons, int dfltbutton,
              const char *textfield, int ex_cmd)
{
  int retval = 0;
  int i;

  if (silent_mode) {  // No dialogs in silent mode ("ex -s")
    return dfltbutton;  // return default option
  }

  int save_msg_silent = msg_silent;
  int oldState = State;

  msg_silent = 0;  // If dialog prompts for input, user needs to see it! #8788

  char *hotkeys = msg_show_console_dialog(message, buttons, dfltbutton);

  while (true) {
    // Without a UI Nvim waits for input forever.
    if (!ui_active() && !input_available()) {
      retval = dfltbutton;
      break;
    }

    // Get a typed character directly from the user.
    int c = prompt_for_input(confirm_buttons, HLF_M, true, NULL);
    switch (c) {
    case CAR:                 // User accepts default option
    case NUL:
      retval = dfltbutton;
      break;
    case Ctrl_C:              // User aborts/cancels
    case ESC:
      retval = 0;
      break;
    default:                  // Could be a hotkey?
      if (c < 0) {            // special keys are ignored here
        continue;
      }
      if (c == ':' && ex_cmd) {
        retval = dfltbutton;
        ins_char_typebuf(':', 0, false);
        break;
      }

      // Make the character lowercase, as chars in "hotkeys" are.
      c = mb_tolower(c);
      retval = 1;
      for (i = 0; hotkeys[i]; i++) {
        if (utf_ptr2char(hotkeys + i) == c) {
          break;
        }
        i += utfc_ptr2len(hotkeys + i) - 1;
        retval++;
      }
      if (hotkeys[i]) {
        break;
      }
      // No hotkey match, so keep waiting
      continue;
    }
    break;
  }

  xfree(hotkeys);
  xfree(confirm_msg);
  confirm_msg = NULL;

  msg_silent = save_msg_silent;
  State = oldState;
  setmouse();

  return retval;
}

/// Copy one character from "*from" to "*to", taking care of multi-byte
/// characters.  Return the length of the character in bytes.
///
/// @param lowercase  make character lower case
static int copy_char(const char *from, char *to, bool lowercase)
  FUNC_ATTR_NONNULL_ALL
{
  if (lowercase) {
    int c = mb_tolower(utf_ptr2char(from));
    return utf_char2bytes(c, to);
  }
  int len = utfc_ptr2len(from);
  memmove(to, from, (size_t)len);
  return len;
}

#define HAS_HOTKEY_LEN 30
#define HOTK_LEN MB_MAXBYTES

/// Allocates memory for dialog string & for storing hotkeys
///
/// Finds the size of memory required for the confirm_msg & for storing hotkeys
/// and then allocates the memory for them.
/// has_hotkey array is also filled-up.
///
/// @param message Message which will be part of the confirm_msg
/// @param buttons String containing button names
/// @param[out] has_hotkey An element in this array is set to true if
///                        corresponding button has a hotkey
///
/// @return Pointer to memory allocated for storing hotkeys
static char *console_dialog_alloc(const char *message, const char *buttons, bool has_hotkey[])
{
  int lenhotkey = HOTK_LEN;  // count first button
  has_hotkey[0] = false;

  // Compute the size of memory to allocate.
  int msg_len = 0;
  int button_len = 0;
  int idx = 0;
  const char *r = buttons;
  while (*r) {
    if (*r == DLG_BUTTON_SEP) {
      button_len += 3;                  // '\n' -> ', '; 'x' -> '(x)'
      lenhotkey += HOTK_LEN;            // each button needs a hotkey
      if (idx < HAS_HOTKEY_LEN - 1) {
        has_hotkey[++idx] = false;
      }
    } else if (*r == DLG_HOTKEY_CHAR) {
      r++;
      button_len++;                     // '&a' -> '[a]'
      if (idx < HAS_HOTKEY_LEN - 1) {
        has_hotkey[idx] = true;
      }
    }

    // Advance to the next character
    MB_PTR_ADV(r);
  }

  msg_len += (int)strlen(message) + 3;     // for the NL's and NUL
  button_len += (int)strlen(buttons) + 3;  // for the ": " and NUL
  lenhotkey++;                             // for the NUL

  // If no hotkey is specified, first char is used.
  if (!has_hotkey[0]) {
    button_len += 2;                       // "x" -> "[x]"
  }

  // Now allocate space for the strings
  confirm_msg = xmalloc((size_t)msg_len);
  snprintf(confirm_msg, (size_t)msg_len, "\n%s\n", message);

  xfree(confirm_buttons);
  confirm_buttons = xmalloc((size_t)button_len);

  return xmalloc((size_t)lenhotkey);
}

/// Format the dialog string, and display it at the bottom of
/// the screen. Return a string of hotkey chars (if defined) for
/// each 'button'. If a button has no hotkey defined, the first character of
/// the button is used.
/// The hotkeys can be multi-byte characters, but without combining chars.
///
/// @return  an allocated string with hotkeys.
static char *msg_show_console_dialog(const char *message, const char *buttons, int dfltbutton)
  FUNC_ATTR_NONNULL_RET
{
  bool has_hotkey[HAS_HOTKEY_LEN] = { false };
  char *hotk = console_dialog_alloc(message, buttons, has_hotkey);

  copy_confirm_hotkeys(buttons, dfltbutton, has_hotkey, hotk);

  display_confirm_msg();
  return hotk;
}

/// Copies hotkeys into the memory allocated for it
///
/// @param buttons String containing button names
/// @param default_button_idx Number of default button
/// @param has_hotkey An element in this array is true if corresponding button
///                   has a hotkey
/// @param[out] hotkeys_ptr Pointer to the memory location where hotkeys will be copied
static void copy_confirm_hotkeys(const char *buttons, int default_button_idx,
                                 const bool has_hotkey[], char *hotkeys_ptr)
{
  // Define first default hotkey. Keep the hotkey string NUL
  // terminated to avoid reading past the end.
  hotkeys_ptr[copy_char(buttons, hotkeys_ptr, true)] = NUL;

  bool first_hotkey = false;  // Is the first char of button a hotkey
  if (!has_hotkey[0]) {
    first_hotkey = true;     // If no hotkey is specified, first char is used
  }

  // Remember where the choices start, sent as prompt to cmdline.
  char *msgp = confirm_buttons;

  int idx = 0;
  const char *r = buttons;
  while (*r) {
    if (*r == DLG_BUTTON_SEP) {
      *msgp++ = ',';
      *msgp++ = ' ';                    // '\n' -> ', '

      // Advance to next hotkey and set default hotkey
      hotkeys_ptr += strlen(hotkeys_ptr);
      hotkeys_ptr[copy_char(r + 1, hotkeys_ptr, true)] = NUL;

      if (default_button_idx) {
        default_button_idx--;
      }

      // If no hotkey is specified, first char is used.
      if (idx < HAS_HOTKEY_LEN - 1 && !has_hotkey[++idx]) {
        first_hotkey = true;
      }
    } else if (*r == DLG_HOTKEY_CHAR || first_hotkey) {
      if (*r == DLG_HOTKEY_CHAR) {
        r++;
      }

      first_hotkey = false;
      if (*r == DLG_HOTKEY_CHAR) {                 // '&&a' -> '&a'
        *msgp++ = *r;
      } else {
        // '&a' -> '[a]'
        *msgp++ = (default_button_idx == 1) ? '[' : '(';
        msgp += copy_char(r, msgp, false);
        *msgp++ = (default_button_idx == 1) ? ']' : ')';

        // redefine hotkey
        hotkeys_ptr[copy_char(r, hotkeys_ptr, true)] = NUL;
      }
    } else {
      // everything else copy literally
      msgp += copy_char(r, msgp, false);
    }

    // advance to the next character
    MB_PTR_ADV(r);
  }

  *msgp++ = ':';
  *msgp++ = ' ';
  *msgp = NUL;
}

/// Display the ":confirm" message.  Also called when screen resized.
static void display_confirm_msg(void)
{
  if (confirm_msg != NULL) {
    msg_ext_set_kind("confirm");
    msg_puts_hl(confirm_msg, HLF_M, false);
  }
}

int vim_dialog_yesno(int type, char *title, char *message, int dflt)
{
  if (do_dialog(type,
                title == NULL ? _("Question") : title,
                message,
                _("&Yes\n&No"), dflt, NULL, false) == 1) {
    return VIM_YES;
  }
  return VIM_NO;
}

int vim_dialog_yesnocancel(int type, char *title, char *message, int dflt)
{
  switch (do_dialog(type,
                    title == NULL ? _("Question") : title,
                    message,
                    _("&Yes\n&No\n&Cancel"), dflt, NULL, false)) {
  case 1:
    return VIM_YES;
  case 2:
    return VIM_NO;
  }
  return VIM_CANCEL;
}

int vim_dialog_yesnoallcancel(int type, char *title, char *message, int dflt)
{
  switch (do_dialog(type,
                    title == NULL ? "Question" : title,
                    message,
                    _("&Yes\n&No\nSave &All\n&Discard All\n&Cancel"),
                    dflt, NULL, false)) {
  case 1:
    return VIM_YES;
  case 2:
    return VIM_NO;
  case 3:
    return VIM_ALL;
  case 4:
    return VIM_DISCARDALL;
  }
  return VIM_CANCEL;
}
