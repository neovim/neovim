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

void *malloc(size_t size)
{
  int has_mem;
  if (has_mem)
    return __coverity_alloc__(size);
  else
    return 0;
}

void *try_malloc(size_t size)
{
  size_t allocated_size = size ? size : 1;
  return malloc(allocated_size);
}

void *xmalloc(size_t size)
{
  void *p = malloc(size);
  if (!p)
    __coverity_panic__();
  return p;
}

void xfree(void * ptr)
{
  __coverity_free__(ptr);
}

void *xcalloc(size_t count, size_t size)
{
  size_t allocated_count = count && size ? count : 1;
  size_t allocated_size = count && size ? size : 1;
  void *p = try_malloc(allocated_count * allocated_size);
  if (!p)
    __coverity_panic__();
  __coverity_writeall0__(p);
  return p;
}

void *xrealloc(void *ptr, size_t size)
{
  __coverity_escape__(ptr);
  void * p = xmalloc(size);
  __coverity_writeall__(p);
  return p;
}

void *xmallocz(size_t size)
{
  void * p = malloc(size + 1);
  ((char*)p)[size] = 0;
  return p;
}

void * xmemdupz(const void * data, size_t len)
{
  void * p = xmallocz(len);
  __coverity_writeall__(p);
  ((char*)p)[len] = 0;
  return p;
}

void * xmemdup(const void *data, size_t len)
{
  void * p = xmalloc(len);
  __coverity_writeall__(p);
  return p;
}

// Teach coverity that lua errors are noreturn

typedef struct {} lua_State;

int luaL_typerror(lua_State *L, int narg, const char *tname)
{
  __coverity_panic__();
  return 0;
}

int luaL_error(lua_State *L, const char *fmt, ...)
{
  __coverity_panic__();
  return 0;
}

int luaL_argerror(lua_State *L, int numarg, const char *extramsg)
{
  __coverity_panic__();
  return 0;
}

void *luaL_checkudata(lua_State *L, int ud, const char *tname)
{
  return __coverity_alloc_nosize__()
}

