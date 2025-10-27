// tee.c - pipe fitting
//
//      Copyright (c) 1996, Paul Slootman
//
//      Author: Paul Slootman
//                      (paul@wurtel.hobby.nl, paul@murphy.nl, paulS@toecompst.nl)
//      Modifications for MSVC: Yasuhiro Matsumoto
//      Modifications for Neovim: https://github.com/neovim/neovim/pull/36363
//
//      This source code is released into the public domain. It is provided on an
//      as-is basis and no responsibility is accepted for its failure to perform
//      as expected. It is worth at least as much as you paid for it!
//
//
// tee reads stdin, and writes what it reads to each of the specified
// files. The primary reason of existence for this version is a quick
// and dirty implementation to distribute with Vim, to make one of the
// most useful features of Vim possible on OS/2: quickfix.
//
// Of course, not using tee but instead redirecting make's output directly
// into a temp file and then processing that is possible, but if we have a
// system capable of correctly piping (unlike DOS, for example), why not
// use it as well as possible? This tee should also work on other systems,
// but it's not been tested there, only on OS/2.
//
// tee is also available in the GNU shellutils package, which is available
// precompiled for OS/2. That one probably works better.

#ifndef _MSC_VER
# include <unistd.h>
#endif
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
# define sysconf(x) - 1
#endif

void usage(void)
{
  fprintf(stderr,
          "Neotee: a web-scale fork of tee\n"
          "Usage:\n"
          "\ttee [-a] file ... file_n\n"
          "\n"
          "\t-a\tappend to files instead of truncating\n"
          "\n"
          "Tee reads its input, and writes to each of the specified files,\n"
          "as well as to the standard output.\n"
          "\n"
          "Shipped with Nvim 0.12+ for use with :make, :grep, :!, etc.\n");
}

int main(int argc, char *argv[])
{
  int append = 0;
  size_t numfiles;
  int maxfiles;
  FILE **filepointers;
  int i;
  char buf[65536];
  int n;
  int optnr = 1;

  for (i = 1; i < argc; i++) {
    if (argv[i][0] != '-') {
      break;
    }
    if (!strcmp(argv[i], "-a")) {
      append++;
    } else {
      usage();
      exit(2);
    }
    optnr++;
  }

  numfiles = argc - optnr;

  if (numfiles == 0) {
    usage();
    exit(2);
  }

  maxfiles = sysconf(_SC_OPEN_MAX);       // or fill in 10 or so
  if (maxfiles < 0) {
    maxfiles = 10;
  }
  if (numfiles + 3 > maxfiles) {  // +3 accounts for stdin, out, err
    fprintf(stderr, "There is a limit of max %d files.\n", maxfiles - 3);
    exit(1);
  }
  filepointers = calloc(numfiles, sizeof(FILE *));  // NOLINT
  if (filepointers == NULL) {
    fprintf(stderr, "Error allocating memory for %ld files\n", (long)numfiles);
    exit(1);
  }
  for (i = 0; i < numfiles; i++) {
    filepointers[i] = fopen(argv[i + optnr], append ? "ab" : "wb");
    if (filepointers[i] == NULL) {
      fprintf(stderr, "Can't open \"%s\"\n", argv[i + optnr]);
      exit(1);
    }
  }
#ifdef _WIN32
  setmode(fileno(stdin),  O_BINARY);
  fflush(stdout);  // needed for _fsetmode(stdout)
  setmode(fileno(stdout),  O_BINARY);
  setvbuf(stdout, NULL, _IONBF, 0);  // unbuffered for immediate output
#endif

  while ((n = fread(buf, 1, sizeof(buf), stdin)) > 0) {
    fwrite(buf, 1, n, stdout);
    for (i = 0; i < numfiles; i++) {
      if (filepointers[i]) {
        fwrite(buf, 1, n, filepointers[i]);
      }
    }
    fflush(stdout);
  }
  for (i = 0; i < numfiles; i++) {
    if (filepointers[i]) {
      fclose(filepointers[i]);
    }
  }

  exit(0);
}
