#ifndef NVIM_GETCHAR_H
#define NVIM_GETCHAR_H

/* Values for "noremap" argument of ins_typebuf().  Also used for
 * map->m_noremap and menu->noremap[]. */
#define REMAP_YES       0       /* allow remapping */
#define REMAP_NONE      -1      /* no remapping */
#define REMAP_SCRIPT    -2      /* remap script-local mappings only */
#define REMAP_SKIP      -3      /* no remapping for first char */

#define KEYLEN_PART_KEY -1      /* keylen value for incomplete key-code */
#define KEYLEN_PART_MAP -2      /* keylen value for incomplete mapping */
#define KEYLEN_REMOVED  9999    /* keylen value for removed sequence */

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "getchar.h.generated.h"
#endif
#endif  // NVIM_GETCHAR_H
