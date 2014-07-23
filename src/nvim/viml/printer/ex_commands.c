#include <stdbool.h>
#include <stddef.h>

#include "nvim/viml/printer/printer.h"

#include "nvim/viml/printer/ex_commands.c.h"
#include "nvim/viml/dumpers/dumpers.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/printer/ex_commands.c.generated.h"
#endif

void sprint_cmd(const StyleOptions *const po, const CommandNode *node,
                char **pp)
  FUNC_ATTR_NONNULL_ALL
{
  sprint_node(po, node, 0, false, pp);
}

size_t sprint_cmd_len(const StyleOptions *const po, const CommandNode *node)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_CONST
{
  return sprint_node_len(po, node, 0, false);
}

int print_cmd(const StyleOptions *const po, const CommandNode *node,
              Writer write, void *cookie)
{
  return print_node(po, node, 0, false, write, cookie);
}
