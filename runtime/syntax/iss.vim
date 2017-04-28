" Vim syntax file
" Language:             Inno Setup File (iss file) and My InnoSetup extension
" Maintainer:           Jason Mills (jmills@cs.mun.ca)
" Previous Maintainer:  Dominique Stéphan (dominique@mggen.com)
" Last Change:          2004 Dec 14
"
" Todo:
"  - The paramter String: is matched as flag string (because of case ignore).
"  - Pascal scripting syntax is not recognized.
"  - Embedded double quotes confuse string matches. e.g. "asfd""asfa"

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" shut case off
syn case ignore

" Preprocessor
syn region issPreProc start="^\s*#" end="$"

" Section
syn region issSection	start="\[" end="\]"

" Label in the [Setup] Section
syn match  issDirective	"^[^=]\+="

" URL
syn match  issURL	"http[s]\=:\/\/.*$"

" Parameters used for any section.
" syn match  issParam"[^: ]\+:"
syn match  issParam	"Name:"
syn match  issParam	"MinVersion:\|OnlyBelowVersion:\|Languages:"
syn match  issParam	"Source:\|DestDir:\|DestName:\|CopyMode:"
syn match  issParam	"Attribs:\|Permissions:\|FontInstall:\|Flags:"
syn match  issParam	"FileName:\|Parameters:\|WorkingDir:\|HotKey:\|Comment:"
syn match  issParam	"IconFilename:\|IconIndex:"
syn match  issParam	"Section:\|Key:\|String:"
syn match  issParam	"Root:\|SubKey:\|ValueType:\|ValueName:\|ValueData:"
syn match  issParam	"RunOnceId:"
syn match  issParam	"Type:\|Excludes:"
syn match  issParam	"Components:\|Description:\|GroupDescription:\|Types:\|ExtraDiskSpaceRequired:"
syn match  issParam	"StatusMsg:\|RunOnceId:\|Tasks:"
syn match  issParam	"MessagesFile:\|LicenseFile:\|InfoBeforeFile:\|InfoAfterFile:"

syn match  issComment	"^\s*;.*$"

" folder constant
syn match  issFolder	"{[^{]*}"

" string
syn region issString	start=+"+ end=+"+ contains=issFolder

" [Dirs]
syn keyword issDirsFlags deleteafterinstall uninsalwaysuninstall uninsneveruninstall

" [Files]
syn keyword issFilesCopyMode normal onlyifdoesntexist alwaysoverwrite alwaysskipifsameorolder dontcopy
syn keyword issFilesAttribs readonly hidden system
syn keyword issFilesPermissions full modify readexec
syn keyword issFilesFlags allowunsafefiles comparetimestampalso confirmoverwrite deleteafterinstall
syn keyword issFilesFlags dontcopy dontverifychecksum external fontisnttruetype ignoreversion 
syn keyword issFilesFlags isreadme onlyifdestfileexists onlyifdoesntexist overwritereadonly 
syn keyword issFilesFlags promptifolder recursesubdirs regserver regtypelib restartreplace
syn keyword issFilesFlags sharedfile skipifsourcedoesntexist sortfilesbyextension touch 
syn keyword issFilesFlags uninsremovereadonly uninsrestartdelete uninsneveruninstall
syn keyword issFilesFlags replacesameversion nocompression noencryption noregerror


" [Icons]
syn keyword issIconsFlags closeonexit createonlyiffileexists dontcloseonexit 
syn keyword issIconsFlags runmaximized runminimized uninsneveruninstall useapppaths

" [INI]
syn keyword issINIFlags createkeyifdoesntexist uninsdeleteentry uninsdeletesection uninsdeletesectionifempty

" [Registry]
syn keyword issRegRootKey   HKCR HKCU HKLM HKU HKCC
syn keyword issRegValueType none string expandsz multisz dword binary
syn keyword issRegFlags createvalueifdoesntexist deletekey deletevalue dontcreatekey 
syn keyword issRegFlags preservestringtype noerror uninsclearvalue 
syn keyword issRegFlags uninsdeletekey uninsdeletekeyifempty uninsdeletevalue

" [Run] and [UninstallRun]
syn keyword issRunFlags hidewizard nowait postinstall runhidden runmaximized
syn keyword issRunFlags runminimized shellexec skipifdoesntexist skipifnotsilent 
syn keyword issRunFlags skipifsilent unchecked waituntilidle

" [Types]
syn keyword issTypesFlags iscustom

" [Components]
syn keyword issComponentsFlags dontinheritcheck exclusive fixed restart disablenouninstallwarning

" [UninstallDelete] and [InstallDelete]
syn keyword issInstallDeleteType files filesandordirs dirifempty

" [Tasks]
syn keyword issTasksFlags checkedonce dontinheritcheck exclusive restart unchecked 


" Define the default highlighting.
" Only when an item doesn't have highlighting yet

" The default methods for highlighting.  Can be overridden later
hi def link issSection	Special
hi def link issComment	Comment
hi def link issDirective	Type
hi def link issParam	Type
hi def link issFolder	Special
hi def link issString	String
hi def link issURL	Include
hi def link issPreProc	PreProc 

hi def link issDirsFlags		Keyword
hi def link issFilesCopyMode	Keyword
hi def link issFilesAttribs	Keyword
hi def link issFilesPermissions	Keyword
hi def link issFilesFlags		Keyword
hi def link issIconsFlags		Keyword
hi def link issINIFlags		Keyword
hi def link issRegRootKey		Keyword
hi def link issRegValueType	Keyword
hi def link issRegFlags		Keyword
hi def link issRunFlags		Keyword
hi def link issTypesFlags		Keyword
hi def link issComponentsFlags	Keyword
hi def link issInstallDeleteType	Keyword
hi def link issTasksFlags		Keyword


let b:current_syntax = "iss"

" vim:ts=8
