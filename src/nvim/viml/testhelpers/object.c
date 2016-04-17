#include <stddef.h>
#include "nvim/viml/testhelpers/object.c.h"
#include "nvim/viml/dumpers/dumpers.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/testhelpers/object.c.generated.h"
#endif

size_t sdump_object_len(const Object o)
{
  return sdump_obj_len(0, o, 0);
}

void sdump_object(const Object o, char **pp)
{
  sdump_obj(0, o, 0, pp);
}

int dump_object(const Object o, Writer write, void *cookie)
{
  return dump_obj(0, o, 0, write, cookie);
}
