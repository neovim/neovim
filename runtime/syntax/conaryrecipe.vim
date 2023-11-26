" Vim syntax file
" Language:	Conary Recipe
" Maintainer:	rPath Inc <http://www.rpath.com>
" Updated:	2007-12-08

if exists("b:current_syntax")
  finish
endif

runtime! syntax/python.vim

syn keyword conarySFunction	mainDir addAction addSource addArchive addPatch
syn keyword conarySFunction	addRedirect addSvnSnapshot addMercurialSnapshot
syn keyword conarySFunction	addCvsSnapshot addGitSnapshot addBzrSnapshot

syn keyword conaryGFunction	add addAll addNewGroup addReference createGroup
syn keyword conaryGFunction	addNewGroup startGroup remove removeComponents
syn keyword conaryGFunction	replace setByDefault setDefaultGroup 
syn keyword conaryGFunction	setLabelPath addCopy setSearchPath AddAllFlags
syn keyword conaryGFunction	GroupRecipe GroupReference TroveCacheWrapper
syn keyword conaryGFunction	TroveCache buildGroups findTrovesForGroups
syn keyword conaryGFunction	followRedirect processAddAllDirectives
syn keyword conaryGFunction	processOneAddAllDirective removeDifferences
syn keyword conaryGFunction	addTrovesToGroup addCopiedComponents
syn keyword conaryGFunction	findAllWeakTrovesToRemove checkForRedirects
syn keyword conaryGFunction	addPackagesForComponents getResolveSource
syn keyword conaryGFunction	resolveGroupDependencies checkGroupDependencies
syn keyword conaryGFunction	calcSizeAndCheckHashes findSourcesForGroup
syn keyword conaryGFunction	addPostInstallScript addPostRollbackScript
syn keyword conaryGFunction	addPostUpdateScript addPreUpdateScript
syn keyword conaryGFunction	addTrove moveComponents copyComponents
syn keyword conaryGFunction	removeItemsAlsoInNewGroup removeItemsAlsoInGroup
syn keyword conaryGFunction	addResolveSource iterReplaceSpecs
syn keyword conaryGFunction	setCompatibilityClass getLabelPath
syn keyword conaryGFunction	getResolveTroveSpecs getSearchFlavor
syn keyword conaryGFunction	getChildGroups getGroupMap

syn keyword conaryBFunction 	Run Automake Configure ManualConfigure 
syn keyword conaryBFunction 	Make MakeParallelSubdir MakeInstall
syn keyword conaryBFunction 	MakePathsInstall CompilePython
syn keyword conaryBFunction 	Ldconfig Desktopfile Environment SetModes
syn keyword conaryBFunction 	Install Copy Move Symlink Link Remove Doc
syn keyword conaryBFunction 	Create MakeDirs disableParallelMake
syn keyword conaryBFunction 	ConsoleHelper Replace SGMLCatalogEntry
syn keyword conaryBFunction 	XInetdService XMLCatalogEntry TestSuite
syn keyword conaryBFunction	PythonSetup CMake Ant JavaCompile ClassPath
syn keyword conaryBFunction	JavaDoc IncludeLicense MakeFIFO

syn keyword conaryPFunction 	NonBinariesInBindirs FilesInMandir 
syn keyword conaryPFunction 	ImproperlyShared CheckSonames CheckDestDir
syn keyword conaryPFunction 	ComponentSpec PackageSpec 
syn keyword conaryPFunction 	Config InitScript GconfSchema SharedLibrary
syn keyword conaryPFunction 	ParseManifest MakeDevices DanglingSymlinks
syn keyword conaryPFunction 	AddModes WarnWriteable IgnoredSetuid
syn keyword conaryPFunction 	Ownership ExcludeDirectories
syn keyword conaryPFunction 	BadFilenames BadInterpreterPaths ByDefault
syn keyword conaryPFunction 	ComponentProvides ComponentRequires Flavor
syn keyword conaryPFunction 	EnforceConfigLogBuildRequirements Group
syn keyword conaryPFunction 	EnforceSonameBuildRequirements InitialContents
syn keyword conaryPFunction 	FilesForDirectories LinkCount
syn keyword conaryPFunction 	MakdeDevices NonMultilibComponent ObsoletePaths
syn keyword conaryPFunction 	NonMultilibDirectories NonUTF8Filenames TagSpec
syn keyword conaryPFunction 	Provides RequireChkconfig Requires TagHandler
syn keyword conaryPFunction 	TagDescription Transient User UtilizeGroup
syn keyword conaryPFunction 	WorldWritableExecutables UtilizeUser
syn keyword conaryPFunction 	WarnWritable Strip CheckDesktopFiles
syn keyword conaryPFunction	FixDirModes LinkType reportMissingBuildRequires
syn keyword conaryPFunction	reportErrors FixupManpagePaths FixObsoletePaths
syn keyword conaryPFunction	NonLSBPaths PythonEggs
syn keyword conaryPFunction	EnforcePythonBuildRequirements
syn keyword conaryPFunction	EnforceJavaBuildRequirements
syn keyword conaryPFunction	EnforceCILBuildRequirements
syn keyword conaryPFunction	EnforcePerlBuildRequirements
syn keyword conaryPFunction	EnforceFlagBuildRequirements
syn keyword conaryPFunction	FixupMultilibPaths ExecutableLibraries
syn keyword conaryPFunction	NormalizeLibrarySymlinks NormalizeCompression
syn keyword conaryPFunction	NormalizeManPages NormalizeInfoPages
syn keyword conaryPFunction	NormalizeInitscriptLocation
syn keyword conaryPFunction	NormalizeInitscriptContents
syn keyword conaryPFunction	NormalizeAppDefaults NormalizeInterpreterPaths
syn keyword conaryPFunction	NormalizePamConfig ReadableDocs
syn keyword conaryPFunction	WorldWriteableExecutables NormalizePkgConfig
syn keyword conaryPFunction	EtcConfig InstallBucket SupplementalGroup
syn keyword conaryPFunction	FixBuilddirSymlink RelativeSymlinks

" Most destdirPolicy aren't called from recipes, except for these
syn keyword conaryPFunction	AutoDoc RemoveNonPackageFiles TestSuiteFiles
syn keyword conaryPFunction	TestSuiteLinks

syn match   conaryMacro		"%(\w\+)[sd]" contained
syn match   conaryBadMacro	"%(\w*)[^sd]" contained " no final marker
syn keyword conaryArches	contained x86 x86_64 alpha ia64 ppc ppc64 s390
syn keyword conaryArches	contained sparc sparc64
syn keyword conarySubArches	contained sse2 3dnow 3dnowext cmov i486 i586
syn keyword conarySubArches	contained i686 mmx mmxext nx sse sse2
syn keyword conaryBad		RPM_BUILD_ROOT EtcConfig InstallBucket subDir
syn keyword conaryBad		RPM_OPT_FLAGS subdir 
syn cluster conaryArchFlags 	contains=conaryArches,conarySubArches
syn match   conaryArch		"Arch\.[a-z0-9A-Z]\+" contains=conaryArches,conarySubArches
syn match   conaryArch		"Arch\.[a-z0-9A-Z]\+" contains=conaryArches,conarySubArches
syn keyword conaryKeywords	name buildRequires version clearBuildReqs
syn keyword conaryUseFlag	contained pcre tcpwrappers gcj gnat selinux pam 
syn keyword conaryUseFlag	contained bootstrap python perl 
syn keyword conaryUseFlag	contained readline gdbm emacs krb builddocs 
syn keyword conaryUseFlag	contained alternatives tcl tk X gtk gnome qt
syn keyword conaryUseFlag	contained xfce gd ldap sasl pie desktop ssl kde
syn keyword conaryUseFlag	contained slang netpbm nptl ipv6 buildtests
syn keyword conaryUseFlag	contained ntpl xen dom0 domU
syn match   conaryUse		"Use\.[a-z0-9A-Z]\+" contains=conaryUseFlag

" strings
syn region pythonString		matchgroup=Normal start=+[uU]\='+ end=+'+ skip=+\\\\\|\\'+ contains=pythonEscape,conaryMacro,conaryBadMacro
syn region pythonString		matchgroup=Normal start=+[uU]\="+ end=+"+ skip=+\\\\\|\\"+ contains=pythonEscape,conaryMacro,conaryBadMacro
syn region pythonString		matchgroup=Normal start=+[uU]\="""+ end=+"""+ contains=pythonEscape,conaryMacro,conaryBadMacro
syn region pythonString		matchgroup=Normal start=+[uU]\='''+ end=+'''+ contains=pythonEscape,conaryMacro,conaryBadMacro
syn region pythonRawString	matchgroup=Normal start=+[uU]\=[rR]'+ end=+'+ skip=+\\\\\|\\'+ contains=conaryMacro,conaryBadMacro
syn region pythonRawString	matchgroup=Normal start=+[uU]\=[rR]"+ end=+"+ skip=+\\\\\|\\"+ contains=conaryMacro,conaryBadMacro
syn region pythonRawString	matchgroup=Normal start=+[uU]\=[rR]"""+ end=+"""+ contains=conaryMacro,conaryBadMacro
syn region pythonRawString	matchgroup=Normal start=+[uU]\=[rR]'''+ end=+'''+ contains=conaryMacro,conaryBadMacro

hi def link conaryMacro			Special
hi def link conaryrecipeFunction	Function
hi def link conaryError			Error
hi def link conaryBFunction		conaryrecipeFunction
hi def link conaryGFunction        	conaryrecipeFunction
hi def link conarySFunction		Operator
hi def link conaryPFunction		Typedef
hi def link conaryFlags			PreCondit
hi def link conaryArches		Special
hi def link conarySubArches		Special
hi def link conaryBad			conaryError
hi def link conaryBadMacro		conaryError
hi def link conaryKeywords		Special
hi def link conaryUseFlag		Typedef

let b:current_syntax = "conaryrecipe"

