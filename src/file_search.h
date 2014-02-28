#ifndef NEOVIM_FIND_FILE_H
#define NEOVIM_FIND_FILE_H

void *vim_findfile_init __ARGS((char_u *path, char_u *filename, char_u *
                                stopdirs, int level, int free_visited,
                                int find_what, void *search_ctx_arg,
                                int tagfile,
                                char_u *rel_fname));
char_u *vim_findfile_stopdir __ARGS((char_u *buf));
void vim_findfile_cleanup __ARGS((void *ctx));
char_u *vim_findfile __ARGS((void *search_ctx_arg));
void vim_findfile_free_visited __ARGS((void *search_ctx_arg));
char_u *find_file_in_path __ARGS((char_u *ptr, int len, int options, int first,
                                  char_u *rel_fname));
void free_findfile __ARGS((void));
char_u *find_directory_in_path __ARGS((char_u *ptr, int len, int options,
                                       char_u *rel_fname));
char_u *find_file_in_path_option __ARGS((char_u *ptr, int len, int options,
                                         int first, char_u *path_option,
                                         int find_what, char_u *rel_fname,
                                         char_u *suffixes));

#endif /* NEOVIM_FIND_FILE_H */
