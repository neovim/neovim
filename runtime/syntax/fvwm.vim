" Vim syntax file for Fvwm-2.5.22
" Language:		Fvwm{1,2} configuration file
" Maintainer:		Gautam Iyer <gi1242@users.sourceforge.net>
" Previous Maintainer:	Haakon Riiser <hakonrk@fys.uio.no>
" Last Change:		Sat 29 Sep 2007 11:08:34 AM PDT
"
" Thanks to David Necas (Yeti) for adding Fvwm 2.4 support.
"
" 2006-05-09 gi1242: Rewrote fvwm2 syntax completely. Also since fvwm1 is now
" mostly obsolete, made the syntax file pick fvwm2 syntax by default.

if exists("b:current_syntax")
    finish
endif
let s:keepcpo= &cpo
set cpo&vim

" Fvwm configuration files are case insensitive
syn case ignore

" Identifiers in Fvwm can contain most characters, so we only
" include the most common ones here.
setlocal iskeyword=_,-,+,.,a-z,A-Z,48-57

" Syntax items common to fvwm1 and fvwm2 config files
syn cluster fvwmConstants	contains=fvwmEnvVar,fvwmNumber
syn match   fvwmEnvVar		"\$\w\+"
syn match   fvwmNumber		'\v<(\d+|0x[0-9a-f]+)>' 

syn match   fvwmModConf		nextgroup=fvwmModArg	"\v^\s*\*\a+"
syn region  fvwmModArg		contained contains=fvwmString,fvwmRGBValue
				\ start='.' skip='\\$' end='$'

syn region  fvwmString		contains=fvwmBackslash start='"'
				\ matchgroup=fvwmBackslash skip='\v\\"' end='"'
syn region  fvwmString		contains=fvwmBackslash start='`'
				\ matchgroup=fvwmBackslash skip='\v\\`' end='`'
syn region  fvwmString		contains=fvwmBackslash start="'"
				\ matchgroup=fvwmBackslash skip="\v\\'" end="'"
syn match   fvwmBackslash	contained '\\[^"'`]'

syn match   fvwmRGBValue	"#\x\{3}"
syn match   fvwmRGBValue	"#\x\{6}"
syn match   fvwmRGBValue	"#\x\{9}"
syn match   fvwmRGBValue	"#\x\{12}"
syn match   fvwmRGBValue	"rgb:\x\{1,4}/\x\{1,4}/\x\{1,4}"

syn region  fvwmComment		contains=@Spell
				\ start='^\s*#\s' skip='\\$' end='$'
syn region  fvwmComment		start="\v^\s*#(\S|$)" skip='\\$' end='$'

if (exists("b:fvwm_version") && b:fvwm_version == 1)
	    \ || (exists("use_fvwm_1") && use_fvwm_1)

    "
    " Syntax highlighting for Fvwm1 files.
    "

    " Moved from common syntax items
    syn match   fvwmModule	"\<Module\s\+\w\+"he=s+6
    syn keyword fvwmExec	Exec
    syn match   fvwmPath	"\<IconPath\s.*$"lc=8 contains=fvwmEnvVar
    syn match   fvwmPath	"\<ModulePath\s.*$"lc=10 contains=fvwmEnvVar
    syn match   fvwmPath	"\<PixmapPath\s.*$"lc=10 contains=fvwmEnvVar
    syn match   fvwmKey		"\<Key\s\+\w\+"he=s+3

    " fvwm1 specific items
    syn match  fvwmEnvVar	"\$(\w\+)"
    syn match  fvwmWhitespace	contained "\s\+"
    syn region fvwmStyle	oneline keepend
				\ contains=fvwmString,fvwmKeyword,fvwmWhiteSpace
				\ matchgroup=fvwmFunction
				\ start="^\s*Style\>"hs=e-5 end="$"

    syn keyword fvwmFunction	AppsBackingStore AutoRaise BackingStore Beep
				\ BoundaryWidth ButtonStyle CenterOnCirculate
				\ CirculateDown CirculateHit CirculateSkip
				\ CirculateSkipIcons CirculateUp ClickTime
				\ ClickToFocus Close Cursor CursorMove
				\ DecorateTransients Delete Desk DeskTopScale
				\ DeskTopSize Destroy DontMoveOff
				\ EdgeResistance EdgeScroll EndFunction
				\ EndMenu EndPopup Focus Font Function
				\ GotoPage HiBackColor HiForeColor Icon
				\ IconBox IconFont Iconify IconPath Key
				\ Lenience Lower Maximize MenuBackColor
				\ MenuForeColor MenuStippleColor Module
				\ ModulePath Mouse Move MWMBorders MWMButtons
				\ MWMDecorHints MWMFunctionHints
				\ MWMHintOverride MWMMenus NoBorder
				\ NoBoundaryWidth Nop NoPPosition NoTitle
				\ OpaqueMove OpaqueResize Pager PagerBackColor
				\ PagerFont PagerForeColor PagingDefault
				\ PixmapPath Popup Quit Raise RaiseLower
				\ RandomPlacement Refresh Resize Restart
				\ SaveUnders Scroll SloppyFocus SmartPlacement
				\ StartsOnDesk StaysOnTop StdBackColor
				\ StdForeColor Stick Sticky StickyBackColor
				\ StickyForeColor StickyIcons
				\ StubbornIconPlacement StubbornIcons
				\ StubbornPlacement SuppressIcons Title
				\ TogglePage Wait Warp WindowFont WindowList
				\ WindowListSkip WindowsDesk WindowShade
				\ XORvalue

    " These keywords are only used after the "Style" command.  To avoid
    " name collision with several commands, they are contained.
    syn keyword fvwmKeyword	contained
				\ BackColor BorderWidth BoundaryWidth Button
				\ CirculateHit CirculateSkip Color DoubleClick
				\ ForeColor Handles HandleWidth Icon IconTitle
				\ NoBorder NoBoundaryWidth NoButton NoHandles
				\ NoIcon NoIconTitle NoTitle Slippery
				\ StartIconic StartNormal StartsAnyWhere
				\ StartsOnDesk StaysOnTop StaysPut Sticky
				\ Title WindowListHit WindowListSkip

" elseif (exists("b:fvwm_version") && b:fvwm_version == 2)
" 	    \ || (exists("use_fvwm_2") && use_fvwm_2)
else

    "
    " Syntax highlighting for fvwm2 files.
    "
    syn match   fvwmEnvVar	"\${\w\+}"
    syn match   fvwmEnvVar	"\$\[[^]]\+\]"
    syn match   fvwmEnvVar	"\$[$0-9*]"

    syn match   fvwmDef		contains=fvwmMenuString,fvwmWhitespace
				\ '^\s*+\s*".\{-}"'
    syn region  fvwmMenuString	contains=fvwmIcon,fvwmShortcutKey
				\ start='^\s*+\s*\zs"' skip='\v\\\\|\\\"' end='"'
    syn region	fvwmIcon	contained start='\v\%\%@!' end='%'
    syn match   fvwmShortcutKey	contained "&."

    syn keyword fvwmModuleName	FvwmAnimate FvwmAudio FvwmAuto FvwmBacker
				\ FvwmBanner FvwmButtons FvwmCascade
				\ FvwmCommandS FvwmConsole FvwmConsoleC
				\ FvwmCpp FvwmDebug FvwmDragWell FvwmEvent
				\ FvwmForm FvwmGtkDebug FvwmIconBox
				\ FvwmIconMan FvwmIdent FvwmM4 FvwmPager
				\ FvwmPerl FvwmProxy FvwmRearrange FvwmSave
				\ FvwmSaveDesk FvwmScript FvwmScroll FvwmTabs
				\ FvwmTalk FvwmTaskBar FvwmTheme FvwmTile
				\ FvwmWharf FvwmWindowMenu FvwmWinList

    " Obsolete fvwmModuleName: FvwmTheme

    syn keyword fvwmKeyword	AddToMenu ChangeMenuStyle CopyMenuStyle
				\ DestroyMenu DestroyMenuStyle Menu
				\ Popup TearMenuOff Title BugOpts BusyCursor
				\ ClickTime ColorLimit ColormapFocus
				\ DefaultColors DefaultColorset DefaultFont
				\ DefaultIcon DefaultLayers Deschedule Emulate
				\ EscapeFunc FakeClick FakeKeypress GlobalOpts
				\ HilightColor HilightColorset IconFont
				\ PrintInfo Repeat Schedule State WindowFont
				\ XSync XSynchronize AnimatedMove
				\ HideGeometryWindow Layer Lower Move
				\ MoveToDesk MoveThreshold MoveToPage
				\ MoveToScreen OpaqueMoveSize PlaceAgain Raise
				\ RaiseLower ResizeMaximize ResizeMove
				\ ResizeMoveMaximize RestackTransients
				\ SetAnimation SnapAttraction SnapGrid
				\ WindowsDesk XorPixmap XorValue CursorMove
				\ FlipFocus Focus WarpToWindow Close Delete
				\ Destroy Iconify Recapture RecaptureWindow
				\ Refresh RefreshWindow Stick StickAcrossPages
				\ StickAcrossDesks WindowShade
				\ WindowShadeAnimate IgnoreModifiers
				\ EdgeCommand EdgeLeaveCommand GnomeButton
				\ Stroke StrokeFunc FocusStyle DestroyStyle
				\ DestroyWindowStyle UpdateStyles AddToDecor
				\ BorderStyle ChangeDecor DestroyDecor
				\ UpdateDecor DesktopName DeskTopSize
				\ EdgeResistance EdgeScroll EdgeThickness
				\ EwmhBaseStruts EWMHNumberOfDesktops
				\ GotoDeskAndPage GotoPage Scroll Xinerama
				\ XineramaPrimaryScreen XineramaSls
				\ XineramaSlsSize XineramaSlsScreens AddToFunc
				\ Beep DestroyFunc Echo Exec ExecUseShell
				\ Function Nop PipeRead Read SetEnv Silent
				\ UnsetEnv Wait DestroyModuleConfig KillModule
				\ Module ModuleListenOnly ModuleSynchronous
				\ ModuleTimeout SendToModule Quit QuitScreen
				\ QuitSession Restart SaveSession
				\ SaveQuitSession KeepRc NoWindow Break
				\ CleanupColorsets EchoFuncDefinition

    " Conditional commands
    syn keyword fvwmKeyword	nextgroup=fvwmCondition skipwhite
				\ All Any Current Next None Pick PointerWindow
				\ Prev ThisWindow
    syn keyword fvwmKeyword	nextgroup=fvwmDirection skipwhite
				\ Direction
    syn keyword fvwmDirection	contained nextgroup=fvwmDirection skipwhite
				\ FromPointer
    syn keyword fvwmDirection	contained nextgroup=fvwmCondition skipwhite
				\ North Northeast East Southeast South
				\ Southwest West Northwest Center
    syn region	fvwmCondition	contained contains=fvwmCondNames,fvwmString
				\ matchgroup=fvwmKeyword start='(' skip=','
				\ end=')'
    syn keyword fvwmCondNames	contained
				\ AcceptsFocus AnyScreen CirculateHit
				\ CirculateHitIcon CirculateHitShaded Closable
				\ CurrentDesk CurrentGlobalPage
				\ CurrentGlobalPageAnyDesk CurrentPage
				\ CurrentPageAnyDesk CurrentScreen FixedSize
				\ Focused HasHandles HasPointer Iconic
				\ Iconifiable Maximizable Maximized
				\ Overlapped PlacedByButton PlacedByButton3
				\ PlacedByFvwm Raised Shaded Sticky
				\ StickyAcrossDesks StickyAcrossPages
				\ Transient Visible StickyIcon
				\ StickyAcrossPagesIcon StickyAcrossDesksIcon

    syn keyword fvwmCondNames	contained skipwhite nextgroup=@fvwmConstants
				\ State Layer

    " Test
    syn keyword fvwmKeyword	nextgroup=fvwmTCond skipwhite
				\ Test
    syn region	fvwmTCond	contained contains=fvwmTCNames,fvwmString
				\ matchgroup=fvwmKeyword start='(' end=')'
    syn keyword	fvwmTCNames	contained
				\ Version EnvIsSet EnvMatch EdgeHasPointer
				\ EdgeIsActive Start Init Restart Exit Quit
				\ ToRestart True False F R W X I
    
    " TestRc
    syn keyword fvwmKeyword	nextgroup=fvwmTRCond skipwhite
				\ TestRc
    syn region	fvwmTRCond	contained contains=fvwmTRNames,fvwmNumber
				\ matchgroup=fvwmKeyword start='(' end=')'
    syn keyword	fvwmTRNames	contained NoMatch Match Error Break

    " Colorsets
    syn keyword fvwmKeyword	nextgroup=fvwmCSArgs	skipwhite
				\ ColorSet
    syn region	fvwmCSArgs	contained transparent contains=fvwmCSNames,@fvwmConstants,fvwmString,fvwmRGBValue,fvwmGradient
		\ start='.' skip='\\$' end='$'
    syn keyword	fvwmCSNames	contained
				\ fg Fore Foreground bg Back Background hi
				\ Hilite Hilight sh Shade Shadow fgsh Pixmap
				\ TiledPixmap AspectPixmap RootTransparent
				\ Shape TiledShape AspectShape Tint fgTint
				\ bgTint Alpha fgAlpha Dither IconTint
				\ IconAlpha NoShape Plain Translucent
    syn match	fvwmCSNames	contained	'\v<Transparent>'
    syn match	fvwmGradient	contained	'\v<[HVDBSCRY]Gradient>'

    " Styles
    syn keyword fvwmKeyword	nextgroup=fvwmStyleArgs skipwhite
				\ Style WindowStyle
    syn region	fvwmStyleArgs	contained transparent contains=fvwmStyleNames,@fvwmConstants,fvwmString,fvwmRGBValue
				\ start='.' skip='\\$' end='$'
    syn keyword	fvwmStyleNames	contained
				\ BorderWidth HandleWidth NoIcon Icon MiniIcon
				\ IconBox IconGrid IconFill IconSize NoTitle
				\ Title TitleAtBottom TitleAtLeft TitleAtRight
				\ TitleAtTop LeftTitleRotatedCW
				\ LeftTitleRotatedCCW RightTitleRotatedCCW
				\ RightTitleRotatedCW TopTitleRotated
				\ TopTitleNotRotated BottomTitleRotated
				\ BottomTitleNotRotated UseTitleDecorRotation
				\ StippledTitle StippledTitleOff
				\ IndexedWindowName ExactWindowName
				\ IndexedIconName ExactIconName Borders
				\ NoHandles Handles WindowListSkip
				\ WindowListHit CirculateSkip CirculateHit
				\ CirculateSkipShaded CirculateHitShaded Layer
				\ StaysOnTop StaysOnBottom StaysPut Sticky
				\ Slippery StickyAcrossPages StickyAcrossDesks
				\ StartIconic StartNormal Color ForeColor
				\ BackColor Colorset HilightFore HilightBack
				\ HilightColorset BorderColorset
				\ HilightBorderColorset IconTitleColorset
				\ HilightIconTitleColorset
				\ IconBackgroundColorset IconTitleRelief
				\ IconBackgroundRelief IconBackgroundPadding
				\ Font IconFont StartsOnDesk StartsOnPage
				\ StartsAnyWhere StartsOnScreen
				\ ManualPlacementHonorsStartsOnPage
				\ ManualPlacementIgnoresStartsOnPage
				\ CaptureHonorsStartsOnPage
				\ CaptureIgnoresStartsOnPage
				\ RecaptureHonorsStartsOnPage
				\ RecaptureIgnoresStartsOnPage
				\ StartsOnPageIncludesTransients
				\ StartsOnPageIgnoresTransients IconTitle
				\ NoIconTitle MwmButtons FvwmButtons MwmBorder
				\ FvwmBorder MwmDecor NoDecorHint MwmFunctions
				\ NoFuncHint HintOverride NoOverride NoButton
				\ Button ResizeHintOverride NoResizeOverride
				\ OLDecor NoOLDecor GNOMEUseHints
				\ GNOMEIgnoreHints StickyIcon SlipperyIcon
				\ StickyAcrossPagesIcon StickyAcrossDesksIcon
				\ ManualPlacement CascadePlacement
				\ MinOverlapPlacement
				\ MinOverlapPercentPlacement
				\ TileManualPlacement TileCascadePlacement
				\ MinOverlapPlacementPenalties
				\ MinOverlapPercentPlacementPenalties
				\ DecorateTransient NakedTransient
				\ DontRaiseTransient RaiseTransient
				\ DontLowerTransient LowerTransient
				\ DontStackTransientParent
				\ StackTransientParent SkipMapping ShowMapping
				\ ScatterWindowGroups KeepWindowGroupsOnDesk
				\ UseDecor UseStyle NoPPosition UsePPosition
				\ NoUSPosition UseUSPosition
				\ NoTransientPPosition UseTransientPPosition
				\ NoTransientUSPosition UseTransientUSPosition
				\ NoIconPosition UseIconPosition Lenience
				\ NoLenience ClickToFocus SloppyFocus
				\ MouseFocus FocusFollowsMouse NeverFocus
				\ ClickToFocusPassesClickOff
				\ ClickToFocusPassesClick
				\ ClickToFocusRaisesOff ClickToFocusRaises
				\ MouseFocusClickRaises
				\ MouseFocusClickRaisesOff GrabFocus
				\ GrabFocusOff GrabFocusTransientOff
				\ GrabFocusTransient FPFocusClickButtons
				\ FPFocusClickModifiers
				\ FPSortWindowlistByFocus FPClickRaisesFocused
				\ FPClickDecorRaisesFocused
				\ FPClickIconRaisesFocused
				\ FPClickRaisesUnfocused
				\ FPClickDecorRaisesUnfocused
				\ FPClickIconRaisesUnfocused FPClickToFocus
				\ FPClickDecorToFocus FPClickIconToFocus
				\ FPEnterToFocus FPLeaveToUnfocus
				\ FPFocusByProgram FPFocusByFunction
				\ FPFocusByFunctionWarpPointer FPLenient
				\ FPPassFocusClick FPPassRaiseClick
				\ FPIgnoreFocusClickMotion
				\ FPIgnoreRaiseClickMotion
				\ FPAllowFocusClickFunction
				\ FPAllowRaiseClickFunction FPGrabFocus
				\ FPGrabFocusTransient FPOverrideGrabFocus
				\ FPReleaseFocus FPReleaseFocusTransient
				\ FPOverrideReleaseFocus StartsLowered
				\ StartsRaised IgnoreRestack AllowRestack
				\ FixedPosition VariablePosition
				\ FixedUSPosition VariableUSPosition
				\ FixedPPosition VariablePPosition FixedSize
				\ VariableSize FixedUSSize VariableUSSize
				\ FixedPSize VariablePSize Closable
				\ Iconifiable Maximizable
				\ AllowMaximizeFixedSize IconOverride
				\ NoIconOverride NoActiveIconOverride
				\ DepressableBorder FirmBorder MaxWindowSize
				\ IconifyWindowGroups IconifyWindowGroupsOff
				\ ResizeOpaque ResizeOutline BackingStore
				\ BackingStoreOff BackingStoreWindowDefault
				\ Opacity ParentalRelativity SaveUnder
				\ SaveUnderOff WindowShadeShrinks
				\ WindowShadeScrolls WindowShadeSteps
				\ WindowShadeAlwaysLazy WindowShadeBusy
				\ WindowShadeLazy EWMHDonateIcon
				\ EWMHDontDonateIcon EWMHDonateMiniIcon
				\ EWMHDontDonateMiniIcon EWMHMiniIconOverride
				\ EWMHNoMiniIconOverride
				\ EWMHUseStackingOrderHints
				\ EWMHIgnoreStackingOrderHints
				\ EWMHIgnoreStateHints EWMHUseStateHints
				\ EWMHIgnoreStrutHints EWMHIgnoreWindowType
				\ EWMHUseStrutHints
				\ EWMHMaximizeIgnoreWorkingArea
				\ EWMHMaximizeUseWorkingArea
				\ EWMHMaximizeUseDynamicWorkingArea
				\ EWMHPlacementIgnoreWorkingArea
				\ EWMHPlacementUseWorkingArea
				\ EWMHPlacementUseDynamicWorkingArea
				\ MoveByProgramMethod Unmanaged State
				\ StippledIconTitle StickyStippledTitle
				\ StickyStippledIconTitle
				\ PositionPlacement
				\ UnderMousePlacementHonorsStartsOnPage
				\ UnderMousePlacementIgnoresStartsOnPage
				\ MinOverlapPlacementPenalties
				\ MinOverlapPercentPlacementPenalties
				\ MinWindowSize StartShaded

    " Cursor styles
    syn keyword fvwmKeyword	nextgroup=fvwmCursorStyle skipwhite
				\ CursorStyle
    syn case match
    syn keyword fvwmCursorStyle	contained
				\ POSITION TITLE DEFAULT SYS MOVE RESIZE WAIT
				\ MENU SELECT DESTROY TOP RIGHT BOTTOM LEFT
				\ TOP_LEFT TOP_RIGHT BOTTOM_LEFT BOTTOM_RIGHT
				\ TOP_EDGE RIGHT_EDGE BOTTOM_EDGE LEFT_EDGE
				\ ROOT STROKE
    syn case ignore

    " Menu style
    syn keyword fvwmKeyword	nextgroup=fvwmMStyleArgs skipwhite
				\ MenuStyle
    syn region	fvwmMStyleArgs	contained transparent contains=fvwmMStyleNames,@fvwmConstants,fvwmString,fvwmGradient,fvwmRGBValue
				\ start='.' skip='\\$' end='$'
    syn keyword	fvwmMStyleNames	contained
				\ Fvwm Mwm Win BorderWidth Foreground
				\ Background Greyed HilightBack HilightBackOff
				\ ActiveFore ActiveForeOff MenuColorset
				\ ActiveColorset GreyedColorset Hilight3DThick
				\ Hilight3DThin Hilight3DOff
				\ Hilight3DThickness Animation AnimationOff
				\ Font MenuFace PopupDelay PopupOffset
				\ TitleWarp TitleWarpOff TitleUnderlines0
				\ TitleUnderlines1 TitleUnderlines2
				\ SeparatorsLong SeparatorsShort
				\ TrianglesSolid TrianglesRelief
				\ PopupImmediately PopupDelayed
				\ PopdownImmediately PopdownDelayed
				\ PopupActiveArea DoubleClickTime SidePic
				\ SideColor PopupAsRootMenu PopupAsSubmenu
				\ PopupIgnore PopupClose RemoveSubmenus
				\ HoldSubmenus SubmenusRight SubmenusLeft
				\ SelectOnRelease ItemFormat
				\ VerticalItemSpacing VerticalTitleSpacing
				\ AutomaticHotkeys AutomaticHotkeysOff
				\ TitleFont TitleColorset HilightTitleBack

    " Button style
    syn keyword fvwmKeyword	nextgroup=fvwmBNum	skipwhite
				\ ButtonStyle AddButtonStyle
    syn match	fvwmBNum	contained
				\ nextgroup=fvwmBState,fvwmBStyleArgs skipwhite 
				\ '\v<([0-9]|All|Left|Right|Reset)>'
    syn keyword	fvwmBState	contained nextgroup=fvwmBStyleArgs skipwhite
				\ ActiveUp ActiveDown InactiveUp InactiveDown
				\ Active Inactive ToggledActiveUp
				\ ToggledActiveDown ToggledInactiveUp
				\ ToggledInactiveDown ToggledActive
				\ ToggledInactive AllNormal AllToggled
				\ AllActive AllInactive AllUp AllDown
    syn region	fvwmBStyleArgs	contained contains=fvwmBStyleFlags,fvwmBStyleNames,fvwmGradient,fvwmRGBValue,@fvwmConstants,fvwmString
				\ start='\S' skip='\\$' end='$'
    syn keyword	fvwmBStyleNames	contained
				\ Simple Default Solid Colorset Vector Pixmap
				\ AdjustedPixmap ShrunkPixmap StretchedPixmap
				\ TiledPixmap MiniIcon
    syn keyword fvwmBStyleFlags	contained
				\ Raised Sunk Flat UseTitleStyle
				\ UseBorderStyle

    " Border style
    syn keyword fvwmKeyword	skipwhite nextgroup=fvwmBdState,fvwmBdStyleArgs
				\ BorderStyle
    syn keyword	fvwmBdState	contained skipwhite nextgroup=fvwmBdStyleArgs
				\ Active Inactive
    syn region	fvwmBdStyleArgs	contained contains=fvwmBdStyNames,fvwmBdStyFlags
				\ start='\S' skip='\\$' end='$'
    syn keyword	fvwmBdStyNames	contained
				\ TiledPixmap Colorset
    syn keyword	fvwmBdStyFlags	contained
				\ HiddenHandles NoInset Raised Sunk Flat

    " Title styles
    syn keyword	fvwmKeyword	skipwhite nextgroup=fvwmTState,fvwmTStyleArgs
				\ TitleStyle AddTitleStyle
    syn keyword	fvwmTState	contained skipwhite nextgroup=fvwmTStyleArgs
				\ ActiveUp ActiveDown InactiveUp InactiveDown
				\ Active Inactive ToggledActiveUp
				\ ToggledActiveDown ToggledInactiveUp
				\ ToggledInactiveDown ToggledActive
				\ ToggledInactive AllNormal AllToggled
				\ AllActive AllInactive AllUp AllDown
    syn region	fvwmTStyleArgs	contained contains=fvwmBStyleNames,fvwmTStyleNames,fvwmMPmapNames,fvwmTStyleFlags,fvwmGradient,fvwmRGBValue,@fvwmConstants
				\ start='\S' skip='\\$' end='$'
    syn keyword	fvwmTStyleNames	contained
				\ MultiPixmap
    syn keyword fvwmTStyleNames	contained
				\ LeftJustified Centered RightJustified Height
				\ MinHeight
    syn keyword	fvwmMPmapNames	contained
				\ Main LeftMain RightMain UnderText LeftOfText
				\ RightOfText LeftEnd RightEnd Buttons
				\ LeftButtons RightButtons
    syn keyword	fvwmTStyleFlags	contained
				\ Raised Flat Sunk

    " Button state
    syn keyword fvwmKeyword	nextgroup=fvwmBStateArgs
				\ ButtonState
    syn region	fvwmBStateArgs	contained contains=fvwmBStateTF,fvwmBStateNames
				\ start='.' skip='\\$' end='$'
    syn keyword	fvwmBStateNames	contained ActiveDown Inactive InactiveDown
    syn keyword fvwmBStateTF	contained True False

    " Paths
    syn keyword fvwmKeyword	nextgroup=fvwmPath	skipwhite
				\ IconPath ImagePath LocalePath PixmapPath
				\ ModulePath 
    syn match	fvwmPath	contained contains=fvwmEnvVar '\v.+$'

    " Window list command
    syn keyword fvwmKeyword	nextgroup=fvwmWLArgs skipwhite
				\ WindowList
    syn region	fvwmWLArgs	contained
		\ contains=fvwmCondition,@fvwmConstants,fvwmString,fvwmWLOpts
		\ start='.' skip='\\$' end='$'
    syn keyword fvwmWLOpts	contained
				\ Geometry NoGeometry NoGeometryWithInfo
				\ NoDeskNum NoNumInDeskTitle
				\ NoCurrentDeskTitle MaxLabelWidth width
				\ TitleForAllDesks Function funcname Desk
				\ desknum CurrentDesk NoIcons Icons OnlyIcons
				\ NoNormal Normal OnlyNormal NoSticky Sticky
				\ OnlySticky NoStickyAcrossPages
				\ StickyAcrossPages OnlyStickyAcrossPages
				\ NoStickyAcrossDesks StickyAcrossDesks
				\ OnlyStickyAcrossDesks NoOnTop OnTop
				\ OnlyOnTop NoOnBottom OnBottom OnlyOnBottom
				\ Layer UseListSkip OnlyListSkip NoDeskSort
				\ ReverseOrder CurrentAtEnd IconifiedAtEnd
				\ UseIconName Alphabetic NotAlphabetic
				\ SortByResource SortByClass NoHotkeys
				\ SelectOnRelease

    syn keyword fvwmSpecialFn	StartFunction InitFunction RestartFunction
				\ ExitFunction SessionInitFunction
				\ SessionRestartFunction SessionExitFunction
				\ MissingSubmenuFunction WindowListFunc

    syn keyword fvwmKeyword	skipwhite nextgroup=fvwmKeyWin,fvwmKeyName
				\ Key PointerKey
    syn region	fvwmKeyWin	contained skipwhite nextgroup=fvwmKeyName
				\ start='(' end=')'
    syn case match
    syn match	fvwmKeyName	contained skipwhite nextgroup=fvwmKeyContext
				\ '\v<([a-zA-Z0-9]|F\d+|KP_\d)>'
    syn keyword fvwmKeyName	contained skipwhite nextgroup=fvwmKeyContext
				\ BackSpace Begin Break Cancel Clear Delete
				\ Down End Escape Execute Find Help Home
				\ Insert KP_Add KP_Begin KP_Decimal KP_Delete
				\ KP_Divide KP_Down KP_End KP_Enter KP_Equal
				\ KP_Home KP_Insert KP_Left KP_Multiply
				\ KP_Next KP_Page_Down KP_Page_Up KP_Prior
				\ KP_Right KP_Separator KP_Space KP_Subtract
				\ KP_Tab KP_Up Left Linefeed Menu Mode_switch
				\ Next Num_Lock Page_Down Page_Up Pause Print
				\ Prior Redo Return Right script_switch
				\ Scroll_Lock Select Sys_Req Tab Undo Up space
				\ exclam quotedbl numbersign dollar percent
				\ ampersand apostrophe quoteright parenleft
				\ parenright asterisk plus comma minus period
				\ slash colon semicolon less equal greater
				\ question at bracketleft backslash
				\ bracketright asciicircum underscore grave
				\ quoteleft braceleft bar braceright
				\ asciitilde

    syn match	fvwmKeyContext	contained skipwhite nextgroup=fvwmKeyMods
				\ '\v<[][RWDTS_F<^>vI0-9AM-]+>'
    syn match	fvwmKeyMods	contained '\v[NCSMLA1-5]+'
    syn case ignore

    syn keyword	fvwmKeyword	skipwhite nextgroup=fvwmMouseWin,fvwmMouseButton
				\ Mouse
    syn region	fvwmMouseWin	contained skipwhite nextgroup=fvwmMouseButton
				\ start='(' end=')'
    syn match	fvwmMouseButton	contained skipwhite nextgroup=fvwmKeyContext
				\ '[0-5]'
endif

" Define syntax highlighting groups

"
" Common highlighting groups
"
hi def link fvwmComment		Comment
hi def link fvwmEnvVar		Macro
hi def link fvwmNumber		Number
hi def link fvwmKeyword		Keyword
hi def link fvwmPath		Constant
hi def link fvwmModConf		Macro
hi def link fvwmRGBValue	Constant
hi def link fvwmString		String
hi def link fvwmBackslash	SpecialChar


"
" Highlighting groups for fvwm1 specific items
"
hi def link fvwmExec		fvwmKeyword
hi def link fvwmKey		fvwmKeyword
hi def link fvwmModule		fvwmKeyword
hi def link fvwmFunction	Function

"
" Highlighting groups for fvwm2 specific items
"
hi def link fvwmSpecialFn	Type
hi def link fvwmCursorStyle	fvwmStyleNames
hi def link fvwmStyleNames	Identifier
hi def link fvwmMStyleNames	fvwmStyleNames
hi def link fvwmCSNames		fvwmStyleNames
hi def link fvwmGradient	fvwmStyleNames
hi def link fvwmCondNames	fvwmStyleNames
hi def link fvwmTCNames		fvwmStyleNames
hi def link fvwmTRNames		fvwmStyleNames
hi def link fvwmWLOpts		fvwmStyleNames

hi def link fvwmBNum		Number
hi def link fvwmBState		Type
hi def link fvwmBStyleNames	fvwmStyleNames
hi def link fvwmBStyleFlags	Special

hi def link fvwmBStateTF	Constant
hi def link fvwmBStateNames	fvwmStyleNames

hi def link fvwmBdState		fvwmBState
hi def link fvwmBdStyNames	fvwmStyleNames
hi def link fvwmBdStyFlags	fvwmBStyleFlags

hi def link fvwmTState		fvwmBState
hi def link fvwmTStyleNames	fvwmStyleNames
hi def link fvwmMPmapNames	fvwmBStyleFlags
hi def link fvwmTStyleFlags	fvwmBStyleFlags

hi def link fvwmDirection	fvwmBStyleFlags

hi def link fvwmKeyWin		Constant
hi def link fvwmMouseWin	fvwmKeyWin
hi def link fvwmKeyName		Special
hi def link fvwmKeyContext	fvwmKeyName
hi def link fvwmKeyMods		fvwmKeyName
hi def link fvwmMouseButton	fvwmKeyName

hi def link fvwmMenuString	String
hi def link fvwmIcon		Type
hi def link fvwmShortcutKey	SpecialChar

hi def link fvwmModuleName	Function

let b:current_syntax = "fvwm"

let &cpo = s:keepcpo
unlet s:keepcpo
