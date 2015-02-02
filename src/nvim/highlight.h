#ifndef NVIM_HIGHLIGHT_H
#define NVIM_HIGHLIGHT_H

/*
 * Terminal highlighting attribute bits.
 */
#define HL_NORMAL      0x00
#define HL_INVERSE     0x01
#define HL_BOLD        0x02
#define HL_ITALIC      0x04
#define HL_UNDERLINE   0x08
#define HL_UNDERCURL   0x10
#define HL_STANDOUT    0x20
#define HL_ALL         0x3f

/*
 * An attribute number is the index in attr_table plus ATTR_OFF.
 */
#define ATTR_OFF (HL_ALL + 1)


typedef struct {
  char *name;
  RgbValue color;
} color_name_table_T;
extern color_name_table_T color_name_table[];

// TODO: these below should not be exported, refactor affected code in syntax.h instead

/*
 * Structure that stores information about a highlight group.
 * The ID of a highlight group is also called group ID.  It is the index in
 * the highlight_ga array PLUS ONE.
 */
struct hl_group {
  char_u      *sg_name;         /* highlight group name */
  char_u      *sg_name_u;       /* uppercase of sg_name */
  /* for normal terminals */
  int sg_term;                  /* "term=" highlighting attributes */
  char_u      *sg_start;        /* terminal string for start highl */
  char_u      *sg_stop;         /* terminal string for stop highl */
  int sg_term_attr;             /* Screen attr for term mode */
  /* for color terminals */
  int sg_cterm;                 /* "cterm=" highlighting attr */
  int sg_cterm_bold;            /* bold attr was set for light color */
  int sg_cterm_fg;              /* terminal fg color number + 1 */
  int sg_cterm_bg;              /* terminal bg color number + 1 */
  int sg_cterm_attr;            /* Screen attr for color term mode */
  /* Store the sp color name for the GUI or synIDattr() */
  int sg_gui;                   /* "gui=" highlighting attributes */
  RgbValue sg_rgb_fg;           // RGB foreground color
  RgbValue sg_rgb_bg;           // RGB background color
  uint8_t *sg_rgb_fg_name;      // RGB foreground color name
  uint8_t *sg_rgb_bg_name;      // RGB background color name
  int sg_link;                  /* link to this highlight group ID */
  int sg_set;                   /* combination of SG_* flags */
  scid_T sg_scriptID;           /* script in which the group was last set */
};

// highlight groups for 'highlight' option
garray_T highlight_ga;

#define HL_TABLE() ((struct hl_group *)((highlight_ga.ga_data)))
#define MAX_HL_ID       20000   /* maximum value for a highlight ID. */

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "highlight.h.generated.h"
#endif

#endif  // NVIM_HIGHLIGHT_H
