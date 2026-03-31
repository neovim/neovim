This directory contains Vim scripts for syntax highlighting.

These scripts are not for a language, but are used by Vim itself:

syntax.vim	Used for the ":syntax on" command.  Uses synload.vim.

manual.vim	Used for the ":syntax manual" command.  Uses synload.vim.

synload.vim	Contains autocommands to load a language file when a certain
		file name (extension) is used.  And sets up the Syntax menu
		for the GUI.

nosyntax.vim	Used for the ":syntax off" command.  Undo the loading of
		synload.vim.

The "shared" directory contains generated files and what is used by more than
one syntax.


A few special files:

2html.vim	Converts any highlighted file to HTML (GUI only).
colortest.vim	Check for color names and actual color on screen.
hitest.vim	View the current highlight settings.
whitespace.vim  View Tabs and Spaces.


If you want to write a syntax file, read the docs at ":help usr_44.txt".

If you make a new syntax file which would be useful for others, please send it
to the vim-dev mailing list <vim-dev@vim.org>.  Include instructions for
detecting the file type for this language, by file name extension or by
checking a few lines in the file. And please write the file in a portable way,
see ":help 44.12".

If you have remarks about an existing file, send them to the maintainer of
that file.  Only when you get no response send a message to the vim-dev
mailing list: <vim-dev@vim.org>.

If you are the maintainer of a syntax file and make improvements, send the new
version to the vim-dev mailing list: <vim-dev@vim.org>

For further info see ":help syntax" in Vim.
