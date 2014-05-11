#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static inline int arabic_char(int c);
static int A_is_a(int cur_c);
static int A_is_s(int cur_c);
static int A_is_f(int cur_c);
static int chg_c_a2s(int cur_c);
static int chg_c_a2i(int cur_c);
static int chg_c_a2m(int cur_c);
static int chg_c_a2f(int cur_c);
static int chg_c_i2m(int cur_c);
static int chg_c_f2m(int cur_c);
static int chg_c_laa2i(int hid_c);
static int chg_c_laa2f(int hid_c);
static int half_shape(int c);
static int A_firstc_laa(int c, int c1);
static int A_is_harakat(int c);
static int A_is_iso(int c);
static int A_is_formb(int c);
static int A_is_ok(int c);
static int A_is_valid(int c);
static int A_is_special(int c);
#include "func_attr.h"
