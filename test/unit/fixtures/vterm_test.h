#include <stdbool.h>
#include <stdint.h>

#include "nvim/macros_defs.h"
#include "nvim/vterm/vterm.h"

EXTERN VTermPos state_pos;
EXTERN bool want_state_putglyph INIT (=false);
EXTERN bool want_state_movecursor INIT(= false);
EXTERN bool want_state_erase INIT(= false);
EXTERN bool want_state_scrollrect INIT(= false);
EXTERN bool want_state_moverect INIT(= false);
EXTERN bool want_state_settermprop INIT(= false);
EXTERN bool want_state_scrollback INIT(= false);
EXTERN bool want_screen_scrollback INIT(= false);
int parser_text(const char bytes[], size_t len, void *user);
int parser_csi(const char *leader, const long args[], int argcount, const char *intermed,
               char command, void *user);
int parser_osc(int command, VTermStringFragment frag, void *user);
int parser_dcs(const char *command, size_t commandlen, VTermStringFragment frag, void *user);
int parser_apc(VTermStringFragment frag, void *user);
int parser_pm(VTermStringFragment frag, void *user);
int parser_sos(VTermStringFragment frag, void *user);
int selection_set(VTermSelectionMask mask, VTermStringFragment frag, void *user);
int selection_query(VTermSelectionMask mask, void *user);
int state_putglyph(VTermGlyphInfo *info, VTermPos pos, void *user);
int state_movecursor(VTermPos pos, VTermPos oldpos, int visible, void *user);
int state_scrollrect(VTermRect rect, int downward, int rightward, void *user);
int state_moverect(VTermRect dest, VTermRect src, void *user);
int state_settermprop(VTermProp prop, VTermValue *val, void *user);
int state_erase(VTermRect rect, int selective, void *user);
int state_setpenattr(VTermAttr attr, VTermValue *val, void *user);
int state_sb_clear(void *user);
void print_color(const VTermColor *col);
int screen_sb_pushline(int cols, const VTermScreenCell *cells, void *user);
int screen_sb_popline(int cols, VTermScreenCell *cells, void *user);
int screen_sb_clear(void *user);
void term_output(const char *s, size_t len, void *user);
int vterm_state_get_penattr(const VTermState *state, VTermAttr attr, VTermValue *val);
int vterm_screen_get_attrs_extent(const VTermScreen *screen, VTermRect *extent, VTermPos pos, VTermAttrMask attrs);
size_t vterm_screen_get_text(const VTermScreen *screen, char *buffer, size_t len,  VTermRect rect);
int vterm_screen_is_eol(const VTermScreen *screen, VTermPos pos);
void vterm_state_get_cursorpos(const VTermState *state, VTermPos *cursorpos);
void vterm_state_set_bold_highbright(VTermState *state, int bold_is_highbright);
int vterm_color_is_equal(const VTermColor *a, const VTermColor *b);
