static int ff_path_in_stoplist(char_u *, int, char_u **);
static ff_stack_T *ff_create_stack_element(char_u *, char_u *, int, int);
static void ff_free_stack_element(ff_stack_T *stack_ptr);
static void ff_clear(ff_search_ctx_T *search_ctx);
static ff_stack_T *ff_pop(ff_search_ctx_T *search_ctx);
static void ff_push(ff_search_ctx_T *search_ctx, ff_stack_T *stack_ptr);
static int ff_wc_equal(char_u *s1, char_u *s2);
static ff_visited_list_hdr_T* ff_get_visited_list
    (char_u *, ff_visited_list_hdr_T **list_headp);
static void ff_free_visited_list(ff_visited_T *vl);
static void vim_findfile_free_visited_list
    (ff_visited_list_hdr_T **list_headp);
static int ff_check_visited(ff_visited_T **, char_u *, char_u *);
