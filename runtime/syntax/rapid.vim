" ABB Rapid Command syntax file for Vim
" Language: ABB Rapid Command
" Maintainer: Patrick Meiser-Knosowski <knosowski@graeffrobotics.de>
" Version: 2.3.0
" Last Change: 21. Jul 2023
" Credits: Thanks for beta testing to Thomas Baginski
"
" Suggestions of improvement are very welcome. Please email me!
"
"
"
" Note to self:
" for testing perfomance
"     open a 1000 lines file.
"     :syntime on
"     G
"     hold down CTRL-U until reaching top
"     :syntime report
"
"
" TODO:   - highlight rapid constants and maybe constants from common
"           technology packages
"         - optimize rapidErrorStringTooLong 
"         - error highlight for missing 2nd point in MoveCirc et al

" Init {{{
" Remove any old syntax stuff that was loaded (5.x) or quit when a syntax file
" was already loaded (6.x).
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

let s:keepcpo= &cpo
set cpo&vim

" if colorscheme is tortus rapidNoHighLink defaults to 1
if (get(g:,'colors_name'," ")=="tortus" || get(g:,'colors_name'," ")=="tortusless") 
      \&& !exists("g:rapidGroupName")
  let g:rapidGroupName=1 
endif
" rapidGroupName defaults to 0 if it's not initialized yet or 0
if !get(g:,"rapidGroupName",0)
  let g:rapidGroupName=0 
endif

" Rapid does ignore case
syn case ignore
" spell checking
syn spell notoplevel
" }}} init

" common highlighting {{{

" Error {{{
if get(g:,'rapidShowError',1)
  "
  " This error must be defined befor rapidCharCode and rapidEscapedBackSlash
  " a string containing a single \ which is not a char code
  syn match rapidErrorSingleBackslash /\\/ contained
  highlight default link rapidErrorSingleBackslash Error
  "
endif
" }}} Error

" Constant values {{{
" Boolean
syn keyword rapidBoolean TRUE FALSE Edge High Low
highlight default link rapidBoolean Boolean
" Float (num)
" syn match rapidFloat /\v%(\W|_)@1<=[+-]?\d+\.?\d*%(\s*[eE][+-]?\d+)?/
syn match rapidFloat /\v\c%(<\d+\.|\.?<\d)\d*%(E[+-]?\d+)?>/ contains=rapidOperator
highlight default link rapidFloat Float
" integer in decimal, hexadecimal, octal and binary
syn match rapidDec /\<[0-9]\+\>/
highlight default link rapidDec Number
syn match rapidHex /\<0x[0-9a-fA-F]\+\>/
highlight default link rapidHex Number
syn match rapidOct /\<0o[0-7]\+\>/
highlight default link rapidOct Number
syn match rapidBin /\<0b[01]\+\>/
highlight default link rapidBin Number
" String. Note: Don't rename group rapidString. Indent depend on this
syn region rapidString matchgroup=rapidString start=/"/ skip=/""/ end=/"/ oneline contains=rapidStringDoubleQuote,rapidEscapedBackSlash,rapidCharCode,rapidErrorSingleBackslash,rapidErrorStringTooLong,@Spell
highlight default link rapidString String
" two adjacent "" in string for one double quote
syn match rapidStringDoubleQuote /""/ contained
highlight default link rapidStringDoubleQuote SpecialChar
" character code in string
syn match rapidCharCode /\\\x\x/ contained
highlight default link rapidCharCode SpecialChar
" escaped \ in string
syn match rapidEscapedBackSlash /\\\\/ contained
highlight default link rapidEscapedBackSlash SpecialChar
" }}} Constant values

" }}} common highlighting

if bufname("%") =~ '\c\.cfg$'
" {{{ highlighting for *.cfg

  " special chars {{{
  " syn match rapidOperator /:\|[+-]\|\*\|\/\|\\/
  syn match rapidOperator /[-+*/:\\]/
  syn match rapidOperator /^#/
  highlight default link rapidOperator Operator
  " }}} special chars

  " sections {{{
  syn match rapidException /^\w\+/
  syn match rapidException /CFG_\d\+/
  highlight default link rapidException Exception
  " }}} sections

  " Error {{{
  if get(g:,'rapidShowError',1)
    "
    " This error must be defined after rapidString
    " Any Name longer than 32 chars
    syn match rapidErrorNameTooLong /-Name "[^"]\{33,}"/
    highlight default link rapidErrorNameTooLong Error
    "
  endif
  " }}} Error

  " }}} highlighting for *.cfg
else
  " highlighting for *.mod, *.sys and *.prg {{{

  " sync for regions from a line comment or the start of a function
  syn sync match rapidSync grouphere NONE /\v\c^\s*%(!|%(task\s+|local\s+)?%(module|proc|func|trap|record)>)/

  " Comment {{{ 
  " TODO Comment
  syn match rapidTodoComment contained /\<TODO\>\|\<FIXME\>\|\<XXX\>/
  highlight default link rapidTodoComment Todo
  " Debug comment
  syn match rapidDebugComment contained /\<DEBUG\>/
  highlight default link rapidDebugComment Debug
  " Line comment
  syn match rapidComment /!.*$/ contains=rapidTodoComment,rapidDebugComment,@Spell
  highlight default link rapidComment Comment
  " }}} Comment 

  " Header {{{
  syn match rapidHeader /^%%%/
  highlight default link rapidHeader PreProc
  " }}} Header

  " Operator {{{
  " Boolean operator
  syn keyword rapidOperator and or xor not div mod
  " Arithmetic and compare operator
  syn match rapidOperator /[-+*/<>:=]/
  " conditional argument
  syn match rapidOperator /?/
  highlight default link rapidOperator Operator
  " }}} Operator

  " Type, StorageClass and Typedef {{{
  " anytype (preceded by 'alias|pers|var|const|func'
  " TODO: still missing are userdefined types which are part of a parameter:
  " PROC message( mystring msMessagePart1{},
  "               \ myvar msMsg4{})
  " TODO testing. Problem: does not highlight any type if it's part of an argument list
  " syn match rapidAnyType /\v^\s*(global\s+|task\s+|local\s+)?(alias|pers|var|const|func)\s+\w+>/ contains=rapidStorageClass,rapidType,rapidTypeDef
  " highlight default link rapidAnyType Type
  syn keyword rapidType accdata aiotrigg bool btnres busstate buttondata byte
  syn keyword rapidType cfgdomain clock cnvcmd confdata confsupdata corrdescr datapos deflectiondata dionum dir dnum
  syn keyword rapidType egmframetype egmident egm_minmax egmstate egmstopmode errdomain errnum ErrorInfo errstr errtype event_type exec_level extjoint handler_type
  syn keyword rapidType icondata identno inposdata intnum inttypes iodev iounit_state jointtarget
  syn keyword rapidType listitem loaddata loadidnum loadsession mecunit motionprocessmode motsetdata
  " syn keyword rapidType num
  syn keyword rapidType opcalc opnum orient paridnum paridvalidnum pathrecid pnpdata pos pose proc_times progdisp o_jointtarget o_robtarget
  syn keyword rapidType rawbytes restartdata rmqheader rmqmessage rmqslot robjoint robtarget
  syn keyword rapidType searchdata sensor sensorstate sensorvardata shapedata signalai signalao signaldi signaldo signalgi signalgo signalorigin singdata socketdev socketstatus speeddata stopmovestartmove_mem stoppoint stoppointdata string stringdig sup_timeouts supervtype switch symnum syncident 
  syn keyword rapidType taskid tasks tasksatstart testsignal tooldata tpnum trapdata triggdata triggflag triggios triggiosdnum triggmode triggstrgo tsp_status tunegtype tunetype
  syn keyword rapidType uishownum veldata visiondata wobjdata wzstationary wztemporary zonedata
  " SoftMove data types
  syn keyword rapidType css_offset_dir css_soft_dir cssframe
  " arc data types
  syn keyword rapidType advSeamData arcdata flystartdata seamdata arctrackdata opttrackdata weavedata welddata 
  " conveyor tracking data types
  syn keyword rapidType indcnvdata
  " Integrated Vision data types
  syn keyword rapidType cameradev cameratarget 
  " arc Weldguide and MultiPass data types
  syn keyword rapidType adaptdata trackdata multidata 
  " dispense data types
  syn keyword rapidType beaddata equipdata
  " Spot data types
  syn keyword rapidType gundata gunnum spotdata forcedata simdata smeqdata smeqtype
  " Tool change data types
  syn keyword rapidType standno ToolInfo toolno
  " Continuous Application Platform data types
  syn keyword rapidType capaptrreferencedata capdata capevent caplatrackdata capmvsttim capspeeddata capspeeddata capstopmode captestno captrackdata capweavedata flypointdata processtimes restartblkdata supervtimeouts weavestartdata 
  " Bulls Eye data types
  syn keyword rapidType be_device be_scan be_tooldesign
  " Force Control data types
  syn keyword rapidType fcboxvol fccondstatus fccylindervol fcdamping fcforcevector fcframe fclindir fcprocessdata fcplane fcrotdir fcspeedvector fcspherevol fcspdchgtunetype fcxyznum
  " Discrete application platform data types
  syn keyword rapidType dadescapp dadescprc daintdata
  " VW Konzernstandard VWKS_1.07.02
  syn keyword rapidType merker 
  syn keyword rapidType frgnum frgwert robnum 
  syn keyword rapidType fmnum applid calibdatavorr stepdata 
  syn keyword rapidType tsmethode tsdaten teilspeicherdaten
  syn keyword rapidType greiferdaten greiferposition bauteildaten bauteilkontrolle g_datenident g_sensor g_signal g_teilident g_ventil 
  syn keyword rapidType strgnum typnum 
  syn keyword rapidType hubnum kopfnum 
  syn keyword rapidType applservicetype 
  syn keyword rapidType applfraesdaten kwdionum 
  syn keyword rapidType butechnum
  syn keyword rapidType toolnum dbnum 
  " das folgende sind datentypen aber das kann man doch nicht machen...
  " syn keyword rapidType position wert
  syn keyword rapidType camdata camlimitdata cammode camprotocoldata camstatus camsequence campositionstatus
  syn keyword rapidType saposnum sabereichnum autofocusnum focusposnum lascaledata laleistungnum larobnum laprognum uebwnum dgbanum dgjobnum gasspuelnum davalve gasuebwnum 
  syn keyword rapidType lsfigurnum lsstarttype 
  syn keyword rapidType lwprognum lwdiodnum lsstarttype 
  syn keyword rapidType lztype diskrethubnum lztipnum 
  syn keyword rapidType gblmethod
  syn keyword rapidType buatypenum buatechnum buadirnum 
  highlight default link rapidType Type
  " Storage class
  syn keyword rapidStorageClass LOCAL TASK VAR PERS CONST ALIAS NOVIEW NOSTEPIN VIEWONLY READONLY SYSMODULE INOUT
  highlight default link rapidStorageClass StorageClass
  " Not a typedef but I like to have those highlighted different then types,
  " structures or strorage classes
  syn keyword rapidTypeDef MODULE ENDMODULE PROC ERROR UNDO BACKWARD ENDPROC RECORD ENDRECORD TRAP ENDTRAP FUNC ENDFUNC
  highlight default link rapidTypeDef TypeDef
  " }}} Type, StorageClass and Typedef

  " Statements, keywords et al {{{
  " syn keyword rapidStatement
  " highlight default link rapidStatement Statement
  " Conditional
  syn keyword rapidConditional if then elseif else endif test case default endtest
  highlight default link rapidConditional Conditional
  " Repeat
  syn keyword rapidRepeat do
  syn match rapidRepeat /\c\v^\s*%(<while>|<for>)%([^!]+<do>)@=/
  syn keyword rapidRepeat from to step endfor endwhile
  highlight default link rapidRepeat Repeat
  " Label
  syn keyword rapidLabel goto
  syn match rapidLabel /\c\v^\s*[[:upper:][:lower:]]\k*\:\ze%([^=]|$)/ contains=rapidConditional,rapidOperator
  highlight default link rapidLabel Label
  " Keyword
  syn keyword rapidKeyword AccSet ActEventBuffer ActUnit Add AliasCamera AliasIO AliasIOReset BitClear BitSet BookErrNo BrakeCheck
  syn keyword rapidKeyword CallByVar CancelLoad CheckProgRef CirPathMode Clear ClearIOBuff ClearPath ClearRawBytes ClkReset ClkStart ClkStop Close CloseDir ConfJ ConfL CONNECT CopyFile CopyRawBytes CornerPathWarning CorrClear CorrCon CorrDiscon CorrWrite
  syn keyword rapidKeyword CSSAct CSSDeact CSSForceOffsetAct CSSForceOffsetDeact CSSOffsetTune CyclicBrakeCheck
  syn keyword rapidKeyword DeactEventBuffer DeactUnit Decr DitherAct DitherDeact DropSensor 
  syn keyword rapidKeyword EGMActJoint EGMActMove EGMActPose EGMGetId EGMReset EGMSetupAI EGMSetupAO EGMSetupGI EGMSetupLTAPP EGMSetupUC EOffsOff EOffsOn EOffsSet EraseModule ErrLog ErrWrite
  syn keyword rapidKeyword FitCircle FricIdInit FricIdEvaluate FricIdSetFricLevels 
  syn keyword rapidKeyword GetDataVal GetGroupSignalInfo GetJointData GetSysData GetTorqueMargin GetTrapData GripLoad HollowWristReset 
  syn keyword rapidKeyword IDelete IDisable IEnable IError Incr IndReset InvertDO IOBusStart IOBusState IoCtrlAxis_RefSync IoCtrlAxis_RefSyncOff IoCtrlAxis_RefSyncOn IODisable IOEnable IPers IRMQMessage ISignalAI ISignalAO ISignalDI ISignalDO ISignalGI ISignalGO ISleep ITimer IVarValue IWatch
  syn keyword rapidKeyword Load LoadId MakeDir ManLoadIdProc MatrixSolve MatrixSolveQR MatrixSVD MechUnitLoad MotionProcessModeSet MotionSup MToolRotCalib MToolTCPCalib Open OpenDir
  syn keyword rapidKeyword PackDNHeader PackRawBytes PathAccLim PathLengthReset PathLengthStart PathLengthStop PathRecStart PathRecStop PathResol PDispOff PDispOn PDispSet ProcerrRecovery PrxActivAndStoreRecord PrxActivRecord PrxDbgStoreRecord PrxDeactRecord PrxResetPos PrxResetRecords PrxSetPosOffset PrxSetRecordSampleTime PrxSetSyncalarm PrxStartRecord PrxStopRecord PrxStoreRecord PrxUseFileRecord PulseDO
  syn keyword rapidKeyword ReadAnyBin ReadBlock ReadCfgData ReadErrData ReadRawBytes ReadVarArr RemoveAllCyclicBool RemoveCyclicBool RemoveDir RemoveFile RenameFile Reset ResetAxisDistance ResetAxisMoveTime ResetPPMoved ResetRetryCount ResetTorqueMargin RestoPath Rewind RMQEmptyQueue RMQFindSlot RMQGetMessage RMQGetMsgData RMQGetMsgHeader RMQReadWait RMQSendMessage RMQSendWait
  syn keyword rapidKeyword SafetyControllerSyncRequest Save SaveCfgData SCWrite SenDevice Set SetAllDataVal SetAO SetDataSearch SetDataVal SetDO SetGO SetLeadThrough SetSysData SetupCyclicBool SiConnect SiClose SiGetCyclic SingArea SiSetCyclic SkipWarn SocketAccept SocketBind SocketClose SocketConnect SocketCreate SocketListen SocketReceive SocketReceiveFrom SocketSend SocketSendTo SoftAct SoftDeact SoftElbow SpeedLimAxis SpeedLimCheckPoint SpeedRefresh SpyStart SpyStop StartLoad STCalib STClose STIndGun STIndGunReset SToolRotCalib SToolTCPCalib STOpen StorePath STTune STTuneReset SupSyncSensorOff SupSyncSensorOn SyncMoveOff SyncMoveOn SyncMoveResume SyncMoveSuspend SyncMoveUndo SyncToSensor SystemStopAction
  syn keyword rapidKeyword TestSignDefine TestSignReset TextTabInstall TPErase TPReadDnum TPReadFK TPReadNum TPShow TPWrite TriggCheckIO TriggDataCopy TriggDataReset TriggEquip TriggInt TriggIO TriggRampAO TriggSpeed TriggStopProc TryInt TuneReset TuneServo
  syn keyword rapidKeyword UIMsgBox UIMsgWrite UIMsgWriteAbort UIShow UnLoad UnpackRawBytes VelSet WaitAI WaitAO WaitDI WaitDO WaitGI WaitGO WaitLoad WaitRob WaitSensor WaitSyncTask WaitTestAndSet WaitTime WaitUntil WarmStart WITH WorldAccLim Write WriteAnyBin WriteBin WriteBlock WriteCfgData WriteRawBytes WriteStrBin WriteVar WriteVarArr WZBoxDef WZCylDef WZDisable WZDOSet WZEnable WZFree WZHomeJointDef WZLimJointDef WZLimSup WZSphDef
  " arc instructions
  syn keyword rapidKeyword ArcRefresh RecoveryMenu RecoveryMenuWR RecoveryPosSet RecoveryPosReset SetWRProcName 
  " conveyor tracking instructions
  syn keyword rapidKeyword UseACCProfile WaitWObj DropWObj RecordProfile WaitAndRecProf StoreProfile LoadProfile ActivateProfile DeactProfile CnvGenInstr CnvSync CnvGenInstr IndCnvInit IndCnvEnable IndCnvDisable IndCnvReset IndCnvAddObject 
  syn keyword rapidKeyword UseReachableTargets GetMaxUsageTime ResetMaxUsageTime CnvPredictReach
  " Integrated Vision instructions
  syn keyword rapidKeyword CamFlush CamGetParameter CamGetResult CamLoadJob CamReqImage CamSetExposure CamSetParameter CamSetProgramMode CamSetRunMode CamStartLoadJob CamWaitLoadJob 
  " arc Weldguide and MultiPass instructions
  syn keyword rapidKeyword MPSavePath MPLoadPath MPReadInPath MPOffsEaxOnPath
  " Paint instructions
  syn keyword rapidKeyword ConsoleWrite IpsSetParam PntProdUserLog SetBrush SetBrushFac
  " Spot instructions
  syn keyword rapidKeyword SetForce Calibrate ReCalcTCP IndGunMove IndGunMoveReset OpenHighLift CloseHighLift SwSetIntSpotData SwSetIntForceData SwSetIntGunData SwSetIntSimData SwGetCalibData SwGetFixTipData 
  " Tool change instructions
  syn keyword rapidKeyword TcCloseCover TcDropOffTool TcLockTool TcOpenCover TcPickupTool TcUnlockTool
  " dispense instructions
  syn keyword rapidKeyword SetTmSignal SyncWWObj
  " Continuous Application Platform instructions
  syn keyword rapidKeyword CapAPTrSetup CapAPTrSetupAI CapAPTrSetupAO  CapAPTrSetupPERS CapCondSetDO CapEquiDist CapNoProcess CapRefresh CAPSetStopMode CapWeaveSync ICap InitSuperv IPathPos RemoveSuperv SetupSuperv 
  " Bulls Eye instructions
  syn keyword rapidKeyword BECheckTcp BEDebugState BERefPointer BESetupToolJ BETcpExtend BEUpdateTcp
  " Force Control instructions
  syn keyword rapidKeyword FCAct FCCalib FCCondForce FCCondOrient FCCondPos FCCondReoriSpeed FCCondTCPSpeed FCCondTorque FCCondWaitWhile FCDeact FCPress1LStart FCPressC FCPressEnd FCPressL FCRefCircle FCRefForce FCRefLine FCRefMoveFrame FCRefRot FCRefSpiral FCRefSprForceCart FCRefStart FCRefStop FCRefTorque FCResetDampingTune FCResetLPFilterTune FCSpdChgAct FCSpdChgDeact FCSpdChgTunSet FCSpdChgTunReset FCSetDampingTune FCSetLPFilterTune FCSupvForce FCSupvOrient FCSupvPos FCSupvReoriSpeed FCSupvTCPSpeed FCSupvTorque 
  " Discrete application platform instructions
  syn keyword rapidKeyword DaActProc DaDeactAllProc DaDeactProc DaDefExtSig DaDefProcData DaDefProcSig DaDefUserData DaGetCurrData DaSetCurrData DaSetupAppBehav DaStartManAction DaGetAppDescr DaGetAppIndex DaGetNumOfProcs DaGetNumOfRob DaGetPrcDescr 
  " Production Manager instructions
  syn keyword rapidKeyword ExecEngine PMgrGetNextPart PMgrSetNextPart PMgrRunMenu
  " Homepos-Running instructions
  syn keyword rapidKeyword HR_Exit HR_ExitCycle HR_SavePos HR_SetMoveToStartPos HR_SetTypeDIndex HR_SetTypeIndex 
  highlight default link rapidKeyword Keyword
  " Exception
  syn keyword rapidException Exit ErrRaise ExitCycle Raise RaiseToUser Retry Return TryNext
  syn match rapidException /\s\+Stop\s*[\\;]/me=e-1
  highlight default link rapidException Exception
  " }}} Statements, keywords et al

  " Special keyword for move command {{{
  " uncategorized yet
  syn keyword rapidMovement MovePnP
  syn keyword rapidMovement EGMMoveC EGMMoveL EGMRunJoint EGMRunPose EGMStop
  syn keyword rapidMovement IndAMove IndCMove IndDMove IndRMove 
  " common instructions
  syn keyword rapidMovement MoveAbsJ MoveC MoveExtJ MoveJ MoveL 
  syn keyword rapidMovement MoveCAO MoveCDO MoveCGO MoveCSync MoveJAO MoveJDO MoveJGO MoveJSync MoveLAO MoveLDO MoveLGO MoveLSync 
  syn keyword rapidMovement SearchC SearchExtJ SearchL
  syn keyword rapidMovement TriggC TriggJ TriggL TriggJIOs TriggLIOs
  " Arc instructions
  syn keyword rapidMovement ArcC ArcC1 ArcC2 ArcCEnd ArcC1End ArcC2End ArcCStart ArcC1Start ArcC2Start 
  syn keyword rapidMovement ArcL ArcL1 ArcL2 ArcLEnd ArcL1End ArcL2End ArcLStart ArcL1Start ArcL2Start ArcMoveExtJ 
  " Arc Weldguide and MultiPass instructions
  syn keyword rapidMovement ArcRepL ArcAdaptLStart ArcAdaptL ArcAdaptC ArcAdaptLEnd ArcAdaptCEnd ArcCalcLStart ArcCalcL ArcCalcC ArcCalcLEnd ArcCalcCEnd ArcAdaptRepL 
  syn keyword rapidMovement Break 
  " Continuous Application Platform instructions
  syn keyword rapidMovement CapC CapL CapLATrSetup CSSDeactMoveL ContactL
  " Dispense instructions
  syn keyword rapidMovement DispL DispC
  " Nut instructions"
  syn keyword rapidMovement NutL NutJ
  syn keyword rapidMovement PathRecMoveBwd PathRecMoveFwd 
  " Paint instructions"
  syn keyword rapidMovement PaintL PaintLSig PaintLDO PaintC
  syn keyword rapidMovement StartMove StartMoveRetry StepBwdPath StopMove StopMoveReset
  " Spot instructions
  syn keyword rapidMovement SpotL SpotJ SpotML SpotMJ CalibL CalibJ MeasureWearL 
  " Homepos-Running instructions
  syn keyword rapidMovement SMoveJ SMoveJDO SMoveJGO SMoveJSync SMoveL SMoveLDO SMoveLGO SMoveLSync SSearchL STriggJ STriggL
  syn keyword rapidMovement HR_ContMove HR_MoveBack HR_MoveRoutine HR_MoveTo HR_MoveToHome SCSSDeactMoveL 
  " Discrete application platform instructions
  syn keyword rapidMovement DaProcML DaProcMJ
  " VW Konzernstandard VWKS_1.07.02
  syn keyword rapidMovement MoveABS  MoveABS_FB  MoveABS_FRG  MoveABS_ROB
  syn keyword rapidMovement MoveCIRC MoveCIRC_FB MoveCIRC_FRG MoveCIRC_ROB
  syn keyword rapidMovement MoveLIN  MoveLIN_FB  MoveLIN_FRG  MoveLIN_ROB 
  syn keyword rapidMovement MovePTP  MovePTP_FB  MovePTP_FRG  MovePTP_ROB 
  syn keyword rapidMovement SearchCIRC SearchCIRC_M 
  syn keyword rapidMovement SearchLIN  SearchLIN_M 
  syn keyword rapidMovement MoveABS_AO  MoveABS_DO  MoveABS_GO
  syn keyword rapidMovement MoveCIRC_AO MoveCIRC_DO MoveCIRC_GO
  syn keyword rapidMovement MoveLIN_AO  MoveLIN_DO  MoveLIN_GO
  syn keyword rapidMovement KW_LoesenLIN
  syn keyword rapidMovement SPZ_FraesenLIN SPZ_FraesenPTP SPZ_MessenLIN SPZ_MessenPTP SPZ_LIN SPZ_PTP 
  syn keyword rapidMovement BZ_LIN BZ_PTP
  syn keyword rapidMovement KL_LIN KL_CIRC
  syn keyword rapidMovement BP_LIN BP_PTP
  syn keyword rapidMovement BU_CIRC BU_LIN
  syn keyword rapidMovement CZ_LIN CZ_LIN_V CZ_PTP CZ_PTP_V
  syn keyword rapidMovement FD_LIN FD_PTP
  syn keyword rapidMovement KG_LIN KG_PTP
  syn keyword rapidMovement DA_LIN 
  syn keyword rapidMovement LK_CIRC LK_LIN 
  syn keyword rapidMovement LL_CIRC LL_LIN
  syn keyword rapidMovement LS_CIRC LS_LIN LS_LIN_F LS_PTP_F
  syn keyword rapidMovement LW_CIRC LW_LIN
  syn keyword rapidMovement LZ_LIN LZ_PTP LZ_ReinigenLIN LZ_ReinigenPTP
  syn keyword rapidMovement MS_CIRC MS_LIN MS_ReinigenLIN MS_SearchLIN MS_PTP_CS MS_LIN_CS GBL_LIN GBL_PTP GBL_RefPointLIN
  syn keyword rapidMovement NK_LIN
  syn keyword rapidMovement NZ_LIN NZ_LIN_V NZ_PTP NZ_PTP_V 
  syn keyword rapidMovement PR_LIN PR_PTP
  syn keyword rapidMovement RF_CIRC RF_LIN
  syn keyword rapidMovement STP_FraesenLIN STP_FraesenPTP STP_LIN STP_PTP 
  syn keyword rapidMovement SM_LIN SM_PTP
  syn keyword rapidMovement BUA_CIRC BUA_LIN BUA_MessenLIN BUA_MessenPTP
  syn keyword rapidMovement KE_LIN 
  if g:rapidGroupName
    highlight default link rapidMovement Movement
  else
    highlight default link rapidMovement Special
  endif
  " }}} special keyword for move command 

  " Any name {{{
  syn match rapidNames /\v[[:upper:][:lower:]](\k|\.)*/
  " }}} Any name

  " Attempt to avoid false highlight of num in case of parameter name:
  "   TPWrite "goPosNo="\num:=GOutput(goPosNo);
  " Must follow after rapidNames in this file
  syn match rapidType /\c\v<num>\s*\ze[^ :]/

  " Structure value {{{
  " rapid structrure values. added to be able to conceal them
  syn region rapidConcealableString matchgroup=rapidConcealableString start=/"/ skip=/""/ end=/"/ oneline keepend extend contained contains=rapidStringDoubleQuote,rapidEscapedBackSlash,rapidCharCode,rapidErrorSingleBackslash,rapidErrorStringTooLong,@Spell conceal 
  highlight default link rapidConcealableString String
  syn region rapidStructVal matchgroup=rapidStructDelimiter start=/\[/ end=/\]/ contains=rapidStructVal,rapidBoolean,rapidDec,rapidHex,rapidOct,rapidBin,rapidFloat,rapidConcealableString,rapidDelimiter,rapidConstant,rapidErrNo,rapidIntNo,rapidOperator keepend extend conceal cchar=* 
  highlight default link rapidStructDelimiter Delimiter
  " check edge cases like this one:
  "  LOCAL CONST listitem lstAuswService{18}:=[["","Service Position"],["","Bremsentest"],["","Referenzfahrt"],["","Manuelles Abfahren"],["","Justagestellung"],["","Transportposition"],
  "      ["","Spitze-Spitze Greifer 1, [RT]"],["","Spitze-Spitze Greifer 2, [FT]"],["","Spitze-Spitze Pruefspitze"],["","Werkobjekt Ablage"],["","Werkobjekt Modul 1"],
  "      ["","Werkobjekt Modul 2"],["","TCP von Greifer 1 vermessen, [RT]"],["","TCP von Greifer 2 vermessen, [FT]"],["","TCP von Basisdorn vermessen"],
  "      ["","Greifer abdocken"],["","Greifer andocken"],["","Kollision Check (Ohne Greifer)"]];
  " }}} Structure value

  " Delimiter {{{
  syn match rapidDelimiter /[\\(){},;|]/
  highlight default link rapidDelimiter Delimiter
  " }}} Delimiter

  " BuildInFunction {{{
  " dispense functions
  syn keyword rapidBuildInFunction contained GetSignal GetSignalDnum
  " Integrated Vision Platform functions
  syn keyword rapidBuildInFunction contained CamGetExposure CamGetLoadedJob CamGetName CamNumberOfResults 
  " Continuous Application Platform functions
  syn keyword rapidBuildInFunction contained CapGetFailSigs 
  syn keyword rapidBuildInFunction contained Abs AbsDnum ACos ACosDnum AInput AOutput ArgName ASin ASinDnum ATan ATanDnum ATan2 ATan2Dnum
  syn keyword rapidBuildInFunction contained BitAnd BitAndDnum BitCheck BitCheckDnum BitLSh BitLShDnum BitNeg BitNegDnum BitOr BitOrDnum BitRSh BitRShDnum BitXOr BitXOrDnum ByteToStr
  syn keyword rapidBuildInFunction contained CalcJointT CalcRobT CalcRotAxFrameZ CalcRotAxisFrame CDate CJointT ClkRead CorrRead Cos CosDnum CPos CRobT CrossProd CSpeedOverride CTime CTool CWObj
  syn keyword rapidBuildInFunction contained DecToHex DefAccFrame DefDFrame DefFrame Dim DInput Distance DnumToNum DnumToStr DotProd DOutput 
  syn keyword rapidBuildInFunction contained EGMGetState EulerZYX EventType ExecHandler ExecLevel Exp
  syn keyword rapidBuildInFunction contained FileSize FileTime FileTimeDnum FSSize
  syn keyword rapidBuildInFunction contained GetAxisDistance GetAxisMoveTime GetMaxNumberOfCyclicBool GetMecUnitName GetModalPayLoadMode GetMotorTorque GetNextCyclicBool GetNextMechUnit GetNextSym GetNumberOfCyclicBool GetServiceInfo GetSignalOrigin GetSysInfo GetTaskName GetTime GetTSPStatus GetUASUserName GInput GInputDnum GOutput GOutputDnum
  syn keyword rapidBuildInFunction contained HexToDec
  syn keyword rapidBuildInFunction contained IndInpos IndSpeed IOUnitState IsBrakeCheckActive IsCyclicBool IsFile IsLeadThrough IsMechUnitActive IsPers IsStopMoveAct IsStopStateEvent IsSyncMoveOn IsSysId IsVar
  syn keyword rapidBuildInFunction contained Max MaxExtLinearSpeed MaxExtReorientSpeed MaxRobReorientSpeed MaxRobSpeed Min MirPos ModExist ModTime ModTimeDnum MotionPlannerNo
  syn keyword rapidBuildInFunction contained NonMotionMode NOrient NumToDnum NumToStr
  syn keyword rapidBuildInFunction contained Offs OpMode OrientZYX ORobT
  syn keyword rapidBuildInFunction contained ParIdPosValid ParIdRobValid PathLengthGet PathLevel PathRecValidBwd PathRecValidFwd PFRestart PoseInv PoseMult PoseVect Pow PowDnum PPMovedInManMode Present ProgMemFree PrxGetMaxRecordpos
  syn keyword rapidBuildInFunction contained RawBytesLen ReadBin ReadDir ReadMotor ReadNum ReadStr ReadStrBin ReadVar RelTool RemainingRetries RMQGetSlotName RobName RobOS Round RoundDnum RunMode
  syn keyword rapidBuildInFunction contained SafetyControllerGetChecksum SafetyControllerGetOpModePinCode SafetyControllerGetSWVersion SafetyControllerGetUserChecksum Sin SinDnum SocketGetStatus SocketPeek Sqrt SqrtDnum STCalcForce STCalcTorque STIsCalib STIsClosed STIsIndGun STIsOpen StrDigCalc StrDigCmp StrFind StrLen StrMap StrMatch StrMemb StrOrder StrPart StrToByte StrToVal
  syn keyword rapidBuildInFunction contained Tan TanDnum TaskRunMec TaskRunRob TasksInSync TaskIsActive TaskIsExecuting TestAndSet TestDI TestSignRead TextGet TextTabFreeToUse TextTabGet TriggDataValid Trunc TruncDnum Type
  syn keyword rapidBuildInFunction contained UIAlphaEntry UIClientExist UIDnumEntry UIDnumTune UIListView UIMessageBox UINumEntry UINumTune
  syn keyword rapidBuildInFunction contained ValidIO ValToStr Vectmagn
  " Bulls Eye functions
  syn keyword rapidBuildInFunction contained OffsToolXYZ OffsToolPolar
  " Force Control functions
  syn keyword rapidBuildInFunction contained FCGetForce FCGetProcessData FCIsForceMode FCLoadID
  " Discrete application platform functions
  syn keyword rapidBuildInFunction contained DaGetFstTimeEvt DaCheckMMSOpt DaGetMP DaGetRobotName DaGetTaskName
  " Production Manager functions
  syn keyword rapidBuildInFunction contained PMgrAtSafe PMgrAtService PMgrAtState PMgrAtStation PMgrNextStation PMgrTaskNumber PMgrTaskName
  " Spot functions
  syn keyword rapidBuildInFunction contained SwGetCurrTargetName SwGetCurrSpotName 
  " Homepos-Running functions
  syn keyword rapidBuildInFunction contained HR_RobotInHome HR_GetTypeDIndex HR_GetTypeIndex
  " Paint functions
  syn keyword rapidBuildInFunction contained IndexLookup IpsCommand IpsGetParam PaintCommand PntQueueExtraGet PntQueueExtraSet PntQueuePeek 
  if g:rapidGroupName
    highlight default link rapidBuildInFunction BuildInFunction
  else
    highlight default link rapidBuildInFunction Function
  endif
  " }}}

  " Function {{{
  syn match rapidFunction contains=rapidBuildInFunction /\v\c%(<%(PROC|MODULE)\s+)@10<!<[[:upper:][:lower:]]\k+ *\(/me=e-1
  highlight default link rapidFunction Function
  syn match rapidCallByVar /%\ze[^%]/
  highlight default link rapidCallByVar Function
  " }}} Function

  " Constants {{{
  " standard rapid constants
  syn keyword rapidConstant pi stEmpty
  syn keyword rapidConstant STR_DIGIT STR_LOWER STR_UPPER STR_WHITE
  syn keyword rapidConstant flp1 diskhome diskram disktemp usbdisk1 usbdisk2 usbdisk3 usbdisk4 usbdisk5 usbdisk6 usbdisk7 usbdisk8 usbdisk9 usbdisk10
  " stoppoint
  syn keyword rapidConstant inpos stoptime fllwtime
  " stoppointdata
  syn keyword rapidConstant inpos20 inpos50 inpos100
  syn keyword rapidConstant stoptime0_5 stoptime1_0 stoptime1_5
  syn keyword rapidConstant fllwtime0_5 fllwtime1_0 fllwtime1_5
  " default tool/wobj/load
  syn keyword rapidConstant tool0 wobj0 load0
  " zonedata
  syn keyword rapidConstant fine z0 z1 z5 z10 z15 z20 z30 z40 z50 z60 z80 z100 z150 z200
  " speeddata
  syn keyword rapidConstant v5 v10 v20 v30 v40 v50 v60 v80 v100 v150 v200 v300 v400 v500 v600 v800 v1000 v1500 v2000 v2500 v3000 v4000 v5000 v6000 v7000 vmax
  syn keyword rapidConstant vrot1 vrot2 vrot5 vrot10 vrot20 vrot50 vrot100 vlin10 vlin20 vlin50 vlin100 vlin200 vlin500 vlin1000
  " error code starting with ERR_
  syn keyword rapidConstant ERR_ACC_TOO_LOW ERR_ACTIV_PROF ERR_ADDR_INUSE ERR_ALIASIO_DEF ERR_ALIASIO_TYPE ERR_ALRDYCNT ERR_ALRDY_MOVING ERR_AO_LIM ERR_ARGDUPCND ERR_ARGNAME ERR_ARGNOTPER ERR_ARGNOTVAR ERR_ARGVALERR ERR_ARRAY_SIZE ERR_AXIS_ACT ERR_AXIS_IND ERR_AXIS_MOVING ERR_AXIS_PAR
  syn keyword rapidConstant ERR_BUSSTATE ERR_BWDLIMIT
  syn keyword rapidConstant ERR_CALC_DIVZERO ERR_CALC_NEG ERR_CALC_OVERFLOW ERR_CALLIO_INTER ERR_CALLPROC ERR_CAM_BUSY ERR_CAM_COM_TIMEOUT ERR_CAM_GET_MISMATCH ERR_CAM_MAXTIME ERR_CAM_NO_MORE_DATA ERR_CAM_NO_PROGMODE ERR_CAM_NO_RUNMODE ERR_CAM_SET_MISMATCH
  syn keyword rapidConstant ERR_CFG_ILLTYPE ERR_CFG_ILL_DOMAIN ERR_CFG_INTERNAL ERR_CFG_LIMIT ERR_CFG_NOTFND ERR_CFG_OUTOFBOUNDS ERR_CFG_WRITEFILE
  syn keyword rapidConstant ERR_CNTNOTVAR
  syn keyword rapidConstant ERR_CNV_CONNECT ERR_CNV_DROPPED ERR_CNV_NOT_ACT
  syn keyword rapidConstant ERR_COLL_STOP
  syn keyword rapidConstant ERR_COMM_EXT ERR_COMM_INIT ERR_COMM_INIT_FAILED
  syn keyword rapidConstant ERR_CONC_MAX ERR_CONTACTL ERR_CSV_INDEX
  syn keyword rapidConstant ERR_DA_UNKPROC ERR_DATA_RECV ERR_DEV_MAXTIME ERR_DIPLAG_LIM ERR_DIVZERO ERR_DROP_LOAD ERR_EXCRTYMAX ERR_EXECPHR
  syn keyword rapidConstant ERR_FILEACC ERR_FILEEXIST ERR_FILEOPEN ERR_FILESIZE ERR_FILNOTFND
  syn keyword rapidConstant ERR_FNCNORET ERR_FRAME ERR_FRICTUNE_FATAL ERR_GLUEFLOW ERR_GO_LIM
  syn keyword rapidConstant ERR_HAND_FAILEDGRIPPOS ERR_HAND_FAILEDMOVEPOS ERR_HAND_FAILEDVACUUM ERR_HAND_NOTCALIBRATED
  syn keyword rapidConstant ERR_ILLDIM ERR_ILLQUAT ERR_ILLRAISE
  syn keyword rapidConstant ERR_INDCNV_ORDER ERR_INOISSAFE ERR_INOMAX ERR_INPAR_RDONLY ERR_INT_MAXVAL ERR_INT_NOTVAL ERR_INVDIM
  syn keyword rapidConstant ERR_IODISABLE ERR_IODN_TIMEOUT ERR_IOENABLE ERR_IOERROR ERR_IPSDEVICE_UNKNOWN ERR_IPSILLEGAL_CH_OR_FAC ERR_IPS_PARAM
  syn keyword rapidConstant ERR_ITMSRC_UNDEF ERR_LINKREF ERR_LOADED ERR_LOADID_FATAL ERR_LOADID_RETRY ERR_LOADNO_INUSE ERR_LOADNO_NOUSE
  syn keyword rapidConstant ERR_MSG_PENDING ERR_MAXINTVAL ERR_MOC_CNV_REC_FILE_UNKNOWN ERR_MODULE ERR_MOD_NOT_LOADED ERR_MOD_NOTLOADED
  syn keyword rapidConstant ERR_MT_ABORT ERR_MT_HOME ERR_MT_HOMERUN
  syn keyword rapidConstant ERR_NEGARG ERR_NAME_INVALID ERR_NORUNUNIT ERR_NOTARR ERR_NOTEQDIM ERR_NOTINTVAL ERR_NOTPRES ERR_NOTSAVED ERR_NOT_MOVETASK ERR_NO_ALIASIO_DEF ERR_NO_SGUN ERR_NUM_LIMIT
  syn keyword rapidConstant ERR_OUTOFBND ERR_OUTSIDE_REACH ERR_OVERFLOW ERR_PATH ERR_PATHDIST ERR_PATH_STOP ERR_PERSSUPSEARCH ERR_PID_MOVESTOP ERR_PID_RAISE_PP ERR_PPA_TIMEOUT ERR_PRGMEMFULL ERR_PROCSIGNAL_OFF ERR_PROGSTOP
  syn keyword rapidConstant ERR_RANYBIN_CHK ERR_RANYBIN_EOF ERR_RCVDATA ERR_REFUNKDAT ERR_REFUNKFUN ERR_REFUNKPRC ERR_REFUNKTRP
  syn keyword rapidConstant ERR_RMQ_DIM ERR_RMQ_FULL ERR_RMQ_INVALID ERR_RMQ_INVMSG ERR_RMQ_MSGSIZE ERR_RMQ_NAME ERR_RMQ_NOMSG ERR_RMQ_TIMEOUT ERR_RMQ_VALUE
  syn keyword rapidConstant ERR_ROBLIMIT ERR_SC_WRITE
  syn keyword rapidConstant ERR_SGUN_ESTOP ERR_SGUN_MOTOFF ERR_SGUN_NEGVAL ERR_SGUN_NOTACT ERR_SGUN_NOTINIT ERR_SGUN_NOTOPEN ERR_SGUN_NOTSYNC
  syn keyword rapidConstant ERR_SIG_NAME ERR_SIGSUPSEARCH ERR_SIG_NOT_VALID
  syn keyword rapidConstant ERR_SOCK_ADDR_INVALID ERR_SOCK_ADDR_INUSE ERR_SOCK_CLOSED ERR_SOCK_IS_BOUND ERR_SOCK_IS_CONN ERR_SOCK_NET_UNREACH ERR_SOCK_NOT_BOUND ERR_SOCK_NOT_CONN ERR_SOCK_TIMEOUT ERR_SOCK_UNSPEC
  syn keyword rapidConstant ERR_SPEEDLIM_VALUE ERR_SPEED_REFRESH_LIM
  syn keyword rapidConstant ERR_STARTMOVE ERR_STORE_PROF ERR_STRTOOLNG ERR_SYMBOL_TYPE ERR_SYM_ACCESS ERR_SYNCMOVEOFF ERR_SYNCMOVEON ERR_SYNTAX
  syn keyword rapidConstant ERR_TASKNAME
  syn keyword rapidConstant ERR_TP_DIBREAK ERR_TP_DOBREAK ERR_TP_MAXTIME ERR_TP_NO_CLIENT ERR_TP_PERSBOOLBREAK
  syn keyword rapidConstant ERR_TRUSTLEVEL ERR_TXTNOEXIST ERR_UDPUC_COMM
  syn keyword rapidConstant ERR_UISHOW_FATAL ERR_UISHOW_FULL ERR_UI_INITVALUE ERR_UI_MAXMIN ERR_UI_NOTINT
  syn keyword rapidConstant ERR_UNIT_PAR ERR_UNKINO ERR_UNKPROC ERR_UNLOAD ERR_USE_PROF
  syn keyword rapidConstant ERR_WAITSYNCTASK ERR_WAIT_MAX ERR_WAIT_MAXTIME ERR_WHL_SEARCH ERR_WHLSEARCH ERR_WOBJ_MOVING
  " error codes starting with CORR_
  syn keyword rapidConstant CORR_NOFREE CORR_NOOBJECT CORR_NOTCONN
  " error codes starting with SEN_
  syn keyword rapidConstant SEN_BUSY SEN_CAALARM SEN_CAMCHECK SEN_EXALARM SEN_GENERRO SEN_NO_MEAS SEN_NOREADY SEN_TEMP SEN_TIMEOUT SEN_UNKNOWN SEN_VALUE
  " error codes starting with SYS_
  syn keyword rapidConstant SYS_ERR_ARL_INPAR_RDONLY SYS_ERR_HW_SMB_WARNING_BATTERY_LOW SYS_ERR_MOC_CNV_REC_FILE_UNKNOWN SYS_ERR_MOC_CNV_REC_NOT_READY
  " error codes starting with TC_
  syn keyword rapidConstant TC_ERR_AIR TC_ERR_CLOSE_COV TC_ERR_DOUNLOCK TC_ERR_IO TC_ERR_IOCFG TC_ERR_LOCK TC_ERR_NOTOOL TC_ERR_OPEN_COV TC_ERR_POWER TC_ERR_PULOCK TC_ERR_ROBPOS TC_ERR_ROBPOS_DROP TC_ERR_ROBPOS_PICK TC_ERR_SERVO_TOOL TC_ERR_STANDNUM TC_ERR_TOOL TC_ERR_TOOLCFG TC_ERR_TOOLNUM  TC_ERR_UNLOCK
  " long jump error
  syn keyword rapidConstant LONG_JMP_ALL_ERR
  " Arc and Arc sensor
  syn keyword rapidConstant AW_IGNI_ERR AW_EQIP_ERR AW_START_ERR AW_STOP_ERR AW_TRACK_ERR AW_TRACKCORR_ERR AW_TRACKSTA_ERR AW_USERSIG_ERR AW_WELD_ERR AW_WIRE_ERR
  " EGM egmframetype
  syn keyword rapidConstant EGM_FRAME_BASE EGM_FRAME_TOOL EGM_FRAME_WOBJ EGM_FRAME_WORLD EGM_FRAME_JOINT
  " Events
  syn keyword rapidConstant EE_START EE_CYCLE_START EE_PROC_START EE_PRE_PROD EE_CLOSE_JIG EE_INDEX EE_PRE_PART EE_POST_PART EE_OPEN_JIG EE_SERVICE EE_POST_PROD EE_ABORT EE_WAIT_ORDER EE_POST_PROC
  syn keyword rapidConstant EE_POWERON EE_POWERON_OR_START EE_RESTART EE_START_OR_RESTART EE_STOP EE_QSTOP EE_STOP_OR_QSTOP EE_RESET EE_STEP EE_STEP_FWD EE_STEP_BCK EE_BEFORE_INIT EE_AFTER_INIT EE_BEFORE_PROD EE_AFTER_PROD EE_BEFORE_MENU EE_AFTER_MENU
  syn keyword rapidConstant EE_ERROR EE_HOMERUN EE_PROG_END EE_AFTER_PROG_NUMBER EE_PROGNO_UNKNOWN EE_PROD_UNKNOWN EE_MSG_WRITTEN EE_MSG_ACKNOWLEDGED EE_AFTER_PART EE_BEFORE_HOMERUN EE_AFTER_HOMERUN EE_BLOCKED
  " motion process mode
  syn keyword rapidConstant OPTIMAL_CYCLE_TIME_MODE LOW_SPEED_ACCURACY_MODE LOW_SPEED_STIFF_MODE ACCURACY_MODE MPM_USER_MODE_1 MPM_USER_MODE_2 MPM_USER_MODE_3 MPM_USER_MODE_4
  " inttypes
  syn keyword rapidConstant USINT UINT UDINT ULINT SINT INT DINT LINT
  " opcalc
  syn keyword rapidConstant OpAdd OpSub OpMult OpDiv OpMod
  " triggmode
  syn keyword rapidConstant TRIGG_MODE1 TRIGG_MODE2 TRIGG_MODE3
  " tunetype
  syn keyword rapidConstant TUNE_DF TUNE_KP TUNE_KV TUNE_TI TUNE_FRIC_LEV TUNE_FRIC_RAMP TUNE_DG TUNE_DH TUNE_DI TUNE_DK TUNE_DL
  " cellopmode
  syn keyword rapidConstant OP_NO_ROBOT OP_SERVICE OP_PRODUCTION
  " execution mode
  syn keyword rapidConstant CT_CONTINUOUS CT_COUNT_CYCLES CT_COUNT_CYC_ACTION CT_PERIODICAL
  " Force Control
  syn keyword rapidConstant FC_REFFRAME_TOOL FC_REFFRAME_WOBJ FC_LIN_X FC_LIN_Y FC_LIN_Z FC_ROT_X FC_ROT_Y FC_ROT_Z FC_SPEED_RATIO_MIN FC_NO_OF_SPEED_LEVELS
  " tpnum
  syn keyword rapidConstant TP_LATEST TP_PROGRAM TP_SCREENVIEWER
  " paridvalidnum
  syn keyword rapidConstant ROB_LOAD_VAL ROB_NOT_LOAD_VAL ROB_LM1_LOAD_VAL 
  " paridnum
  syn keyword rapidConstant TOOL_LOAD_ID PAY_LOAD_ID IRBP_K IRBP_L IRBP_C IRBP_C_INDEX IRBP_T IRBP_R IRBP_A IRBP_B IRBP_D
  " loadidnum
  syn keyword rapidConstant MASS_KNOWN MASS_WITH_AX3
  " sensorstate
  syn keyword rapidConstant STATE_ERROR STATE_UNDEFINED STATE_CONNECTED STATE_OPERATING STATE_CLOSED 
  " signalorigin
  syn keyword rapidConstant SIGORIG_NONE SIGORIG_CFG SIGORIG_ALIAS 
  " aiotrigg
  syn keyword rapidConstant AIO_ABOVE_HIGH AIO_BELOW_HIGH AIO_ABOVE_LOW AIO_BELOW_LOW AIO_BETWEEN AIO_OUTSIDE AIO_ALWAYS
  " socketstatus
  syn keyword rapidConstant SOCKET_CREATED SOCKET_CONNECTED SOCKET_BOUND SOCKET_LISTENING SOCKET_CLOSED
  " symnum of OpMode()
  syn keyword rapidConstant OP_UNDEF OP_AUTO OP_MAN_PROG OP_MAN_TEST
  " symnum of RunMode()
  syn keyword rapidConstant RUN_UNDEF RUN_CONT_CYCLE RUN_INSTR_FWD RUN_INSTR_BWD RUN_SIM RUN_STEP_MOVE
  " event_type of EventType()
  syn keyword rapidConstant EVENT_NONE EVENT_POWERON EVENT_START EVENT_STOP EVENT_QSTOP EVENT_RESTART EVENT_RESET EVENT_STEP
  " handler_type of ExecHandler()
  syn keyword rapidConstant HANDLER_NONE HANDLER_BWD HANDLER_ERR HANDLER_UNDO
  " event_level of ExecLevel()
  syn keyword rapidConstant LEVEL_NORMAL LEVEL_TRAP LEVEL_SERVICE
  " signalorigin of GetSignalOrigin()
  syn keyword rapidConstant SIGORIG_NONE SIGORIG_CFG SIGORIG_ALIAS
  " opnum
  syn keyword rapidConstant LT LTEQ EQ NOTEQ GT GTEQ
  " icondata
  syn keyword rapidConstant iconNone iconInfo iconWarning iconError
  " buttondata
  syn keyword rapidConstant btnNone btnOK btnAbrtRtryIgn btnOKCancel btnRetryCancel btnYesNo btnYesNoCancel
  " btnres
  syn keyword rapidConstant resUnkwn resOK resAbort resRetry resIgnore resCancel resYes resNo
  " cfgdomain
  syn keyword rapidConstant ALL_DOMAINS EIO_DOMAIN MMC_DOMAIN MOC_DOMAIN PROC_DOMAIN SIO_DOMAIN SYS_DOMAIN
  " errdomain
  syn keyword rapidConstant COMMON_ERR OP_STATE SYSTEM_ERR HARDWARE_ERR PROGRAM_ERR MOTION_ERR OPERATOR_ERR IO_COM_ERR USER_DEF_ERR SAFETY_ERR PROCESS_ERR CFG_ERR OPTION_PROD_ERR ARCWELD_ERR SPOTWELD_ERR PAINT_ERR PICKWARE_ERR
  " errtype
  syn keyword rapidConstant TYPE_ALL TYPE_ERR TYPE_STATE TYPE_WARN
  " Sensor Interface
  syn keyword rapidConstant LTAPP__AGE LTAPP__ANGLE LTAPP__AREA LTAPP__CAMCHECK LTAPP__GAP LTAPP__JOINT_NO LTAPP__LASER_OFF LTAPP__MISMATCH LTAPP__PING LTAPP__POWER_UP LTAPP__RESET LTAPP__STEPDIR LTAPP__THICKNESS LTAPP__UNIT
  syn keyword rapidConstant LTAPP__X LTAPP__Y LTAPP__Z LTAPP__APM_P1 LTAPP__APM_P2 LTAPP__APM_P3 LTAPP__APM_P4 LTAPP__APM_P5 LTAPP__APM_P6 LTAPP__ROT_Y LTAPP__ROT_Z LTAPP__X0 LTAPP__Y0 LTAPP__Z0 LTAPP__X1 LTAPP__Y1 LTAPP__Z1 LTAPP__X2 LTAPP__Y2 LTAPP__Z2
  " iounit_state
  syn keyword rapidConstant IOUNIT_LOG_STATE_DISABLED IOUNIT_LOG_STATE_ENABLED IOUNIT_PHYS_STATE_DEACTIVATED IOUNIT_PHYS_STATE_RUNNING IOUNIT_PHYS_STATE_ERROR IOUNIT_PHYS_STATE_UNCONNECTED IOUNIT_PHYS_STATE_UNCONFIGURED IOUNIT_PHYS_STATE_STARTUP IOUNIT_PHYS_STATE_INIT IOUNIT_RUNNING IOUNIT_RUNERROR IOUNIT_DISABLE IOUNIT_OTHERERR
  " busstate
  syn keyword rapidConstant IOBUS_LOG_STATE_STARTED IOBUS_LOG_STATE_STOPPED IOBUS_PHYS_STATE_ERROR IOBUS_PHYS_STATE_HALTED IOBUS_PHYS_STATE_INIT IOBUS_PHYS_STATE_RUNNING IOBUS_PHYS_STATE_STARTUP
  syn keyword rapidConstant BUSSTATE_ERROR BUSSTATE_HALTED BUSSTATE_INIT BUSSTATE_RUN BUSSTATE_STARTUP
  " SoftMove
  syn keyword rapidConstant CSS_POSX CSS_NEGX CSS_POSY CSS_NEGY CSS_POSZ CSS_NEGZ CSS_X CSS_Y CSS_Z CSS_XY CSS_XZ CSS_YZ CSS_XYZ CSS_XYRZ CSS_ARM_ANGLE CSS_REFFRAME_TOOL CSS_REFFRAME_WOBJ
  " tsp_status
  syn keyword rapidConstant TSP_STATUS_NOT_NORMAL_TASK TSP_STATUS_DEACT TSP_STATUS_DEACT_SERV_ROUT TSP_STATUS_ACT TSP_UNCHECKED_RUN_SERV_ROUT TSP_NORMAL_UNCHECKED TSP_STATIC_UNCHECKED TSP_SEMISTATIC_UNCHECKED TSP_NORMAL_CHECKED TSP_STATIC_CHECKED TSP_SEMISTATIC_CHECKED
  " IRC5P (paint controller)
  syn keyword rapidConstant PW_EQUIP_ERR
  " Bulls Eye
  syn keyword rapidConstant BESuccess BENoOverwrite BENoNameMatch BENoBEDataMod BEArrayFull BEToolNotFound BEInvalidSignal BEAliasSet BERangeLimFail BERangeSingFail BERangeTiltFail BEScanPlaneErr BEBFrameNotRead BEScanRadZero BEHeightSrchErr BEBeamNotFound BEBeamSpinErr BESrchErrInBeam BESrchErrNoDet BENumOfScansErr BEDiaZeroOrLess BESliceCountErr BEGetNewTcpMax BEBeamOriFail BEGetTcpDelErr BERefPosSetErr BERefToolSetErr BERefBeamSetErr BEBFrameDefErr BESetupAlready BERefResetErr BESetupFailed BEToolNotSet BEStartChanged BEBeamMoveErr BECheckTcp BECheckErr BESkipUpdate BEStrtningErr BEAllNotSet BEQuikRefNotDef BEConvergErr BEInstFwdErr BEGetGantryErr BEUnknownErr
  " Continuous Application Platform constants
  syn keyword rapidConstant CAP_START START_PRE PRE_STARTED START_MAIN MAIN_STARTED STOP_WEAVESTART WEAVESTART_REGAIN MOTION_DELAY STARTSPEED_TIME MAIN_MOTION MOVE_STARTED RESTART NEW_INSTR AT_POINT AT_RESTARTPOINT LAST_SEGMENT PROCESS_END_POINT END_MAIN MAIN_ENDED PATH_END_POINT PROCESS_ENDED END_POST1 POST1_ENDED END_POST2 POST2_ENDED CAP_STOP CAP_PF_RESTART EQUIDIST AT_ERRORPOINT FLY_START FLY_END LAST_INSTR_ENDED END_PRE PRE_ENDED START_POST1 POST1_STARTED START_POST2 POST2_STARTED 
  syn keyword rapidConstant CAP_PRE_ERR CAP_PRESTART_ERR CAP_END_PRE_ERR CAP_START_ERR CAP_MAIN_ERR CAP_ENDMAIN_ERR CAP_START_POST1_ERR CAP_POST1_ERR CAP_POST1END_ERR CAP_START_POST2_ERR CAP_POST2_ERR CAP_POST2END_ERR CAP_TRACK_ERR CAP_TRACKSTA_ERR CAP_TRACKCOR_ERR CAP_TRACKCOM_ERR CAP_TRACKPFR_ERR CAP_SEN_NO_MEAS CAP_SEN_NOREADY CAP_SEN_GENERRO CAP_SEN_BUSY CAP_SEN_UNKNOWN CAP_SEN_ILLEGAL CAP_SEN_EXALARM CAP_SEN_CAALARM CAP_SEN_TEMP CAP_SEN_VALUE CAP_SEN_CAMCHECK CAP_SEN_TIMEOUT 
  " Machine Tending grppos 
  syn keyword rapidConstant gsOpen gsVacuumOff gsBackward gsClose gsVacuumOn gsForward gsReset
  " Machine Tending grpaction
  syn keyword rapidConstant gaSetAndCheck gaSet gaCheck gaCheckClose gaCheckClose
  " Palletizing PowerPac
  syn keyword rapidConstant PM_ERR_AXLIM PM_ERR_CALCCONF PM_ERR_FLOW_NOT_FOUND PM_ERR_INVALID_FLOW_STOP_OPTION PM_ERR_JOB_EMPTY PM_ERR_LIM_VALUE PM_ERR_NO_RUNNING_PROJECT PM_ERR_NO_TASK PM_ERR_NOT_VALID_RECOVER_ACTION PM_ERR_OPERATION_LOST PM_ERR_PALLET_EMPTY PM_ERR_PALLET_REDUCED PM_ERR_PART_VAL PM_ERR_PROJ_NOT_FOUND PM_ERR_REDO_LAST_PICK_REJECTED PM_ERR_TIMEOUT PM_ERR_WA_NOT_FOUND PM_ERR_WOBJ PM_ERR_WORKAREA_EXPECTED PM_ERR_WRONG_FLOW_STATE
  syn keyword rapidConstant PM_ACK PM_NACK PM_LOST PM_RECOVER_CONTINUE_OPERATION PM_RECOVER_REDO_LAYER PM_RECOVER_NEXT_PALLET PM_RECOVER_REDO_LAST_PICK PM_FLOW_ERROR PM_FLOW_FINISH_CYCLE PM_FLOW_FINISH_LAYER PM_FLOW_FINISH_PALLET PM_FLOW_RUNNING PM_FLOW_STOP_IMMEDIATELY PM_FLOW_STOPPED PM_FLOW_STOPPING_AFTER_CYCLE PM_FLOW_STOPPING_AFTER_LAYER PM_FLOW_STOPPING_AFTER_PALLET PM_APPROACH_POS PM_DEPART_POS PM_TARGET_POS PM_EVENT_PROC PM_EVENT_DO PM_EVENT_GO PM_MOVE_JOINT PM_MOVE_LIN PM_SEARCH_X PM_SEARCH_Y PM_SEARCH_Z PM_SING_AREA_OFF PM_SING_AREA_WRI PM_STOP_NOT_USED PM_STOP PM_PSTOP PM_SSTOP PM_PROJECT_STOPPED PM_PROJECT_STOPPING PM_PROJECT_STARTING PM_PROJECT_RUNNING PM_PROJECT_ERROR 
  syn keyword rapidConstant MaxToolAngle MinToolAngle
  " other constants
  syn keyword rapidConstant GAP_SERVICE_TYPE GAP_SETUP_TYPE GAP_STATE_IDLE GAP_STATE_PART GAP_STATE_SERV GAP_STATE_SETUP GAP_STATE_UNKN GAP_TASK_NAME GAP_TASK_NO GAP_SHOW_ALWAYS GAP_SHOW_NEVER GAP_SHOW_SAFE GAP_SHOW_SERVICE
  syn keyword rapidConstant EOF EOF_BIN EOF_NUM
  syn keyword rapidConstant END_OF_LIST WAIT_MAX
  syn keyword rapidErrNo ERRNO
  syn keyword rapidIntNo INTNO
  " VW Konzernstandard VWKS_1.07.02
  syn keyword rapidIntNo KG_UNDEFINIERT KG_LETZTEPOS KG_GREIFPOS KG_ZWISCHENPOS KG_TOOLINFO KG_GREIFPOSKORR
  syn keyword rapidIntNo BA1 BA2
  syn keyword rapidIntNo SetupXY SetupZ KorrekturXY KorrekturZ
  if g:rapidGroupName
    highlight default link rapidConstant Sysvars
    highlight default link rapidErrNo Sysvars
    highlight default link rapidIntNo Sysvars
  endif
  " }}} ERRNO Constants

  " Error {{{
  if get(g:,'rapidShowError',1)
    "
    " vars or funcs >32 chars are not possible in rapid. a234567890123456789012345
    syn match rapidErrorIdentifierNameTooLong /\k\{33,}/ containedin=rapidFunction,rapidNames,rapidLabel
    highlight default link rapidErrorIdentifierNameTooLong Error
    "
    " a == b + 1
    syn match rapidErrorShouldBeColonEqual /\c\v%(^\s*%(%(TASK\s+|LOCAL\s+)?%(VAR|PERS|CONST)\s+\k+\s+)?\k+%(\k|[.{},*/+-])*\s*)@<=\=/
    highlight default link rapidErrorShouldBeColonEqual Error
    "
    " WaitUntil a==b
    syn match rapidErrorShouldBeEqual    /\c\v%(^\s*%(Return|WaitUntil|while)>[^!\\]+[^!<>])@<=%(\=|:)\=/
    syn match rapidErrorShouldBeEqual    /\c\v%(^\s*%(if|elseif)>[^!\\]+[^!<>])@<=%(\=|:)\=\ze[^!\\]+<then>/
    highlight default link rapidErrorShouldBeEqual Error
    "
    " WaitUntil a=>b
    syn match rapidErrorShoudBeLessOrGreaterEqual /\c\v%(^\s*%(Return|WaitUntil|if|elseif|while)>[^!]+[^!<>])@<=\=[><]/
    highlight default link rapidErrorShoudBeLessOrGreaterEqual Error
    "
    " WaitUntil a><b
    syn match rapidErrorShouldBeLessGreater /\c\v%(^\s*%(Return|WaitUntil|if|elseif|while)[^!]+)@<=\>\s*\</
    highlight default link rapidErrorShouldBeLessGreater Error
    "
    " if (a==5) (b==6)
    syn match rapidErrorMissingOperator /\c\v%(^\s*%(Return|WaitUntil|if|elseif|while)[^!]+[^!])@<=\)\s*\(/
    highlight default link rapidErrorMissingOperator Error
    "
    " "for" missing "from"
    syn match rapidErrorMissingFrom /\c\v^\s*for\s+%([[:upper:][:lower:]]%(\k|[.{},*/+-])*\s+from)@!\S+\s+\S+/
    highlight default link rapidErrorMissingFrom Error
    "
    "
  endif
  " }}} Error

" }}}
endif

" common Error {{{
if get(g:,'rapidShowError',1)
  "
  " This error must be defined after rapidString
  " string too long
  " syn match rapidErrorStringTooLong /\v%("%(""|\\\\|\\\x\x|[^"\\]){80})@240<=%([^"]|"{2})+/ contained contains=rapidStringDoubleQuote,rapidEscapedBackSlash,rapidCharCode,rapidErrorSingleBackslash
  highlight default link rapidErrorStringTooLong Error
  "
endif

" }}} Error

" Finish {{{
let &cpo = s:keepcpo
unlet s:keepcpo

let b:current_syntax = "rapid"
" }}} Finish

" vim:sw=2 sts=2 et fdm=marker
