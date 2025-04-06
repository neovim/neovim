" Invoked with the name "vim.pot" and a list of Vim script names.
" Converts them to a .js file, stripping comments, so that xgettext works.
" Javascript is used because, like Vim, it accepts both single and double
" quoted strings.

set shortmess+=A

for name in argv()[1:]
  exe 'edit ' .. fnameescape(name)

  " Strip comments
  g/^\s*"/s/.*//

  " Write as .js file, xgettext recognizes them
  exe 'w! ' .. fnamemodify(name, ":t:r") .. ".js"
endfor

quit
