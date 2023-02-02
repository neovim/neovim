" Vim plugin for converting a syntax highlighted file to HTML.
" Maintainer: Ben Fritz <fritzophrenic@gmail.com>
" Last Change: 2023 Jan 01
"
" The core of the code is in $VIMRUNTIME/autoload/tohtml.vim and
" $VIMRUNTIME/syntax/2html.vim
"
if exists('g:loaded_2html_plugin')
  finish
endif
let g:loaded_2html_plugin = 'vim9.0_v1'

"
" Changelog: {{{
"   9.0_v1  (this version): - Implement g:html_no_doc and g:html_no_modeline
"                             for diff mode. Add tests.
"           (Vim 9.0.1122): NOTE: no version string update for this version!
"                           - Bugfix for variable name in g:html_no_doc
"           (Vim 9.0.0819): NOTE: no version string update for this version!
"                           - Add options g:html_no_doc, g:html_no_lines,
"                             and g:html_no_modeline (partially included in Vim
"                             runtime prior to version string update).
"                           - Updates for new Vim9 string append style (i.e. use
"                             ".." instead of ".")
"
"   8.1 updates: {{{
"   8.1_v2  (Vim 8.1.2312): - Fix SourceForge issue #19: fix calculation of tab
"                             stop position to use in expanding a tab, when that
"                             tab occurs after a syntax match which in turn
"                             comes after previously expanded tabs.
"                           - Set eventignore while splitting a window for the
"                             destination file to ignore FileType events;
"                             speeds up processing when the destination file
"                             already exists and HTML highlight takes too long.
"                           - Fix SourceForge issue #20: progress bar could not be
"                             seen when DiffDelete background color matched
"                             StatusLine background color. Added TOhtmlProgress
"                             highlight group for manual user override, but
"                             calculate it to be visible compared to StatusLine
"                             by default.
"                           - Fix SourceForge issue #1: Remove workaround for old
"                             browsers which don't support 'ch' CSS unit, since
"                             all modern browsers, including IE>=9, support it.
"                           - Fix SourceForge issue #10: support termguicolors
"                           - Fix SourceForge issue #21: default to using
"                             generated content instead of <input> tags for
"                             uncopyable text, so that text is correctly
"                             prevented from being copied in chrome. Use
"                             g:html_use_input_for_pc option to control the
"                             method used.
"                           - Switch to HTML5 to allow using vnu as a validator
"                             in unit test.
"                           - Fix fallback sizing of <input> tags for browsers
"                             without "ch" support.
"                           - Fix cursor on unselectable diff filler text.
"   8.1_v1  (Vim 8.1.0528): - Fix SourceForge issue #6: Don't generate empty
"                             script tag.
"                           - Fix SourceForge issue #5: javascript should
"                             declare variables with "var".
"                           - Fix SourceForge issue #13: errors thrown sourcing
"                             2html.vim directly when plugins not loaded.
"                           - Fix SourceForge issue #16: support 'vartabstop'.
"}}}
"
"   7.4 updates: {{{
"   7.4_v2  (Vim 7.4.0899): Fix error raised when converting a diff containing
"                           an empty buffer. Jan Stocker: allow g:html_font to
"                           take a list so it is easier to specfiy fallback
"                           fonts in the generated CSS.
"   7.4_v1  (Vim 7.4.0000): Fix modeline mangling for new "Vim:" format, and
"			    also for version-specific modelines like "vim>703:".
"}}}
"
"   7.3 updates: {{{
"   7.3_v14 (Vim 7.3.1246): Allow suppressing line number anchors using
"			    g:html_line_ids=0. Allow customizing
"			    important IDs (like line IDs and fold IDs) using
"			    g:html_id_expr evaluated when the buffer conversion
"			    is started.
"   7.3_v13 (Vim 7.3.1088): Keep foldmethod at manual in the generated file and
"			    insert modeline to set it to manual.
"			    Fix bug: diff mode with 2 unsaved buffers creates a
"			    duplicate of one buffer instead of including both.
"			    Add anchors to each line so you can put '#L123'
"			    or '#123' at the end of the URL to jump to line 123
"			    (idea by Andy Spencer). Add javascript to open folds
"			    to show the anchor being jumped to if it is hidden.
"			    Fix XML validation error: &nsbp; not part of XML.
"			    Allow TOhtml to chain together with other commands
"			    using |.
"   7.3_v12 (Vim 7.3.0616): Fix modeline mangling to also work for when multiple
"			    highlight groups make up the start-of-modeline text.
"			    Improve render time of page with uncopyable regions
"			    by not using one-input-per-char. Change name of
"			    uncopyable option from html_unselectable to
"			    html_prevent_copy. Added html_no_invalid option and
"			    default to inserting invalid markup for uncopyable
"			    regions to prevent MS Word from pasting undeletable
"			    <input> elements. Fix 'cpo' handling (Thilo Six).
"		 7.3_v12b1: Add html_unselectable option. Rework logic to
"			    eliminate post-processing substitute commands in
"			    favor of doing the work up front. Remove unnecessary
"			    special treatment of 'LineNr' highlight group. Minor
"			    speed improvements. Fix modeline mangling in
"			    generated output so it works for text in the first
"			    column. Fix missing line number and fold column in
"			    diff filler lines. Fix that some fonts have a 1px
"			    gap (using a dirty hack, improvements welcome). Add
"			    "colorscheme" meta tag. Does NOT include support for
"			    the new default foldtext added in v11, as the patch
"			    adding it has not yet been included in Vim.
"   7.3_v11 ( unreleased ): Support new default foldtext from patch by Christian
"			    Brabandt in
"			    http://groups.google.com/d/topic/vim_dev/B6FSGfq9VoI/discussion.
"			    This patch has not yet been included in Vim, thus
"			    these changes are removed in the next version.
"   7.3_v10 (Vim 7.3.0227): Fix error E684 when converting a range wholly inside
"			    multiple nested folds with dynamic folding on.
"			    Also fix problem with foldtext in this situation.
"   7.3_v9  (Vim 7.3.0170): Add html_pre_wrap option active with html_use_css
"			    and without html_no_pre, default value same as
"			    'wrap' option, (Andy Spencer). Don't use
"			    'fileencoding' for converted document encoding if
"			    'buftype' indicates a special buffer which isn't
"			    written.
"   7.3_v8  (Vim 7.3.0100): Add html_expand_tabs option to allow leaving tab
"			    characters in generated output (Andy Spencer).
"			    Escape text that looks like a modeline so Vim
"			    doesn't use anything in the converted HTML as a
"			    modeline. Bugfixes: Fix folding when a fold starts
"			    before the conversion range. Remove fold column when
"			    there are no folds.
"   7.3_v7  (Vim 7-3-0063): see betas released on vim_dev below:
"		  7.3_v7b3: Fixed bug, convert Unicode to UTF-8 all the way.
"		  7.3_v7b2: Remove automatic detection of encodings that are not
"			    supported by all major browsers according to
"			    http://wiki.whatwg.org/wiki/Web_Encodings and
"			    convert to UTF-8 for all Unicode encodings. Make
"			    HTML encoding to Vim encoding detection be
"			    case-insensitive for built-in pairs.
"		  7.3_v7b1: Remove use of setwinvar() function which cannot be
"			    called in restricted mode (Andy Spencer). Use
"			    'fencoding' instead of 'encoding' to determine by
"			    charset, and make sure the 'fenc' of the generated
"			    file matches its indicated charset. Add charsets for
"			    all of Vim's natively supported encodings.
"   7.3_v6  (Vim 7.3.0000): Really fix bug with 'nowrapscan', 'magic' and other
"			    user settings interfering with diff mode generation,
"			    trailing whitespace (e.g. line number column) when
"			    using html_no_pre, and bugs when using
"			    html_hover_unfold.
"   7.3_v5  ( unreleased ): Fix bug with 'nowrapscan' and also with out-of-sync
"			    folds in diff mode when first line was folded.
"   7.3_v4  (Vim 7.3.0000): Bugfixes, especially for xhtml markup, and diff mode
"   7.3_v3  (Vim 7.3.0000): Refactor option handling and make html_use_css
"			    default to true when not set to anything. Use strict
"			    doctypes where possible. Rename use_xhtml option to
"			    html_use_xhtml for consistency. Use .xhtml extension
"			    when using this option. Add meta tag for settings.
"   7.3_v2  (Vim 7.3.0000): Fix syntax highlighting in diff mode to use both the
"			    diff colors and the normal syntax colors
"   7.3_v1  (Vim 7.3.0000): Add conceal support and meta tags in output
"}}}
"}}}

" TODO: {{{
"   * Check the issue tracker:
"     https://sourceforge.net/p/vim-tohtml/issues/search/?q=%21status%3Aclosed
"   * Options for generating the CSS in external style sheets. New :TOcss
"     command to convert the current color scheme into a (mostly) generic CSS
"     stylesheet which can be re-used. Alternate stylesheet support? Good start
"     by Erik Falor
"     ( https://groups.google.com/d/topic/vim_use/7XTmC4D22dU/discussion ).
"   * Add optional argument to :TOhtml command to specify mode (gui, cterm,
"     term) to use for the styling. Suggestion by "nacitar".
"   * Add way to override or specify which RGB colors map to the color numbers
"     in cterm. Get better defaults than just guessing? Suggestion by "nacitar".
"   * Disable filetype detection until after all processing is done.
"   * Add option for not generating the hyperlink on stuff that looks like a
"     URL? Or just color the link to fit with the colorscheme (and only special
"     when hovering)?
"   * Bug: Opera does not allow printing more than one page if uncopyable
"     regions is turned on. Possible solution: Add normal text line numbers with
"     display:none, set to display:inline for print style sheets, and hide
"     <input> elements for print, to allow Opera printing multiple pages (and
"     other uncopyable areas?). May need to make the new text invisible to IE
"     with conditional comments to prevent copying it, IE for some reason likes
"     to copy hidden text. Other browsers too?
"   * Bug: still a 1px gap throughout the fold column when html_prevent_copy is
"     "fn" in some browsers. Specifically, in Chromium on Ubuntu (but not Chrome
"     on Windows). Perhaps it is font related?
"   * Bug: still some gaps in the fold column when html_prevent_copy contains
"     'd' and showing the whole diff (observed in multiple browsers). Only gaps
"     on diff lines though.
"   * Undercurl support via CSS3, with fallback to dotted or something:
"	https://groups.google.com/d/topic/vim_use/BzXA6He1pHg/discussion
"   * Redo updates for modified default foldtext (v11) when/if the patch is
"     accepted to modify it.
"   * Test case +diff_one_file-dynamic_folds+expand_tabs-hover_unfold
"		+ignore_conceal-ignore_folding+no_foldcolumn+no_pre+no_progress
"		+number_lines-pre_wrap-use_css+use_xhtml+whole_filler.xhtml
"     does not show the whole diff filler as it is supposed to?
"   * Bug: when 'isprint' is wrong for the current encoding, will generate
"     invalid content. Can/should anything be done about this? Maybe a separate
"     plugin to correct 'isprint' based on encoding?
"   * Check to see if the windows-125\d encodings actually work in Unix without
"     the 8bit- prefix. Add prefix to autoload dictionaries for Unix if not.
"   * Font auto-detection similar to
"     http://www.vim.org/scripts/script.php?script_id=2384 but for a variety of
"     platforms.
"   * Pull in code from http://www.vim.org/scripts/script.php?script_id=3113 :
"	- listchars support
"	- full-line background highlight
"	- other?
"   * Make it so deleted lines in a diff don't create side-scrolling (get it
"     free with full-line background highlight above).
"   * Restore open/closed folds and cursor position after processing each file
"     with option not to restore for speed increase.
"   * Add extra meta info (generation time, etc.)?
"   * Tidy up so we can use strict doctype in even more situations
"   * Implementation detail: add threshold for writing the lines to the html
"     buffer before we're done (5000 or so lines should do it)
"   * TODO comments for code cleanup scattered throughout
"}}}

" Define the :TOhtml command when:
" - 'compatible' is not set
" - this plugin or user override was not already loaded
" - user commands are available. {{{
if !&cp && !exists(":TOhtml") && has("user_commands")
  command -range=% -bar TOhtml :call tohtml#Convert2HTML(<line1>, <line2>)
endif "}}}

" Make sure any patches will probably use consistent indent
"   vim: ts=8 sw=2 sts=2 noet fdm=marker
