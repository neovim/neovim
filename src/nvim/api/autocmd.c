#include <stdbool.h>

#include "nvim/api/autocmd.h"
#include "nvim/api/private/helpers.h"
#include "nvim/autocmd.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/autocmd.c.generated.h"
#endif

Array nvim_get_autocmds(Dictionary opts, Error *err)
  FUNC_API_SINCE(7)
{
  Array autocmd_list = ARRAY_DICT_INIT;

  Array group_filter = ARRAY_DICT_INIT;
  Array event_filter = ARRAY_DICT_INIT;

  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object *v = &opts.items[i].value;

    if (strequal("groups", k.data)) {
      // TODO: Populate groups from the group filter
    }

  }

  FOR_ALL_AUEVENTS(event) {
    AutoPat* ap = au_get_autopat_for_event(event);

    if (ap == NULL || ap->cmds == NULL) {
      continue;
    }

    // Important values:
    // ap->group
    // ap->buflocalnr (could use to filter only to buffer local autocmds)
    //
    // ap->pat (potentially look at the pattern as well)

    for (AutoCmd *ac = ap->cmds; ac != NULL; ac = ac->next) {
      // TODO: Check the group_filter to see if the current group should be accepted.

      Dictionary autocmd_info = ARRAY_DICT_INIT;

      // TODO: You don't actually want to send the integer group,
      // you want to send a string name of the group, so it's useful to people.
      PUT(autocmd_info, "group", INTEGER_OBJ(ap->group));
      PUT(autocmd_info, "once", BOOLEAN_OBJ(ac->once));
      PUT(autocmd_info, "cmd", STRING_OBJ(cstr_as_string((char *)ac->cmd)));

      ADD(autocmd_list, DICTIONARY_OBJ(autocmd_info));
    }
  }

  return autocmd_list;
}
