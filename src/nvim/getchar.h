#ifndef NVIM_GETCHAR_H
#define NVIM_GETCHAR_H

#include "nvim/types.h"
#include "nvim/buffer_defs.h"
#include "nvim/ex_cmds_defs.h"

/* Values for "noremap" argument of ins_typebuf().  Also used for
 * map->m_noremap and menu->noremap[]. */
#define REMAP_YES       0       /* allow remapping */
#define REMAP_NONE      -1      /* no remapping */
#define REMAP_SCRIPT    -2      /* remap script-local mappings only */
#define REMAP_SKIP      -3      /* no remapping for first char */

#define KEYLEN_PART_KEY -1      /* keylen value for incomplete key-code */
#define KEYLEN_PART_MAP -2      /* keylen value for incomplete mapping */
#define KEYLEN_REMOVED  9999    /* keylen value for removed sequence */

typedef enum { PART_KEY, PART_MAP, NO_MAP } map_type;
typedef enum { FOUND_CHAR, NEED_MORE_BYTES, EXPANDED_MAPPING } typebuf_action;
typedef struct {
  typebuf_action action;
  map_type mapt;
  int c;
} typebuf_ret;

typedef struct {
  int8_t control_id;
  int c;
  bool timedout;
  bool mode_deleted;
} user_ret;

typedef struct {
  mapblock_T *mp;
  bool part_map;
} find_map_ret;
#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "getchar.h.generated.h"
#endif
#endif  // NVIM_GETCHAR_H
