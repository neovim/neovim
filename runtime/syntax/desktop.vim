" Vim syntax file
" Language: XDG desktop entry
" Filenames: *.desktop, *.directory
" Maintainer: Eisuke Kawashima ( e.kawaschima+vim AT gmail.com )
" Previous Maintainer: Mikolaj Machowski ( mikmach AT wp DOT pl )
" Last Change: 2020-06-11
" Version Info: desktop.vim 1.5
" References:
" - https://specifications.freedesktop.org/desktop-entry-spec/desktop-entry-spec-1.5.html (2020-04-27)
" - https://specifications.freedesktop.org/icon-theme-spec/icon-theme-spec-0.11.html (2006-02-07)

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim
syn case match

" Variable {{{1
" This syntax file can be used to all *nix configuration files similar to dos
" ini format (eg. .xawtv, .radio, kde rc files) - this is default mode.
" By default strict following of freedesktop.org standard is enforced.
" To highlight nonstandard extensions that does not begin with X-, set
"   let g:desktop_enable_nonstd = v:true
" Note that this may cause wrong highlight.
" To highlight KDE-reserved features, set
"   let g:desktop_enable_kde = v:true
" g:desktop_enable_kde follows g:desktop_enable_nonstd if not supplied

if exists("g:desktop_enable_nonstd") && g:desktop_enable_nonstd
  let s:desktop_enable_nonstd = v:true
else
  let s:desktop_enable_nonstd = v:false
endif

if exists("g:desktop_enable_kde") && g:desktop_enable_kde || s:desktop_enable_nonstd
  let s:desktop_enable_kde = v:true
else
  let s:desktop_enable_kde = v:false
endif

" Comment {{{1
syn match dtComment /^#.*$/

" Error {{{1
syn match dtError /\%(^\s.*\|\s\+$\)/

" Group Header {{{1
" ASCII printable characters except for brackets [ (0x5B) and ] (0x5D)
syn match dtGroup /^\[[\x20-\x5A\x5C\x5E-\x7E]\+\]$/

" Entries {{{1
syn match dtDelim /=/ contained
" lang_territory.codeset@modifier
syn match dtLocaleSuffix
      \ /\[\%(C\|POSIX\|[a-z]\{2,4}\%(_[A-Z0-9]\{2,3}\)\?\)\%(\.[A-Za-z0-9_-]\+\)\?\%(@[A-Za-z]\+\)\?\]\ze\s*=/
      \ contained

" Boolean Value {{{2
syn match   dtBoolean
      \ /^\%(DBusActivatable\|Hidden\|NoDisplay\|PrefersNonDefaultGPU\|StartupNotify\|Terminal\)\s*=\s*\%(true\|false\)/
      \ contains=dtBooleanKey,dtDelim,dtBooleanValue transparent
syn keyword dtBooleanKey
      \ DBusActivatable Hidden NoDisplay PrefersNonDefaultGPU StartupNotify Terminal
      \ contained nextgroup=dtDelim

if s:desktop_enable_kde
  syn match   dtBoolean
        \ /^ReadOnly\s*=\s*\%(true\|false\)/
        \ contains=dtBooleanKey,dtDelim,dtBooleanValue transparent
  syn keyword dtBooleanKey
        \ ReadOnly
        \ contained nextgroup=dtDelim
endif
syn keyword dtBooleanValue true false contained

" Numeric Value {{{2
" icon theme
syn match   dtNumeric /^\%(MaxSize\|MinSize\|Size\|Threshold\)\s*=\s*\d\+/ contains=dtNumericKey,dtDelim,dtNumericDecimal
syn keyword dtNumericKey
      \ MaxSize MinSize Size Threshold
      \ contained nextgroup=dtDelim

if s:desktop_enable_kde
  syn match   dtNumeric /^InitialPreference\s*=\s*\d\+/ contains=dtNumericKey,dtDelim,dtNumericDecimal
  syn keyword dtNumericKey
        \ InitialPreference
        \ contained nextgroup=dtDelim
endif

syn match   dtNumericDecimal /\<\d\+$/ contained

" String Value {{{2
syn match   dtString
      \ /^\%(Actions\|Implements\|MimeType\|NotShowIn\|OnlyShowIn\|Path\|StartupWMClass\|URL\)\s*=.*\S/
      \ contains=dtStringKey,dtDelim transparent
syn keyword dtStringKey
      \ Actions Implements MimeType NotShowIn OnlyShowIn Path StartupWMClass URL Version
      \ contained nextgroup=dtDelim

" icon theme
syn match   dtString
      \ /^\%(Context\|Directories\|Example\|Inherits\)\s*=.*\S/
      \ contains=dtStringKey,dtDelim transparent
syn keyword dtStringKey
      \ Context Directories Example Inherits
      \ contained nextgroup=dtDelim

if s:desktop_enable_kde
  syn match   dtString
        \ /^\%(Dev\|DocPath\|FSType\|MountPoint\|ServiceTypes\)\s*=.*\S/
        \ contains=dtStringKey,dtDelim transparent
  syn keyword dtStringKey
        \ Dev DocPath FSType MountPoint ServiceTypes
        \ contained nextgroup=dtDelim
endif

" Categories {{{3
" https://specifications.freedesktop.org/menu-spec/menu-spec-1.0.html#category-registry
syn match   dtCategories /^Categories\s*=.\+\S/ contains=dtCategoriesKey,dtDelim,dtCategoriesValue transparent
syn keyword dtCategoriesKey
      \ Categories
      \ contained nextgroup=dtDelim

" Main Categories
syn keyword dtCategoriesValue
      \ Audio AudioVideo Development Education Game Graphics Network Office
      \ Settings System Utility Video
      \ contained

" Additional Categories
syn keyword dtCategoriesValue
      \ BoardGame Chat Clock Geoscience Presentation 2DGraphics 3DGraphics
      \ Accessibility ActionGame AdventureGame Amusement ArcadeGame Archiving
      \ Art ArtificialIntelligence Astronomy AudioVideoEditing Biology
      \ BlocksGame BoardGame Building Calculator Calendar CardGame Chart Chat
      \ Chemistry Clock Compression ComputerScience ConsoleOnly Construction
      \ ContactManagement Core DataVisualization Database Debugger
      \ DesktopSettings Dialup Dictionary DiscBurning Documentation Economy
      \ Electricity Electronics Email Emulator Engineering FileManager
      \ FileTools FileTransfer Filesystem Finance FlowChart GNOME GTK
      \ GUIDesigner Geography Geology Geoscience HamRadio HardwareSettings
      \ History IDE IRCClient ImageProcessing InstantMessaging Java KDE
      \ KidsGame Languages Literature LogicGame Math MedicalSoftware Midi
      \ Mixer Monitor Motif Music News NumericalAnalysis OCR P2P PDA
      \ PackageManager ParallelComputing Photography Physics Player
      \ Presentation Printing Profiling ProjectManagement Publishing Qt
      \ RasterGraphics Recorder RemoteAccess RevisionControl Robotics
      \ RolePlaying Scanning Science Security Sequencer Simulation Sports
      \ SportsGame Spreadsheet StrategyGame TV Telephony TelephonyTools
      \ TerminalEmulator TextEditor TextTools Translation Tuner VectorGraphics
      \ VideoConference Viewer WebBrowser WebDevelopment WordProcessor
      \ contained

" Reserved Category
syn keyword dtCategoriesValue
      \ Applet Screensaver Shell TrayIcon
      \ contained

" Exec/TryExec {{{3
syn match   dtExec /^\%(Exec\|TryExec\)\s*=.\+\S/ contains=dtExecKey,dtDelim,dtExecParam transparent
syn keyword dtExecKey
      \ Exec TryExec
      \ contained nextgroup=dtDelim
" code for file(s), URL(s), etc
syn match   dtExecParam  /\s\zs%[fFuUick]\ze\%(\W\|$\)/ contained

" Type {{{3
syn match   dtType /^Type\s*=\s*\S\+/ contains=dtTypeKey,dtDelim,dtTypeValue transparent
syn keyword dtTypeKey
      \ Type
      \ contained nextgroup=dtDelim
syn keyword dtTypeValue
      \ Application Directory Link
      \ contained

if s:desktop_enable_kde
  syn keyword dtTypeValue
        \ FSDevice Service ServiceType
        \ contained
endif


" Version {{{3
syn match   dtVersion /^Version\s*=\s*\S\+/ contains=dtVersionKey,dtDelim,dtVersionValue transparent
syn keyword dtVersionKey
      \ Version
      \ contained nextgroup=dtDelim
syn match   dtVersionValue /[0-9]\+\%(\.[0-9]\+\)\{1,2}$/ contained

" Localestring Value {{{2
syn match   dtLocalestring
      \ /^\%(Comment\|GenericName\|Keywords\|Name\)\%(\[.\{-}\]\)\?\s*=.*\S/
      \ contains=dtLocalestringKey,dtLocaleSuffix,dtDelim transparent
syn keyword dtLocalestringKey
      \ Comment GenericName Keywords Name
      \ contained nextgroup=dtLocaleSuffix,dtDelim skipwhite

" Iconstring Value {{{2
syn match   dtIconstring
      \ /^Icon\s*=.*\S/
      \ contains=dtIconstringKey,dtDelim transparent
syn keyword dtIconstringKey
      \ Icon
      \ contained nextgroup=dtDelim skipwhite

if s:desktop_enable_kde
  syn match   dtIconstring
        \ /^UnmountIcon\>\%(\[.\{-}\]\)\?\s*=.*\S/
        \ contains=dtIconstringKey,dtLocaleSuffix,dtDelim transparent
  syn keyword dtIconstringKey
        \ UnmountIcon
        \ contained nextgroup=dtLocaleSuffix,dtDelim skipwhite
endif

" X-Extension {{{2
syn match   dtXExtension    /^X-[0-9A-Za-z-]*\%(\[.\{-}\]\)\?\s*=.*\S/
      \ contains=dtXExtensionKey,dtLocaleSuffix,dtDelim transparent
syn match   dtXExtensionKey /^X-[0-9A-Za-z-]*/ contained nextgroup=dtLocaleSuffix,dtDelim

" non standard {{{2
if s:desktop_enable_nonstd
  syn match dtNonStdLabel    /^[0-9A-Za-z-]\+\%(\[.\{-}\]\)\?\s*=.*\S/
        \ contains=dtNonStdLabelKey,dtLocaleSuffix,dtDelim transparent
  syn match dtNonStdLabelKey /^[0-9A-Za-z-]\+/ contained nextgroup=dtLocaleSuffix,dtDelim
endif

" Highlight {{{1
hi def link dtComment		Comment
hi def link dtError		Error

hi def link dtGroup		Special

hi def link dtDelim		Delimiter
hi def link dtLocaleSuffix	Identifier

hi def link dtBooleanKey	Type
hi def link dtBooleanValue	Boolean

hi def link dtNumericKey	Type
hi def link dtNumericDecimal	Number

hi def link dtStringKey		Type
hi def link dtCategoriesKey	Type
hi def link dtCategoriesValue	Constant
hi def link dtExecKey		Type
hi def link dtExecParam		Special
hi def link dtTypeKey		Type
hi def link dtTypeValue		Constant
hi def link dtVersionKey	Type
hi def link dtVersionValue	Constant

hi def link dtLocalestringKey	Type

hi def link dtIconStringKey	Type

hi def link dtXExtensionKey	Type

hi def link dtNonStdLabelKey	Type

" Clean Up {{{1
let b:current_syntax = "desktop"
let &cpo = s:cpo_save

" vim:ts=8:sw=2:fdm=marker
