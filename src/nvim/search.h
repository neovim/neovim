#ifndef NVIM_SEARCH_H
#define NVIM_SEARCH_H

/* Values for the find_pattern_in_path() function args 'type' and 'action': */
#define FIND_ANY        1
#define FIND_DEFINE     2
#define CHECK_PATH      3

#define ACTION_SHOW     1
#define ACTION_GOTO     2
#define ACTION_SPLIT    3
#define ACTION_SHOW_ALL 4
#define ACTION_EXPAND   5

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "search.h.generated.h"
#endif
#endif  // NVIM_SEARCH_H
