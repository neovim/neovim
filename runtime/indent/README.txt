This directory contains files to automatically compute the indent for a
type of file.

If you want to add your own indent file for your personal use, read the docs
at ":help indent-expression".  Looking at the existing files should give you
inspiration.

If you make a new indent file which would be useful for others, please send it
to Bram@vim.org.  Include instructions for detecting the file type for this
language, by file name extension or by checking a few lines in the file.
And please stick to the rules below.

If you have remarks about an existing file, send them to the maintainer of
that file.  Only when you get no response send a message to Bram@vim.org.

If you are the maintainer of an indent file and make improvements, e-mail the
new version to Bram@vim.org.


Rules for making an indent file:

You should use this check for "b:did_indent":

	" Only load this indent file when no other was loaded yet.
	if exists("b:did_indent")
	  finish
	endif
	let b:did_indent = 1

Always use ":setlocal" to set 'indentexpr'.  This avoids it being carried over
to other buffers.

To trigger the indenting after typing a word like "endif", add the word to the
'indentkeys' option with "+=".

You normally set 'indentexpr' to evaluate a function and then define that
function.  That function only needs to be defined once for as long as Vim is
running.  Add a test if the function exists and use ":finish", like this:
	if exists("*GetMyIndent")
	  finish
	endif

The user may have several options set unlike you, try to write the file such
that it works with any option settings.  Also be aware of certain features not
being compiled in.

To test the indent file, see testdir/README.txt.
