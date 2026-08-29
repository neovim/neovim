#pragma once

// inlined from https://github.com/sabotage-linux/gettext-tiny/blob/master/include/libintl.h

#define _(X) ((char *)(X))  // gettext()
#define N_(X) X  // gettext_noop()
#define NGETTEXT(X, Y, \
                 N) ((char *)((((unsigned long)N) == 1) ? ((void)(Y), (X)) : ((void)(X), (Y))))  // ngettext()
#define bindtextdomain(X, Y) ((void)(X), (void)(Y), (char *)"/")
#define bind_textdomain_codeset(dom, codeset) ((void)(dom), (void)(codeset), (char *)0)
#define textdomain(X) ((void)(X), (char *)"messages")
