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
    const char *lang_region = NULL;
    CFTypeRef cf_lang_region = NULL;

    CFLocaleRef cf_locale = CFLocaleCopyCurrent();
    if (cf_locale) {
      cf_lang_region = CFLocaleGetValue(cf_locale, kCFLocaleIdentifier);
      CFRetain(cf_lang_region);
      lang_region = CFStringGetCStringPtr(cf_lang_region,
                                          kCFStringEncodingUTF8);
      CFRelease(cf_locale);
    } else {
      // Use the primary language defined in Preferences -> Language & Region
      CFArrayRef cf_langs = CFLocaleCopyPreferredLanguages();
      if (cf_langs && CFArrayGetCount(cf_langs) > 0) {
        cf_lang_region = CFArrayGetValueAtIndex(cf_langs, 0);
        CFRetain(cf_lang_region);
        CFRelease(cf_langs);
        lang_region = CFStringGetCStringPtr(cf_lang_region,
                                            kCFStringEncodingUTF8);
      } else {
        ELOG("$LANG is empty and your primary language cannot be inferred.");
        return;
      }
    }

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

#  ifdef LC_NUMERIC
    // Make sure strtod() uses a decimal point, not a comma.
    setlocale(LC_NUMERIC, "C");
#  endif
# endif
  }
#endif
}
