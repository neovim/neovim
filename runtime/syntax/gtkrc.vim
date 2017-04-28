" Vim syntax file
" This is a GENERATED FILE. Please always refer to source file at the URI below.
" Language: Gtk+ theme files `gtkrc'
" Maintainer: David Ne\v{c}as (Yeti) <yeti@physics.muni.cz>
" Last Change: 2002-10-31
" URL: http://trific.ath.cx/Ftp/vim/syntax/gtkrc.vim

" Setup
" quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

setlocal iskeyword=_,-,a-z,A-Z,48-57

syn case match

" Base constructs
syn match gtkrcComment "#.*$" contains=gtkrcFixme
syn keyword gtkrcFixme FIXME TODO XXX NOT contained
syn region gtkrcACString start=+"+ skip=+\\\\\|\\"+ end=+"+ oneline contains=gtkrcWPathSpecial,gtkrcClassName,gtkrcClassNameGnome contained
syn region gtkrcBString start=+"+ skip=+\\\\\|\\"+ end=+"+ oneline contains=gtkrcKeyMod contained
syn region gtkrcString start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=gtkrcStockName,gtkrcPathSpecial,gtkrcRGBColor
syn match gtkrcPathSpecial "<parent>" contained
syn match gtkrcWPathSpecial "[*?.]" contained
syn match gtkrcNumber "^\(\d\+\)\=\.\=\d\+"
syn match gtkrcNumber "\W\(\d\+\)\=\.\=\d\+"lc=1
syn match gtkrcRGBColor "#\(\x\{12}\|\x\{9}\|\x\{6}\|\x\{3}\)" contained
syn cluster gtkrcPRIVATE add=gtkrcFixme,gtkrcPathSpecial,gtkrcWPathSpecial,gtkrcRGBColor,gtkrcACString

" Keywords
syn keyword gtkrcInclude include
syn keyword gtkrcPathSet module_path pixmap_path
syn keyword gtkrcTop binding style
syn keyword gtkrcTop widget widget_class nextgroup=gtkrcACString skipwhite
syn keyword gtkrcTop class nextgroup=gtkrcACString skipwhite
syn keyword gtkrcBind bind nextgroup=gtkrcBString skipwhite
syn keyword gtkrcStateName NORMAL INSENSITIVE PRELIGHT ACTIVE SELECTED
syn keyword gtkrcPriorityName HIGHEST RC APPLICATION GTK LOWEST
syn keyword gtkrcPriorityName highest rc application gtk lowest
syn keyword gtkrcTextDirName LTR RTL
syn keyword gtkrcStyleKeyword fg bg fg_pixmap bg_pixmap bg_text base font font_name fontset stock text
syn match gtkrcKeyMod "<\(alt\|ctrl\|control\|mod[1-5]\|release\|shft\|shift\)>" contained
syn cluster gtkrcPRIVATE add=gtkrcKeyMod

" Enums and engine words
syn keyword gtkrcKeyword engine image
syn keyword gtkrcImage arrow_direction border detail file gap_border gap_end_border gap_end_file gap_file gap_side gap_side gap_start_border gap_start_file orientation overlay_border overlay_file overlay_stretch recolorable shadow state stretch thickness
syn keyword gtkrcConstant TRUE FALSE NONE IN OUT LEFT RIGHT TOP BOTTOM UP DOWN VERTICAL HORIZONTAL ETCHED_IN ETCHED_OUT
syn keyword gtkrcFunction function nextgroup=gtkrcFunctionEq skipwhite
syn match gtkrcFunctionEq "=" nextgroup=gtkrcFunctionName contained skipwhite
syn keyword gtkrcFunctionName ARROW BOX BOX_GAP CHECK CROSS DIAMOND EXTENSION FLAT_BOX FOCUS HANDLE HLINE OPTION OVAL POLYGON RAMP SHADOW SHADOW_GAP SLIDER STRING TAB VLINE contained
syn cluster gtkrcPRIVATE add=gtkrcFunctionName,gtkrcFunctionEq

" Class names
syn keyword gtkrcClassName GtkAccelLabel GtkAdjustment GtkAlignment GtkArrow GtkAspectFrame GtkBin GtkBox GtkButton GtkButtonBox GtkCList GtkCTree GtkCalendar GtkCheckButton GtkCheckMenuItem GtkColorSelection GtkColorSelectionDialog GtkCombo GtkContainer GtkCurve GtkData GtkDialog GtkDrawingArea GtkEditable GtkEntry GtkEventBox GtkFileSelection GtkFixed GtkFontSelection GtkFontSelectionDialog GtkFrame GtkGammaCurve GtkHBox GtkHButtonBox GtkHPaned GtkHRuler GtkHScale GtkHScrollbar GtkHSeparator GtkHandleBox GtkImage GtkImageMenuItem GtkInputDialog GtkInvisible GtkItem GtkItemFactory GtkLabel GtkLayout GtkList GtkListItem GtkMenu GtkMenuBar GtkMenuItem GtkMenuShell GtkMessageDialog GtkMisc GtkNotebook GtkObject GtkOptionMenu GtkPacker GtkPaned GtkPixmap GtkPlug GtkPreview GtkProgress GtkProgressBar GtkRadioButton GtkRadioMenuItem GtkRange GtkRuler GtkScale GtkScrollbar GtkScrolledWindow GtkSeparatorMenuItem GtkSocket GtkSpinButton GtkStatusbar GtkTable GtkTearoffMenuItem GtkText GtkTextBuffer GtkTextMark GtkTextTag GtkTextView GtkTipsQuery GtkToggleButton GtkToolbar GtkTooltips GtkTree GtkTreeView GtkTreeItem GtkVBox GtkVButtonBox GtkVPaned GtkVRuler GtkVScale GtkVScrollbar GtkVSeparator GtkViewport GtkWidget GtkWindow GtkWindowGroup contained
syn keyword gtkrcClassName AccelLabel Adjustment Alignment Arrow AspectFrame Bin Box Button ButtonBox CList CTree Calendar CheckButton CheckMenuItem ColorSelection ColorSelectionDialog Combo Container Curve Data Dialog DrawingArea Editable Entry EventBox FileSelection Fixed FontSelection FontSelectionDialog Frame GammaCurve HBox HButtonBox HPaned HRuler HScale HScrollbar HSeparator HandleBox Image ImageMenuItem InputDialog Invisible Item ItemFactory Label Layout List ListItem Menu MenuBar MenuItem MenuShell MessageDialog Misc Notebook Object OptionMenu Packer Paned Pixmap Plug Preview Progress ProgressBar RadioButton RadioMenuItem Range Ruler Scale Scrollbar ScrolledWindow SeparatorMenuItem Socket SpinButton Statusbar Table TearoffMenuItem Text TextBuffer TextMark TextTag TextView TipsQuery ToggleButton Toolbar Tooltips Tree TreeView TreeItem VBox VButtonBox VPaned VRuler VScale VScrollbar VSeparator Viewport Widget Window WindowGroup contained
syn keyword gtkrcClassNameGnome GnomeAbout GnomeAnimator GnomeApp GnomeAppBar GnomeCalculator GnomeCanvas GnomeCanvasEllipse GnomeCanvasGroup GnomeCanvasImage GnomeCanvasItem GnomeCanvasLine GnomeCanvasPolygon GnomeCanvasRE GnomeCanvasRect GnomeCanvasText GnomeCanvasWidget GnomeClient GnomeColorPicker GnomeDEntryEdit GnomeDateEdit GnomeDialog GnomeDock GnomeDockBand GnomeDockItem GnomeDockLayout GnomeDruid GnomeDruidPage GnomeDruidPageFinish GnomeDruidPageStandard GnomeDruidPageStart GnomeEntry GnomeFileEntry GnomeFontPicker GnomeFontSelector GnomeHRef GnomeIconEntry GnomeIconList GnomeIconSelection GnomeIconTextItem GnomeLess GnomeMDI GnomeMDIChild GnomeMDIGenericChild GnomeMessageBox GnomeNumberEntry GnomePaperSelector GnomePixmap GnomePixmapEntry GnomeProcBar GnomePropertyBox GnomeScores GnomeSpell GnomeStock GtkClock GtkDial GtkPixmapMenuItem GtkTed contained
syn cluster gtkrcPRIVATE add=gtkrcClassName,gtkrcClassNameGnome

" Stock item names
syn keyword gtkrcStockName gtk-add gtk-apply gtk-bold gtk-cancel gtk-cdrom gtk-clear gtk-close gtk-convert gtk-copy gtk-cut gtk-delete gtk-dialog-error gtk-dialog-info gtk-dialog-question gtk-dialog-warning gtk-dnd gtk-dnd-multiple gtk-execute gtk-find gtk-find-and-replace gtk-floppy gtk-goto-bottom gtk-goto-first gtk-goto-last gtk-goto-top gtk-go-back gtk-go-down gtk-go-forward gtk-go-up gtk-help gtk-home gtk-index gtk-italic gtk-jump-to gtk-justify-center gtk-justify-fill gtk-justify-left gtk-justify-right gtk-missing-image gtk-new gtk-no gtk-ok gtk-open gtk-paste gtk-preferences gtk-print gtk-print-preview gtk-properties gtk-quit gtk-redo gtk-refresh gtk-remove gtk-revert-to-saved gtk-save gtk-save-as gtk-select-color gtk-select-font gtk-sort-ascending gtk-sort-descending gtk-spell-check gtk-stop gtk-strikethrough gtk-undelete gtk-underline gtk-undo gtk-yes gtk-zoom-100 gtk-zoom-fit gtk-zoom-in gtk-zoom-out contained
syn cluster gtkrcPRIVATE add=gtkrcStockName

" Gtk Settings
syn keyword gtkrcSettingsName gtk-double-click-time gtk-cursor-blink gtk-cursor-blink-time gtk-split-cursor gtk-theme-name gtk-key-theme-name gtk-menu-bar-accel gtk-dnd-drag-threshold gtk-font-name gtk-color-palette gtk-entry-select-on-focus gtk-can-change-accels gtk-toolbar-style gtk-toolbar-icon-size
syn cluster gtkrcPRIVATE add=gtkrcSettingsName

" Catch errors caused by wrong parenthesization
syn region gtkrcParen start='(' end=')' transparent contains=ALLBUT,gtkrcParenError,@gtkrcPRIVATE
syn match gtkrcParenError ")"
syn region gtkrcBrace start='{' end='}' transparent contains=ALLBUT,gtkrcBraceError,@gtkrcPRIVATE
syn match gtkrcBraceError "}"
syn region gtkrcBracket start='\[' end=']' transparent contains=ALLBUT,gtkrcBracketError,@gtkrcPRIVATE
syn match gtkrcBracketError "]"

" Synchronization
syn sync minlines=50
syn sync match gtkrcSyncClass groupthere NONE "^\s*class\>"

" Define the default highlighting

hi def link gtkrcComment Comment
hi def link gtkrcFixme Todo

hi def link gtkrcInclude Preproc

hi def link gtkrcACString gtkrcString
hi def link gtkrcBString gtkrcString
hi def link gtkrcString String
hi def link gtkrcNumber Number
hi def link gtkrcStateName gtkrcConstant
hi def link gtkrcPriorityName gtkrcConstant
hi def link gtkrcTextDirName gtkrcConstant
hi def link gtkrcSettingsName Function
hi def link gtkrcStockName Function
hi def link gtkrcConstant Constant

hi def link gtkrcPathSpecial gtkrcSpecial
hi def link gtkrcWPathSpecial gtkrcSpecial
hi def link gtkrcRGBColor gtkrcSpecial
hi def link gtkrcKeyMod gtkrcSpecial
hi def link gtkrcSpecial Special

hi def link gtkrcTop gtkrcKeyword
hi def link gtkrcPathSet gtkrcKeyword
hi def link gtkrcStyleKeyword gtkrcKeyword
hi def link gtkrcFunction gtkrcKeyword
hi def link gtkrcBind gtkrcKeyword
hi def link gtkrcKeyword Keyword

hi def link gtkrcClassNameGnome gtkrcGtkClass
hi def link gtkrcClassName gtkrcGtkClass
hi def link gtkrcFunctionName gtkrcGtkClass
hi def link gtkrcGtkClass Type

hi def link gtkrcImage gtkrcOtherword
hi def link gtkrcOtherword Function

hi def link gtkrcParenError gtkrcError
hi def link gtkrcBraceError gtkrcError
hi def link gtkrcBracketError gtkrcError
hi def link gtkrcError Error


let b:current_syntax = "gtkrc"
