#ifndef NVIM_TERM_H
#define NVIM_TERM_H

/* Size of the buffer used for tgetent().  Unfortunately this is largely
 * undocumented, some systems use 1024.  Using a buffer that is too small
 * causes a buffer overrun and a crash.  Use the maximum known value to stay
 * on the safe side. */
#define TBUFSZ 2048             /* buffer size for termcap entry */

/* Codes for mouse button events in lower three bits: */
# define MOUSE_LEFT     0x00
# define MOUSE_MIDDLE   0x01
# define MOUSE_RIGHT    0x02
# define MOUSE_RELEASE  0x03

/* bit masks for modifiers: */
# define MOUSE_SHIFT    0x04
# define MOUSE_ALT      0x08
# define MOUSE_CTRL     0x10

/* mouse buttons that are handled like a key press (GUI only) */
/* Note that the scroll wheel keys are inverted: MOUSE_5 scrolls lines up but
 * the result of this is that the window moves down, similarly MOUSE_6 scrolls
 * columns left but the window moves right. */
# define MOUSE_4        0x100   /* scroll wheel down */
# define MOUSE_5        0x200   /* scroll wheel up */

# define MOUSE_X1       0x300 /* Mouse-button X1 (6th) */
# define MOUSE_X2       0x400 /* Mouse-button X2 */

# define MOUSE_6        0x500   /* scroll wheel left */
# define MOUSE_7        0x600   /* scroll wheel right */

/* 0x20 is reserved by xterm */
# define MOUSE_DRAG_XTERM   0x40

# define MOUSE_DRAG     (0x40 | MOUSE_RELEASE)

/* Lowest button code for using the mouse wheel (xterm only) */
# define MOUSEWHEEL_LOW         0x60

# define MOUSE_CLICK_MASK       0x03

# define NUM_MOUSE_CLICKS(code) \
  (((unsigned)((code) & 0xC0) >> 6) + 1)

# define SET_NUM_MOUSE_CLICKS(code, num) \
  (code) = ((code) & 0x3f) | ((((num) - 1) & 3) << 6)

/* Added to mouse column for GUI when 'mousefocus' wants to give focus to a
 * window by simulating a click on its status line.  We could use up to 128 *
 * 128 = 16384 columns, now it's reduced to 10000. */
# define MOUSE_COLOFF 10000

# if defined(UNIX) && defined(HAVE_GETTIMEOFDAY) && defined(HAVE_SYS_TIME_H)
#  define CHECK_DOUBLE_CLICK 1  /* Checking for double clicks ourselves. */
# endif

/* term.c */
int set_termname(char_u *term);
void set_mouse_termcode(int n, char_u *s);
void del_mouse_termcode(int n);
void getlinecol(long *cp, long *rp);
int add_termcap_entry(char_u *name, int force);
int term_is_8bit(char_u *name);
char_u *tltoa(unsigned long i);
void termcapinit(char_u *name);
void out_flush(void);
void out_flush_check(void);
void out_char(unsigned c);
void out_str_nf(char_u *s);
void out_str(char_u *s);
void term_windgoto(int row, int col);
void term_cursor_right(int i);
void term_append_lines(int line_count);
void term_delete_lines(int line_count);
void term_set_winpos(int x, int y);
void term_set_winsize(int width, int height);
void term_fg_color(int n);
void term_bg_color(int n);
void term_settitle(char_u *title);
void ttest(int pairs);
void check_shellsize(void);
void limit_screen_size(void);
void win_new_shellsize(void);
void shell_resized(void);
void shell_resized_check(void);
void set_shellsize(int width, int height, int mustset);
void settmode(int tmode);
void starttermcap(void);
void stoptermcap(void);
void may_req_termresponse(void);
void may_req_ambiguous_char_width(void);
int swapping_screen(void);
void setmouse(void);
int mouse_has(int c);
int mouse_model_popup(void);
void scroll_start(void);
void cursor_on(void);
void cursor_off(void);
void term_cursor_shape(void);
void scroll_region_set(win_T *wp, int off);
void scroll_region_reset(void);
void clear_termcodes(void);
void add_termcode(char_u *name, char_u *string, int flags);
char_u *find_termcode(char_u *name);
char_u *get_termcode(int i);
void del_termcode(char_u *name);
void set_mouse_topline(win_T *wp);
int check_termcode(int max_offset, char_u *buf, int bufsize,
                           int *buflen);
char_u *replace_termcodes(char_u *from, char_u **bufp, int from_part,
                                  int do_lt,
                                  int special);
int find_term_bykeys(char_u *src);
void show_termcodes(void);
int show_one_termcode(char_u *name, char_u *code, int printit);
char_u *translate_mapping(char_u *str, int expmap);
#endif /* NVIM_TERM_H */
