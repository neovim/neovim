" Placeholder livebook filetype plugin file.
" This simply uses the markdown filetype plugin.

" Only load this plugin when no other was loaded.
if exists("b:did_ftplugin")
    finish
endif

runtime! ftplugin/markdown[.]{vim,lua} ftplugin/markdown_*.{vim,lua} ftplugin/markdown/*.{vim,lua}
