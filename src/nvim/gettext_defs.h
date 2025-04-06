#pragma once

#ifdef HAVE_WORKING_LIBINTL
# include <libintl.h>  // IWYU pragma: export
# define _(x) gettext(x)  // NOLINT(bugprone-reserved-identifier)
// XXX do we actually need this?
# ifdef gettext_noop
#  define N_(x) gettext_noop(x)
# else
#  define N_(x) x
# endif
# define NGETTEXT(x, xs, n) ngettext(x, xs, (unsigned long)n)
// On a Mac, gettext's libintl.h defines "setlocale" to be replaced by
// "libintl_setlocal" which leads to wrong return values. #9789
# if defined(__APPLE__) && defined(setlocale)
#  undef setlocale
# endif
#else
# define _(x) ((char *)(x))  // NOLINT(bugprone-reserved-identifier)
# define N_(x) x
# define NGETTEXT(x, xs, n) ((n) == 1 ? (x) : (xs))
# define bindtextdomain(x, y)  // empty
# define bind_textdomain_codeset(x, y)  // empty
# define textdomain(x)  // empty
#endif
