#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static void vim_findfile_free_visited_list(ff_visited_list_hdr_T **list_headp);
static void ff_free_visited_list(ff_visited_T *vl);
static ff_visited_list_hdr_T *ff_get_visited_list(char_u *filename, ff_visited_list_hdr_T **list_headp);
static int ff_wc_equal(char_u *s1, char_u *s2);
static int ff_check_visited(ff_visited_T **visited_list, char_u *fname, char_u *wc_path);
static ff_stack_T *ff_create_stack_element(char_u *fix_part, char_u *wc_part, int level, int star_star_empty);
static void ff_push(ff_search_ctx_T *search_ctx, ff_stack_T *stack_ptr);
static ff_stack_T *ff_pop(ff_search_ctx_T *search_ctx);
static void ff_free_stack_element(ff_stack_T *stack_ptr);
static void ff_clear(ff_search_ctx_T *search_ctx);
static int ff_path_in_stoplist(char_u *path, int path_len, char_u **stopdirs_v);
#include "func_attr.h"
