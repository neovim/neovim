#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "api/helpers.h"
#include "api/defs.h"
#include "../vim.h"

void try_start()
{
  ++trylevel;
}

bool try_end(Error *err)
{
  --trylevel;

  // Without this it stops processing all subsequent VimL commands and
  // generates strange error messages if I e.g. try calling Test() in a
  // cycle
  did_emsg = false;

  if (got_int) {
    if (did_throw) {
      // If we got an interrupt, discard the current exception 
      discard_current_exception();
    }

    set_api_error("Keyboard interrupt", err);
    got_int = false;
  } else if (msg_list != NULL && *msg_list != NULL) {
    int should_free;
    char *msg = (char *)get_exception_string(*msg_list,
                                             ET_ERROR,
                                             NULL,
                                             &should_free);
    strncpy(err->msg, msg, sizeof(err->msg));
    err->set = true;
    free_global_msglist();

    if (should_free) {
      free(msg);
    }
  } else if (did_throw) {
    set_api_error((char *)current_exception->value, err);
  }

  return err->set;
}

