" Vim syntax file
" Language:	Oracle config files (.ora) (Oracle 8i, ver. 8.1.5)
" Maintainer:	Sandor Kopanyi <sandor.kopanyi@mailbox.hu>
" Url:		<->
" Last Change:	2003 May 11

" * the keywords are listed by file (sqlnet.ora, listener.ora, etc.)
" * the parathesis-checking is made at the beginning for all keywords
" * possible values are listed also
" * there are some overlappings (e.g. METHOD is mentioned both for
"   sqlnet-ora and tnsnames.ora; since will not cause(?) problems
"   is easier to follow separately each file's keywords)

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

if !exists("main_syntax")
  let main_syntax = 'ora'
endif

syn case ignore

"comments
syn match oraComment "\#.*"

" catch errors caused by wrong parenthesis
syn region  oraParen transparent start="(" end=")" contains=@oraAll,oraParen
syn match   oraParenError ")"

" strings
syn region  oraString start=+"+ end=+"+

"common .ora staff

"common protocol parameters
syn keyword oraKeywordGroup   ADDRESS ADDRESS_LIST
syn keyword oraKeywordGroup   DESCRIPTION_LIST DESCRIPTION
"all protocols
syn keyword oraKeyword	      PROTOCOL
syn keyword oraValue	      ipc tcp nmp
"Bequeath
syn keyword oraKeyword	      PROGRAM ARGV0 ARGS
"IPC
syn keyword oraKeyword	      KEY
"Named Pipes
syn keyword oraKeyword	      SERVER PIPE
"LU6.2
syn keyword oraKeyword	      LU_NAME LLU LOCAL_LU LLU_NAME LOCAL_LU_NAME
syn keyword oraKeyword	      MODE MDN
syn keyword oraKeyword	      PLU PARTNER_LU_NAME PLU_LA PARTNER_LU_LOCAL_ALIAS
syn keyword oraKeyword	      TP_NAME TPN
"SPX
syn keyword oraKeyword	      SERVICE
"TCP/IP and TCP/IP with SSL
syn keyword oraKeyword	      HOST PORT

"misc. keywords I've met but didn't find in manual (maybe they are deprecated?)
syn keyword oraKeywordGroup COMMUNITY_LIST
syn keyword oraKeyword	    COMMUNITY NAME DEFAULT_ZONE
syn keyword oraValue	    tcpcom

"common values
syn keyword oraValue	    yes no on off true false null all none ok
"word 'world' is used a lot...
syn keyword oraModifier       world

"misc. common keywords
syn keyword oraKeyword      TRACE_DIRECTORY TRACE_LEVEL TRACE_FILE


"sqlnet.ora
syn keyword oraKeywordPref  NAMES NAMESCTL
syn keyword oraKeywordPref  OSS SOURCE SQLNET TNSPING
syn keyword oraKeyword      AUTOMATIC_IPC BEQUEATH_DETACH DAEMON TRACE_MASK
syn keyword oraKeyword      DISABLE_OOB
syn keyword oraKeyword      LOG_DIRECTORY_CLIENT LOG_DIRECTORY_SERVER
syn keyword oraKeyword      LOG_FILE_CLIENT LOG_FILE_SERVER
syn keyword oraKeyword      DCE PREFIX DEFAULT_DOMAIN DIRECTORY_PATH
syn keyword oraKeyword      INITIAL_RETRY_TIMEOUT MAX_OPEN_CONNECTIONS
syn keyword oraKeyword      MESSAGE_POOL_START_SIZE NIS META_MAP
syn keyword oraKeyword      PASSWORD PREFERRED_SERVERS REQUEST_RETRIES
syn keyword oraKeyword      INTERNAL_ENCRYPT_PASSWORD INTERNAL_USE
syn keyword oraKeyword      NO_INITIAL_SERVER NOCONFIRM
syn keyword oraKeyword      SERVER_PASSWORD TRACE_UNIQUE MY_WALLET
syn keyword oraKeyword      LOCATION DIRECTORY METHOD METHOD_DATA
syn keyword oraKeyword      SQLNET_ADDRESS
syn keyword oraKeyword      AUTHENTICATION_SERVICES
syn keyword oraKeyword      AUTHENTICATION_KERBEROS5_SERVICE
syn keyword oraKeyword      AUTHENTICATION_GSSAPI_SERVICE
syn keyword oraKeyword      CLIENT_REGISTRATION
syn keyword oraKeyword      CRYPTO_CHECKSUM_CLIENT CRYPTO_CHECKSUM_SERVER
syn keyword oraKeyword      CRYPTO_CHECKSUM_TYPES_CLIENT CRYPTO_CHECKSUM_TYPES_SERVER
syn keyword oraKeyword      CRYPTO_SEED
syn keyword oraKeyword      ENCRYPTION_CLIENT ENCRYPTION_SERVER
syn keyword oraKeyword      ENCRYPTION_TYPES_CLIENT ENCRYPTION_TYPES_SERVER
syn keyword oraKeyword      EXPIRE_TIME
syn keyword oraKeyword      IDENTIX_FINGERPRINT_DATABASE IDENTIX_FINGERPRINT_DATABASE_USER
syn keyword oraKeyword      IDENTIX_FINGERPRINT_DATABASE_PASSWORD IDENTIX_FINGERPRINT_METHOD
syn keyword oraKeyword      KERBEROS5_CC_NAME KERBEROS5_CLOCKSKEW KERBEROS5_CONF
syn keyword oraKeyword      KERBEROS5_KEYTAB KERBEROS5_REALMS
syn keyword oraKeyword      RADIUS_ALTERNATE RADIUS_ALTERNATE_PORT RADIUS_ALTERNATE_RETRIES
syn keyword oraKeyword      RADIUS_AUTHENTICATION_TIMEOUT RADIUS_AUTHENTICATION
syn keyword oraKeyword      RADIUS_AUTHENTICATION_INTERFACE RADIUS_AUTHENTICATION_PORT
syn keyword oraKeyword      RADIUS_AUTHENTICATION_RETRIES RADIUS_AUTHENTICATION_TIMEOUT
syn keyword oraKeyword      RADIUS_CHALLENGE_RESPONSE RADIUS_SECRET RADIUS_SEND_ACCOUNTING
syn keyword oraKeyword      SSL_CLIENT_AUTHENTICATION SSL_CIPHER_SUITES SSL_VERSION
syn keyword oraKeyword      TRACE_DIRECTORY_CLIENT TRACE_DIRECTORY_SERVER
syn keyword oraKeyword      TRACE_FILE_CLIENT TRACE_FILE_SERVER
syn keyword oraKeyword      TRACE_LEVEL_CLIENT TRACE_LEVEL_SERVER
syn keyword oraKeyword      TRACE_UNIQUE_CLIENT
syn keyword oraKeyword      USE_CMAN USE_DEDICATED_SERVER
syn keyword oraValue	    user admin support
syn keyword oraValue	    accept accepted reject rejected requested required
syn keyword oraValue	    md5 rc4_40 rc4_56 rc4_128 des des_40
syn keyword oraValue	    tnsnames onames hostname dce nis novell
syn keyword oraValue	    file oracle
syn keyword oraValue	    oss
syn keyword oraValue	    beq nds nts kerberos5 securid cybersafe identix dcegssapi radius
syn keyword oraValue	    undetermined

"tnsnames.ora
syn keyword oraKeywordGroup CONNECT_DATA FAILOVER_MODE
syn keyword oraKeyword      FAILOVER LOAD_BALANCE SOURCE_ROUTE TYPE_OF_SERVICE
syn keyword oraKeyword      BACKUP TYPE METHOD GLOBAL_NAME HS
syn keyword oraKeyword      INSTANCE_NAME RDB_DATABASE SDU SERVER
syn keyword oraKeyword      SERVICE_NAME SERVICE_NAMES SID
syn keyword oraKeyword      HANDLER_NAME EXTPROC_CONNECTION_DATA
syn keyword oraValue	    session select basic preconnect dedicated shared

"listener.ora
syn keyword oraKeywordGroup SID_LIST SID_DESC PRESPAWN_LIST PRESPAWN_DESC
syn match   oraKeywordGroup "SID_LIST_\w*"
syn keyword oraKeyword      PROTOCOL_STACK PRESENTATION SESSION
syn keyword oraKeyword      GLOBAL_DBNAME ORACLE_HOME PROGRAM SID_NAME
syn keyword oraKeyword      PRESPAWN_MAX POOL_SIZE TIMEOUT
syn match   oraKeyword      "CONNECT_TIMEOUT_\w*"
syn match   oraKeyword      "LOG_DIRECTORY_\w*"
syn match   oraKeyword      "LOG_FILE_\w*"
syn match   oraKeyword      "PASSWORDS_\w*"
syn match   oraKeyword      "STARTUP_WAIT_TIME_\w*"
syn match   oraKeyword      "STARTUP_WAITTIME_\w*"
syn match   oraKeyword      "TRACE_DIRECTORY_\w*"
syn match   oraKeyword      "TRACE_FILE_\w*"
syn match   oraKeyword      "TRACE_LEVEL_\w*"
syn match   oraKeyword      "USE_PLUG_AND_PLAY_\w*"
syn keyword oraValue	    ttc giop ns raw

"names.ora
syn keyword oraKeywordGroup ADDRESSES ADMIN_REGION
syn keyword oraKeywordGroup DEFAULT_FORWARDERS FORWARDER_LIST FORWARDER
syn keyword oraKeywordGroup DOMAIN_HINTS HINT_DESC HINT_LIST
syn keyword oraKeywordGroup DOMAINS DOMAIN_LIST DOMAIN
syn keyword oraKeywordPref  NAMES
syn keyword oraKeyword      EXPIRE REFRESH REGION RETRY USERID VERSION
syn keyword oraKeyword      AUTHORITY_REQUIRED CONNECT_TIMEOUT
syn keyword oraKeyword      AUTO_REFRESH_EXPIRE AUTO_REFRESH_RETRY
syn keyword oraKeyword      CACHE_CHECKPOINT_FILE CACHE_CHECKPOINT_INTERVAL
syn keyword oraKeyword      CONFIG_CHECKPOINT_FILE DEFAULT_FORWARDERS_ONLY
syn keyword oraKeyword      HINT FORWARDING_AVAILABLE FORWARDING_DESIRED
syn keyword oraKeyword      KEEP_DB_OPEN
syn keyword oraKeyword      LOG_DIRECTORY LOG_FILE LOG_STATS_INTERVAL LOG_UNIQUE
syn keyword oraKeyword      MAX_OPEN_CONNECTIONS MAX_REFORWARDS
syn keyword oraKeyword      MESSAGE_POOL_START_SIZE
syn keyword oraKeyword      NO_MODIFY_REQUESTS NO_REGION_DATABASE
syn keyword oraKeyword      PASSWORD REGION_CHECKPOINT_FILE
syn keyword oraKeyword      RESET_STATS_INTERVAL SAVE_CONFIG_ON_STOP
syn keyword oraKeyword      SERVER_NAME TRACE_FUNC TRACE_UNIQUE

"cman.ora
syn keyword oraKeywordGroup   CMAN CMAN_ADMIN CMAN_PROFILE PARAMETER_LIST
syn keyword oraKeywordGroup   CMAN_RULES RULES_LIST RULE
syn keyword oraKeyword	      ANSWER_TIMEOUT AUTHENTICATION_LEVEL LOG_LEVEL
syn keyword oraKeyword	      MAX_FREELIST_BUFFERS MAXIMUM_CONNECT_DATA MAXIMUM_RELAYS
syn keyword oraKeyword	      RELAY_STATISTICS SHOW_TNS_INFO TRACING
syn keyword oraKeyword	      USE_ASYNC_CALL SRC DST SRV ACT

"protocol.ora
syn match oraKeyword	      "\w*\.EXCLUDED_NODES"
syn match oraKeyword	      "\w*\.INVITED_NODES"
syn match oraKeyword	      "\w*\.VALIDNODE_CHECKING"
syn keyword oraKeyword	      TCP NODELAY




"---------------------------------------
"init.ora

"common values
syn keyword oraValue	      nested_loops merge hash unlimited

"init params
syn keyword oraKeyword	      O7_DICTIONARY_ACCESSIBILITY ALWAYS_ANTI_JOIN ALWAYS_SEMI_JOIN
syn keyword oraKeyword	      AQ_TM_PROCESSES ARCH_IO_SLAVES AUDIT_FILE_DEST AUDIT_TRAIL
syn keyword oraKeyword	      BACKGROUND_CORE_DUMP BACKGROUND_DUMP_DEST
syn keyword oraKeyword	      BACKUP_TAPE_IO_SLAVES BITMAP_MERGE_AREA_SIZE
syn keyword oraKeyword	      BLANK_TRIMMING BUFFER_POOL_KEEP BUFFER_POOL_RECYCLE
syn keyword oraKeyword	      COMMIT_POINT_STRENGTH COMPATIBLE CONTROL_FILE_RECORD_KEEP_TIME
syn keyword oraKeyword	      CONTROL_FILES CORE_DUMP_DEST CPU_COUNT
syn keyword oraKeyword	      CREATE_BITMAP_AREA_SIZE CURSOR_SPACE_FOR_TIME
syn keyword oraKeyword	      DB_BLOCK_BUFFERS DB_BLOCK_CHECKING DB_BLOCK_CHECKSUM
syn keyword oraKeyword	      DB_BLOCK_LRU_LATCHES DB_BLOCK_MAX_DIRTY_TARGET
syn keyword oraKeyword	      DB_BLOCK_SIZE DB_DOMAIN
syn keyword oraKeyword	      DB_FILE_DIRECT_IO_COUNT DB_FILE_MULTIBLOCK_READ_COUNT
syn keyword oraKeyword	      DB_FILE_NAME_CONVERT DB_FILE_SIMULTANEOUS_WRITES
syn keyword oraKeyword	      DB_FILES DB_NAME DB_WRITER_PROCESSES
syn keyword oraKeyword	      DBLINK_ENCRYPT_LOGIN DBWR_IO_SLAVES
syn keyword oraKeyword	      DELAYED_LOGGING_BLOCK_CLEANOUTS DISCRETE_TRANSACTIONS_ENABLED
syn keyword oraKeyword	      DISK_ASYNCH_IO DISTRIBUTED_TRANSACTIONS
syn keyword oraKeyword	      DML_LOCKS ENQUEUE_RESOURCES ENT_DOMAIN_NAME EVENT
syn keyword oraKeyword	      FAST_START_IO_TARGET FAST_START_PARALLEL_ROLLBACK
syn keyword oraKeyword	      FIXED_DATE FREEZE_DB_FOR_FAST_INSTANCE_RECOVERY
syn keyword oraKeyword	      GC_DEFER_TIME GC_FILES_TO_LOCKS GC_RELEASABLE_LOCKS GC_ROLLBACK_LOCKS
syn keyword oraKeyword	      GLOBAL_NAMES HASH_AREA_SIZE
syn keyword oraKeyword	      HASH_JOIN_ENABLED HASH_MULTIBLOCK_IO_COUNT
syn keyword oraKeyword	      HI_SHARED_MEMORY_ADDRESS HS_AUTOREGISTER
syn keyword oraKeyword	      IFILE
syn keyword oraKeyword	      INSTANCE_GROUPS INSTANCE_NAME INSTANCE_NUMBER
syn keyword oraKeyword	      JAVA_POOL_SIZE JOB_QUEUE_INTERVAL JOB_QUEUE_PROCESSES LARGE_POOL_SIZE
syn keyword oraKeyword	      LICENSE_MAX_SESSIONS LICENSE_MAX_USERS LICENSE_SESSIONS_WARNING
syn keyword oraKeyword	      LM_LOCKS LM_PROCS LM_RESS
syn keyword oraKeyword	      LOCAL_LISTENER LOCK_NAME_SPACE LOCK_SGA LOCK_SGA_AREAS
syn keyword oraKeyword	      LOG_ARCHIVE_BUFFER_SIZE LOG_ARCHIVE_BUFFERS LOG_ARCHIVE_DEST
syn match   oraKeyword	      "LOG_ARCHIVE_DEST_\(1\|2\|3\|4\|5\)"
syn match   oraKeyword	      "LOG_ARCHIVE_DEST_STATE_\(1\|2\|3\|4\|5\)"
syn keyword oraKeyword	      LOG_ARCHIVE_DUPLEX_DEST LOG_ARCHIVE_FORMAT LOG_ARCHIVE_MAX_PROCESSES
syn keyword oraKeyword	      LOG_ARCHIVE_MIN_SUCCEED_DEST LOG_ARCHIVE_START
syn keyword oraKeyword	      LOG_BUFFER LOG_CHECKPOINT_INTERVAL LOG_CHECKPOINT_TIMEOUT
syn keyword oraKeyword	      LOG_CHECKPOINTS_TO_ALERT LOG_FILE_NAME_CONVERT
syn keyword oraKeyword	      MAX_COMMIT_PROPAGATION_DELAY MAX_DUMP_FILE_SIZE
syn keyword oraKeyword	      MAX_ENABLED_ROLES MAX_ROLLBACK_SEGMENTS
syn keyword oraKeyword	      MTS_DISPATCHERS MTS_MAX_DISPATCHERS MTS_MAX_SERVERS MTS_SERVERS
syn keyword oraKeyword	      NLS_CALENDAR NLS_COMP NLS_CURRENCY NLS_DATE_FORMAT
syn keyword oraKeyword	      NLS_DATE_LANGUAGE NLS_DUAL_CURRENCY NLS_ISO_CURRENCY NLS_LANGUAGE
syn keyword oraKeyword	      NLS_NUMERIC_CHARACTERS NLS_SORT NLS_TERRITORY
syn keyword oraKeyword	      OBJECT_CACHE_MAX_SIZE_PERCENT OBJECT_CACHE_OPTIMAL_SIZE
syn keyword oraKeyword	      OPEN_CURSORS OPEN_LINKS OPEN_LINKS_PER_INSTANCE
syn keyword oraKeyword	      OPS_ADMINISTRATION_GROUP
syn keyword oraKeyword	      OPTIMIZER_FEATURES_ENABLE OPTIMIZER_INDEX_CACHING
syn keyword oraKeyword	      OPTIMIZER_INDEX_COST_ADJ OPTIMIZER_MAX_PERMUTATIONS
syn keyword oraKeyword	      OPTIMIZER_MODE OPTIMIZER_PERCENT_PARALLEL
syn keyword oraKeyword	      OPTIMIZER_SEARCH_LIMIT
syn keyword oraKeyword	      ORACLE_TRACE_COLLECTION_NAME ORACLE_TRACE_COLLECTION_PATH
syn keyword oraKeyword	      ORACLE_TRACE_COLLECTION_SIZE ORACLE_TRACE_ENABLE
syn keyword oraKeyword	      ORACLE_TRACE_FACILITY_NAME ORACLE_TRACE_FACILITY_PATH
syn keyword oraKeyword	      OS_AUTHENT_PREFIX OS_ROLES
syn keyword oraKeyword	      PARALLEL_ADAPTIVE_MULTI_USER PARALLEL_AUTOMATIC_TUNING
syn keyword oraKeyword	      PARALLEL_BROADCAST_ENABLED PARALLEL_EXECUTION_MESSAGE_SIZE
syn keyword oraKeyword	      PARALLEL_INSTANCE_GROUP PARALLEL_MAX_SERVERS
syn keyword oraKeyword	      PARALLEL_MIN_PERCENT PARALLEL_MIN_SERVERS
syn keyword oraKeyword	      PARALLEL_SERVER PARALLEL_SERVER_INSTANCES PARALLEL_THREADS_PER_CPU
syn keyword oraKeyword	      PARTITION_VIEW_ENABLED PLSQL_V2_COMPATIBILITY
syn keyword oraKeyword	      PRE_PAGE_SGA PROCESSES
syn keyword oraKeyword	      QUERY_REWRITE_ENABLED QUERY_REWRITE_INTEGRITY
syn keyword oraKeyword	      RDBMS_SERVER_DN READ_ONLY_OPEN_DELAYED RECOVERY_PARALLELISM
syn keyword oraKeyword	      REMOTE_DEPENDENCIES_MODE REMOTE_LOGIN_PASSWORDFILE
syn keyword oraKeyword	      REMOTE_OS_AUTHENT REMOTE_OS_ROLES
syn keyword oraKeyword	      REPLICATION_DEPENDENCY_TRACKING
syn keyword oraKeyword	      RESOURCE_LIMIT RESOURCE_MANAGER_PLAN
syn keyword oraKeyword	      ROLLBACK_SEGMENTS ROW_LOCKING SERIAL _REUSE SERVICE_NAMES
syn keyword oraKeyword	      SESSION_CACHED_CURSORS SESSION_MAX_OPEN_FILES SESSIONS
syn keyword oraKeyword	      SHADOW_CORE_DUMP
syn keyword oraKeyword	      SHARED_MEMORY_ADDRESS SHARED_POOL_RESERVED_SIZE SHARED_POOL_SIZE
syn keyword oraKeyword	      SORT_AREA_RETAINED_SIZE SORT_AREA_SIZE SORT_MULTIBLOCK_READ_COUNT
syn keyword oraKeyword	      SQL92_SECURITY SQL_TRACE STANDBY_ARCHIVE_DEST
syn keyword oraKeyword	      STAR_TRANSFORMATION_ENABLED TAPE_ASYNCH_IO THREAD
syn keyword oraKeyword	      TIMED_OS_STATISTICS TIMED_STATISTICS
syn keyword oraKeyword	      TRANSACTION_AUDITING TRANSACTIONS TRANSACTIONS_PER_ROLLBACK_SEGMENT
syn keyword oraKeyword	      USE_INDIRECT_DATA_BUFFERS USER_DUMP_DEST
syn keyword oraKeyword	      UTL_FILE_DIR
syn keyword oraKeywordObs     ALLOW_PARTIAL_SN_RESULTS B_TREE_BITMAP_PLANS
syn keyword oraKeywordObs     BACKUP_DISK_IO_SLAVES CACHE_SIZE_THRESHOLD
syn keyword oraKeywordObs     CCF_IO_SIZE CLEANUP_ROLLBACK_ENTRIES
syn keyword oraKeywordObs     CLOSE_CACHED_OPEN_CURSORS COMPATIBLE_NO_RECOVERY
syn keyword oraKeywordObs     COMPLEX_VIEW_MERGING
syn keyword oraKeywordObs     DB_BLOCK_CHECKPOINT_BATCH DB_BLOCK_LRU_EXTENDED_STATISTICS
syn keyword oraKeywordObs     DB_BLOCK_LRU_STATISTICS
syn keyword oraKeywordObs     DISTRIBUTED_LOCK_TIMEOUT DISTRIBUTED_RECOVERY_CONNECTION_HOLD_TIME
syn keyword oraKeywordObs     FAST_FULL_SCAN_ENABLED GC_LATCHES GC_LCK_PROCS
syn keyword oraKeywordObs     LARGE_POOL_MIN_ALLOC LGWR_IO_SLAVES
syn keyword oraKeywordObs     LOG_BLOCK_CHECKSUM LOG_FILES
syn keyword oraKeywordObs     LOG_SIMULTANEOUS_COPIES LOG_SMALL_ENTRY_MAX_SIZE
syn keyword oraKeywordObs     MAX_TRANSACTION_BRANCHES
syn keyword oraKeywordObs     MTS_LISTENER_ADDRESS MTS_MULTIPLE_LISTENERS
syn keyword oraKeywordObs     MTS_RATE_LOG_SIZE MTS_RATE_SCALE MTS_SERVICE
syn keyword oraKeywordObs     OGMS_HOME OPS_ADMIN_GROUP
syn keyword oraKeywordObs     PARALLEL_DEFAULT_MAX_INSTANCES PARALLEL_MIN_MESSAGE_POOL
syn keyword oraKeywordObs     PARALLEL_SERVER_IDLE_TIME PARALLEL_TRANSACTION_RESOURCE_TIMEOUT
syn keyword oraKeywordObs     PUSH_JOIN_PREDICATE REDUCE_ALARM ROW_CACHE_CURSORS
syn keyword oraKeywordObs     SEQUENCE_CACHE_ENTRIES SEQUENCE_CACHE_HASH_BUCKETS
syn keyword oraKeywordObs     SHARED_POOL_RESERVED_MIN_ALLOC
syn keyword oraKeywordObs     SORT_DIRECT_WRITES SORT_READ_FAC SORT_SPACEMAP_SIZE
syn keyword oraKeywordObs     SORT_WRITE_BUFFER_SIZE SORT_WRITE_BUFFERS
syn keyword oraKeywordObs     SPIN_COUNT TEMPORARY_TABLE_LOCKS USE_ISM
syn keyword oraValue	      db os full partial mandatory optional reopen enable defer
syn keyword oraValue	      always default intent disable dml plsql temp_disable
syn match   oravalue	      "Arabic Hijrah"
syn match   oravalue	      "English Hijrah"
syn match   oravalue	      "Gregorian"
syn match   oravalue	      "Japanese Imperial"
syn match   oravalue	      "Persian"
syn match   oravalue	      "ROC Official"
syn match   oravalue	      "Thai Buddha"
syn match   oravalue	      "8.0.0"
syn match   oravalue	      "8.0.3"
syn match   oravalue	      "8.0.4"
syn match   oravalue	      "8.1.3"
syn match oraModifier	      "archived log"
syn match oraModifier	      "backup corruption"
syn match oraModifier	      "backup datafile"
syn match oraModifier	      "backup piece  "
syn match oraModifier	      "backup redo log"
syn match oraModifier	      "backup set"
syn match oraModifier	      "copy corruption"
syn match oraModifier	      "datafile copy"
syn match oraModifier	      "deleted object"
syn match oraModifier	      "loghistory"
syn match oraModifier	      "offline range"

"undocumented init params
"up to 7.2 (inclusive)
syn keyword oraKeywordUndObs  _latch_spin_count _trace_instance_termination
syn keyword oraKeywordUndObs  _wakeup_timeout _lgwr_async_write
"7.3
syn keyword oraKeywordUndObs  _standby_lock_space_name _enable_dba_locking
"8.0.5
syn keyword oraKeywordUnd     _NUMA_instance_mapping _NUMA_pool_size
syn keyword oraKeywordUnd     _advanced_dss_features _affinity_on _all_shared_dblinks
syn keyword oraKeywordUnd     _allocate_creation_order _allow_resetlogs_corruption
syn keyword oraKeywordUnd     _always_star_transformation _bump_highwater_mark_count
syn keyword oraKeywordUnd     _column_elimination_off _controlfile_enqueue_timeout
syn keyword oraKeywordUnd     _corrupt_blocks_on_stuck_recovery _corrupted_rollback_segments
syn keyword oraKeywordUnd     _cr_deadtime _cursor_db_buffers_pinned
syn keyword oraKeywordUnd     _db_block_cache_clone _db_block_cache_map _db_block_cache_protect
syn keyword oraKeywordUnd     _db_block_hash_buckets _db_block_hi_priority_batch_size
syn keyword oraKeywordUnd     _db_block_max_cr_dba _db_block_max_scan_cnt
syn keyword oraKeywordUnd     _db_block_med_priority_batch_size _db_block_no_idle_writes
syn keyword oraKeywordUnd     _db_block_write_batch _db_handles _db_handles_cached
syn keyword oraKeywordUnd     _db_large_dirty_queue _db_no_mount_lock
syn keyword oraKeywordUnd     _db_writer_histogram_statistics _db_writer_scan_depth
syn keyword oraKeywordUnd     _db_writer_scan_depth_decrement _db_writer_scan_depth_increment
syn keyword oraKeywordUnd     _disable_incremental_checkpoints
syn keyword oraKeywordUnd     _disable_latch_free_SCN_writes_via_32cas
syn keyword oraKeywordUnd     _disable_latch_free_SCN_writes_via_64cas
syn keyword oraKeywordUnd     _disable_logging _disable_ntlog_events
syn keyword oraKeywordUnd     _dss_cache_flush _dynamic_stats_threshold
syn keyword oraKeywordUnd     _enable_cscn_caching _enable_default_affinity
syn keyword oraKeywordUnd     _enqueue_debug_multi_instance _enqueue_hash
syn keyword oraKeywordUnd     _enqueue_hash_chain_latches _enqueue_locks
syn keyword oraKeywordUnd     _fifth_spare_parameter _first_spare_parameter _fourth_spare_parameter
syn keyword oraKeywordUnd     _gc_class_locks _groupby_nopushdown_cut_ratio
syn keyword oraKeywordUnd     _idl_conventional_index_maintenance _ignore_failed_escalates
syn keyword oraKeywordUnd     _init_sql_file
syn keyword oraKeywordUnd     _io_slaves_disabled _ioslave_batch_count _ioslave_issue_count
syn keyword oraKeywordUnd     _kgl_bucket_count _kgl_latch_count _kgl_multi_instance_invalidation
syn keyword oraKeywordUnd     _kgl_multi_instance_lock _kgl_multi_instance_pin
syn keyword oraKeywordUnd     _latch_miss_stat_sid _latch_recovery_alignment _latch_wait_posting
syn keyword oraKeywordUnd     _lm_ast_option _lm_direct_sends _lm_dlmd_procs _lm_domains _lm_groups
syn keyword oraKeywordUnd     _lm_non_fault_tolerant _lm_send_buffers _lm_statistics _lm_xids
syn keyword oraKeywordUnd     _log_blocks_during_backup _log_buffers_debug _log_checkpoint_recovery_check
syn keyword oraKeywordUnd     _log_debug_multi_instance _log_entry_prebuild_threshold _log_io_size
syn keyword oraKeywordUnd     _log_space_errors
syn keyword oraKeywordUnd     _max_exponential_sleep _max_sleep_holding_latch
syn keyword oraKeywordUnd     _messages _minimum_giga_scn _mts_load_constants _nested_loop_fudge
syn keyword oraKeywordUnd     _no_objects _no_or_expansion
syn keyword oraKeywordUnd     _number_cached_attributes _offline_rollback_segments _open_files_limit
syn keyword oraKeywordUnd     _optimizer_undo_changes
syn keyword oraKeywordUnd     _oracle_trace_events _oracle_trace_facility_version
syn keyword oraKeywordUnd     _ordered_nested_loop _parallel_server_sleep_time
syn keyword oraKeywordUnd     _passwordfile_enqueue_timeout _pdml_slaves_diff_part
syn keyword oraKeywordUnd     _plsql_dump_buffer_events _predicate_elimination_enabled
syn keyword oraKeywordUnd     _project_view_columns
syn keyword oraKeywordUnd     _px_broadcast_fudge_factor _px_broadcast_trace _px_dop_limit_degree
syn keyword oraKeywordUnd     _px_dop_limit_threshold _px_kxfr_granule_allocation _px_kxib_tracing
syn keyword oraKeywordUnd     _release_insert_threshold _reuse_index_loop
syn keyword oraKeywordUnd     _rollback_segment_count _rollback_segment_initial
syn keyword oraKeywordUnd     _row_cache_buffer_size _row_cache_instance_locks
syn keyword oraKeywordUnd     _save_escalates _scn_scheme
syn keyword oraKeywordUnd     _second_spare_parameter _session_idle_bit_latches
syn keyword oraKeywordUnd     _shared_session_sort_fetch_buffer _single_process
syn keyword oraKeywordUnd     _small_table_threshold _sql_connect_capability_override
syn keyword oraKeywordUnd     _sql_connect_capability_table
syn keyword oraKeywordUnd     _test_param_1 _test_param_2 _test_param_3
syn keyword oraKeywordUnd     _third_spare_parameter _tq_dump_period
syn keyword oraKeywordUnd     _trace_archive_dest _trace_archive_start _trace_block_size
syn keyword oraKeywordUnd     _trace_buffers_per_process _trace_enabled _trace_events
syn keyword oraKeywordUnd     _trace_file_size _trace_files_public _trace_flushing _trace_write_batch_size
syn keyword oraKeywordUnd     _upconvert_from_ast _use_vector_post _wait_for_sync _walk_insert_threshold
"dunno which version; may be 8.1.x, may be obsoleted
syn keyword oraKeywordUndObs  _arch_io_slaves _average_dirties_half_life _b_tree_bitmap_plans
syn keyword oraKeywordUndObs  _backup_disk_io_slaves _backup_io_pool_size
syn keyword oraKeywordUndObs  _cleanup_rollback_entries _close_cached_open_cursors
syn keyword oraKeywordUndObs  _compatible_no_recovery _complex_view_merging
syn keyword oraKeywordUndObs  _cpu_to_io _cr_server
syn keyword oraKeywordUndObs  _db_aging_cool_count _db_aging_freeze_cr _db_aging_hot_criteria
syn keyword oraKeywordUndObs  _db_aging_stay_count _db_aging_touch_time
syn keyword oraKeywordUndObs  _db_percent_hot_default _db_percent_hot_keep _db_percent_hot_recycle
syn keyword oraKeywordUndObs  _db_writer_chunk_writes _db_writer_max_writes
syn keyword oraKeywordUndObs  _dbwr_async_io _dbwr_tracing
syn keyword oraKeywordUndObs  _defer_multiple_waiters _discrete_transaction_enabled
syn keyword oraKeywordUndObs  _distributed_lock_timeout _distributed_recovery _distribited_recovery_
syn keyword oraKeywordUndObs  _domain_index_batch_size _domain_index_dml_batch_size
syn keyword oraKeywordUndObs  _enable_NUMA_optimization _enable_block_level_transaction_recovery
syn keyword oraKeywordUndObs  _enable_list_io _enable_multiple_sampling
syn keyword oraKeywordUndObs  _fairness_treshold _fast_full_scan_enabled _foreground_locks
syn keyword oraKeywordUndObs  _full_pwise_join_enabled _gc_latches _gc_lck_procs
syn keyword oraKeywordUndObs  _high_server_treshold _index_prefetch_factor _kcl_debug
syn keyword oraKeywordUndObs  _kkfi_trace _large_pool_min_alloc _lazy_freelist_close _left_nested_loops_random
syn keyword oraKeywordUndObs  _lgwr_async_io _lgwr_io_slaves _lock_sga_areas
syn keyword oraKeywordUndObs  _log_archive_buffer_size _log_archive_buffers _log_simultaneous_copies
syn keyword oraKeywordUndObs  _low_server_treshold _max_transaction_branches
syn keyword oraKeywordUndObs  _mts_rate_log_size _mts_rate_scale
syn keyword oraKeywordUndObs  _mview_cost_rewrite _mview_rewrite_2
syn keyword oraKeywordUndObs  _ncmb_readahead_enabled _ncmb_readahead_tracing
syn keyword oraKeywordUndObs  _ogms_home
syn keyword oraKeywordUndObs  _parallel_adaptive_max_users _parallel_default_max_instances
syn keyword oraKeywordUndObs  _parallel_execution_message_align _parallel_fake_class_pct
syn keyword oraKeywordUndObs  _parallel_load_bal_unit _parallel_load_balancing
syn keyword oraKeywordUndObs  _parallel_min_message_pool _parallel_recovery_stopat
syn keyword oraKeywordUndObs  _parallel_server_idle_time _parallelism_cost_fudge_factor
syn keyword oraKeywordUndObs  _partial_pwise_join_enabled _pdml_separate_gim _push_join_predicate
syn keyword oraKeywordUndObs  _px_granule_size _px_index_sampling _px_load_publish_interval
syn keyword oraKeywordUndObs  _px_max_granules_per_slave _px_min_granules_per_slave _px_no_stealing
syn keyword oraKeywordUndObs  _row_cache_cursors _serial_direct_read _shared_pool_reserved_min_alloc
syn keyword oraKeywordUndObs  _sort_space_for_write_buffers _spin_count _system_trig_enabled
syn keyword oraKeywordUndObs  _trace_buffer_flushes _trace_cr_buffer_creates _trace_multi_block_reads
syn keyword oraKeywordUndObs  _transaction_recovery_servers _use_ism _yield_check_interval


syn cluster oraAll add=oraKeyword,oraKeywordGroup,oraKeywordPref,oraKeywordObs,oraKeywordUnd,oraKeywordUndObs
syn cluster oraAll add=oraValue,oraModifier,oraString,oraSpecial,oraComment

"==============================================================================
" highlighting

" Only when an item doesn't have highlighting yet

hi def link oraKeyword	  Statement		"usual keywords
hi def link oraKeywordGroup  Type			"keywords which group other keywords
hi def link oraKeywordPref   oraKeywordGroup	"keywords which act as prefixes
hi def link oraKeywordObs	  Todo			"obsolete keywords
hi def link oraKeywordUnd	  PreProc		"undocumented keywords
hi def link oraKeywordUndObs oraKeywordObs		"undocumented obsolete keywords
hi def link oraValue	  Identifier		"values, like true or false
hi def link oraModifier	  oraValue		"modifies values
hi def link oraString	  String		"strings

hi def link oraSpecial	  Special		"special characters
hi def link oraError	  Error			"errors
hi def link oraParenError	  oraError		"errors caused by mismatching parantheses

hi def link oraComment	  Comment		"comments



let b:current_syntax = "ora"

if main_syntax == 'ora'
  unlet main_syntax
endif

" vim: ts=8
