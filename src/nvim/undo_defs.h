#pragma once

#include <time.h>

#include "nvim/extmark_defs.h"
#include "nvim/mark_defs.h"

enum { UNDO_HASH_SIZE = 32, };  ///< Size in bytes of the hash used in the undo file.

typedef struct u_header u_header_T;

/// Structure to store info about the Visual area.
typedef struct {
  pos_T vi_start;       ///< start pos of last VIsual
  pos_T vi_end;         ///< end position of last VIsual
  int vi_mode;          ///< VIsual_mode of last VIsual
  colnr_T vi_curswant;  ///< MAXCOL from w_curswant
} visualinfo_T;

// One line saved for undo.
typedef struct {
  char *ul_line;  // text of the line
  size_t ul_len;  // length of the line including NUL
} undoline_T;

typedef struct u_entry u_entry_T;
struct u_entry {
  u_entry_T *ue_next;  ///< pointer to next entry in list
  linenr_T ue_top;     ///< number of line above undo block
  linenr_T ue_bot;     ///< number of line below undo block
  linenr_T ue_lcount;  ///< linecount when u_save called
  undoline_T *ue_array;  ///< array of lines in undo block
  linenr_T ue_size;    ///< number of lines in ue_array
#ifdef U_DEBUG
  int ue_magic;        ///< magic number to check allocation
#endif
};

struct u_header {
  // The following have a pointer and a number. The number is used when reading
  // the undo file in u_read_undo()
  union {
    u_header_T *ptr;              ///< pointer to next undo header in list
    int seq;
  } uh_next;
  union {
    u_header_T *ptr;              ///< pointer to previous header in list
    int seq;
  } uh_prev;
  union {
    u_header_T *ptr;              ///< pointer to next header for alt. redo
    int seq;
  } uh_alt_next;
  union {
    u_header_T *ptr;              ///< pointer to previous header for alt. redo
    int seq;
  } uh_alt_prev;
  int uh_seq;                     ///< sequence number, higher == newer undo
  int uh_walk;                    ///< used by undo_time()
  u_entry_T *uh_entry;            ///< pointer to first entry
  u_entry_T *uh_getbot_entry;     ///< pointer to where ue_bot must be set
  pos_T uh_cursor;                ///< cursor position before saving
  colnr_T uh_cursor_vcol;
  int uh_flags;                   ///< see below
  fmark_T uh_namedm[NMARKS];      ///< marks before undo/after redo
  extmark_undo_vec_t uh_extmark;  ///< info to move extmarks
  visualinfo_T uh_visual;         ///< Visual areas before undo/after redo
  time_t uh_time;                 ///< timestamp when the change was made
  int uh_save_nr;                 ///< set when the file was saved after the
                                  ///< changes in this block
#ifdef U_DEBUG
  int uh_magic;                   ///< magic number to check allocation
#endif
};

/// values for uh_flags
enum {
  UH_CHANGED  = 0x01,  ///< b_changed flag before undo/after redo
  UH_EMPTYBUF = 0x02,  ///< buffer was empty
  UH_RELOAD   = 0x04,  ///< buffer was reloaded
};
