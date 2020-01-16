// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/path.h"
#include "nvim/os/os.h"
#include "nvim/os/path_win.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/path_win.c.generated.h"
#endif

/// Save the long filename.
/// @param fname An long or short filename.
/// @return The long filename of `fname`.
char *path_to_long_save(const char *fname)
{
  char *result = NULL;
  wchar_t *fname_utf16;
  int conversion_result = utf8_to_utf16(fname, -1, &fname_utf16);
  if (conversion_result == 0) {
    wchar_t *lfname_utf16 = xmalloc(MAXPATHL * sizeof(*lfname_utf16));
    DWORD ret = GetLongPathNameW(fname_utf16, lfname_utf16, MAXPATHL);
    if (ret > MAXPATHL - 1) {
      lfname_utf16 = xrealloc(lfname_utf16, (ret + 1) * sizeof(*lfname_utf16));
      ret = GetLongPathNameW(fname_utf16, lfname_utf16, ret + 1);
    }
    if (ret != 0) {
      char *lfname_utf8;
      conversion_result = utf16_to_utf8(lfname_utf16, -1, &lfname_utf8);
      if (conversion_result == 0) {
        result = lfname_utf8;
      } else {
        EMSG2("utf16_to_utf8 failed: %d", conversion_result);
      }
    }
    xfree(fname_utf16);
    xfree(lfname_utf16);
  } else {
    EMSG2("utf8_to_utf16 failed: %d", conversion_result);
  }
  return result;
}

/// Save long filename to "buf[len]".
///
/// @param      fname filename to evaluate
/// @param[out] buf   contains `fname` long filename, or:
///                   - truncated `fname` if longer than `len`
///                   - unmodified `fname` if long filename fails
/// @param      len   length of `buf`
///
/// @return           false for failure, true otherwise
bool path_to_long(char *fname, char *buf, size_t len)
{
  char *lfname = path_to_long_save(fname);
  if (lfname != NULL) {
    xstrlcpy(buf, lfname, len);
    xfree(lfname);
    return true;
  }
  return false;
}

/// Save the short filename.
/// @param fname An long or short filename.
/// @return The short filename of `fname`.
char *path_to_short_save(char *fname)
{
  char *result = NULL;
  wchar_t *fname_utf16;
  int conversion_result = utf8_to_utf16(fname, -1, &fname_utf16);
  if (conversion_result == 0) {
    wchar_t *sfname_utf16 = xmalloc(MAXPATHL * sizeof(*sfname_utf16));
    DWORD ret = GetShortPathNameW(fname_utf16, sfname_utf16, MAXPATHL);
    if (ret > MAXPATHL - 1) {
      sfname_utf16 = xrealloc(sfname_utf16, (ret + 1) * sizeof(*sfname_utf16));
      ret = GetShortPathNameW(fname_utf16, sfname_utf16, ret + 1);
    }
    if (ret != 0) {
      char *sfname_utf8;
      conversion_result = utf16_to_utf8(sfname_utf16, -1, &sfname_utf8);
      if (conversion_result == 0) {
        result = sfname_utf8;
      } else {
        EMSG2("utf16_to_utf8 failed: %d", conversion_result);
      }
    }
    xfree(fname_utf16);
    xfree(sfname_utf16);
  } else {
    EMSG2("utf8_to_utf16 failed: %d", conversion_result);
  }
  return result;
}

/// Save short filename to "buf[len]".
///
/// @param      fname filename to evaluate
/// @param[out] buf   contains `fname` short filename, or:
///                   - truncated `fname` if longer than `len`
///                   - unmodified `fname` if short filename fails
/// @param      len   length of `buf`
///
/// @return           false for failure, true otherwise
bool path_to_short(char *fname, char *buf, size_t len)
{
  char *sfname = path_to_short_save(fname);
  if (sfname != NULL) {
    xstrlcpy(buf, sfname, len);
    xfree(sfname);
    return true;
  }
  return false;
}

// Get the short path (8.3) for the filename in "fname". The converted
// path is returned in "bufp".
//
// Some of the directories specified in "fname" may not exist. This function
// will shorten the existing directories at the beginning of the path and then
// append the remaining non-existing path.
//
// fname - Pointer to the filename to shorten.  On return, contains the
//         pointer to the shortened pathname
// bufp -  Pointer to an allocated buffer for the filename.
// fnamelen - Length of the filename pointed to by fname
//
// Returns true on success (or nothing done) and false on failure (out of
// memory).
bool path_short_for_invalid_fname(char **fname, char **bufp, size_t fnamelen)
{
  bool retval = false;

  // Make a copy
  size_t old_len = fnamelen;
  char *save_fname = (char *)vim_strnsave((char_u *)(*fname), old_len);
  char *short_fname = NULL;

  char *endp = save_fname + old_len - 1;  // Find the end of the copy
  char *save_endp = endp;

  // Try shortening the supplied path till it succeeds by removing one
  // directory at a time from the tail of the path.
  for (;;) {
    // go back one path-separator
    while (endp > save_fname && !after_pathsep(save_fname, endp + 1)) {
      endp--;
    }
    if (endp <= save_fname) {
      break;  // processed the complete path
    }

    // Replace the path separator with a NUL and try to shorten the
    // resulting path.
    char ch = *endp;
    *endp = NUL;
    if (os_path_exists((const char_u *)save_fname)) {
      short_fname = path_to_short_save(save_fname);
      if (short_fname == NULL) {
        retval = false;
        goto theend;
      }
      *endp = ch;  // preserve the string
      retval = true;
      break;  // successfully shortened the path
    }
    // failed to shorten the path. Skip the path separator
    endp--;
  }

  size_t len = STRLEN(short_fname);
  if (retval) {
    // Succeeded in shortening the path. Now concatenate the shortened
    // path with the remaining path at the tail.

    // Compute the length of the new path.
    size_t sfx_len = (size_t)(save_endp - endp + 1);
    size_t new_len = len + sfx_len;

    xfree(*bufp);
    if (new_len > old_len) {
      // There is not enough space in the currently allocated string,
      // copy it to a buffer big enough.
      *fname = *bufp = (char *)vim_strnsave((char_u *)short_fname, new_len);
    } else {
      // Transfer short_fname to the main buffer (it's big enough),
      // unless get_short_pathname() did its work in-place.
      *fname = *bufp = save_fname;
      xstrlcpy(save_fname, short_fname, len + 1);
      save_fname = NULL;
    }

    // concat the not-shortened part of the path
    xstrlcpy(*fname + len, endp, sfx_len + 1);
    (*fname)[new_len] = NUL;
  }

theend:
  xfree(short_fname);
  xfree(save_fname);

  return retval;
}

// Get a pathname for a partial path.
// Returns true for success, false for failure.
bool path_short_for_partial(char **fnamep, char **bufp, size_t fnamelen)
{
  int sepcount;
  char *p;

  // Count up the path separators from the RHS.. so we know which part
  // of the path to return.
  sepcount = 0;
  for (p = *fnamep; p < *fnamep + fnamelen; MB_PTR_ADV(p)) {
    if (vim_ispathsep(*p)) {
      sepcount++;
    }
  }

  // Need full path first (use expand_env() to remove a "~/")
  bool hasTilde = (**fnamep == '~');
  char *pbuf, *tfname;
  if (hasTilde) {
    pbuf = tfname = (char *)expand_env_save((char_u *)(*fnamep));
  } else {
    pbuf = tfname = FullName_save(*fnamep, false);
  }

  size_t len = STRLEN(tfname);

  if (os_path_exists((const char_u *)tfname)) {
    if (!path_to_short(tfname, pbuf, len)) {
      return false;
    }
  } else {
    // Don't have a valid filename, so shorten the rest of the
    // path if we can. This CAN give us invalid 8.3 filenames, but
    // there's not a lot of point in guessing what it might be.
    if (!path_short_for_invalid_fname(&tfname, &pbuf, len)) {
      return false;
    }
  }

  len = STRLEN(tfname);

  // Count the paths backward to find the beginning of the desired string.
  for (p = tfname + len - 1; p >= tfname; p--) {
    if (has_mbyte) {
      p -= utf_head_off((const char_u *)tfname, (char_u *)p);
    }
    if (vim_ispathsep(*p)) {
      if (sepcount == 0 || (hasTilde && sepcount == 1)) {
        break;
      } else {
        sepcount--;
      }
    }
  }
  if (hasTilde) {
    p--;
    if (p >= tfname) {
      *p = '~';
    } else {
      return false;
    }
  } else {
    p++;
  }

  // Copy in the string - p indexes into tfname - allocated at pbuf
  xfree(*bufp);
  *bufp = pbuf;
  *fnamep = p;

  return true;
}
