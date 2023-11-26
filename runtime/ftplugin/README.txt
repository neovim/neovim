The ftplugin directory is for Vim plugin scripts that are only used for a
specific filetype.

All files ending in .vim in this directory and subdirectories will be sourced
by Vim when it detects the filetype that matches the name of the file or
subdirectory.
For example, these are all loaded for the "c" filetype:

	c.vim
	c_extra.vim
	c/settings.vim

Note that the "_" in "c_extra.vim" is required to separate the filetype name
from the following arbitrary name.

The filetype plugins are only loaded when the ":filetype plugin" command has
been used.

The default filetype plugin files contain settings that 95% of the users will
want to use.  They do not contain personal preferences, like the value of
'shiftwidth'.

If you want to do additional settings, or overrule the default filetype
plugin, you can create your own plugin file.  See ":help ftplugin" in Vim.
