# Netrw.vim

netrw.vim plugin from vim (upstream repository)

The upstream maintained netrw plugin. The original has been created and
maintained by Charles E Campbell and maintained by the vim project until
v9.1.0988.

Every major version a snapshot from here will be sent to the main [Vim][1]
upstream for distribution with Vim.

# License

To see License informations see the LICENSE.txt file included in this
repository.

# Credits

Below are stated the contribution made in the past to netrw.

Changes made to `autoload/netrw.vim`:
- 2023 Nov 21 by Vim Project: ignore wildignore when expanding $COMSPEC (v173a)
- 2023 Nov 22 by Vim Project: fix handling of very long filename on longlist style (v173a)
- 2024 Feb 19 by Vim Project: (announce adoption)
- 2024 Feb 29 by Vim Project: handle symlinks in tree mode correctly
- 2024 Apr 03 by Vim Project: detect filetypes for remote edited files
- 2024 May 08 by Vim Project: cleanup legacy Win9X checks
- 2024 May 09 by Vim Project: remove hard-coded private.ppk
- 2024 May 10 by Vim Project: recursively delete directories by default
- 2024 May 13 by Vim Project: prefer scp over pscp
- 2024 Jun 04 by Vim Project: set bufhidden if buffer changed, nohidden is set and buffer shall be switched (#14915)
- 2024 Jun 13 by Vim Project: glob() on Windows fails when a directory name contains [] (#14952)
- 2024 Jun 23 by Vim Project: save ad restore registers when liststyle = WIDELIST (#15077, #15114)
- 2024 Jul 22 by Vim Project: avoid endless recursion (#15318)
- 2024 Jul 23 by Vim Project: escape filename before trying to delete it (#15330)
- 2024 Jul 30 by Vim Project: handle mark-copy to same target directory (#12112)
- 2024 Aug 02 by Vim Project: honor g:netrw_alt{o,v} for :{S,H,V}explore (#15417)
- 2024 Aug 15 by Vim Project: style changes, prevent E121 (#15501)
- 2024 Aug 22 by Vim Project: fix mf-selection highlight (#15551)
- 2024 Aug 22 by Vim Project: adjust echo output of mx command (#15550)
- 2024 Sep 15 by Vim Project: more strict confirmation dialog (#15680)
- 2024 Sep 19 by Vim Project: mf-selection highlight uses wrong pattern (#15700)
- 2024 Sep 21 by Vim Project: remove extraneous closing bracket (#15718)
- 2024 Oct 21 by Vim Project: remove netrwFileHandlers (#15895)
- 2024 Oct 27 by Vim Project: clean up gx mapping (#15721)
- 2024 Oct 30 by Vim Project: fix filetype detection for remote files (#15961)
- 2024 Oct 30 by Vim Project: fix x mapping on cygwin (#13687)
- 2024 Oct 31 by Vim Project: add netrw#Launch() and netrw#Open() (#15962)
- 2024 Oct 31 by Vim Project: fix E874 when browsing remote dir (#15964)
- 2024 Nov 07 by Vim Project: use keeppatterns to prevent polluting the search history
- 2024 Nov 07 by Vim Project: fix a few issues with netrw tree listing (#15996)
- 2024 Nov 10 by Vim Project: directory symlink not resolved in tree view (#16020)
- 2024 Nov 14 by Vim Project: small fixes to netrw#BrowseX (#16056)
- 2024 Nov 23 by Vim Project: update decompress defaults (#16104)
- 2024 Nov 23 by Vim Project: fix powershell escaping issues (#16094)
- 2024 Dec 04 by Vim Project: do not detach for gvim (#16168)
- 2024 Dec 08 by Vim Project: check the first arg of netrw_browsex_viewer for being executable (#16185)
- 2024 Dec 12 by Vim Project: do not pollute the search history (#16206)
- 2024 Dec 19 by Vim Project: change style (#16248)
- 2024 Dec 20 by Vim Project: change style continued (#16266), fix escaping of # in :Open command (#16265)

General changes made to netrw:

```
	v172:	Sep 02, 2021	* (Bram Moolenaar) Changed "l:go" to "go"
				* (Bram Moolenaar) no need for "b" in
				  netrw-safe guioptions
		Nov 15, 2021	* removed netrw_localrm and netrw_localrmdir
				  references
		Aug 18, 2022	* (Miguel Barro) improving compatibility with
				  powershell
	v171:	Oct 09, 2020	* included code in s:NetrwOptionsSafe()
				  to allow |'bh'| to be set to delete when
				  rather than hide when g:netrw_fastbrowse
				  was zero.
				* Installed |g:netrw_clipboard| setting
				* Installed option bypass for |'guioptions'|
				  a/A settings
				* Changed popup_beval() to |popup_atcursor()|
				  in netrw#ErrorMsg (lacygoill). Apparently
				  popup_beval doesn't reliably close the
				  popup when the mouse is moved.
				* VimEnter() now using win_execute to examine
				  buffers for an attempt to open a directory.
				  Avoids issues with popups/terminal from
				  command line. (lacygoill)
		Jun 28, 2021	* (zeertzjq) provided a patch for use of
				  xmap,xno instead of vmap,vno in
				  netrwPlugin.vim. Avoids entanglement with
				  select mode.
		Jul 14, 2021	* Fixed problem addressed by tst976; opening
				  a file using tree mode, going up a
				  directory, and opening a file there was
				  opening the file in the wrong directory.
		Jul 28, 2021	* (Ingo Karkat) provided a patch fixing an
				  E488 error with netrwPlugin.vim
				  (occurred for vim versions < 8.02)
	v170:	Mar 11, 2020	* (reported by Reiner Herrmann) netrw+tree
				  would not hide with the ^\..* pattern
				  correctly.
				* (Marcin Szamotulski) NetrwOptionRestore
				  did not restore options correctly that
				  had a single quote in the option string.
		Apr 13, 2020	* implemented error handling via popup
				  windows (see |popup_beval()|)
		Apr 30, 2020	* (reported by Manatsu Takahashi) while
				  using Lexplore, a modified file could
				  be overwritten.  Sol'n: will not overwrite,
				  but will emit an |E37| (although one cannot
				  add an ! to override)
		Jun 07, 2020	* (reported by Jo Totland) repeatedly invoking
				  :Lexplore and quitting it left unused
				  hidden buffers.  Netrw will now set netrw
				  buffers created by :Lexplore to |'bh'|=wipe.
	v169:	Dec 20, 2019	* (reported by amkarthik) that netrw's x
				  (|netrw-x|) would throw an error when
				  attempting to open a local directory.
	v168:	Dec 12, 2019	* scp timeout error message not reported,
				  hopefully now fixed (Shane Xb Qian)
	v167:	Nov 29, 2019	* netrw does a save&restore on @* and @+.
				  That causes problems with the clipboard.
				  Now restores occurs only if @* or @+ have
				  been changed.
				* netrw will change @* or @+ less often.
				  Never if I happen to have caught all the
				  operations that modify the unnamed
				  register (which also writes @*).
				* Modified hiding behavior so that "s"
				  will not ignore hiding.
	v166:	Nov 06, 2019	* Removed a space from a nmap for "-"
				* Numerous debugging statement changes
	v163:	Dec 05, 2017	* (Cristi Balan) reported that a setting ('sel')
				  was left changed
				* (Holger Mitschke) reported a problem with
				  saving and restoring history.  Fixed.
				* Hopefully I fixed a nasty bug that caused a
				  file rename to wipe out a buffer that it
				  should not have wiped out.
				* (Holger Mitschke) amended this help file
				  with additional |g:netrw_special_syntax|
				  items
				* Prioritized wget over curl for
				  g:netrw_http_cmd
	v162:	Sep 19, 2016	* (haya14busa) pointed out two syntax errors
				  with a patch; these are now fixed.
		Oct 26, 2016	* I started using mate-terminal and found that
				  x and gx (|netrw-x| and |netrw-gx|) were no
				  longer working.  Fixed (using atril when
				  $DESKTOP_SESSION is "mate").
		Nov 04, 2016	* (Martin Vuille) pointed out that @+ was
				  being restored with keepregstar rather than
				  keepregplus.
		Nov 09, 2016	* Broke apart the command from the options,
				  mostly for Windows.  Introduced new netrw
				  settings: |g:netrw_localcopycmdopt|
				  |g:netrw_localcopydircmdopt|
				  |g:netrw_localmkdiropt|
				  |g:netrw_localmovecmdopt|
		Nov 21, 2016	* (mattn) provided a patch for preview; swapped
				  winwidth() with winheight()
		Nov 22, 2016	* (glacambre) reported that files containing
				  spaces weren't being obtained properly via
				  scp.  Fix: apparently using single quotes
				  such as with 'file name' wasn't enough; the
				  spaces inside the quotes also had to be
				  escaped (ie. 'file\ name').
				* Also fixed obtain (|netrw-O|) to be able to
				  obtain files with spaces in their names
		Dec 20, 2016	* (xc1427) Reported that using "I" (|netrw-I|)
				  when atop "Hiding" in the banner also caused
				  the active-banner hiding control to occur
		Jan 03, 2017	* (Enno Nagel) reported that attempting to
				  apply netrw to a directory that was without
				  read permission caused a syntax error.
		Jan 13, 2017	* (Ingo Karkat) provided a patch which makes
				  using netrw#Call() better.  Now returns
				  value of internal routines return, for example.
		Jan 13, 2017	* (Ingo Karkat) changed netrw#FileUrlRead to
				  use |:edit| instead of |:read|.  I also
				  changed the routine name to netrw#FileUrlEdit.
		Jan 16, 2017	* (Sayem) reported a problem where :Lexplore
				  could generate a new listing buffer and
				  window instead of toggling the netrw display.
				  Unfortunately, the directions for eliciting
				  the problem weren't complete, so I may or
				  may not have fixed that issue.
		Feb 06, 2017	* Implemented cb and cB.  Changed "c" to "cd".
				  (see |netrw-cb|, |netrw-cB|, and |netrw-cd|)
		Mar 21, 2017	* previously, netrw would specify (safe) settings
				  even when the setting was already safe for
				  netrw.  Netrw now attempts to leave such
				  already-netrw-safe settings alone.
				  (affects s:NetrwOptionRestore() and
				  s:NetrwSafeOptions(); also introduced
				  s:NetrwRestoreSetting())
		Jun 26, 2017	* (Christian Brabandt) provided a patch to
				  allow curl to follow redirects (ie. -L
				  option)
		Jun 26, 2017	* (Callum Howard) reported a problem with
				  :Lexpore not removing the Lexplore window
				  after a change-directory
		Aug 30, 2017	* (Ingo Karkat) one cannot switch to the
				  previously edited file (e.g. with CTRL-^)
				  after editing a file:// URL.  Patch to
				  have a "keepalt" included.
		Oct 17, 2017	* (Adam Faryna) reported that gn (|netrw-gn|)
				  did not work on directories in the current
				  tree
	v157:	Apr 20, 2016	* (Nicola) had set up a "nmap <expr> ..." with
				  a function that returned a 0 while silently
				  invoking a shell command.  The shell command
				  activated a ShellCmdPost event which in turn
				  called s:LocalBrowseRefresh().  That looks
				  over all netrw buffers for changes needing
				  refreshes.  However, inside a |:map-<expr>|,
				  tab and window changes are disallowed.  Fixed.
				  (affects netrw's s:LocalBrowseRefresh())
				* g:netrw_localrmdir not used any more, but
				  the relevant patch that causes |delete()| to
				  take over was #1107 (not #1109).
				* |expand()| is now used on |g:netrw_home|;
				  consequently, g:netrw_home may now use
				  environment variables
				* s:NetrwLeftmouse and s:NetrwCLeftmouse will
				  return without doing anything if invoked
				  when inside a non-netrw window
		Jun 15, 2016	* gx now calls netrw#GX() which returns
				  the word under the cursor.  The new
				  wrinkle: if one is in a netrw buffer,
				  then netrw's s:NetrwGetWord().
		Jun 22, 2016	* Netrw was executing all its associated
				  Filetype commands silently; I'm going
				  to try doing that "noisily" and see if
				  folks have a problem with that.
		Aug 12, 2016	* Changed order of tool selection for
				  handling http://... viewing.
				  (Nikolay Aleksandrovich Pavlov)
		Aug 21, 2016	* Included hiding/showing/all for tree
				  listings
				* Fixed refresh (^L) for tree listings
	v156:	Feb 18, 2016	* Changed =~ to =~# where appropriate
		Feb 23, 2016	* s:ComposePath(base,subdir) now uses
				  fnameescape() on the base portion
		Mar 01, 2016	* (gt_macki) reported where :Explore would
				  make file unlisted. Fixed (tst943)
		Apr 04, 2016	* (reported by John Little) netrw normally
				  suppresses browser messages, but sometimes
				  those "messages" are what is wanted.
				  See |g:netrw_suppress_gx_mesg|
		Apr 06, 2016	* (reported by Carlos Pita) deleting a remote
				  file was giving an error message.  Fixed.
		Apr 08, 2016	* (Charles Cooper) had a problem with an
				  undefined b:netrw_curdir.  He also provided
				  a fix.
		Apr 20, 2016	* Changed s:NetrwGetBuffer(); now uses
				  dictionaries.  Also fixed the "No Name"
				  buffer problem.
	v155:	Oct 29, 2015	* (Timur Fayzrakhmanov) reported that netrw's
				  mapping of ctrl-l was not allowing refresh of
				  other windows when it was done in a netrw
				  window.
		Nov 05, 2015	* Improved s:TreeSqueezeDir() to use search()
				  instead of a loop
				* NetrwBrowse() will return line to
				  w:netrw_bannercnt if cursor ended up in
				  banner
		Nov 16, 2015	* Added a <Plug>NetrwTreeSqueeze (|netrw-s-cr|)
		Nov 17, 2015	* Commented out imaps -- perhaps someone can
				  tell me how they're useful and should be
				  retained?
		Nov 20, 2015	* Added |netrw-ma| and |netrw-mA| support
		Nov 20, 2015	* gx (|netrw-gx|) on a URL downloaded the
				  file in addition to simply bringing up the
				  URL in a browser.  Fixed.
		Nov 23, 2015	* Added |g:netrw_sizestyle| support
		Nov 27, 2015	* Inserted a lot of <c-u>s into various netrw
				  maps.
		Jan 05, 2016	* |netrw-qL| implemented to mark files based
				  upon |location-list|s; similar to |netrw-qF|.
		Jan 19, 2016	* using - call delete(directoryname,"d") -
				  instead of using g:netrw_localrmdir if
				  v7.4 + patch#1107 is available
		Jan 28, 2016	* changed to using |winsaveview()| and
				  |winrestview()|
		Jan 28, 2016	* s:NetrwTreePath() now does a save and
				  restore of view
		Feb 08, 2016	* Fixed a tree-listing problem with remote
				  directories
	v154:	Feb 26, 2015	* (Yuri Kanivetsky) reported a situation where
				  a file was not treated properly as a file
				  due to g:netrw_keepdir == 1
		Mar 25, 2015	* (requested by Ben Friz) one may now sort by
				  extension
		Mar 28, 2015	* (requested by Matt Brooks) netrw has a lot
				  of buffer-local mappings; however, some
				  plugins (such as vim-surround) set up
				  conflicting mappings that cause vim to wait.
				  The "<nowait>" modifier has been included
				  with most of netrw's mappings to avoid that
				  delay.
		Jun 26, 2015	* |netrw-gn| mapping implemented
				* :Ntree NotADir resulted in having
				  the tree listing expand in the error messages
				  window.  Fixed.
		Jun 29, 2015	* Attempting to delete a file remotely caused
				  an error with "keepsol" mentioned; fixed.
		Jul 08, 2015	* Several changes to keep the |:jumps| table
				  correct when working with
				  |g:netrw_fastbrowse| set to 2
				* wide listing with accented characters fixed
				  (using %-S instead of %-s with a |printf()|
		Jul 13, 2015	* (Daniel Hahler) CheckIfKde() could be true
				  but kfmclient not installed.  Changed order
				  in netrw#BrowseX(): checks if kde and
				  kfmclient, then will use xdg-open on a unix
				  system (if xdg-open is executable)
		Aug 11, 2015	* (McDonnell) tree listing mode wouldn't
				  select a file in a open subdirectory.
				* (McDonnell) when multiple subdirectories
				  were concurrently open in tree listing
				  mode, a ctrl-L wouldn't refresh properly.
				* The netrw:target menu showed duplicate
				  entries
		Oct 13, 2015	* (mattn) provided an exception to handle
				  windows with shellslash set but no shell
		Oct 23, 2015	* if g:netrw_usetab and <c-tab> now used
				  to control whether NetrwShrink is used
				  (see |netrw-c-tab|)
	v153:	May 13, 2014	* added another |g:netrw_ffkeep| usage {{{2
		May 14, 2014	* changed s:PerformListing() so that it
				  always sets ft=netrw for netrw buffers
				  (ie. even when syntax highlighting is
				  off, not available, etc)
		May 16, 2014	* introduced the |netrw-ctrl-r| functionality
		May 17, 2014	* introduced the |netrw-:NetrwMB| functionality
				* mb and mB (|netrw-mb|, |netrw-mB|) will
				  add/remove marked files from bookmark list
		May 20, 2014	* (Enno Nagel) reported that :Lex <dirname>
				  wasn't working.  Fixed.
		May 26, 2014	* restored test to prevent leftmouse window
				  resizing from causing refresh.
				  (see s:NetrwLeftmouse())
				* fixed problem where a refresh caused cursor
				  to go just under the banner instead of
				  staying put
		May 28, 2014	* (László Bimba) provided a patch for opening
				  the |:Lexplore| window 100% high, optionally
				  on the right, and will work with remote
				  files.
		May 29, 2014	* implemented :NetrwC  (see |netrw-:NetrwC|)
		Jun 01, 2014	* Removed some "silent"s from commands used
				  to implemented scp://... and pscp://...
				  directory listing.  Permits request for
				  password to appear.
		Jun 05, 2014	* (Enno Nagel) reported that user maps "/"
				  caused problems with "b" and "w", which
				  are mapped (for wide listings only) to
				  skip over files rather than just words.
		Jun 10, 2014	* |g:netrw_gx| introduced to allow users to
				  override default "<cfile>" with the gx
				  (|netrw-gx|) map
		Jun 11, 2014	* gx (|netrw-gx|), with |'autowrite'| set,
				  will write modified files.  s:NetrwBrowseX()
				  will now save, turn off, and restore the
				  |'autowrite'| setting.
		Jun 13, 2014	* added visual map for gx use
		Jun 15, 2014	* (Enno Nagel) reported that with having hls
				  set and wide listing style in use, that the
				  b and w maps caused unwanted highlighting.
		Jul 05, 2014	* |netrw-mv| and |netrw-mX| commands included
		Jul 09, 2014	* |g:netrw_keepj| included, allowing optional
				  keepj
		Jul 09, 2014	* fixing bugs due to previous update
		Jul 21, 2014	* (Bruno Sutic) provided an updated
				  netrw_gitignore.vim
		Jul 30, 2014	* (Yavuz Yetim) reported that editing two
				  remote files of the same name caused the
				  second instance to have a "temporary"
				  name.  Fixed: now they use the same buffer.
		Sep 18, 2014	* (Yasuhiro Matsumoto) provided a patch which
				  allows scp and windows local paths to work.
		Oct 07, 2014	* gx (see |netrw-gx|) when atop a directory,
				  will now do |gf| instead
		Nov 06, 2014	* For cygwin: cygstart will be available for
				  netrw#BrowseX() to use if its executable.
		Nov 07, 2014	* Began support for file://... urls.  Will use
				  |g:netrw_file_cmd| (typically elinks or links)
		Dec 02, 2014	* began work on having mc (|netrw-mc|) copy
				  directories.  Works for linux machines,
				  cygwin+vim, but not for windows+gvim.
		Dec 02, 2014	* in tree mode, netrw was not opening
				  directories via symbolic links.
		Dec 02, 2014	* added resolved link information to
				  thin and tree modes
		Dec 30, 2014	* (issue#231) |:ls| was not showing
				  remote-file buffers reliably.  Fixed.
	v152:	Apr 08, 2014	* uses the |'noswapfile'| option (requires {{{2
				  vim 7.4 with patch 213)
				* (Enno Nagel) turn |'rnu'| off in netrw
				  buffers.
				* (Quinn Strahl) suggested that netrw
				  allow regular window splitting to occur,
				  thereby allowing |'equalalways'| to take
				  effect.
				* (qingtian zhao) normally, netrw will
				  save and restore the |'fileformat'|;
				  however, sometimes that isn't wanted
		Apr 14, 2014	* whenever netrw marks a buffer as ro,
				  it will also mark it as nomod.
		Apr 16, 2014	* sftp protocol now supported by
				  netrw#Obtain(); this means that one
				  may use "mc" to copy a remote file
				  to a local file using sftp, and that
				  the |netrw-O| command can obtain remote
				  files via sftp.
				* added [count]C support (see |netrw-C|)
		Apr 18, 2014	* when |g:netrw_chgwin| is one more than
				  the last window, then vertically split
				  the last window and use it as the
				  chgwin window.
		May 09, 2014	* SavePosn was "saving filename under cursor"
				  from a non-netrw window when using :Rex.
	v151:	Jan 22, 2014	* extended :Rexplore to return to buffer {{{2
				  prior to Explore or editing a directory
				* (Ken Takata) netrw gave error when
				  clipboard was disabled.  Sol'n: Placed
				  several if has("clipboard") tests in.
				* Fixed ftp://X@Y@Z// problem; X@Y now
				  part of user id, and only Z is part of
				  hostname.
				* (A Loumiotis) reported that completion
				  using a directory name containing spaces
				  did not work.  Fixed with a retry in
				  netrw#Explore() which removes the
				  backslashes vim inserted.
		Feb 26, 2014	* :Rexplore now records the current file
				   using w:netrw_rexfile when returning via
				  |:Rexplore|
		Mar 08, 2014	* (David Kotchan) provided some patches
				  allowing netrw to work properly with
				  windows shares.
				* Multiple one-liner help messages available
				  by pressing <cr> while atop the "Quick
				  Help" line
				* worked on ShellCmdPost, FocusGained event
				  handling.
				* |:Lexplore| path: will be used to update
				  a left-side netrw browsing directory.
		Mar 12, 2014	* |netrw-s-cr|: use <s-cr>  to close
				  tree directory implemented
		Mar 13, 2014	* (Tony Mechylynck) reported that using
				  the browser with ftp on a directory,
				  and selecting a gzipped txt file, that
				  an E19 occurred (which was issued by
				  gzip.vim).  Fixed.
		Mar 14, 2014	* Implemented :MF and :MT (see |netrw-:MF|
				  and |netrw-:MT|, respectively)
		Mar 17, 2014	* |:Ntree| [dir] wasn't working properly; fixed
		Mar 18, 2014	* Changed all uses of set to setl
		Mar 18, 2014	* Commented the netrw_btkeep line in
				  s:NetrwOptionSave(); the effect is that
				  netrw buffers will remain as |'bt'|=nofile.
				  This should prevent swapfiles being created
				  for netrw buffers.
		Mar 20, 2014	* Changed all uses of lcd to use s:NetrwLcd()
				  instead.  Consistent error handling results
				  and it also handles Window's shares
				* Fixed |netrw-d| command when applied with ftp
				* https: support included for netrw#NetRead()
	v150:	Jul 12, 2013	* removed a "keepalt" to allow ":e #" to {{{2
				  return to the netrw directory listing
		Jul 13, 2013	* (Jonas Diemer) suggested changing
				  a <cWORD> to <cfile>.
		Jul 21, 2013	* (Yuri Kanivetsky) reported that netrw's
				  use of mkdir did not produce directories
				  following the user's umask.
		Aug 27, 2013	* introduced |g:netrw_altfile| option
		Sep 05, 2013	* s:Strlen() now uses |strdisplaywidth()|
				  when available, by default
		Sep 12, 2013	* (Selyano Baldo) reported that netrw wasn't
				  opening some directories properly from the
				  command line.
		Nov 09, 2013	* |:Lexplore| introduced
				* (Ondrej Platek) reported an issue with
				  netrw's trees (P15).  Fixed.
				* (Jorge Solis) reported that "t" in
				  tree mode caused netrw to forget its
				  line position.
		Dec 05, 2013	* Added <s-leftmouse> file marking
				  (see |netrw-mf|)
		Dec 05, 2013	* (Yasuhiro Matsumoto) Explore should use
				  strlen() instead s:Strlen() when handling
				  multibyte chars with strpart()
				  (ie. strpart() is byte oriented, not
				  display-width oriented).
		Dec 09, 2013	* (Ken Takata) Provided a patch; File sizes
				  and a portion of timestamps were wrongly
				  highlighted with the directory color when
				  setting `:let g:netrw_liststyle=1` on Windows.
				* (Paul Domaskis) noted that sometimes
				  cursorline was activating in non-netrw
				  windows.  All but one setting of cursorline
				  was done via setl; there was one that was
				  overlooked.  Fixed.
		Dec 24, 2013	* (esquifit) asked that netrw allow the
				  /cygdrive prefix be a user-alterable
				  parameter.
		Jan 02, 2014	* Fixed a problem with netrw-based ballon
				  evaluation (ie. netrw#NetrwBaloonHelp()
				  not having been loaded error messages)
		Jan 03, 2014	* Fixed a problem with tree listings
				* New command installed: |:Ntree|
		Jan 06, 2014	* (Ivan Brennan) reported a problem with
				  |netrw-P|.  Fixed.
		Jan 06, 2014	* Fixed a problem with |netrw-P| when the
				  modified file was to be abandoned.
		Jan 15, 2014	* (Matteo Cavalleri) reported that when the
				  banner is suppressed and tree listing is
				  used, a blank line was left at the top of
				  the display.  Fixed.
		Jan 20, 2014	* (Gideon Go) reported that, in tree listing
				  style, with a previous window open, that
				  the wrong directory was being used to open
				  a file.  Fixed. (P21)
	v149:	Apr 18, 2013	* in wide listing format, now have maps for {{{2
				  w and b to move to next/previous file
		Apr 26, 2013	* one may now copy files in the same
				  directory; netrw will issue requests for
				  what names the files should be copied under
		Apr 29, 2013	* Trying Benzinger's problem again.  Seems
				  that commenting out the BufEnter and
				  installing VimEnter (only) works.  Weird
				  problem!  (tree listing, vim -O Dir1 Dir2)
		May 01, 2013	* :Explore ftp://... wasn't working.  Fixed.
		May 02, 2013	* introduced |g:netrw_bannerbackslash| as
				  requested by Paul Domaskis.
		Jul 03, 2013	* Explore now avoids splitting when a buffer
				  will be hidden.
	v148:	Apr 16, 2013	* changed Netrw's Style menu to allow direct {{{2
				  choice of listing style, hiding style, and
				  sorting style
```

[1]: https://github.com/vim/vim
