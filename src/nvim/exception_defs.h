#ifndef NVIM_EXCEPTION_DEFS_H
#define NVIM_EXCEPTION_DEFS_H

#include "nvim/pos.h"           // for linenr_T
#include "nvim/types.h"

// A list of error messages that can be converted to an exception.  "throw_msg"
// is only set in the first element of the list.  Usually, it points to the
// original message stored in that element, but sometimes it points to a later
// message in the list.  See cause_errthrow() below.
struct msglist {
  char *msg;             // original message
  char *throw_msg;       // msg to throw: usually original one
  struct msglist *next;            // next of several messages in a row
};

// The exception types.
typedef enum
{
  ET_USER,       // exception caused by ":throw" command
  ET_ERROR,      // error exception
  ET_INTERRUPT,  // interrupt exception triggered by Ctrl-C
} except_type_T;

// Structure describing an exception.
// (don't use "struct exception", it's used by the math library).
typedef struct vim_exception except_T;
struct vim_exception {
  except_type_T type;                   // exception type
  char *value;           // exception value
  struct msglist *messages;        // message(s) causing error exception
  char_u *throw_name;      // name of the throw point
  linenr_T throw_lnum;                  // line number of the throw point
  except_T *caught;          // next exception on the caught stack
};

// Structure to save the error/interrupt/exception state between calls to
// enter_cleanup() and leave_cleanup().  Must be allocated as an automatic
// variable by the (common) caller of these functions.
typedef struct cleanup_stuff cleanup_T;
struct cleanup_stuff {
  int pending;                  // error/interrupt/exception state
  except_T *exception;          // exception value
};

#endif  // NVIM_EXCEPTION_DEFS_H
