#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static char_u *parse_list_options(char_u *option_str, option_table_T *table, int table_size);
static long_u darken_rgb(long_u rgb);
static long_u prt_get_term_color(int colorindex);
static void prt_get_attr(int hl_id, prt_text_attr_T *pattr, int modec);
static void prt_set_fg(long_u fg);
static void prt_set_bg(long_u bg);
static void prt_set_font(int bold, int italic, int underline);
static void prt_line_number(prt_settings_T *psettings, int page_line, linenr_T lnum);
static void prt_header(prt_settings_T *psettings, int pagenum, linenr_T lnum);
static void prt_message(char_u *s);
static colnr_T hardcopy_line(prt_settings_T *psettings, int page_line, prt_pos_T *ppos);
static void prt_write_file_raw_len(char_u *buffer, int bytes);
static void prt_write_file(char_u *buffer);
static void prt_write_file_len(char_u *buffer, int bytes);
static void prt_write_string(char *s);
static void prt_write_int(int i);
static void prt_write_boolean(int b);
static void prt_def_font(char *new_name, char *encoding, int height, char *font);
static void prt_def_cidfont(char *new_name, int height, char *cidfont);
static void prt_dup_cidfont(char *original_name, char *new_name);
static void prt_real_bits(double real, int precision, int *pinteger, int *pfraction);
static void prt_write_real(double val, int prec);
static void prt_def_var(char *name, double value, int prec);
static void prt_flush_buffer(void);
static void prt_resource_name(char_u *filename, void *cookie);
static int prt_find_resource(char *name, struct prt_ps_resource_S *resource);
static int prt_resfile_next_line(void);
static int prt_resfile_strncmp(int offset, char *string, int len);
static int prt_resfile_skip_nonws(int offset);
static int prt_resfile_skip_ws(int offset);
static int prt_next_dsc(struct prt_dsc_line_S *p_dsc_line);
static int prt_open_resource(struct prt_ps_resource_S *resource);
static int prt_check_resource(struct prt_ps_resource_S *resource, char_u *version);
static void prt_dsc_start(void);
static void prt_dsc_noarg(char *comment);
static void prt_dsc_textline(char *comment, char *text);
static void prt_dsc_text(char *comment, char *text);
static void prt_dsc_ints(char *comment, int count, int *ints);
static void prt_dsc_resources(char *comment, char *type, char *string);
static void prt_dsc_font_resource(char *resource, struct prt_ps_font_S *ps_font);
static void prt_dsc_requirements(int duplex, int tumble, int collate, int color, int num_copies);
static void prt_dsc_docmedia(char *paper_name, double width, double height, double weight, char *colour, char *type);
static float to_device_units(int idx, double physsize, int def_number);
static void prt_page_margins(double width, double height, double *left, double *right, double *top, double *bottom);
static void prt_font_metrics(int font_scale);
static int prt_get_cpl(void);
static void prt_build_cid_fontname(int font, char_u *name, int name_len);
static int prt_get_lpp(void);
static int prt_match_encoding(char *p_encoding, struct prt_ps_mbfont_S *p_cmap, struct prt_ps_encoding_S **pp_mbenc);
static int prt_match_charset(char *p_charset, struct prt_ps_mbfont_S *p_cmap, struct prt_ps_charset_S **pp_mbchar);
static int prt_add_resource(struct prt_ps_resource_S *resource);
#include "func_attr.h"
