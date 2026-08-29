// Vendored from https://github.com/sabotage-linux/gettext-tiny/blob/master/include/libintl.h
#ifndef LIBINTL_H
#define LIBINTL_H

#ifdef __cplusplus
extern "C" {
#endif

#if __GNUC__ + 0 >= 3
# define GETTEXT_INTERNAL_FA(n) __attribute__ ((__format_arg__ (n)))
#else
# define GETTEXT_INTERNAL_FA(n)
#endif

char *gettext(const char *msgid)
	GETTEXT_INTERNAL_FA(1);
char *dgettext(const char *domainname, const char *msgid)
	GETTEXT_INTERNAL_FA(2);
char *dcgettext(const char *domainname, const char *msgid, int category)
	GETTEXT_INTERNAL_FA(2);
char *ngettext(const char *msgid1, const char *msgid2, unsigned long n)
	GETTEXT_INTERNAL_FA(1) GETTEXT_INTERNAL_FA(2);
char *dngettext(const char *domainname, const char *msgid1, const char *msgid2, unsigned long n)
	GETTEXT_INTERNAL_FA(2) GETTEXT_INTERNAL_FA(3);
char *dcngettext(const char *domainname, const char *msgid1, const char *msgid2, unsigned long n, int category)
	GETTEXT_INTERNAL_FA(2) GETTEXT_INTERNAL_FA(3);

char *textdomain(const char *domainname);
char *bind_textdomain_codeset(const char *domainname, const char *codeset);
char *bindtextdomain(const char *domainname, const char *dirname);
#ifdef __cplusplus
}
#endif

#undef gettext_noop
#define gettext_noop(X) X

#ifndef LIBINTL_NO_MACROS
/* if these macros are defined, configure checks will detect libintl as
 * built into the libc because test programs will work without -lintl.
 * for example:
 * checking for ngettext in libc ... yes
 * the consequence is that -lintl will not be added to the LDFLAGS.
 * so if for some reason you want that libintl.a gets linked,
 * add -DLIBINTL_NO_MACROS=1 to your CPPFLAGS. */

#define gettext(X) ((char*) (X))
#define dgettext(dom, X) ((void)(dom), (char*) (X))
#define dcgettext(dom, X, cat) ((void)(dom), (void)(cat), (char*) (X))
#define ngettext(X, Y, N) \
	((char*) (((N) == 1) ? ((void)(Y), (X)) : ((void)(X), (Y))))
#define dngettext(dom, X, Y, N) \
	((dom), (char*) (((N) == 1) ? ((void)(Y), (X)) : ((void)(X), (Y))))
#define dcngettext(dom, X, Y, N, cat) \
	((dom), (cat), (char*) (((N) == 1) ? ((void)(Y), (X)) : ((void)(X), (Y))))
#define bindtextdomain(X, Y) ((void)(X), (void)(Y), (char*) "/")
#define bind_textdomain_codeset(dom, codeset) \
	((void)(dom), (void)(codeset), (char*) 0)
#define textdomain(X) ((void)(X), (char*) "messages")

#undef ENABLE_NLS
#undef DISABLE_NLS
#define DISABLE_NLS 1

#if __GNUC__ +0 > 3
/* most ppl call bindtextdomain() without using its return value
   thus we get tons of warnings about "statement with no effect" */
#pragma GCC diagnostic ignored "-Wunused-value"
#endif

#endif

// Nvim: unused, and variadic macros are an unsupported extension
// #include <stdio.h>
// #define gettext_printf(args...) printf(args)

/* to supply LC_MESSAGES and other stuff GNU expects to be exported when
   including libintl.h */
#include <locale.h>

#endif

