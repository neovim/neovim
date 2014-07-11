" Vim syntax file
" Language:	InstallShield Script
" Maintainer:	Robert M. Cortopassi <cortopar@mindspring.com>
" Last Change:	2001 May 09

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn keyword ishdStatement abort begin case default downto else end
syn keyword ishdStatement endif endfor endwhile endswitch endprogram exit elseif
syn keyword ishdStatement error for function goto if
syn keyword ishdStatement program prototype return repeat string step switch
syn keyword ishdStatement struct then to typedef until while

syn keyword ishdType BOOL BYREF CHAR GDI HWND INT KERNEL LIST LONG
syn keyword ishdType NUMBER POINTER SHORT STRING USER

syn keyword ishdConstant _MAX_LENGTH _MAX_STRING
syn keyword ishdConstant AFTER ALLCONTENTS ALLCONTROLS APPEND ASKDESTPATH
syn keyword ishdConstant ASKOPTIONS ASKPATH ASKTEXT BATCH_INSTALL BACK
syn keyword ishdConstant BACKBUTTON BACKGROUND BACKGROUNDCAPTION BADPATH
syn keyword ishdConstant BADTAGFILE BASEMEMORY BEFORE BILLBOARD BINARY
syn keyword ishdConstant BITMAP256COLORS BITMAPFADE BITMAPICON BK_BLUE BK_GREEN
syn keyword ishdConstant BK_MAGENTA BK_MAGENTA1 BK_ORANGE BK_PINK BK_RED
syn keyword ishdConstant BK_SMOOTH BK_SOLIDBLACK  BK_SOLIDBLUE BK_SOLIDGREEN
syn keyword ishdConstant BK_SOLIDMAGENTA BK_SOLIDORANGE BK_SOLIDPINK BK_SOLIDRED
syn keyword ishdConstant BK_SOLIDWHITE BK_SOLIDYELLOW BK_YELLOW BLACK BLUE
syn keyword ishdConstant BOOTUPDRIVE BUTTON_CHECKED BUTTON_ENTER BUTTON_UNCHECKED
syn keyword ishdConstant BUTTON_UNKNOWN CMDLINE COMMONFILES CANCEL CANCELBUTTON
syn keyword ishdConstant CC_ERR_FILEFORMATERROR CC_ERR_FILEREADERROR
syn keyword ishdConstant CC_ERR_NOCOMPONENTLIST CC_ERR_OUTOFMEMORY CDROM
syn keyword ishdConstant CDROM_DRIVE CENTERED CHANGEDIR CHECKBOX CHECKBOX95
syn keyword ishdConstant CHECKLINE CHECKMARK CMD_CLOSE CMD_MAXIMIZE CMD_MINIMIZE
syn keyword ishdConstant CMD_PUSHDOWN CMD_RESTORE COLORMODE256 COLORS
syn keyword ishdConstant COMBOBOX_ENTER COMBOBOX_SELECT COMMAND COMMANDEX
syn keyword ishdConstant COMMON COMP_DONE COMP_ERR_CREATEDIR
syn keyword ishdConstant COMP_ERR_DESTCONFLICT COMP_ERR_FILENOTINLIB
syn keyword ishdConstant COMP_ERR_FILESIZE COMP_ERR_FILETOOLARGE
syn keyword ishdConstant COMP_ERR_HEADER COMP_ERR_INCOMPATIBLE
syn keyword ishdConstant COMP_ERR_INTPUTNOTCOMPRESSED COMP_ERR_INVALIDLIST
syn keyword ishdConstant COMP_ERR_LAUNCHSERVER COMP_ERR_MEMORY
syn keyword ishdConstant COMP_ERR_NODISKSPACE COMP_ERR_OPENINPUT
syn keyword ishdConstant COMP_ERR_OPENOUTPUT COMP_ERR_OPTIONS
syn keyword ishdConstant COMP_ERR_OUTPUTNOTCOMPRESSED COMP_ERR_SPLIT
syn keyword ishdConstant COMP_ERR_TARGET COMP_ERR_TARGETREADONLY COMP_ERR_WRITE
syn keyword ishdConstant COMP_INFO_ATTRIBUTE COMP_INFO_COMPSIZE COMP_INFO_DATE
syn keyword ishdConstant COMP_INFO_INVALIDATEPASSWORD COMP_INFO_ORIGSIZE
syn keyword ishdConstant COMP_INFO_SETPASSWORD COMP_INFO_TIME
syn keyword ishdConstant COMP_INFO_VERSIONLS COMP_INFO_VERSIONMS COMP_NORMAL
syn keyword ishdConstant COMP_UPDATE_DATE COMP_UPDATE_DATE_NEWER
syn keyword ishdConstant COMP_UPDATE_SAME COMP_UPDATE_VERSION COMPACT
syn keyword ishdConstant COMPARE_DATE COMPARE_SIZE COMPARE_VERSION
syn keyword ishdConstant COMPONENT_FIELD_CDROM_FOLDER
syn keyword ishdConstant COMPONENT_FIELD_DESCRIPTION COMPONENT_FIELD_DESTINATION
syn keyword ishdConstant COMPONENT_FIELD_DISPLAYNAME COMPONENT_FIELD_FILENEED
syn keyword ishdConstant COMPONENT_FIELD_FTPLOCATION
syn keyword ishdConstant COMPONENT_FIELD_HTTPLOCATION COMPONENT_FIELD_MISC
syn keyword ishdConstant COMPONENT_FIELD_OVERWRITE COMPONENT_FIELD_PASSWORD
syn keyword ishdConstant COMPONENT_FIELD_SELECTED COMPONENT_FIELD_SIZE
syn keyword ishdConstant COMPONENT_FIELD_STATUS COMPONENT_FIELD_VISIBLE
syn keyword ishdConstant COMPONENT_FILEINFO_COMPRESSED
syn keyword ishdConstant COMPONENT_FILEINFO_COMPRESSENGINE
syn keyword ishdConstant COMPONENT_FILEINFO_LANGUAGECOMPONENT_FILEINFO_OS
syn keyword ishdConstant COMPONENT_FILEINFO_POTENTIALLYLOCKED
syn keyword ishdConstant COMPONENT_FILEINFO_SELFREGISTERING
syn keyword ishdConstant COMPONENT_FILEINFO_SHARED COMPONENT_INFO_ATTRIBUTE
syn keyword ishdConstant COMPONENT_INFO_COMPSIZE COMPONENT_INFO_DATE
syn keyword ishdConstant COMPONENT_INFO_DATE_EX_EX COMPONENT_INFO_LANGUAGE
syn keyword ishdConstant COMPONENT_INFO_ORIGSIZE COMPONENT_INFO_OS
syn keyword ishdConstant COMPONENT_INFO_TIME COMPONENT_INFO_VERSIONLS
syn keyword ishdConstant COMPONENT_INFO_VERSIONMS COMPONENT_INFO_VERSIONSTR
syn keyword ishdConstant COMPONENT_VALUE_ALWAYSOVERWRITE
syn keyword ishdConstant COMPONENT_VALUE_CRITICAL
syn keyword ishdConstant COMPONENT_VALUE_HIGHLYRECOMMENDED
syn keyword ishdConstant COMPONENT_FILEINFO_LANGUAGE COMPONENT_FILEINFO_OS
syn keyword ishdConstant COMPONENT_VALUE_NEVEROVERWRITE
syn keyword ishdConstant COMPONENT_VALUE_NEWERDATE COMPONENT_VALUE_NEWERVERSION
syn keyword ishdConstant COMPONENT_VALUE_OLDERDATE COMPONENT_VALUE_OLDERVERSION
syn keyword ishdConstant COMPONENT_VALUE_SAMEORNEWDATE
syn keyword ishdConstant COMPONENT_VALUE_SAMEORNEWERVERSION
syn keyword ishdConstant COMPONENT_VALUE_STANDARD COMPONENT_VIEW_CHANGE
syn keyword ishdConstant COMPONENT_INFO_DATE_EX COMPONENT_VIEW_CHILDVIEW
syn keyword ishdConstant COMPONENT_VIEW_COMPONENT COMPONENT_VIEW_DESCRIPTION
syn keyword ishdConstant COMPONENT_VIEW_MEDIA COMPONENT_VIEW_PARENTVIEW
syn keyword ishdConstant COMPONENT_VIEW_SIZEAVAIL COMPONENT_VIEW_SIZETOTAL
syn keyword ishdConstant COMPONENT_VIEW_TARGETLOCATION COMPRESSHIGH COMPRESSLOW
syn keyword ishdConstant COMPRESSMED COMPRESSNONE CONTIGUOUS CONTINUE
syn keyword ishdConstant COPY_ERR_CREATEDIR COPY_ERR_NODISKSPACE
syn keyword ishdConstant COPY_ERR_OPENINPUT COPY_ERR_OPENOUTPUT
syn keyword ishdConstant COPY_ERR_TARGETREADONLY COPY_ERR_MEMORY
syn keyword ishdConstant CORECOMPONENTHANDLING CPU CUSTOM DATA_COMPONENT
syn keyword ishdConstant DATA_LIST DATA_NUMBER DATA_STRING DATE DEFAULT
syn keyword ishdConstant DEFWINDOWMODE DELETE_EOF DIALOG DIALOGCACHE
syn keyword ishdConstant DIALOGTHINFONT DIR_WRITEABLE DIRECTORY DISABLE DISK
syn keyword ishdConstant DISK_FREESPACE DISK_TOTALSPACE DISKID DLG_ASK_OPTIONS
syn keyword ishdConstant DLG_ASK_PATH DLG_ASK_TEXT DLG_ASK_YESNO DLG_CANCEL
syn keyword ishdConstant DLG_CDIR DLG_CDIR_MSG DLG_CENTERED DLG_CLOSE
syn keyword ishdConstant DLG_DIR_DIRECTORY DLG_DIR_FILE DLG_ENTER_DISK DLG_ERR
syn keyword ishdConstant DLG_ERR_ALREADY_EXISTS DLG_ERR_ENDDLG DLG_INFO_ALTIMAGE
syn keyword ishdConstant DLG_INFO_CHECKMETHOD DLG_INFO_CHECKSELECTION
syn keyword ishdConstant DLG_INFO_ENABLEIMAGE DLG_INFO_KUNITS
syn keyword ishdConstant DLG_INFO_USEDECIMAL DLG_INIT DLG_MSG_ALL
syn keyword ishdConstant DLG_MSG_INFORMATION DLG_MSG_NOT_HAND DLG_MSG_SEVERE
syn keyword ishdConstant DLG_MSG_STANDARD DLG_MSG_WARNING DLG_OK DLG_STATUS
syn keyword ishdConstant DLG_USER_CAPTION DRIVE DRIVEOPEN DLG_DIR_DRIVE
syn keyword ishdConstant EDITBOX_CHANGE EFF_BOXSTRIPE EFF_FADE EFF_HORZREVEAL
syn keyword ishdConstant EFF_HORZSTRIPE EFF_NONE EFF_REVEAL EFF_VERTSTRIPE
syn keyword ishdConstant ENABLE END_OF_FILE END_OF_LIST ENHANCED ENTERDISK
syn keyword ishdConstant ENTERDISK_ERRMSG ENTERDISKBEEP ENVSPACE EQUALS
syn keyword ishdConstant ERR_BADPATH ERR_BADTAGFILE ERR_BOX_BADPATH
syn keyword ishdConstant ERR_BOX_BADTAGFILE ERR_BOX_DISKID ERR_BOX_DRIVEOPEN
syn keyword ishdConstant ERR_BOX_EXIT ERR_BOX_HELP ERR_BOX_NOSPACE ERR_BOX_PAUSE
syn keyword ishdConstant ERR_BOX_READONLY ERR_DISKID ERR_DRIVEOPEN
syn keyword ishdConstant EXCLUDE_SUBDIR EXCLUSIVE EXISTS EXIT EXTENDEDMEMORY
syn keyword ishdConstant EXTENSION_ONLY ERRORFILENAME FADE_IN FADE_OUT
syn keyword ishdConstant FAILIFEXISTS FALSE FDRIVE_NUM FEEDBACK FEEDBACK_FULL
syn keyword ishdConstant FEEDBACK_OPERATION FEEDBACK_SPACE FILE_ATTR_ARCHIVED
syn keyword ishdConstant FILE_ATTR_DIRECTORY FILE_ATTR_HIDDEN FILE_ATTR_NORMAL
syn keyword ishdConstant FILE_ATTR_READONLY FILE_ATTR_SYSTEM FILE_ATTRIBUTE
syn keyword ishdConstant FILE_BIN_CUR FILE_BIN_END FILE_BIN_START FILE_DATE
syn keyword ishdConstant FILE_EXISTS FILE_INSTALLED FILE_INVALID FILE_IS_LOCKED
syn keyword ishdConstant FILE_LINE_LENGTH FILE_LOCKED FILE_MODE_APPEND
syn keyword ishdConstant FILE_MODE_BINARY FILE_MODE_BINARYREADONLY
syn keyword ishdConstant FILE_MODE_NORMAL FILE_NO_VERSION FILE_NOT_FOUND
syn keyword ishdConstant FILE_RD_ONLY FILE_SIZE FILE_SRC_EQUAL FILE_SRC_OLD
syn keyword ishdConstant FILE_TIME FILE_WRITEABLE FILENAME FILENAME_ONLY
syn keyword ishdConstant FINISHBUTTON FIXED_DRIVE FONT_TITLE FREEENVSPACE
syn keyword ishdConstant FS_CREATEDIR FS_DISKONEREQUIRED FS_DONE FS_FILENOTINLIB
syn keyword ishdConstant FS_GENERROR FS_INCORRECTDISK FS_LAUNCHPROCESS
syn keyword ishdConstant FS_OPERROR FS_OUTOFSPACE FS_PACKAGING FS_RESETREQUIRED
syn keyword ishdConstant FS_TARGETREADONLY FS_TONEXTDISK FULL FULLSCREEN
syn keyword ishdConstant FULLSCREENSIZE FULLWINDOWMODE FOLDER_DESKTOP
syn keyword ishdConstant FOLDER_PROGRAMS FOLDER_STARTMENU FOLDER_STARTUP
syn keyword ishdConstant GREATER_THAN GREEN HELP HKEY_CLASSES_ROOT
syn keyword ishdConstant HKEY_CURRENT_CONFIG HKEY_CURRENT_USER HKEY_DYN_DATA
syn keyword ishdConstant HKEY_LOCAL_MACHINE HKEY_PERFORMANCE_DATA HKEY_USERS
syn keyword ishdConstant HOURGLASS HWND_DESKTOP HWND_INSTALL IGNORE_READONLY
syn keyword ishdConstant INCLUDE_SUBDIR INDVFILESTATUS INFO INFO_DESCRIPTION
syn keyword ishdConstant INFO_IMAGE INFO_MISC INFO_SIZE INFO_SUBCOMPONENT
syn keyword ishdConstant INFO_VISIBLE INFORMATION INVALID_LIST IS_186 IS_286
syn keyword ishdConstant IS_386 IS_486 IS_8514A IS_86 IS_ALPHA IS_CDROM IS_CGA
syn keyword ishdConstant IS_DOS IS_EGA IS_FIXED IS_FOLDER IS_ITEM ISLANG_ALL
syn keyword ishdConstant ISLANG_ARABIC ISLANG_ARABIC_SAUDIARABIA
syn keyword ishdConstant ISLANG_ARABIC_IRAQ ISLANG_ARABIC_EGYPT
syn keyword ishdConstant ISLANG_ARABIC_LIBYA ISLANG_ARABIC_ALGERIA
syn keyword ishdConstant ISLANG_ARABIC_MOROCCO ISLANG_ARABIC_TUNISIA
syn keyword ishdConstant ISLANG_ARABIC_OMAN ISLANG_ARABIC_YEMEN
syn keyword ishdConstant ISLANG_ARABIC_SYRIA ISLANG_ARABIC_JORDAN
syn keyword ishdConstant ISLANG_ARABIC_LEBANON ISLANG_ARABIC_KUWAIT
syn keyword ishdConstant ISLANG_ARABIC_UAE ISLANG_ARABIC_BAHRAIN
syn keyword ishdConstant ISLANG_ARABIC_QATAR ISLANG_AFRIKAANS
syn keyword ishdConstant ISLANG_AFRIKAANS_STANDARD ISLANG_ALBANIAN
syn keyword ishdConstant ISLANG_ENGLISH_TRINIDAD ISLANG_ALBANIAN_STANDARD
syn keyword ishdConstant ISLANG_BASQUE ISLANG_BASQUE_STANDARD ISLANG_BULGARIAN
syn keyword ishdConstant ISLANG_BULGARIAN_STANDARD ISLANG_BELARUSIAN
syn keyword ishdConstant ISLANG_BELARUSIAN_STANDARD ISLANG_CATALAN
syn keyword ishdConstant ISLANG_CATALAN_STANDARD ISLANG_CHINESE
syn keyword ishdConstant ISLANG_CHINESE_TAIWAN ISLANG_CHINESE_PRC
syn keyword ishdConstant ISLANG_SPANISH_PUERTORICO ISLANG_CHINESE_HONGKONG
syn keyword ishdConstant ISLANG_CHINESE_SINGAPORE ISLANG_CROATIAN
syn keyword ishdConstant ISLANG_CROATIAN_STANDARD ISLANG_CZECH
syn keyword ishdConstant ISLANG_CZECH_STANDARD ISLANG_DANISH
syn keyword ishdConstant ISLANG_DANISH_STANDARD ISLANG_DUTCH
syn keyword ishdConstant ISLANG_DUTCH_STANDARD ISLANG_DUTCH_BELGIAN
syn keyword ishdConstant ISLANG_ENGLISH ISLANG_ENGLISH_BELIZE
syn keyword ishdConstant ISLANG_ENGLISH_UNITEDSTATES
syn keyword ishdConstant ISLANG_ENGLISH_UNITEDKINGDOM ISLANG_ENGLISH_AUSTRALIAN
syn keyword ishdConstant ISLANG_ENGLISH_CANADIAN ISLANG_ENGLISH_NEWZEALAND
syn keyword ishdConstant ISLANG_ENGLISH_IRELAND ISLANG_ENGLISH_SOUTHAFRICA
syn keyword ishdConstant ISLANG_ENGLISH_JAMAICA ISLANG_ENGLISH_CARIBBEAN
syn keyword ishdConstant ISLANG_ESTONIAN ISLANG_ESTONIAN_STANDARD
syn keyword ishdConstant ISLANG_FAEROESE ISLANG_FAEROESE_STANDARD ISLANG_FARSI
syn keyword ishdConstant ISLANG_FINNISH ISLANG_FINNISH_STANDARD ISLANG_FRENCH
syn keyword ishdConstant ISLANG_FRENCH_STANDARD ISLANG_FRENCH_BELGIAN
syn keyword ishdConstant ISLANG_FRENCH_CANADIAN ISLANG_FRENCH_SWISS
syn keyword ishdConstant ISLANG_FRENCH_LUXEMBOURG ISLANG_FARSI_STANDARD
syn keyword ishdConstant ISLANG_GERMAN ISLANG_GERMAN_STANDARD
syn keyword ishdConstant ISLANG_GERMAN_SWISS ISLANG_GERMAN_AUSTRIAN
syn keyword ishdConstant ISLANG_GERMAN_LUXEMBOURG ISLANG_GERMAN_LIECHTENSTEIN
syn keyword ishdConstant ISLANG_GREEK ISLANG_GREEK_STANDARD ISLANG_HEBREW
syn keyword ishdConstant ISLANG_HEBREW_STANDARD ISLANG_HUNGARIAN
syn keyword ishdConstant ISLANG_HUNGARIAN_STANDARD ISLANG_ICELANDIC
syn keyword ishdConstant ISLANG_ICELANDIC_STANDARD ISLANG_INDONESIAN
syn keyword ishdConstant ISLANG_INDONESIAN_STANDARD ISLANG_ITALIAN
syn keyword ishdConstant ISLANG_ITALIAN_STANDARD ISLANG_ITALIAN_SWISS
syn keyword ishdConstant ISLANG_JAPANESE ISLANG_JAPANESE_STANDARD ISLANG_KOREAN
syn keyword ishdConstant ISLANG_KOREAN_STANDARD  ISLANG_KOREAN_JOHAB
syn keyword ishdConstant ISLANG_LATVIAN ISLANG_LATVIAN_STANDARD
syn keyword ishdConstant ISLANG_LITHUANIAN ISLANG_LITHUANIAN_STANDARD
syn keyword ishdConstant ISLANG_NORWEGIAN ISLANG_NORWEGIAN_BOKMAL
syn keyword ishdConstant ISLANG_NORWEGIAN_NYNORSK ISLANG_POLISH
syn keyword ishdConstant ISLANG_POLISH_STANDARD ISLANG_PORTUGUESE
syn keyword ishdConstant ISLANG_PORTUGUESE_BRAZILIAN ISLANG_PORTUGUESE_STANDARD
syn keyword ishdConstant ISLANG_ROMANIAN ISLANG_ROMANIAN_STANDARD ISLANG_RUSSIAN
syn keyword ishdConstant ISLANG_RUSSIAN_STANDARD ISLANG_SLOVAK
syn keyword ishdConstant ISLANG_SLOVAK_STANDARD ISLANG_SLOVENIAN
syn keyword ishdConstant ISLANG_SLOVENIAN_STANDARD ISLANG_SERBIAN
syn keyword ishdConstant ISLANG_SERBIAN_LATIN ISLANG_SERBIAN_CYRILLIC
syn keyword ishdConstant ISLANG_SPANISH ISLANG_SPANISH_ARGENTINA
syn keyword ishdConstant ISLANG_SPANISH_BOLIVIA ISLANG_SPANISH_CHILE
syn keyword ishdConstant ISLANG_SPANISH_COLOMBIA ISLANG_SPANISH_COSTARICA
syn keyword ishdConstant ISLANG_SPANISH_DOMINICANREPUBLIC ISLANG_SPANISH_ECUADOR
syn keyword ishdConstant ISLANG_SPANISH_ELSALVADOR ISLANG_SPANISH_GUATEMALA
syn keyword ishdConstant ISLANG_SPANISH_HONDURAS ISLANG_SPANISH_MEXICAN
syn keyword ishdConstant ISLANG_THAI_STANDARD ISLANG_SPANISH_MODERNSORT
syn keyword ishdConstant ISLANG_SPANISH_NICARAGUA ISLANG_SPANISH_PANAMA
syn keyword ishdConstant ISLANG_SPANISH_PARAGUAY ISLANG_SPANISH_PERU
syn keyword ishdConstant IISLANG_SPANISH_PUERTORICO
syn keyword ishdConstant ISLANG_SPANISH_TRADITIONALSORT ISLANG_SPANISH_VENEZUELA
syn keyword ishdConstant ISLANG_SPANISH_URUGUAY ISLANG_SWEDISH
syn keyword ishdConstant ISLANG_SWEDISH_FINLAND ISLANG_SWEDISH_STANDARD
syn keyword ishdConstant ISLANG_THAI ISLANG_THA_STANDARDI ISLANG_TURKISH
syn keyword ishdConstant ISLANG_TURKISH_STANDARD ISLANG_UKRAINIAN
syn keyword ishdConstant ISLANG_UKRAINIAN_STANDARD ISLANG_VIETNAMESE
syn keyword ishdConstant ISLANG_VIETNAMESE_STANDARD IS_MIPS IS_MONO IS_OS2
syn keyword ishdConstant ISOSL_ALL ISOSL_WIN31 ISOSL_WIN95 ISOSL_NT351
syn keyword ishdConstant ISOSL_NT351_ALPHA ISOSL_NT351_MIPS ISOSL_NT351_PPC
syn keyword ishdConstant ISOSL_NT40 ISOSL_NT40_ALPHA ISOSL_NT40_MIPS
syn keyword ishdConstant ISOSL_NT40_PPC IS_PENTIUM IS_POWERPC IS_RAMDRIVE
syn keyword ishdConstant IS_REMOTE IS_REMOVABLE IS_SVGA IS_UNKNOWN IS_UVGA
syn keyword ishdConstant IS_VALID_PATH IS_VGA IS_WIN32S IS_WINDOWS IS_WINDOWS95
syn keyword ishdConstant IS_WINDOWSNT IS_WINOS2 IS_XVGA ISTYPE INFOFILENAME
syn keyword ishdConstant ISRES ISUSER ISVERSION LANGUAGE LANGUAGE_DRV LESS_THAN
syn keyword ishdConstant LINE_NUMBER LISTBOX_ENTER LISTBOX_SELECT LISTFIRST
syn keyword ishdConstant LISTLAST LISTNEXT LISTPREV LOCKEDFILE LOGGING
syn keyword ishdConstant LOWER_LEFT LOWER_RIGHT LIST_NULL MAGENTA MAINCAPTION
syn keyword ishdConstant MATH_COPROCESSOR MAX_STRING MENU METAFILE MMEDIA_AVI
syn keyword ishdConstant MMEDIA_MIDI MMEDIA_PLAYASYNCH MMEDIA_PLAYCONTINUOUS
syn keyword ishdConstant MMEDIA_PLAYSYNCH MMEDIA_STOP MMEDIA_WAVE MOUSE
syn keyword ishdConstant MOUSE_DRV MEDIA MODE NETWORK NETWORK_DRV NEXT
syn keyword ishdConstant NEXTBUTTON NO NO_SUBDIR NO_WRITE_ACCESS NONCONTIGUOUS
syn keyword ishdConstant NONEXCLUSIVE NORMAL NORMALMODE NOSET NOTEXISTS NOTRESET
syn keyword ishdConstant NOWAIT NULL NUMBERLIST OFF OK ON ONLYDIR OS OSMAJOR
syn keyword ishdConstant OSMINOR OTHER_FAILURE OUT_OF_DISK_SPACE PARALLEL
syn keyword ishdConstant PARTIAL PATH PATH_EXISTS PAUSE PERSONAL PROFSTRING
syn keyword ishdConstant PROGMAN PROGRAMFILES RAM_DRIVE REAL RECORDMODE RED
syn keyword ishdConstant REGDB_APPPATH REGDB_APPPATH_DEFAULT REGDB_BINARY
syn keyword ishdConstant REGDB_ERR_CONNECTIONEXISTS REGDB_ERR_CORRUPTEDREGISTRY
syn keyword ishdConstant REGDB_ERR_FILECLOSE REGDB_ERR_FILENOTFOUND
syn keyword ishdConstant REGDB_ERR_FILEOPEN REGDB_ERR_FILEREAD
syn keyword ishdConstant REGDB_ERR_INITIALIZATION REGDB_ERR_INVALIDFORMAT
syn keyword ishdConstant REGDB_ERR_INVALIDHANDLE REGDB_ERR_INVALIDNAME
syn keyword ishdConstant REGDB_ERR_INVALIDPLATFORM REGDB_ERR_OUTOFMEMORY
syn keyword ishdConstant REGDB_ERR_REGISTRY REGDB_KEYS REGDB_NAMES REGDB_NUMBER
syn keyword ishdConstant REGDB_STRING REGDB_STRING_EXPAND REGDB_STRING_MULTI
syn keyword ishdConstant REGDB_UNINSTALL_NAME REGKEY_CLASSES_ROOT
syn keyword ishdConstant REGKEY_CURRENT_USER REGKEY_LOCAL_MACHINE REGKEY_USERS
syn keyword ishdConstant REMOTE_DRIVE REMOVE REMOVEABLE_DRIVE REPLACE
syn keyword ishdConstant REPLACE_ITEM RESET RESTART ROOT ROTATE RUN_MAXIMIZED
syn keyword ishdConstant RUN_MINIMIZED RUN_SEPARATEMEMORY SELECTFOLDER
syn keyword ishdConstant SELFREGISTER SELFREGISTERBATCH SELFREGISTRATIONPROCESS
syn keyword ishdConstant SERIAL SET SETUPTYPE SETUPTYPE_INFO_DESCRIPTION
syn keyword ishdConstant SETUPTYPE_INFO_DISPLAYNAME SEVERE SHARE SHAREDFILE
syn keyword ishdConstant SHELL_OBJECT_FOLDER SILENTMODE SPLITCOMPRESS SPLITCOPY
syn keyword ishdConstant SRCTARGETDIR STANDARD STATUS STATUS95 STATUSBAR
syn keyword ishdConstant STATUSDLG STATUSEX STATUSOLD STRINGLIST STYLE_BOLD
syn keyword ishdConstant STYLE_ITALIC STYLE_NORMAL STYLE_SHADOW STYLE_UNDERLINE
syn keyword ishdConstant SW_HIDE SW_MAXIMIZE SW_MINIMIZE SW_NORMAL SW_RESTORE
syn keyword ishdConstant SW_SHOW SW_SHOWMAXIMIZED SW_SHOWMINIMIZED
syn keyword ishdConstant SW_SHOWMINNOACTIVE SW_SHOWNA SW_SHOWNOACTIVATE
syn keyword ishdConstant SW_SHOWNORMAL SYS_BOOTMACHINE SYS_BOOTWIN
syn keyword ishdConstant SYS_BOOTWIN_INSTALL SYS_RESTART SYS_SHUTDOWN SYS_TODOS
syn keyword ishdConstant SELECTED_LANGUAGE SHELL_OBJECT_LANGUAGE SRCDIR SRCDISK
syn keyword ishdConstant SUPPORTDIR TEXT TILED TIME TRUE TYPICAL TARGETDIR
syn keyword ishdConstant TARGETDISK UPPER_LEFT UPPER_RIGHT USER_ADMINISTRATOR
syn keyword ishdConstant UNINST VALID_PATH VARIABLE_LEFT VARIABLE_UNDEFINED
syn keyword ishdConstant VER_DLL_NOT_FOUND VER_UPDATE_ALWAYS VER_UPDATE_COND
syn keyword ishdConstant VERSION VIDEO VOLUMELABEL WAIT WARNING WELCOME WHITE
syn keyword ishdConstant WIN32SINSTALLED WIN32SMAJOR WIN32SMINOR WINDOWS_SHARED
syn keyword ishdConstant WINMAJOR WINMINOR WINDIR WINDISK WINSYSDIR WINSYSDISK
syn keyword ishdConstant XCOPY_DATETIME YELLOW YES

syn keyword ishdFunction AskDestPath AskOptions AskPath AskText AskYesNo
syn keyword ishdFunction AppCommand AddProfString AddFolderIcon BatchAdd
syn keyword ishdFunction BatchDeleteEx BatchFileLoad BatchFileSave BatchFind
syn keyword ishdFunction BatchGetFileName BatchMoveEx BatchSetFileName
syn keyword ishdFunction ComponentDialog ComponentAddItem
syn keyword ishdFunction ComponentCompareSizeRequired ComponentDialog
syn keyword ishdFunction ComponentError ComponentFileEnum ComponentFileInfo
syn keyword ishdFunction ComponentFilterLanguage ComponentFilterOS
syn keyword ishdFunction ComponentGetData ComponentGetItemSize
syn keyword ishdFunction ComponentInitialize ComponentIsItemSelected
syn keyword ishdFunction ComponentListItems ComponentMoveData
syn keyword ishdFunction ComponentSelectItem ComponentSetData ComponentSetTarget
syn keyword ishdFunction ComponentSetupTypeEnum ComponentSetupTypeGetData
syn keyword ishdFunction ComponentSetupTypeSet ComponentTotalSize
syn keyword ishdFunction ComponentValidate ConfigAdd ConfigDelete ConfigFileLoad
syn keyword ishdFunction ConfigFileSave ConfigFind ConfigGetFileName
syn keyword ishdFunction ConfigGetInt ConfigMove ConfigSetFileName ConfigSetInt
syn keyword ishdFunction CmdGetHwndDlg CtrlClear CtrlDir CtrlGetCurSel
syn keyword ishdFunction CtrlGetMLEText CtrlGetMultCurSel CtrlGetState
syn keyword ishdFunction CtrlGetSubCommand CtrlGetText CtrlPGroups
syn keyword ishdFunction CtrlSelectText CtrlSetCurSel CtrlSetFont CtrlSetList
syn keyword ishdFunction CtrlSetMLEText CtrlSetMultCurSel CtrlSetState
syn keyword ishdFunction CtrlSetText CallDLLFx ChangeDirectory CloseFile
syn keyword ishdFunction CopyFile CreateDir CreateFile CreateRegistrySet
syn keyword ishdFunction CommitSharedFiles CreateProgramFolder
syn keyword ishdFunction CreateShellObjects CopyBytes DefineDialog Delay
syn keyword ishdFunction DeleteDir DeleteFile Do DoInstall DeinstallSetReference
syn keyword ishdFunction DeinstallStart DialogSetInfo DeleteFolderIcon
syn keyword ishdFunction DeleteProgramFolder Disable EzBatchAddPath
syn keyword ishdFunction EzBatchAddString ExBatchReplace EnterDisk
syn keyword ishdFunction EzConfigAddDriver EzConfigAddString EzConfigGetValue
syn keyword ishdFunction EzConfigSetValue EndDialog EzDefineDialog ExistsDir
syn keyword ishdFunction ExistsDisk ExitProgMan Enable EzBatchReplace
syn keyword ishdFunction FileCompare FileDeleteLine FileGrep FileInsertLine
syn keyword ishdFunction FindAllDirs FindAllFiles FindFile FindWindow
syn keyword ishdFunction GetFileInfo GetLine GetFont GetDiskSpace GetEnvVar
syn keyword ishdFunction GetExtents GetMemFree GetMode GetSystemInfo
syn keyword ishdFunction GetValidDrivesList GetWindowHandle GetProfInt
syn keyword ishdFunction GetProfString GetFolderNameList GetGroupNameList
syn keyword ishdFunction GetItemNameList GetDir GetDisk HIWORD Handler Is
syn keyword ishdFunction ISCompareServicePack InstallationInfo LOWORD LaunchApp
syn keyword ishdFunction LaunchAppAndWait ListAddItem ListAddString ListCount
syn keyword ishdFunction ListCreate ListCurrentItem ListCurrentString
syn keyword ishdFunction ListDeleteItem ListDeleteString ListDestroy
syn keyword ishdFunction ListFindItem ListFindString ListGetFirstItem
syn keyword ishdFunction ListGetFirstString ListGetNextItem ListGetNextString
syn keyword ishdFunction ListReadFromFile ListSetCurrentItem
syn keyword ishdFunction ListSetCurrentString ListSetIndex ListWriteToFile
syn keyword ishdFunction LongPathFromShortPath LongPathToQuote
syn keyword ishdFunction LongPathToShortPath MessageBox MessageBeep NumToStr
syn keyword ishdFunction OpenFile OpenFileMode PathAdd PathDelete PathFind
syn keyword ishdFunction PathGet PathMove PathSet ProgDefGroupType ParsePath
syn keyword ishdFunction PlaceBitmap PlaceWindow PlayMMedia QueryProgGroup
syn keyword ishdFunction QueryProgItem QueryShellMgr RebootDialog ReleaseDialog
syn keyword ishdFunction ReadBytes RenameFile ReplaceProfString ReloadProgGroup
syn keyword ishdFunction ReplaceFolderIcon RGB RegDBConnectRegistry
syn keyword ishdFunction RegDBCreateKeyEx RegDBDeleteKey RegDBDeleteValue
syn keyword ishdFunction RegDBDisConnectRegistry RegDBGetAppInfo RegDBGetItem
syn keyword ishdFunction RegDBGetKeyValueEx RegDBKeyExist RegDBQueryKey
syn keyword ishdFunction RegDBSetAppInfo RegDBSetDefaultRoot RegDBSetItem
syn keyword ishdFunction RegDBSetKeyValueEx SeekBytes SelectDir SetFileInfo
syn keyword ishdFunction SelectDir SelectFolder SetupType SprintfBox SdSetupType
syn keyword ishdFunction SdSetupTypeEx SdMakeName SilentReadData SilentWriteData
syn keyword ishdFunction SendMessage Sprintf System SdAskDestPath SdAskOptions
syn keyword ishdFunction SdAskOptionsList SdBitmap SdComponentDialog
syn keyword ishdFunction SdComponentDialog2 SdComponentDialogAdv SdComponentMult
syn keyword ishdFunction SdConfirmNewDir SdConfirmRegistration SdDisplayTopics
syn keyword ishdFunction SdFinish SdFinishReboot SdInit SdLicense SdMakeName
syn keyword ishdFunction SdOptionsButtons SdProductName SdRegisterUser
syn keyword ishdFunction SdRegisterUserEx SdSelectFolder SdSetupType
syn keyword ishdFunction SdSetupTypeEx SdShowAnyDialog SdShowDlgEdit1
syn keyword ishdFunction SdShowDlgEdit2 SdShowDlgEdit3 SdShowFileMods
syn keyword ishdFunction SdShowInfoList SdShowMsg SdStartCopy SdWelcome
syn keyword ishdFunction SelectFolder ShowGroup ShowProgamFolder SetColor
syn keyword ishdFunction SetDialogTitle SetDisplayEffect SetErrorMsg
syn keyword ishdFunction SetErrorTitle SetFont SetStatusWindow SetTitle
syn keyword ishdFunction SizeWindow StatusUpdate StrCompare StrFind StrGetTokens
syn keyword ishdFunction StrLength StrRemoveLastSlash StrSub StrToLower StrToNum
syn keyword ishdFunction StrToUpper ShowProgramFolder UnUseDLL UseDLL VarRestore
syn keyword ishdFunction VarSave VerUpdateFile VerCompare VerFindFileVersion
syn keyword ishdFunction VerGetFileVersion VerSearchAndUpdateFile VerUpdateFile
syn keyword ishdFunction Welcome WaitOnDialog WriteBytes WriteLine
syn keyword ishdFunction WriteProfString XCopyFile

syn keyword ishdTodo contained TODO

"integer number, or floating point number without a dot.
syn match  ishdNumber		"\<\d\+\>"
"floating point number, with dot
syn match  ishdNumber		"\<\d\+\.\d*\>"
"floating point number, starting with a dot
syn match  ishdNumber		"\.\d\+\>"

" String constants
syn region  ishdString	start=+"+  skip=+\\\\\|\\"+  end=+"+

syn region  ishdComment	start="//" end="$" contains=ishdTodo
syn region  ishdComment	start="/\*"   end="\*/" contains=ishdTodo

" Pre-processor commands
syn region	ishdPreCondit	start="^\s*#\s*\(if\>\|ifdef\>\|ifndef\>\|elif\>\|else\>\|endif\>\)" skip="\\$" end="$" contains=ishdComment,ishdString
if !exists("ishd_no_if0")
  syn region	ishdHashIf0	start="^\s*#\s*if\s\+0\>" end=".\|$" contains=ishdHashIf0End
  syn region	ishdHashIf0End	contained start="0" end="^\s*#\s*\(endif\>\|else\>\|elif\>\)" contains=ishdHashIf0Skip
  syn region	ishdHashIf0Skip	contained start="^\s*#\s*\(if\>\|ifdef\>\|ifndef\>\)" skip="\\$" end="^\s*#\s*endif\>" contains=ishdHashIf0Skip
endif
syn region	ishdIncluded	contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match	ishdInclude	+^\s*#\s*include\>\s*"+ contains=ishdIncluded
syn cluster	ishdPreProcGroup	contains=ishdPreCondit,ishdIncluded,ishdInclude,ishdDefine,ishdHashIf0,ishdHashIf0End,ishdHashIf0Skip,ishdNumber
syn region	ishdDefine		start="^\s*#\s*\(define\|undef\)\>" end="$" contains=ALLBUT,@ishdPreProcGroup

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_is_syntax_inits")
  if version < 508
    let did_is_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink ishdNumber	    Number
  HiLink ishdError	    Error
  HiLink ishdStatement	    Statement
  HiLink ishdString	    String
  HiLink ishdComment	    Comment
  HiLink ishdTodo	    Todo
  HiLink ishdFunction	    Identifier
  HiLink ishdConstant	    PreProc
  HiLink ishdType	    Type
  HiLink ishdInclude	    Include
  HiLink ishdDefine	    Macro
  HiLink ishdIncluded	    String
  HiLink ishdPreCondit	    PreCondit
  HiLink ishdHashIf0Skip   ishdHashIf0
  HiLink ishdHashIf0End    ishdHashIf0
  HiLink ishdHashIf0	    Comment

  delcommand HiLink
endif

let b:current_syntax = "ishd"

" vim: ts=8
