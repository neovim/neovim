#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/map_defs.h"

/// A block number.
///
/// Blocks numbered from 0 upwards have been assigned a place in the actual
/// file. The block number is equal to the page number in the file. The blocks
/// with negative numbers are currently in memory only.
typedef int64_t blocknr_T;

/// A block header.
///
/// There is a block header for each previously used block in the memfile.
///
/// The block may be linked in the used list OR in the free list.
///
/// The used list is a doubly linked list, most recently used block first.
/// The blocks in the used list have a block of memory allocated.
/// The free list is a single linked list, not sorted.
/// The blocks in the free list have no block of memory allocated and
/// the contents of the block in the file (if any) is irrelevant.
typedef struct {
  blocknr_T bh_bnum;                 ///< key used in hash table

  void *bh_data;                     ///< pointer to memory (for used block)
  unsigned bh_page_count;            ///< number of pages in this block

#define BH_DIRTY    1U
#define BH_LOCKED   2U
  unsigned bh_flags;                 ///< BH_DIRTY or BH_LOCKED
} bhdr_T;

typedef enum {
  MF_DIRTY_NO = 0,      ///< no dirty blocks
  MF_DIRTY_YES,         ///< there are dirty blocks
  MF_DIRTY_YES_NOSYNC,  ///< there are dirty blocks, do not sync yet
} mfdirty_T;

/// A memory file.
typedef struct {
  char *mf_fname;                    ///< name of the file
  char *mf_ffname;                   ///< idem, full path
  int mf_fd;                         ///< file descriptor
  int mf_flags;                      ///< flags used when opening this memfile
  bool mf_reopen;                    ///< mf_fd was closed, retry opening
  bhdr_T *mf_free_first;             ///< first block header in free list

  /// The used blocks are kept in mf_hash.
  /// mf_hash are used to quickly find a block in the used list.
  PMap(int64_t) mf_hash;

  /// When a block with a negative number is flushed to the file, it gets
  /// a positive number. Because the reference to the block is still the negative
  /// number, we remember the translation to the new positive number.
  Map(int64_t, int64_t) mf_trans;

  blocknr_T mf_blocknr_max;          ///< highest positive block number + 1
  blocknr_T mf_blocknr_min;          ///< lowest negative block number - 1
  blocknr_T mf_neg_count;            ///< number of negative blocks numbers
  blocknr_T mf_infile_count;         ///< number of pages in the file
  unsigned mf_page_size;             ///< number of bytes in a page
  mfdirty_T mf_dirty;
} memfile_T;
