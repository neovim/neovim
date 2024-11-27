#include <stdbool.h>
#include <stdint.h>

#include "nvim/macros_defs.h"
#include "vterm/vterm.h"

int parser_text(const char bytes[], size_t len, void *user);
int parser_csi(const char *leader, const long args[], int argcount, const char *intermed, char command, void *user);
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
EXTERN VTermPos state_pos;
EXTERN bool want_state_putglyph INIT (=false);
EXTERN bool want_state_movecursor INIT(= false);
EXTERN bool want_state_erase INIT(= false);
EXTERN bool want_state_scrollrect INIT(= false);
EXTERN bool want_state_moverect INIT(= false);
EXTERN bool want_state_settermprop INIT(= false);
EXTERN bool want_state_scrollback INIT(= false);
EXTERN bool want_screen_scrollback INIT(= false);
