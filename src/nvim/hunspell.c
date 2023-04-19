#include <stdlib.h>

#include "nvim/ascii.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/userfunc.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/garray.h"
#include "nvim/getchar.h"
#include "nvim/gettext.h"
#include "nvim/globals.h"
#include "nvim/highlight_defs.h"
#include "nvim/indent.h"
#include "nvim/indent_c.h"
#include "nvim/insexpand.h"
#include "nvim/keycodes.h"
#include "nvim/macros.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/option.h"
#include "nvim/os/fs.h"
#include "nvim/os/input.h"
#include "nvim/os/time.h"
#include "nvim/path.h"
#include "nvim/popupmenu.h"
#include "nvim/pos.h"
#include "nvim/regexp.h"
#include "nvim/search.h"
#include "nvim/spell.h"
#include "nvim/state.h"
#include "nvim/strings.h"
#include "nvim/tag.h"
#include "nvim/textformat.h"
#include "nvim/types.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/vim.h"
#include "hunspell/hunspell.h"

// Declare global variable exarg_T ea
void ex_hunspell_suggest(exarg_T *eap)
{
    Hunhandle *pHunspell = NULL;
    pHunspell = Hunspell_create("/Users/ethan/neo/neovim/src/nvim/hunspell/lib/en_US.aff", "/Users/ethan/neo/neovim/src/nvim/hunspell/lib/en_US.dic");
    if (pHunspell == NULL) {
        msg("failed to make hunspell");
        return;
    }

    // Read the buffer into a string
    buf_T *buf = curbuf;
    size_t buf_len = 0;
    for (linenr_T lnum = 1; lnum <= buf->b_ml.ml_line_count; ++lnum) {
        buf_len += strlen((char *)ml_get_buf(buf, lnum, false));
    }

    char *buffer_contents = (char *)malloc(buf_len + 1);
    if (buffer_contents == NULL) {
        Hunspell_destroy(pHunspell);
        return;
    }

    buffer_contents[0] = '\0';
    for (linenr_T lnum = 1; lnum <= buf->b_ml.ml_line_count; ++lnum) {
        strcat(buffer_contents, (char *)ml_get_buf(buf, lnum, false));
    }

    // Tokenize the string into words
    char *word;
    char *ptr = buffer_contents;
    int suggestion_line = 1;
    while ((word = strtok_r(ptr, " \t\n\r", &ptr))) {
        // Check if the word is spelled correctly
        if (Hunspell_spell(pHunspell, word) == 0) {
            char **slst;
            int ns = Hunspell_suggest(pHunspell, &slst, word);
            if (ns > 0) {
                char suggestion_msg[256];
                snprintf(suggestion_msg, sizeof(suggestion_msg), "Suggestions for '%s':", word);
                msg(suggestion_msg);
                for (int i = 0; i < ns; i++) {
                    msg(slst[i]);
                }
                Hunspell_free_list(pHunspell, &slst, ns);
            }
        }
    }

    free(buffer_contents);
    Hunspell_destroy(pHunspell);
}