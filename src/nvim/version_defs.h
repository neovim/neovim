#ifndef NVIM_VERSION_DEFS_H
#define NVIM_VERSION_DEFS_H

// VIM - Vi IMproved    by Bram Moolenaar
//
// Do ":help uganda"  in Vim to read copying and usage conditions.
// Do ":help credits" in Vim to see a list of people who contributed.

// Vim version number, name, etc. Patchlevel is defined in version.c.

#define VIM_VERSION_MAJOR                7
#define VIM_VERSION_MAJOR_STR           "7"
#define VIM_VERSION_MINOR                4
#define VIM_VERSION_MINOR_STR           "4"
#define VIM_VERSION_100     (VIM_VERSION_MAJOR * 100 + VIM_VERSION_MINOR)

#define VIM_VERSION_BUILD                280
#define VIM_VERSION_BUILD_BCD           0x118
#define VIM_VERSION_BUILD_STR           "280"
#define VIM_VERSION_PATCHLEVEL           0
#define VIM_VERSION_PATCHLEVEL_STR      "0"
/* Used by MacOS port should be one of: development, alpha, beta, final */
#define VIM_VERSION_RELEASE             development

// used for the runtime directory name
#define VIM_VERSION_NODOT       "vim74"
// copied into the swap file (max. length is 6 chars)
#define VIM_VERSION_SHORT       "7.4"
// used for the startup-screen
#define VIM_VERSION_MEDIUM      "7.4"
// used for the ":version" command and "Vim -h"
#define NVIM_VERSION_LONG        "NVIM 0.0.0 pre-alpha"
#define NVIM_VERSION_LONG_DATE   "NVIM 0.0.0 pre-alpha (compiled "

/* Displayed on splash screen. */
#define MODIFIED_BY "the Neovim contributors."

#endif  // NVIM_VERSION_DEFS_H
