/**
 *  This is syntentic example for proof-of-concept demonstration. This is a
 *  part of nvim/api/biffer.c.
 */

#include "nvim/api/buffer.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"
#include "nvim/vim.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/misc1.h"
#include "nvim/ex_cmds.h"
#include "nvim/mark.h"
#include "nvim/fileio.h"
#include "nvim/move.h"
#include "nvim/syntax.h"
#include "nvim/window.h"
#include "nvim/undo.h"
#include "nvim/ex_docmd.h"
#include "nvim/buffer_updates.h"

#include "nvim/func_attr.h"

Integer nvim_buf_line_count(Buffer buffer, Error *err)
  FUNC_API_SINCE(1)
{
  return NULL;
}

Integer nvim_buf_line_count_not_rpc(Buffer buffer, Error *err) {
  return NULL;
}
