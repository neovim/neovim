#ifndef NVIM_HARDCOPY_H
#define NVIM_HARDCOPY_H

#include <stdint.h>
#include <stdlib.h>  // for size_t

#include "nvim/globals.h"  // for TriState
#include "nvim/types.h"  // for char_u
#include "nvim/ex_cmds_defs.h"  // for exarg_T

/*
 * Structure to hold printing color and font attributes.
 */
typedef struct {
  uint32_t fg_color;
  uint32_t bg_color;
  TriState bold;
  TriState italic;
  TriState underline;
  int undercurl;
} prt_text_attr_T;

/*
 * Structure passed back to the generic printer code.
 */
typedef struct {
  int n_collated_copies;
  int n_uncollated_copies;
  int duplex;
  int chars_per_line;
  int lines_per_page;
  int has_color;
  prt_text_attr_T number;
  int modec;
  int do_syntax;
  int user_abort;
  char_u      *jobname;
  char_u      *outfile;
  char_u      *arguments;
} prt_settings_T;

/*
 * Generic option table item, only used for printer at the moment.
 */
typedef struct {
  const char  *name;
  int hasnum;
  int number;
  char_u      *string;          /* points into option string */
  int strlen;
  int present;
} option_table_T;

#define OPT_PRINT_TOP          0
#define OPT_PRINT_BOT          1
#define OPT_PRINT_LEFT         2
#define OPT_PRINT_RIGHT        3
#define OPT_PRINT_HEADERHEIGHT 4
#define OPT_PRINT_SYNTAX       5
#define OPT_PRINT_NUMBER       6
#define OPT_PRINT_WRAP         7
#define OPT_PRINT_DUPLEX       8
#define OPT_PRINT_PORTRAIT     9
#define OPT_PRINT_PAPER        10
#define OPT_PRINT_COLLATE      11
#define OPT_PRINT_JOBSPLIT     12
#define OPT_PRINT_FORMFEED     13
#define OPT_PRINT_NUM_OPTIONS  14

/* For prt_get_unit(). */
#define PRT_UNIT_NONE  -1
#define PRT_UNIT_PERC  0
#define PRT_UNIT_INCH  1
#define PRT_UNIT_MM    2
#define PRT_UNIT_POINT 3
#define PRT_UNIT_NAMES {"pc", "in", "mm", "pt"}

#define PRINT_NUMBER_WIDTH 8


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "hardcopy.h.generated.h"
#endif
#endif  // NVIM_HARDCOPY_H
