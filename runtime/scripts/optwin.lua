---@param x string
---@return string
local function N_(x)
  return vim.fn.gettext(x)
end

---@type {header:string,[integer]:[string,string]}[]
local options_list = {
  {
    header = N_ 'important',
    { 'cpoptions', N_ 'list of flags to specify Vi compatibility' },
    { 'runtimepath', N_ 'list of directories used for runtime files and plugins' },
    { 'packpath', N_ 'list of directories used for plugin packages' },
    { 'helpfile', N_ 'name of the main help file' },
  },
  {
    header = N_ 'moving around, searching and patterns',
    { 'whichwrap', N_ 'list of flags specifying which commands wrap to another line' },
    {
      'startofline',
      N_ 'many jump commands move the cursor to the first non-blank\ncharacter of a line',
    },
    { 'paragraphs', N_ 'nroff macro names that separate paragraphs' },
    { 'sections', N_ 'nroff macro names that separate sections' },
    { 'path', N_ 'list of directory names used for file searching' },
    { 'findfunc', N_ 'function called for :find' },
    { 'cdhome', N_ ':cd without argument goes to the home directory' },
    { 'cdpath', N_ 'list of directory names used for :cd' },
    { 'autochdir', N_ 'change to directory of file in buffer' },
    { 'wrapscan', N_ 'search commands wrap around the end of the buffer' },
    { 'incsearch', N_ 'show match for partly typed search command' },
    { 'magic', N_ 'change the way backslashes are used in search patterns' },
    { 'regexpengine', N_ 'select the default regexp engine used' },
    { 'ignorecase', N_ 'ignore case when using a search pattern' },
    { 'smartcase', N_ "override 'ignorecase' when pattern has upper case characters" },
    { 'maxsearchcount', N_ 'maximum number for the search count feature' },
    { 'casemap', N_ 'what method to use for changing case of letters' },
    { 'maxmempattern', N_ 'maximum amount of memory in Kbyte used for pattern matching' },
    { 'define', N_ 'pattern for a macro definition line' },
    { 'include', N_ 'pattern for an include-file line' },
    { 'includeexpr', N_ 'expression used to transform an include line to a file name' },
    { 'jumpoptions', N_ 'controls the behavior of the jumplist' },
  },
  {
    header = N_ 'tags',
    { 'tagbsearch', N_ 'use binary searching in tags files' },
    { 'taglength', N_ 'number of significant characters in a tag name or zero' },
    { 'tags', N_ 'list of file names to search for tags' },
    {
      'tagcase',
      N_ 'how to handle case when searching in tags files:\n"followic" to follow \'ignorecase\', "ignore" or "match"',
    },
    { 'tagrelative', N_ 'file names in a tags file are relative to the tags file' },
    { 'tagstack', N_ 'a :tag command will use the tagstack' },
    { 'showfulltag', N_ 'when completing tags in Insert mode show more info' },
    { 'tagfunc', N_ 'a function to be used to perform tag searches' },
  },
  {
    header = N_ 'displaying text',
    { 'scroll', N_ 'number of lines to scroll for CTRL-U and CTRL-D' },
    { 'smoothscroll', N_ 'scroll by screen line' },
    { 'scrolloff', N_ 'number of screen lines to show around the cursor' },
    { 'wrap', N_ 'long lines wrap' },
    { 'linebreak', N_ "wrap long lines at a character in 'breakat'" },
    { 'breakindent', N_ 'preserve indentation in wrapped text' },
    { 'breakindentopt', N_ 'adjust breakindent behaviour' },
    { 'breakat', N_ 'which characters might cause a line break' },
    { 'showbreak', N_ 'string to put before wrapped screen lines' },
    { 'sidescroll', N_ 'minimal number of columns to scroll horizontally' },
    { 'sidescrolloff', N_ 'minimal number of columns to keep left and right of the cursor' },
    {
      'display',
      N_ 'include "lastline" to show the last line even if it doesn\'t fit\ninclude "uhex" to show unprintable characters as a hex number',
    },
    {
      'fillchars',
      N_ 'characters to use for the status line, folds, diffs,\nbuffer text, filler lines and truncation in the completion menu',
    },
    { 'cmdheight', N_ 'number of lines used for the command-line' },
    { 'columns', N_ 'width of the display' },
    { 'lines', N_ 'number of lines in the display' },
    { 'window', N_ 'number of lines to scroll for CTRL-F and CTRL-B' },
    { 'lazyredraw', N_ "don't redraw while executing macros" },
    { 'redrawtime', N_ "timeout for 'hlsearch' and :match highlighting in msec" },
    { 'writedelay', N_ 'delay in msec for each char written to the display' },
    { 'redrawdebug', N_ 'change the way redrawing works (debug)' },
    { 'list', N_ 'show <Tab> as ^I and end-of-line as $' },
    { 'listchars', N_ 'list of strings used for list mode' },
    { 'number', N_ 'show the line number for each line' },
    { 'relativenumber', N_ 'show the relative line number for each line' },
    { 'numberwidth', N_ 'number of columns to use for the line number' },
    { 'chistory', N_ 'maximum number of quickfix lists that can be stored in history' },
    { 'lhistory', N_ 'maximum number of location lists that can be stored in history' },
    { 'conceallevel', N_ 'controls whether concealable text is hidden' },
    { 'concealcursor', N_ 'modes in which text in the cursor line can be concealed' },
  },
  {
    header = N_ 'syntax, highlighting and spelling',
    { 'background', N_ '"dark" or "light"; the background color brightness' },
    { 'filetype', N_ 'type of file; triggers the FileType event when set' },
    { 'syntax', N_ 'name of syntax highlighting used' },
    { 'synmaxcol', N_ 'maximum column to look for syntax items' },
    { 'hlsearch', N_ 'highlight all matches for the last used search pattern' },
    { 'termguicolors', N_ 'use GUI colors for the terminal' },
    { 'cursorcolumn', N_ 'highlight the screen column of the cursor' },
    { 'cursorline', N_ 'highlight the screen line of the cursor' },
    { 'cursorlineopt', N_ "specifies which area 'cursorline' highlights" },
    { 'colorcolumn', N_ 'columns to highlight' },
    { 'spell', N_ 'highlight spelling mistakes' },
    { 'spelllang', N_ 'list of accepted languages' },
    { 'spellfile', N_ 'file that "zg" adds good words to' },
    { 'spellcapcheck', N_ 'pattern to locate the end of a sentence' },
    { 'spelloptions', N_ 'flags to change how spell checking works' },
    { 'spellsuggest', N_ 'methods used to suggest corrections' },
    { 'mkspellmem', N_ 'amount of memory used by :mkspell before compressing' },
    { 'winhighlight', N_ 'override highlighting-groups window-locally' },
  },
  {
    header = N_ 'multiple windows',
    { 'laststatus', N_ '0, 1, 2 or 3; when to use a status line for the last window' },
    { 'statuscolumn', N_ 'custom format for the status column' },
    { 'statusline', N_ 'alternate format to be used for a status line' },
    { 'equalalways', N_ 'make all windows the same size when adding/removing windows' },
    { 'eadirection', N_ 'in which direction \'equalalways\' works: "ver", "hor" or "both"' },
    { 'winheight', N_ 'minimal number of lines used for the current window' },
    { 'winminheight', N_ 'minimal number of lines used for any window' },
    { 'winfixbuf', N_ 'keep window focused on a single buffer' },
    { 'winfixheight', N_ 'keep the height of the window' },
    { 'winfixwidth', N_ 'keep the width of the window' },
    { 'winwidth', N_ 'minimal number of columns used for the current window' },
    { 'winminwidth', N_ 'minimal number of columns used for any window' },
    { 'helpheight', N_ 'initial height of the help window' },
    { 'previewheight', N_ 'default height for the preview window' },
    { 'previewwindow', N_ 'identifies the preview window' },
    { 'winbar', N_ 'custom format for the window bar' },
    { 'winborder', N_ 'border of floating window' },
    { 'winblend', N_ 'transparency level for floating windows' },
    { 'hidden', N_ "don't unload a buffer when no longer shown in a window" },
    { 'switchbuf', N_ '"useopen" and/or "split"; which window to use when jumping\nto a buffer' },
    { 'splitbelow', N_ 'a new window is put below the current one' },
    { 'splitkeep', N_ 'determines scroll behavior for split windows' },
    { 'splitright', N_ 'a new window is put right of the current one' },
    { 'scrollbind', N_ 'this window scrolls together with other bound windows' },
    { 'scrollopt', N_ '"ver", "hor" and/or "jump"; list of options for \'scrollbind\'' },
    { 'cursorbind', N_ "this window's cursor moves together with other bound windows" },
  },
  {
    header = N_ 'multiple tab pages',
    { 'showtabline', N_ '0, 1 or 2; when to use a tab pages line' },
    { 'tabclose', N_ 'behaviour when closing tab pages: left, uselast or empty' },
    { 'tabpagemax', N_ 'maximum number of tab pages to open for -p and "tab all"' },
    { 'tabline', N_ 'custom tab pages line' },
  },
  {
    header = N_ 'terminal',
    { 'scrolljump', N_ 'minimal number of lines to scroll at a time' },
    { 'guicursor', N_ 'specifies what the cursor looks like in different modes' },
    { 'title', N_ 'show info in the window title' },
    { 'titlelen', N_ "percentage of 'columns' used for the window title" },
    { 'titlestring', N_ 'when not empty, string to be used for the window title' },
    { 'titleold', N_ 'string to restore the title to when exiting Vim' },
    { 'icon', N_ 'set the text of the icon for this window' },
    { 'iconstring', N_ 'when not empty, text for the icon of this window' },
  },
  {
    header = N_ 'using the mouse',
    { 'mouse', N_ 'list of flags for using the mouse' },
    { 'mousescroll', N_ 'amount to scroll by when scrolling with a mouse' },
    { 'mousefocus', N_ 'the window with the mouse pointer becomes the current one' },
    { 'mousehide', N_ 'hide the mouse pointer while typing' },
    {
      'mousemodel',
      N_ '"extend", "popup" or "popup_setpos"; what the right\nmouse button is used for',
    },
    { 'mousetime', N_ 'maximum time in msec to recognize a double-click' },
    { 'mousemoveevent', N_ 'deliver mouse move events to input queue' },
  },
  {
    header = N_ 'GUI',
    { 'guifont', N_ 'list of font names to be used in the GUI' },
    { 'guifontwide', N_ 'list of font names to be used for double-wide characters' },
    { 'browsedir', N_ '"last", "buffer" or "current": which directory used for\nthe file browser' },
    { 'langmenu', N_ 'language to be used for the menus' },
    { 'menuitems', N_ 'maximum number of items in one menu' },
    { 'winaltkeys', N_ '"no", "yes" or "menu"; how to use the ALT key' },
    { 'linespace', N_ 'number of pixel lines to use between characters' },
    { 'termsync', N_ 'synchronize redraw output with the host terminal' },
  },
  {
    header = N_ 'messages and info',
    { 'shortmess', N_ 'list of flags to make messages shorter' },
    { 'messagesopt', N_ 'options for outputting messages' },
    { 'showcmd', N_ "show (partial) command keys in location given by 'showcmdloc'" },
    { 'showcmdloc', N_ "location where to show the (partial) command keys for 'showcmd'" },
    { 'showmode', N_ 'display the current mode in the status line' },
    { 'ruler', N_ 'show cursor position below each window' },
    { 'rulerformat', N_ 'alternate format to be used for the ruler' },
    { 'report', N_ 'threshold for reporting number of changed lines' },
    { 'verbose', N_ 'the higher the more messages are given' },
    { 'verbosefile', N_ 'file to write messages in' },
    { 'more', N_ 'pause listings when the screen is full' },
    { 'confirm', N_ 'start a dialog when a command fails' },
    { 'errorbells', N_ 'ring the bell for error messages' },
    { 'visualbell', N_ 'use a visual bell instead of beeping' },
    { 'belloff', N_ 'do not ring the bell for these reasons' },
    { 'helplang', N_ 'list of preferred languages for finding help' },
  },
  {
    header = N_ 'selecting text',
    { 'selection', N_ '"old", "inclusive" or "exclusive"; how selecting text behaves' },
    {
      'selectmode',
      N_ '"mouse", "key" and/or "cmd"; when to start Select mode\ninstead of Visual mode',
    },
    {
      'clipboard',
      N_ '"unnamed" to use the * register like unnamed register\n"autoselect" to always put selected text on the clipboard',
    },
    { 'keymodel', N_ '"startsel" and/or "stopsel"; what special keys can do' },
  },
  {
    header = N_ 'editing text',
    { 'undolevels', N_ 'maximum number of changes that can be undone' },
    { 'undofile', N_ 'automatically save and restore undo history' },
    { 'undodir', N_ 'list of directories for undo files' },
    { 'undoreload', N_ 'maximum number lines to save for undo on a buffer reload' },
    { 'modified', N_ 'changes have been made and not written to a file' },
    { 'readonly', N_ 'buffer is not to be written' },
    { 'modifiable', N_ 'changes to the text are possible' },
    { 'textwidth', N_ 'line length above which to break a line' },
    { 'wrapmargin', N_ 'margin from the right in which to break a line' },
    { 'backspace', N_ 'specifies what <BS>, CTRL-W, etc. can do in Insert mode' },
    { 'comments', N_ 'definition of what comment lines look like' },
    { 'commentstring', N_ 'template for comments; used to put the marker in' },
    { 'formatoptions', N_ 'list of flags that tell how automatic formatting works' },
    { 'formatlistpat', N_ 'pattern to recognize a numbered list' },
    { 'formatexpr', N_ 'expression used for "gq" to format lines' },
    { 'complete', N_ 'specifies how Insert mode completion works for CTRL-N and CTRL-P' },
    { 'autocomplete', N_ 'automatic completion in insert mode' },
    { 'autocompletetimeout', N_ "initial decay timeout for 'autocomplete' algorithm" },
    { 'completetimeout', N_ 'initial decay timeout for CTRL-N and CTRL-P completion' },
    { 'autocompletedelay', N_ 'delay in msec before menu appears after typing' },
    { 'completeopt', N_ 'whether to use a popup menu for Insert mode completion' },
    { 'completeitemalign', N_ 'popup menu item align order' },
    { 'completefuzzycollect', N_ 'use fuzzy collection for specific completion modes' },
    { 'pumheight', N_ 'maximum height of the popup menu' },
    { 'pumwidth', N_ 'minimum width of the popup menu' },
    { 'pummaxwidth', N_ 'maximum width of the popup menu' },
    { 'pumblend', N_ 'transparency level of popup menu' },
    { 'pumborder', N_ 'border of popupmenu' },
    { 'completefunc', N_ 'user defined function for Insert mode completion' },
    { 'omnifunc', N_ 'function for filetype-specific Insert mode completion' },
    { 'dictionary', N_ 'list of dictionary files for keyword completion' },
    { 'thesaurus', N_ 'list of thesaurus files for keyword completion' },
    { 'thesaurusfunc', N_ 'function used for thesaurus completion' },
    { 'infercase', N_ 'adjust case of a keyword completion match' },
    { 'digraph', N_ 'enable entering digraphs with c1 <BS> c2' },
    { 'tildeop', N_ 'the "~" command behaves like an operator' },
    { 'operatorfunc', N_ 'function called for the "g@" operator' },
    { 'showmatch', N_ 'when inserting a bracket, briefly jump to its match' },
    { 'matchtime', N_ "tenth of a second to show a match for 'showmatch'" },
    { 'matchpairs', N_ 'list of pairs that match for the "%" command' },
    { 'joinspaces', N_ "use two spaces after '.' when joining a line" },
    {
      'nrformats',
      N_ '"alpha", "octal", "hex", "bin" and/or "unsigned"; number formats\nrecognized for CTRL-A and CTRL-X commands',
    },
  },
  {
    header = N_ 'tabs and indenting',
    { 'tabstop', N_ 'number of spaces a <Tab> in the text stands for' },
    { 'shiftwidth', N_ 'number of spaces used for each step of (auto)indent' },
    { 'vartabstop', N_ 'list of number of spaces a tab counts for' },
    { 'varsofttabstop', N_ 'list of number of spaces a soft tabsstop counts for' },
    { 'smarttab', N_ "a <Tab> in an indent inserts 'shiftwidth' spaces" },
    { 'softtabstop', N_ 'if non-zero, number of spaces to insert for a <Tab>' },
    { 'shiftround', N_ 'round to \'shiftwidth\' for "<<" and ">>"' },
    { 'expandtab', N_ 'expand <Tab> to spaces in Insert mode' },
    { 'autoindent', N_ 'automatically set the indent of a new line' },
    { 'smartindent', N_ 'do clever autoindenting' },
    { 'cindent', N_ 'enable specific indenting for C code' },
    { 'cinoptions', N_ 'options for C-indenting' },
    { 'cinkeys', N_ 'keys that trigger C-indenting in Insert mode' },
    { 'cinwords', N_ 'list of words that cause more C-indent' },
    { 'cinscopedecls', N_ 'list of scope declaration names used by cino-g' },
    { 'indentexpr', N_ 'expression used to obtain the indent of a line' },
    { 'indentkeys', N_ "keys that trigger indenting with 'indentexpr' in Insert mode" },
    { 'copyindent', N_ 'copy whitespace for indenting from previous line' },
    { 'preserveindent', N_ 'preserve kind of whitespace when changing indent' },
    { 'lisp', N_ 'enable lisp mode' },
    { 'lispwords', N_ 'words that change how lisp indenting works' },
    { 'lispoptions', N_ 'options for Lisp indenting' },
  },
  {
    header = N_ 'folding',
    { 'foldenable', N_ 'unset to display all folds open' },
    { 'foldlevel', N_ 'folds with a level higher than this number will be closed' },
    { 'foldlevelstart', N_ "value for 'foldlevel' when starting to edit a file" },
    { 'foldcolumn', N_ 'width of the column used to indicate folds' },
    { 'foldtext', N_ 'expression used to display the text of a closed fold' },
    { 'foldclose', N_ 'set to "all" to close a fold when the cursor leaves it' },
    { 'foldopen', N_ 'specifies for which commands a fold will be opened' },
    { 'foldminlines', N_ 'minimum number of screen lines for a fold to be closed' },
    { 'foldmethod', N_ 'folding type: "manual", "indent", "expr", "marker",\n"syntax" or "diff"' },
    { 'foldexpr', N_ 'expression used when \'foldmethod\' is "expr"' },
    { 'foldignore', N_ 'used to ignore lines when \'foldmethod\' is "indent"' },
    { 'foldmarker', N_ 'markers used when \'foldmethod\' is "marker"' },
    { 'foldnestmax', N_ 'maximum fold depth for when \'foldmethod\' is "indent" or "syntax"' },
  },
  {
    header = N_ 'diff mode',
    { 'diff', N_ 'use diff mode for the current window' },
    { 'diffopt', N_ 'options for using diff mode' },
    { 'diffexpr', N_ 'expression used to obtain a diff file' },
    { 'diffanchors', N_ 'list of addresses for anchoring a diff' },
    { 'patchexpr', N_ 'expression used to patch a file' },
  },
  {
    header = N_ 'mapping',
    { 'maxmapdepth', N_ 'maximum depth of mapping' },
    { 'timeout', N_ 'allow timing out halfway into a mapping' },
    { 'ttimeout', N_ 'allow timing out halfway into a key code' },
    { 'timeoutlen', N_ "time in msec for 'timeout'" },
    { 'ttimeoutlen', N_ "time in msec for 'ttimeout'" },
  },
  {
    header = N_ 'reading and writing files',
    { 'modeline', N_ 'enable using settings from modelines when reading a file' },
    { 'modelineexpr', N_ 'allow setting expression options from a modeline' },
    { 'modelines', N_ 'number of lines to check for modelines' },
    { 'binary', N_ 'binary file editing' },
    { 'endofline', N_ 'last line in the file has an end-of-line' },
    { 'endoffile', N_ 'last line in the file followed by CTRL-Z' },
    { 'fixendofline', N_ 'fixes missing end-of-line at end of text file' },
    { 'bomb', N_ 'prepend a Byte Order Mark to the file' },
    { 'fileformat', N_ 'end-of-line format: "dos", "unix" or "mac"' },
    { 'fileformats', N_ 'list of file formats to look for when editing a file' },
    { 'write', N_ 'writing files is allowed' },
    { 'writebackup', N_ 'write a backup file before overwriting a file' },
    { 'backup', N_ 'keep a backup after overwriting a file' },
    { 'backupskip', N_ 'patterns that specify for which files a backup is not made' },
    { 'backupcopy', N_ 'whether to make the backup as a copy or rename the existing file' },
    { 'backupdir', N_ 'list of directories to put backup files in' },
    { 'backupext', N_ 'file name extension for the backup file' },
    { 'autowrite', N_ 'automatically write a file when leaving a modified buffer' },
    { 'autowriteall', N_ "as 'autowrite', but works with more commands" },
    { 'writeany', N_ 'always write without asking for confirmation' },
    { 'autoread', N_ 'automatically read a file when it was modified outside of Vim' },
    { 'patchmode', N_ 'keep oldest version of a file; specifies file name extension' },
    { 'fsync', N_ 'forcibly sync the file to disk after writing it' },
  },
  {
    header = N_ 'the swap file',
    { 'directory', N_ 'list of directories for the swap file' },
    { 'swapfile', N_ 'use a swap file for this buffer' },
    { 'updatecount', N_ 'number of characters typed to cause a swap file update' },
    { 'updatetime', N_ 'time in msec after which the swap file will be updated' },
  },
  {
    header = N_ 'command line editing',
    { 'history', N_ 'how many command lines are remembered' },
    { 'wildchar', N_ 'key that triggers command-line expansion' },
    { 'wildcharm', N_ "like 'wildchar' but can also be used in a mapping" },
    { 'wildmode', N_ 'specifies how command line completion works' },
    { 'wildoptions', N_ 'empty or "tagfile" to list file name of matching tags' },
    { 'suffixes', N_ 'list of file name extensions that have a lower priority' },
    { 'suffixesadd', N_ 'list of file name extensions added when searching for a file' },
    { 'wildignore', N_ 'list of patterns to ignore files for file name completion' },
    { 'fileignorecase', N_ 'ignore case when using file names' },
    { 'wildignorecase', N_ 'ignore case when completing file names' },
    { 'wildmenu', N_ 'command-line completion shows a list of matches' },
    { 'cedit', N_ 'key used to open the command-line window' },
    { 'cmdwinheight', N_ 'height of the command-line window' },
  },
  {
    header = N_ 'executing external commands',
    { 'shell', N_ 'name of the shell program used for external commands' },
    { 'shellquote', N_ 'character(s) to enclose a shell command in' },
    { 'shellxquote', N_ "like 'shellquote' but include the redirection" },
    { 'shellxescape', N_ "characters to escape when 'shellxquote' is (" },
    { 'shellcmdflag', N_ "argument for 'shell' to execute a command" },
    { 'shellredir', N_ 'used to redirect command output to a file' },
    { 'shelltemp', N_ 'use a temp file for shell commands instead of using a pipe' },
    { 'equalprg', N_ 'program used for "=" command' },
    { 'formatprg', N_ 'program used to format lines with "gq" command' },
    { 'keywordprg', N_ 'program used for the "K" command' },
    { 'warn', N_ 'warn when using a shell command and a buffer has changes' },
  },
  {
    header = N_ 'running make and jumping to errors (quickfix)',
    { 'errorfile', N_ 'name of the file that contains error messages' },
    { 'errorformat', N_ 'list of formats for error messages' },
    { 'makeprg', N_ 'program used for the ":make" command' },
    { 'shellpipe', N_ 'string used to put the output of ":make" in the error file' },
    { 'makeef', N_ "name of the errorfile for the 'makeprg' command" },
    { 'grepprg', N_ 'program used for the ":grep" command' },
    { 'grepformat', N_ "list of formats for output of 'grepprg'" },
    { 'makeencoding', N_ 'encoding of the ":make" and ":grep" output' },
    { 'quickfixtextfunc', N_ 'function to display text in the quickfix window' },
  },
  {
    header = N_ 'system specific',
    { 'shellslash', N_ 'use forward slashes in file names; for Unix-like shells' },
    { 'completeslash', N_ 'specifies slash/backslash used for completion' },
  },
  {
    header = N_ 'language specific',
    { 'isfname', N_ 'specifies the characters in a file name' },
    { 'isident', N_ 'specifies the characters in an identifier' },
    { 'isexpand', N_ 'defines trigger strings for complete_match()' },
    { 'iskeyword', N_ 'specifies the characters in a keyword' },
    { 'isprint', N_ 'specifies printable characters' },
    { 'quoteescape', N_ 'specifies escape characters in a string' },
    { 'rightleft', N_ 'display the buffer right-to-left' },
    { 'rightleftcmd', N_ 'when to edit the command-line right-to-left' },
    { 'revins', N_ 'insert characters backwards' },
    { 'allowrevins', N_ "allow CTRL-_ in Insert and Command-line mode to toggle 'revins'" },
    { 'arabic', N_ 'prepare for editing Arabic text' },
    { 'arabicshape', N_ 'perform shaping of Arabic characters' },
    { 'termbidi', N_ 'terminal will perform bidi handling' },
    { 'keymap', N_ 'name of a keyboard mapping' },
    { 'langmap', N_ 'list of characters that are translated in Normal mode' },
    { 'langremap', N_ "apply 'langmap' to mapped characters" },
    { 'iminsert', N_ 'in Insert mode: 1: use :lmap; 2: use IM; 0: neither' },
    { 'imsearch', N_ 'entering a search pattern: 1: use :lmap; 2: use IM; 0: neither' },
  },
  {
    header = N_ 'multi-byte characters',
    { 'fileencoding', N_ 'character encoding for the current file' },
    { 'fileencodings', N_ 'automatically detected character encodings' },
    { 'charconvert', N_ 'expression used for character encoding conversion' },
    { 'delcombine', N_ 'delete combining (composing) characters on their own' },
    { 'ambiwidth', N_ 'width of ambiguous width characters' },
    { 'emoji', N_ 'emoji characters are full width' },
  },
  {
    header = N_ 'various',
    { 'virtualedit', N_ 'when to use virtual editing: "block", "insert", "all"\nand/or "onemore"' },
    { 'eventignore', N_ 'list of autocommand events which are to be ignored' },
    { 'eventignorewin', N_ 'list of autocommand events which are to be ignored in a window' },
    { 'loadplugins', N_ 'load plugin scripts when starting up' },
    { 'exrc', N_ 'enable reading .vimrc/.exrc/.gvimrc in the current directory' },
    { 'gdefault', N_ 'use the \'g\' flag for ":substitute"' },
    { 'maxfuncdepth', N_ 'maximum depth of function calls' },
    { 'sessionoptions', N_ 'list of words that specifies what to put in a session file' },
    { 'viewoptions', N_ 'list of words that specifies what to save for :mkview' },
    { 'viewdir', N_ 'directory where to store files with :mkview' },
    { 'shada', N_ 'list that specifies what to write in the ShaDa file' },
    { 'shadafile', N_ 'overrides the filename used for shada' },
    { 'bufhidden', N_ "what happens with a buffer when it's no longer in a window" },
    { 'buftype', N_ 'empty, "nofile", "nowrite", "quickfix", etc.: type of buffer' },
    { 'buflisted', N_ 'whether the buffer shows up in the buffer list' },
    { 'debug', N_ 'set to "msg" to see all error messages' },
    { 'signcolumn', N_ 'whether to show the signcolumn' },
    { 'pyxversion', N_ 'whether to use Python 2 or 3' },
    { 'inccommand', N_ 'live preview of substitution' },
    { 'busy', N_ 'buffer is busy' },
    { 'termpastefilter', N_ 'characters removed when pasting into terminal window' },
    { 'scrollback', N_ 'number of lines kept beyond the visible screen in terminal buffer' },
  },
}

local local_to_window = N_ '(local to window)'
local local_to_buffer = N_ '(local to buffer)'
local global_or_local_to_buffer = N_ '(global or local to buffer)'
local global_or_local_to_window = N_ '(global or local to window)'

local lines = {
  N_ '" Each "set" line shows the current value of an option (on the left).',
  N_ '" Hit <Enter> on a "set" line to execute it.',
  N_ '"            A boolean option will be toggled.',
  N_ '"            For other options you can edit the value before hitting <Enter>.',
  N_ '" Hit <Enter> on a help line to open a help window on this option.',
  N_ '" Hit <Enter> on an index line to jump there.',
  N_ '" Hit <Space> on a "set" line to refresh it.',
  '',
}

for header_number, options in ipairs(options_list) do
  table.insert(lines, ('%2d %s'):format(header_number, options.header))
end
table.insert(lines, '')

for header_number, options in ipairs(options_list) do
  table.insert(lines, '')
  table.insert(lines, ('%2d %s'):format(header_number, options.header))
  table.insert(lines, '')
  for _, opt_desc_and_name in ipairs(options) do
    local name, desc = unpack(opt_desc_and_name)

    vim.list_extend(
      lines,
      vim.split(
        ('%s%s\t%s'):format(name, #name >= 15 and '\n' or '', desc:gsub('\n', '\n\t')),
        '\n'
      )
    )

    local info = vim.api.nvim_get_option_info2(name, {})

    if info.scope == 'buf' and info.global_local then
      table.insert(lines, '\t' .. global_or_local_to_buffer)
    elseif info.scope == 'win' and info.global_local then
      table.insert(lines, '\t' .. global_or_local_to_window)
    elseif info.scope == 'buf' then
      table.insert(lines, '\t' .. local_to_buffer)
    elseif info.scope == 'win' then
      table.insert(lines, '\t' .. local_to_window)
    end

    local shortname = info.shortname or name
    if shortname == '' then
      shortname = name
    end

    if info.type == 'boolean' then
      if vim.o[name] then
        table.insert(lines, (' \tset %s\tno%s'):format(shortname, shortname))
      else
        table.insert(lines, (' \tset no%s\t%s'):format(shortname, shortname))
      end
    else
      local value = vim.o[name] --[[@as string]]
      table.insert(lines, (' \tset %s=%s'):format(shortname, value))
    end
  end
end

--- An optwin buffer has 5 types of lines (given pattern):
--- '^".*'       : comment (other)
--- '^ *[0-9]+'  : header (header)
--- '^[^\ts].*'  : option header + description (opt-desc)
--- '^\t.*'      : description continuation (desc-cont)
--- '^ \tset .*' : option set (set)
---
---@param line string
---@return 'set'|'opt-desc'|'desc-cont'|'header'|'other'
local function line_get_type(line)
  if line:find('^ \tset ') then
    return 'set'
  elseif line:find('^%s-[0-9]') then
    return 'header'
  elseif line:find('^\t') then
    return 'desc-cont'
  elseif line:find('^[a-z]') then
    return 'opt-desc'
  end
  return 'other'
end

---@return integer|false
local function find_window_to_have_options_in()
  local thiswin = vim.fn.winnr()
  local altwin = vim.fn.winnr('#')

  if vim.bo[vim.fn.winbufnr(altwin)].filetype == 'help' then
    altwin = altwin + 1
    if altwin == thiswin then
      altwin = altwin + 1 --[[@as integer]]
    end
  end

  if
    altwin == 0
    or altwin == thiswin
    or vim.bo[vim.fn.winbufnr(altwin)].filetype == 'help'
    or vim.fn.winnr('$') < altwin
  then
    vim.notify("Don't know in which window")
    return false
  end

  return vim.fn.win_getid(altwin)
end

local function update_current_line()
  local line = vim.api.nvim_get_current_line()
  if line_get_type(line) ~= 'set' then
    return
  end

  ---@type string
  local name
  if line:find('=') then
    name = line:match('^ \tset (.-)=')
  else
    name = line:match('^ \tset ([a-z]*)'):gsub('^no', '') --[[@as string]]
  end

  local info = vim.api.nvim_get_option_info2(name, {})

  ---@type any
  local value
  if info.global_local or info.scope == 'global' then
    value = vim.o[name] --[[@as any]]
  else
    local win = find_window_to_have_options_in()
    if not win then
      return
    end

    value = vim._with({
      win = win,
    }, function()
      return vim.o[name]
    end)
  end

  if info.type == 'boolean' then
    if value then
      vim.api.nvim_set_current_line((' \tset %s\tno%s'):format(name, name))
    else
      vim.api.nvim_set_current_line((' \tset no%s\t%s'):format(name, name))
    end
  else
    vim.api.nvim_set_current_line((' \tset %s=%s'):format(name, value))
  end
end

local function current_line_set_option()
  local line = vim.api.nvim_get_current_line()
  if line_get_type(line) ~= 'set' then
    return
  end

  ---@type string
  local name
  ---@type string|boolean|integer
  local value
  if line:find('=') then
    name, value = line:match('^ \tset (.-)=(.*)')
  else
    local option = line:match('^ \tset ([a-z]*)')
    name = option:gsub('^no', '') --[[@as string]]
    value = vim.startswith(option, 'no')
  end

  local info = vim.api.nvim_get_option_info2(name, {})

  if info.type == 'number' then
    value = assert(tonumber(value), value .. ' is not a number')
  end

  if info.global_local or info.scope == 'global' then
    ---@diagnostic disable-next-line: no-unknown
    vim.o[name] = value
  else
    local win = find_window_to_have_options_in()
    if not win then
      return
    end

    vim._with({
      win = win,
    }, function()
      ---@diagnostic disable-next-line: no-unknown
      vim.o[name] = value
    end)
  end

  update_current_line()
end

local buf = vim.fn.bufnr('nvim-optwin://optwin')
if buf >= 0 then
  local winids = vim.fn.win_findbuf(buf)
  if #winids > 0 and vim.fn.win_gotoid(winids[1]) == 1 then
    return
  end

  vim.cmd((vim.env.OPTWIN_CMD or '') .. ' new nvim-optwin://optwin')
else
  vim.cmd((vim.env.OPTWIN_CMD or '') .. ' new nvim-optwin://optwin')

  buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].tabstop = 15
  vim.bo[buf].buftype = 'nofile'
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)

  vim.bo[buf].filetype = 'vim'
  vim.cmd [[
  syn match optwinHeader "^ \=[0-9].*"
  syn match optwinName "^[a-z]*\t" nextgroup=optwinComment
  syn match optwinComment ".*" contained
  syn match optwinComment "^\t.*"
  if !exists("did_optwin_syntax_inits")
    let did_optwin_syntax_inits = 1
    hi link optwinHeader Title
    hi link optwinName Identifier
    hi link optwinComment Comment
  endif
  ]]

  vim.keymap.set({ 'n', 'i' }, '<CR>', function()
    local lnum = vim.fn.search('^[^\t]', 'bcWn')
    local line = vim.fn.getline(lnum)

    local line_type = line_get_type(line)

    if line_type == 'set' then
      current_line_set_option()
    elseif line_type == 'header' then
      vim.fn.search(line, 'w')
    elseif line_type == 'opt-desc' then
      local name = line:match('[^\t]*')
      vim.cmd.help(("'%s'"):format(name))
    end
  end, { buffer = buf })

  vim.keymap.set({ 'n', 'i' }, '<space>', update_current_line, { buffer = buf })
end

vim.cmd '1'
