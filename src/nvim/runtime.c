// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// @file runtime.c
///
/// Management of runtime files (including packages)

#include "nvim/api/private/helpers.h"
#include "nvim/ascii.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/misc1.h"
#include "nvim/option.h"
#include "nvim/os/os.h"
#include "nvim/runtime.h"
#include "nvim/vim.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "runtime.c.generated.h"
#endif

static bool runtime_search_path_valid = false;
static int *runtime_search_path_ref = NULL;
static RuntimeSearchPath runtime_search_path;

/// ":runtime [what] {name}"
void ex_runtime(exarg_T *eap)
{
  char_u *arg = eap->arg;
  char_u *p = skiptowhite(arg);
  ptrdiff_t len = p - arg;
  int flags = eap->forceit ? DIP_ALL : 0;

  if (STRNCMP(arg, "START", len) == 0) {
    flags += DIP_START + DIP_NORTP;
    arg = skipwhite(arg + len);
  } else if (STRNCMP(arg, "OPT", len) == 0) {
    flags += DIP_OPT + DIP_NORTP;
    arg = skipwhite(arg + len);
  } else if (STRNCMP(arg, "PACK", len) == 0) {
    flags += DIP_START + DIP_OPT + DIP_NORTP;
    arg = skipwhite(arg + len);
  } else if (STRNCMP(arg, "ALL", len) == 0) {
    flags += DIP_START + DIP_OPT;
    arg = skipwhite(arg + len);
  }

  source_runtime(arg, flags);
}


static void source_callback(char_u *fname, void *cookie)
{
  (void)do_source(fname, false, DOSO_NONE);
}

/// Find the file "name" in all directories in "path" and invoke
/// "callback(fname, cookie)".
/// "name" can contain wildcards.
/// When "flags" has DIP_ALL: source all files, otherwise only the first one.
/// When "flags" has DIP_DIR: find directories instead of files.
/// When "flags" has DIP_ERR: give an error message if there is no match.
///
/// return FAIL when no file could be sourced, OK otherwise.
int do_in_path(char_u *path, char_u *name, int flags, DoInRuntimepathCB callback, void *cookie)
{
  char_u *tail;
  int num_files;
  char_u **files;
  int i;
  bool did_one = false;

  // Make a copy of 'runtimepath'.  Invoking the callback may change the
  // value.
  char_u *rtp_copy = vim_strsave(path);
  char_u *buf = xmallocz(MAXPATHL);
  {
    if (p_verbose > 10 && name != NULL) {
      verbose_enter();
      smsg(_("Searching for \"%s\" in \"%s\""),
           (char *)name, (char *)path);
      verbose_leave();
    }

    // Loop over all entries in 'runtimepath'.
    char_u *rtp = rtp_copy;
    while (*rtp != NUL && ((flags & DIP_ALL) || !did_one)) {
      // Copy the path from 'runtimepath' to buf[].
      copy_option_part(&rtp, buf, MAXPATHL, ",");
      size_t buflen = STRLEN(buf);

      // Skip after or non-after directories.
      if (flags & (DIP_NOAFTER | DIP_AFTER)) {
        bool is_after = path_is_after(buf, buflen);

        if ((is_after && (flags & DIP_NOAFTER))
            || (!is_after && (flags & DIP_AFTER))) {
          continue;
        }
      }

      if (name == NULL) {
        (*callback)(buf, cookie);
        did_one = true;
      } else if (buflen + STRLEN(name) + 2 < MAXPATHL) {
        add_pathsep((char *)buf);
        tail = buf + STRLEN(buf);

        // Loop over all patterns in "name"
        char_u *np = name;
        while (*np != NUL && ((flags & DIP_ALL) || !did_one)) {
          // Append the pattern from "name" to buf[].
          assert(MAXPATHL >= (tail - buf));
          copy_option_part(&np, tail, (size_t)(MAXPATHL - (tail - buf)),
                           "\t ");

          if (p_verbose > 10) {
            verbose_enter();
            smsg(_("Searching for \"%s\""), buf);
            verbose_leave();
          }

          int ew_flags = ((flags & DIP_DIR) ? EW_DIR : EW_FILE)
                         | (flags & DIP_DIRFILE) ? (EW_DIR|EW_FILE) : 0;

          // Expand wildcards, invoke the callback for each match.
          if (gen_expand_wildcards(1, &buf, &num_files, &files, ew_flags) == OK) {
            for (i = 0; i < num_files; i++) {
              (*callback)(files[i], cookie);
              did_one = true;
              if (!(flags & DIP_ALL)) {
                break;
              }
            }
            FreeWild(num_files, files);
          }
        }
      }
    }
  }
  xfree(buf);
  xfree(rtp_copy);
  if (!did_one && name != NULL) {
    char *basepath = path == p_rtp ? "runtimepath" : "packpath";

    if (flags & DIP_ERR) {
      EMSG3(_(e_dirnotf), basepath, name);
    } else if (p_verbose > 0) {
      verbose_enter();
      smsg(_("not found in '%s': \"%s\""), basepath, name);
      verbose_leave();
    }
  }


  return did_one ? OK : FAIL;
}

/// Find the file "name" in all directories in "path" and invoke
/// "callback(fname, cookie)".
/// "name" can contain wildcards.
/// When "flags" has DIP_ALL: source all files, otherwise only the first one.
/// When "flags" has DIP_DIR: find directories instead of files.
/// When "flags" has DIP_ERR: give an error message if there is no match.
///
/// return FAIL when no file could be sourced, OK otherwise.
int do_in_cached_path(char_u *name, int flags, DoInRuntimepathCB callback, void *cookie)
{
  runtime_search_path_validate();
  char_u *tail;
  int num_files;
  char_u **files;
  int i;
  bool did_one = false;

  char_u buf[MAXPATHL];

  if (p_verbose > 10 && name != NULL) {
    verbose_enter();
    smsg(_("Searching for \"%s\" in runtime path"), (char *)name);
    verbose_leave();
  }

  RuntimeSearchPath path = runtime_search_path;
  int ref = 0;
  if (runtime_search_path_ref == NULL) {
    // cached path was unreferenced. keep a ref to
    // prevent runtime_search_path() to freeing it too early
    ref++;
    runtime_search_path_ref = &ref;
  }

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
      (*callback)((char_u *)item.path, cookie);
      did_one = true;
    } else if (buflen + STRLEN(name) + 2 < MAXPATHL) {
      STRCPY(buf, item.path);
      add_pathsep((char *)buf);
      tail = buf + STRLEN(buf);

      // Loop over all patterns in "name"
      char_u *np = name;
      while (*np != NUL && ((flags & DIP_ALL) || !did_one)) {
        // Append the pattern from "name" to buf[].
        assert(MAXPATHL >= (tail - buf));
        copy_option_part(&np, tail, (size_t)(MAXPATHL - (tail - buf)),
                         "\t ");

        if (p_verbose > 10) {
          verbose_enter();
          smsg(_("Searching for \"%s\""), buf);
          verbose_leave();
        }

        int ew_flags = ((flags & DIP_DIR) ? EW_DIR : EW_FILE)
                       | (flags & DIP_DIRFILE) ? (EW_DIR|EW_FILE) : 0;

        // Expand wildcards, invoke the callback for each match.
        char_u *(pat[]) = { buf };
        if (gen_expand_wildcards(1, pat, &num_files, &files, ew_flags) == OK) {
          for (i = 0; i < num_files; i++) {
            (*callback)(files[i], cookie);
            did_one = true;
            if (!(flags & DIP_ALL)) {
              break;
            }
          }
          FreeWild(num_files, files);
        }
      }
    }
  }

  if (!did_one && name != NULL) {
    if (flags & DIP_ERR) {
      EMSG3(_(e_dirnotf), "runtime path", name);
    } else if (p_verbose > 0) {
      verbose_enter();
      smsg(_("not found in runtime path: \"%s\""), name);
      verbose_leave();
    }
  }

  if (ref) {
    if (runtime_search_path_ref == &ref) {
      runtime_search_path_ref = NULL;
    } else {
      runtime_search_path_free(path);
    }
  }


  return did_one ? OK : FAIL;
}
/// Find "name" in "path".  When found, invoke the callback function for
/// it: callback(fname, "cookie")
/// When "flags" has DIP_ALL repeat for all matches, otherwise only the first
/// one is used.
/// Returns OK when at least one match found, FAIL otherwise.
/// If "name" is NULL calls callback for each entry in "path". Cookie is
/// passed by reference in this case, setting it to NULL indicates that callback
/// has done its job.
int do_in_path_and_pp(char_u *path, char_u *name, int flags, DoInRuntimepathCB callback,
                      void *cookie)
{
  int done = FAIL;

  if ((flags & DIP_NORTP) == 0) {
    done |= do_in_path(path, (name && !*name) ? NULL : name, flags, callback, cookie);
  }

  if ((done == FAIL || (flags & DIP_ALL)) && (flags & DIP_START)) {
    char *start_dir = "pack/*/start/*/%s%s";  // NOLINT
    size_t len = STRLEN(start_dir) + STRLEN(name) + 6;
    char_u *s = xmallocz(len);  // TODO(bfredl): get rid of random allocations
    char *suffix = (flags & DIP_AFTER) ? "after/" : "";

    vim_snprintf((char *)s, len, start_dir, suffix, name);
    done |= do_in_path(p_pp, s, flags & ~DIP_AFTER, callback, cookie);

    xfree(s);

    if (done == FAIL || (flags & DIP_ALL)) {
      start_dir = "start/*/%s%s";  // NOLINT
      len = STRLEN(start_dir) + STRLEN(name) + 6;
      s = xmallocz(len);

      vim_snprintf((char *)s, len, start_dir, suffix, name);
      done |= do_in_path(p_pp, s, flags & ~DIP_AFTER, callback, cookie);

      xfree(s);
    }
  }

  if ((done == FAIL || (flags & DIP_ALL)) && (flags & DIP_OPT)) {
    char *opt_dir = "pack/*/opt/*/%s";  // NOLINT
    size_t len = STRLEN(opt_dir) + STRLEN(name);
    char_u *s = xmallocz(len);

    vim_snprintf((char *)s, len, opt_dir, name);
    done |= do_in_path(p_pp, s, flags, callback, cookie);

    xfree(s);

    if (done == FAIL || (flags & DIP_ALL)) {
      opt_dir = "opt/*/%s";  // NOLINT
      len = STRLEN(opt_dir) + STRLEN(name);
      s = xmallocz(len);

      vim_snprintf((char *)s, len, opt_dir, name);
      done |= do_in_path(p_pp, s, flags, callback, cookie);

      xfree(s);
    }
  }

  return done;
}

static void push_path(RuntimeSearchPath *search_path, Map(String, handle_T) *rtp_used,
                      char *entry, bool after)
{
  handle_T h = map_get(String, handle_T)(rtp_used, cstr_as_string(entry));
  if (h == 0) {
    char *allocated = xstrdup(entry);
    map_put(String, handle_T)(rtp_used, cstr_as_string(allocated), 1);
    kv_push(*search_path, ((SearchPathItem){ allocated, after }));
  }
}

static void expand_rtp_entry(RuntimeSearchPath *search_path, Map(String, handle_T) *rtp_used,
                             char *entry, bool after)
{
  if (map_get(String, handle_T)(rtp_used, cstr_as_string(entry))) {
    return;
  }

  if (!*entry) {
    push_path(search_path, rtp_used, entry, after);
  }

  int num_files;
  char_u **files;
  char_u *(pat[]) = { (char_u *)entry };
  if (gen_expand_wildcards(1, pat, &num_files, &files, EW_DIR) == OK) {
    for (int i = 0; i < num_files; i++) {
      push_path(search_path, rtp_used, (char *)files[i], after);
    }
    FreeWild(num_files, files);
  }
}

static void expand_pack_entry(RuntimeSearchPath *search_path, Map(String, handle_T) *rtp_used,
                              CharVec *after_path, char_u *pack_entry)
{
  static char buf[MAXPATHL];
  char *(start_pat[]) = { "/pack/*/start/*", "/start/*" };  // NOLINT
  for (int i = 0; i < 2; i++) {
    if (STRLEN(pack_entry) + STRLEN(start_pat[i]) + 1 > MAXPATHL) {
      continue;
    }
    xstrlcpy(buf, (char *)pack_entry, MAXPATHL);
    xstrlcat(buf, start_pat[i], sizeof buf);
    expand_rtp_entry(search_path, rtp_used, buf, false);
    size_t after_size = STRLEN(buf)+7;
    char *after = xmallocz(after_size);
    xstrlcpy(after, buf, after_size);
    xstrlcat(after, "/after", after_size);
    kv_push(*after_path, after);
  }
}

static bool path_is_after(char_u *buf, size_t buflen)
{
  // NOTE: we only consider dirs exactly matching "after" to be an AFTER dir.
  // vim8 considers all dirs like "foo/bar_after", "Xafter" etc, as an
  // "after" dir in SOME codepaths not not in ALL codepaths.
  return buflen >= 5
         && (!(buflen >= 6) || vim_ispathsep(buf[buflen-6]))
         && STRCMP(buf + buflen - 5, "after") == 0;
}

RuntimeSearchPath runtime_search_path_build(void)
{
  kvec_t(String) pack_entries = KV_INITIAL_VALUE;
  // TODO(bfredl): these should just be sets, when Set(String) is do merge to
  // master.
  Map(String, handle_T) pack_used = MAP_INIT;
  Map(String, handle_T) rtp_used = MAP_INIT;
  RuntimeSearchPath search_path = KV_INITIAL_VALUE;
  CharVec after_path = KV_INITIAL_VALUE;

  static char_u buf[MAXPATHL];
  for (char *entry = (char *)p_pp; *entry != NUL; ) {
    char *cur_entry = entry;
    copy_option_part((char_u **)&entry, buf, MAXPATHL, ",");

    String the_entry = { .data = cur_entry, .size = STRLEN(buf) };

    kv_push(pack_entries, the_entry);
    map_put(String, handle_T)(&pack_used, the_entry, 0);
  }


  char *rtp_entry;
  for (rtp_entry = (char *)p_rtp; *rtp_entry != NUL; ) {
    char *cur_entry = rtp_entry;
    copy_option_part((char_u **)&rtp_entry, buf, MAXPATHL, ",");
    size_t buflen = STRLEN(buf);

    if (path_is_after(buf, buflen)) {
      rtp_entry = cur_entry;
      break;
    }

    // fact: &rtp entries can contain wild chars
    expand_rtp_entry(&search_path, &rtp_used, (char *)buf, false);

    handle_T *h = map_ref(String, handle_T)(&pack_used, cstr_as_string((char *)buf), false);
    if (h) {
      (*h)++;
      expand_pack_entry(&search_path, &rtp_used, &after_path, buf);
    }
  }

  for (size_t i = 0; i < kv_size(pack_entries); i++) {
    handle_T h = map_get(String, handle_T)(&pack_used, kv_A(pack_entries, i));
    if (h == 0) {
      expand_pack_entry(&search_path, &rtp_used, &after_path, (char_u *)kv_A(pack_entries, i).data);
    }
  }

  // "after" packages
  for (size_t i = 0; i < kv_size(after_path); i++) {
    expand_rtp_entry(&search_path, &rtp_used, kv_A(after_path, i), true);
    xfree(kv_A(after_path, i));
  }

  // "after" dirs in rtp
  for (; *rtp_entry != NUL;) {
    copy_option_part((char_u **)&rtp_entry, buf, MAXPATHL, ",");
    expand_rtp_entry(&search_path, &rtp_used, (char *)buf, path_is_after(buf, STRLEN(buf)));
  }

  // strings are not owned
  kv_destroy(pack_entries);
  kv_destroy(after_path);
  map_destroy(String, handle_T)(&pack_used);
  map_destroy(String, handle_T)(&rtp_used);

  return search_path;
}

void runtime_search_path_invalidate(void)
{
  runtime_search_path_valid = false;
}

void runtime_search_path_free(RuntimeSearchPath path)
{
  for (size_t j = 0; j < kv_size(path); j++) {
    SearchPathItem item = kv_A(path, j);
    xfree(item.path);
  }
  kv_destroy(path);
}

void runtime_search_path_validate(void)
{
  if (!runtime_search_path_valid) {
    if (!runtime_search_path_ref) {
      runtime_search_path_free(runtime_search_path);
    }
    runtime_search_path = runtime_search_path_build();
    runtime_search_path_valid = true;
    runtime_search_path_ref = NULL;  // initially unowned
  }
}



/// Just like do_in_path_and_pp(), using 'runtimepath' for "path".
int do_in_runtimepath(char_u *name, int flags, DoInRuntimepathCB callback, void *cookie)
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
int source_runtime(char_u *name, int flags)
{
  return do_in_runtimepath(name, flags, source_callback, NULL);
}

/// Just like source_runtime(), but use "path" instead of 'runtimepath'.
int source_in_path(char_u *path, char_u *name, int flags)
{
  return do_in_path_and_pp(path, name, flags, source_callback, NULL);
}

// Expand wildcards in "pat" and invoke do_source()/nlua_exec_file()
// for each match.
static void source_all_matches(char_u *pat)
{
  int num_files;
  char_u **files;

  if (gen_expand_wildcards(1, &pat, &num_files, &files, EW_FILE) == OK) {
    for (int i = 0; i < num_files; i++) {
      (void)do_source(files[i], false, DOSO_NONE);
    }
    FreeWild(num_files, files);
  }
}

/// Add the package directory to 'runtimepath'
///
/// @param fname the package path
/// @param is_pack whether the added dir is a "pack/*/start/*/" style package
static int add_pack_dir_to_rtp(char_u *fname, bool is_pack)
{
  char_u *p4, *p3, *p2, *p1, *p;
  char_u *buf = NULL;
  char *afterdir = NULL;
  int retval = FAIL;

  p4 = p3 = p2 = p1 = get_past_head(fname);
  for (p = p1; *p; MB_PTR_ADV(p)) {
    if (vim_ispathsep_nocolon(*p)) {
      p4 = p3; p3 = p2; p2 = p1; p1 = p;
    }
  }

  // now we have:
  // rtp/pack/name/start/name
  //    p4   p3   p2   p1
  //
  // find the part up to "pack" in 'runtimepath'
  p4++;  // append pathsep in order to expand symlink
  char_u c = *p4;
  *p4 = NUL;
  char *const ffname = fix_fname((char *)fname);
  *p4 = c;

  if (ffname == NULL) {
    return FAIL;
  }

  // Find "ffname" in "p_rtp", ignoring '/' vs '\' differences
  // Also stop at the first "after" directory
  size_t fname_len = strlen(ffname);
  buf = try_malloc(MAXPATHL);
  if (buf == NULL) {
    goto theend;
  }
  const char *insp = NULL;
  const char *after_insp = NULL;
  for (const char *entry = (const char *)p_rtp; *entry != NUL; ) {
    const char *cur_entry = entry;

    copy_option_part((char_u **)&entry, buf, MAXPATHL, ",");
    if (insp == NULL) {
      add_pathsep((char *)buf);
      char *const rtp_ffname = fix_fname((char *)buf);
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

    if ((p = (char_u *)strstr((char *)buf, "after")) != NULL
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
  }

  if (insp == NULL) {
    // Both "fname" and "after" not found, append at the end.
    insp = (const char *)p_rtp + STRLEN(p_rtp);
  }

  // check if rtp/pack/name/start/name/after exists
  afterdir = concat_fnames((char *)fname, "after", true);
  size_t afterlen = 0;
  if (is_pack ? pack_has_entries((char_u *)afterdir) : os_isdir((char_u *)afterdir)) {
    afterlen = strlen(afterdir) + 1;  // add one for comma
  }

  const size_t oldlen = STRLEN(p_rtp);
  const size_t addlen = STRLEN(fname) + 1;  // add one for comma
  const size_t new_rtp_capacity = oldlen + addlen + afterlen + 1;
  // add one for NUL ------------------------------------------^
  char *const new_rtp = try_malloc(new_rtp_capacity);
  if (new_rtp == NULL) {
    goto theend;
  }

  // We now have 'rtp' parts: {keep}{keep_after}{rest}.
  // Create new_rtp, first: {keep},{fname}
  size_t keep = (size_t)(insp - (const char *)p_rtp);
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
    size_t keep_after = (size_t)(after_insp - (const char *)p_rtp);

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

  set_option_value("rtp", 0L, new_rtp, 0);
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
/// load these from filetype.vim)
static int load_pack_plugin(bool opt, char_u *fname)
{
  static const char *ftpat = "%s/ftdetect/*.vim";  // NOLINT

  char *const ffname = fix_fname((char *)fname);
  size_t len = strlen(ffname) + STRLEN(ftpat);
  char_u *pat = xmallocz(len);

  vim_snprintf((char *)pat, len, "%s/plugin/**/*.vim", ffname);  // NOLINT
  source_all_matches(pat);
  vim_snprintf((char *)pat, len, "%s/plugin/**/*.lua", ffname);  // NOLINT
  source_all_matches(pat);

  char_u *cmd = vim_strsave((char_u *)"g:did_load_filetypes");

  // If runtime/filetype.vim wasn't loaded yet, the scripts will be
  // found when it loads.
  if (opt && eval_to_number(cmd) > 0) {
    do_cmdline_cmd("augroup filetypedetect");
    vim_snprintf((char *)pat, len, ftpat, ffname);
    source_all_matches(pat);
    vim_snprintf((char *)pat, len, "%s/ftdetect/*.lua", ffname);  // NOLINT
    source_all_matches(pat);
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

static void add_pack_plugin(bool opt, char_u *fname, void *cookie)
{
  if (cookie != &APP_LOAD) {
    char *buf = xmalloc(MAXPATHL);
    bool found = false;

    const char *p = (const char *)p_rtp;
    while (*p != NUL) {
      copy_option_part((char_u **)&p, (char_u *)buf, MAXPATHL, ",");
      if (path_fnamecmp(buf, (char *)fname) == 0) {
        found = true;
        break;
      }
    }
    xfree(buf);
    if (!found) {
      // directory is not yet in 'runtimepath', add it
      if (add_pack_dir_to_rtp(fname, false) == FAIL) {
        return;
      }
    }
  }

  if (cookie != &APP_ADD_DIR) {
    load_pack_plugin(opt, fname);
  }
}

static void add_start_pack_plugin(char_u *fname, void *cookie)
{
  add_pack_plugin(false, fname, cookie);
}

static void add_opt_pack_plugin(char_u *fname, void *cookie)
{
  add_pack_plugin(true, fname, cookie);
}


/// Add all packages in the "start" directory to 'runtimepath'.
void add_pack_start_dirs(void)
{
  do_in_path(p_pp, NULL, DIP_ALL + DIP_DIR, add_pack_start_dir, NULL);
}

static bool pack_has_entries(char_u *buf)
{
  int num_files;
  char_u **files;
  char_u *(pat[]) = { buf };
  if (gen_expand_wildcards(1, pat, &num_files, &files, EW_DIR) == OK) {
    FreeWild(num_files, files);
  }
  return num_files > 0;
}

static void add_pack_start_dir(char_u *fname, void *cookie)
{
  static char_u buf[MAXPATHL];
  char *(start_pat[]) = { "/start/*", "/pack/*/start/*" };  // NOLINT
  for (int i = 0; i < 2; i++) {
    if (STRLEN(fname) + STRLEN(start_pat[i]) + 1 > MAXPATHL) {
      continue;
    }
    xstrlcpy((char *)buf, (char *)fname, MAXPATHL);
    xstrlcat((char *)buf, start_pat[i], sizeof buf);
    if (pack_has_entries(buf)) {
      add_pack_dir_to_rtp(buf, true);
    }
  }
}


/// Load plugins from all packages in the "start" directory.
void load_start_packages(void)
{
  did_source_packages = true;
  do_in_path(p_pp, (char_u *)"pack/*/start/*", DIP_ALL + DIP_DIR,  // NOLINT
             add_start_pack_plugin, &APP_LOAD);
  do_in_path(p_pp, (char_u *)"start/*", DIP_ALL + DIP_DIR,  // NOLINT
             add_start_pack_plugin, &APP_LOAD);
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
    char_u *rtp_copy = p_rtp;
    char_u *const plugin_pattern_vim = (char_u *)"plugin/**/*.vim";  // NOLINT
    char_u *const plugin_pattern_lua = (char_u *)"plugin/**/*.lua";  // NOLINT

    if (!did_source_packages) {
      rtp_copy = vim_strsave(p_rtp);
      add_pack_start_dirs();
    }

    // don't use source_runtime() yet so we can check for :packloadall below
    source_in_path(rtp_copy, plugin_pattern_vim, DIP_ALL | DIP_NOAFTER);
    source_in_path(rtp_copy, plugin_pattern_lua, DIP_ALL | DIP_NOAFTER);
    TIME_MSG("loading rtp plugins");

    // Only source "start" packages if not done already with a :packloadall
    // command.
    if (!did_source_packages) {
      xfree(rtp_copy);
      load_start_packages();
    }
    TIME_MSG("loading packages");

    source_runtime(plugin_pattern_vim, DIP_ALL | DIP_AFTER);
    source_runtime(plugin_pattern_lua, DIP_ALL | DIP_AFTER);
    TIME_MSG("loading after plugins");
  }
}

/// ":packadd[!] {name}"
void ex_packadd(exarg_T *eap)
{
  static const char *plugpat = "pack/*/%s/%s";    // NOLINT
  int res = OK;

  // Round 1: use "start", round 2: use "opt".
  for (int round = 1; round <= 2; round++) {
    // Only look under "start" when loading packages wasn't done yet.
    if (round == 1 && did_source_packages) {
      continue;
    }

    const size_t len = STRLEN(plugpat) + STRLEN(eap->arg) + 5;
    char *pat = xmallocz(len);
    vim_snprintf(pat, len, plugpat, round == 1 ? "start" : "opt", eap->arg);
    // The first round don't give a "not found" error, in the second round
    // only when nothing was found in the first round.
    res = do_in_path(p_pp, (char_u *)pat,
                     DIP_ALL + DIP_DIR
                     + (round == 2 && res == FAIL ? DIP_ERR : 0),
                     round == 1 ? add_start_pack_plugin : add_opt_pack_plugin,
                     eap->forceit ? &APP_ADD_DIR : &APP_BOTH);
    xfree(pat);
  }
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


#define NVIM_SIZE (sizeof("nvim") - 1)
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
      memmove(dest, "nvim", NVIM_SIZE);
      dest += NVIM_SIZE;
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
#if defined(WIN32)
    size_t size = (type == kXDGDataHome ? sizeof("nvim-data") - 1 : NVIM_SIZE);
    memmove(dest, (type == kXDGDataHome ? "nvim-data" : "nvim"), size);
    dest += size;
#else
    memmove(dest, "nvim", NVIM_SIZE);
    dest += NVIM_SIZE;
#endif
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
      && os_isdir((const char_u *)default_lib_dir)) {
    return xstrdup(default_lib_dir);
  }

  // Find library path relative to the nvim binary: ../lib/nvim/
  char exe_name[MAXPATHL];
  vim_get_prefix_from_exepath(exe_name);
  if (append_path(exe_name, "lib" _PATHSEPSTR "nvim", MAXPATHL) == OK) {
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
  if (data_home != NULL) {
    data_len = strlen(data_home);
    if (data_len != 0) {
#if defined(WIN32)
      size_t nvim_size = (sizeof("nvim-data") - 1);
#else
      size_t nvim_size = NVIM_SIZE;
#endif
      rtp_size += ((data_len + memcnt(data_home, ',', data_len)
                    + nvim_size + 1 + SITE_SIZE + 1
                    + !after_pathsep(data_home, data_home + data_len)) * 2
                   + AFTER_SIZE + 1);
    }
  }
  if (config_home != NULL) {
    config_len = strlen(config_home);
    if (config_len != 0) {
      rtp_size += ((config_len + memcnt(config_home, ',', config_len)
                    + NVIM_SIZE + 1
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
                                         NVIM_SIZE + 1 + SITE_SIZE + 1,
                                         AFTER_SIZE + 1);
  rtp_size += compute_double_env_sep_len(config_dirs, NVIM_SIZE + 1,
                                         AFTER_SIZE + 1);
  if (rtp_size == 0) {
    return NULL;
  }
  char *const rtp = xmalloc(rtp_size);
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
  xfree(data_dirs);
  xfree(config_dirs);
  xfree(data_home);
  xfree(config_home);
  xfree(vimruntime);
  xfree(libdir);

  return rtp;
}
#undef NVIM_SIZE
