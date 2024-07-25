" Vim syntax file
" Language:		Progress 4GL
" Filename extensions:	*.p (collides with Pascal),
"			*.i (collides with assembler)
"			*.w (collides with cweb)
" Maintainer:           Daniel Smith <daniel@rdnlsmith.com>
" Previous Maintainer:  Philip Uren <philuSPAXY@ieee.org> Remove SPAXY spam block
" Contributors:         Matthew Stickney	<mtstickneySPAXY@gmail.com>
" 			Chris Ruprecht		<chrisSPAXY@ruprecht.org>
"			Mikhail Kuperblum	<mikhailSPAXY@whasup.com>
"			John Florian		<jflorianSPAXY@voyager.net>
" Version:              13
" Last Change:		Nov 11 2012

" quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword=@,48-57,_,-,!,#,$,%

" The Progress editor doesn't cope with tabs very well.
set expandtab

syn case ignore

" Progress Blocks of code and mismatched "end." errors.
syn match   ProgressEndError		"\<end\>"
syn region ProgressDoBlock transparent matchgroup=ProgressDo start="\<do\>" matchgroup=ProgressDo end="\<end\>" contains=ALLBUT,ProgressProcedure,ProgressFunction
syn region ProgressForBlock transparent matchgroup=ProgressFor start="\<for\>" matchgroup=ProgressFor end="\<end\>" contains=ALLBUT,ProgressProcedure,ProgressFunction
syn region ProgressRepeatBlock transparent matchgroup=ProgressRepeat start="\<repeat\>" matchgroup=ProgressRepeat end="\<end\>" contains=ALLBUT,ProgressProcedure,ProgressFunction
syn region ProgressCaseBlock transparent matchgroup=ProgressCase start="\<case\>" matchgroup=ProgressCase end="\<end\scase\>\|\<end\>" contains=ALLBUT,ProgressProcedure,ProgressFunction

" These are Progress reserved words,
" and they could go in ProgressReserved,
" but I found it more helpful to highlight them in a different color.
syn keyword ProgressConditional	if else then when otherwise
syn keyword ProgressFor				each where

" Make those TODO and debugging notes stand out!
syn keyword ProgressTodo			contained	TODO BUG FIX
syn keyword ProgressDebug			contained	DEBUG
syn keyword ProgressDebug			debugger

" If you like to highlight the whole line of
" the start and end of procedures
" to make the whole block of code stand out:
syn match ProgressProcedure		"^\s*procedure.*"
syn match ProgressProcedure		"^\s*end\s\s*procedure.*"
syn match ProgressFunction		"^\s*function.*"
syn match ProgressFunction		"^\s*end\s\s*function.*"
" ... otherwise use this:
" syn keyword ProgressFunction	procedure function

syn keyword ProgressReserved	accum[ulate] active-form active-window add alias all alter ambig[uous] analyz[e] and any apply as asc[ending]
syn keyword ProgressReserved	assign asynchronous at attr[-space] audit-control audit-policy authorization auto-ret[urn] avail[able] back[ground]
syn keyword ProgressReserved	before-h[ide] begins bell between big-endian blank break buffer-comp[are] buffer-copy by by-pointer by-variant-point[er] call
syn keyword ProgressReserved	can-do can-find case case-sen[sitive] cast center[ed] check chr clear clipboard codebase-locator colon color column-lab[el]
syn keyword ProgressReserved	col[umns] com-self compiler connected control copy-lob count-of cpstream create current current-changed current-lang[uage]
syn keyword ProgressReserved	current-window current_date curs[or] database dataservers dataset dataset-handle db-remote-host dbcodepage dbcollation dbname
syn keyword ProgressReserved	dbparam dbrest[rictions] dbtaskid dbtype dbvers[ion] dde deblank debug-list debugger decimals declare default
syn keyword ProgressReserved	default-noxl[ate] default-window def[ine] delete delimiter desc[ending] dict[ionary] disable discon[nect] disp[lay] distinct do dos
syn keyword ProgressReserved	down drop dynamic-cast dynamic-func[tion] dynamic-new each editing else enable encode end entry error-stat[us] escape
syn keyword ProgressReserved	etime event-procedure except exclusive[-lock] exclusive-web[-user] exists export false fetch field[s] file-info[rmation]
syn keyword ProgressReserved	fill find find-case-sensitive find-global find-next-occurrence find-prev-occurrence find-select find-wrap-around first
syn keyword ProgressReserved	first-of focus font for form[at] fram[e] frame-col frame-db frame-down frame-field frame-file frame-inde[x] frame-line
syn keyword ProgressReserved	frame-name frame-row frame-val[ue] from from-c[hars] from-p[ixels] function-call-type gateway[s] get-attr-call-type get-byte
syn keyword ProgressReserved	get-codepage[s] get-coll[ations] get-column get-error-column get-error-row get-file-name get-file-offse[t] get-key-val[ue]
syn keyword ProgressReserved	get-message-type get-row getbyte global go-on go-pend[ing] grant graphic-e[dge] group having header help hide host-byte-order if
syn keyword ProgressReserved	import in index indicator input input-o[utput] insert into is is-attr[-space] join kblabel key-code key-func[tion] key-label
syn keyword ProgressReserved	keycode keyfunc[tion] keylabel keys keyword label last last-even[t] last-key last-of lastkey ldbname leave library like
syn keyword ProgressReserved	like-sequential line-count[er] listi[ng] little-endian locked log-manager lookup machine-class map member message message-lines mouse
syn keyword ProgressReserved	mpe new next next-prompt no no-attr[-space] no-error no-f[ill] no-help no-hide no-label[s] no-lobs no-lock no-map
syn keyword ProgressReserved	no-mes[sage] no-pause no-prefe[tch] no-return-val[ue] no-undo no-val[idate] no-wait not now null num-ali[ases] num-dbs num-entries
syn keyword ProgressReserved	of off old on open opsys option or os-append os-command os-copy os-create-dir os-delete os-dir os-drive[s] os-error
syn keyword ProgressReserved	os-rename otherwise output overlay page page-bot[tom] page-num[ber] page-top param[eter] password-field pause pdbname
syn keyword ProgressReserved	persist[ent] pixels preproc[ess] privileges proc-ha[ndle] proc-st[atus] procedure-call-type process profiler program-name progress
syn keyword ProgressReserved	prompt[-for] promsgs propath provers[ion] publish put put-byte put-key-val[ue] putbyte query query-tuning quit r-index
syn keyword ProgressReserved	rcode-info[rmation] read-available read-exact-num readkey recid record-len[gth] rect[angle] release repeat reposition retain retry return
syn keyword ProgressReserved	return-val[ue] revert revoke row-created row-deleted row-modified row-unmodified run save sax-comple[te] sax-parser-error
syn keyword ProgressReserved	sax-running sax-uninitialized sax-write-begin sax-write-complete sax-write-content sax-write-element sax-write-error
syn keyword ProgressReserved	sax-write-idle sax-write-tag schema screen screen-io screen-lines scroll sdbname search search-self search-target security-policy
syn keyword ProgressReserved	seek select self session set set-attr-call-type setuser[id] share[-lock] shared show-stat[s] skip some source-procedure
syn keyword ProgressReserved	space status stream stream-handle stream-io string-xref subscribe super system-dialog table table-handle target-procedure
syn keyword ProgressReserved	term[inal] text text-cursor text-seg[-grow] then this-object this-procedure time title to today top-only trans[action] trigger
syn keyword ProgressReserved	triggers trim true underl[ine] undo unform[atted] union unique unix unless-hidden unsubscribe up update use-index use-revvideo
syn keyword ProgressReserved	use-underline user[id] using value values view view-as wait-for web-con[text] when where while window window-delayed-min[imize]
syn keyword ProgressReserved	window-maxim[ized] window-minim[ized] window-normal with work-tab[le] workfile write xcode xcode-session-key xref xref-xml yes

" Strings. Handles embedded quotes.
" Note that, for some reason, Progress doesn't use the backslash, "\"
" as the escape character; it uses tilde, "~".
syn region ProgressString matchgroup=ProgressQuote start=+"+ end=+"+ skip=+\~'\|\~\~\|\~"+ contains=@Spell
syn region ProgressString matchgroup=ProgressQuote start=+'+ end=+'+ skip=+\~'\|\~\~\|\~"+ contains=@Spell

syn match  ProgressIdentifier		"\<[a-zA-Z_][a-zA-Z0-9_]*\>()"

" syn match  ProgressDelimiter		"()"

syn match  ProgressMatrixDelimiter	"[][]"
" If you prefer you can highlight the range:
"syn match  ProgressMatrixDelimiter	"[\d\+\.\.\d\+]"

syn match  ProgressNumber		"\<\-\=\d\+\(u\=l\=\|lu\|f\)\>"
syn match  ProgressByte			"\$[0-9a-fA-F]\+"

" More values: Logicals, and Progress's unknown value, ?.
syn match   ProgressNumber				"?"
syn keyword ProgressNumber		true false yes no

" If you don't like tabs:
syn match ProgressShowTab "\t"

" If you don't like white space on the end of lines, uncomment this:
" syn match   ProgressSpaceError "\s\+$"

syn region ProgressComment		start="/\*"  end="\*/" contains=ProgressComment,ProgressTodo,ProgressDebug,@Spell
syn region ProgressInclude		start="^[ 	]*[{]" end="[}]" contains=ProgressPreProc,ProgressOperator,ProgressString,ProgressComment
syn region ProgressPreProc		start="&" end="\>" contained

" This next line works reasonably well.
" syn match ProgressOperator        "[!;|)(:.><+*=-]"
"
" Progress allows a '-' to be part of an identifier.  To be considered
" the subtraction/negation operation operator it needs a non-word
" character on either side.  Also valid are cases where the minus
" operation appears at the beginning or end of a line.
" This next line trips up on "no-undo" etc.
" syn match ProgressOperator    "[!;|)(:.><+*=]\|\W-\W\|^-\W\|\W-$"
syn match ProgressOperator      "[!;|)(:.><+*=]\|\s-\s\|^-\s\|\s-$"

syn keyword ProgressOperator	<= <> >=
syn keyword ProgressOperator	abs[olute] accelerator accept-changes accept-row-changes across active actor add-buffer add-calc-col[umn]
syn keyword ProgressOperator	add-columns-from add-events-proc[edure] add-fields-from add-first add-header-entry add-index-field add-interval add-last
syn keyword ProgressOperator	add-like-col[umn] add-like-field add-like-index add-new-field add-new-index add-rel[ation] add-schema-location add-source-buffer
syn keyword ProgressOperator	add-super-proc[edure] adm-data advise after-buffer after-rowid after-table alert-box allow-column-searching allow-replication alternate-key
syn keyword ProgressOperator	always-on-top ansi-only anywhere append append-child appl-alert[-boxes] appl-context-id application apply-callback appserver-info
syn keyword ProgressOperator	appserver-password appserver-userid array-m[essage] ask-overwrite assembly async-request-count async-request-handle attach-data-source
syn keyword ProgressOperator	attached-pairlist attach attribute-names audit-enabled audit-event-context authentication-failed auto-comp[letion] auto-delete
syn keyword ProgressOperator	auto-delete-xml auto-end-key auto-endkey auto-go auto-ind[ent] auto-resize auto-synchronize auto-val[idate] auto-z[ap] automatic
syn keyword ProgressOperator	available-formats ave[rage] avg backward[s] base-ade base-key basic-logging batch[-mode] batch-size before-buffer before-rowid
syn keyword ProgressOperator	before-table begin-event-group bgc[olor] binary bind bind-where blob block-iteration-display border-b[ottom-chars]
syn keyword ProgressOperator	border-bottom-p[ixels] border-l[eft-chars] border-left-p[ixels] border-r[ight-chars] border-right-p[ixels] border-t[op-chars]
syn keyword ProgressOperator	border-top-p[ixels] both bottom box box-select[able] browse buffer buffer-chars buffer-create buffer-delete buffer-field buffer-handle
syn keyword ProgressOperator	buffer-lines buffer-n[ame] buffer-releas[e] buffer-validate buffer-value button[s] by-reference by-value byte bytes-read
syn keyword ProgressOperator	bytes-written cache cache-size call-name call-type can-crea[te] can-dele[te] can-query can-read can-set can-writ[e] cancel-break
syn keyword ProgressOperator	cancel-button cancel-requests cancelled caps careful-paint catch cdecl chained char[acter] character_length charset checked
syn keyword ProgressOperator	child-buffer child-num choose class class-type clear-appl-context clear-log clear-select[ion] clear-sort-arrow[s]
syn keyword ProgressOperator	client-connection-id client-principal client-tty client-type client-workstation clob clone-node close close-log code codepage
syn keyword ProgressOperator	codepage-convert col-of collate colon-align[ed] color-table column-bgc[olor] column-codepage column-dcolor column-fgc[olor]
syn keyword ProgressOperator	column-font column-movable column-of column-pfc[olor] column-read-only column-resizable column-sc[rolling] com-handle combo-box
syn keyword ProgressOperator	command compare[s] compile complete config-name connect constructor contents context context-help context-help-file
syn keyword ProgressOperator	context-help-id context-pop[up] control-box control-fram[e] convert convert-to-offs[et] copy-dataset copy-sax-attributes
syn keyword ProgressOperator	copy-temp-table count cpcase cpcoll cpint[ernal] cplog cpprint cprcodein cprcodeout cpterm crc-val[ue] create-like
syn keyword ProgressOperator	create-like-sequential create-node create-node-namespace create-result-list-entry create-test-file current-column current-env[ironment]
syn keyword ProgressOperator	current-iteration current-query current-result-row current-row-modified current-value cursor-char cursor-line cursor-offset data-b[ind]
syn keyword ProgressOperator	data-entry-ret[urn] data-rel[ation] data-source data-source-complete-map data-source-modified data-source-rowid data-t[ype] date
syn keyword ProgressOperator	date-f[ormat] day db-references dcolor dde-error dde-i[d] dde-item dde-name dde-topic debu[g] debug-alert
syn keyword ProgressOperator	declare-namespace decrypt default-buffer-handle default-but[ton] default-commit default-ex[tension] default-string
syn keyword ProgressOperator	default-value define-user-event-manager defined delete-char delete-current-row delete-header-entry delete-line delete-node
syn keyword ProgressOperator	delete-result-list-entry delete-selected-row delete-selected-rows descript[ion] deselect-focused-row deselect-rows deselect-selected-row
syn keyword ProgressOperator	destructor detach-data-source dialog-box dir directory disable-auto-zap disable-connections disable-dump-triggers
syn keyword ProgressOperator	disable-load-triggers disabled display-message display-timezone display-t[ype] domain-description domain-name domain-type double
syn keyword ProgressOperator	drag-enabled drop-down drop-down-list drop-target dump dump-logging-now dynamic dynamic-current-value dynamic-next-value echo
syn keyword ProgressOperator	edge[-chars] edge-p[ixels] edit-can-paste edit-can-undo edit-clear edit-copy edit-cut edit-paste edit-undo editor empty
syn keyword ProgressOperator	empty-dataset empty-temp-table enable-connections enabled encoding encrypt encrypt-audit-mac-key encryption-salt end-document
syn keyword ProgressOperator	end-element end-event-group end-file-drop end-key end-user-prompt endkey entered entry-types-list eq error error-col[umn]
syn keyword ProgressOperator	error-object-detail error-row error-stack-trace error-string event-group-id event-procedure-context event-t[ype] events exclusive-id
syn keyword ProgressOperator	execute execution-log exp expand expandable expire explicit export-principal extended extent external extract
syn keyword ProgressOperator	fetch-selected-row fgc[olor] file file-create-d[ate] file-create-t[ime] file-mod-d[ate] file-mod-t[ime] file-name file-off[set]
syn keyword ProgressOperator	file-size file-type filename fill-in fill-mode fill-where-string filled filters final finally find-by-rowid find-current
syn keyword ProgressOperator	find-first find-last find-unique finder first-async[-request] first-buffer first-child first-column first-data-source
syn keyword ProgressOperator	first-dataset first-form first-object first-proc[edure] first-query first-serv[er] first-server-socket first-socket
syn keyword ProgressOperator	first-tab-i[tem] fit-last-column fix-codepage fixed-only flat-button float focused-row focused-row-selected font-table force-file
syn keyword ProgressOperator	fore[ground] foreign-key-hidden form-input form-long-input formatte[d] forward-only forward[s] fragmen[t] frame-spa[cing] frame-x
syn keyword ProgressOperator	frame-y frequency from-cur[rent] full-height[-chars] full-height-p[ixels] full-pathn[ame] full-width[-chars]
syn keyword ProgressOperator	full-width-p[ixels] function ge generate-pbe-key generate-pbe-salt generate-random-key generate-uuid get get-attribute get-attribute-node
syn keyword ProgressOperator	get-binary-data get-bits get-blue[-value] get-browse-col[umn] get-buffer-handle get-byte-order get-bytes get-bytes-available
syn keyword ProgressOperator	get-callback-proc-context get-callback-proc-name get-cgi-list get-cgi-long-value get-cgi-value get-changes get-child get-child-rel[ation]
syn keyword ProgressOperator	get-config-value get-curr[ent] get-dataset-buffer get-dir get-document-element get-double get-dropped-file get-dynamic get-file
syn keyword ProgressOperator	get-firs[t] get-float get-green[-value] get-header-entr[y] get-index-by-namespace-name get-index-by-qname get-iteration get-last
syn keyword ProgressOperator	get-localname-by-index get-long get-message get-next get-node get-number get-parent get-pointer-value get-prev get-printers get-property
syn keyword ProgressOperator	get-qname-by-index get-red[-value] get-rel[ation] get-repositioned-row get-rgb[-value] get-selected[-widget] get-serialized get-short
syn keyword ProgressOperator	get-signature get-size get-socket-option get-source-buffer get-string get-tab-item get-text-height[-chars] get-text-height-p[ixels]
syn keyword ProgressOperator	get-text-width[-chars] get-text-width-p[ixels] get-top-buffer get-type-by-index get-type-by-namespace-name get-type-by-qname
syn keyword ProgressOperator	get-unsigned-long get-unsigned-short get-uri-by-index get-value-by-index get-value-by-namespace-name get-value-by-qname
syn keyword ProgressOperator	get-wait[-state] grayed grid-factor-h[orizontal] grid-factor-v[ertical] grid-snap grid-unit-height[-chars] grid-unit-height-p[ixels]
syn keyword ProgressOperator	grid-unit-width[-chars] grid-unit-width-p[ixels] grid-visible group-box gt guid handle handler has-lobs has-records height[-chars]
syn keyword ProgressOperator	height-p[ixels] help-topic hex-decode hex-encode hidden hint hori[zontal] html-charset html-end-of-line html-end-of-page
syn keyword ProgressOperator	html-frame-begin html-frame-end html-header-begin html-header-end html-title-begin html-title-end hwnd icfparam[eter] icon
syn keyword ProgressOperator	ignore-current-mod[ified] image image-down image-insensitive image-size image-size-c[hars] image-size-p[ixels] image-up immediate-display
syn keyword ProgressOperator	implements import-node import-principal in-handle increment-exclusive-id index-hint index-info[rmation] indexed-reposition
syn keyword ProgressOperator	info[rmation] inherit-bgc[olor] inherit-fgc[olor] inherits init[ial] initial-dir initial-filter initialize-document-type initiate
syn keyword ProgressOperator	inner inner-chars inner-lines input-value insert-attribute insert-b[acktab] insert-before insert-file insert-row
syn keyword ProgressOperator	insert-string insert-t[ab] instantiating-procedure int[eger] interface internal-entries interval invoke is-clas[s]
syn keyword ProgressOperator	is-codepage-fixed is-column-codepage is-lead-byte is-open is-parameter-set is-row-selected is-selected is-xml iso-date item
syn keyword ProgressOperator	items-per-row join-by-sqldb keep-connection-open keep-frame-z[-order] keep-messages keep-security-cache keep-tab-order key
syn keyword ProgressOperator	keyword-all label-bgc[olor] label-dc[olor] label-fgc[olor] label-font label-pfc[olor] labels landscape language[s] large
syn keyword ProgressOperator	large-to-small last-async[-request] last-batch last-child last-form last-object last-proce[dure] last-serv[er] last-server-socket
syn keyword ProgressOperator	last-socket last-tab-i[tem] lc le leading left left-align[ed] left-trim length line list-events list-item-pairs list-items
syn keyword ProgressOperator	list-property-names list-query-attrs list-set-attrs list-widgets literal-question load load-domains load-icon load-image load-image-down
syn keyword ProgressOperator	load-image-insensitive load-image-up load-mouse-p[ointer] load-picture load-small-icon lob-dir local-host local-name local-port
syn keyword ProgressOperator	locator-column-number locator-line-number locator-public-id locator-system-id locator-type lock-registration log log-audit-event
syn keyword ProgressOperator	log-entry-types log-threshold logfile-name logging-level logical login-expiration-timestamp login-host login-state logout long[char]
syn keyword ProgressOperator	longchar-to-node-value lookahead lower lt mandatory manual-highlight margin-extra margin-height[-chars] margin-height-p[ixels]
syn keyword ProgressOperator	margin-width[-chars] margin-width-p[ixels] mark-new mark-row-state matches max-button max-chars max-data-guess max-height[-chars]
syn keyword ProgressOperator	max-height-p[ixels] max-rows max-size max-val[ue] max-width[-chars] max-width-p[ixels] maximize max[imum] maximum-level memory memptr
syn keyword ProgressOperator	memptr-to-node-value menu menu-bar menu-item menu-k[ey] menu-m[ouse] menubar merge-by-field merge-changes merge-row-changes message-area
syn keyword ProgressOperator	message-area-font method min-button min-column-width-c[hars] min-column-width-p[ixels] min-height[-chars] min-height-p[ixels]
syn keyword ProgressOperator	min-schema-marshal min-size min-val[ue] min-width[-chars] min-width-p[ixels] min[imum] modified mod[ulo] month mouse-p[ointer] movable
syn keyword ProgressOperator	move-after[-tab-item] move-befor[e-tab-item] move-col[umn] move-to-b[ottom] move-to-eof move-to-t[op] mtime multi-compile multiple
syn keyword ProgressOperator	multiple-key multitasking-interval must-exist must-understand name namespace-prefix namespace-uri native ne needs-appserver-prompt
syn keyword ProgressOperator	needs-prompt nested new-instance new-row next-col[umn] next-rowid next-sibling next-tab-ite[m] next-value no-apply
syn keyword ProgressOperator	no-array-m[essage] no-assign no-attr-l[ist] no-auto-validate no-bind-where no-box no-console no-convert no-current-value no-debug
syn keyword ProgressOperator	no-drag no-echo no-empty-space no-focus no-index-hint no-inherit-bgc[olor] no-inherit-fgc[olor] no-join-by-sqldb no-lookahead
syn keyword ProgressOperator	no-row-markers no-schema-marshal no-scrollbar-v[ertical] no-separate-connection no-separators no-tab[-stop] no-und[erline]
syn keyword ProgressOperator	no-word-wrap node-value node-value-to-longchar node-value-to-memptr nonamespace-schema-location none normalize not-active
syn keyword ProgressOperator	num-buffers num-but[tons] num-child-relations num-children num-col[umns] num-copies num-dropped-files num-fields num-formats
syn keyword ProgressOperator	num-header-entries num-items num-iterations num-lines num-locked-col[umns] num-log-files num-messages num-parameters num-references
syn keyword ProgressOperator	num-relations num-repl[aced] num-results num-selected-rows num-selected[-widgets] num-source-buffers num-tabs num-to-retain
syn keyword ProgressOperator	num-top-buffers num-visible-col[umns] numeric numeric-dec[imal-point] numeric-f[ormat] numeric-sep[arator] object ok ok-cancel
syn keyword ProgressOperator	on-frame[-border] ordered-join ordinal orientation origin-handle origin-rowid os-getenv outer outer-join override owner owner-document
syn keyword ProgressOperator	page-size page-wid[th] paged parent parent-buffer parent-rel[ation] parse-status partial-key pascal pathname
syn keyword ProgressOperator	pbe-hash-alg[orithm] pbe-key-rounds perf[ormance] persistent-cache-disabled persistent-procedure pfc[olor] pixels-per-col[umn]
syn keyword ProgressOperator	pixels-per-row popup-m[enu] popup-o[nly] portrait position precision prefer-dataset prepare-string prepared presel[ect] prev
syn keyword ProgressOperator	prev-col[umn] prev-sibling prev-tab-i[tem] primary printer printer-control-handle printer-hdc printer-name printer-port
syn keyword ProgressOperator	printer-setup private private-d[ata] proce[dure] procedure-name progress-s[ource] property protected proxy proxy-password
syn keyword ProgressOperator	proxy-userid public public-id published-events put-bits put-bytes put-double put-float put-long put-short put-string
syn keyword ProgressOperator	put-unsigned-long put-unsigned-short query-close query-off-end query-open query-prepare question quoter radio-buttons radio-set random
syn keyword ProgressOperator	raw raw-transfer read read-file read-only read-xml read-xmlschema real recursive reference-only refresh
syn keyword ProgressOperator	refresh-audit-policy refreshable register-domain reject-changes reject-row-changes rejected relation-fi[elds] relations-active remote
syn keyword ProgressOperator	remote-host remote-port remove-attribute remove-child remove-events-proc[edure] remove-super-proc[edure] replace replace-child
syn keyword ProgressOperator	replace-selection-text replication-create replication-delete replication-write reposition-back[ward] reposition-forw[ard] reposition-to-row
syn keyword ProgressOperator	reposition-to-rowid request reset resiza[ble] resize restart-row restart-rowid result retain-s[hape] retry-cancel return-ins[erted]
syn keyword ProgressOperator	return-to-start-di[r] return-value-data-type returns reverse-from rgb-v[alue] right right-align[ed] right-trim roles round rounded
syn keyword ProgressOperator	routine-level row row-height[-chars] row-height-p[ixels] row-ma[rkers] row-of row-resizable row-state rowid rule run-proc[edure]
syn keyword ProgressOperator	save-as save-file save-row-changes save-where-string sax-attributes sax-parse sax-parse-first sax-parse-next sax-reader
syn keyword ProgressOperator	sax-writer schema-change schema-location schema-marshal schema-path screen-val[ue] scroll-bars scroll-delta scroll-offset
syn keyword ProgressOperator	scroll-to-current-row scroll-to-i[tem] scroll-to-selected-row scrollable scrollbar-h[orizontal] scrollbar-v[ertical]
syn keyword ProgressOperator	scrolled-row-pos[ition] scrolling seal seal-timestamp section select-all select-focused-row select-next-row select-prev-row select-row
syn keyword ProgressOperator	selectable selected selection-end selection-list selection-start selection-text send sensitive separate-connection
syn keyword ProgressOperator	separator-fgc[olor] separators server server-connection-bo[und] server-connection-bound-re[quest] server-connection-co[ntext]
syn keyword ProgressOperator	server-connection-id server-operating-mode server-socket session-end session-id set-actor set-appl-context set-attribute
syn keyword ProgressOperator	set-attribute-node set-blue[-value] set-break set-buffers set-byte-order set-callback set-callback-procedure set-client set-commit
syn keyword ProgressOperator	set-connect-procedure set-contents set-db-client set-dynamic set-green[-value] set-input-source set-must-understand set-node
syn keyword ProgressOperator	set-numeric-form[at] set-option set-output-destination set-parameter set-pointer-val[ue] set-property set-read-response-procedure
syn keyword ProgressOperator	set-red[-value] set-repositioned-row set-rgb[-value] set-rollback set-selection set-serialized set-size set-socket-option
syn keyword ProgressOperator	set-sort-arrow set-wait[-state] short show-in-task[bar] side-label-h[andle] side-lab[els] silent simple single single-character size
syn keyword ProgressOperator	size-c[hars] size-p[ixels] skip-deleted-rec[ord] slider small-icon small-title smallint soap-fault soap-fault-actor
syn keyword ProgressOperator	soap-fault-code soap-fault-detail soap-fault-string soap-header soap-header-entryref socket sort sort-ascending sort-number source
syn keyword ProgressOperator	sql sqrt ssl-server-name standalone start-document start-element start[ing] startup-parameters state-detail static
syn keyword ProgressOperator	status-area status-area-font stdcall stop stop-parsing stoppe[d] stored-proc[edure] stretch-to-fit strict string string-value
syn keyword ProgressOperator	sub-ave[rage] sub-count sub-max[imum] sub-menu sub-menu-help sub-min[imum] sub-total subst[itute] substr[ing] subtype sum
syn keyword ProgressOperator	super-proc[edures] suppress-namespace-processing suppress-w[arnings] suspend symmetric-encryption-algorithm symmetric-encryption-iv
syn keyword ProgressOperator	symmetric-encryption-key symmetric-support synchronize system-alert[-boxes] system-help system-id tab-position tab-stop table-crc-list
syn keyword ProgressOperator	table-list table-num[ber] target temp-dir[ectory] temp-table temp-table-prepar[e] terminate text-selected three-d through throw
syn keyword ProgressOperator	thru tic-marks time-source timezone title-bgc[olor] title-dc[olor] title-fgc[olor] title-fo[nt] to-rowid toggle-box
syn keyword ProgressOperator	tooltip tooltips top top-nav-query topic total tracking-changes trailing trans-init-proc[edure] transaction-mode
syn keyword ProgressOperator	transpar[ent] trunc[ate] ttcodepage type type-of unbox unbuff[ered] unique-id unique-match unload unsigned-byte unsigned-integer
syn keyword ProgressOperator	unsigned-long unsigned-short update-attribute upper url url-decode url-encode url-password url-userid use use-dic[t-exps]
syn keyword ProgressOperator	use-filename use-text use-widget-pool user-id valid-event valid-handle valid-object validate validate-expressio[n]
syn keyword ProgressOperator	validate-message validate-seal validate-xml validation-enabled var[iable] verb[ose] version vert[ical] view-first-column-on-reopen
syn keyword ProgressOperator	virtual-height[-chars] virtual-height-p[ixels] virtual-width[-chars] virtual-width-p[ixels] visible void wait warning weekday where-string
syn keyword ProgressOperator	widget widget-e[nter] widget-h[andle] widget-id widget-l[eave] widget-pool width[-chars] width-p[ixels] window-name
syn keyword ProgressOperator	window-sta[te] window-sys[tem] word-index word-wrap work-area-height-p[ixels] work-area-width-p[ixels] work-area-x work-area-y
syn keyword ProgressOperator	write-cdata write-characters write-comment write-data-element write-empty-element write-entity-ref write-external-dtd
syn keyword ProgressOperator	write-fragment write-message write-processing-instruction write-status write-xml write-xmlschema x x-document x-noderef x-of
syn keyword ProgressOperator	xml-data-type xml-node-name xml-node-type xml-schema-pat[h] xml-suppress-namespace-processing y y-of year year-offset yes-no
syn keyword ProgressOperator	yes-no-cancel

syn keyword ProgressType	char[acter] int[eger] int64 dec[imal] log[ical] da[te] datetime datetime-tz

syn sync lines=800

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

" The default methods for highlighting. Can be overridden later.
hi def link ProgressByte		Number
hi def link ProgressCase		Repeat
hi def link ProgressComment		Comment
hi def link ProgressConditional	Conditional
hi def link ProgressDebug		Debug
hi def link ProgressDo		Repeat
hi def link ProgressEndError		Error
hi def link ProgressFor		Repeat
hi def link ProgressFunction		Procedure
hi def link ProgressIdentifier	Identifier
hi def link ProgressInclude		Include
hi def link ProgressMatrixDelimiter	Identifier
hi def link ProgressNumber		Number
hi def link ProgressOperator		Operator
hi def link ProgressPreProc		PreProc
hi def link ProgressProcedure	Procedure
hi def link ProgressQuote		Delimiter
hi def link ProgressRepeat		Repeat
hi def link ProgressReserved		Statement
hi def link ProgressSpaceError	Error
hi def link ProgressString		String
hi def link ProgressTodo		Todo
hi def link ProgressType		Statement
hi def link ProgressShowTab		Error


let b:current_syntax = "progress"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 sw=8
