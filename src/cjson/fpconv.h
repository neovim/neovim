/* Lua CJSON floating point conversion routines */

/* Buffer required to store the largest string representation of a double.
 *
 * Longest double printed with %.14g is 21 characters long:
 * -1.7976931348623e+308 */
# define FPCONV_G_FMT_BUFSIZE   32

#ifdef USE_INTERNAL_FPCONV
// #ifdef MULTIPLE_THREADS
// #include "dtoa_config.h"
// #include <unistd.h>
// static inline void fpconv_init()
// {
//     // Add one to try and avoid core id multiplier alignment
//     set_max_dtoa_threads((sysconf(_SC_NPROCESSORS_CONF) + 1) * 3);
// }
// #else
static inline void fpconv_init()
{
    /* Do nothing - not required */
}
// #endif
#else
extern void fpconv_init(void);
#endif

extern int fpconv_g_fmt(char*, double, int);
extern double fpconv_strtod(const char*, char**);

/* vi:ai et sw=4 ts=4:
 */
