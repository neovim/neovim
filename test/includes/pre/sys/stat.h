#ifndef _GNU_SOURCE
# define _GNU_SOURCE
#endif
#include <sys/stat.h>

static const mode_t kS_IFMT = S_IFMT;
static const mode_t kS_IFSOCK = S_IFSOCK;
static const mode_t kS_IFLNK = S_IFLNK;
static const mode_t kS_IFREG = S_IFREG;
static const mode_t kS_IFBLK = S_IFBLK;
static const mode_t kS_IFDIR = S_IFDIR;
static const mode_t kS_IFCHR = S_IFCHR;
static const mode_t kS_IFIFO = S_IFIFO;
static const mode_t kS_ISUID = S_ISUID;
static const mode_t kS_ISGID = S_ISGID;
static const mode_t kS_ISVTX = S_ISVTX;
static const mode_t kS_IRWXU = S_IRWXU;
static const mode_t kS_IRUSR = S_IRUSR;
static const mode_t kS_IWUSR = S_IWUSR;
static const mode_t kS_IXUSR = S_IXUSR;
static const mode_t kS_IRWXG = S_IRWXG;
static const mode_t kS_IRGRP = S_IRGRP;
static const mode_t kS_IWGRP = S_IWGRP;
static const mode_t kS_IXGRP = S_IXGRP;
static const mode_t kS_IRWXO = S_IRWXO;
static const mode_t kS_IROTH = S_IROTH;
static const mode_t kS_IWOTH = S_IWOTH;
static const mode_t kS_IXOTH = S_IXOTH;
