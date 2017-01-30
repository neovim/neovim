//Copyright 2011 Martin T. Sandsmark <sandsmark@samfundet.no>
//Redistribution and use in source and binary forms, with or without
//modification, are permitted provided that the following conditions
//are met:
//
//1. Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
//2. Redistributions in binary form must reproduce the above copyright
//   notice, this list of conditions and the following disclaimer in the
//   documentation and/or other materials provided with the distribution.
//
//THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
//IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
//IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
//INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
//NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
//THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#ifndef NVIM_OS_WINDEP_WINDOW_UTSNAME_H
#define NVIM_OS_WINDEP_WINDOW_UTSNAME_H

#include "nvim/vim.h"

#define WINDOWS "Windows"
#define AMD64   "x86_64"
#define IA64    "ia64"
#define INTEL   "x86"
#define UNkNOWN "unknown"

#define WINDOW_UTSNAME_LENGTH 256

struct w_utsname {
  char sysname[WINDOW_UTSNAME_LENGTH];
  char nodename[WINDOW_UTSNAME_LENGTH];
  char release[WINDOW_UTSNAME_LENGTH];
  char version[WINDOW_UTSNAME_LENGTH];
  char machine[WINDOW_UTSNAME_LENGTH];
};

int w_uname(struct w_utsname *name);

#endif  //NVIM_OS_WINDEP_WINDOW_UTSNAME_H
