// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#ifdef __APPLE__
# define Boolean CFBoolean  // Avoid conflict with API's Boolean
# define FileInfo CSFileInfo  // Avoid conflict with API's Fileinfo
# include <CoreServices/CoreServices.h>
# undef Boolean
# undef FileInfo
#endif

#include "auto/config.h"

#ifdef HAVE_LOCALE_H
# include <locale.h>
#endif

#include "nvim/os/lang.h"
#include "nvim/os/os.h"

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
