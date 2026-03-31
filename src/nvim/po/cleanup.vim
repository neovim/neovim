" Vim script to cleanup a .po file:
" - Remove line numbers (avoids that diffs are messy).
" - Comment-out fuzzy and empty messages.
" - Make sure there is a space before the string (required for Solaris).
" Requires Vim 6.0 or later (because of multi-line search patterns).

" Disable diff mode, because it makes this very slow
let s:was_diff = &diff
setl nodiff

" untranslated message preceded by c-format or comment
silent g/^#, c-format\n#/.d _
silent g/^#\..*\n#/.d _

" c-format comments have no effect, the check.vim scripts checks it.
" But they might still be useful?
" silent g/^#, c-format$/d _

silent g/^#[:~] /d _
silent g/^#, fuzzy\(, .*\)\=\nmsgid ""\@!/.+1,/^$/-1s/^/#\~ /
silent g/^msgstr"/s//msgstr "/
silent g/^msgid"/s//msgid "/
silent g/^msgstr ""\(\n"\)\@!/?^msgid?,.s/^/#\~ /

" Comments only useful for the translator
silent g/^#\./d _

" clean up empty lines
silent g/^\n\n\n/.d _
silent! %s/\n\+\%$//

if s:was_diff
  setl diff
endif
