#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static int get_x11_title(int test_only);
static int get_x11_icon(int test_only);
static void exit_scroll();
static void save_patterns(int num_pat, char_u **pat, int *num_file, char_u ***file);
static int have_wildcard(int num, char_u **file);
static int have_dollars(int num, char_u **file);
#include "func_attr.h"
