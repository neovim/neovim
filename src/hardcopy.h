#ifndef NEOVIM_HARDCOPY_H
#define NEOVIM_HARDCOPY_H

/*
 * Structure to hold printing color and font attributes.
 */
typedef struct {
  long_u fg_color;
  long_u bg_color;
  int bold;
  int italic;
  int underline;
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
  long number;
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

char_u *parse_printoptions(void);
char_u *parse_printmbfont(void);
int prt_header_height(void);
int prt_use_number(void);
int prt_get_unit(int idx);
void ex_hardcopy(exarg_T *eap);
void mch_print_cleanup(void);
int mch_print_init(prt_settings_T *psettings, char_u *jobname,
                   int forceit);
int mch_print_begin(prt_settings_T *psettings);
void mch_print_end(prt_settings_T *psettings);
int mch_print_end_page(void);
int mch_print_begin_page(char_u *str);
int mch_print_blank_page(void);
void mch_print_start_line(int margin, int page_line);
int mch_print_text_out(char_u *p, int len);
void mch_print_set_font(int iBold, int iItalic, int iUnderline);
void mch_print_set_bg(long_u bgcol);
void mch_print_set_fg(long_u fgcol);
/* vim: set ft=c : */
#endif /* NEOVIM_HARDCOPY_H */
