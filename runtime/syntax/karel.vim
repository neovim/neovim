" Vim syntax file
" Language:    KAREL
" Last Change: 2024-11-17
" Maintainer:  Kirill Morozov <kirill@robotix.pro>
" Credits:     Jay Strybis for the initial implementation and Patrick Knosowski
"              for a couple of fixes.

if exists("b:current_syntax")
  finish
endif

" KAREL is case-insensitive
syntax case ignore

" Identifiers
syn match   karelIdentifier  /[a-zA-Z0-9_]\+/
hi def link karelIdentifier  Identifier

" Constants
syn keyword karelConstant    CR
syn region  karelString      start="'" end="'"
syn match   karelReal        /\d\+\.\d\+/
syn match   karelInteger     /\d\+/
syn keyword karelBoolean     true false
hi def link karelConstant    Constant
hi def link karelString      String
hi def link karelInteger     Number
hi def link karelReal        Float
hi def link karelBoolean     Boolean

" Directives
syn match   karelDirective   /%[a-zA-Z]\+/
hi def link karelDirective   PreProc

" Operators
syn keyword karelOperator    AND OR NOT DIV MOD
syn match   karelOperator    /[\+\-\*\/\<\=\>\:\#\@]/
syn match   karelOperator    /<=/
syn match   karelOperator    />=/
syn match   karelOperator    /<>/
syn match   karelOperator    />=</
hi def link karelOperator    Operator

" Types
syn keyword karelType        ARRAY BOOLEAN BYTE CONFIG DISP_DAT_T FILE INTEGER JOINTPOS PATH POSITION QUEUE_TYPE REAL SHORT STD_PTH_NODE STRING VECTOR XYZWPR XYZWPREXT
syn keyword karelStructure   STRUCTURE ENDSTRUCTURE
hi def link karelType        Type
hi def link karelStructure   Typedef

syn keyword karelAction      NOABORT NOMESSAGE NOPAUSE PAUSE PULSE RESUME STOP UNHOLD UNPAUSE
syn match   karelAction      /SIGNAL EVENT/
syn match   karelAction      /SIGNAL SEMAPHORE/
hi def link karelAction      Keyword

syn keyword karelFunction    ABS ACOS APPROACH ARRAY_LEN ASIN ATAN2 ATTACH BYNAME BYTES_LEFT CHR COS CURJPOS CURPOS CURR_PROG EXP
syn keyword karelFunction    FRAME GET_FILE_POS GET_JPOS_REG GET_JPOS_TPE GET_PORT_ATR GET_POS_REG GET_POS_TPE GET_USEC_TIM INDEX
syn keyword karelFunction    IN_RANGE INV IO_STATUS J_IN_RANGE JOINT2POS LN MIRROR MOTION_CTL NODE_SIZE ORD ORIENT PATH_LEN POS POS2JOINT
syn keyword karelFunction    ROUND SEMA_COUNT SIN SQRT STR_LEN SUB_STR TAN TRUNC UNINIT
hi def link karelFunction    Function

syn keyword karelClause      EVAL FROM IN WHEN WITH
hi def link karelClause      Keyword

syn keyword karelConditional IF THEN ELSE ENDIF SELECT ENDSELECT CASE
hi def link karelConditional Conditional

syn keyword karelRepeat      WHILE DO ENDWHILE FOR
hi def link karelRepeat      Repeat

syn keyword karelProcedure   ABORT_TASK ACT_SCREEN ACT_TBL ADD_BYNAMEPC ADD_DICT ADD_INTPC ADD_REALPC ADD_STRINGPC APPEND_NODE APPEND_QUEUE
syn keyword karelProcedure   ATT_WINDOW_D ATT_WINDOW_S AVL_POS_NUM
syn keyword karelProcedure   BYTES_AHEAD
syn keyword karelProcedure   CALL_PROG CALL_PROGLIN CHECK_DICT CHECK_EPOS CHECK_NAME CLEAR CLEAR_SEMA CLOSE_TEP CLR_IO_STAT CLR_PORT_SIM CLR_POS_REG
syn keyword karelProcedure   CNC_DYN_DISB CNC_DYN_DISE CNC_DYN_DISI CNC_DYN_DISP CNC_DYN_DISR CNC_DYN_DISS CNCL_STP_MTN CNV_CNF_STRG CNV_CONF_STR CNV_INT_STR CNV_JPOS_REL CNV_REAL_STR CNV_REL_JPOS CNV_STR_CONF CNV_STR_INT CNV_STR_REAL CNV_STR_TIME CNV_TIME_STR
syn keyword karelProcedure   COMPARE_FILE CONT_TASK COPY_FILE COPY_PATH COPY_QUEUE COPY_TPE CREATE_TPE CREATE_VAR
syn keyword karelProcedure   DAQ_CHECKP DAQ_REGPIPE DAQ_START DAQ_STOP DAQ_UNREG DAQ_WRITE DEF_SCREEN DEF_WINDOW
syn keyword karelProcedure   DELETE_FILE DELETE_NODE DELETE_QUEUE DEL_INST_TPE DET_WINDOW DISCTRL_ALPH DISCTRL_FORM DISCTRL_LIST DISCTRL_PLMN DISCTRL_SBMN DISCTRL_TBL DISMOUNT_DEV DOSFILE_INF
syn keyword karelProcedure   ERR_DATA FILE_LIST FORCE_SPMENU FORMAT_DEV GET_ATTR_PRG GET_PORT_ASG GET_PORT_CMT GET_PORT_MOD GET_PORT_SIM GET_PORT_VAL GET_POS_FRM GET_POS_TYP GET_PREG_CMT GET_QUEUE
syn keyword karelProcedure   GET_REG GET_REG_CMT GET_SREG_CMT GET_STR_REG GET_TIME GET_TPE_CMT GET_TPE_PRM GET_TSK_INFO GET_USEC_SUB GET_VAR
syn keyword karelProcedure   INI_DYN_DISB INI_DYN_DISE INI_DYN_DISI INI_DYN_DISP INI_DYN_DISR INI_DYN_DISS INIT_QUEUE INIT_TBL INSERT_NODE INSERT_QUEUE IO_MOD_TYPE
syn keyword karelProcedure   KCL KCL_NO_WAIT KCL_STATUS LOAD LOAD_STATUS LOCK_GROUP MODIFY_QUEUE MOUNT_DEV MOVE_FILE MSG_CONNECT MSG_DISO MSG_PING
syn keyword karelProcedure   OPEN_TPE PAUSE_TASK PEND_SEMA PIPE_CONFIG POP_KEY_RD POS_REG_TYPE POST_ERR POST_ERR_L POST_SEMA PRINT_FILE PROG_BACKUP PROG_CLEAR PROG_RESTORE PROG_LIST
syn keyword karelProcedure   PURGE_DEV PUSH_KEY_RD READ_DICT READ_DICT_V READ_KB REMOVE_DICT RENAME_FILE RENAME_VAR RENAME_VARS RESET RUN_TASK SAVE SAVE_DRAM SELECT_TPE SEND_DATAPC SEND_EVENTPC SET_ATTR_PRG SET_CURSOR SET_EPOS_REG SET_EPOS_TPE
syn keyword karelProcedure   SET_FILE_ATR SET_FILE_POS SET_INT_REG SET_JPOS_REG SET_JPOS_TPE SET_LANG SET_PERCH SET_PORT_ASG SET_PORT_ATR SET_PORT_CMT SET_PORT_MOD SET_PORT_SIM SET_PORT_VAL SET_POS_REG SET_POS_TPE SET_PREG_CMT SET_REAL_REG SET_REG CMT SET_SREG_CMT SET_STR_REG SET_TIME SET_TPE_CMT SET_TRNS_TPE SET_TSK_ATTR SET_TSK_NAME SET_VAR
syn keyword karelProcedure   TRANSLATE UNLOCK_GROUP UNPOS V_CAM_CALIB V_GET_OFFSET V_GET_PASSFL V_GET_QUEUE V_INIT_QUEUE V_RALC_QUEUE V_RUN_FIND V_SET_REF V_START_VTRK V_STOP_VTRK VAR_INFO VAR_LIST VOL_SPACE VREG_FND_POS VREG_OFFSET
syn keyword karelProcedure   WRITE_DICT WRITE_DICT_V XML_ADDTAG XML_GETDATA XML_REMTAG XML_SCAN XML_SETVAR
hi def link karelProcedure   Function

syn keyword karelStatement   ABORT CONDITION ENDCONDITION CONTINUE DELAY ERROR EVENT FOR ENDFOR HOLD READ RELEASE REPEAT RETURN SEMAPHORE UNTIL USING ENDUSING WRITE
syn match   karelStatement   /CANCEL FILE/
syn match   karelStatement   /CLOSE FILE/
syn match   karelStatement   /CLOSE HAND/
syn match   karelStatement   /CONNECT TIMER/
syn match   karelStatement   /DISABLE CONDITION/
syn match   karelStatement   /DISCONNECT TIMER/
syn match   karelStatement   /ENABLE CONDITION/
syn match   karelStatement   /GO TO/
syn match   karelStatement   /OPEN FILE/
syn match   karelStatement   /OPEN HAND/
syn match   karelStatement   /PURGE CONDITION/
syn match   karelStatement   /RELAX HAND/
syn match   karelStatement   /WAIT FOR/
hi def link karelStatement   Statement

syn keyword karelKeyword     BEGIN CONST END PROGRAM ROUTINE STRUCT TYPE VAR
hi def link karelKeyword     Keyword

" Comments
syn region karelComment      start="--" end="$"
hi def link karelComment     Comment

let b:current_syntax = "karel"
