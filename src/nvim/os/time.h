#ifndef NEOVIM_OS_TIME_H
#define NEOVIM_OS_TIME_H

#include <stdint.h>
#include <stdbool.h>

/// Initializes the time module
void time_init(void);

/// Sleeps for a certain amount of milliseconds
///
/// @param milliseconds Number of milliseconds to sleep
/// @param ignoreinput If true, allow a SIGINT to interrupt us
void os_delay(uint64_t milliseconds, bool ignoreinput);

/// Sleeps for a certain amount of microseconds
///
/// @param microseconds Number of microseconds to sleep
/// @param ignoreinput If true, allow a SIGINT to interrupt us
void os_microdelay(uint64_t microseconds, bool ignoreinput);

/// Portable version of POSIX localtime_r()
///
/// @return NULL in case of error
struct tm *os_localtime_r(const time_t *clock, struct tm *result);

/// Obtains the current UNIX timestamp and adjusts it to local time
///
/// @param result Pointer to a 'struct tm' where the result should be placed
/// @return A pointer to a 'struct tm' in the current time zone (the 'result'
///         argument) or NULL in case of error
struct tm *os_get_localtime(struct tm *result);

#endif  // NEOVIM_OS_TIME_H

