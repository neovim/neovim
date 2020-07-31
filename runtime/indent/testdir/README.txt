TESTING INDENT SCRIPTS

We'll use FILETYPE for the filetype name here.


FORMAT OF THE FILETYPE.IN FILE

First of all, create a FILETYPE.in file.  It should contain:

- A modeline setting the 'filetype' and any other option values.
  This must work like a comment for FILETYPE.  E.g. for vim:
	" vim: set ft=vim sw=4 :

- At least one block of lines to indent, prefixed with START_INDENT and
  followed by END_INDENT.  These lines must also look like a comment for your
  FILETYPE.  You would normally leave out all indent, so that the effect of
  the indent command results in adding indent.  Example:

	" START_INDENT
	func Some()
	let x = 1
	endfunc
	" END_INDENT

  If you just want to test normal indenting with default options, you can make
  this a large number of lines.  Just add all kinds of language constructs,
  nested statements, etc. with valid syntax.

- Optionally, add lines with INDENT_EXE after START_INDENT, followed by a Vim
  command.  This will be executed before indenting the lines.  Example:

	" START_INDENT
	" INDENT_EXE let g:vim_indent_cont = 6
	let cmd =
	      \ 'some '
	      \ 'string'
	" END_INDENT

  Note that the command is not undone, you may need to reverse the effect for
  the next block of lines.

- Alternatively to indenting all the lines between START_INDENT and
  END_INDENT, use an INDENT_AT line, which specifies a pattern to find the
  line to indent.  Example:

	" START_INDENT
	" INDENT_AT  this-line
	func Some()
	let f = x " this-line
	endfunc
	" END_INDENT

  Alternatively you can use INDENT_NEXT to indent the line below the matching
  pattern.  Keep in mind that quite often it will indent relative to the
  matching line:

	" START_INDENT
	" INDENT_NEXT  next-line
	func Some()
	" next-line
	let f = x
	endfunc
	" END_INDENT

  Or use INDENT_PREV to indent the line above the matching pattern:

	" START_INDENT
	" INDENT_PREV  prev-line
	func Some()
      	let f = x
	" prev-line
	endfunc
	" END_INDENT

It's best to keep the whole file valid for FILETYPE, so that syntax
highlighting works normally, and any indenting that depends on the syntax
highlighting also works.


RUNNING THE TEST

Before running the test, create a FILETYPE.ok file.  You can leave it empty at
first.

Now run "make test" from the parent directory.  After Vim has done the
indenting you will see a FILETYPE.fail file.  This contains the actual result
of indenting, and it's different from the FILETYPE.ok file.

Check the contents of the FILETYPE.fail file.  If it is perfectly OK, then
rename it to overwrite the FILETYPE.ok file. If you now run "make test" again,
the test will pass and create a FILETYPE.out file, which is identical to the
FILETYPE.ok file.  The FILETYPE.fail file will be deleted.

If you try to run "make test" again you will notice that nothing happens,
because the FILETYPE.out file already exists.  Delete it, or do "make clean",
so that the text runs again.  If you edit the FILETYPE.in file, so that it's
newer than the FILETYPE.out file, the test will also run.
