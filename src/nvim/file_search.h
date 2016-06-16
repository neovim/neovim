#ifndef NVIM_FILE_SEARCH_H
#define NVIM_FILE_SEARCH_H

#include "nvim/os/fs_defs.h"

/* Flags for find_file_*() functions. */
#define FINDFILE_FILE   0       /* only files */
#define FINDFILE_DIR    1       /* only directories */
#define FINDFILE_BOTH   2       /* files and directories */

/* Number of levels to descend into the directory tree */
#define LEVELS 100

/*
 * type for the directory search stack
 */
typedef struct ff_stack {
  struct ff_stack     *ffs_prev;

  /* the fix part (no wildcards) and the part containing the wildcards
   * of the search path
   */
  char_u              *ffs_fix_path;
  char_u              *ffs_wc_path;

  /* files/dirs found in the above directory, matched by the first wildcard
   * of wc_part
   */
  char_u              **ffs_filearray;
  int ffs_filearray_size;
  char_u ffs_filearray_cur;                  /* needed for partly handled dirs */

  /* to store status of partly handled directories
   * 0: we work on this directory for the first time
   * 1: this directory was partly searched in an earlier step
   */
  int ffs_stage;

  /* How deep are we in the directory tree?
   * Counts backward from value of level parameter to vim_findfile_init
   */
  int ffs_level;

  /* Did we already expand '**' to an empty string? */
  int ffs_star_star_empty;
} ff_stack_T;

/*
 * type for already visited directories or files.
 */
typedef struct ff_visited {
  struct ff_visited   *ffv_next;

  /* Visited directories are different if the wildcard string are
   * different. So we have to save it.
   */
  char_u              *ffv_wc_path;
  // use FileID for comparison (needed because of links), else use filename.
  bool file_id_valid;
  FileID file_id;
  /* The memory for this struct is allocated according to the length of
   * ffv_fname.
   */
  char_u ffv_fname[1];                  /* actually longer */
} ff_visited_T;

/*
 * We might have to manage several visited lists during a search.
 * This is especially needed for the tags option. If tags is set to:
 *      "./++/tags,./++/TAGS,++/tags"  (replace + with *)
 * So we have to do 3 searches:
 *   1) search from the current files directory downward for the file "tags"
 *   2) search from the current files directory downward for the file "TAGS"
 *   3) search from Vims current directory downwards for the file "tags"
 * As you can see, the first and the third search are for the same file, so for
 * the third search we can use the visited list of the first search. For the
 * second search we must start from an empty visited list.
 * The struct ff_visited_list_hdr is used to manage a linked list of already
 * visited lists.
 */
typedef struct ff_visited_list_hdr {
  struct ff_visited_list_hdr  *ffvl_next;

  /* the filename the attached visited list is for */
  char_u                      *ffvl_filename;

  ff_visited_T                *ffvl_visited_list;

} ff_visited_list_hdr_T;


/*
 * '**' can be expanded to several directory levels.
 * Set the default maximum depth.
 */
#define FF_MAX_STAR_STAR_EXPAND ((char_u)30)

/*
 * The search context:
 *   ffsc_stack_ptr:	the stack for the dirs to search
 *   ffsc_visited_list: the currently active visited list
 *   ffsc_dir_visited_list: the currently active visited list for search dirs
 *   ffsc_visited_lists_list: the list of all visited lists\
 *   ffsc_dir_visited_lists_list: the list of all visited lists for search dirs
 *   ffsc_file_to_search:     the file to search for
 *   ffsc_start_dir:	the starting directory, if search path was relative
 *   ffsc_fix_path:	the fix part of the given path (without wildcards)
 *			Needed for upward search.
 *   ffsc_wc_path:	the part of the given path containing wildcards
 *   ffsc_level:	how many levels of dirs to search downwards
 *   ffsc_stopdirs_v:	array of stop directories for upward search
 *   ffsc_find_what:	FINDFILE_BOTH, FINDFILE_DIR or FINDFILE_FILE
 *   ffsc_tagfile:	searching for tags file, don't use 'suffixesadd'
 */
typedef struct ff_search_ctx_T {
  ff_stack_T                 *ffsc_stack_ptr;
  ff_visited_list_hdr_T      *ffsc_visited_list;
  ff_visited_list_hdr_T      *ffsc_dir_visited_list;
  ff_visited_list_hdr_T      *ffsc_visited_lists_list;
  ff_visited_list_hdr_T      *ffsc_dir_visited_lists_list;
  char_u                     *ffsc_file_to_search;
  char_u                     *ffsc_start_dir;
  char_u                     *ffsc_fix_path;
  char_u                     *ffsc_wc_path;
  int ffsc_level;
  char_u                     **ffsc_stopdirs_v;
  int ffsc_find_what;
  int ffsc_tagfile;
} ff_search_ctx_T;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "file_search.h.generated.h"
#endif
#endif  // NVIM_FILE_SEARCH_H
