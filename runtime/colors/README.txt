README.txt for color scheme files

These files are used for the `:colorscheme` command.  They appear in the
"Edit/Color Scheme" menu in the GUI.

The colorschemes were updated for the Vim 9 release.  If you don't like the
changes you can find the old ones here:
https://github.com/vim/colorschemes/tree/master/legacy_colors


Hints for writing a color scheme file:

There are two basic ways to define a color scheme:

1. Define a new Normal color and set the 'background' option accordingly. >

	set background={light or dark}
	highlight clear
	highlight Normal ...
	...

2. Use the default Normal color and automatically adjust to the value of
   'background'. >

	highlight clear Normal
	set background&
	highlight clear
	if &background == "light"
	  highlight Error ...
	  ...
	else
	  highlight Error ...
	  ...
	endif

You can use `:highlight clear` to reset everything to the defaults, and then
change the groups that you want differently.  This will also work for groups
that are added in later versions of Vim.
Note that `:highlight clear` uses the value of 'background', thus set it
before this command.
Some attributes (e.g., bold) might be set in the defaults that you want
removed in your color scheme.  Use something like "gui=NONE" to remove the
attributes.

In case you want to set 'background' depending on the colorscheme selected,
this autocmd might be useful: >

     autocmd SourcePre */colors/blue_sky.vim set background=dark

Replace "blue_sky" with the name of the colorscheme.

In case you want to tweak a colorscheme after it was loaded, check out the
ColorScheme autocommand event.

To clean up just before loading another colorscheme, use the ColorSchemePre
autocommand event.  For example: >

	let g:term_ansi_colors = ...
	augroup MyColorscheme
	  au!
	  au ColorSchemePre * unlet g:term_ansi_colors
	  au ColorSchemePre * au! MyColorscheme
	augroup END

To customize a colorscheme use another name, e.g.  "~/.vim/colors/mine.vim",
and use ":runtime" to load the original colorscheme: >

	" load the "evening" colorscheme
	runtime colors/evening.vim
	" change the color of statements
	hi Statement ctermfg=Blue guifg=Blue

To see which highlight group is used where, see `:help highlight-groups` and
`:help group-name` .

You can use ":highlight" to find out the current colors.  Exception: the
ctermfg and ctermbg values are numbers, which are only valid for the current
terminal.  Use the color names instead for better portability.  See
`:help cterm-colors` .

The default color settings can be found in the source file
"src/nvim/highlight_group.c".  Search for "highlight_init".

If you think you have a color scheme that is good enough to be used by others,
please check the following items:

- Source the $VIMRUNTIME/colors/tools/check_colors.vim script to check for
  common mistakes.

- Does it work in a color terminal as well as in the GUI? Is it consistent?

- Is "g:colors_name" set to a meaningful value?  In case of doubt you can do
  it this way: >

  	let g:colors_name = expand('<sfile>:t:r')

- Is 'background' either used or appropriately set to "light" or "dark"?

- Try setting 'hlsearch' and searching for a pattern, is the match easy to
  spot?

- Split a window with ":split" and ":vsplit".  Are the status lines and
  vertical separators clearly visible?

- In the GUI, is it easy to find the cursor, also in a file with lots of
  syntax highlighting?

- In general, test your color scheme against as many filetypes, Vim features,
  environments, etc. as possible.

- Do not use hard coded escape sequences, these will not work in other
  terminals.  Always use #RRGGBB for the GUI.

- When targetting 8-16 colors terminals, don't count on "darkblue" to be blue
  and dark, or on "2" to be even vaguely reddish.  Names are more portable
  than numbers, though.

- When targetting 256 colors terminals, prefer colors 16-255 to colors 0-15
  for the same reason.

- Typographic attributes (bold, italic, underline, reverse, etc.) are not
  universally supported.  Don't count on any of them.

- Is "g:terminal_ansi_colors" set to a list of 16 #RRGGBB values?

- Try to keep your color scheme simple by avoiding unnecessary logic and
  refraining from adding options.  The best color scheme is one that only
  requires: >

  	colorscheme foobar

The color schemes distributed with Vim are built with lifepillar/colortemplate
(https://github.com/lifepillar/vim-colortemplate).  It is therefore highly
recommended.

If you would like your color scheme to be distributed with Vim, make sure
that:

- it satisfies the guidelines above,
- it was made with colortemplate,

and join us at vim/colorschemes: (https://github.com/vim/colorschemes).


vim: set ft=help :
