#ifndef NEOVIM_FUNC_ATTR_H
#define NEOVIM_FUNC_ATTR_H

// gcc and clang expose their version as follows:
//
// gcc 4.7.2:
//   __GNUC__          = 4
//   __GNUC_MINOR__    = 7
//   __GNUC_PATCHLEVEL = 2
//
// clang 3.4 (claims compat with gcc 4.2.1):
//   __GNUC__          = 4
//   __GNUC_MINOR__    = 2
//   __GNUC_PATCHLEVEL = 1
//   __clang__         = 1
//   __clang_major__   = 3
//   __clang_minor__   = 4
//
// To view the default defines of these compilers, you can perform:
//
// $ gcc -E -dM - </dev/null
// $ echo | clang -dM -E -

#ifdef __GNUC__
  // place defines for all gnulikes here, for now that's gcc, clang and
  // intel.

  // place these after the argument list of the function declaration
  // (not definition), like so:
  // void myfunc(void) FUNC_ATTR_ALWAYS_INLINE;
  #define FUNC_ATTR_MALLOC __attribute__((malloc))
  #define FUNC_ATTR_ALLOC_ALIGN(x) __attribute__((alloc_align(x)))
  #define FUNC_ATTR_PURE __attribute__ ((pure))
  #define FUNC_ATTR_CONST __attribute__((const))
  #define FUNC_ATTR_WARN_UNUSED_RESULT __attribute__((warn_unused_result))
  #define FUNC_ATTR_ALWAYS_INLINE __attribute__((always_inline))
  #define FUNC_ATTR_UNUSED __attribute__((unused))

  #ifdef __clang__
    // clang only
  #elif defined(__INTEL_COMPILER)
    // intel only
  #else
    #define GCC_VERSION \
           (__GNUC__ * 10000 + \
            __GNUC_MINOR__ * 100 + \
            __GNUC_PATCHLEVEL__)
    // gcc only
    #define FUNC_ATTR_ALLOC_SIZE(x) __attribute__((alloc_size(x)))
    #define FUNC_ATTR_ALLOC_SIZE_PROD(x,y) __attribute__((alloc_size(x,y)))
    #define FUNC_ATTR_NONNULL_ALL __attribute__((nonnull))
    #define FUNC_ATTR_NONNULL_ARG(...) __attribute__((nonnull(__VA_ARGS__)))
    #if GCC_VERSION >= 40900
      #define FUNC_ATTR_NONNULL_RET __attribute__((returns_nonnull))
    #endif
  #endif
#endif

// define function attributes that haven't been defined for this specific
// compiler.

#ifndef FUNC_ATTR_MALLOC
  #define FUNC_ATTR_MALLOC
#endif

#ifndef FUNC_ATTR_ALLOC_SIZE
  #define FUNC_ATTR_ALLOC_SIZE(x)
#endif

#ifndef FUNC_ATTR_ALLOC_SIZE_PROD
  #define FUNC_ATTR_ALLOC_SIZE_PROD(x,y)
#endif

#ifndef FUNC_ATTR_ALLOC_ALIGN
  #define FUNC_ATTR_ALLOC_ALIGN(x)
#endif

#ifndef FUNC_ATTR_PURE
  #define FUNC_ATTR_PURE
#endif

#ifndef FUNC_ATTR_CONST
  #define FUNC_ATTR_CONST
#endif

#ifndef FUNC_ATTR_WARN_UNUSED_RESULT
  #define FUNC_ATTR_WARN_UNUSED_RESULT
#endif

#ifndef FUNC_ATTR_ALWAYS_INLINE
  #define FUNC_ATTR_ALWAYS_INLINE
#endif

#ifndef FUNC_ATTR_UNUSED
  #define FUNC_ATTR_UNUSED
#endif

#ifndef FUNC_ATTR_NONNULL_ALL
  #define FUNC_ATTR_NONNULL_ALL
#endif

#ifndef FUNC_ATTR_NONNULL_ARG
  #define FUNC_ATTR_NONNULL_ARG(...)
#endif

#ifndef FUNC_ATTR_NONNULL_RET
  #define FUNC_ATTR_NONNULL_RET
#endif

#endif // NEOVIM_FUNC_ATTR_H
