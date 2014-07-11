keymap files for Vim

One of these files is loaded when the 'keymap' option is set.

The name of the file consists of these parts:

	{language}[-{layout}][_{encoding}].vim

{language}	Name of the language (e.g., "hebrew", "greek")

{layout}	Optional: name of the keyboard layout (e.g., "spanish",
		"russian3").  When omitted the layout of the standard
		US-english keyboard is assumed.

{encoding}	Optional: character encoding for which this keymap works.
		When omitted the "normal" encoding for the language is
		assumed.
		Use the value the 'encoding' option: lower case only, use '-'
		instead of '_'.

Each file starts with a header, naming the maintainer and the date when it was
last changed.  If you find a problem in a keymap file, check if you have the
most recent version.  If necessary, report a problem to the maintainer.

The format of the keymap lines below "loadkeymap" is explained in the Vim help
files, see ":help keymap-file-format".
