static int cs_show(exarg_T *eap);
static char *       cs_resolve_file(int, char *);
static int cs_reset(exarg_T *eap);
static void cs_release_csp(int, int freefnpp);
static int cs_read_prompt(int);
static void cs_print_tags_priv(char **, char **, int);
static char *       cs_pathcomponents(char *path);
static char *       cs_parse_results(int cnumber, char *buf,
                                     int bufsize, char **context,
                                     char **linenumber,
                                     char **search);
static char *       cs_manage_matches(char **, char **, int, mcmd_e);
static char *       cs_make_vim_style_matches(char *, char *,
                                              char *, char *);
static cscmd_T *    cs_lookup_cmd(exarg_T *eap);
static void cs_kill_execute(int, char *);
static int cs_kill(exarg_T *eap);
static int cs_insert_filelist(char *, char *, char *,
                                      struct stat *);
static void clear_csinfo(int i);
static int cs_help(exarg_T *eap);
static int cs_find_common(char *opt, char *pat, int, int, int,
                                  char_u *cmdline);
static int cs_find(exarg_T *eap);
static void cs_fill_results(char *, int, int *, char ***,
                                    char ***, int *);
static void cs_file_results(FILE *, int *);
static void do_cscope_general(exarg_T *eap, int make_split);
static int cs_create_connection(int i);
static char *       cs_create_cmd(char *csoption, char *pattern);
static int cs_cnt_matches(int idx);
static void cs_reading_emsg(int idx);
static int cs_cnt_connections(void);
static int cs_check_for_tags(void);
static int cs_check_for_connections(void);
static int cs_add_common(char *, char *, char *);
static void cs_stat_emsg(char *fname);
static int cs_add(exarg_T *eap);
static void cs_usage_msg(csid_e x);
