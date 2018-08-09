// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#ifdef __APPLE__
# define Boolean CFBoolean  // Avoid conflict with API's Boolean
# include <CoreFoundation/CFLocale.h>
# include <CoreFoundation/CFString.h>
# undef Boolean
#endif

#ifdef HAVE_LOCALE_H
# include <locale.h>
#endif
#include "nvim/os/os.h"

void lang_init(void)
{
#ifdef __APPLE__
  if (os_getenv("LANG") == NULL) {
    CFLocaleRef cf_locale = CFLocaleCopyCurrent();
    CFTypeRef cf_lang_region = CFLocaleGetValue(cf_locale,
                                                kCFLocaleIdentifier);
    CFRetain(cf_lang_region);
    CFRelease(cf_locale);

    const char *lang_region = CFStringGetCStringPtr(cf_lang_region,
                                                    kCFStringEncodingUTF8);
    if (lang_region) {
      os_setenv("LANG", lang_region, true);
    } else {
      char buf[20] = { 0 };
      if (CFStringGetCString(cf_lang_region, buf, 20,
                             kCFStringEncodingUTF8)) {
        os_setenv("LANG", buf, true);
      }
    }
    CFRelease(cf_lang_region);
# ifdef HAVE_LOCALE_H
    setlocale(LC_ALL, "");
# endif
  }
#endif
}
