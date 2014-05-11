// If DEFINE_FUNC_ATTRIBUTES macro is not defined then all function attributes 
// are defined as empty values.
//
// If DO_NOT_DEFINE_EMPTY_ATTRIBUTES then empty macros are not defined. Thus 
// undefined DEFINE_FUNC_ATTRIBUTES and defined DO_NOT_DEFINE_EMPTY_ATTRIBUTES 
// leaves file with untouched FUNC_ATTR_* macros. This variant is used for 
// scripts/gendeclarations.lua.
//
// Empty macros are used for *.c files. (undefined DEFINE_FUNC_ATTRIBUTES and 
// undefined DO_NOT_DEFINE_EMPTY_ATTRIBUTES)
//
// Macros defined as __attribute__((*)) are used by generated header files. 
// (defined DEFINE_FUNC_ATTRIBUTES and undefined 
// DO_NOT_DEFINE_EMPTY_ATTRIBUTES)
//
// Defined DEFINE_FUNC_ATTRIBUTES and defined DO_NOT_DEFINE_EMPTY_ATTRIBUTES is 
// not used by anything.

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

#ifdef FUNC_ATTR_MALLOC
  #undef FUNC_ATTR_MALLOC
#endif

#ifdef FUNC_ATTR_ALLOC_SIZE
  #undef FUNC_ATTR_ALLOC_SIZE
#endif

#ifdef FUNC_ATTR_ALLOC_SIZE_PROD
  #undef FUNC_ATTR_ALLOC_SIZE_PROD
#endif

#ifdef FUNC_ATTR_ALLOC_ALIGN
  #undef FUNC_ATTR_ALLOC_ALIGN
#endif

#ifdef FUNC_ATTR_PURE
  #undef FUNC_ATTR_PURE
#endif

#ifdef FUNC_ATTR_CONST
  #undef FUNC_ATTR_CONST
#endif

#ifdef FUNC_ATTR_WARN_UNUSED_RESULT
  #undef FUNC_ATTR_WARN_UNUSED_RESULT
#endif

#ifdef FUNC_ATTR_ALWAYS_INLINE
  #undef FUNC_ATTR_ALWAYS_INLINE
#endif

#ifdef FUNC_ATTR_UNUSED
  #undef FUNC_ATTR_UNUSED
#endif

#ifdef FUNC_ATTR_NONNULL_ALL
  #undef FUNC_ATTR_NONNULL_ALL
#endif

#ifdef FUNC_ATTR_NONNULL_ARG
  #undef FUNC_ATTR_NONNULL_ARG
#endif

#ifdef FUNC_ATTR_NONNULL_RET
  #undef FUNC_ATTR_NONNULL_RET
#endif

#ifdef DEFINE_FUNC_ATTRIBUTES
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
#endif

#ifndef DO_NOT_DEFINE_EMPTY_ATTRIBUTES
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
#endif
