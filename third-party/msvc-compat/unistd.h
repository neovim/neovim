#ifndef GUARD_UNIBILIUM_UNISTD_H_
#define GUARD_UNIBILIUM_UNISTD_H_

#ifdef  _WIN64
typedef unsigned __int64    ssize_t;
#else
typedef _W64 unsigned int   ssize_t;
#endif

#endif
