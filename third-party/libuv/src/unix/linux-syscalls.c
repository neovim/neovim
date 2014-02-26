/* Copyright Joyent, Inc. and other Node contributors. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

#include "linux-syscalls.h"
#include <unistd.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <errno.h>

#if defined(__i386__)
# ifndef __NR_socketcall
#  define __NR_socketcall 102
# endif
#endif

#if defined(__arm__)
# if defined(__thumb__) || defined(__ARM_EABI__)
#  define UV_SYSCALL_BASE 0
# else
#  define UV_SYSCALL_BASE 0x900000
# endif
#endif /* __arm__ */

#ifndef __NR_accept4
# if defined(__x86_64__)
#  define __NR_accept4 288
# elif defined(__i386__)
   /* Nothing. Handled through socketcall(). */
# elif defined(__arm__)
#  define __NR_accept4 (UV_SYSCALL_BASE + 366)
# endif
#endif /* __NR_accept4 */

#ifndef __NR_eventfd
# if defined(__x86_64__)
#  define __NR_eventfd 284
# elif defined(__i386__)
#  define __NR_eventfd 323
# elif defined(__arm__)
#  define __NR_eventfd (UV_SYSCALL_BASE + 351)
# endif
#endif /* __NR_eventfd */

#ifndef __NR_eventfd2
# if defined(__x86_64__)
#  define __NR_eventfd2 290
# elif defined(__i386__)
#  define __NR_eventfd2 328
# elif defined(__arm__)
#  define __NR_eventfd2 (UV_SYSCALL_BASE + 356)
# endif
#endif /* __NR_eventfd2 */

#ifndef __NR_epoll_create
# if defined(__x86_64__)
#  define __NR_epoll_create 213
# elif defined(__i386__)
#  define __NR_epoll_create 254
# elif defined(__arm__)
#  define __NR_epoll_create (UV_SYSCALL_BASE + 250)
# endif
#endif /* __NR_epoll_create */

#ifndef __NR_epoll_create1
# if defined(__x86_64__)
#  define __NR_epoll_create1 291
# elif defined(__i386__)
#  define __NR_epoll_create1 329
# elif defined(__arm__)
#  define __NR_epoll_create1 (UV_SYSCALL_BASE + 357)
# endif
#endif /* __NR_epoll_create1 */

#ifndef __NR_epoll_ctl
# if defined(__x86_64__)
#  define __NR_epoll_ctl 233 /* used to be 214 */
# elif defined(__i386__)
#  define __NR_epoll_ctl 255
# elif defined(__arm__)
#  define __NR_epoll_ctl (UV_SYSCALL_BASE + 251)
# endif
#endif /* __NR_epoll_ctl */

#ifndef __NR_epoll_wait
# if defined(__x86_64__)
#  define __NR_epoll_wait 232 /* used to be 215 */
# elif defined(__i386__)
#  define __NR_epoll_wait 256
# elif defined(__arm__)
#  define __NR_epoll_wait (UV_SYSCALL_BASE + 252)
# endif
#endif /* __NR_epoll_wait */

#ifndef __NR_epoll_pwait
# if defined(__x86_64__)
#  define __NR_epoll_pwait 281
# elif defined(__i386__)
#  define __NR_epoll_pwait 319
# elif defined(__arm__)
#  define __NR_epoll_pwait (UV_SYSCALL_BASE + 346)
# endif
#endif /* __NR_epoll_pwait */

#ifndef __NR_inotify_init
# if defined(__x86_64__)
#  define __NR_inotify_init 253
# elif defined(__i386__)
#  define __NR_inotify_init 291
# elif defined(__arm__)
#  define __NR_inotify_init (UV_SYSCALL_BASE + 316)
# endif
#endif /* __NR_inotify_init */

#ifndef __NR_inotify_init1
# if defined(__x86_64__)
#  define __NR_inotify_init1 294
# elif defined(__i386__)
#  define __NR_inotify_init1 332
# elif defined(__arm__)
#  define __NR_inotify_init1 (UV_SYSCALL_BASE + 360)
# endif
#endif /* __NR_inotify_init1 */

#ifndef __NR_inotify_add_watch
# if defined(__x86_64__)
#  define __NR_inotify_add_watch 254
# elif defined(__i386__)
#  define __NR_inotify_add_watch 292
# elif defined(__arm__)
#  define __NR_inotify_add_watch (UV_SYSCALL_BASE + 317)
# endif
#endif /* __NR_inotify_add_watch */

#ifndef __NR_inotify_rm_watch
# if defined(__x86_64__)
#  define __NR_inotify_rm_watch 255
# elif defined(__i386__)
#  define __NR_inotify_rm_watch 293
# elif defined(__arm__)
#  define __NR_inotify_rm_watch (UV_SYSCALL_BASE + 318)
# endif
#endif /* __NR_inotify_rm_watch */

#ifndef __NR_pipe2
# if defined(__x86_64__)
#  define __NR_pipe2 293
# elif defined(__i386__)
#  define __NR_pipe2 331
# elif defined(__arm__)
#  define __NR_pipe2 (UV_SYSCALL_BASE + 359)
# endif
#endif /* __NR_pipe2 */

#ifndef __NR_recvmmsg
# if defined(__x86_64__)
#  define __NR_recvmmsg 299
# elif defined(__i386__)
#  define __NR_recvmmsg 337
# elif defined(__arm__)
#  define __NR_recvmmsg (UV_SYSCALL_BASE + 365)
# endif
#endif /* __NR_recvmsg */

#ifndef __NR_sendmmsg
# if defined(__x86_64__)
#  define __NR_sendmmsg 307
# elif defined(__i386__)
#  define __NR_sendmmsg 345
# elif defined(__arm__)
#  define __NR_sendmmsg (UV_SYSCALL_BASE + 374)
# endif
#endif /* __NR_sendmmsg */

#ifndef __NR_utimensat
# if defined(__x86_64__)
#  define __NR_utimensat 280
# elif defined(__i386__)
#  define __NR_utimensat 320
# elif defined(__arm__)
#  define __NR_utimensat (UV_SYSCALL_BASE + 348)
# endif
#endif /* __NR_utimensat */


int uv__accept4(int fd, struct sockaddr* addr, socklen_t* addrlen, int flags) {
#if defined(__i386__)
  unsigned long args[4];
  int r;

  args[0] = (unsigned long) fd;
  args[1] = (unsigned long) addr;
  args[2] = (unsigned long) addrlen;
  args[3] = (unsigned long) flags;

  r = syscall(__NR_socketcall, 18 /* SYS_ACCEPT4 */, args);

  /* socketcall() raises EINVAL when SYS_ACCEPT4 is not supported but so does
   * a bad flags argument. Try to distinguish between the two cases.
   */
  if (r == -1)
    if (errno == EINVAL)
      if ((flags & ~(UV__SOCK_CLOEXEC|UV__SOCK_NONBLOCK)) == 0)
        errno = ENOSYS;

  return r;
#elif defined(__NR_accept4)
  return syscall(__NR_accept4, fd, addr, addrlen, flags);
#else
  return errno = ENOSYS, -1;
#endif
}


int uv__eventfd(unsigned int count) {
#if defined(__NR_eventfd)
  return syscall(__NR_eventfd, count);
#else
  return errno = ENOSYS, -1;
#endif
}


int uv__eventfd2(unsigned int count, int flags) {
#if defined(__NR_eventfd2)
  return syscall(__NR_eventfd2, count, flags);
#else
  return errno = ENOSYS, -1;
#endif
}


int uv__epoll_create(int size) {
#if defined(__NR_epoll_create)
  return syscall(__NR_epoll_create, size);
#else
  return errno = ENOSYS, -1;
#endif
}


int uv__epoll_create1(int flags) {
#if defined(__NR_epoll_create1)
  return syscall(__NR_epoll_create1, flags);
#else
  return errno = ENOSYS, -1;
#endif
}


int uv__epoll_ctl(int epfd, int op, int fd, struct uv__epoll_event* events) {
#if defined(__NR_epoll_ctl)
  return syscall(__NR_epoll_ctl, epfd, op, fd, events);
#else
  return errno = ENOSYS, -1;
#endif
}


int uv__epoll_wait(int epfd,
                   struct uv__epoll_event* events,
                   int nevents,
                   int timeout) {
#if defined(__NR_epoll_wait)
  return syscall(__NR_epoll_wait, epfd, events, nevents, timeout);
#else
  return errno = ENOSYS, -1;
#endif
}


int uv__epoll_pwait(int epfd,
                    struct uv__epoll_event* events,
                    int nevents,
                    int timeout,
                    const sigset_t* sigmask) {
#if defined(__NR_epoll_pwait)
  return syscall(__NR_epoll_pwait,
                 epfd,
                 events,
                 nevents,
                 timeout,
                 sigmask,
                 sizeof(*sigmask));
#else
  return errno = ENOSYS, -1;
#endif
}


int uv__inotify_init(void) {
#if defined(__NR_inotify_init)
  return syscall(__NR_inotify_init);
#else
  return errno = ENOSYS, -1;
#endif
}


int uv__inotify_init1(int flags) {
#if defined(__NR_inotify_init1)
  return syscall(__NR_inotify_init1, flags);
#else
  return errno = ENOSYS, -1;
#endif
}


int uv__inotify_add_watch(int fd, const char* path, uint32_t mask) {
#if defined(__NR_inotify_add_watch)
  return syscall(__NR_inotify_add_watch, fd, path, mask);
#else
  return errno = ENOSYS, -1;
#endif
}


int uv__inotify_rm_watch(int fd, int32_t wd) {
#if defined(__NR_inotify_rm_watch)
  return syscall(__NR_inotify_rm_watch, fd, wd);
#else
  return errno = ENOSYS, -1;
#endif
}


int uv__pipe2(int pipefd[2], int flags) {
#if defined(__NR_pipe2)
  return syscall(__NR_pipe2, pipefd, flags);
#else
  return errno = ENOSYS, -1;
#endif
}


int uv__sendmmsg(int fd,
                 struct uv__mmsghdr* mmsg,
                 unsigned int vlen,
                 unsigned int flags) {
#if defined(__NR_sendmmsg)
  return syscall(__NR_sendmmsg, fd, mmsg, vlen, flags);
#else
  return errno = ENOSYS, -1;
#endif
}


int uv__recvmmsg(int fd,
                 struct uv__mmsghdr* mmsg,
                 unsigned int vlen,
                 unsigned int flags,
                 struct timespec* timeout) {
#if defined(__NR_recvmmsg)
  return syscall(__NR_recvmmsg, fd, mmsg, vlen, flags, timeout);
#else
  return errno = ENOSYS, -1;
#endif
}


int uv__utimesat(int dirfd,
                 const char* path,
                 const struct timespec times[2],
                 int flags)
{
#if defined(__NR_utimensat)
  return syscall(__NR_utimensat, dirfd, path, times, flags);
#else
  return errno = ENOSYS, -1;
#endif
}
