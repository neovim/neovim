/// @file runtime.c
///
/// Management of runtime files (including packages)

#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <uv.h>

#include "klib/kvec.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand.h"
#include "nvim/debugger.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/userfunc.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_eval_defs.h"
#include "nvim/garray.h"
#include "nvim/getchar.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/hashtab.h"
#include "nvim/hashtab_defs.h"
#include "nvim/lua/executor.h"
#include "nvim/macros_defs.h"
#include "nvim/map_defs.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/os/fs.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/stdpaths_defs.h"
#include "nvim/path.h"
#include "nvim/pos_defs.h"
#include "nvim/profile.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/runtime.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/usercmd.h"
#include "nvim/vim_defs.h"
#ifdef USE_CRNL
# include "nvim/highlight.h"
#endif

/// Structure used to store info for each sourced file.
/// It is shared between do_source() and getsourceline().
/// This is required, because it needs to be handed to do_cmdline() and
/// sourcing can be done recursively.
typedef struct {
  FILE *fp;                     ///< opened file for sourcing
  char *nextline;               ///< if not NULL: line that was read ahead
  linenr_T sourcing_lnum;       ///< line number of the source file
  int finished;                 ///< ":finish" used
#ifdef USE_CRNL
  int fileformat;               ///< EOL_UNKNOWN, EOL_UNIX or EOL_DOS
  bool error;                   ///< true if LF found after CR-LF
#endif
  linenr_T breakpoint;          ///< next line with breakpoint or zero
  char *fname;                  ///< name of sourced file
  int dbg_tick;                 ///< debug_tick when breakpoint was set
  int level;                    ///< top nesting level of sourced file
  vimconv_T conv;               ///< type of conversion
} source_cookie_T;

typedef struct {
  char *path;
  bool after;
  TriState has_lua;
} SearchPathItem;

typedef kvec_t(SearchPathItem) RuntimeSearchPath;
typedef kvec_t(char *) CharVec;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "runtime.c.generated.h"
#endif

garray_T exestack = { 0, 0, sizeof(estack_T), 50, NULL };
garray_T script_items = { 0, 0, sizeof(scriptitem_T *), 20, NULL };

/// The names of packages that once were loaded are remembered.
static garray_T ga_loaded = { 0, 0, sizeof(char *), 4, NULL };

static int last_current_SID_seq = 0;

/// Initialize the execution stack.
void estack_init(void)
{
  ga_grow(&exestack, 10);
  estack_T *entry = ((estack_T *)exestack.ga_data) + exestack.ga_len;
  entry->es_type = ETYPE_TOP;
  entry->es_name = NULL;
  entry->es_lnum = 0;
  entry->es_info.ufunc = NULL;
  exestack.ga_len++;
}

/// Add an item to the execution stack.
/// @return  the new entry
estack_T *estack_push(etype_T type, char *name, linenr_T lnum)
{
  ga_grow(&exestack, 1);
  estack_T *entry = ((estack_T *)exestack.ga_data) + exestack.ga_len;
  entry->es_type = type;
  entry->es_name = name;
  entry->es_lnum = lnum;
  entry->es_info.ufunc = NULL;
  exestack.ga_len++;
  return entry;
}

/// Add a user function to the execution stack.
void estack_push_ufunc(ufunc_T *ufunc, linenr_T lnum)
{
  estack_T *entry = estack_push(ETYPE_UFUNC,
                                ufunc->uf_name_exp != NULL ? ufunc->uf_name_exp : ufunc->uf_name,
                                lnum);
  if (entry != NULL) {
    entry->es_info.ufunc = ufunc;
  }
}

/// Take an item off of the execution stack.
void estack_pop(void)
{
  if (exestack.ga_len > 1) {
    exestack.ga_len--;
  }
}

/// Get the current value for <sfile> in allocated memory.
/// @param which  ESTACK_SFILE for <sfile>, ESTACK_STACK for <stack> or
///               ESTACK_SCRIPT for <script>.
char *estack_sfile(estack_arg_T which)
{
  const estack_T *entry = ((estack_T *)exestack.ga_data) + exestack.ga_len - 1;
  if (which == ESTACK_SFILE && entry->es_type != ETYPE_UFUNC) {
    if (entry->es_name == NULL) {
      return NULL;
    }
    return xstrdup(entry->es_name);
  }

  // If evaluated in a function or autocommand, return the path of the script
  // where it is defined, at script level the current script path is returned
  // instead.
  if (which == ESTACK_SCRIPT) {
    // Walk the stack backwards, starting from the current frame.
    for (int idx = exestack.ga_len - 1; idx >= 0; idx--, entry--) {
      if (entry->es_type == ETYPE_UFUNC || entry->es_type == ETYPE_AUCMD) {
        const sctx_T *const def_ctx = (entry->es_type == ETYPE_UFUNC
                                       ? &entry->es_info.ufunc->uf_script_ctx
                                       : &entry->es_info.aucmd->script_ctx);
        return def_ctx->sc_sid > 0
               ? xstrdup((SCRIPT_ITEM(def_ctx->sc_sid)->sn_name))
               : NULL;
      } else if (entry->es_type == ETYPE_SCRIPT) {
        return xstrdup(entry->es_name);
      }
    }
    return NULL;
  }

  // Give information about each stack entry up to the root.
  // For a function we compose the call stack, as it was done in the past:
  //   "function One[123]..Two[456]..Three"
  garray_T ga;
  ga_init(&ga, sizeof(char), 100);
  etype_T last_type = ETYPE_SCRIPT;
  for (int idx = 0; idx < exestack.ga_len; idx++) {
    entry = ((estack_T *)exestack.ga_data) + idx;
    if (entry->es_name != NULL) {
      size_t len = strlen(entry->es_name) + 15;
      char *type_name = "";
      if (entry->es_type != last_type) {
        switch (entry->es_type) {
        case ETYPE_SCRIPT:
          type_name = "script "; break;
        case ETYPE_UFUNC:
          type_name = "function "; break;
        default:
          type_name = ""; break;
        }
        last_type = entry->es_type;
      }
      len += strlen(type_name);
      ga_grow(&ga, (int)len);
      linenr_T lnum = idx == exestack.ga_len - 1
                      ? which == ESTACK_STACK ? SOURCING_LNUM : 0
                      : entry->es_lnum;
      char *dots = idx == exestack.ga_len - 1 ? "" : "..";
      if (lnum == 0) {
        // For the bottom entry of <sfile>: do not add the line number,
        // it is used in <slnum>.  Also leave it out when the number is
        // not set.
        vim_snprintf((char *)ga.ga_data + ga.ga_len, len, "%s%s%s",
                     type_name, entry->es_name, dots);
      } else {
        vim_snprintf((char *)ga.ga_data + ga.ga_len, len, "%s%s[%" PRIdLINENR "]%s",
                     type_name, entry->es_name, lnum, dots);
      }
      ga.ga_len += (int)strlen((char *)ga.ga_data + ga.ga_len);
    }
  }

  return (char *)ga.ga_data;
}

static bool runtime_search_path_valid = false;
static int *runtime_search_path_ref = NULL;
static RuntimeSearchPath runtime_search_path;
static RuntimeSearchPath runtime_search_path_thread;
static uv_mutex_t runtime_search_path_mutex;

void runtime_init(void)
{
  uv_mutex_init(&runtime_search_path_mutex);
}

/// Get DIP_ flags from the [where] argument of a :runtime command.
/// "*argp" is advanced to after the [where] argument.
static int get_runtime_cmd_flags(char **argp, size_t where_len)
{
  char *arg = *argp;

  if (where_len == 0) {
    return 0;
  }

  if (strncmp(arg, "START", where_len) == 0) {
    *argp = skipwhite(arg + where_len);
    return DIP_START + DIP_NORTP;
  }
  if (strncmp(arg, "OPT", where_len) == 0) {
    *argp = skipwhite(arg + where_len);
    return DIP_OPT + DIP_NORTP;
  }
  if (strncmp(arg, "PACK", where_len) == 0) {
    *argp = skipwhite(arg + where_len);
    return DIP_START + DIP_OPT + DIP_NORTP;
  }
  if (strncmp(arg, "ALL", where_len) == 0) {
    *argp = skipwhite(arg + where_len);
    return DIP_START + DIP_OPT;
  }

  return 0;
}

/// ":runtime [where] {name}"
void ex_runtime(exarg_T *eap)
{
  char *arg = eap->arg;
  int flags = eap->forceit ? DIP_ALL : 0;
  char *p = skiptowhite(arg);
  flags += get_runtime_cmd_flags(&arg, (size_t)(p - arg));
  assert(arg != NULL);  // suppress clang false positive
  source_runtime(arg, flags);
}

static int runtime_expand_flags;

/// Set the completion context for the :runtime command.
void set_context_in_runtime_cmd(expand_T *xp, const char *arg)
{
  char *p = skiptowhite(arg);
  runtime_expand_flags
    = *p != NUL ? get_runtime_cmd_flags((char **)&arg, (size_t)(p - arg)) : 0;
  // Skip to the last argument.
  while (*(p = skiptowhite_esc(arg)) != NUL) {
    if (runtime_expand_flags == 0) {
      // When there are multiple arguments and [where] is not specified,
      // use an unrelated non-zero flag to avoid expanding [where].
      runtime_expand_flags = DIP_ALL;
    }
    arg = skipwhite(p);
  }
  xp->xp_context = EXPAND_RUNTIME;
  xp->xp_pattern = (char *)arg;
}

/// Source all .vim and .lua files in "fnames" with .vim files being sourced first.
static bool source_callback_vim_lua(int num_fnames, char **fnames, bool all, void *cookie)
{
  bool did_one = false;

  for (int i = 0; i < num_fnames; i++) {
    if (path_with_extension(fnames[i], "vim")) {
      do_source(fnames[i], false, DOSO_NONE, cookie);
      did_one = true;
      if (!all) {
        return true;
      }
    }
  }

  for (int i = 0; i < num_fnames; i++) {
    if (path_with_extension(fnames[i], "lua")) {
      do_source(fnames[i], false, DOSO_NONE, cookie);
      did_one = true;
      if (!all) {
        return true;
      }
    }
  }

  return did_one;
}

/// Source all files in "fnames" with .vim files sourced first, .lua files
/// sourced second, and any remaining files sourced last.
static bool source_callback(int num_fnames, char **fnames, bool all, void *cookie)
{
  bool did_one = source_callback_vim_lua(num_fnames, fnames, all, cookie);

  if (!all && did_one) {
    return true;
  }

  for (int i = 0; i < num_fnames; i++) {
    if (!path_with_extension(fnames[i], "vim")
        && !path_with_extension(fnames[i], "lua")) {
      do_source(fnames[i], false, DOSO_NONE, cookie);
      did_one = true;
      if (!all) {
        return true;
      }
    }
  }

  return did_one;
}

/// Find the patterns in "name" in all directories in "path" and invoke
/// "callback(fname, cookie)".
/// "prefix" is prepended to each pattern in "name".
/// When "flags" has DIP_ALL: source all files, otherwise only the first one.
/// When "flags" has DIP_DIR: find directories instead of files.
/// When "flags" has DIP_ERR: give an error message if there is no match.
///
/// Return FAIL when no file could be sourced, OK otherwise.
int do_in_path(const char *path, const char *prefix, char *name, int flags,
               DoInRuntimepathCB callback, void *cookie)
  FUNC_ATTR_NONNULL_ARG(1, 2)
{
  bool did_one = false;

  // Make a copy of 'runtimepath'.  Invoking the callback may change the
  // value.
  char *rtp_copy = xstrdup(path);
  char *buf = xmallocz(MAXPATHL);
  {
    char *tail;
    if (p_verbose > 10 && name != NULL) {
      verbose_enter();
      if (*prefix != NUL) {
        smsg(0, _("Searching for \"%s\" under \"%s\" in \"%s\""), name, prefix, path);
      } else {
        smsg(0, _("Searching for \"%s\" in \"%s\""), name, path);
      }
      verbose_leave();
    }

    bool do_all = (flags & DIP_ALL) != 0;

    // Loop over all entries in 'runtimepath'.
    char *rtp = rtp_copy;
    while (*rtp != NUL && (do_all || !did_one)) {
      // Copy the path from 'runtimepath' to buf[].
      copy_option_part(&rtp, buf, MAXPATHL, ",");
      size_t buflen = strlen(buf);

      // Skip after or non-after directories.
      if (flags & (DIP_NOAFTER | DIP_AFTER)) {
        bool is_after = path_is_after(buf, buflen);

        if ((is_after && (flags & DIP_NOAFTER))
            || (!is_after && (flags & DIP_AFTER))) {
          continue;
        }
      }

      if (name == NULL) {
        (*callback)(1, &buf, do_all, cookie);
        did_one = true;
      } else if (buflen + 2 + strlen(prefix) + strlen(name) < MAXPATHL) {
        add_pathsep(buf);
        STRCAT(buf, prefix);
        tail = buf + strlen(buf);

        // Loop over all patterns in "name"
        char *np = name;
        while (*np != NUL && (do_all || !did_one)) {
          // Append the pattern from "name" to buf[].
          assert(MAXPATHL >= (tail - buf));
          copy_option_part(&np, tail, (size_t)(MAXPATHL - (tail - buf)), "\t ");

          if (p_verbose > 10) {
            verbose_enter();
            smsg(0, _("Searching for \"%s\""), buf);
            verbose_leave();
          }

          int ew_flags = ((flags & DIP_DIR) ? EW_DIR : EW_FILE)
                         | ((flags & DIP_DIRFILE) ? (EW_DIR|EW_FILE) : 0);

          did_one |= gen_expand_wildcards_and_cb(1, &buf, ew_flags, do_all, callback,
                                                 cookie) == OK;
        }
      }
    }
  }
  xfree(buf);
  xfree(rtp_copy);
  if (!did_one && name != NULL) {
    char *basepath = path == p_rtp ? "runtimepath" : "packpath";

    if (flags & DIP_ERR) {
      semsg(_(e_dirnotf), basepath, name);
    } else if (p_verbose > 1) {
      verbose_enter();
      smsg(0, _("not found in '%s': \"%s\""), basepath, name);
      verbose_leave();
    }
  }

  return did_one ? OK : FAIL;
}

static RuntimeSearchPath runtime_search_path_get_cached(int *ref)
  FUNC_ATTR_NONNULL_ALL
{
  runtime_search_path_validate();

  *ref = 0;
  if (runtime_search_path_ref == NULL) {
    // cached path was unreferenced. keep a ref to
    // prevent runtime_search_path() to freeing it too early
    (*ref)++;
    runtime_search_path_ref = ref;
  }
  return runtime_search_path;
}

static RuntimeSearchPath copy_runtime_search_path(const RuntimeSearchPath src)
{
  RuntimeSearchPath dst = KV_INITIAL_VALUE;
  for (size_t j = 0; j < kv_size(src); j++) {
    SearchPathItem src_item = kv_A(src, j);
    kv_push(dst, ((SearchPathItem){ xstrdup(src_item.path), src_item.after, src_item.has_lua }));
  }

  return dst;
}

static void runtime_search_path_unref(RuntimeSearchPath path, const int *ref)
  FUNC_ATTR_NONNULL_ALL
{
  if (*ref) {
    if (runtime_search_path_ref == ref) {
      runtime_search_path_ref = NULL;
    } else {
      runtime_search_path_free(path);
    }
  }
}

/// Find the file "name" in all directories in "path" and invoke
/// "callback(fname, cookie)".
/// "name" can contain wildcards.
/// When "flags" has DIP_ALL: source all files, otherwise only the first one.
/// When "flags" has DIP_DIR: find directories instead of files.
/// When "flags" has DIP_ERR: give an error message if there is no match.
///
/// return FAIL when no file could be sourced, OK otherwise.
static int do_in_cached_path(char *name, int flags, DoInRuntimepathCB callback, void *cookie)
{
  char *tail;
  bool did_one = false;

  char buf[MAXPATHL];

  if (p_verbose > 10 && name != NULL) {
    verbose_enter();
    smsg(0, _("Searching for \"%s\" in runtime path"), name);
    verbose_leave();
  }

  int ref;
  RuntimeSearchPath path = runtime_search_path_get_cached(&ref);

  bool do_all = (flags & DIP_ALL) != 0;

  // Loop over all entries in cached path
  for (size_t j = 0; j < kv_size(path); j++) {
    SearchPathItem item = kv_A(path, j);
    size_t buflen = strlen(item.path);

    // Skip after or non-after directories.
    if (flags & (DIP_NOAFTER | DIP_AFTER)) {
      if ((item.after && (flags & DIP_NOAFTER))
          || (!item.after && (flags & DIP_AFTER))) {
        continue;
      }
    }

    if (name == NULL) {
      (*callback)(1, &item.path, do_all, cookie);
    } else if (buflen + strlen(name) + 2 < MAXPATHL) {
      STRCPY(buf, item.path);
      add_pathsep(buf);
      tail = buf + strlen(buf);

      // Loop over all patterns in "name"
      char *np = name;

      while (*np != NUL && (do_all || !did_one)) {
        // Append the pattern from "name" to buf[].
        assert(MAXPATHL >= (tail - buf));
        copy_option_part(&np, tail, (size_t)(MAXPATHL - (tail - buf)), "\t ");

        if (p_verbose > 10) {
          verbose_enter();
          smsg(0, _("Searching for \"%s\""), buf);
          verbose_leave();
        }

        int ew_flags = ((flags & DIP_DIR) ? EW_DIR : EW_FILE)
                       | ((flags & DIP_DIRFILE) ? (EW_DIR|EW_FILE) : 0)
                       | EW_NOBREAK;

        // Expand wildcards, invoke the callback for each match.
        char *(pat[]) = { buf };
        did_one |= gen_expand_wildcards_and_cb(1, pat, ew_flags, do_all, callback, cookie) == OK;
      }
    }
  }

  if (!did_one && name != NULL) {
    if (flags & DIP_ERR) {
      semsg(_(e_dirnotf), "runtime path", name);
    } else if (p_verbose > 1) {
      verbose_enter();
      smsg(0, _("not found in runtime path: \"%s\""), name);
      verbose_leave();
    }
  }

  runtime_search_path_unref(path, &ref);

  return did_one ? OK : FAIL;
}

Array runtime_inspect(Arena *arena)
{
  RuntimeSearchPath path = runtime_search_path;
  Array rv = arena_array(arena, kv_size(path));

  for (size_t i = 0; i < kv_size(path); i++) {
    SearchPathItem *item = &kv_A(path, i);
    Array entry = arena_array(arena, 3);
    ADD_C(entry, CSTR_AS_OBJ(item->path));
    ADD_C(entry, BOOLEAN_OBJ(item->after));
    if (item->has_lua != kNone) {
      ADD_C(entry, BOOLEAN_OBJ(item->has_lua == kTrue));
    }
    ADD_C(rv, ARRAY_OBJ(entry));
  }
  return rv;
}

ArrayOf(String) runtime_get_named(bool lua, Array pat, bool all, Arena *arena)
{
  int ref;
  RuntimeSearchPath path = runtime_search_path_get_cached(&ref);
  static char buf[MAXPATHL];

  ArrayOf(String) rv = runtime_get_named_common(lua, pat, all, path, buf, sizeof buf, arena);

  runtime_search_path_unref(path, &ref);
  return rv;
}

ArrayOf(String) runtime_get_named_thread(bool lua, Array pat, bool all)
{
  // TODO(bfredl): avoid contention between multiple worker threads?
  uv_mutex_lock(&runtime_search_path_mutex);
  static char buf[MAXPATHL];
  ArrayOf(String) rv = runtime_get_named_common(lua, pat, all, runtime_search_path_thread,
                                                buf, sizeof buf, NULL);
  uv_mutex_unlock(&runtime_search_path_mutex);
  return rv;
}

static ArrayOf(String) runtime_get_named_common(bool lua, Array pat, bool all,
                                                RuntimeSearchPath path, char *buf, size_t buf_len,
                                                Arena *arena)
{
  ArrayOf(String) rv = arena_array(arena, kv_size(path) * pat.size);
  for (size_t i = 0; i < kv_size(path); i++) {
    SearchPathItem *item = &kv_A(path, i);
    if (lua) {
      if (item->has_lua == kNone) {
        size_t size = (size_t)snprintf(buf, buf_len, "%s/lua/", item->path);
        item->has_lua = (size < buf_len && os_isdir(buf));
      }
      if (item->has_lua == kFalse) {
        continue;
      }
    }

    for (size_t j = 0; j < pat.size; j++) {
      Object pat_item = pat.items[j];
      if (pat_item.type == kObjectTypeString) {
        size_t size = (size_t)snprintf(buf, buf_len, "%s/%s",
                                       item->path, pat_item.data.string.data);
        if (size < buf_len) {
          if (os_file_is_readable(buf)) {
            ADD_C(rv, CSTR_TO_ARENA_OBJ(arena, buf));
            if (!all) {
              goto done;
            }
          }
        }
      }
    }
  }
done:
  return rv;
}

/// Find "name" in "path".  When found, invoke the callback function for
/// it: callback(fname, "cookie")
/// When "flags" has DIP_ALL repeat for all matches, otherwise only the first
/// one is used.
/// Returns OK when at least one match found, FAIL otherwise.
/// If "name" is NULL calls callback for each entry in "path". Cookie is
/// passed by reference in this case, setting it to NULL indicates that callback
/// has done its job.
int do_in_path_and_pp(char *path, char *name, int flags, DoInRuntimepathCB callback, void *cookie)
{
  int done = FAIL;

  if ((flags & DIP_NORTP) == 0) {
    done |= do_in_path(path, "", (name && !*name) ? NULL : name, flags, callback,
                       cookie);
  }

  if ((done == FAIL || (flags & DIP_ALL)) && (flags & DIP_START)) {
    const char *prefix
      = (flags & DIP_AFTER) ? "pack/*/start/*/after/" : "pack/*/start/*/";  // NOLINT
    done |= do_in_path(p_pp, prefix, name, flags & ~DIP_AFTER, callback, cookie);

    if (done == FAIL || (flags & DIP_ALL)) {
      prefix = (flags & DIP_AFTER) ? "start/*/after/" : "start/*/";  // NOLINT
      done |= do_in_path(p_pp, prefix, name, flags & ~DIP_AFTER, callback, cookie);
    }
  }

  if ((done == FAIL || (flags & DIP_ALL)) && (flags & DIP_OPT)) {
    done |= do_in_path(p_pp, "pack/*/opt/*/", name, flags, callback, cookie);  // NOLINT

    if (done == FAIL || (flags & DIP_ALL)) {
      done |= do_in_path(p_pp, "opt/*/", name, flags, callback, cookie);  // NOLINT
    }
  }

  return done;
}

static void push_path(RuntimeSearchPath *search_path, Set(String) *rtp_used, char *entry,
                      bool after)
{
  String *key_alloc;
  if (set_put_ref(String, rtp_used, cstr_as_string(entry), &key_alloc)) {
    *key_alloc = cstr_to_string(entry);
    kv_push(*search_path, ((SearchPathItem){ key_alloc->data, after, kNone }));
  }
}

static void expand_rtp_entry(RuntimeSearchPath *search_path, Set(String) *rtp_used, char *entry,
                             bool after)
{
  if (set_has(String, rtp_used, cstr_as_string(entry))) {
    return;
  }

  if (!*entry) {
    push_path(search_path, rtp_used, entry, after);
  }

  int num_files;
  char **files;
  char *(pat[]) = { entry };
  if (gen_expand_wildcards(1, pat, &num_files, &files, EW_DIR | EW_NOBREAK) == OK) {
    for (int i = 0; i < num_files; i++) {
      push_path(search_path, rtp_used, files[i], after);
    }
    FreeWild(num_files, files);
  }
}

static void expand_pack_entry(RuntimeSearchPath *search_path, Set(String) *rtp_used,
                              CharVec *after_path, char *pack_entry, size_t pack_entry_len)
{
  static char buf[MAXPATHL];
  char *(start_pat[]) = { "/pack/*/start/*", "/start/*" };  // NOLINT
  for (int i = 0; i < 2; i++) {
    if (pack_entry_len + strlen(start_pat[i]) + 1 > sizeof buf) {
      continue;
    }
    xstrlcpy(buf, pack_entry, sizeof buf);
    xstrlcpy(buf + pack_entry_len, start_pat[i], sizeof buf - pack_entry_len);
    expand_rtp_entry(search_path, rtp_used, buf, false);
    size_t after_size = strlen(buf) + 7;
    char *after = xmallocz(after_size);
    xstrlcpy(after, buf, after_size);
    xstrlcat(after, "/after", after_size);
    kv_push(*after_path, after);
  }
}

static bool path_is_after(char *buf, size_t buflen)
{
  // NOTE: we only consider dirs exactly matching "after" to be an AFTER dir.
  // vim8 considers all dirs like "foo/bar_after", "Xafter" etc, as an
  // "after" dir in SOME codepaths not not in ALL codepaths.
  return buflen >= 5
         && (!(buflen >= 6) || vim_ispathsep(buf[buflen - 6]))
         && strcmp(buf + buflen - 5, "after") == 0;
}

static RuntimeSearchPath runtime_search_path_build(void)
{
  kvec_t(String) pack_entries = KV_INITIAL_VALUE;
  Map(String, int) pack_used = MAP_INIT;
  Set(String) rtp_used = SET_INIT;
  RuntimeSearchPath search_path = KV_INITIAL_VALUE;
  CharVec after_path = KV_INITIAL_VALUE;

  static char buf[MAXPATHL];
  for (char *entry = p_pp; *entry != NUL;) {
    char *cur_entry = entry;
    copy_option_part(&entry, buf, MAXPATHL, ",");

    String the_entry = { .data = cur_entry, .size = strlen(buf) };

    kv_push(pack_entries, the_entry);
    map_put(String, int)(&pack_used, the_entry, 0);
  }

  char *rtp_entry;
  for (rtp_entry = p_rtp; *rtp_entry != NUL;) {
    char *cur_entry = rtp_entry;
    copy_option_part(&rtp_entry, buf, MAXPATHL, ",");
    size_t buflen = strlen(buf);

    if (path_is_after(buf, buflen)) {
      rtp_entry = cur_entry;
      break;
    }

    // fact: &rtp entries can contain wild chars
    expand_rtp_entry(&search_path, &rtp_used, buf, false);

    handle_T *h = map_ref(String, int)(&pack_used, cstr_as_string(buf), NULL);
    if (h) {
      (*h)++;
      expand_pack_entry(&search_path, &rtp_used, &after_path, buf, buflen);
    }
  }

  for (size_t i = 0; i < kv_size(pack_entries); i++) {
    String item = kv_A(pack_entries, i);
    handle_T h = map_get(String, int)(&pack_used, item);
    if (h == 0) {
      expand_pack_entry(&search_path, &rtp_used, &after_path, item.data, item.size);
    }
  }

  // "after" packages
  for (size_t i = 0; i < kv_size(after_path); i++) {
    expand_rtp_entry(&search_path, &rtp_used, kv_A(after_path, i), true);
    xfree(kv_A(after_path, i));
  }

  // "after" dirs in rtp
  for (; *rtp_entry != NUL;) {
    copy_option_part(&rtp_entry, buf, MAXPATHL, ",");
    expand_rtp_entry(&search_path, &rtp_used, buf, path_is_after(buf, strlen(buf)));
  }

  // strings are not owned
  kv_destroy(pack_entries);
  kv_destroy(after_path);
  map_destroy(String, &pack_used);
  set_destroy(String, &rtp_used);

  return search_path;
}

const char *did_set_runtimepackpath(optset_T *args)
{
  runtime_search_path_valid = false;
  return NULL;
}

static void runtime_search_path_free(RuntimeSearchPath path)
{
  for (size_t j = 0; j < kv_size(path); j++) {
    SearchPathItem item = kv_A(path, j);
    xfree(item.path);
  }
  kv_destroy(path);
}

void runtime_search_path_validate(void)
{
  if (!nlua_is_deferred_safe()) {
    // Cannot rebuild search path in an async context. As a plugin will invoke
    // itself asynchronously from sync code in the same plugin, the sought
    // after lua/autoload module will most likely already be in the cached path.
    // Thus prefer using the stale cache over erroring out in this situation.
    return;
  }
  if (!runtime_search_path_valid) {
    if (!runtime_search_path_ref) {
      runtime_search_path_free(runtime_search_path);
    }
    runtime_search_path = runtime_search_path_build();
    runtime_search_path_valid = true;
    runtime_search_path_ref = NULL;  // initially unowned
    uv_mutex_lock(&runtime_search_path_mutex);
    runtime_search_path_free(runtime_search_path_thread);
    runtime_search_path_thread = copy_runtime_search_path(runtime_search_path);
    uv_mutex_unlock(&runtime_search_path_mutex);
  }
}

/// Just like do_in_path_and_pp(), using 'runtimepath' for "path".
int do_in_runtimepath(char *name, int flags, DoInRuntimepathCB callback, void *cookie)
{
  int success = FAIL;
  if (!(flags & DIP_NORTP)) {
    success |= do_in_cached_path((name && !*name) ? NULL : name, flags, callback, cookie);
    flags = (flags & ~DIP_START) | DIP_NORTP;
  }
  // TODO(bfredl): we could integrate disabled OPT dirs into the cached path
  // which would effectivize ":packadd myoptpack" as well
  if ((flags & (DIP_START|DIP_OPT)) && (success == FAIL || (flags & DIP_ALL))) {
    success |= do_in_path_and_pp(p_rtp, name, flags, callback, cookie);
  }
  return success;
}

/// Source the file "name" from all directories in 'runtimepath'.
/// "name" can contain wildcards.
/// When "flags" has DIP_ALL: source all files, otherwise only the first one.
///
/// return FAIL when no file could be sourced, OK otherwise.
int source_runtime(char *name, int flags)
{
  return do_in_runtimepath(name, flags, source_callback, NULL);
}

/// Just like source_runtime(), but only source vim and lua files
int source_runtime_vim_lua(char *name, int flags)
{
  return do_in_runtimepath(name, flags, source_callback_vim_lua, NULL);
}

/// Just like source_runtime(), but:
/// - use "path" instead of 'runtimepath'.
/// - only source .vim and .lua files
int source_in_path_vim_lua(char *path, char *name, int flags)
{
  return do_in_path_and_pp(path, name, flags, source_callback_vim_lua, NULL);
}

/// Expand wildcards in "pats" and invoke callback matches.
///
/// @param      num_pat  is number of input patterns.
/// @param      patx     is an array of pointers to input patterns.
/// @param      flags    is a combination of EW_* flags used in
///                      expand_wildcards().
/// @param      all      invoke callback on all matches or just one
/// @param      callback called for each match.
/// @param      cookie   context for callback
///
/// @returns             OK when some files were found, FAIL otherwise.
static int gen_expand_wildcards_and_cb(int num_pat, char **pats, int flags, bool all,
                                       DoInRuntimepathCB callback, void *cookie)
{
  int num_files;
  char **files;

  if (gen_expand_wildcards(num_pat, pats, &num_files, &files, flags) != OK) {
    return FAIL;
  }

  (*callback)(num_files, files, all, cookie);

  FreeWild(num_files, files);

  return OK;
}

/// Add the package directory to 'runtimepath'
///
/// @param fname the package path
/// @param is_pack whether the added dir is a "pack/*/start/*/" style package
static int add_pack_dir_to_rtp(char *fname, bool is_pack)
{
  char *p;
  char *afterdir = NULL;
  int retval = FAIL;

  char *p1 = get_past_head(fname);
  char *p2 = p1;
  char *p3 = p1;
  char *p4 = p1;
  for (p = p1; *p; MB_PTR_ADV(p)) {
    if (vim_ispathsep_nocolon(*p)) {
      p4 = p3;
      p3 = p2;
      p2 = p1;
      p1 = p;
    }
  }

  // now we have:
  // rtp/pack/name/start/name
  //    p4   p3   p2   p1
  //
  // find the part up to "pack" in 'runtimepath'
  p4++;  // append pathsep in order to expand symlink
  char c = *p4;
  *p4 = NUL;
  char *const ffname = fix_fname(fname);
  *p4 = c;

  if (ffname == NULL) {
    return FAIL;
  }

  // Find "ffname" in "p_rtp", ignoring '/' vs '\' differences
  // Also stop at the first "after" directory
  size_t fname_len = strlen(ffname);
  char *buf = try_malloc(MAXPATHL);
  if (buf == NULL) {
    goto theend;
  }
  const char *insp = NULL;
  const char *after_insp = NULL;
  for (const char *entry = p_rtp; *entry != NUL;) {
    const char *cur_entry = entry;

    copy_option_part((char **)&entry, buf, MAXPATHL, ",");

    if ((p = strstr(buf, "after")) != NULL
        && p > buf
        && vim_ispathsep(p[-1])
        && (vim_ispathsep(p[5]) || p[5] == NUL || p[5] == ',')) {
      if (insp == NULL) {
        // Did not find "ffname" before the first "after" directory,
        // insert it before this entry.
        insp = cur_entry;
      }
      after_insp = cur_entry;
      break;
    }

    if (insp == NULL) {
      add_pathsep(buf);
      char *const rtp_ffname = fix_fname(buf);
      if (rtp_ffname == NULL) {
        goto theend;
      }
      bool match = path_fnamencmp(rtp_ffname, ffname, fname_len) == 0;
      xfree(rtp_ffname);
      if (match) {
        // Insert "ffname" after this entry (and comma).
        insp = entry;
      }
    }
  }

  if (insp == NULL) {
    // Both "fname" and "after" not found, append at the end.
    insp = p_rtp + strlen(p_rtp);
  }

  // check if rtp/pack/name/start/name/after exists
  afterdir = concat_fnames(fname, "after", true);
  size_t afterlen = 0;
  if (is_pack ? pack_has_entries(afterdir) : os_isdir(afterdir)) {
    afterlen = strlen(afterdir) + 1;  // add one for comma
  }

  const size_t oldlen = strlen(p_rtp);
  const size_t addlen = strlen(fname) + 1;  // add one for comma
  const size_t new_rtp_capacity = oldlen + addlen + afterlen + 1;
  // add one for NUL ------------------------------------------^
  char *const new_rtp = try_malloc(new_rtp_capacity);
  if (new_rtp == NULL) {
    goto theend;
  }

  // We now have 'rtp' parts: {keep}{keep_after}{rest}.
  // Create new_rtp, first: {keep},{fname}
  size_t keep = (size_t)(insp - p_rtp);
  memmove(new_rtp, p_rtp, keep);
  size_t new_rtp_len = keep;
  if (*insp == NUL) {
    new_rtp[new_rtp_len++] = ',';  // add comma before
  }
  memmove(new_rtp + new_rtp_len, fname, addlen - 1);
  new_rtp_len += addlen - 1;
  if (*insp != NUL) {
    new_rtp[new_rtp_len++] = ',';  // add comma after
  }

  if (afterlen > 0 && after_insp != NULL) {
    size_t keep_after = (size_t)(after_insp - p_rtp);

    // Add to new_rtp: {keep},{fname}{keep_after},{afterdir}
    memmove(new_rtp + new_rtp_len, p_rtp + keep, keep_after - keep);
    new_rtp_len += keep_after - keep;
    memmove(new_rtp + new_rtp_len, afterdir, afterlen - 1);
    new_rtp_len += afterlen - 1;
    new_rtp[new_rtp_len++] = ',';
    keep = keep_after;
  }

  if (p_rtp[keep] != NUL) {
    // Append rest: {keep},{fname}{keep_after},{afterdir}{rest}
    memmove(new_rtp + new_rtp_len, p_rtp + keep, oldlen - keep + 1);
  } else {
    new_rtp[new_rtp_len] = NUL;
  }

  if (afterlen > 0 && after_insp == NULL) {
    // Append afterdir when "after" was not found:
    // {keep},{fname}{rest},{afterdir}
    xstrlcat(new_rtp, ",", new_rtp_capacity);
    xstrlcat(new_rtp, afterdir, new_rtp_capacity);
  }

  set_option_value_give_err(kOptRuntimepath, CSTR_AS_OPTVAL(new_rtp), 0);
  xfree(new_rtp);
  retval = OK;

theend:
  xfree(buf);
  xfree(ffname);
  xfree(afterdir);
  return retval;
}

/// Load scripts in "plugin" directory of the package.
/// For opt packages, also load scripts in "ftdetect" (start packages already
/// load these from filetype.lua)
static int load_pack_plugin(bool opt, char *fname)
{
  static const char plugpat[] = "%s/plugin/**/*";  // NOLINT
  static const char ftpat[] = "%s/ftdetect/*";  // NOLINT

  char *const ffname = fix_fname(fname);
  size_t len = strlen(ffname) + sizeof(plugpat);
  char *pat = xmallocz(len);

  vim_snprintf(pat, len, plugpat, ffname);
  gen_expand_wildcards_and_cb(1, &pat, EW_FILE, true, source_callback_vim_lua, NULL);

  char *cmd = xstrdup("g:did_load_filetypes");

  // If runtime/filetype.lua wasn't loaded yet, the scripts will be
  // found when it loads.
  if (opt && eval_to_number(cmd) > 0) {
    do_cmdline_cmd("augroup filetypedetect");
    vim_snprintf(pat, len, ftpat, ffname);
    gen_expand_wildcards_and_cb(1, &pat, EW_FILE, true, source_callback_vim_lua, NULL);
    do_cmdline_cmd("augroup END");
  }
  xfree(cmd);
  xfree(pat);
  xfree(ffname);

  return OK;
}

// used for "cookie" of add_pack_plugin()
static int APP_ADD_DIR;
static int APP_LOAD;
static int APP_BOTH;

static void add_pack_plugins(bool opt, int num_fnames, char **fnames, bool all, void *cookie)
{
  bool did_one = false;

  if (cookie != &APP_LOAD) {
    char *buf = xmalloc(MAXPATHL);
    for (int i = 0; i < num_fnames; i++) {
      bool found = false;

      const char *p = p_rtp;
      while (*p != NUL) {
        copy_option_part((char **)&p, buf, MAXPATHL, ",");
        if (path_fnamecmp(buf, fnames[i]) == 0) {
          found = true;
          break;
        }
      }
      if (!found) {
        // directory is not yet in 'runtimepath', add it
        if (add_pack_dir_to_rtp(fnames[i], false) == FAIL) {
          xfree(buf);
          return;
        }
      }
      did_one = true;
      if (!all) {
        break;
      }
    }
    xfree(buf);
  }

  if (!all && did_one) {
    return;
  }

  if (cookie != &APP_ADD_DIR) {
    for (int i = 0; i < num_fnames; i++) {
      load_pack_plugin(opt, fnames[i]);
      if (!all) {
        break;
      }
    }
  }
}

static bool add_start_pack_plugins(int num_fnames, char **fnames, bool all, void *cookie)
{
  add_pack_plugins(false, num_fnames, fnames, all, cookie);
  return num_fnames > 0;
}

static bool add_opt_pack_plugins(int num_fnames, char **fnames, bool all, void *cookie)
{
  add_pack_plugins(true, num_fnames, fnames, all, cookie);
  return num_fnames > 0;
}

/// Add all packages in the "start" directory to 'runtimepath'.
void add_pack_start_dirs(void)
{
  do_in_path(p_pp, "", NULL, DIP_ALL + DIP_DIR, add_pack_start_dir, NULL);
}

static bool pack_has_entries(char *buf)
{
  int num_files;
  char **files;
  char *(pat[]) = { buf };
  if (gen_expand_wildcards(1, pat, &num_files, &files, EW_DIR) == OK) {
    FreeWild(num_files, files);
  }
  return num_files > 0;
}

static bool add_pack_start_dir(int num_fnames, char **fnames, bool all, void *cookie)
{
  static char buf[MAXPATHL];
  for (int i = 0; i < num_fnames; i++) {
    char *(start_pat[]) = { "/start/*", "/pack/*/start/*" };  // NOLINT
    for (int j = 0; j < 2; j++) {
      if (strlen(fnames[i]) + strlen(start_pat[j]) + 1 > MAXPATHL) {
        continue;
      }
      xstrlcpy(buf, fnames[i], MAXPATHL);
      xstrlcat(buf, start_pat[j], sizeof buf);
      if (pack_has_entries(buf)) {
        add_pack_dir_to_rtp(buf, true);
      }
    }

    if (!all) {
      break;
    }
  }

  return num_fnames > 1;
}

/// Load plugins from all packages in the "start" directory.
void load_start_packages(void)
{
  did_source_packages = true;
  do_in_path(p_pp, "", "pack/*/start/*", DIP_ALL + DIP_DIR,  // NOLINT
             add_start_pack_plugins, &APP_LOAD);
  do_in_path(p_pp, "", "start/*", DIP_ALL + DIP_DIR,  // NOLINT
             add_start_pack_plugins, &APP_LOAD);
}

// ":packloadall"
// Find plugins in the package directories and source them.
void ex_packloadall(exarg_T *eap)
{
  if (!did_source_packages || eap->forceit) {
    // First do a round to add all directories to 'runtimepath', then load
    // the plugins. This allows for plugins to use an autoload directory
    // of another plugin.
    add_pack_start_dirs();
    load_start_packages();
  }
}

/// Read all the plugin files at startup
void load_plugins(void)
{
  if (p_lpl) {
    char *rtp_copy = p_rtp;
    char *const plugin_pattern = "plugin/**/*";  // NOLINT

    if (!did_source_packages) {
      rtp_copy = xstrdup(p_rtp);
      add_pack_start_dirs();
    }

    // Don't use source_runtime_vim_lua() yet so we can check for :packloadall below.
    // NB: after calling this "rtp_copy" may have been freed if it wasn't copied.
    source_in_path_vim_lua(rtp_copy, plugin_pattern, DIP_ALL | DIP_NOAFTER);
    TIME_MSG("loading rtp plugins");

    // Only source "start" packages if not done already with a :packloadall
    // command.
    if (!did_source_packages) {
      xfree(rtp_copy);
      load_start_packages();
    }
    TIME_MSG("loading packages");

    source_runtime_vim_lua(plugin_pattern, DIP_ALL | DIP_AFTER);
    TIME_MSG("loading after plugins");
  }
}

/// ":packadd[!] {name}"
void ex_packadd(exarg_T *eap)
{
  static const char plugpat[] = "pack/*/%s/%s";  // NOLINT
  int res = OK;

  // Round 1: use "start", round 2: use "opt".
  for (int round = 1; round <= 2; round++) {
    // Only look under "start" when loading packages wasn't done yet.
    if (round == 1 && did_source_packages) {
      continue;
    }

    const size_t len = sizeof(plugpat) + strlen(eap->arg) + 5;
    char *pat = xmallocz(len);
    vim_snprintf(pat, len, plugpat, round == 1 ? "start" : "opt", eap->arg);
    // The first round don't give a "not found" error, in the second round
    // only when nothing was found in the first round.
    res =
      do_in_path(p_pp, "", pat,
                 DIP_ALL + DIP_DIR + (round == 2 && res == FAIL ? DIP_ERR : 0),
                 round == 1 ? add_start_pack_plugins : add_opt_pack_plugins,
                 eap->forceit ? &APP_ADD_DIR : &APP_BOTH);
    xfree(pat);
  }
}

static void ExpandRTDir_int(char *pat, size_t pat_len, int flags, bool keep_ext, garray_T *gap,
                            char *dirnames[])
{
  // TODO(bfredl): this is bullshit, expandpath should not reinvent path logic.
  for (int i = 0; dirnames[i] != NULL; i++) {
    const size_t buf_len = strlen(dirnames[i]) + pat_len + 31;
    char *const buf = xmalloc(buf_len);
    char *const tail = buf + 15;
    const size_t tail_buflen = buf_len - 15;
    int glob_flags = 0;
    bool expand_dirs = false;

    if (*dirnames[i] == NUL) {  // empty dir used for :runtime
      snprintf(tail, tail_buflen, "%s*.{vim,lua}", pat);
    } else {
      snprintf(tail, tail_buflen, "%s/%s*.{vim,lua}", dirnames[i], pat);
    }

expand:
    if ((flags & DIP_NORTP) == 0) {
      globpath(p_rtp, tail, gap, glob_flags, expand_dirs);
    }

    if (flags & DIP_START) {
      memcpy(tail - 15, S_LEN("pack/*/start/*/"));  // NOLINT
      globpath(p_pp, tail - 15, gap, glob_flags, expand_dirs);
      memcpy(tail - 8, S_LEN("start/*/"));  // NOLINT
      globpath(p_pp, tail - 8, gap, glob_flags, expand_dirs);
    }

    if (flags & DIP_OPT) {
      memcpy(tail - 13, S_LEN("pack/*/opt/*/"));  // NOLINT
      globpath(p_pp, tail - 13, gap, glob_flags, expand_dirs);
      memcpy(tail - 6, S_LEN("opt/*/"));  // NOLINT
      globpath(p_pp, tail - 6, gap, glob_flags, expand_dirs);
    }

    if (*dirnames[i] == NUL && !expand_dirs) {
      // expand dir names in another round
      snprintf(tail, tail_buflen, "%s*", pat);
      glob_flags = WILD_ADD_SLASH;
      expand_dirs = true;
      goto expand;
    }

    xfree(buf);
  }

  int pat_pathsep_cnt = 0;
  for (size_t i = 0; i < pat_len; i++) {
    if (vim_ispathsep(pat[i])) {
      pat_pathsep_cnt++;
    }
  }

  for (int i = 0; i < gap->ga_len; i++) {
    char *match = ((char **)gap->ga_data)[i];
    char *s = match;
    char *e = s + strlen(s);
    if (e - s > 4 && !keep_ext && (STRNICMP(e - 4, ".vim", 4) == 0
                                   || STRNICMP(e - 4, ".lua", 4) == 0)) {
      e -= 4;
      *e = NUL;
    }

    int match_pathsep_cnt = (e > s && e[-1] == '/') ? -1 : 0;
    for (s = e; s > match; MB_PTR_BACK(match, s)) {
      if (vim_ispathsep(*s) && ++match_pathsep_cnt > pat_pathsep_cnt) {
        break;
      }
    }
    s++;
    if (s != match) {
      assert((e - s) + 1 >= 0);
      memmove(match, s, (size_t)(e - s) + 1);
    }
  }

  if (GA_EMPTY(gap)) {
    return;
  }

  // Sort and remove duplicates which can happen when specifying multiple
  // directories in dirnames.
  ga_remove_duplicate_strings(gap);
}

/// Expand color scheme, compiler or filetype names.
/// Search from 'runtimepath':
///   'runtimepath'/{dirnames}/{pat}.{vim,lua}
/// When "flags" has DIP_START: search also from "start" of 'packpath':
///   'packpath'/pack/*/start/*/{dirnames}/{pat}.{vim,lua}
/// When "flags" has DIP_OPT: search also from "opt" of 'packpath':
///   'packpath'/pack/*/opt/*/{dirnames}/{pat}.{vim,lua}
/// "dirnames" is an array with one or more directory names.
int ExpandRTDir(char *pat, int flags, int *num_file, char ***file, char *dirnames[])
{
  *num_file = 0;
  *file = NULL;

  garray_T ga;
  ga_init(&ga, (int)sizeof(char *), 10);

  ExpandRTDir_int(pat, strlen(pat), flags, false, &ga, dirnames);

  if (GA_EMPTY(&ga)) {
    return FAIL;
  }

  *file = ga.ga_data;
  *num_file = ga.ga_len;
  return OK;
}

/// Handle command line completion for :runtime command.
int expand_runtime_cmd(char *pat, int *numMatches, char ***matches)
{
  *numMatches = 0;
  *matches = NULL;

  garray_T ga;
  ga_init(&ga, sizeof(char *), 10);

  const size_t pat_len = strlen(pat);
  char *dirnames[] = { "", NULL };
  ExpandRTDir_int(pat, pat_len, runtime_expand_flags, true, &ga, dirnames);

  // Try to complete values for [where] argument when none was found.
  if (runtime_expand_flags == 0) {
    char *where_values[] = { "START", "OPT", "PACK", "ALL" };
    for (size_t i = 0; i < ARRAY_SIZE(where_values); i++) {
      if (strncmp(pat, where_values[i], pat_len) == 0) {
        GA_APPEND(char *, &ga, xstrdup(where_values[i]));
      }
    }
  }

  if (GA_EMPTY(&ga)) {
    return FAIL;
  }

  *matches = ga.ga_data;
  *numMatches = ga.ga_len;
  return OK;
}

/// Expand loadplugin names:
/// 'packpath'/pack/*/opt/{pat}
int ExpandPackAddDir(char *pat, int *num_file, char ***file)
{
  garray_T ga;

  *num_file = 0;
  *file = NULL;
  size_t pat_len = strlen(pat);
  ga_init(&ga, (int)sizeof(char *), 10);

  size_t buflen = pat_len + 26;
  char *s = xmalloc(buflen);
  snprintf(s, buflen, "pack/*/opt/%s*", pat);  // NOLINT
  globpath(p_pp, s, &ga, 0, true);
  snprintf(s, buflen, "opt/%s*", pat);  // NOLINT
  globpath(p_pp, s, &ga, 0, true);
  xfree(s);

  for (int i = 0; i < ga.ga_len; i++) {
    char *match = ((char **)ga.ga_data)[i];
    s = path_tail(match);
    memmove(match, s, strlen(s) + 1);
  }

  if (GA_EMPTY(&ga)) {
    return FAIL;
  }

  // Sort and remove duplicates which can happen when specifying multiple
  // directories in dirnames.
  ga_remove_duplicate_strings(&ga);

  *file = ga.ga_data;
  *num_file = ga.ga_len;
  return OK;
}

/// Append string with escaped commas
static char *strcpy_comma_escaped(char *dest, const char *src, const size_t len)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t shift = 0;
  for (size_t i = 0; i < len; i++) {
    if (src[i] == ',') {
      dest[i + shift++] = '\\';
    }
    dest[i + shift] = src[i];
  }
  return &dest[len + shift];
}

/// Compute length of a ENV_SEPCHAR-separated value, doubled and with some
/// suffixes
///
/// @param[in]  val  ENV_SEPCHAR-separated array value.
/// @param[in]  common_suf_len  Length of the common suffix which is appended to
///                             each item in the array, twice.
/// @param[in]  single_suf_len  Length of the suffix which is appended to each
///                             item in the array once.
///
/// @return Length of the ENV_SEPCHAR-separated string array that contains each
///         item in the original array twice with suffixes with given length
///         (common_suf is present after each new item, single_suf is present
///         after half of the new items) and with commas after each item, commas
///         inside the values are escaped.
static inline size_t compute_double_env_sep_len(const char *const val, const size_t common_suf_len,
                                                const size_t single_suf_len)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  if (val == NULL || *val == NUL) {
    return 0;
  }
  size_t ret = 0;
  const void *iter = NULL;
  do {
    size_t dir_len;
    const char *dir;
    iter = vim_env_iter(ENV_SEPCHAR, val, iter, &dir, &dir_len);
    if (dir != NULL && dir_len > 0) {
      ret += ((dir_len + memcnt(dir, ',', dir_len) + common_suf_len
               + !after_pathsep(dir, dir + dir_len)) * 2
              + single_suf_len);
    }
  } while (iter != NULL);
  return ret;
}

/// Add directories to a ENV_SEPCHAR-separated array from a colon-separated one
///
/// Commas are escaped in process. To each item PATHSEP "nvim" is appended in
/// addition to suf1 and suf2.
///
/// @param[in,out]  dest  Destination comma-separated array.
/// @param[in]  val  Source ENV_SEPCHAR-separated array.
/// @param[in]  suf1  If not NULL, suffix appended to destination. Prior to it
///                   directory separator is appended. Suffix must not contain
///                   commas.
/// @param[in]  len1  Length of the suf1.
/// @param[in]  suf2  If not NULL, another suffix appended to destination. Again
///                   with directory separator behind. Suffix must not contain
///                   commas.
/// @param[in]  len2  Length of the suf2.
/// @param[in]  forward  If true, iterate over val in forward direction.
///                      Otherwise in reverse.
///
/// @return (dest + appended_characters_length)
static inline char *add_env_sep_dirs(char *dest, const char *const val, const char *const suf1,
                                     const size_t len1, const char *const suf2, const size_t len2,
                                     const bool forward)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET FUNC_ATTR_NONNULL_ARG(1)
{
  if (val == NULL || *val == NUL) {
    return dest;
  }
  const void *iter = NULL;
  const char *appname = get_appname();
  const size_t appname_len = strlen(appname);
  do {
    size_t dir_len;
    const char *dir;
    iter = (forward ? vim_env_iter : vim_env_iter_rev)(ENV_SEPCHAR, val, iter,
                                                       &dir, &dir_len);
    if (dir != NULL && dir_len > 0) {
      dest = strcpy_comma_escaped(dest, dir, dir_len);
      if (!after_pathsep(dest - 1, dest)) {
        *dest++ = PATHSEP;
      }
      memmove(dest, appname, appname_len);
      dest += appname_len;
      if (suf1 != NULL) {
        *dest++ = PATHSEP;
        memmove(dest, suf1, len1);
        dest += len1;
        if (suf2 != NULL) {
          *dest++ = PATHSEP;
          memmove(dest, suf2, len2);
          dest += len2;
        }
      }
      *dest++ = ',';
    }
  } while (iter != NULL);
  return dest;
}

/// Adds directory `dest` to a comma-separated list of directories.
///
/// Commas in the added directory are escaped.
///
/// Windows: Appends "nvim-data" instead of "nvim" if `type` is kXDGDataHome.
///
/// @see get_xdg_home
///
/// @param[in,out]  dest  Destination comma-separated array.
/// @param[in]  dir  Directory to append.
/// @param[in]  type  Decides whether to append "nvim" (Win: or "nvim-data").
/// @param[in]  suf1  If not NULL, suffix appended to destination. Prior to it
///                   directory separator is appended. Suffix must not contain
///                   commas.
/// @param[in]  len1  Length of the suf1.
/// @param[in]  suf2  If not NULL, another suffix appended to destination. Again
///                   with directory separator behind. Suffix must not contain
///                   commas.
/// @param[in]  len2  Length of the suf2.
/// @param[in]  forward  If true, iterate over val in forward direction.
///                      Otherwise in reverse.
///
/// @return (dest + appended_characters_length)
static inline char *add_dir(char *dest, const char *const dir, const size_t dir_len,
                            const XDGVarType type, const char *const suf1, const size_t len1,
                            const char *const suf2, const size_t len2)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (dir == NULL || dir_len == 0) {
    return dest;
  }
  dest = strcpy_comma_escaped(dest, dir, dir_len);
  bool append_nvim = (type == kXDGDataHome || type == kXDGConfigHome);
  if (append_nvim) {
    if (!after_pathsep(dest - 1, dest)) {
      *dest++ = PATHSEP;
    }
    const char *appname = get_appname();
    size_t appname_len = strlen(appname);
    assert(appname_len < (IOSIZE - sizeof("-data")));
    xmemcpyz(IObuff, appname, appname_len);
#if defined(MSWIN)
    if (type == kXDGDataHome || type == kXDGStateHome) {
      xstrlcat(IObuff, "-data", IOSIZE);
      appname_len += 5;
    }
#endif
    xmemcpyz(dest, IObuff, appname_len);
    dest += appname_len;
    if (suf1 != NULL) {
      *dest++ = PATHSEP;
      memmove(dest, suf1, len1);
      dest += len1;
      if (suf2 != NULL) {
        *dest++ = PATHSEP;
        memmove(dest, suf2, len2);
        dest += len2;
      }
    }
  }
  *dest++ = ',';
  return dest;
}

char *get_lib_dir(void)
{
  // TODO(bfredl): too fragile? Ideally default_lib_dir would be made empty
  // in an appimage build
  if (strlen(default_lib_dir) != 0
      && os_isdir(default_lib_dir)) {
    return xstrdup(default_lib_dir);
  }

  // Find library path relative to the nvim binary: ../lib/nvim/
  char exe_name[MAXPATHL];
  vim_get_prefix_from_exepath(exe_name);
  if (append_path(exe_name, "lib/nvim", MAXPATHL) == OK) {
    return xstrdup(exe_name);
  }
  return NULL;
}

/// Determine the startup value for &runtimepath
///
/// Windows: Uses "…/nvim-data" for kXDGDataHome to avoid storing
/// configuration and data files in the same path. #4403
///
/// @param clean_arg  Nvim was started with --clean.
/// @return allocated string with the value
char *runtimepath_default(bool clean_arg)
{
  size_t rtp_size = 0;
  char *const data_home = clean_arg
                          ? NULL
                          : stdpaths_get_xdg_var(kXDGDataHome);
  char *const config_home = clean_arg
                            ? NULL
                            : stdpaths_get_xdg_var(kXDGConfigHome);
  char *const vimruntime = vim_getenv("VIMRUNTIME");
  char *const libdir = get_lib_dir();
  char *const data_dirs = stdpaths_get_xdg_var(kXDGDataDirs);
  char *const config_dirs = stdpaths_get_xdg_var(kXDGConfigDirs);
#define SITE_SIZE (sizeof("site") - 1)
#define AFTER_SIZE (sizeof("after") - 1)
  size_t data_len = 0;
  size_t config_len = 0;
  size_t vimruntime_len = 0;
  size_t libdir_len = 0;
  const char *appname = get_appname();
  size_t appname_len = strlen(appname);
  if (data_home != NULL) {
    data_len = strlen(data_home);
    size_t nvim_data_size = appname_len;
#if defined(MSWIN)
    nvim_data_size += sizeof("-data") - 1;  // -1: NULL byte should be ignored
#endif
    if (data_len != 0) {
      rtp_size += ((data_len + memcnt(data_home, ',', data_len)
                    + nvim_data_size + 1 + SITE_SIZE + 1
                    + !after_pathsep(data_home, data_home + data_len)) * 2
                   + AFTER_SIZE + 1);
    }
  }
  if (config_home != NULL) {
    config_len = strlen(config_home);
    if (config_len != 0) {
      rtp_size += ((config_len + memcnt(config_home, ',', config_len)
                    + appname_len + 1
                    + !after_pathsep(config_home, config_home + config_len)) * 2
                   + AFTER_SIZE + 1);
    }
  }
  if (vimruntime != NULL) {
    vimruntime_len = strlen(vimruntime);
    if (vimruntime_len != 0) {
      rtp_size += vimruntime_len + memcnt(vimruntime, ',', vimruntime_len) + 1;
    }
  }
  if (libdir != NULL) {
    libdir_len = strlen(libdir);
    if (libdir_len != 0) {
      rtp_size += libdir_len + memcnt(libdir, ',', libdir_len) + 1;
    }
  }
  rtp_size += compute_double_env_sep_len(data_dirs,
                                         appname_len + 1 + SITE_SIZE + 1,
                                         AFTER_SIZE + 1);
  rtp_size += compute_double_env_sep_len(config_dirs, appname_len + 1,
                                         AFTER_SIZE + 1);
  char *rtp = NULL;
  if (rtp_size == 0) {
    goto freeall;
  }
  rtp = xmalloc(rtp_size);
  char *rtp_cur = rtp;
  rtp_cur = add_dir(rtp_cur, config_home, config_len, kXDGConfigHome,
                    NULL, 0, NULL, 0);
  rtp_cur = add_env_sep_dirs(rtp_cur, config_dirs, NULL, 0, NULL, 0, true);
  rtp_cur = add_dir(rtp_cur, data_home, data_len, kXDGDataHome,
                    "site", SITE_SIZE, NULL, 0);
  rtp_cur = add_env_sep_dirs(rtp_cur, data_dirs, "site", SITE_SIZE, NULL, 0,
                             true);
  rtp_cur = add_dir(rtp_cur, vimruntime, vimruntime_len, kXDGNone,
                    NULL, 0, NULL, 0);
  rtp_cur = add_dir(rtp_cur, libdir, libdir_len, kXDGNone, NULL, 0, NULL, 0);
  rtp_cur = add_env_sep_dirs(rtp_cur, data_dirs, "site", SITE_SIZE,
                             "after", AFTER_SIZE, false);
  rtp_cur = add_dir(rtp_cur, data_home, data_len, kXDGDataHome,
                    "site", SITE_SIZE, "after", AFTER_SIZE);
  rtp_cur = add_env_sep_dirs(rtp_cur, config_dirs, "after", AFTER_SIZE, NULL, 0,
                             false);
  rtp_cur = add_dir(rtp_cur, config_home, config_len, kXDGConfigHome,
                    "after", AFTER_SIZE, NULL, 0);
  // Strip trailing comma.
  rtp_cur[-1] = NUL;
  assert((size_t)(rtp_cur - rtp) == rtp_size);
#undef SITE_SIZE
#undef AFTER_SIZE
freeall:
  xfree(data_dirs);
  xfree(config_dirs);
  xfree(data_home);
  xfree(config_home);
  xfree(vimruntime);
  xfree(libdir);

  return rtp;
}

static void cmd_source(char *fname, exarg_T *eap)
{
  if (eap != NULL && *fname == NUL) {
    cmd_source_buffer(eap, false);
  } else if (eap != NULL && eap->forceit) {
    // ":source!": read Normal mode commands
    // Need to execute the commands directly.  This is required at least
    // for:
    // - ":g" command busy
    // - after ":argdo", ":windo" or ":bufdo"
    // - another command follows
    // - inside a loop
    openscript(fname, global_busy || listcmd_busy || eap->nextcmd != NULL
               || eap->cstack->cs_idx >= 0);

    // ":source" read ex commands
  } else if (do_source(fname, false, DOSO_NONE, NULL) == FAIL) {
    semsg(_(e_notopen), fname);
  }
}

/// ":source [{fname}]"
void ex_source(exarg_T *eap)
{
  cmd_source(eap->arg, eap);
}

/// ":options"
void ex_options(exarg_T *eap)
{
  char buf[500];
  bool multi_mods = 0;

  buf[0] = NUL;
  add_win_cmd_modifiers(buf, &cmdmod, &multi_mods);

  os_setenv("OPTWIN_CMD", buf, 1);
  cmd_source(SYS_OPTWIN_FILE, NULL);
}

/// ":source" and associated commands.
///
/// @return address holding the next breakpoint line for a source cookie
linenr_T *source_breakpoint(void *cookie)
{
  return &((source_cookie_T *)cookie)->breakpoint;
}

/// @return  the address holding the debug tick for a source cookie.
int *source_dbg_tick(void *cookie)
{
  return &((source_cookie_T *)cookie)->dbg_tick;
}

/// @return  the nesting level for a source cookie.
int source_level(void *cookie)
  FUNC_ATTR_PURE
{
  return ((source_cookie_T *)cookie)->level;
}

/// Special function to open a file without handle inheritance.
/// If possible the handle is closed on exec().
static FILE *fopen_noinh_readbin(char *filename)
{
#ifdef MSWIN
  int fd_tmp = os_open(filename, O_RDONLY | O_BINARY | O_NOINHERIT, 0);
#else
  int fd_tmp = os_open(filename, O_RDONLY, 0);
#endif

  if (fd_tmp < 0) {
    return NULL;
  }

  os_set_cloexec(fd_tmp);

  return fdopen(fd_tmp, READBIN);
}

/// Concatenate Vimscript line if it starts with a line continuation into a growarray
/// (excluding the continuation chars and leading whitespace)
///
/// @note Growsize of the growarray may be changed to speed up concatenations!
///
/// @param ga  the growarray to append to
/// @param init_growsize  the starting growsize value of the growarray
/// @param p  pointer to the beginning of the line to consider
/// @param len  the length of this line
///
/// @return true if this line did begin with a continuation (the next line
///         should also be considered, if it exists); false otherwise
static bool concat_continued_line(garray_T *const ga, const int init_growsize, const char *const p,
                                  size_t len)
  FUNC_ATTR_NONNULL_ALL
{
  const char *const line = skipwhite_len(p, len);
  len -= (size_t)(line - p);
  // Skip lines starting with '\" ', concat lines starting with '\'
  if (len >= 3 && strncmp(line, S_LEN("\"\\ ")) == 0) {
    return true;
  } else if (len == 0 || line[0] != '\\') {
    return false;
  }
  if (ga->ga_len > init_growsize) {
    ga_set_growsize(ga, MIN(ga->ga_len, 8000));
  }
  ga_concat_len(ga, line + 1, len - 1);
  return true;
}

typedef struct {
  char *buf;
  size_t offset;
} GetStrLineCookie;

/// Get one full line from a sourced string (in-memory, no file).
/// Called by do_cmdline() when it's called from do_source_str().
///
/// @return pointer to allocated line, or NULL for end-of-file or
///         some error.
static char *get_str_line(int c, void *cookie, int indent, bool do_concat)
{
  GetStrLineCookie *p = cookie;
  if (strlen(p->buf) <= p->offset) {
    return NULL;
  }
  const char *line = p->buf + p->offset;
  const char *eol = skip_to_newline(line);
  garray_T ga;
  ga_init(&ga, sizeof(char), 400);
  ga_concat_len(&ga, line, (size_t)(eol - line));
  if (do_concat && vim_strchr(p_cpo, CPO_CONCAT) == NULL) {
    while (eol[0] != NUL) {
      line = eol + 1;
      const char *const next_eol = skip_to_newline(line);
      if (!concat_continued_line(&ga, 400, line, (size_t)(next_eol - line))) {
        break;
      }
      eol = next_eol;
    }
  }
  ga_append(&ga, NUL);
  p->offset = (size_t)(eol - p->buf) + 1;
  return ga.ga_data;
}

/// Create a new script item and allocate script-local vars. @see new_script_vars
///
/// @param  name  File name of the script. NULL for anonymous :source.
/// @param[out]  sid_out  SID of the new item.
///
/// @return  pointer to the created script item.
scriptitem_T *new_script_item(char *const name, scid_T *const sid_out)
{
  static scid_T last_current_SID = 0;
  const scid_T sid = ++last_current_SID;
  if (sid_out != NULL) {
    *sid_out = sid;
  }
  ga_grow(&script_items, sid - script_items.ga_len);
  while (script_items.ga_len < sid) {
    scriptitem_T *si = xcalloc(1, sizeof(scriptitem_T));
    script_items.ga_len++;
    SCRIPT_ITEM(script_items.ga_len) = si;
    si->sn_name = NULL;

    // Allocate the local script variables to use for this script.
    new_script_vars(script_items.ga_len);

    si->sn_prof_on = false;
  }
  SCRIPT_ITEM(sid)->sn_name = name;
  return SCRIPT_ITEM(sid);
}

static int source_using_linegetter(void *cookie, LineGetter fgetline, const char *traceback_name)
{
  char *save_sourcing_name = SOURCING_NAME;
  linenr_T save_sourcing_lnum = SOURCING_LNUM;
  char sourcing_name_buf[256];
  char *sname;
  if (save_sourcing_name == NULL) {
    sname = (char *)traceback_name;
  } else {
    snprintf(sourcing_name_buf, sizeof(sourcing_name_buf),
             "%s called at %s:%" PRIdLINENR, traceback_name, save_sourcing_name,
             save_sourcing_lnum);
    sname = sourcing_name_buf;
  }
  estack_push(ETYPE_SCRIPT, sname, 0);

  const sctx_T save_current_sctx = current_sctx;
  if (current_sctx.sc_sid != SID_LUA) {
    current_sctx.sc_sid = SID_STR;
  }
  current_sctx.sc_seq = 0;
  current_sctx.sc_lnum = save_sourcing_lnum;
  funccal_entry_T entry;
  save_funccal(&entry);
  int retval = do_cmdline(NULL, fgetline, cookie,
                          DOCMD_VERBOSE | DOCMD_NOWAIT | DOCMD_REPEAT);
  estack_pop();
  current_sctx = save_current_sctx;
  restore_funccal();
  return retval;
}

void cmd_source_buffer(const exarg_T *const eap, bool ex_lua)
  FUNC_ATTR_NONNULL_ALL
{
  if (curbuf == NULL) {
    return;
  }
  garray_T ga;
  ga_init(&ga, sizeof(char), 400);
  const linenr_T final_lnum = eap->line2;
  // Copy the contents to be executed.
  for (linenr_T curr_lnum = eap->line1; curr_lnum <= final_lnum; curr_lnum++) {
    // Adjust growsize to current length to speed up concatenating many lines.
    if (ga.ga_len > 400) {
      ga_set_growsize(&ga, MIN(ga.ga_len, 8000));
    }
    ga_concat(&ga, ml_get(curr_lnum));
    ga_append(&ga, NL);
  }
  ((char *)ga.ga_data)[ga.ga_len - 1] = NUL;
  if (ex_lua || strequal(curbuf->b_p_ft, "lua")
      || (curbuf->b_fname && path_with_extension(curbuf->b_fname, "lua"))) {
    char *name = ex_lua ? ":{range}lua" : ":source (no file)";
    nlua_source_str(ga.ga_data, name);
  } else {
    const GetStrLineCookie cookie = {
      .buf = ga.ga_data,
      .offset = 0,
    };
    source_using_linegetter((void *)&cookie, get_str_line, ":source (no file)");
  }
  ga_clear(&ga);
}

/// Executes lines in `src` as Ex commands.
///
/// @see do_source()
int do_source_str(const char *cmd, const char *traceback_name)
{
  GetStrLineCookie cookie = {
    .buf = (char *)cmd,
    .offset = 0,
  };
  return source_using_linegetter((void *)&cookie, get_str_line, traceback_name);
}

/// When fname is a 'lua' file nlua_exec_file() is invoked to source it.
/// Otherwise reads the file `fname` and executes its lines as Ex commands.
///
/// This function may be called recursively!
///
/// @see do_source_str
///
/// @param fname
/// @param check_other  check for .vimrc and _vimrc
/// @param is_vimrc     DOSO_ value
/// @param ret_sid      if not NULL and we loaded the script before, don't load it again
///
/// @return  FAIL if file could not be opened, OK otherwise
///
/// If a scriptitem_T was found or created "*ret_sid" is set to the SID.
int do_source(char *fname, int check_other, int is_vimrc, int *ret_sid)
{
  source_cookie_T cookie;
  uint8_t *firstline = NULL;
  int retval = FAIL;
  int save_debug_break_level = debug_break_level;
  scriptitem_T *si = NULL;
  proftime_T wait_start;
  bool trigger_source_post = false;

  char *p = expand_env_save(fname);
  if (p == NULL) {
    return retval;
  }
  char *fname_exp = fix_fname(p);
  xfree(p);
  if (fname_exp == NULL) {
    return retval;
  }
  if (os_isdir(fname_exp)) {
    smsg(0, _("Cannot source a directory: \"%s\""), fname);
    goto theend;
  }

  // See if we loaded this script before.
  int sid = find_script_by_name(fname_exp);
  if (sid > 0 && ret_sid != NULL) {
    // Already loaded and no need to load again, return here.
    *ret_sid = sid;
    retval = OK;
    goto theend;
  }

  // Apply SourceCmd autocommands, they should get the file and source it.
  if (has_autocmd(EVENT_SOURCECMD, fname_exp, NULL)
      && apply_autocmds(EVENT_SOURCECMD, fname_exp, fname_exp,
                        false, curbuf)) {
    retval = aborting() ? FAIL : OK;
    if (retval == OK) {
      // Apply SourcePost autocommands.
      apply_autocmds(EVENT_SOURCEPOST, fname_exp, fname_exp, false, curbuf);
    }
    goto theend;
  }

  // Apply SourcePre autocommands, they may get the file.
  apply_autocmds(EVENT_SOURCEPRE, fname_exp, fname_exp, false, curbuf);

  cookie.fp = fopen_noinh_readbin(fname_exp);
  if (cookie.fp == NULL && check_other) {
    // Try again, replacing file name ".nvimrc" by "_nvimrc" or vice versa,
    // and ".exrc" by "_exrc" or vice versa.
    p = path_tail(fname_exp);
    if ((*p == '.' || *p == '_')
        && (STRICMP(p + 1, "nvimrc") == 0 || STRICMP(p + 1, "exrc") == 0)) {
      *p = (*p == '_') ? '.' : '_';
      cookie.fp = fopen_noinh_readbin(fname_exp);
    }
  }

  if (cookie.fp == NULL) {
    if (p_verbose > 1) {
      verbose_enter();
      if (SOURCING_NAME == NULL) {
        smsg(0, _("could not source \"%s\""), fname);
      } else {
        smsg(0, _("line %" PRId64 ": could not source \"%s\""),
             (int64_t)SOURCING_LNUM, fname);
      }
      verbose_leave();
    }
    goto theend;
  }

  // The file exists.
  // - In verbose mode, give a message.
  // - For a vimrc file, may want to call vimrc_found().
  if (p_verbose > 1) {
    verbose_enter();
    if (SOURCING_NAME == NULL) {
      smsg(0, _("sourcing \"%s\""), fname);
    } else {
      smsg(0, _("line %" PRId64 ": sourcing \"%s\""), (int64_t)SOURCING_LNUM, fname);
    }
    verbose_leave();
  }
  if (is_vimrc == DOSO_VIMRC) {
    vimrc_found(fname_exp, "MYVIMRC");
  }

#ifdef USE_CRNL
  // If no automatic file format: Set default to CR-NL.
  if (*p_ffs == NUL) {
    cookie.fileformat = EOL_DOS;
  } else {
    cookie.fileformat = EOL_UNKNOWN;
  }
  cookie.error = false;
#endif

  cookie.nextline = NULL;
  cookie.sourcing_lnum = 0;
  cookie.finished = false;

  // Check if this script has a breakpoint.
  cookie.breakpoint = dbg_find_breakpoint(true, fname_exp, 0);
  cookie.fname = fname_exp;
  cookie.dbg_tick = debug_tick;

  cookie.level = ex_nesting_level;

  // start measuring script load time if --startuptime was passed and
  // time_fd was successfully opened afterwards.
  proftime_T rel_time;
  proftime_T start_time;
  FILE * const l_time_fd = time_fd;
  if (l_time_fd != NULL) {
    time_push(&rel_time, &start_time);
  }

  const int l_do_profiling = do_profiling;
  if (l_do_profiling == PROF_YES) {
    prof_child_enter(&wait_start);    // entering a child now
  }

  // Don't use local function variables, if called from a function.
  // Also starts profiling timer for nested script.
  funccal_entry_T funccalp_entry;
  save_funccal(&funccalp_entry);

  const sctx_T save_current_sctx = current_sctx;

  current_sctx.sc_lnum = 0;

  // Always use a new sequence number.
  current_sctx.sc_seq = ++last_current_SID_seq;

  if (sid > 0) {
    // loading the same script again
    si = SCRIPT_ITEM(sid);
  } else {
    // It's new, generate a new SID.
    si = new_script_item(fname_exp, &sid);
    fname_exp = xstrdup(si->sn_name);  // used for autocmd
    if (ret_sid != NULL) {
      *ret_sid = sid;
    }
  }
  current_sctx.sc_sid = sid;

  // Keep the sourcing name/lnum, for recursive calls.
  estack_push(ETYPE_SCRIPT, si->sn_name, 0);

  if (l_do_profiling == PROF_YES) {
    bool forceit = false;

    // Check if we do profiling for this script.
    if (!si->sn_prof_on && has_profiling(true, si->sn_name, &forceit)) {
      profile_init(si);
      si->sn_pr_force = forceit;
    }
    if (si->sn_prof_on) {
      si->sn_pr_count++;
      si->sn_pr_start = profile_start();
      si->sn_pr_children = profile_zero();
    }
  }

  cookie.conv.vc_type = CONV_NONE;              // no conversion

  if (path_with_extension(fname_exp, "lua")) {
    const sctx_T current_sctx_backup = current_sctx;
    current_sctx.sc_sid = SID_LUA;
    current_sctx.sc_lnum = 0;
    // Source the file as lua
    nlua_exec_file(fname_exp);
    current_sctx = current_sctx_backup;
  } else {
    // Read the first line so we can check for a UTF-8 BOM.
    firstline = (uint8_t *)getsourceline(0, (void *)&cookie, 0, true);
    if (firstline != NULL && strlen((char *)firstline) >= 3 && firstline[0] == 0xef
        && firstline[1] == 0xbb && firstline[2] == 0xbf) {
      // Found BOM; setup conversion, skip over BOM and recode the line.
      convert_setup(&cookie.conv, "utf-8", p_enc);
      p = string_convert(&cookie.conv, (char *)firstline + 3, NULL);
      if (p == NULL) {
        p = xstrdup((char *)firstline + 3);
      }
      xfree(firstline);
      firstline = (uint8_t *)p;
    }
    // Call do_cmdline, which will call getsourceline() to get the lines.
    do_cmdline((char *)firstline, getsourceline, (void *)&cookie,
               DOCMD_VERBOSE|DOCMD_NOWAIT|DOCMD_REPEAT);
  }
  retval = OK;

  if (l_do_profiling == PROF_YES) {
    // Get "si" again, "script_items" may have been reallocated.
    si = SCRIPT_ITEM(current_sctx.sc_sid);
    if (si->sn_prof_on) {
      si->sn_pr_start = profile_end(si->sn_pr_start);
      si->sn_pr_start = profile_sub_wait(wait_start, si->sn_pr_start);
      si->sn_pr_total = profile_add(si->sn_pr_total, si->sn_pr_start);
      si->sn_pr_self = profile_self(si->sn_pr_self, si->sn_pr_start,
                                    si->sn_pr_children);
    }
  }

  if (got_int) {
    emsg(_(e_interr));
  }
  estack_pop();
  if (p_verbose > 1) {
    verbose_enter();
    smsg(0, _("finished sourcing %s"), fname);
    if (SOURCING_NAME != NULL) {
      smsg(0, _("continuing in %s"), SOURCING_NAME);
    }
    verbose_leave();
  }

  if (l_time_fd != NULL) {
    vim_snprintf(IObuff, IOSIZE, "sourcing %s", fname);
    time_msg(IObuff, &start_time);
    time_pop(rel_time);
  }

  if (!got_int) {
    trigger_source_post = true;
  }

  // After a "finish" in debug mode, need to break at first command of next
  // sourced file.
  if (save_debug_break_level > ex_nesting_level
      && debug_break_level == ex_nesting_level) {
    debug_break_level++;
  }

  current_sctx = save_current_sctx;
  restore_funccal();
  if (l_do_profiling == PROF_YES) {
    prof_child_exit(&wait_start);    // leaving a child now
  }
  fclose(cookie.fp);
  xfree(cookie.nextline);
  xfree(firstline);
  convert_setup(&cookie.conv, NULL, NULL);

  if (trigger_source_post) {
    apply_autocmds(EVENT_SOURCEPOST, fname_exp, fname_exp, false, curbuf);
  }

theend:
  xfree(fname_exp);
  return retval;
}

/// Find an already loaded script "name".
/// If found returns its script ID.  If not found returns -1.
int find_script_by_name(char *name)
{
  assert(script_items.ga_len >= 0);
  for (int sid = script_items.ga_len; sid > 0; sid--) {
    // We used to check inode here, but that doesn't work:
    // - If a script is edited and written, it may get a different
    //   inode number, even though to the user it is the same script.
    // - If a script is deleted and another script is written, with a
    //   different name, the inode may be re-used.
    scriptitem_T *si = SCRIPT_ITEM(sid);
    if (si->sn_name != NULL && path_fnamecmp(si->sn_name, name) == 0) {
      return sid;
    }
  }
  return -1;
}

/// ":scriptnames"
void ex_scriptnames(exarg_T *eap)
{
  if (eap->addr_count > 0 || *eap->arg != NUL) {
    // :script {scriptId}: edit the script
    if (eap->addr_count > 0 && !SCRIPT_ID_VALID(eap->line2)) {
      emsg(_(e_invarg));
    } else {
      if (eap->addr_count > 0) {
        eap->arg = SCRIPT_ITEM(eap->line2)->sn_name;
      } else {
        expand_env(eap->arg, NameBuff, MAXPATHL);
        eap->arg = NameBuff;
      }
      do_exedit(eap, NULL);
    }
    return;
  }

  for (int i = 1; i <= script_items.ga_len && !got_int; i++) {
    if (SCRIPT_ITEM(i)->sn_name != NULL) {
      home_replace(NULL, SCRIPT_ITEM(i)->sn_name, NameBuff, MAXPATHL, true);
      vim_snprintf(IObuff, IOSIZE, "%3d: %s", i, NameBuff);
      if (!message_filtered(IObuff)) {
        msg_putchar('\n');
        msg_outtrans(IObuff, 0);
        line_breakcheck();
      }
    }
  }
}

#if defined(BACKSLASH_IN_FILENAME)
/// Fix slashes in the list of script names for 'shellslash'.
void scriptnames_slash_adjust(void)
{
  for (int i = 1; i <= script_items.ga_len; i++) {
    if (SCRIPT_ITEM(i)->sn_name != NULL) {
      slash_adjust(SCRIPT_ITEM(i)->sn_name);
    }
  }
}

#endif

/// Get a pointer to a script name.  Used for ":verbose set".
/// Message appended to "Last set from "
char *get_scriptname(LastSet last_set, bool *should_free)
{
  *should_free = false;

  switch (last_set.script_ctx.sc_sid) {
  case SID_MODELINE:
    return _("modeline");
  case SID_CMDARG:
    return _("--cmd argument");
  case SID_CARG:
    return _("-c argument");
  case SID_ENV:
    return _("environment variable");
  case SID_ERROR:
    return _("error handler");
  case SID_WINLAYOUT:
    return _("changed window size");
  case SID_LUA:
    return _("Lua (run Nvim with -V1 for more details)");
  case SID_API_CLIENT:
    snprintf(IObuff, IOSIZE, _("API client (channel id %" PRIu64 ")"), last_set.channel_id);
    return IObuff;
  case SID_STR:
    return _("anonymous :source");
  default: {
    char *const sname = SCRIPT_ITEM(last_set.script_ctx.sc_sid)->sn_name;
    if (sname == NULL) {
      snprintf(IObuff, IOSIZE, _("anonymous :source (script id %d)"),
               last_set.script_ctx.sc_sid);
      return IObuff;
    }

    *should_free = true;
    return home_replace_save(NULL, sname);
  }
  }
}

#if defined(EXITFREE)
void free_scriptnames(void)
{
  profile_reset();

# define FREE_SCRIPTNAME(item) \
  do { \
    scriptitem_T *_si = *(item); \
    /* the variables themselves are cleared in evalvars_clear() */ \
    xfree(_si->sn_vars); \
    xfree(_si->sn_name); \
    ga_clear(&_si->sn_prl_ga); \
    xfree(_si); \
  } while (0) \

  GA_DEEP_CLEAR(&script_items, scriptitem_T *, FREE_SCRIPTNAME);
}
#endif

void free_autoload_scriptnames(void)
{
  ga_clear_strings(&ga_loaded);
}

linenr_T get_sourced_lnum(LineGetter fgetline, void *cookie)
  FUNC_ATTR_PURE
{
  return fgetline == getsourceline
         ? ((source_cookie_T *)cookie)->sourcing_lnum
         : SOURCING_LNUM;
}

/// Return a List of script-local functions defined in the script with id "sid".
static list_T *get_script_local_funcs(scid_T sid)
{
  hashtab_T *const functbl = func_tbl_get();
  list_T *l = tv_list_alloc((ptrdiff_t)functbl->ht_used);

  // Iterate through all the functions in the global function hash table
  // looking for functions with script ID "sid".
  HASHTAB_ITER(functbl, hi, {
    const ufunc_T *const fp = HI2UF(hi);
    // Add functions with script id == "sid"
    if (fp->uf_script_ctx.sc_sid == sid) {
      const char *const name = fp->uf_name_exp != NULL ? fp->uf_name_exp : fp->uf_name;
      tv_list_append_string(l, name, -1);
    }
  });

  return l;
}

/// "getscriptinfo()" function
void f_getscriptinfo(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  tv_list_alloc_ret(rettv, script_items.ga_len);

  if (tv_check_for_opt_dict_arg(argvars, 0) == FAIL) {
    return;
  }

  list_T *l = rettv->vval.v_list;

  regmatch_T regmatch = {
    .regprog = NULL,
    .rm_ic = p_ic,
  };
  bool filterpat = false;
  varnumber_T sid = -1;

  char *pat = NULL;
  if (argvars[0].v_type == VAR_DICT) {
    dictitem_T *sid_di = tv_dict_find(argvars[0].vval.v_dict, S_LEN("sid"));
    if (sid_di != NULL) {
      bool error = false;
      sid = tv_get_number_chk(&sid_di->di_tv, &error);
      if (error) {
        return;
      }
      if (sid <= 0) {
        semsg(_(e_invargNval), "sid", tv_get_string(&sid_di->di_tv));
        return;
      }
    } else {
      pat = tv_dict_get_string(argvars[0].vval.v_dict, "name", true);
      if (pat != NULL) {
        regmatch.regprog = vim_regcomp(pat, RE_MAGIC + RE_STRING);
      }
      if (regmatch.regprog != NULL) {
        filterpat = true;
      }
    }
  }

  for (varnumber_T i = sid > 0 ? sid : 1;
       (i == sid || sid <= 0) && i <= script_items.ga_len; i++) {
    scriptitem_T *si = SCRIPT_ITEM(i);

    if (si->sn_name == NULL) {
      continue;
    }

    if (filterpat && !vim_regexec(&regmatch, si->sn_name, 0)) {
      continue;
    }

    dict_T *d = tv_dict_alloc();
    tv_list_append_dict(l, d);
    tv_dict_add_str(d, S_LEN("name"), si->sn_name);
    tv_dict_add_nr(d, S_LEN("sid"), i);
    tv_dict_add_nr(d, S_LEN("version"), 1);
    // Vim9 autoload script (:h vim9-autoload), not applicable to Nvim.
    tv_dict_add_bool(d, S_LEN("autoload"), false);

    // When a script ID is specified, return information about only the
    // specified script, and add the script-local variables and functions.
    if (sid > 0) {
      dict_T *var_dict = tv_dict_copy(NULL, &si->sn_vars->sv_dict, true, get_copyID());
      tv_dict_add_dict(d, S_LEN("variables"), var_dict);
      tv_dict_add_list(d, S_LEN("functions"), get_script_local_funcs((scid_T)sid));
    }
  }

  vim_regfree(regmatch.regprog);
  xfree(pat);
}

/// Get one full line from a sourced file.
/// Called by do_cmdline() when it's called from do_source().
///
/// @return pointer to the line in allocated memory, or NULL for end-of-file or
///         some error.
char *getsourceline(int c, void *cookie, int indent, bool do_concat)
{
  source_cookie_T *sp = (source_cookie_T *)cookie;
  char *line;

  // If breakpoints have been added/deleted need to check for it.
  if (sp->dbg_tick < debug_tick) {
    sp->breakpoint = dbg_find_breakpoint(true, sp->fname, SOURCING_LNUM);
    sp->dbg_tick = debug_tick;
  }
  if (do_profiling == PROF_YES) {
    script_line_end();
  }
  // Set the current sourcing line number.
  SOURCING_LNUM = sp->sourcing_lnum + 1;
  // Get current line.  If there is a read-ahead line, use it, otherwise get
  // one now.  "fp" is NULL if actually using a string.
  if (sp->finished || sp->fp == NULL) {
    line = NULL;
  } else if (sp->nextline == NULL) {
    line = get_one_sourceline(sp);
  } else {
    line = sp->nextline;
    sp->nextline = NULL;
    sp->sourcing_lnum++;
  }
  if (line != NULL && do_profiling == PROF_YES) {
    script_line_start();
  }

  // Only concatenate lines starting with a \ when 'cpoptions' doesn't
  // contain the 'C' flag.
  if (line != NULL && do_concat && (vim_strchr(p_cpo, CPO_CONCAT) == NULL)) {
    char *p;
    // compensate for the one line read-ahead
    sp->sourcing_lnum--;

    // Get the next line and concatenate it when it starts with a
    // backslash. We always need to read the next line, keep it in
    // sp->nextline.
    // Also check for a comment in between continuation lines: "\ .
    sp->nextline = get_one_sourceline(sp);
    if (sp->nextline != NULL
        && (*(p = skipwhite(sp->nextline)) == '\\'
            || (p[0] == '"' && p[1] == '\\' && p[2] == ' '))) {
      garray_T ga;

      ga_init(&ga, (int)sizeof(char), 400);
      ga_concat(&ga, line);
      while (sp->nextline != NULL
             && concat_continued_line(&ga, 400, sp->nextline, strlen(sp->nextline))) {
        xfree(sp->nextline);
        sp->nextline = get_one_sourceline(sp);
      }
      ga_append(&ga, NUL);
      xfree(line);
      line = ga.ga_data;
    }
  }

  if (line != NULL && sp->conv.vc_type != CONV_NONE) {
    // Convert the encoding of the script line.
    char *s = string_convert(&sp->conv, line, NULL);
    if (s != NULL) {
      xfree(line);
      line = s;
    }
  }

  // Did we encounter a breakpoint?
  if (sp->breakpoint != 0 && sp->breakpoint <= SOURCING_LNUM) {
    dbg_breakpoint(sp->fname, SOURCING_LNUM);
    // Find next breakpoint.
    sp->breakpoint = dbg_find_breakpoint(true, sp->fname, SOURCING_LNUM);
    sp->dbg_tick = debug_tick;
  }

  return line;
}

static char *get_one_sourceline(source_cookie_T *sp)
{
  garray_T ga;
  int len;
  int c;
  char *buf;
#ifdef USE_CRNL
  bool has_cr;                           // CR-LF found
#endif
  bool have_read = false;

  // use a growarray to store the sourced line
  ga_init(&ga, 1, 250);

  // Loop until there is a finished line (or end-of-file).
  sp->sourcing_lnum++;
  while (true) {
    // make room to read at least 120 (more) characters
    ga_grow(&ga, 120);
    buf = ga.ga_data;

retry:
    errno = 0;
    if (fgets(buf + ga.ga_len, ga.ga_maxlen - ga.ga_len,
              sp->fp) == NULL) {
      if (errno == EINTR) {
        goto retry;
      }

      break;
    }
    len = ga.ga_len + (int)strlen(buf + ga.ga_len);
#ifdef USE_CRNL
    // Ignore a trailing CTRL-Z, when in Dos mode. Only recognize the
    // CTRL-Z by its own, or after a NL.
    if ((len == 1 || (len >= 2 && buf[len - 2] == '\n'))
        && sp->fileformat == EOL_DOS
        && buf[len - 1] == Ctrl_Z) {
      buf[len - 1] = NUL;
      break;
    }
#endif

    have_read = true;
    ga.ga_len = len;

    // If the line was longer than the buffer, read more.
    if (ga.ga_maxlen - ga.ga_len == 1 && buf[len - 1] != '\n') {
      continue;
    }

    if (len >= 1 && buf[len - 1] == '\n') {     // remove trailing NL
#ifdef USE_CRNL
      has_cr = (len >= 2 && buf[len - 2] == '\r');
      if (sp->fileformat == EOL_UNKNOWN) {
        if (has_cr) {
          sp->fileformat = EOL_DOS;
        } else {
          sp->fileformat = EOL_UNIX;
        }
      }

      if (sp->fileformat == EOL_DOS) {
        if (has_cr) {               // replace trailing CR
          buf[len - 2] = '\n';
          len--;
          ga.ga_len--;
        } else {          // lines like ":map xx yy^M" will have failed
          if (!sp->error) {
            msg_source(HL_ATTR(HLF_W));
            emsg(_("W15: Warning: Wrong line separator, ^M may be missing"));
          }
          sp->error = true;
          sp->fileformat = EOL_UNIX;
        }
      }
#endif
      // The '\n' is escaped if there is an odd number of ^V's just
      // before it, first set "c" just before the 'V's and then check
      // len&c parities (is faster than ((len-c)%2 == 0)) -- Acevedo
      for (c = len - 2; c >= 0 && buf[c] == Ctrl_V; c--) {}
      if ((len & 1) != (c & 1)) {       // escaped NL, read more
        sp->sourcing_lnum++;
        continue;
      }

      buf[len - 1] = NUL;               // remove the NL
    }

    // Check for ^C here now and then, so recursive :so can be broken.
    line_breakcheck();
    break;
  }

  if (have_read) {
    return ga.ga_data;
  }

  xfree(ga.ga_data);
  return NULL;
}

/// ":scriptencoding": Set encoding conversion for a sourced script.
/// Without the multi-byte feature it's simply ignored.
void ex_scriptencoding(exarg_T *eap)
{
  source_cookie_T *sp;
  char *name;

  if (!getline_equal(eap->ea_getline, eap->cookie, getsourceline)) {
    emsg(_("E167: :scriptencoding used outside of a sourced file"));
    return;
  }

  if (*eap->arg != NUL) {
    name = enc_canonize(eap->arg);
  } else {
    name = eap->arg;
  }

  // Setup for conversion from the specified encoding to 'encoding'.
  sp = (source_cookie_T *)getline_cookie(eap->ea_getline, eap->cookie);
  convert_setup(&sp->conv, name, p_enc);

  if (name != eap->arg) {
    xfree(name);
  }
}

/// ":finish": Mark a sourced file as finished.
void ex_finish(exarg_T *eap)
{
  if (getline_equal(eap->ea_getline, eap->cookie, getsourceline)) {
    do_finish(eap, false);
  } else {
    emsg(_("E168: :finish used outside of a sourced file"));
  }
}

/// Mark a sourced file as finished.  Possibly makes the ":finish" pending.
/// Also called for a pending finish at the ":endtry" or after returning from
/// an extra do_cmdline().  "reanimate" is used in the latter case.
void do_finish(exarg_T *eap, bool reanimate)
{
  if (reanimate) {
    ((source_cookie_T *)getline_cookie(eap->ea_getline, eap->cookie))->finished = false;
  }

  // Cleanup (and deactivate) conditionals, but stop when a try conditional
  // not in its finally clause (which then is to be executed next) is found.
  // In this case, make the ":finish" pending for execution at the ":endtry".
  // Otherwise, finish normally.
  int idx = cleanup_conditionals(eap->cstack, 0, true);
  if (idx >= 0) {
    eap->cstack->cs_pending[idx] = CSTP_FINISH;
    report_make_pending(CSTP_FINISH, NULL);
  } else {
    ((source_cookie_T *)getline_cookie(eap->ea_getline, eap->cookie))->finished = true;
  }
}

/// @return  true when a sourced file had the ":finish" command: Don't give error
///          message for missing ":endif".
///          false when not sourcing a file.
bool source_finished(LineGetter fgetline, void *cookie)
{
  return getline_equal(fgetline, cookie, getsourceline)
         && ((source_cookie_T *)getline_cookie(fgetline, cookie))->finished;
}

/// Return the autoload script name for a function or variable name
/// Caller must make sure that "name" contains AUTOLOAD_CHAR.
///
/// @param[in]  name  Variable/function name.
/// @param[in]  name_len  Name length.
///
/// @return [allocated] autoload script name.
char *autoload_name(const char *const name, const size_t name_len)
  FUNC_ATTR_MALLOC FUNC_ATTR_WARN_UNUSED_RESULT
{
  // Get the script file name: replace '#' with '/', append ".vim".
  char *const scriptname = xmalloc(name_len + sizeof("autoload/.vim"));
  memcpy(scriptname, "autoload/", sizeof("autoload/") - 1);
  memcpy(scriptname + sizeof("autoload/") - 1, name, name_len);
  size_t auchar_idx = 0;
  for (size_t i = sizeof("autoload/") - 1;
       i - sizeof("autoload/") + 1 < name_len;
       i++) {
    if (scriptname[i] == AUTOLOAD_CHAR) {
      scriptname[i] = '/';
      auchar_idx = i;
    }
  }
  memcpy(scriptname + auchar_idx, ".vim", sizeof(".vim"));

  return scriptname;
}

/// If name has a package name try autoloading the script for it
///
/// @param[in]  name  Variable/function name.
/// @param[in]  name_len  Name length.
/// @param[in]  reload  If true, load script again when already loaded.
///
/// @return true if a package was loaded.
bool script_autoload(const char *const name, const size_t name_len, const bool reload)
{
  // If there is no '#' after name[0] there is no package name.
  const char *p = memchr(name, AUTOLOAD_CHAR, name_len);
  if (p == NULL || p == name) {
    return false;
  }

  bool ret = false;
  char *tofree = autoload_name(name, name_len);
  char *scriptname = tofree;

  // Find the name in the list of previously loaded package names.  Skip
  // "autoload/", it's always the same.
  int i = 0;
  for (; i < ga_loaded.ga_len; i++) {
    if (strcmp(((char **)ga_loaded.ga_data)[i] + 9, scriptname + 9) == 0) {
      break;
    }
  }
  if (!reload && i < ga_loaded.ga_len) {
    ret = false;  // Was loaded already.
  } else {
    // Remember the name if it wasn't loaded already.
    if (i == ga_loaded.ga_len) {
      GA_APPEND(char *, &ga_loaded, scriptname);
      tofree = NULL;
    }

    // Try loading the package from $VIMRUNTIME/autoload/<name>.vim
    // Use "ret_sid" to avoid loading the same script again.
    int ret_sid;
    if (do_in_runtimepath(scriptname, 0, source_callback, &ret_sid) == OK) {
      ret = true;
    }
  }

  xfree(tofree);
  return ret;
}
