#ifndef NVIM_GETTEXT_H
#define NVIM_GETTEXT_H

#ifdef HAVE_WORKING_LIBINTL
# include <libintl.h>
# define _(x) gettext((char *)(x))
// XXX do we actually need this?
# ifdef gettext_noop
#  define N_(x) gettext_noop(x)
# else
#  define N_(x) x
# endif
# define NGETTEXT(x, xs, n) ngettext(x, xs, n)
#else
# define _(x) ((char *)(x))
# define N_(x) x
# define NGETTEXT(x, xs, n) ((n) == 1 ? (x) : (xs))
# define bindtextdomain(x, y)  // empty
# define bind_textdomain_codeset(x, y)  // empty
# define textdomain(x)  // empty
#endif

#endif  // NVIM_GETTEXT_H
