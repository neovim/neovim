// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// @file scriptfile.c
///
/// functions for dealing with the runtime directories/files

#include "nvim/scriptfile.h"
#include "nvim/vim.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "scriptfile.c.generated.h"
#endif

// Initialize the execution stack.
void estack_init(void)
{
  estack_T *entry;

  ga_grow(&exestack, 10);
  entry = ((estack_T *)exestack.ga_data) + exestack.ga_len;
  entry->es_type = ETYPE_TOP;
  entry->es_name = NULL;
  entry->es_lnum = 0;
  entry->es_info.ufunc = NULL;
  exestack.ga_len++;
}

// Add an item to the execution stack.
// Returns the new entry or NULL when out of memory.
estack_T *estack_push(etype_T type, char_u *name, long lnum)
{
  estack_T *entry;

  ga_grow(&exestack, 1);
  entry = ((estack_T *)exestack.ga_data) + exestack.ga_len;
  entry->es_type = type;
  entry->es_name = name;
  entry->es_lnum = lnum;
  entry->es_info.ufunc = NULL;
  exestack.ga_len++;
  return entry;
}

// Add a user function to the execution stack.
void estack_push_ufunc(etype_T type, ufunc_T *ufunc, long lnum)
{
  estack_T *entry
      = estack_push(type, ufunc->uf_name_exp != NULL ? ufunc->uf_name_exp : ufunc->uf_name, lnum);
  if (entry != NULL) {
    entry->es_info.ufunc = ufunc;
  }
}

// Take an item off of the execution stack.
void estack_pop(void)
{
  if (exestack.ga_len > 1) {
    exestack.ga_len--;
  }
}

// Get the current value for <sfile> in allocated memory.
char_u *estack_sfile(void)
{
  size_t len;
  int idx;
  estack_T *entry;
  char *res;
  size_t done;

  entry = ((estack_T *)exestack.ga_data) + exestack.ga_len - 1;
  if (entry->es_name == NULL) {
    return NULL;
  }
  if (entry->es_info.ufunc == NULL) {
    return vim_strsave(entry->es_name);
  }

  // For a function we compose the call stack, as it was done in the past:
  //   "function One[123]..Two[456]..Three"
  len = STRLEN(entry->es_name) + 10;
  for (idx = exestack.ga_len - 2; idx >= 0; idx--) {
    entry = ((estack_T *)exestack.ga_data) + idx;
    if (entry->es_name == NULL || entry->es_info.ufunc == NULL) {
      idx++;
      break;
    }
    len += STRLEN(entry->es_name) + 15;
  }

  res = (char *)xmalloc(len);
  if (res != NULL) {
    STRCPY(res, "function ");
    while (idx < exestack.ga_len - 1) {
      done = STRLEN(res);
      entry = ((estack_T *)exestack.ga_data) + idx;
      vim_snprintf(res + done, len - done, "%s[%ld]..", entry->es_name, entry->es_lnum);
      idx++;
    }
    done = STRLEN(res);
    entry = ((estack_T *)exestack.ga_data) + idx;
    vim_snprintf(res + done, len - done, "%s", entry->es_name);
  }
  return (char_u *)res;
}
