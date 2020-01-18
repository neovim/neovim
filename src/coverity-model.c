// Coverity Scan model
//
// This is a modeling file for Coverity Scan. Modeling helps to avoid false
// positives.
//
// - A model file can't import any header files.
// - Therefore only some built-in primitives like int, char and void are
//   available but not wchar_t, NULL etc.
// - Modeling doesn't need full structs and typedefs. Rudimentary structs
//   and similar types are sufficient.
// - An uninitialized local pointer is not an error. It signifies that the
//   variable could be either NULL or have some data.
//
// Coverity Scan doesn't pick up modifications automatically. The model file
// must be uploaded by an admin in the analysis settings of
// http://scan.coverity.com/projects/neovim-neovim
//

// Issue 105985
//
// Teach coverity that uv_pipe_open saves fd on success (0 return value)
// and doesn't save it on failure (return value != 0).

struct uv_pipe_s {
  int something;
};

int uv_pipe_open(struct uv_pipe_s *handle, int fd)
{
  int result;
  if (result == 0) {
    __coverity_escape__(fd);
  }
  return result;
}

// Hint Coverity that adding item to d avoids losing track
// of the memory allocated for item.
typedef struct {} dictitem_T;
typedef struct {} dict_T;
int tv_dict_add(dict_T *const d, dictitem_T *const item)
{
  __coverity_escape__(item);
}
