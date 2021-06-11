// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// @file runtime.c
///
/// Management of runtime files (including packages)

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/option.h"
#include "nvim/ex_cmds.h"
#include "nvim/ex_cmds2.h"
#include "nvim/misc1.h"
#include "nvim/os/os.h"
#include "nvim/runtime.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "runtime.c.generated.h"
#endif


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
int do_in_path(char_u *path, char_u *name, int flags,
               DoInRuntimepathCB callback, void *cookie)
{
  char_u      *tail;
  int num_files;
  char_u      **files;
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
        bool is_after = buflen >= 5
          && STRCMP(buf + buflen - 5, "after") == 0;

        if ((is_after && (flags & DIP_NOAFTER))
            || (!is_after && (flags & DIP_AFTER))) {
          continue;
        }
      }

      if (name == NULL) {
        (*callback)(buf, (void *)&cookie);
        if (!did_one) {
          did_one = (cookie == NULL);
        }
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

          // Expand wildcards, invoke the callback for each match.
          if (gen_expand_wildcards(1, &buf, &num_files, &files,
                                   (flags & DIP_DIR) ? EW_DIR : EW_FILE)
              == OK) {
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

/// Find "name" in "path".  When found, invoke the callback function for
/// it: callback(fname, "cookie")
/// When "flags" has DIP_ALL repeat for all matches, otherwise only the first
/// one is used.
/// Returns OK when at least one match found, FAIL otherwise.
/// If "name" is NULL calls callback for each entry in "path". Cookie is
/// passed by reference in this case, setting it to NULL indicates that callback
/// has done its job.
int do_in_path_and_pp(char_u *path, char_u *name, int flags,
                      DoInRuntimepathCB callback, void *cookie)
{
  int done = FAIL;

  if ((flags & DIP_NORTP) == 0) {
    done = do_in_path(path, name, flags, callback, cookie);
  }

  if ((done == FAIL || (flags & DIP_ALL)) && (flags & DIP_START)) {
    char *start_dir = "pack/*/start/*/%s";  // NOLINT
    size_t len = STRLEN(start_dir) + STRLEN(name);
    char_u *s = xmallocz(len);

    vim_snprintf((char *)s, len, start_dir, name);
    done = do_in_path(p_pp, s, flags, callback, cookie);

    xfree(s);

    if (done == FAIL|| (flags & DIP_ALL)) {
      start_dir = "start/*/%s";  // NOLINT
      len = STRLEN(start_dir) + STRLEN(name);
      s = xmallocz(len);

      vim_snprintf((char *)s, len, start_dir, name);
      done = do_in_path(p_pp, s, flags, callback, cookie);

      xfree(s);
    }
  }

  if ((done == FAIL || (flags & DIP_ALL)) && (flags & DIP_OPT)) {
    char *opt_dir = "pack/*/opt/*/%s";  // NOLINT
    size_t len = STRLEN(opt_dir) + STRLEN(name);
    char_u *s = xmallocz(len);

    vim_snprintf((char *)s, len, opt_dir, name);
    done = do_in_path(p_pp, s, flags, callback, cookie);

    xfree(s);

    if (done == FAIL || (flags & DIP_ALL)) {
      opt_dir = "opt/*/%s";  // NOLINT
      len = STRLEN(opt_dir) + STRLEN(name);
      s = xmallocz(len);

      vim_snprintf((char *)s, len, opt_dir, name);
      done = do_in_path(p_pp, s, flags, callback, cookie);

      xfree(s);
    }
  }

  return done;
}

/// Just like do_in_path_and_pp(), using 'runtimepath' for "path".
int do_in_runtimepath(char_u *name, int flags, DoInRuntimepathCB callback,
                      void *cookie)
{
  return do_in_path_and_pp(p_rtp, name, flags, callback, cookie);
}

/// Source the file "name" from all directories in 'runtimepath'.
/// "name" can contain wildcards.
/// When "flags" has DIP_ALL: source all files, otherwise only the first one.
///
/// return FAIL when no file could be sourced, OK otherwise.
int source_runtime(char_u *name, int flags)
{
  flags |= (flags & DIP_NORTP) ? 0 : DIP_START;
  return source_in_path(p_rtp, name, flags);
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
static int add_pack_dir_to_rtp(char_u *fname)
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
  if (os_isdir((char_u *)afterdir)) {
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

/// Load scripts in "plugin" and "ftdetect" directories of the package.
static int load_pack_plugin(char_u *fname)
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
  if (eval_to_number(cmd) > 0) {
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

static void add_pack_plugin(char_u *fname, void *cookie)
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
      if (add_pack_dir_to_rtp(fname) == FAIL) {
        return;
      }
    }
  }

  if (cookie != &APP_ADD_DIR) {
    load_pack_plugin(fname);
  }
}

/// Add all packages in the "start" directory to 'runtimepath'.
void add_pack_start_dirs(void)
{
  do_in_path(p_pp, (char_u *)"pack/*/start/*", DIP_ALL + DIP_DIR,  // NOLINT
             add_pack_plugin, &APP_ADD_DIR);
  do_in_path(p_pp, (char_u *)"start/*", DIP_ALL + DIP_DIR,  // NOLINT
             add_pack_plugin, &APP_ADD_DIR);
}

/// Load plugins from all packages in the "start" directory.
void load_start_packages(void)
{
  did_source_packages = true;
  do_in_path(p_pp, (char_u *)"pack/*/start/*", DIP_ALL + DIP_DIR,  // NOLINT
             add_pack_plugin, &APP_LOAD);
  do_in_path(p_pp, (char_u *)"start/*", DIP_ALL + DIP_DIR,  // NOLINT
             add_pack_plugin, &APP_LOAD);
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
                     add_pack_plugin, eap->forceit ? &APP_ADD_DIR : &APP_BOTH);
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
static inline size_t compute_double_env_sep_len(const char *const val,
                                                const size_t common_suf_len,
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
static inline char *add_env_sep_dirs(char *dest, const char *const val,
                                     const char *const suf1, const size_t len1,
                                     const char *const suf2, const size_t len2,
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
static inline char *add_dir(char *dest, const char *const dir,
                            const size_t dir_len, const XDGVarType type,
                            const char *const suf1, const size_t len1,
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
