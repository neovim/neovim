#pragma once

#include <stddef.h>  // IWYU pragma: keep

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"  // IWYU pragma: keep
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/garray_defs.h"
#include "nvim/option_defs.h"  // IWYU pragma: keep
#include "nvim/pos_defs.h"  // IWYU pragma: keep
#include "nvim/runtime_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// Stack of execution contexts.  Each entry is an estack_T.
/// Current context is at ga_len - 1.
extern garray_T exestack;
/// name of error message source
#define SOURCING_NAME (((estack_T *)exestack.ga_data)[exestack.ga_len - 1].es_name)
/// line number in the message source or zero
#define SOURCING_LNUM (((estack_T *)exestack.ga_data)[exestack.ga_len - 1].es_lnum)

/// Growarray to store info about already sourced scripts.
extern garray_T script_items;
#define SCRIPT_ITEM(id) (((scriptitem_T **)script_items.ga_data)[(id) - 1])
#define SCRIPT_ID_VALID(id) ((id) > 0 && (id) <= script_items.ga_len)

/// last argument for do_source()
enum {
  DOSO_NONE = 0,
  DOSO_VIMRC = 1,  ///< loading vimrc file
};

/// Used for flags in do_in_path()
enum {
  DIP_ALL     = 0x01,   ///< all matches, not just the first one
  DIP_DIR     = 0x02,   ///< find directories instead of files
  DIP_ERR     = 0x04,   ///< give an error message when none found
  DIP_START   = 0x08,   ///< also use "start" directory in 'packpath'
  DIP_OPT     = 0x10,   ///< also use "opt" directory in 'packpath'
  DIP_NORTP   = 0x20,   ///< do not use 'runtimepath'
  DIP_NOAFTER = 0x40,   ///< skip "after" directories
  DIP_AFTER   = 0x80,   ///< only use "after" directories
  DIP_DIRFILE = 0x200,  ///< find both files and directories
};

#include "runtime.h.generated.h"
