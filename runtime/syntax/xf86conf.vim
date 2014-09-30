" Vim syntax file
" This is a GENERATED FILE. Please always refer to source file at the URI below.
" Language: XF86Config (XFree86 configuration file)
" Former Maintainer: David Ne\v{c}as (Yeti) <yeti@physics.muni.cz>
" Last Change: 2010 Nov 01
" URL: http://trific.ath.cx/Ftp/vim/syntax/xf86conf.vim
" Required Vim Version: 6.0
"
" Options: let xf86conf_xfree86_version = 3 or 4
"							 to force XFree86 3.x or 4.x XF86Config syntax

" Setup
if version >= 600
	if exists("b:current_syntax")
		finish
	endif
else
	echo "Sorry, but this syntax file relies on Vim 6 features.	 Either upgrade Vim or usea version of " . expand("<sfile>:t:r") . " syntax file appropriate for Vim " . version/100 . "." . version %100 . "."
	finish
endif

if !exists("b:xf86conf_xfree86_version")
	if exists("xf86conf_xfree86_version")
		let b:xf86conf_xfree86_version = xf86conf_xfree86_version
	else
		let b:xf86conf_xfree86_version = 4
	endif
endif

syn case ignore

" Comments
syn match xf86confComment "#.*$" contains=xf86confTodo
syn case match
syn keyword xf86confTodo FIXME TODO XXX NOT contained
syn case ignore
syn match xf86confTodo "???" contained

" Sectioning errors
syn keyword xf86confSectionError Section contained
syn keyword xf86confSectionError EndSection
syn keyword xf86confSubSectionError SubSection
syn keyword xf86confSubSectionError EndSubSection
syn keyword xf86confModeSubSectionError Mode
syn keyword xf86confModeSubSectionError EndMode
syn cluster xf86confSectionErrors contains=xf86confSectionError,xf86confSubSectionError,xf86confModeSubSectionError

" Values
if b:xf86conf_xfree86_version >= 4
	syn region xf86confString start=+"+ skip=+\\\\\|\\"+ end=+"+ contained contains=xf86confSpecialChar,xf86confConstant,xf86confOptionName oneline keepend nextgroup=xf86confValue skipwhite
else
	syn region xf86confString start=+"+ skip=+\\\\\|\\"+ end=+"+ contained contains=xf86confSpecialChar,xf86confOptionName oneline keepend
endif
syn match xf86confSpecialChar "\\\d\d\d\|\\." contained
syn match xf86confDecimalNumber "\(\s\|-\)\zs\d*\.\=\d\+\>"
syn match xf86confFrequency "\(\s\|-\)\zs\d\+\.\=\d*\(Hz\|k\|kHz\|M\|MHz\)"
syn match xf86confOctalNumber "\<0\o\+\>"
syn match xf86confOctalNumberError "\<0\o\+[89]\d*\>"
syn match xf86confHexadecimalNumber "\<0x\x\+\>"
syn match xf86confValue "\s\+.*$" contained contains=xf86confComment,xf86confString,xf86confFrequency,xf86conf\w\+Number,xf86confConstant
syn keyword xf86confOption Option nextgroup=xf86confString skipwhite
syn match xf86confModeLineValue "\"[^\"]\+\"\(\_s\+[0-9.]\+\)\{9}" nextgroup=xf86confSync skipwhite skipnl

" Sections and subsections
if b:xf86conf_xfree86_version >= 4
	syn region xf86confSection matchgroup=xf86confSectionDelim start="^\s*Section\s\+\"\(Files\|Server[_ ]*Flags\|Input[_ ]*Device\|Device\|Video[_ ]*Adaptor\|Server[_ ]*Layout\|DRI\|Extensions\|Vendor\|Keyboard\|Pointer\|InputClass\)\"" end="^\s*EndSection\>" skip="#.*$\|\"[^\"]*\"" contains=xf86confComment,xf86confOption,xf86confKeyword,xf86confSectionError
	syn region xf86confSectionModule matchgroup=xf86confSectionDelim start="^\s*Section\s\+\"Module\"" end="^\s*EndSection\>" skip="#.*$\|\"[^\"]*\"" contains=xf86confSubsectionAny,xf86confComment,xf86confOption,xf86confKeyword
	syn region xf86confSectionMonitor matchgroup=xf86confSectionDelim start="^\s*Section\s\+\"Monitor\"" end="^\s*EndSection\>" skip="#.*$\|\"[^\"]*\"" contains=xf86confSubsectionMode,xf86confModeLine,xf86confComment,xf86confOption,xf86confKeyword
	syn region xf86confSectionModes matchgroup=xf86confSectionDelim start="^\s*Section\s\+\"Modes\"" end="^\s*EndSection\>" skip="#.*$\|\"[^\"]*\"" contains=xf86confSubsectionMode,xf86confModeLine,xf86confComment
	syn region xf86confSectionScreen matchgroup=xf86confSectionDelim start="^\s*Section\s\+\"Screen\"" end="^\s*EndSection\>" skip="#.*$\|\"[^\"]*\"" contains=xf86confSubsectionDisplay,xf86confComment,xf86confOption,xf86confKeyword
	syn region xf86confSubSectionAny matchgroup=xf86confSectionDelim start="^\s*SubSection\s\+\"[^\"]\+\"" end="^\s*EndSubSection\>" skip="#.*$\|\"[^\"]*\"" contains=xf86confComment,xf86confOption,xf86confKeyword,@xf86confSectionErrors
	syn region xf86confSubSectionMode matchgroup=xf86confSectionDelim start="^\s*Mode\s\+\"[^\"]\+\"" end="^\s*EndMode\>" skip="#.*$\|\"[^\"]*\"" contains=xf86confComment,xf86confKeyword,@xf86confSectionErrors
	syn region xf86confSubSectionDisplay matchgroup=xf86confSectionDelim start="^\s*SubSection\s\+\"Display\"" end="^\s*EndSubSection\>" skip="#.*$\|\"[^\"]*\"" contains=xf86confComment,xf86confOption,xf86confKeyword,@xf86confSectionErrors
else
	syn region xf86confSection matchgroup=xf86confSectionDelim start="^\s*Section\s\+\"\(Files\|Server[_ ]*Flags\|Device\|Keyboard\|Pointer\)\"" end="^\s*EndSection\>" skip="#.*$\|\"[^\"]*\"" contains=xf86confComment,xf86confOptionName,xf86confOption,xf86confKeyword
	syn region xf86confSectionMX matchgroup=xf86confSectionDelim start="^\s*Section\s\+\"\(Module\|Xinput\)\"" end="^\s*EndSection\>" skip="#.*$\|\"[^\"]*\"" contains=xf86confSubsectionAny,xf86confComment,xf86confOptionName,xf86confOption,xf86confKeyword
	syn region xf86confSectionMonitor matchgroup=xf86confSectionDelim start="^\s*Section\s\+\"Monitor\"" end="^\s*EndSection\>" skip="#.*$\|\"[^\"]*\"" contains=xf86confSubsectionMode,xf86confModeLine,xf86confComment,xf86confOptionName,xf86confOption,xf86confKeyword
	syn region xf86confSectionScreen matchgroup=xf86confSectionDelim start="^\s*Section\s\+\"Screen\"" end="^\s*EndSection\>" skip="#.*$\|\"[^\"]*\"" contains=xf86confSubsectionDisplay,xf86confComment,xf86confOptionName,xf86confOption,xf86confKeyword
	syn region xf86confSubSectionAny matchgroup=xf86confSectionDelim start="^\s*SubSection\s\+\"[^\"]\+\"" end="^\s*EndSubSection\>" skip="#.*$\|\"[^\"]*\"" contains=xf86confComment,xf86confOptionName,xf86confOption,xf86confKeyword,@xf86confSectionErrors
	syn region xf86confSubSectionMode matchgroup=xf86confSectionDelim start="^\s*Mode\s\+\"[^\"]\+\"" end="^\s*EndMode\>" skip="#.*$\|\"[^\"]*\"" contains=xf86confComment,xf86confOptionName,xf86confOption,xf86confKeyword,@xf86confSectionErrors
	syn region xf86confSubSectionDisplay matchgroup=xf86confSectionDelim start="^\s*SubSection\s\+\"Display\"" end="^\s*EndSubSection\>" skip="#.*$\|\"[^\"]*\"" contains=xf86confComment,xf86confOptionName,xf86confOption,xf86confKeyword,@xf86confSectionErrors
endif

" Options
if b:xf86conf_xfree86_version >= 4
	command -nargs=+ Xf86confdeclopt syn keyword xf86confOptionName <args> contained
else
	command -nargs=+ Xf86confdeclopt syn keyword xf86confOptionName <args> contained nextgroup=xf86confValue,xf86confComment skipwhite
endif

Xf86confdeclopt 18bitBus AGPFastWrite AGPMode Accel AllowClosedownGrabs AllowDeactivateGrabs
Xf86confdeclopt AllowMouseOpenFail AllowNonLocalModInDev AllowNonLocalXvidtune AlwaysCore
Xf86confdeclopt AngleOffset AutoRepeat BaudRate BeamTimeout Beep BlankTime BlockWrite BottomX
Xf86confdeclopt BottomY ButtonNumber ButtonThreshold Buttons ByteSwap CacheLines ChordMiddle
Xf86confdeclopt ClearDTR ClearDTS ClickMode CloneDisplay CloneHSync CloneMode CloneVRefresh
Xf86confdeclopt ColorKey Composite CompositeSync CoreKeyboard CorePointer Crt2Memory CrtScreen
Xf86confdeclopt CrtcNumber CyberShadow CyberStretch DDC DDCMode DMAForXv DPMS Dac6Bit DacSpeed
Xf86confdeclopt DataBits Debug DebugLevel DefaultServerLayout DeltaX DeltaY Device DeviceName
Xf86confdeclopt DisableModInDev DisableVidModeExtension Display Display1400 DontVTSwitch
Xf86confdeclopt DontZap DontZoom DoubleScan DozeMode DozeScan DozeTime DragLockButtons
Xf86confdeclopt DualCount DualRefresh EarlyRasPrecharge Emulate3Buttons Emulate3Timeout
Xf86confdeclopt EmulateWheel EmulateWheelButton EmulateWheelInertia EnablePageFlip EnterCount
Xf86confdeclopt EstimateSizesAggressively ExternDisp FPClock16 FPClock24 FPClock32
Xf86confdeclopt FPClock8 FPDither FastDram FifoAggresive FifoConservative FifoModerate
Xf86confdeclopt FireGL3000 FixPanelSize FlatPanel FlipXY FlowControl ForceCRT1 ForceCRT2Type
Xf86confdeclopt ForceLegacyCRT ForcePCIMode FpmVRAM FrameBufferWC FullMMIO GammaBrightness
Xf86confdeclopt HWClocks HWCursor HandleSpecialKeys HistorySize Interlace Interlaced InternDisp
Xf86confdeclopt InvX InvY InvertX InvertY KeepShape LCDClock LateRasPrecharge LcdCenter
Xf86confdeclopt LeftAlt Linear MGASDRAM MMIO MMIOCache MTTR MaxX MaxY MaximumXPosition
Xf86confdeclopt MaximumYPosition MinX MinY MinimumXPosition MinimumYPosition NoAccel
Xf86confdeclopt NoAllowMouseOpenFail NoAllowNonLocalModInDev NoAllowNonLocalXvidtune
Xf86confdeclopt NoBlockWrite NoCompositeSync NoCompression NoCrtScreen NoCyberShadow NoDCC
Xf86confdeclopt NoDDC NoDac6Bit NoDebug NoDisableModInDev NoDisableVidModeExtension NoDontZap
Xf86confdeclopt NoDontZoom NoFireGL3000 NoFixPanelSize NoFpmVRAM NoFrameBufferWC NoHWClocks
Xf86confdeclopt NoHWCursor NoHal NoLcdCenter NoLinear NoMGASDRAM NoMMIO NoMMIOCache NoMTTR
Xf86confdeclopt NoOverClockMem NoOverlay NoPC98 NoPM NoPciBurst NoPciRetry NoProbeClock
Xf86confdeclopt NoSTN NoSWCursor NoShadowFb NoShowCache NoSlowEDODRAM NoStretch NoSuspendHack
Xf86confdeclopt NoTexturedVideo NoTrapSignals NoUseFBDev NoUseModeline NoUseVclk1 NoVTSysReq
Xf86confdeclopt NoXVideo NvAGP OSMImageBuffers OffTime Origin OverClockMem Overlay
Xf86confdeclopt PC98 PCIBurst PM PWMActive PWMSleep PanelDelayCompensation PanelHeight
Xf86confdeclopt PanelOff PanelWidth Parity PciBurst PciRetry Pixmap Port PressDur PressPitch
Xf86confdeclopt PressVol ProbeClocks ProgramFPRegs Protocol RGBBits ReleaseDur ReleasePitch
Xf86confdeclopt ReportingMode Resolution RightAlt RightCtl Rotate STN SWCursor SampleRate
Xf86confdeclopt ScreenNumber ScrollLock SendCoreEvents SendDragEvents Serial ServerNumLock
Xf86confdeclopt SetLcdClk SetMClk SetRefClk ShadowFb ShadowStatus ShowCache SleepMode
Xf86confdeclopt SleepScan SleepTime SlowDram SlowEDODRAM StandbyTime StopBits Stretch
Xf86confdeclopt SuspendHack SuspendTime SwapXY SyncOnGreen TV TVOutput TVOverscan TVStandard
Xf86confdeclopt TVXPosOffset TVYPosOffset TexturedVideo Threshold Tilt TopX TopY TouchTime
Xf86confdeclopt TrapSignals Type USB UseBIOS UseFB UseFBDev UseFlatPanel UseModeline
Xf86confdeclopt UseROMData UseVclk1 VTInit VTSysReq VTime VideoKey Vmin XAxisMapping
Xf86confdeclopt XLeds XVideo XaaNoCPUToScreenColorExpandFill XaaNoColor8x8PatternFillRect
Xf86confdeclopt XaaNoColor8x8PatternFillTrap XaaNoDashedBresenhamLine XaaNoDashedTwoPointLine
Xf86confdeclopt XaaNoImageWriteRect XaaNoMono8x8PatternFillRect XaaNoMono8x8PatternFillTrap
Xf86confdeclopt XaaNoOffscreenPixmaps XaaNoPixmapCache XaaNoScanlineCPUToScreenColorExpandFill
Xf86confdeclopt XaaNoScanlineImageWriteRect XaaNoScreenToScreenColorExpandFill
Xf86confdeclopt XaaNoScreenToScreenCopy XaaNoSolidBresenhamLine XaaNoSolidFillRect
Xf86confdeclopt XaaNoSolidFillTrap XaaNoSolidHorVertLine XaaNoSolidTwoPointLine Xinerama
Xf86confdeclopt XkbCompat XkbDisable XkbGeometry XkbKeycodes XkbKeymap XkbLayout XkbModel
Xf86confdeclopt XkbOptions XkbRules XkbSymbols XkbTypes XkbVariant XvBskew XvHsync XvOnCRT2
Xf86confdeclopt XvRskew XvVsync YAxisMapping ZAxisMapping ZoomOnLCD

delcommand Xf86confdeclopt

" Keywords
syn keyword xf86confKeyword Device Driver FontPath Group Identifier Load ModelName ModulePath Monitor RGBPath VendorName VideoAdaptor Visual nextgroup=xf86confComment,xf86confString skipwhite
syn keyword xf86confKeyword BiosBase Black BoardName BusID ChipID ChipRev Chipset nextgroup=xf86confComment,xf86confValue
syn keyword xf86confKeyword ClockChip Clocks DacSpeed DefaultDepth DefaultFbBpp nextgroup=xf86confComment,xf86confValue
syn keyword xf86confKeyword DefaultColorDepth nextgroup=xf86confComment,xf86confValue
syn keyword xf86confKeyword Depth DisplaySize DotClock FbBpp Flags Gamma HorizSync nextgroup=xf86confComment,xf86confValue
syn keyword xf86confKeyword Hskew HTimings InputDevice IOBase MemBase Mode nextgroup=xf86confComment,xf86confValue
syn keyword xf86confKeyword Modes Ramdac Screen TextClockFreq UseModes VendorName nextgroup=xf86confComment,xf86confValue
syn keyword xf86confKeyword VertRefresh VideoRam ViewPort Virtual VScan VTimings nextgroup=xf86confComment,xf86confValue
syn keyword xf86confKeyword Weight White nextgroup=xf86confComment,xf86confValue
syn keyword xf86confModeLine ModeLine nextgroup=xf86confComment,xf86confModeLineValue skipwhite skipnl

" Constants
if b:xf86conf_xfree86_version >= 4
	syn keyword xf86confConstant true false on off yes no omit contained
else
	syn keyword xf86confConstant Meta Compose Control
endif
syn keyword xf86confConstant StaticGray GrayScale StaticColor PseudoColor TrueColor DirectColor contained
syn keyword xf86confConstant Absolute RightOf LeftOf Above Below Relative StaticGray GrayScale StaticColor PseudoColor TrueColor DirectColor contained
syn match xf86confSync "\(\s\+[+-][CHV]_*Sync\)\+" contained

" Synchronization
if b:xf86conf_xfree86_version >= 4
	syn sync match xf86confSyncSection grouphere xf86confSection "^\s*Section\s\+\"\(Files\|Server[_ ]*Flags\|Input[_ ]*Device\|Device\|Video[_ ]*Adaptor\|Server[_ ]*Layout\|DRI\|Extensions\|Vendor\|Keyboard\|Pointer\|InputClass\)\""
	syn sync match xf86confSyncSectionModule grouphere xf86confSectionModule "^\s*Section\s\+\"Module\""
	syn sync match xf86confSyncSectionModes groupthere xf86confSectionModes "^\s*Section\s\+\"Modes\""
else
	syn sync match xf86confSyncSection grouphere xf86confSection "^\s*Section\s\+\"\(Files\|Server[_ ]*Flags\|Device\|Keyboard\|Pointer\)\""
	syn sync match xf86confSyncSectionMX grouphere xf86confSectionMX "^\s*Section\s\+\"\(Module\|Xinput\)\""
endif
syn sync match xf86confSyncSectionMonitor groupthere xf86confSectionMonitor "^\s*Section\s\+\"Monitor\""
syn sync match xf86confSyncSectionScreen groupthere xf86confSectionScreen "^\s*Section\s\+\"Screen\""
syn sync match xf86confSyncEndSection groupthere NONE "^\s*End_*Section\s*$"

" Define the default highlighting
hi def link xf86confComment Comment
hi def link xf86confTodo Todo
hi def link xf86confSectionDelim Statement
hi def link xf86confOptionName Identifier

hi def link xf86confSectionError xf86confError
hi def link xf86confSubSectionError xf86confError
hi def link xf86confModeSubSectionError xf86confError
hi def link xf86confOctalNumberError xf86confError
hi def link xf86confError Error

hi def link xf86confOption xf86confKeyword
hi def link xf86confModeLine xf86confKeyword
hi def link xf86confKeyword Type

hi def link xf86confDecimalNumber xf86confNumber
hi def link xf86confOctalNumber xf86confNumber
hi def link xf86confHexadecimalNumber xf86confNumber
hi def link xf86confFrequency xf86confNumber
hi def link xf86confModeLineValue Constant
hi def link xf86confNumber Constant

hi def link xf86confSync xf86confConstant
hi def link xf86confConstant Special
hi def link xf86confSpecialChar Special
hi def link xf86confString String

hi def link xf86confValue Constant

let b:current_syntax = "xf86conf"
