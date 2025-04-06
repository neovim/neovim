" Description	: Vim syntax file for mrxvtrc (for mrxvt-0.5.0 and up)
" Created	: Wed 26 Apr 2006 01:20:53 AM CDT
" Modified	: Thu 02 Feb 2012 08:37:45 PM EST
" Maintainer	: GI <a@b.c>, where a='gi1242+vim', b='gmail', c='com'

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn case match

" Errors
syn match	mrxvtrcError	contained	'\v\S+'

" Comments
syn match	mrxvtrcComment	contains=@Spell '^\s*[!#].*$'
syn match	mrxvtrcComment	'\v^\s*[#!]\s*\w+[.*]\w+.*:.*'

"
" Options.
"
syn match	mrxvtrcClass	'\v^\s*\w+[.*]'
	    \ nextgroup=mrxvtrcOptions,mrxvtrcProfile,@mrxvtrcPOpts,mrxvtrcError

" Boolean options
syn keyword	mrxvtrcOptions	contained nextgroup=mrxvtrcBColon,mrxvtrcError
				\ highlightTabOnBell syncTabTitle hideTabbar
				\ autohideTabbar bottomTabbar hideButtons
				\ syncTabIcon veryBoldFont maximized
				\ fullscreen reverseVideo loginShell
				\ jumpScroll scrollBar scrollbarRight
				\ scrollbarFloating scrollTtyOutputInhibit
				\ scrollTtyKeypress transparentForce
				\ transparentScrollbar transparentMenubar
				\ transparentTabbar tabUsePixmap utmpInhibit
				\ visualBell mapAlert meta8
				\ mouseWheelScrollPage multibyte_cursor
				\ tripleclickwords showMenu xft xftNomFont
				\ xftSlowOutput xftAntialias xftHinting
				\ xftAutoHint xftGlobalAdvance cmdAllTabs
				\ protectSecondary thai borderLess
				\ overrideRedirect broadcast smartResize
				\ pointerBlank cursorBlink noSysConfig
				\ disableMacros linuxHomeEndKey sessionMgt
				\ boldColors smoothResize useFifo veryBright
syn match	mrxvtrcOptions	contained nextgroup=mrxvtrcBColon,mrxvtrcError
				\ '\v<transparent>'
syn match	mrxvtrcBColon	contained skipwhite
				\ nextgroup=mrxvtrcBoolVal,mrxvtrcError ':'
syn case ignore
syn keyword	mrxvtrcBoolVal	contained skipwhite nextgroup=mrxvtrcError
				\ 0 1 yes no on off true false
syn case match

" Color options
syn keyword	mrxvtrcOptions	contained nextgroup=mrxvtrcCColon,mrxvtrcError
				\ ufBackground textShadow tabForeground
				\ itabForeground tabBackground itabBackground
				\ scrollColor troughColor highlightColor
				\ cursorColor cursorColor2 pointerColor
				\ borderColor tintColor
syn match	mrxvtrcOptions	contained nextgroup=mrxvtrcCColon,mrxvtrcError
				\ '\v<color([0-9]|1[0-5]|BD|UL|RV)>'
syn match	mrxvtrcCColon	contained skipwhite
				\ nextgroup=mrxvtrcColorVal ':'
syn match	mrxvtrcColorVal	contained skipwhite nextgroup=mrxvtrcError
				\ '\v#[0-9a-fA-F]{6}'

" Numeric options
syn keyword	mrxvtrcOptions	contained nextgroup=mrxvtrcNColon,mrxvtrcError
				\ maxTabWidth minVisibleTabs
				\ scrollbarThickness xftmSize xftSize desktop
				\ externalBorder internalBorder lineSpace
				\ pointerBlankDelay cursorBlinkInterval
				\ shading backgroundFade bgRefreshInterval
				\ fading opacity opacityDegree xftPSize
syn match	mrxvtrcNColon	contained skipwhite
				\ nextgroup=mrxvtrcNumVal,mrxvtrcError ':'
syn match	mrxvtrcNumVal	contained skipwhite nextgroup=mrxvtrcError
				\ '\v[+-]?<(0[0-7]+|\d+|0x[0-9a-f]+)>'

" String options
syn keyword	mrxvtrcOptions	contained nextgroup=mrxvtrcSColon,mrxvtrcError
				\ tabTitle termName title clientName iconName
				\ bellCommand backspaceKey deleteKey
				\ printPipe cutChars answerbackString
				\ smClientID geometry path boldFont xftFont
				\ xftmFont xftPFont inputMethod
				\ greektoggle_key menu menubarPixmap
				\ scrollbarPixmap tabbarPixmap appIcon
				\ multichar_encoding initProfileList
syn match	mrxvtrcOptions	contained nextgroup=mrxvtrcSColon,mrxvtrcError
				\ '\v<m?font[1-5]?>'
syn match	mrxvtrcSColon	contained skipwhite nextgroup=mrxvtrcStrVal ':'
syn match	mrxvtrcStrVal	contained '\v\S.*'

" Profile options
syn cluster	mrxvtrcPOpts	contains=mrxvtrcPSOpts,mrxvtrcPCOpts,mrxvtrcPNOpts
syn match	mrxvtrcProfile	contained nextgroup=@mrxvtrcPOpts,mrxvtrcError
				\ '\vprofile\d+\.'
syn keyword	mrxvtrcPSOpts	contained nextgroup=mrxvtrcSColon,mrxvtrcError
				\ tabTitle command holdExitText holdExitTitle
				\ Pixmap workingDirectory titleFormat
				\ winTitleFormat
syn keyword	mrxvtrcPCOpts	contained nextgroup=mrxvtrcCColon,mrxvtrcError
				\ background foreground
syn keyword	mrxvtrcPNOpts	contained nextgroup=mrxvtrcNColon,mrxvtrcError
				\ holdExit saveLines

" scrollbarStyle
syn match	mrxvtrcOptions	contained skipwhite
				\ nextgroup=mrxvtrcSBstyle,mrxvtrcError
				\ '\v<scrollbarStyle:'
syn keyword	mrxvtrcSBstyle	contained skipwhite nextgroup=mrxvtrcError
				\ plain xterm rxvt next sgi

" scrollbarAlign
syn match	mrxvtrcOptions	contained skipwhite
				\ nextgroup=mrxvtrcSBalign,mrxvtrcError
				\ '\v<scrollbarAlign:'
syn keyword	mrxvtrcSBalign	contained skipwhite nextgroup=mrxvtrcError
				\ top bottom

" textShadowMode
syn match	mrxvtrcOptions	contained skipwhite
				\ nextgroup=mrxvtrcTSmode,mrxvtrcError
				\ '\v<textShadowMode:'
syn keyword	mrxvtrcTSmode	contained skipwhite nextgroup=mrxvtrcError
				\ none top bottom left right topleft topright
				\ botleft botright

" greek_keyboard
syn match	mrxvtrcOptions	contained skipwhite
				\ nextgroup=mrxvtrcGrkKbd,mrxvtrcError
				\ '\v<greek_keyboard:'
syn keyword	mrxvtrcGrkKbd	contained skipwhite nextgroup=mrxvtrcError
				\ iso ibm

" xftWeight
syn match	mrxvtrcOptions	contained skipwhite
				\ nextgroup=mrxvtrcXftWt,mrxvtrcError
				\ '\v<(xftWeight|xftBoldWeight):'
syn keyword	mrxvtrcXftWt	contained skipwhite nextgroup=mrxvtrcError
				\ light medium demibold bold black

" xftSlant
syn match	mrxvtrcOptions	contained skipwhite
				\ nextgroup=mrxvtrcXftSl,mrxvtrcError
				\ '\v<xftSlant:'
syn keyword	mrxvtrcXftSl	contained skipwhite nextgroup=mrxvtrcError
				\ roman italic oblique

" xftWidth
syn match	mrxvtrcOptions	contained skipwhite
				\ nextgroup=mrxvtrcXftWd,mrxvtrcError
				\ '\v<xftWidth:'
syn keyword	mrxvtrcXftWd	contained skipwhite nextgroup=mrxvtrcError
				\ ultracondensed ultraexpanded
				\ condensed expanded normal

" xftRGBA
syn match	mrxvtrcOptions	contained skipwhite
				\ nextgroup=mrxvtrcXftHt,mrxvtrcError
				\ '\v<xftRGBA:'
syn keyword	mrxvtrcXftHt	contained skipwhite nextgroup=mrxvtrcError
				\ rgb bgr vrgb vbgr none

" preeditType
syn match	mrxvtrcOptions	contained skipwhite
				\ nextgroup=mrxvtrcPedit,mrxvtrcError
				\ '\v<preeditType:'
syn keyword	mrxvtrcPedit	contained skipwhite nextgroup=mrxvtrcError
				\ OverTheSpot OffTheSpot Root

" modifier
syn match	mrxvtrcOptions	contained skipwhite
				\ nextgroup=mrxvtrcMod,mrxvtrcError
				\ '\v<modifier:'
syn keyword	mrxvtrcMod	contained skipwhite nextgroup=mrxvtrcError
				\ alt meta hyper super mod1 mod2 mod3 mod4 mod5

" selectStyle
syn match	mrxvtrcOptions	contained skipwhite
				\ nextgroup=mrxvtrcSelSty,mrxvtrcError
				\ '\v<selectStyle:'
syn keyword	mrxvtrcSelSty	contained skipwhite nextgroup=mrxvtrcError
				\ old oldword


"
" Macros
"
syn keyword	mrxvtrcOptions	contained nextgroup=mrxvtrcKey,mrxvtrcError
				\ macro
syn case ignore
syn match	mrxvtrcKey	contained skipwhite
			    \ nextgroup=mrxvtrcMacro,mrxvtrcError
			    \ '\v\.((primary|add|ctrl|alt|meta|shift)\+)*\w+:'
syn case match

" Macros without arguments
syn keyword	mrxvtrcMacro	contained skipwhite nextgroup=mrxvtrcError
				\ Dummy Copy Paste ToggleVeryBold
				\ ToggleTransparency ToggleBroadcast
				\ ToggleHold SetTitle ToggleMacros
				\ ToggleFullscreen Raise

" Macros with a string argument
syn keyword	mrxvtrcMacro	contained skipwhite nextgroup=mrxvtrcStrVal
				\ Esc Str Exec Scroll PrintScreen SaveConfig

" Macros with a numeric argument
syn keyword	mrxvtrcMacro	contained skipwhite
				\ nextgroup=mrxvtrcNumVal,mrxvtrcError
				\ Close GotoTab MoveTab ResizeFont UseFifo

" NewTab macro
syn keyword	mrxvtrcMacro	contained skipwhite
				\ nextgroup=mrxvtrcTitle,mrxvtrcShell,mrxvtrcCmd
				\ NewTab
syn region	mrxvtrcTitle	contained oneline skipwhite
				\ nextgroup=mrxvtrcShell,mrxvtrcCmd
				\ start='"' end='"'
syn match	mrxvtrcShell	contained nextgroup=mrxvtrcCmd '!' 
syn match	mrxvtrcCmd	contained '\v[^!" \t].*'

" ToggleSubwin macro
syn keyword	mrxvtrcMacro	contained skipwhite
				\ nextgroup=mrxvtrcSubwin,mrxvtrcError
				\ ToggleSubwin
syn match	mrxvtrcSubwin	contained skipwhite nextgroup=mrxvtrcError
				\ '\v[-+]?[bmst]>'

"
" Highlighting groups
"
hi def link mrxvtrcError	Error
hi def link mrxvtrcComment	Comment

hi def link mrxvtrcClass	Statement
hi def link mrxvtrcOptions	mrxvtrcClass
hi def link mrxvtrcBColon	mrxvtrcClass
hi def link mrxvtrcCColon	mrxvtrcClass
hi def link mrxvtrcNColon	mrxvtrcClass
hi def link mrxvtrcSColon	mrxvtrcClass
hi def link mrxvtrcProfile	mrxvtrcClass
hi def link mrxvtrcPSOpts	mrxvtrcClass
hi def link mrxvtrcPCOpts	mrxvtrcClass
hi def link mrxvtrcPNOpts	mrxvtrcClass

hi def link mrxvtrcBoolVal	Boolean
hi def link mrxvtrcStrVal	String
hi def link mrxvtrcColorVal	Constant
hi def link mrxvtrcNumVal	Number

hi def link mrxvtrcSBstyle	mrxvtrcStrVal
hi def link mrxvtrcSBalign	mrxvtrcStrVal
hi def link mrxvtrcTSmode	mrxvtrcStrVal
hi def link mrxvtrcGrkKbd	mrxvtrcStrVal
hi def link mrxvtrcXftWt	mrxvtrcStrVal
hi def link mrxvtrcXftSl	mrxvtrcStrVal
hi def link mrxvtrcXftWd	mrxvtrcStrVal
hi def link mrxvtrcXftHt	mrxvtrcStrVal
hi def link mrxvtrcPedit	mrxvtrcStrVal
hi def link mrxvtrcMod		mrxvtrcStrVal
hi def link mrxvtrcSelSty	mrxvtrcStrVal

hi def link mrxvtrcMacro	Identifier
hi def link mrxvtrcKey		mrxvtrcClass
hi def link mrxvtrcTitle	mrxvtrcStrVal
hi def link mrxvtrcShell	Special
hi def link mrxvtrcCmd		PreProc
hi def link mrxvtrcSubwin	mrxvtrcStrVal

let b:current_syntax = "mrxvtrc"

let &cpo = s:cpo_save
unlet s:cpo_save
