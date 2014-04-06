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


#endif  // NEOVIM_OS_TIME_H

