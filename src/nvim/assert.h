#ifndef NVIM_ASSERT_H
#define NVIM_ASSERT_H

// support static asserts (aka compile-time asserts)

// some compilers don't properly support short-circuiting apparently, giving
// ugly syntax errors when using things like defined(__clang__) &&
// defined(__has_feature) && __has_feature(...). Therefore we define Clang's
// __has_feature and __has_extension macro's before referring to them.
#ifndef __has_feature
  #define __has_feature(x) 0
#endif

#ifndef __has_extension
  #define __has_extension __has_feature
#endif

/// STATIC_ASSERT(condition, message) - assert at compile time if !cond
///
/// example:
///  STATIC_ASSERT(sizeof(void *) == 8, "need 64-bits mode");

// define STATIC_ASSERT as C11's _Static_assert whenever either C11 mode is
// detected or the compiler is known to support it. Note that Clang in C99
// mode defines __has_feature(c_static_assert) as false and
// __has_extension(c_static_assert) as true. Meaning it does support it, but
// warns. A similar thing goes for gcc, which warns when it's not compiling
// as C11 but does support _Static_assert since 4.6. Since we prefer the
// clearer messages we get from _Static_assert, we suppress the warnings
// temporarily.

// the easiest case, when the mode is C11 (generic compiler) or Clang
// advertises explicit support for c_static_assert, meaning it won't warn.
#if __STDC_VERSION__ >= 201112L || __has_feature(c_static_assert)
  #define STATIC_ASSERT(cond, msg) _Static_assert(cond, msg)
// if we're dealing with gcc >= 4.6 in C99 mode, we can still use
// _Static_assert but we need to suppress warnings, this is pretty ugly.
#elif (!defined(__clang__) && !defined(__INTEL_COMPILER)) && \
  (__GNUC__ > 4 || (__GNUC__ == 4 && __GNUC_MINOR__ >= 6))
  #define STATIC_ASSERT(cond, msg) \
	_Pragma("GCC diagnostic push") \
	_Pragma("GCC diagnostic ignored \"-pedantic\"") \
	_Static_assert(cond, msg); \
	_Pragma("GCC diagnostic pop") \

// the same goes for clang in C99 mode, but we suppress a different warning
#elif defined(__clang__) && __has_extension(c_static_assert)
  #define STATIC_ASSERT(cond, msg) \
	_Pragma("clang diagnostic push") \
	_Pragma("clang diagnostic ignored \"-Wc11-extensions\"") \
	_Static_assert(cond, msg); \
	_Pragma("clang diagnostic pop") \

// TODO(aktau): verify that this works, don't have MSVC on hand.
#elif _MSC_VER >= 1600
  #define STATIC_ASSERT(cond, msg) static_assert(cond, msg)

// fallback for compilers that don't support _Static_assert or static_assert
// not as pretty but gets the job done. Credit goes to Pádraig Brady and
// contributors.
#else
  #define ASSERT_CONCAT_(a, b) a##b
  #define ASSERT_CONCAT(a, b) ASSERT_CONCAT_(a, b)
  // These can't be used after statements in c89.
  #ifdef __COUNTER__
	#define STATIC_ASSERT(e,m) \
	  { enum { ASSERT_CONCAT(static_assert_, __COUNTER__) = 1/(!!(e)) }; }
  #else
	// This can't be used twice on the same line so ensure if using in headers
	// that the headers are not included twice (by wrapping in #ifndef...#endif)
	// Note it doesn't cause an issue when used on same line of separate modules
	// compiled with gcc -combine -fwhole-program.
	#define STATIC_ASSERT(e,m) \
	  { enum { ASSERT_CONCAT(assert_line_, __LINE__) = 1/(!!(e)) }; }
  #endif
#endif

#endif  // NVIM_ASSERT_H
