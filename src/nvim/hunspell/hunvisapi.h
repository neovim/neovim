#ifndef HUNSPELL_VISIBILITY_H_
#define HUNSPELL_VISIBILITY_H_

#if defined(HUNSPELL_STATIC)
#  define LIBHUNSPELL_DLL_EXPORTED
#elif defined(_WIN32)
#  if defined(BUILDING_LIBHUNSPELL)
#    define LIBHUNSPELL_DLL_EXPORTED __declspec(dllexport)
#  else
#    define LIBHUNSPELL_DLL_EXPORTED __declspec(dllimport)
#  endif
#elif defined(BUILDING_LIBHUNSPELL) && 1
#  define LIBHUNSPELL_DLL_EXPORTED __attribute__((__visibility__("default")))
#else
#  define LIBHUNSPELL_DLL_EXPORTED
#endif

#endif
