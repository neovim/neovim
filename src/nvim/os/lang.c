// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#ifdef __APPLE__
# define Boolean CFBoolean  // Avoid conflict with API's Boolean
# define FileInfo CSFileInfo  // Avoid conflict with API's Fileinfo
# include <CoreServices/CoreServices.h>
# undef Boolean
# undef FileInfo
#endif

#include <locale.h>
#include <stdbool.h>
#include <stdio.h>

#include "auto/config.h"
#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/garray.h"
#include "nvim/gettext.h"
#include "nvim/macros.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option.h"
#include "nvim/os/lang.h"
#include "nvim/os/os.h"
#include "nvim/os/shell.h"
#include "nvim/path.h"
#include "nvim/profile.h"
#include "nvim/types.h"
#include "nvim/vim.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/lang.c.generated.h"
#endif

static char *get_locale_val(int what)
{
  // Obtain the locale value from the libraries.
  char *loc = setlocale(what, NULL);

  return loc;
}

/// @return  true when "lang" starts with a valid language name.
///          Rejects NULL, empty string, "C", "C.UTF-8" and others.
static bool is_valid_mess_lang(const char *lang)
{
  return lang != NULL && ASCII_ISALPHA(lang[0]) && ASCII_ISALPHA(lang[1]);
}

/// Obtain the current messages language.  Used to set the default for
/// 'helplang'.  May return NULL or an empty string.
char *get_mess_lang(void)
{
  char *p;

#if defined(LC_MESSAGES)
  p = get_locale_val(LC_MESSAGES);
#else
  // This is necessary for Win32, where LC_MESSAGES is not defined and $LANG
  // may be set to the LCID number.  LC_COLLATE is the best guess, LC_TIME
  // and LC_MONETARY may be set differently for a Japanese working in the
  // US.
  p = get_locale_val(LC_COLLATE);
#endif
  return is_valid_mess_lang(p) ? p : NULL;
}

// Complicated #if; matches with where get_mess_env() is used below.
#ifdef HAVE_WORKING_LIBINTL
/// Get the language used for messages from the environment.
static char *get_mess_env(void)
{
  char *p;

  p = (char *)os_getenv("LC_ALL");
  if (p == NULL) {
    p = (char *)os_getenv("LC_MESSAGES");
    if (p == NULL) {
      p = (char *)os_getenv("LANG");
      if (p != NULL && ascii_isdigit(*p)) {
        p = NULL;                       // ignore something like "1043"
      }
      if (p == NULL) {
        p = get_locale_val(LC_CTYPE);
      }
    }
  }
  return p;
}
#endif

/// Set the "v:lang" variable according to the current locale setting.
/// Also do "v:lc_time"and "v:ctype".
void set_lang_var(void)
{
  const char *loc;

  loc = get_locale_val(LC_CTYPE);
  set_vim_var_string(VV_CTYPE, loc, -1);

  // When LC_MESSAGES isn't defined use the value from $LC_MESSAGES, fall
  // back to LC_CTYPE if it's empty.
#ifdef HAVE_WORKING_LIBINTL
  loc = get_mess_env();
#elif defined(LC_MESSAGES)
  loc = get_locale_val(LC_MESSAGES);
#else
  // In Windows LC_MESSAGES is not defined fallback to LC_CTYPE
  loc = get_locale_val(LC_CTYPE);
#endif
  set_vim_var_string(VV_LANG, loc, -1);

  loc = get_locale_val(LC_TIME);
  set_vim_var_string(VV_LC_TIME, loc, -1);

  loc = get_locale_val(LC_COLLATE);
  set_vim_var_string(VV_COLLATE, loc, -1);
}

/// Setup to use the current locale (for ctype() and many other things).
void init_locale(void)
{
  setlocale(LC_ALL, "");

#ifdef LC_NUMERIC
  // Make sure strtod() uses a decimal point, not a comma.
  setlocale(LC_NUMERIC, "C");
#endif

  char localepath[MAXPATHL] = { 0 };
  snprintf(localepath, sizeof(localepath), "%s", get_vim_var_str(VV_PROGPATH));
  char *tail = path_tail_with_sep(localepath);
  *tail = NUL;
  tail = path_tail(localepath);
  xstrlcpy(tail, "share/locale",
           sizeof(localepath) - (size_t)(tail - localepath));
  bindtextdomain(PROJECT_NAME, localepath);
  textdomain(PROJECT_NAME);
  TIME_MSG("locale set");
}

#ifdef HAVE_WORKING_LIBINTL

/// ":language":  Set the language (locale).
///
/// @param eap
void ex_language(exarg_T *eap)
{
  char *loc;
  char *p;
  char *name;
  int what = LC_ALL;
  char *whatstr = "";
# ifdef LC_MESSAGES
#  define VIM_LC_MESSAGES LC_MESSAGES
# else
#  define VIM_LC_MESSAGES 6789
# endif

  name = eap->arg;

  // Check for "messages {name}", "ctype {name}" or "time {name}" argument.
  // Allow abbreviation, but require at least 3 characters to avoid
  // confusion with a two letter language name "me" or "ct".
  p = skiptowhite(eap->arg);
  if ((*p == NUL || ascii_iswhite(*p)) && p - eap->arg >= 3) {
    if (STRNICMP(eap->arg, "messages", p - eap->arg) == 0) {
      what = VIM_LC_MESSAGES;
      name = skipwhite(p);
      whatstr = "messages ";
    } else if (STRNICMP(eap->arg, "ctype", p - eap->arg) == 0) {
      what = LC_CTYPE;
      name = skipwhite(p);
      whatstr = "ctype ";
    } else if (STRNICMP(eap->arg, "time", p - eap->arg) == 0) {
      what = LC_TIME;
      name = skipwhite(p);
      whatstr = "time ";
    } else if (STRNICMP(eap->arg, "collate", p - eap->arg) == 0) {
      what = LC_COLLATE;
      name = skipwhite(p);
      whatstr = "collate ";
    }
  }

  if (*name == NUL) {
    if (what == VIM_LC_MESSAGES) {
      p = get_mess_env();
    } else {
      p = setlocale(what, NULL);
    }
    if (p == NULL || *p == NUL) {
      p = "Unknown";
    }
    smsg(_("Current %slanguage: \"%s\""), whatstr, p);
  } else {
# ifndef LC_MESSAGES
    if (what == VIM_LC_MESSAGES) {
      loc = "";
    } else {
# endif
    loc = setlocale(what, name);
# ifdef LC_NUMERIC
    // Make sure strtod() uses a decimal point, not a comma.
    setlocale(LC_NUMERIC, "C");
# endif
# ifndef LC_MESSAGES
  }
# endif
    if (loc == NULL) {
      semsg(_("E197: Cannot set language to \"%s\""), name);
    } else {
# ifdef HAVE_NL_MSG_CAT_CNTR
      // Need to do this for GNU gettext, otherwise cached translations
      // will be used again.
      extern int _nl_msg_cat_cntr;

      _nl_msg_cat_cntr++;
# endif
      // Reset $LC_ALL, otherwise it would overrule everything.
      os_setenv("LC_ALL", "", 1);

      if (what != LC_TIME && what != LC_COLLATE) {
        // Tell gettext() what to translate to.  It apparently doesn't
        // use the currently effective locale.
        if (what == LC_ALL) {
          os_setenv("LANG", name, 1);

          // Clear $LANGUAGE because GNU gettext uses it.
          os_setenv("LANGUAGE", "", 1);
        }
        if (what != LC_CTYPE) {
          os_setenv("LC_MESSAGES", name, 1);
          set_helplang_default(name);
        }
      }

      // Set v:lang, v:lc_time, v:collate and v:ctype to the final result.
      set_lang_var();
      maketitle();
    }
  }
}

static char **locales = NULL;       // Array of all available locales

# ifndef MSWIN
static bool did_init_locales = false;

/// @return  an array of strings for all available locales + NULL for the
///          last element or,
///          NULL in case of error.
static char **find_locales(void)
{
  garray_T locales_ga;
  char *loc;
  char *saveptr = NULL;

  // Find all available locales by running command "locale -a".  If this
  // doesn't work we won't have completion.
  char *locale_a = get_cmd_output("locale -a", NULL, kShellOptSilent, NULL);
  if (locale_a == NULL) {
    return NULL;
  }
  ga_init(&locales_ga, sizeof(char *), 20);

  // Transform locale_a string where each locale is separated by "\n"
  // into an array of locale strings.
  loc = os_strtok(locale_a, "\n", &saveptr);

  while (loc != NULL) {
    loc = xstrdup(loc);
    GA_APPEND(char *, &locales_ga, loc);
    loc = os_strtok(NULL, "\n", &saveptr);
  }
  xfree(locale_a);
  // Guarantee that .ga_data is NULL terminated
  ga_grow(&locales_ga, 1);
  ((char **)locales_ga.ga_data)[locales_ga.ga_len] = NULL;
  return locales_ga.ga_data;
}
# endif

/// Lazy initialization of all available locales.
static void init_locales(void)
{
# ifndef MSWIN
  if (did_init_locales) {
    return;
  }

  did_init_locales = true;
  locales = find_locales();
# endif
}

# if defined(EXITFREE)
void free_locales(void)
{
  if (locales == NULL) {
    return;
  }

  for (int i = 0; locales[i] != NULL; i++) {
    xfree(locales[i]);
  }
  XFREE_CLEAR(locales);
}
# endif

/// Function given to ExpandGeneric() to obtain the possible arguments of the
/// ":language" command.
char *get_lang_arg(expand_T *xp, int idx)
{
  if (idx == 0) {
    return "messages";
  }
  if (idx == 1) {
    return "ctype";
  }
  if (idx == 2) {
    return "time";
  }
  if (idx == 3) {
    return "collate";
  }

  init_locales();
  if (locales == NULL) {
    return NULL;
  }
  return locales[idx - 4];
}

/// Function given to ExpandGeneric() to obtain the available locales.
char *get_locales(expand_T *xp, int idx)
{
  init_locales();
  if (locales == NULL) {
    return NULL;
  }
  return locales[idx];
}

#endif

void lang_init(void)
{
#ifdef __APPLE__
  if (os_getenv("LANG") == NULL) {
    char buf[50] = { 0 };

    // $LANG is not set, either because it was unset or Nvim was started
    // from the Dock. Query the system locale.
    if (LocaleRefGetPartString(NULL,
                               kLocaleLanguageMask | kLocaleLanguageVariantMask |
                               kLocaleRegionMask | kLocaleRegionVariantMask,
                               sizeof(buf) - 10, buf) == noErr && *buf) {
      if (strcasestr(buf, "utf-8") == NULL) {
        xstrlcat(buf, ".UTF-8", sizeof(buf));
      }
      os_setenv("LANG", buf, true);
      setlocale(LC_ALL, "");
      // Make sure strtod() uses a decimal point, not a comma.
      setlocale(LC_NUMERIC, "C");
    } else {
      ELOG("$LANG is empty and the macOS primary language cannot be inferred.");
    }
  }
#endif
}
