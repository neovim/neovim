" Vim syntax file
" Language:	APT config file
" Maintainer:	Yann Amar <quidame@poivron.org>
" Last Change:	2021 Jul 12

" quit when a syntax file was already loaded
if !exists("main_syntax")
  if exists("b:current_syntax")
    finish
  endif
  let main_syntax = 'aptconf'
endif

let s:cpo_save = &cpo
set cpo&vim

" Errors:
" Catch all that is not overridden by next rules/items:
syn match	aptconfError		display '[^[:blank:]]'
syn match	aptconfError		display '^[^[:blank:]][^:{]*'

" Options:
" Define a general regular expression for the options that are not defined
" later as keywords. Following apt.conf(5), we know that options are case
" insensitive, and can contain alphanumeric characters and '/-:._+'; we
" assume that there can not be consecutive colons (::) which is used as
" syntax operator; we also assume that an option name can not start or end
" by a colon.
syn case	ignore
syn match	aptconfRegexpOpt	'[-[:alnum:]/.+_]\+\(:[-[:alnum:]/.+_]\+\)*' contained display

" Keywords:
setlocal iskeyword+=/,-,.,_,+
"setlocal iskeyword+=: is problematic, because of the '::' separator

" Incomplete keywords will be treated differently than completely bad strings:
syn keyword	aptconfGroupIncomplete
	\ a[cquire] a[dequate] a[ptitude] a[ptlistbugs] d[ebtags] d[ebug]
	\ d[ir] d[pkg] d[select] o[rderlist] p[ackagemanager] p[kgcachegen]
	\ q[uiet] r[pm] s[ynaptic] u[nattended-upgrade] w[hatmaps]

" Only the following keywords can be used at toplevel (to begin an option):
syn keyword	aptconfGroup
	\ acquire adequate apt aptitude aptlistbugs debtags debug
	\ dir dpkg dselect orderlist packagemanager pkgcachegen
	\ quiet rpm synaptic unattended-upgrade whatmaps

" Possible options for each group:
" Acquire: {{{
syn keyword	aptconfAcquire contained
	\ cdrom Check-Valid-Until CompressionTypes ForceHash ForceIPv4
	\ ForceIPv6 ftp gpgv GzipIndexes http https Languages Max-ValidTime
	\ Min-ValidTime PDiffs Queue-Mode Retries Source-Symlinks

syn keyword	aptconfAcquireCDROM contained
	\ AutoDetect CdromOnly Mount UMount

syn keyword	aptconfAcquireCompressionTypes contained
	\ bz2 lzma gz Order

syn keyword	aptconfAcquireFTP contained
	\ ForceExtended Passive Proxy ProxyLogin Timeout

syn keyword	aptconfAcquireHTTP contained
	\ AllowRedirect Dl-Limit Max-Age No-Cache No-Store Pipeline-Depth
	\ Proxy ProxyAutoDetect Proxy-Auto-Detect Timeout User-Agent

syn keyword	aptconfAcquireHTTPS contained
	\ AllowRedirect CaInfo CaPath CrlFile Dl-Limit IssuerCert Max-Age
	\ No-Cache No-Store Proxy SslCert SslForceVersion SslKey Timeout
	\ Verify-Host Verify-Peer

syn keyword	aptconfAcquireMaxValidTime contained
	\ Debian Debian-Security

syn keyword	aptconfAcquirePDiffs contained
	\ FileLimit SizeLimit

syn cluster	aptconfAcquire_ contains=aptconfAcquire,
	\ aptconfAcquireCDROM,aptconfAcquireCompressionTypes,aptconfAcquireFTP,
	\ aptconfAcquireHTTP,aptconfAcquireHTTPS,aptconfAcquireMaxValidTime,
	\ aptconfAcquirePDiffs
" }}}
" Adequate: {{{
syn keyword	aptconfAdequate contained
	\ Enabled

syn cluster	aptconfAdequate_ contains=aptconfAdequate
" }}}
" Apt: {{{
syn keyword	aptconfApt contained
	\ Architecture Architectures Archive Authentication AutoRemove
	\ Build-Essential Build-Profiles Cache Cache-Grow Cache-Limit
	\ Cache-Start CDROM Changelogs Clean-Installed Compressor
	\ Default-Release Force-LoopBreak Get Ignore-Hold Immediate-Configure
	\ Install-Recommends Install-Suggests Keep-Fds List-Cleanup
	\ Move-Autobit-Sections NeverAutoRemove Never-MarkAuto-Sections
	\ Periodic Status-Fd Update VersionedKernelPackages

syn keyword	aptconfAptAuthentication contained
	\ TrustCDROM

syn keyword	aptconfAptAutoRemove contained
	\ RecommendsImportant SuggestsImportant

syn keyword	aptconfAptCache contained
	\ AllNames AllVersions Generate GivenOnly Important Installed NamesOnly
	\ RecurseDepends ShowFull

syn keyword	aptconfAptCDROM contained
	\ Fast NoAct NoMount Rename

syn keyword	aptconfAptChangelogs contained
	\ Server

syn keyword	aptconfAptCompressor contained
	\ bzip2 gzip lzma xz

syn keyword	aptconfAptCompressorAll contained
	\ Binary CompressArg Cost Extension Name UncompressArg

syn keyword	aptconfAptGet contained
	\ AllowUnauthenticated Arch-Only Assume-No Assume-Yes AutomaticRemove
	\ Build-Dep-Automatic Compile Diff-Only Download Download-Only Dsc-Only
	\ Fix-Broken Fix-Missing Force-Yes HideAutoRemove Host-Architecture
	\ List-Cleanup Only-Source Print-URIs Purge ReInstall Remove
	\ Show-Upgraded Show-User-Simulation-Note Show-Versions Simulate
	\ Tar-Only Trivial-Only Upgrade

syn keyword	aptconfAptPeriodic contained
	\ AutocleanInterval BackupArchiveInterval BackupLevel
	\ Download-Upgradeable-Packages Download-Upgradeable-Packages-Debdelta
	\ Enable MaxAge MaxSize MinAge Unattended-Upgrade Update-Package-Lists
	\ Verbose

syn keyword	aptconfAptUpdate contained
	\ List-Refresh Pre-Invoke Post-Invoke Post-Invoke-Success

syn cluster	aptconfApt_ contains=aptconfApt,
	\ aptconfAptAuthentication,aptconfAptAutoRemove,aptconfAptCache,
	\ aptconfAptCDROM,aptconfAptChangelogs,aptconfAptCompressor,
	\ aptconfAptCompressorAll,aptconfAptGet,aptconfAptPeriodic,
	\ aptconfAptUpdate
" }}}
" Aptitude: {{{
syn keyword	aptconfAptitude contained
	\ Allow-Null-Upgrade Always-Use-Safe-Resolver Autoclean-After-Update
	\ Auto-Install Auto-Fix-Broken Cmdline Debtags-Binary
	\ Debtags-Update-Options Delete-Unused Delete-Unused-Pattern
	\ Display-Planned-Action Forget-New-On-Install Forget-New-On-Update
	\ Get-Root-Command Ignore-Old-Tmp Ignore-Recommends-Important
	\ Keep-Recommends Keep-Suggests Keep-Unused-Pattern LockFile Log
	\ Logging Parse-Description-Bullets Pkg-Display-Limit ProblemResolver
	\ Purge-Unused Recommends-Important Safe-Resolver Screenshot Sections
	\ Simulate Spin-Interval Suggests-Important Suppress-Read-Only-Warning
	\ Theme Track-Dselect-State UI Warn-Not-Root

syn keyword	aptconfAptitudeCmdline contained
	\ Always-Prompt Assume-Yes Disable-Columns Download-Only Fix-Broken
	\ Ignore-Trust-Violations Package-Display-Format Package-Display-Width
	\ Progress Request-Strictness Resolver-Debug Resolver-Dump
	\ Resolver-Show-Steps Safe-Upgrade Show-Deps Show-Size-Changes
	\ Show-Versions Show-Why Simulate Verbose Version-Display-Format
	\ Versions-Group-By Versions-Show-Package-Names Visual-Preview
	\ Why-Display-Mode

syn keyword	aptconfAptitudeCmdlineProgress contained
	\ Percent-On-Right Retain-Completed

syn keyword	aptconfAptitudeCmdlineSafeUpgrade contained
	\ No-New-Installs

syn keyword	aptconfAptitudeLogging contained
	\ File Levels

syn keyword	aptconfAptitudeProblemResolver contained
	\ Allow-Break-Holds BreakHoldScore Break-Hold-Level BrokenScore
	\ DefaultResolutionScore Discard-Null-Solution
	\ EssentialRemoveScore ExtraScore FullReplacementScore FutureHorizon
	\ Hints ImportantScore Infinity InstallScore Keep-All-Level KeepScore
	\ NonDefaultScore Non-Default-Level OptionalScore PreserveAutoScore
	\ PreserveManualScore RemoveScore Remove-Essential-Level Remove-Level
	\ RequiredScore ResolutionScore Safe-Level SolutionCost StandardScore
	\ StepLimit StepScore Trace-Directory Trace-File
	\ UndoFullReplacementScore UnfixedSoftScore UpgradeScore

syn keyword	aptconfAptitudeSafeResolver contained
	\ No-New-Installs No-New-Upgrades Show-Resolver-Actions

syn keyword	aptconfAptitudeScreenshot contained
	\ Cache-Max IncrementalLoadLimit

syn keyword	aptconfAptitudeSections contained
	\ Descriptions Top-Sections

syn keyword	aptconfAptitudeUI contained
	\ Advance-On-Action Auto-Show-Reasons Default-Grouping
	\ Default-Package-View Default-Preview-Grouping Default-Sorting
	\ Description-Visible-By-Default Exit-On-Last-Close Fill-Text
	\ Flat-View-As-First-View HelpBar Incremental-Search InfoAreaTabs
	\ KeyBindings MenuBar-Autohide Minibuf-Download-Bar Minibuf-Prompts
	\ New-package-Commands Package-Display-Format Package-Header-Format
	\ Package-Status-Format Pause-After-Download Preview-Limit
	\ Prompt-On-Exit Styles ViewTabs

syn keyword	aptconfAptitudeUIKeyBindings contained
	\ ApplySolution Begin BugReport Cancel Changelog ChangePkgTreeGrouping
	\ ChangePkgTreeLimit ChangePkgTreeSorting ClearAuto CollapseAll
	\ CollapseTree Commit Confirm Cycle CycleNext CycleOrder CyclePrev
	\ DelBOL DelBack DelEOL DelForward Dependencies DescriptionCycle
	\ DescriptionDown DescriptionUp DoInstallRun Down DpkgReconfigure
	\ DumpResolver EditHier End ExamineSolution ExpandAll ExpandTree
	\ FirstSolution ForbidUpgrade ForgetNewPackages Help HistoryNext
	\ HistoryPrev Hold Install InstallSingle Keep LastSolution Left
	\ LevelDown LevelUp MarkUpgradable MineFlagSquare MineLoadGame
	\ MineSaveGame MineSweepSquare MineUncoverSquare MineUncoverSweepSquare
	\ NextPage NextSolution No Parent PrevPage PrevSolution Purge
	\ PushButton Quit QuitProgram RejectBreakHolds Refresh Remove
	\ ReInstall RepeatSearchBack ReSearch ReverseDependencies Right
	\ SaveHier Search SearchBack SearchBroken SetAuto ShowHideDescription
	\ SolutionActionApprove SolutionActionReject ToggleExpanded
	\ ToggleMenuActive Undo Up UpdatePackageList Versions Yes

syn keyword	aptconfAptitudeUIStyles contained
	\ Bullet ChangeLogNewerVersion Default DepBroken DisabledMenuEntry
	\ DownloadHit DownloadProgress EditLine Error Header HighlightedMenuBar
	\ HighlightedMenuEntry MediaChange MenuBar MenuBorder MenuEntry
	\ MineBomb MineBorder MineFlag MineNumber1 MineNumber2 MineNumber3
	\ MineNumber4 MineNumber5 MineNumber6 MineNumber7 MineNumber8
	\ MultiplexTab MultiplexTabHighlighted PkgBroken PkgBrokenHighlighted
	\ PkgIsInstalled PkgIsInstalledHighlighted PkgNotInstalled
	\ PkgNotInstalledHighlighted PkgToDowngrade PkgToDowngradeHighlighted
	\ PkgToHold PkgToHoldHighlighted PkgToInstall PkgToInstallHighlighted
	\ PkgToRemove PkgToRemoveHighlighted PkgToUpgrade
	\ PkgToUpgradeHighlighted Progress SolutionActionApproved
	\ SolutionActionRejected Status TreeBackground TrustWarning

syn keyword	aptconfAptitudeUIStylesElements contained
	\ bg clear fg flip set

syn cluster	aptconfAptitude_ contains=aptconfAptitude,
	\ aptconfAptitudeCmdline,aptconfAptitudeCmdlineProgress,
	\ aptconfAptitudeCmdlineSafeUpgrade,aptconfAptitudeLogging,
	\ aptconfAptitudeProblemResolver,aptconfAptitudeSafeResolver,
	\ aptconfAptitudeScreenshot,aptconfAptitudeSections,aptconfAptitudeUI,
	\ aptconfAptitudeUIKeyBindings,aptconfAptitudeUIStyles,
	\ aptconfAptitudeUIStylesElements
" }}}
" AptListbugs: {{{
syn keyword	aptconfAptListbugs contained
	\ IgnoreRegexp Severities

syn cluster	aptconfAptListbugs_ contains=aptconfAptListbugs
" }}}
" DebTags: {{{
syn keyword	aptconfDebTags contained
	\ Vocabulary

syn cluster	aptconfDebTags_ contains=aptconfDebTags
" }}}
" Debug: {{{
syn keyword	aptconfDebug contained
	\ Acquire aptcdrom BuildDeps Hashes IdentCdrom Nolocking
	\ pkgAcquire pkgAutoRemove pkgCacheGen pkgDepCache pkgDPkgPM
	\ pkgDPkgProgressReporting pkgInitialize pkgOrderList
	\ pkgPackageManager pkgPolicy pkgProblemResolver RunScripts
	\ sourceList

syn keyword	aptconfDebugAcquire contained
	\ cdrom Ftp gpgv Http Https netrc

syn keyword	aptconfDebugPkgAcquire contained
	\ Auth Diffs RRed Worker

syn keyword	aptconfDebugPkgDepCache contained
	\ AutoInstall Marker

syn keyword	aptconfDebugPkgProblemResolver contained
	\ ShowScores

syn cluster	aptconfDebug_ contains=aptconfDebug,
	\ aptconfDebugAcquire,aptconfDebugPkgAcquire,aptconfDebugPkgDepCache,
	\ aptconfDebugPkgProblemResolver
" }}}
" Dir: {{{
syn keyword	aptconfDir contained
	\ Aptitude Bin Cache Etc Ignore-Files-Silently Log Media Parts RootDir
	\ State

syn keyword	aptconfDirAptitude contained
	\ state

syn keyword	aptconfDirBin contained
	\ apt-get apt-cache dpkg dpkg-buildpackage dpkg-source gpg gzip Methods
	\ solvers

syn keyword	aptconfDirCache contained
	\ Archives Backup pkgcache srcpkgcache

syn keyword	aptconfDirEtc contained
	\ Main Netrc Parts Preferences PreferencesParts SourceList SourceParts
	\ VendorList VendorParts Trusted TrustedParts

syn keyword	aptconfDirLog contained
	\ History Terminal

syn keyword	aptconfDirMedia contained
	\ MountPath

syn keyword	aptconfDirState contained
	\ cdroms extended_states Lists mirrors preferences status

syn cluster	aptconfDir_ contains=aptconfDir,
	\ aptconfDirAptitude,aptconfDirBin,aptconfDirCache,aptconfDirEtc,
	\ aptconfDirLog,aptconfDirMedia,aptconfDirState
" }}}
" DPkg: {{{
syn keyword	aptconfDPkg contained
	\ Build-Options Chroot-Directory ConfigurePending FlushSTDIN
	\ MaxArgBytes MaxArgs MaxBytes NoTriggers options
	\ Pre-Install-Pkgs Pre-Invoke Post-Invoke
	\ Run-Directory StopOnError Tools TriggersPending

syn keyword	aptconfDPkgTools contained
	\ adequate InfoFD Options Version

syn cluster	aptconfDPkg_ contains=aptconfDPkg,
	\ aptconfDPkgTools
" }}}
" DSelect: {{{
syn keyword	aptconfDSelect contained
	\ CheckDir Clean Options PromptAfterUpdate UpdateOptions

syn cluster	aptconfDSelect_ contains=aptconfDSelect
" }}}
" OrderList: {{{
syn keyword	aptconfOrderList contained
	\ Score

syn keyword	aptconfOrderListScore contained
	\ Delete Essential Immediate PreDepends

syn cluster	aptconfOrderList_ contains=aptconfOrderList,
	\ aptconfOrderListScore
" }}}
" PackageManager: {{{
syn keyword	aptconfPackageManager contained
	\ Configure

syn cluster	aptconfPackageManager_ contains=aptconfPackageManager
" }}}
" PkgCacheGen: {{{
syn keyword	aptconfPkgCacheGen contained
	\ Essential

syn cluster	aptconfPkgCacheGen_ contains=aptconfPkgCacheGen
" }}}
" Quiet: {{{
syn keyword	aptconfQuiet contained
	\ NoUpdate

syn cluster	aptconfQuiet_ contains=aptconfQuiet
" }}}
" Rpm: {{{
syn keyword	aptconfRpm contained
	\ Post-Invoke Pre-Invoke

syn cluster	aptconfRpm_ contains=aptconfRpm
" }}}
" Synaptic: {{{
syn keyword	aptconfSynaptic contained
	\ AskQuitOnProceed AskRelated AutoCleanCache CleanCache DefaultDistro
	\ delAction delHistory Download-Only ftpProxy ftpProxyPort httpProxy
	\ httpProxyPort Install-Recommends LastSearchType Maximized noProxy
	\ OneClickOnStatusActions ShowAllPkgInfoInMain showWelcomeDialog
	\ ToolbarState undoStackSize update upgradeType useProxy UseStatusColors
	\ UseTerminal useUserFont useUserTerminalFont ViewMode
	\ availVerColumnPos availVerColumnVisible componentColumnPos
	\ componentColumnVisible descrColumnPos descrColumnVisible
	\ downloadSizeColumnPos downloadSizeColumnVisible hpanedPos
	\ instVerColumnPos instVerColumnVisible instSizeColumnPos
	\ instSizeColumnVisible nameColumnPos nameColumnVisible
	\ sectionColumnPos sectionColumnVisible statusColumnPos
	\ statusColumnVisible supportedColumnPos supportedColumnVisible
	\ vpanedPos windowWidth windowHeight windowX windowY closeZvt
	\ color-available color-available-locked color-broken color-downgrade
	\ color-install color-installed-locked color-installed-outdated
	\ color-installed-updated color-new color-purge color-reinstall
	\ color-remove color-upgrade

syn keyword	aptconfSynapticUpdate contained
	\ last type

syn cluster	aptconfSynaptic_ contains=aptconfSynaptic,
	\ aptconfSynapticUpdate
" }}}
" Unattended Upgrade: {{{
syn keyword	aptconfUnattendedUpgrade contained
	\ Allow-APT-Mark-Fallback Allow-downgrade AutoFixInterruptedDpkg
	\ Automatic-Reboot Automatic-Reboot-Time Automatic-Reboot-WithUsers
	\ Debug InstallOnShutdown Mail MailOnlyOnError MailReport MinimalSteps
	\ OnlyOnACPower Origins-Pattern Package-Blacklist
	\ Remove-New-Unused-Dependencies Remove-Unused-Dependencies
	\ Remove-Unused-Kernel-Packages Skip-Updates-On-Metered-Connections
	\ SyslogEnable SyslogFacility Verbose

syn cluster	aptconfUnattendedUpgrade_ contains=aptconfUnattendedUpgrade
" }}}
" Whatmaps: {{{
syn keyword	aptconfWhatmaps contained
	\ Enable-Restart Security-Update-Origins

syn cluster	aptconfWhatmaps_ contains=aptconfWhatmaps
" }}}

syn case	match

" Now put all the keywords (and 'valid' options) in a single cluster:
syn cluster	aptconfOptions contains=aptconfRegexpOpt,
	\ @aptconfAcquire_,@aptconfAdequate_,@aptconfApt_,@aptconfAptitude_,
	\ @aptconfAptListbugs_,@aptconfDebTags_,@aptconfDebug_,@aptconfDir_,
	\ @aptconfDPkg_,@aptconfDSelect_,@aptconfOrderList_,
	\ @aptconfPackageManager_,@aptconfPkgCacheGen_,@aptconfQuiet_,
	\ @aptconfRpm_,@aptconfSynaptic_,@aptconfUnattendedUpgrade_,
	\ @aptconfWhatmaps_

" Syntax:
syn match	aptconfSemiColon	';'
syn match	aptconfDoubleColon	'::'
syn match	aptconfCurlyBraces	'[{}]'
syn region	aptconfValue		start='"' end='"' oneline display
syn region	aptconfInclude		matchgroup=aptconfOperator start='{' end='}' contains=ALLBUT,aptconfGroup,aptconfGroupIncomplete,@aptconfCommentSpecial
syn region	aptconfInclude		matchgroup=aptconfOperator start='::' end='{'me=s-1 contains=@aptconfOptions,aptconfError display
syn region	aptconfInclude		matchgroup=aptconfOperator start='::' end='::\|\s'me=s-1 oneline contains=@aptconfOptions,aptconfError display

" Basic Syntax Errors: XXX avoid to generate false positives !!!
"
" * Undocumented inline comment. Since it is currently largely used, and does
" not seem to cause trouble ('apt-config dump' never complains when # is used
" the same way than //) it has been moved to aptconfComment group. But it
" still needs to be defined here (i.e. before #clear and #include directives)
syn match	aptconfComment		'#.*' contains=@aptconfCommentSpecial
"
" * When a semicolon is missing after a double-quoted string:
" There are some cases (for example in the Dir group of options, but not only)
" where this syntax is valid. So we don't treat it as a strict error.
syn match	aptconfAsError		display '"[^"]*"[^;]'me=e-1
syn match	aptconfAsError		display '"[^"]*"$'
"
" * When double quotes are missing around a value (before a semicolon):
" This omission has no effect if the value is a single string (without blank
" characters). But apt.conf(5) says that quotes are required, and this item
" avoids to match unquoted keywords.
syn match	aptconfAsError		display '\s[^"[:blank:]]*[^}"];'me=e-1
"
" * When only one double quote is missing around a value (before a semicolon):
" No comment for that: it must be highly visible.
syn match	aptconfError		display '\(\s\|;\)"[^"[:blank:]]\+;'me=e-1
syn match	aptconfError		display '\(\s\|;\)[^"[:blank:]]\+";'me=e-1
"
" * When space is missing between option and (quoted) value:
" TODO (partially implemented)
syn match	aptconfError		display '::[^[:blank:]]*"'

" Special Actions:
syn match	aptconfAction		'^#\(clear\|include\)\>'
syn region	aptconfAction		matchgroup=aptconfAction start='^#clear\>' end=';'me=s-1 oneline contains=aptconfGroup,aptconfDoubleColon,@aptconfOptions
syn region	aptconfAction		matchgroup=aptconfAction start='^#include\>' end=';'me=s-1 oneline contains=aptconfRegexpOpt

" Comments:
syn keyword	aptconfTodo		TODO FIXME NOTE XXX contained
syn cluster	aptconfCommentSpecial	contains=@Spell,aptconfTodo
syn match	aptconfComment		'//.*' contains=@aptconfCommentSpecial
syn region	aptconfComment		start='/\*' end='\*/' contains=@aptconfCommentSpecial

" Highlight Definitions:
hi def link aptconfTodo				Todo
hi def link aptconfError			Error
hi def link aptconfComment			Comment
hi def link aptconfOperator			Operator

hi def link aptconfAction			PreProc
hi def link aptconfOption			Type
hi def link aptconfValue			String
hi def link aptconfRegexpOpt			Normal
hi def link aptconfAsError			Special

hi def link aptconfSemiColon			aptconfOperator
hi def link aptconfDoubleColon			aptconfOperator
hi def link aptconfCurlyBraces			aptconfOperator

hi def link aptconfGroupIncomplete		Special
hi def link aptconfGroup			aptconfOption

hi def link aptconfAcquire			aptconfOption
hi def link aptconfAcquireCDROM			aptconfOption
hi def link aptconfAcquireCompressionTypes	aptconfOption
hi def link aptconfAcquireFTP			aptconfOption
hi def link aptconfAcquireHTTP			aptconfOption
hi def link aptconfAcquireHTTPS			aptconfOption
hi def link aptconfAcquireMaxValidTime		aptconfOption
hi def link aptconfAcquirePDiffs		aptconfOption

hi def link aptconfAdequate			aptconfOption

hi def link aptconfApt				aptconfOption
hi def link aptconfAptAuthentication		aptconfOption
hi def link aptconfAptAutoRemove		aptconfOption
hi def link aptconfAptCache			aptconfOption
hi def link aptconfAptCDROM			aptconfOption
hi def link aptconfAptChangelogs		aptconfOption
hi def link aptconfAptCompressor		aptconfOption
hi def link aptconfAptCompressorAll		aptconfOption
hi def link aptconfAptGet			aptconfOption
hi def link aptconfAptPeriodic			aptconfOption
hi def link aptconfAptUpdate			aptconfOption

hi def link aptconfAptitude			aptconfOption
hi def link aptconfAptitudeCmdline		aptconfOption
hi def link aptconfAptitudeCmdlineProgress	aptconfOption
hi def link aptconfAptitudeCmdlineSafeUpgrade	aptconfOption
hi def link aptconfAptitudeLogging		aptconfOption
hi def link aptconfAptitudeProblemResolver	aptconfOption
hi def link aptconfAptitudeSafeResolver		aptconfOption
hi def link aptconfAptitudeScreenshot		aptconfOption
hi def link aptconfAptitudeSections		aptconfOption
hi def link aptconfAptitudeUI			aptconfOption
hi def link aptconfAptitudeUIKeyBindings	aptconfOption
hi def link aptconfAptitudeUIStyles		aptconfOption
hi def link aptconfAptitudeUIStylesElements	aptconfOption

hi def link aptconfAptListbugs			aptconfOption

hi def link aptconfDebTags			aptconfOption

hi def link aptconfDebug			aptconfOption
hi def link aptconfDebugAcquire			aptconfOption
hi def link aptconfDebugPkgAcquire		aptconfOption
hi def link aptconfDebugPkgDepCache		aptconfOption
hi def link aptconfDebugPkgProblemResolver	aptconfOption

hi def link aptconfDir				aptconfOption
hi def link aptconfDirAptitude			aptconfOption
hi def link aptconfDirBin			aptconfOption
hi def link aptconfDirCache			aptconfOption
hi def link aptconfDirEtc			aptconfOption
hi def link aptconfDirLog			aptconfOption
hi def link aptconfDirMedia			aptconfOption
hi def link aptconfDirState			aptconfOption

hi def link aptconfDPkg				aptconfOption
hi def link aptconfDPkgTools			aptconfOption

hi def link aptconfDSelect			aptconfOption

hi def link aptconfOrderList			aptconfOption
hi def link aptconfOrderListScore		aptconfOption

hi def link aptconfPackageManager		aptconfOption

hi def link aptconfPkgCacheGen			aptconfOption

hi def link aptconfQuiet			aptconfOption

hi def link aptconfRpm				aptconfOption

hi def link aptconfSynaptic			aptconfOption
hi def link aptconfSynapticUpdate		aptconfOption

hi def link aptconfUnattendedUpgrade		aptconfOption

hi def link aptconfWhatmaps			aptconfOption

let b:current_syntax = "aptconf"

let &cpo = s:cpo_save
unlet s:cpo_save
