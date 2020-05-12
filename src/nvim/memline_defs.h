#ifndef NVIM_MEMLINE_DEFS_H
#define NVIM_MEMLINE_DEFS_H

#include "nvim/memfile_defs.h"

///
/// When searching for a specific line, we remember what blocks in the tree
/// are the branches leading to that block. This is stored in ml_stack.  Each
/// entry is a pointer to info in a block (may be data block or pointer block)
///
typedef struct info_pointer {
  blocknr_T ip_bnum;            // block number
  linenr_T ip_low;              // lowest lnum in this block
  linenr_T ip_high;             // highest lnum in this block
  int ip_index;                 // index for block with current lnum
} infoptr_T;    // block/index pair

typedef struct ml_chunksize {
  int mlcs_numlines;
  long mlcs_totalsize;
} chunksize_T;

// Flags when calling ml_updatechunk()
#define ML_CHNK_ADDLINE 1
#define ML_CHNK_DELLINE 2
#define ML_CHNK_UPDLINE 3

/// memline structure: the contents of a buffer.
/// Essentially a tree with a branch factor of 128.
/// Lines are stored at leaf nodes.
/// Nodes are stored on ml_mfp (memfile_T):
///   pointer_block: internal nodes
///   data_block: leaf nodes
///
/// Memline also has "chunks" of 800 lines that are separate from the 128-tree
/// structure, primarily used to speed up line2byte() and byte2line().
///
/// Motivation: If you have a file that is 10000 lines long, and you insert
///             a line at linenr 1000, you don't want to move 9000 lines in
///             memory.  With this structure it is roughly (N * 128) pointer
///             moves, where N is the height (typically 1-3).
///
typedef struct memline {
  linenr_T ml_line_count;       // number of lines in the buffer

  memfile_T   *ml_mfp;          // pointer to associated memfile

#define ML_EMPTY        1       // empty buffer
#define ML_LINE_DIRTY   2       // cached line was changed and allocated
#define ML_LOCKED_DIRTY 4       // ml_locked was changed
#define ML_LOCKED_POS   8       // ml_locked needs positive block number
  int ml_flags;

  infoptr_T   *ml_stack;        // stack of pointer blocks (array of IPTRs)
  int ml_stack_top;             // current top of ml_stack
  int ml_stack_size;            // total number of entries in ml_stack

  linenr_T ml_line_lnum;        // line number of cached line, 0 if not valid
  char_u      *ml_line_ptr;     // pointer to cached line

  bhdr_T      *ml_locked;       // block used by last ml_get
  linenr_T ml_locked_low;       // first line in ml_locked
  linenr_T ml_locked_high;      // last line in ml_locked
  int ml_locked_lineadd;        // number of lines inserted in ml_locked
  chunksize_T *ml_chunksize;
  int ml_numchunks;
  int ml_usedchunks;
} memline_T;

#endif // NVIM_MEMLINE_DEFS_H
