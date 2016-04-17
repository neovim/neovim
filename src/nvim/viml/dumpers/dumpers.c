#include <string.h>
#include <stddef.h>
#include <stdint.h>

#include "nvim/vim.h"
#include "nvim/viml/dumpers/dumpers.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/dumpers/dumpers.h.generated.h"
#endif

#define _STRINGIFY(x) #x
#define STRINGIFY(x) _STRINGIFY(x)

/// Length of a buffer capable of holding decimal intmax_t representation
///
/// @note Size of the buffer may be actually a few characters off compared to
///       minimum required size.
#define MAXNUMBUFLEN (sizeof(STRINGIFY(INTMAX_MAX)) - 1 + 1)

/// Write string with the given length
///
/// @param[in]  s       String that will be written.
/// @param[in]  len     Length of this string.
/// @param[in]  write   Function used to write the string.
/// @param[in]  cookie  Last argument to that function.
///
/// @return OK in case of success, FAIL otherwise.
int write_string_len(const char *const s, size_t len, Writer write,
                     void *cookie)
{
  if (len) {
    write(s, 1, len, cookie);
  }
  return OK;
}

/// Write string with given characters escaped
///
/// @param[in]  s       String that will be written.
/// @param[in]  len     Length of this string.
/// @param[in]  write   Function used to write the string.
/// @param[in]  cookie  Pointer to the structure with last argument to that
///                     function and characters that need to be escaped.
///
/// @return Number of characters written.
size_t write_escaped_string_len(const void *s, size_t size, size_t nmemb,
                                void *cookie)
{
  const EscapedCookie *const arg = (const EscapedCookie *) cookie;

  if (size != 1) {
    return arg->write(s, size, nmemb, arg->cookie);
  }

  const char *const e = ((char *) s) + nmemb - 1;
  const char bslash[] = { '\\' };
  size_t written = 0;

  for (const char *p = (char *) s; p <= e; p++) {
    if (strchr(arg->echars, *p) != NULL) {
      written += arg->write(bslash, 1, 1, arg->cookie);
    }
    written += arg->write(p, 1, 1, arg->cookie);
  }
  return written;
}

/// Return given unsigned integer number string representation length
///
/// @param[in]  unumber  Dumped integer.
size_t sdump_unumber_len(const uintmax_t unumber)
{
  uintmax_t i = unumber;
  size_t len = 0;
  do {
    i /= 10;
    len++;
  } while (i);
  return len;
}

/// Dump given unsigned integer number to given location
///
/// @param[in]   unumber  Dumped integer.
/// @param[out]  pp       Location where number should be written to.
void sdump_unumber(const uintmax_t unumber, char **pp)
{
  char *p = *pp;
  size_t i = sdump_unumber_len(unumber);
  do {
    uintmax_t digit;
    uintmax_t d = 1;
    for (size_t j = 1; j < i; j++) {
      d *= 10;
    }
    digit = (unumber / d) % 10;
    *p++ = (char) ('0' + digit);
  } while (--i);
  *pp = p;
}

/// Write given unsigned integer number
///
/// @param[in]  unumber  Dumped integer.
/// @param[in]  write    Function used to write result.
/// @param[in]  cookie   Last argument to that function.
int dump_unumber(const uintmax_t unumber, Writer write, void *cookie)
{
  char result[MAXNUMBUFLEN];
  char *e = result;
  sdump_unumber(unumber, &e);
  return write_string_len(result, (size_t) (e - result), write, cookie);
}

#define ABS(n) ((uintmax_t) (n >= 0 ? n : -n))

/// Return given signed integer number string representation length
///
/// @param[in]  number  Dumped integer.
size_t sdump_number_len(const intmax_t number)
{
  return sdump_unumber_len(ABS(number)) + (number < 0);
}

/// Dump given signed integer number to given location
///
/// @param[in]   number  Dumped integer.
/// @param[out]  pp      Location where number should be written to.
void sdump_number(const intmax_t number, char **pp)
{
  char *p = *pp;
  if (number < 0) {
    *p++ = '-';
  }
  sdump_unumber(ABS(number), &p);
  *pp = p;
}

/// Write given signed integer number
///
/// @param[in]  number  Dumped integer.
/// @param[in]  write   Function used to write result.
/// @param[in]  cookie  Last argument to that function.
int dump_number(const intmax_t number, Writer write, void *cookie)
{
  char result[MAXNUMBUFLEN + 1];
  char *e = result;
  sdump_number((intmax_t) number, &e);
  return write_string_len(result, (size_t) (e - result), write, cookie);
}

#undef ABS
