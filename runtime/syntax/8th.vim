" Vim syntax file
" Language:     8th
" Version:      25.04.01
" Last Change:  2025 Jun 10
" Maintainer:   Ron Aaron <ron@aaron-tech.com>
" URL:          https://8th-dev.com/
" Filetypes:    *.8th
" NOTE:         You should also have the ftplugin/8th.vim file to set 'isk'

if exists("b:current_syntax")
   finish
endif

let s:cpo_save = &cpo
set cpo&vim
syn clear

syn sync ccomment 
syn sync maxlines=200

syn case match
syn iskeyword 33-255

syn match eighthColonName "\S\+" contained
syn match eighthColonDef ":\s\+\S\+" contains=eighthColonName

" new words
syn match eighthClasses "\<\S\+:" contained
syn match eighthClassWord "\<\S\+:.\+" contains=eighthClasses

syn keyword eighthEndOfColonDef ; i;
syn keyword eighthDefine var var,

" Built in words:
com! -nargs=+ Builtin syn keyword eighthBuiltin <args>


Builtin  gen-secret 2fa:gen-secret gen-url 2fa:gen-url validate-code 2fa:validate-code cb AWS:cb cli AWS:cli
Builtin  cmd AWS:cmd cp AWS:cp rc AWS:rc LIBS DBUS:LIBS call DBUS:call init DBUS:init + DOM:+ - DOM:-
Builtin  attr! DOM:attr! attr@ DOM:attr@ attrs DOM:attrs children DOM:children css-parse DOM:css-parse
Builtin  each DOM:each find DOM:find new DOM:new type DOM:type ! G:! !if G:!if #! G:#! ## G:## #if G:#if
Builtin  #ifdef G:#ifdef #ifeval G:#ifeval ' G:' ( G:( (:) G:(:) (code) G:(code) (defer) G:(defer) (dump) G:(dump)
Builtin  (getc) G:(getc) (gets) G:(gets) (interp) G:(interp) (log) G:(log) (needs) G:(needs) (parseln) G:(parseln)
Builtin  (putc) G:(putc) (puts) G:(puts) (stat) G:(stat) (with) G:(with) ) G:) +hook G:+hook +ref G:+ref
Builtin  ,# G:,# -----BEGIN G:-----BEGIN -Inf G:-Inf -Inf? G:-Inf? -hook G:-hook -ref G:-ref -rot G:-rot
Builtin  . G:. .# G:.# .hook G:.hook .needs G:.needs .r G:.r .s G:.s .s-truncate G:.s-truncate .stats G:.stats
Builtin  .ver G:.ver .with G:.with 0; G:0; 2dip G:2dip 2drop G:2drop 2dup G:2dup 2nip G:2nip 2over G:2over
Builtin  2swap G:2swap 2tuck G:2tuck 3drop G:3drop 3dup G:3dup 3rev G:3rev 4drop G:4drop 8thdt? G:8thdt?
Builtin  8thsku? G:8thsku? 8thver? G:8thver? 8thvernum? G:8thvernum? : G:: ; G:; ;; G:;; ;;; G:;;; ;with G:;with
Builtin  >clip G:>clip >clip-mime G:>clip-mime >json G:>json >kind G:>kind >n G:>n >r G:>r >s G:>s ?: G:?:
Builtin  ?@ G:?@ @ G:@ BITMAP: G:BITMAP: ENUM: G:ENUM: FLAG: G:FLAG: I G:I Inf G:Inf Inf? G:Inf? J G:J
Builtin  K G:K NaN G:NaN NaN? G:NaN? SED-CHECK G:SED-CHECK SED: G:SED: SED: G:SED: X G:X \ G:\ _dup G:_dup
Builtin  _swap G:_swap actor: G:actor: again G:again ahead G:ahead all-words G:all-words and G:and apropos G:apropos
Builtin  argc G:argc args G:args array? G:array? assert G:assert base G:base base>n G:base>n bi G:bi
Builtin  bits G:bits break G:break break? G:break? breakif G:breakif build? G:build? buildver? G:buildver?
Builtin  bye G:bye c/does G:c/does case: G:case: catch G:catch chdir G:chdir clip-mime> G:clip-mime>
Builtin  clip-mime? G:clip-mime? clip> G:clip> clone G:clone clone-shallow G:clone-shallow cold G:cold
Builtin  compile G:compile compile? G:compile? compiling? G:compiling? conflict G:conflict const G:const
Builtin  container? G:container? counting-allocations G:counting-allocations cr G:cr critical: G:critical:
Builtin  critical; G:critical; curlang G:curlang curry G:curry curry: G:curry: decimal G:decimal default: G:default:
Builtin  defer: G:defer: deferred: G:deferred: deg>rad G:deg>rad depth G:depth die G:die dip G:dip drop G:drop
Builtin  dstack G:dstack dump G:dump dup G:dup dup>r G:dup>r dup? G:dup? e# G:e# enum: G:enum: error? G:error?
Builtin  eval G:eval eval! G:eval! eval0 G:eval0 exit G:exit expect G:expect extra! G:extra! extra@ G:extra@
Builtin  false G:false fnv G:fnv fourth G:fourth free G:free func: G:func: getc G:getc getcwd G:getcwd
Builtin  getenv G:getenv gets G:gets goto G:goto handler G:handler header G:header help G:help help_db G:help_db
Builtin  here G:here hex G:hex i: G:i: i; G:i; immutable G:immutable isa? G:isa? items-used G:items-used
Builtin  jcall G:jcall jclass G:jclass jmethod G:jmethod json! G:json! json-8th> G:json-8th> json-nesting G:json-nesting
Builtin  json-pretty G:json-pretty json-throw G:json-throw json> G:json> json@ G:json@ k32 G:k32 keep G:keep
Builtin  l: G:l: last G:last lib G:lib libbin G:libbin libc G:libc libimg G:libimg literal G:literal
Builtin  locals: G:locals: lock G:lock lock-to G:lock-to locked? G:locked? log G:log logl G:logl long-days G:long-days
Builtin  long-months G:long-months longjmp G:longjmp lookup G:lookup loop G:loop loop- G:loop- map? G:map?
Builtin  mark G:mark mark? G:mark? mobile? G:mobile? n# G:n# name>os G:name>os name>sem G:name>sem ndrop G:ndrop
Builtin  needs G:needs needs-throws G:needs-throws new G:new next-arg G:next-arg nip G:nip noop G:noop
Builtin  not G:not nothrow G:nothrow ns G:ns ns: G:ns: ns>ls G:ns>ls ns>s G:ns>s ns? G:ns? null G:null
Builtin  null; G:null; null? G:null? nullvar G:nullvar number? G:number? of: G:of: off G:off on G:on
Builtin  onexit G:onexit only G:only op! G:op! or G:or os G:os os-names G:os-names os>long-name G:os>long-name
Builtin  os>name G:os>name over G:over p: G:p: pack G:pack parse G:parse parse-csv G:parse-csv parse-date G:parse-date
Builtin  parsech G:parsech parseln G:parseln parsews G:parsews pick G:pick poke G:poke pool-clear G:pool-clear
Builtin  pool-clear-all G:pool-clear-all prior G:prior private G:private process-args G:process-args
Builtin  process-args-fancy G:process-args-fancy process-args-help G:process-args-help prompt G:prompt
Builtin  public G:public putc G:putc puts G:puts quote G:quote r! G:r! r> G:r> r@ G:r@ rad>deg G:rad>deg
Builtin  rand-float G:rand-float rand-float-signed G:rand-float-signed rand-jit G:rand-jit rand-jsf G:rand-jsf
Builtin  rand-native G:rand-native rand-normal G:rand-normal rand-pcg G:rand-pcg rand-pcg-seed G:rand-pcg-seed
Builtin  rand-range G:rand-range rand-select G:rand-select randbuf-pcg G:randbuf-pcg random G:random
Builtin  rdrop G:rdrop recurse G:recurse recurse-stack G:recurse-stack ref@ G:ref@ reg! G:reg! reg@ G:reg@
Builtin  regbin@ G:regbin@ remaining-args G:remaining-args repeat G:repeat requires G:requires reset G:reset
Builtin  roll G:roll rop! G:rop! rot G:rot rpick G:rpick rreset G:rreset rroll G:rroll rstack G:rstack
Builtin  rswap G:rswap rusage G:rusage s>ns G:s>ns same? G:same? scriptdir G:scriptdir scriptfile G:scriptfile
Builtin  sem G:sem sem-post G:sem-post sem-rm G:sem-rm sem-wait G:sem-wait sem-wait? G:sem-wait? sem>name G:sem>name
Builtin  semi-throw G:semi-throw set-wipe G:set-wipe setenv G:setenv setjmp G:setjmp settings! G:settings!
Builtin  settings![] G:settings![] settings-clear G:settings-clear settings-db-name G:settings-db-name
Builtin  settings-gather G:settings-gather settings-load G:settings-load settings-save G:settings-save
Builtin  settings-save-these G:settings-save-these settings-ungather G:settings-ungather settings@ G:settings@
Builtin  settings@? G:settings@? settings@[] G:settings@[] sh G:sh sh! G:sh! sh!to G:sh!to sh$ G:sh$
Builtin  short-days G:short-days short-months G:short-months sleep G:sleep sleep-msec G:sleep-msec sleep-nsec G:sleep-nsec
Builtin  sleep-until G:sleep-until slog G:slog space G:space stack-check G:stack-check stack-size G:stack-size
Builtin  step G:step sthrow G:sthrow string? G:string? struct: G:struct: swap G:swap tab-hook G:tab-hook
Builtin  tell-conflict G:tell-conflict tempdir G:tempdir tempfilename G:tempfilename third G:third throw G:throw
Builtin  thrownull G:thrownull times G:times toggle G:toggle tri G:tri true G:true tuck G:tuck type-check G:type-check
Builtin  typeassert G:typeassert uid G:uid uname G:uname unlock G:unlock unpack G:unpack until G:until
Builtin  until! G:until! while G:while while! G:while! with: G:with: word? G:word? words G:words words-like G:words-like
Builtin  words/ G:words/ xchg G:xchg xor G:xor >auth HTTP:>auth (curry) I:(curry) appopts I:appopts
Builtin  notimpl I:notimpl sh I:sh call JSONRPC:call auth-string OAuth:auth-string gen-nonce OAuth:gen-nonce
Builtin  params OAuth:params call SOAP:call ! a:! + a:+ - a:- / a:/ 2each a:2each 2len a:2len 2map a:2map
Builtin  2map+ a:2map+ 2map= a:2map= <> a:<> = a:= @ a:@ @? a:@? _@ a:_@ _len a:_len _push a:_push all a:all
Builtin  any a:any bsearch a:bsearch centroid a:centroid clear a:clear close a:close cmp a:cmp diff a:diff
Builtin  dot a:dot each a:each each! a:each! each-par a:each-par each-slice a:each-slice exists? a:exists?
Builtin  filter a:filter filter-par a:filter-par generate a:generate group a:group indexof a:indexof
Builtin  insert a:insert intersect a:intersect join a:join len a:len map a:map map+ a:map+ map-par a:map-par
Builtin  map= a:map= maxlen a:maxlen mean a:mean mean&variance a:mean&variance merge a:merge new a:new
Builtin  op! a:op! open a:open pigeon a:pigeon pivot a:pivot pop a:pop push a:push qsort a:qsort randeach a:randeach
Builtin  reduce a:reduce reduce+ a:reduce+ remove a:remove rev a:rev rindexof a:rindexof shift a:shift
Builtin  shuffle a:shuffle slice a:slice slice+ a:slice+ slide a:slide smear a:smear sort a:sort split a:split
Builtin  squash a:squash switch a:switch union a:union uniq a:uniq unzip a:unzip x a:x x-each a:x-each
Builtin  xchg a:xchg y a:y zip a:zip 8thdir app:8thdir asset app:asset atrun app:atrun atrun app:atrun
Builtin  atrun app:atrun basedir app:basedir basename app:basename config-file-name app:config-file-name
Builtin  current app:current datadir app:datadir display-moved app:display-moved exename app:exename
Builtin  localechanged app:localechanged lowmem app:lowmem main app:main meta! app:meta! meta@ app:meta@
Builtin  name app:name onback app:onback oncrash app:oncrash opts! app:opts! opts@ app:opts@ orientation app:orientation
Builtin  orientation! app:orientation! pid app:pid post-main app:post-main pre-main app:pre-main privdir app:privdir
Builtin  quiet? app:quiet? raise app:raise read-config app:read-config read-config-map app:read-config-map
Builtin  read-config-var app:read-config-var request-perm app:request-perm restart app:restart resumed app:resumed
Builtin  signal app:signal standalone app:standalone standalone! app:standalone! subdir app:subdir suspended app:suspended
Builtin  sysquit app:sysquit terminated app:terminated theme? app:theme? themechanged app:themechanged
Builtin  ticks app:ticks timeout app:timeout trap app:trap dawn astro:dawn do-dawn astro:do-dawn do-dusk astro:do-dusk
Builtin  do-rise astro:do-rise dst! astro:dst! dusk astro:dusk latitude astro:latitude location! astro:location!
Builtin  longitude astro:longitude sunrise astro:sunrise genkeys auth:genkeys secret auth:secret session-id auth:session-id
Builtin  session-key auth:session-key validate auth:validate ! b:! + b:+ / b:/ 1+ b:1+ 1- b:1- <> b:<>
Builtin  = b:= >base16 b:>base16 >base32 b:>base32 >base64 b:>base64 >base85 b:>base85 >hex b:>hex >mpack b:>mpack
Builtin  @ b:@ ICONVLIBS b:ICONVLIBS append b:append base16> b:base16> base32> b:base32> base64> b:base64>
Builtin  base85> b:base85> bit! b:bit! bit@ b:bit@ clear b:clear compress b:compress conv b:conv each b:each
Builtin  each! b:each! each-slice b:each-slice expand b:expand fill b:fill getb b:getb hex> b:hex> len b:len
Builtin  mem> b:mem> move b:move mpack-compat b:mpack-compat mpack-date b:mpack-date mpack-ignore b:mpack-ignore
Builtin  mpack> b:mpack> n! b:n! n+ b:n+ n@ b:n@ new b:new op b:op op! b:op! pad b:pad rev b:rev search b:search
Builtin  shmem b:shmem slice b:slice splice b:splice ungetb b:ungetb unpad b:unpad writable b:writable
Builtin  xor b:xor +block bc:+block .blocks bc:.blocks add-block bc:add-block block-hash bc:block-hash
Builtin  block@ bc:block@ first-block bc:first-block hash bc:hash last-block bc:last-block load bc:load
Builtin  new bc:new save bc:save set-sql bc:set-sql validate bc:validate validate-block bc:validate-block
Builtin  add bloom:add filter bloom:filter in? bloom:in? parse bson:parse LIBS bt:LIBS accept bt:accept
Builtin  ch! bt:ch! ch@ bt:ch@ connect bt:connect disconnect bt:disconnect init bt:init leconnect bt:leconnect
Builtin  lescan bt:lescan listen bt:listen on? bt:on? read bt:read scan bt:scan service? bt:service?
Builtin  services? bt:services? write bt:write * c:* * c:* + c:+ + c:+ = c:= = c:= >polar c:>polar >polar c:>polar
Builtin  >ri c:>ri >ri c:>ri ^ c:^ ^ c:^ abs c:abs abs c:abs arg c:arg arg c:arg conj c:conj conj c:conj
Builtin  im c:im im c:im log c:log log c:log n> c:n> n> c:n> new c:new new c:new polar> c:polar> polar> c:polar>
Builtin  re c:re re c:re (.hebrew) cal:(.hebrew) (.islamic) cal:(.islamic) .hebrew cal:.hebrew .islamic cal:.islamic
Builtin  >hebepoch cal:>hebepoch >jdn cal:>jdn Adar cal:Adar Adar2 cal:Adar2 Av cal:Av Elul cal:Elul
Builtin  Heshvan cal:Heshvan Iyar cal:Iyar Kislev cal:Kislev Nissan cal:Nissan Shevat cal:Shevat Sivan cal:Sivan
Builtin  Tammuz cal:Tammuz Tevet cal:Tevet Tishrei cal:Tishrei d>iso cal:d>iso d>week cal:d>week days-in-hebrew-year cal:days-in-hebrew-year
Builtin  displaying-hebrew cal:displaying-hebrew fixed>hebrew cal:fixed>hebrew fixed>islamic cal:fixed>islamic
Builtin  gershayim cal:gershayim hanukkah cal:hanukkah hebrew-epoch cal:hebrew-epoch hebrew-leap-year? cal:hebrew-leap-year?
Builtin  hebrew-leap-year? cal:hebrew-leap-year? hebrew>fixed cal:hebrew>fixed hebrewtoday cal:hebrewtoday
Builtin  hmonth-name cal:hmonth-name islamic.epoch cal:islamic.epoch islamic>fixed cal:islamic>fixed
Builtin  islamictoday cal:islamictoday iso>d cal:iso>d jdn> cal:jdn> last-day-of-hebrew-month cal:last-day-of-hebrew-month
Builtin  number>hebrew cal:number>hebrew omer cal:omer pesach cal:pesach purim cal:purim rosh-chodesh? cal:rosh-chodesh?
Builtin  rosh-hashanah cal:rosh-hashanah shavuot cal:shavuot taanit-esther cal:taanit-esther tisha-beav cal:tisha-beav
Builtin  week>d cal:week>d yom-haatsmaut cal:yom-haatsmaut yom-kippur cal:yom-kippur >hsva clr:>hsva
Builtin  complement clr:complement dist clr:dist gradient clr:gradient hsva> clr:hsva> invert clr:invert
Builtin  names clr:names nearest-name clr:nearest-name parse clr:parse >redir con:>redir accept con:accept
Builtin  accept-nl con:accept-nl accept-pwd con:accept-pwd alert con:alert ansi? con:ansi? black con:black
Builtin  blue con:blue clreol con:clreol cls con:cls ctrld-empty con:ctrld-empty cyan con:cyan down con:down
Builtin  file>history con:file>history free con:free getxy con:getxy gotoxy con:gotoxy green con:green
Builtin  history-handler con:history-handler history>file con:history>file init con:init key con:key
Builtin  key? con:key? left con:left load-history con:load-history magenta con:magenta max-history con:max-history
Builtin  onBlack con:onBlack onBlue con:onBlue onCyan con:onCyan onGreen con:onGreen onMagenta con:onMagenta
Builtin  onRed con:onRed onWhite con:onWhite onYellow con:onYellow print con:print red con:red redir> con:redir>
Builtin  redir? con:redir? right con:right save-history con:save-history size? con:size? up con:up white con:white
Builtin  yellow con:yellow >aes128gcm cr:>aes128gcm >aes256gcm cr:>aes256gcm >cp cr:>cp >cpe cr:>cpe
Builtin  >decrypt cr:>decrypt >edbox cr:>edbox >encrypt cr:>encrypt >nbuf cr:>nbuf >rsabox cr:>rsabox
Builtin  >uuid cr:>uuid aad? cr:aad? aes128box-sig cr:aes128box-sig aes128gcm> cr:aes128gcm> aes256box-sig cr:aes256box-sig
Builtin  aes256gcm> cr:aes256gcm> aesgcm cr:aesgcm blakehash cr:blakehash chacha20box-sig cr:chacha20box-sig
Builtin  chachapoly cr:chachapoly cipher! cr:cipher! cipher@ cr:cipher@ ciphers cr:ciphers cp> cr:cp>
Builtin  cpe> cr:cpe> decrypt cr:decrypt decrypt+ cr:decrypt+ decrypt> cr:decrypt> ebox-sig cr:ebox-sig
Builtin  ecc-curves cr:ecc-curves ecc-genkey cr:ecc-genkey ecc-secret cr:ecc-secret ecc-sign cr:ecc-sign
Builtin  ecc-verify cr:ecc-verify ed25519 cr:ed25519 ed25519-secret cr:ed25519-secret ed25519-sign cr:ed25519-sign
Builtin  ed25519-verify cr:ed25519-verify edbox-sig cr:edbox-sig edbox> cr:edbox> encrypt cr:encrypt
Builtin  encrypt+ cr:encrypt+ encrypt> cr:encrypt> ensurekey cr:ensurekey genkey cr:genkey hash cr:hash
Builtin  hash! cr:hash! hash+ cr:hash+ hash>b cr:hash>b hash>s cr:hash>s hash@ cr:hash@ hashes cr:hashes
Builtin  hmac cr:hmac hotp cr:hotp iv? cr:iv? pem-read cr:pem-read pem-write cr:pem-write pwd-valid? cr:pwd-valid?
Builtin  pwd/ cr:pwd/ pwd>hash cr:pwd>hash rand cr:rand randbuf cr:randbuf randkey cr:randkey random-salt cr:random-salt
Builtin  restore cr:restore root-certs cr:root-certs rsa_decrypt cr:rsa_decrypt rsa_encrypt cr:rsa_encrypt
Builtin  rsa_sign cr:rsa_sign rsa_verify cr:rsa_verify rsabox-sig cr:rsabox-sig rsabox> cr:rsabox> rsagenkey cr:rsagenkey
Builtin  save cr:save sbox-sig cr:sbox-sig sha1-hmac cr:sha1-hmac shard cr:shard tag? cr:tag? totp cr:totp
Builtin  totp-epoch cr:totp-epoch totp-time-step cr:totp-time-step unshard cr:unshard uuid cr:uuid uuid> cr:uuid>
Builtin  validate-pgp-sig cr:validate-pgp-sig validate-pwd cr:validate-pwd (.time) d:(.time) + d:+ +day d:+day
Builtin  +hour d:+hour +min d:+min +msec d:+msec - d:- .time d:.time / d:/ = d:= >fixed d:>fixed >hmds d:>hmds
Builtin  >hmds: d:>hmds: >msec d:>msec >unix d:>unix >ymd d:>ymd ?= d:?= Fri d:Fri Mon d:Mon Sat d:Sat
Builtin  Sun d:Sun Thu d:Thu Tue d:Tue Wed d:Wed adjust-dst d:adjust-dst alarm d:alarm approx! d:approx!
Builtin  approx? d:approx? approximates! d:approximates! between d:between cmp d:cmp d. d:d. daylight-db d:daylight-db
Builtin  default-now d:default-now doy d:doy dst-ofs d:dst-ofs dst? d:dst? dstinfo d:dstinfo dstquery d:dstquery
Builtin  dstzones? d:dstzones? elapsed-timer d:elapsed-timer elapsed-timer-hmds d:elapsed-timer-hmds
Builtin  elapsed-timer-msec d:elapsed-timer-msec elapsed-timer-seconds d:elapsed-timer-seconds first-dow d:first-dow
Builtin  fixed> d:fixed> fixed>dow d:fixed>dow fixed>iso d:fixed>iso format d:format iso>fixed d:iso>fixed
Builtin  join d:join last-dow d:last-dow last-month d:last-month last-week d:last-week last-year d:last-year
Builtin  leap? d:leap? mdays d:mdays msec d:msec msec> d:msec> new d:new next-dow d:next-dow next-month d:next-month
Builtin  next-week d:next-week next-year d:next-year parse d:parse parse-approx d:parse-approx parse-range d:parse-range
Builtin  prev-dow d:prev-dow relative d:relative rfc5322 d:rfc5322 start-timer d:start-timer ticks d:ticks
Builtin  ticks/sec d:ticks/sec timer d:timer timer-ctrl d:timer-ctrl tzadjust d:tzadjust unix> d:unix>
Builtin  unknown d:unknown unknown? d:unknown? updatetz d:updatetz year@ d:year@ ymd d:ymd ymd> d:ymd>
Builtin  MYSQLLIB db:MYSQLLIB ODBCLIB db:ODBCLIB add-func db:add-func aes! db:aes! again? db:again?
Builtin  begin db:begin bind db:bind bind-exec db:bind-exec bind-exec{} db:bind-exec{} close db:close
Builtin  col db:col col{} db:col{} commit db:commit db db:db dbpush db:dbpush disuse db:disuse each db:each
Builtin  err-handler db:err-handler exec db:exec exec-cb db:exec-cb exec-name db:exec-name exec{} db:exec{}
Builtin  get db:get get-sub db:get-sub key db:key kind? db:kind? last-rowid db:last-rowid mysql? db:mysql?
Builtin  odbc? db:odbc? open db:open open? db:open? prep-name db:prep-name prepare db:prepare query db:query
Builtin  query-all db:query-all rekey db:rekey rollback db:rollback set db:set set-sub db:set-sub sql@ db:sql@
Builtin  sql[] db:sql[] sql[np] db:sql[np] sql{np} db:sql{np} sql{} db:sql{} use db:use zip db:zip .state dbg:.state
Builtin  bp dbg:bp bt dbg:bt except-task@ dbg:except-task@ go dbg:go prompt dbg:prompt see dbg:see stop dbg:stop
Builtin  trace dbg:trace pso ds:pso / f:/ >posix f:>posix abspath f:abspath absrel f:absrel append f:append
Builtin  associate f:associate atime f:atime autodel f:autodel canwrite? f:canwrite? chmod f:chmod close f:close
Builtin  copy f:copy copydir f:copydir create f:create ctime f:ctime dir? f:dir? dname f:dname eachbuf f:eachbuf
Builtin  eachline f:eachline enssep f:enssep eof? f:eof? epub-meta f:epub-meta exec f:exec exists? f:exists?
Builtin  expand f:expand expand-home f:expand-home flush f:flush fname f:fname getb f:getb getc f:getc
Builtin  getline f:getline getmod f:getmod glob f:glob glob-links f:glob-links glob-nocase f:glob-nocase
Builtin  globfilter f:globfilter gunz f:gunz homedir f:homedir homedir! f:homedir! include f:include
Builtin  ioctl f:ioctl join f:join launch f:launch link f:link link> f:link> link? f:link? lock f:lock
Builtin  mkdir f:mkdir mmap f:mmap mmap-range f:mmap-range mmap-range? f:mmap-range? mtime f:mtime mv f:mv
Builtin  name@ f:name@ open f:open open! f:open! open-ro f:open-ro popen f:popen popen3 f:popen3 print f:print
Builtin  read f:read read-buf f:read-buf read? f:read? relpath f:relpath rglob f:rglob rm f:rm rmdir f:rmdir
Builtin  seek f:seek sep f:sep size f:size slurp f:slurp sparse? f:sparse? spit f:spit stderr f:stderr
Builtin  stdin f:stdin stdout f:stdout tell f:tell tempfile f:tempfile tilde f:tilde tilde? f:tilde?
Builtin  times f:times tmpspit f:tmpspit trash f:trash truncate f:truncate ungetb f:ungetb ungetc f:ungetc
Builtin  unzip f:unzip unzip-entry f:unzip-entry watch f:watch write f:write writen f:writen zip+ f:zip+
Builtin  zip@ f:zip@ zipentry f:zipentry zipnew f:zipnew zipopen f:zipopen zipsave f:zipsave atlas! font:atlas!
Builtin  atlas@ font:atlas@ default-size font:default-size default-size@ font:default-size@ info font:info
Builtin  ls font:ls measure font:measure new font:new oversample font:oversample pixels font:pixels
Builtin  pixels? font:pixels? system font:system system font:system filebrowser g:filebrowser media? g:media?
Builtin  event-loop game:event-loop init game:init state! game:state! state@ game:state@ distance geo:distance
Builtin  km/deg-lat geo:km/deg-lat km/deg-lon geo:km/deg-lon nearest geo:nearest close gpio:close flags! gpio:flags!
Builtin  info gpio:info init gpio:init line gpio:line open gpio:open read gpio:read req gpio:req write gpio:write
Builtin  +edge gr:+edge +edge+w gr:+edge+w +node gr:+node connect gr:connect edges gr:edges edges! gr:edges!
Builtin  m! gr:m! m@ gr:m@ neighbors gr:neighbors new gr:new node-edges gr:node-edges nodes gr:nodes
Builtin  traverse gr:traverse weight! gr:weight! + h:+ @ h:@ clear h:clear cmp! h:cmp! len h:len max! h:max!
Builtin  new h:new peek h:peek pop h:pop push h:push unique h:unique parse html:parse arm? hw:arm? camera hw:camera
Builtin  camera-img hw:camera-img camera? hw:camera? cpu? hw:cpu? device? hw:device? displays? hw:displays?
Builtin  displaysize? hw:displaysize? finger-match hw:finger-match finger-support hw:finger-support
Builtin  i2c hw:i2c i2c! hw:i2c! i2c!reg hw:i2c!reg i2c@ hw:i2c@ i2c@reg hw:i2c@reg isround? hw:isround?
Builtin  iswatch? hw:iswatch? mac? hw:mac? mem? hw:mem? model? hw:model? poll hw:poll sensor hw:sensor
Builtin  sensor-event hw:sensor-event sensors? hw:sensors? start hw:start stop hw:stop touch? hw:touch?
Builtin  uid? hw:uid? fetch-full imap:fetch-full fetch-uid-mail imap:fetch-uid-mail login imap:login
Builtin  logout imap:logout new imap:new search imap:search select-inbox imap:select-inbox >file img:>file
Builtin  >fmt img:>fmt ECC-HIGH img:ECC-HIGH ECC-LOW img:ECC-LOW ECC-MEDIUM img:ECC-MEDIUM ECC-QUARTILE img:ECC-QUARTILE
Builtin  copy img:copy crop img:crop data img:data desat img:desat draw img:draw draw-sub img:draw-sub
Builtin  exif img:exif exif-rotate? img:exif-rotate? fill img:fill fillrect img:fillrect filter img:filter
Builtin  fit img:fit flip img:flip from-svg img:from-svg line img:line new img:new pikchr img:pikchr
Builtin  pix! img:pix! pix@ img:pix@ qr-black img:qr-black qr-block img:qr-block qr-gen img:qr-gen qr-margin img:qr-margin
Builtin  qr-parse img:qr-parse qr-white img:qr-white qr>img img:qr>img rect img:rect rotate img:rotate
Builtin  scale img:scale scroll img:scroll size img:size countries iso:countries languages iso:languages
Builtin  bearing loc:bearing city loc:city city-db loc:city-db city-exact loc:city-exact city-exact loc:city-exact
Builtin  city-version loc:city-version city_country loc:city_country find loc:find sort loc:sort console log:console
Builtin  file log:file hook log:hook level log:level local log:local qsize log:qsize syslog log:syslog
Builtin  task log:task time log:time ! m:! !? m:!? + m:+ +? m:+? - m:- <> m:<> = m:= >arr m:>arr @ m:@
Builtin  @? m:@? _! m:_! _@ m:_@ _@? m:_@? accumulate m:accumulate alias m:alias arr> m:arr> bitmap m:bitmap
Builtin  clear m:clear data m:data each m:each exists? m:exists? filter m:filter ic m:ic iter m:iter
Builtin  iter-all m:iter-all keys m:keys len m:len map m:map merge m:merge new m:new op! m:op! open m:open
Builtin  slice m:slice vals m:vals xchg m:xchg zip m:zip ! mat:! * mat:* + mat:+ = mat:= @ mat:@ affine mat:affine
Builtin  col mat:col data mat:data det mat:det dim? mat:dim? get-n mat:get-n ident mat:ident inv mat:inv
Builtin  m. mat:m. minor mat:minor n* mat:n* new mat:new new-minor mat:new-minor rotate mat:rotate row mat:row
Builtin  same-size? mat:same-size? scale mat:scale shear mat:shear trans mat:trans translate mat:translate
Builtin  xform mat:xform 2console md:2console 2html md:2html 2nk md:2nk 8th? md:8th? user! md:user!
Builtin  user!@ md:user!@ user@ md:user@ user@@ md:user@@ color meta:color console meta:console gui meta:gui
Builtin  meta meta:meta ! n:! * n:* */ n:*/ + n:+ +! n:+! - n:- / n:/ /mod n:/mod 1+ n:1+ 1- n:1- < n:<
Builtin  = n:= > n:> >bool n:>bool BIGE n:BIGE BIGPI n:BIGPI E n:E PI n:PI ^ n:^ _mod n:_mod abs n:abs
Builtin  acos n:acos acosd n:acosd acosh n:acosh andor n:andor asin n:asin asind n:asind asinh n:asinh
Builtin  atan n:atan atan2 n:atan2 atand n:atand atanh n:atanh band n:band between n:between bfloat n:bfloat
Builtin  bic n:bic bint n:bint binv n:binv bits? n:bits? bnot n:bnot bor n:bor bxor n:bxor cast n:cast
Builtin  ceil n:ceil clamp n:clamp clz? n:clz? cmp n:cmp comb n:comb cos n:cos cosd n:cosd cosh n:cosh
Builtin  ctz? n:ctz? emod n:emod erf n:erf erfc n:erfc exp n:exp expm1 n:expm1 expmod n:expmod float n:float
Builtin  floor n:floor fmod n:fmod frac n:frac gcd n:gcd int n:int invmod n:invmod kind? n:kind? lcm n:lcm
Builtin  lerp n:lerp ln n:ln ln1p n:ln1p lnerp n:lnerp logistic n:logistic max n:max median n:median
Builtin  min n:min mod n:mod neg n:neg odd? n:odd? parity? n:parity? perm n:perm prime? n:prime? quantize n:quantize
Builtin  quantize! n:quantize! r+ n:r+ range n:range rot32l n:rot32l rot32r n:rot32r round n:round round2 n:round2
Builtin  rounding n:rounding running-variance n:running-variance running-variance-finalize n:running-variance-finalize
Builtin  sgn n:sgn shl n:shl shr n:shr sin n:sin sincos n:sincos sind n:sind sinh n:sinh sqr n:sqr sqrt n:sqrt
Builtin  tan n:tan tand n:tand tanh n:tanh trunc n:trunc ~= n:~= ! net:! !? net:!? - net:- >base64url net:>base64url
Builtin  >url net:>url @ net:@ @? net:@? CGI net:CGI DGRAM net:DGRAM INET4 net:INET4 INET6 net:INET6
Builtin  PROTO_TCP net:PROTO_TCP PROTO_UDP net:PROTO_UDP REMOTE_IP net:REMOTE_IP STREAM net:STREAM accept net:accept
Builtin  active? net:active? addrinfo>o net:addrinfo>o again? net:again? alloc-and-read net:alloc-and-read
Builtin  alloc-buf net:alloc-buf avail? net:avail? base64url> net:base64url> bind net:bind cgi-get net:cgi-get
Builtin  cgi-http-header net:cgi-http-header cgi-init net:cgi-init cgi-init-stunnel net:cgi-init-stunnel
Builtin  cgi-out net:cgi-out close net:close closed? net:closed? connect net:connect curnet net:curnet
Builtin  debug? net:debug? delete net:delete dns net:dns get net:get getaddrinfo net:getaddrinfo getpeername net:getpeername
Builtin  head net:head ifaces? net:ifaces? interp8th net:interp8th ipv6? net:ipv6? launch net:launch
Builtin  listen net:listen map>url net:map>url mime-type net:mime-type net-socket net:net-socket opts net:opts
Builtin  port-is-ssl? net:port-is-ssl? post net:post proxy! net:proxy! put net:put read net:read read-all net:read-all
Builtin  read-buf net:read-buf recvfrom net:recvfrom s>url net:s>url sendto net:sendto server net:server
Builtin  setsockopt net:setsockopt socket net:socket socket-mcast net:socket-mcast tcp-connect net:tcp-connect
Builtin  tlserr net:tlserr tlshello net:tlshello udp-connect net:udp-connect url> net:url> user-agent net:user-agent
Builtin  valid-email? net:valid-email? vpncheck net:vpncheck wait net:wait webserver net:webserver write net:write
Builtin  (begin) nk:(begin) (chart-begin) nk:(chart-begin) (chart-begin-colored) nk:(chart-begin-colored)
Builtin  (chart-end) nk:(chart-end) (end) nk:(end) (group-begin) nk:(group-begin) (group-end) nk:(group-end)
Builtin  (property) nk:(property) >img nk:>img PIXEL-FORMATS nk:PIXEL-FORMATS addfont nk:addfont affine nk:affine
Builtin  anti-alias nk:anti-alias any-clicked? nk:any-clicked? bounds nk:bounds bounds! nk:bounds! button nk:button
Builtin  button-color nk:button-color button-label nk:button-label button-set-behavior nk:button-set-behavior
Builtin  button-symbol nk:button-symbol button-symbol-label nk:button-symbol-label calendar nk:calendar
Builtin  chart-add-slot nk:chart-add-slot chart-add-slot-colored nk:chart-add-slot-colored chart-push nk:chart-push
Builtin  chart-push-slot nk:chart-push-slot checkbox nk:checkbox circle nk:circle clicked? nk:clicked?
Builtin  close-this! nk:close-this! close-this? nk:close-this? close? nk:close? color-chooser nk:color-chooser
Builtin  color-picker nk:color-picker combo nk:combo combo-begin-color nk:combo-begin-color combo-begin-label nk:combo-begin-label
Builtin  combo-cb nk:combo-cb combo-end nk:combo-end contextual-begin nk:contextual-begin contextual-close nk:contextual-close
Builtin  contextual-end nk:contextual-end contextual-item-image-text nk:contextual-item-image-text contextual-item-symbol-text nk:contextual-item-symbol-text
Builtin  contextual-item-text nk:contextual-item-text cp! nk:cp! cp@ nk:cp@ curpos nk:curpos cursor-load nk:cursor-load
Builtin  cursor-set nk:cursor-set cursor-show nk:cursor-show display-info nk:display-info display-scale@ nk:display-scale@
Builtin  display@ nk:display@ do nk:do down? nk:down? draw-image nk:draw-image draw-image-at nk:draw-image-at
Builtin  draw-image-centered nk:draw-image-centered draw-sub-image nk:draw-sub-image draw-text nk:draw-text
Builtin  draw-text-centered nk:draw-text-centered draw-text-high nk:draw-text-high draw-text-wrap nk:draw-text-wrap
Builtin  driver nk:driver drivers nk:drivers dropped nk:dropped dropping nk:dropping edit-focus nk:edit-focus
Builtin  edit-string nk:edit-string event nk:event event-boost nk:event-boost event-msec nk:event-msec
Builtin  event-wait nk:event-wait event? nk:event? fill-arc nk:fill-arc fill-circle nk:fill-circle fill-color nk:fill-color
Builtin  fill-poly nk:fill-poly fill-rect nk:fill-rect fill-rect-color nk:fill-rect-color fill-triangle nk:fill-triangle
Builtin  finger nk:finger flags! nk:flags! flags@ nk:flags@ flash nk:flash fullscreen nk:fullscreen
Builtin  gesture nk:gesture get nk:get get-row-height nk:get-row-height getfont nk:getfont getmap nk:getmap
Builtin  getmap! nk:getmap! gget nk:gget grid nk:grid grid-peek nk:grid-peek grid-push nk:grid-push
Builtin  group-scroll-ofs nk:group-scroll-ofs group-scroll-ofs! nk:group-scroll-ofs! gset nk:gset hints nk:hints
Builtin  hovered? nk:hovered? hrule nk:hrule ident nk:ident image nk:image init nk:init init-flags nk:init-flags
Builtin  init-sub nk:init-sub input-button nk:input-button input-key nk:input-key input-motion nk:input-motion
Builtin  input-scroll nk:input-scroll input-string nk:input-string key-down? nk:key-down? key-pressed? nk:key-pressed?
Builtin  key-released? nk:key-released? knob nk:knob label nk:label label-colored nk:label-colored label-wrap nk:label-wrap
Builtin  label-wrap-colored nk:label-wrap-colored layout-bounds nk:layout-bounds layout-grid-begin nk:layout-grid-begin
Builtin  layout-grid-end nk:layout-grid-end layout-push-dynamic nk:layout-push-dynamic layout-push-static nk:layout-push-static
Builtin  layout-push-variable nk:layout-push-variable layout-ratio-from-pixel nk:layout-ratio-from-pixel
Builtin  layout-reset-row-height nk:layout-reset-row-height layout-row nk:layout-row layout-row-begin nk:layout-row-begin
Builtin  layout-row-dynamic nk:layout-row-dynamic layout-row-end nk:layout-row-end layout-row-height nk:layout-row-height
Builtin  layout-row-push nk:layout-row-push layout-row-static nk:layout-row-static layout-row-template-begin nk:layout-row-template-begin
Builtin  layout-row-template-end nk:layout-row-template-end layout-space-begin nk:layout-space-begin
Builtin  layout-space-end nk:layout-space-end layout-space-push nk:layout-space-push layout-widget-bounds nk:layout-widget-bounds
Builtin  line-rel nk:line-rel line-to nk:line-to list-begin nk:list-begin list-end nk:list-end list-new nk:list-new
Builtin  list-ofs nk:list-ofs list-range nk:list-range m! nk:m! m@ nk:m@ make-style nk:make-style max-vertex-element nk:max-vertex-element
Builtin  maximize nk:maximize measure nk:measure measure-font nk:measure-font menu-begin nk:menu-begin
Builtin  menu-close nk:menu-close menu-end nk:menu-end menu-item-image nk:menu-item-image menu-item-label nk:menu-item-label
Builtin  menu-item-symbol nk:menu-item-symbol menubar-begin nk:menubar-begin menubar-end nk:menubar-end
Builtin  minimize nk:minimize mouse-pos nk:mouse-pos move-back nk:move-back move-rel nk:move-rel move-to nk:move-to
Builtin  msg nk:msg msgdlg nk:msgdlg ontop nk:ontop option nk:option pen-color nk:pen-color pen-width nk:pen-width
Builtin  pix! nk:pix! plot nk:plot plot-fn nk:plot-fn polygon nk:polygon pop-font nk:pop-font popup-begin nk:popup-begin
Builtin  popup-close nk:popup-close popup-end nk:popup-end popup-scroll-ofs nk:popup-scroll-ofs popup-scroll-ofs! nk:popup-scroll-ofs!
Builtin  progress nk:progress prop-int nk:prop-int pt-in? nk:pt-in? pt>local nk:pt>local pt>screen nk:pt>screen
Builtin  push-font nk:push-font raise nk:raise rect-rel nk:rect-rel rect-to nk:rect-to rect>local nk:rect>local
Builtin  rect>screen nk:rect>screen released? nk:released? render nk:render render! nk:render! render-loop nk:render-loop
Builtin  render-loop-max nk:render-loop-max render-loop-timed nk:render-loop-timed render-timed nk:render-timed
Builtin  render@ nk:render@ renderers nk:renderers rendering nk:rendering restore nk:restore rotate nk:rotate
Builtin  rotate-rel nk:rotate-rel rtl! nk:rtl! rtl? nk:rtl? safe-bounds nk:safe-bounds save nk:save
Builtin  scale nk:scale scale@ nk:scale@ scancode? nk:scancode? screen-saver nk:screen-saver screen-size nk:screen-size
Builtin  screen-win-close nk:screen-win-close selectable nk:selectable set nk:set set-font nk:set-font
Builtin  set-hint nk:set-hint set-num-vertices nk:set-num-vertices set-radius nk:set-radius setpos nk:setpos
Builtin  setwin nk:setwin show nk:show skew nk:skew slider nk:slider slider-int nk:slider-int space nk:space
Builtin  spacing nk:spacing start-text nk:start-text stroke-arc nk:stroke-arc stroke-circle nk:stroke-circle
Builtin  stroke-curve nk:stroke-curve stroke-line nk:stroke-line stroke-polygon nk:stroke-polygon stroke-polyline nk:stroke-polyline
Builtin  stroke-rect nk:stroke-rect stroke-tri nk:stroke-tri style-from-table nk:style-from-table swipe nk:swipe
Builtin  swipe-dir-threshold nk:swipe-dir-threshold swipe-threshold nk:swipe-threshold text nk:text
Builtin  text-align nk:text-align text-font nk:text-font text-pad nk:text-pad text? nk:text? timer-delay nk:timer-delay
Builtin  timer? nk:timer? toast nk:toast tooltip nk:tooltip translate nk:translate tree-pop nk:tree-pop
Builtin  tree-state-push nk:tree-state-push triangle nk:triangle use-style nk:use-style vsync nk:vsync
Builtin  widget nk:widget widget-bounds nk:widget-bounds widget-disable nk:widget-disable widget-fitting nk:widget-fitting
Builtin  widget-high nk:widget-high widget-hovered? nk:widget-hovered? widget-mouse-click-down? nk:widget-mouse-click-down?
Builtin  widget-mouse-clicked? nk:widget-mouse-clicked? widget-pos nk:widget-pos widget-size nk:widget-size
Builtin  widget-size-allot nk:widget-size-allot widget-wide nk:widget-wide win nk:win win-bounds nk:win-bounds
Builtin  win-bounds! nk:win-bounds! win-close nk:win-close win-closed? nk:win-closed? win-collapse nk:win-collapse
Builtin  win-collapsed? nk:win-collapsed? win-content-bounds nk:win-content-bounds win-focus nk:win-focus
Builtin  win-focused? nk:win-focused? win-hidden? nk:win-hidden? win-high nk:win-high win-hovered? nk:win-hovered?
Builtin  win-icon! nk:win-icon! win-pos nk:win-pos win-scroll-ofs nk:win-scroll-ofs win-scroll-ofs! nk:win-scroll-ofs!
Builtin  win-show nk:win-show win-size nk:win-size win-title! nk:win-title! win-wide nk:win-wide win? nk:win?
Builtin  MAX ns:MAX ! o:! + o:+ +? o:+? ??? o:??? @ o:@ class o:class exec o:exec isa o:isa method o:method
Builtin  mutate o:mutate new o:new super o:super POSIX os:POSIX chroot os:chroot devname os:devname
Builtin  docker? os:docker? env os:env lang os:lang locales os:locales notify os:notify power-state os:power-state
Builtin  region os:region waitpid os:waitpid bezier pdf:bezier bezierq pdf:bezierq circle pdf:circle
Builtin  color pdf:color ellipse pdf:ellipse font pdf:font img pdf:img line pdf:line new pdf:new page pdf:page
Builtin  page-size pdf:page-size rect pdf:rect save pdf:save size pdf:size text pdf:text text-rotate pdf:text-rotate
Builtin  text-size pdf:text-size text-width pdf:text-width text-wrap pdf:text-wrap text-wrap-rotate pdf:text-wrap-rotate
Builtin  cast ptr:cast deref ptr:deref len ptr:len null? ptr:null? pack ptr:pack unpack ptr:unpack unpack_orig ptr:unpack_orig
Builtin  publish pubsub:publish qsize pubsub:qsize subscribe pubsub:subscribe + q:+ clear q:clear len q:len
Builtin  new q:new notify q:notify overwrite q:overwrite peek q:peek pick q:pick pop q:pop push q:push
Builtin  remove q:remove shift q:shift size q:size slide q:slide throwing q:throwing wait q:wait ++match r:++match
Builtin  +/ r:+/ +match r:+match / r:/ @ r:@ _@ r:_@ len r:len match r:match match[] r:match[] matchall[] r:matchall[]
Builtin  new r:new rx r:rx str r:str * rat:* + rat:+ - rat:- / rat:/ >n rat:>n >s rat:>s new rat:new
Builtin  proper rat:proper ! rect:! /high rect:/high /wide rect:/wide = rect:= >a rect:>a >pts rect:>pts
Builtin  >pts4 rect:>pts4 @ rect:@ center rect:center center-pt rect:center-pt intersect rect:intersect
Builtin  new rect:new new-pt rect:new-pt ofs rect:ofs open rect:open pad rect:pad pos rect:pos pt-open rect:pt-open
Builtin  pt>a rect:pt>a pt>rect rect:pt>rect pts> rect:pts> restrict rect:restrict shrink rect:shrink
Builtin  size rect:size union rect:union ! s:! * s:* + s:+ - s:- / s:/ /scripts s:/scripts /ws s:/ws
Builtin  2len s:2len <+ s:<+ <> s:<> = s:= =ic s:=ic >base64 s:>base64 >ucs2 s:>ucs2 @ s:@ _len s:_len
Builtin  append s:append base64> s:base64> clear s:clear cmp s:cmp cmpi s:cmpi compress s:compress count-match s:count-match
Builtin  days! s:days! dist s:dist each s:each each! s:each! eachline s:eachline escape s:escape expand s:expand
Builtin  expand-env s:expand-env fill s:fill fold s:fold gen-uid s:gen-uid globmatch s:globmatch hexupr s:hexupr
Builtin  insert s:insert intl s:intl intl! s:intl! lang s:lang lc s:lc lc? s:lc? len s:len lsub s:lsub
Builtin  ltrim s:ltrim map s:map months! s:months! n> s:n> new s:new norm s:norm reduce s:reduce repinsert s:repinsert
Builtin  replace s:replace replace! s:replace! rev s:rev rsearch s:rsearch rsub s:rsub rtl s:rtl rtrim s:rtrim
Builtin  scan-match s:scan-match script? s:script? search s:search size s:size slice s:slice soundex s:soundex
Builtin  strfmap s:strfmap strfmt s:strfmt term s:term text-wrap s:text-wrap tr s:tr transform s:transform
Builtin  trim s:trim tsub s:tsub uc s:uc uc? s:uc? ucs2> s:ucs2> utf8? s:utf8? zt s:zt >a set:>a add set:add
Builtin  add[] set:add[] del set:del difference set:difference has set:has intersect set:intersect new set:new
Builtin  union set:union bits! sio:bits! bits@ sio:bits@ close sio:close enum sio:enum hz! sio:hz! hz@ sio:hz@
Builtin  mode! sio:mode! mode@ sio:mode@ open sio:open open sio:open opts! sio:opts! opts@ sio:opts@
Builtin  read sio:read read sio:read write sio:write write sio:write @ slv:@ auto slv:auto build slv:build
Builtin  constraint slv:constraint dump slv:dump edit slv:edit named-variable slv:named-variable new slv:new
Builtin  relation slv:relation reset slv:reset suggest slv:suggest term slv:term update slv:update v[] slv:v[]
Builtin  variable slv:variable v{} slv:v{} new smtp:new send smtp:send apply-filter snd:apply-filter
Builtin  devices? snd:devices? end-record snd:end-record filter snd:filter freq snd:freq gain snd:gain
Builtin  gain? snd:gain? init snd:init len snd:len loop snd:loop loop? snd:loop? mix snd:mix new snd:new
Builtin  pause snd:pause play snd:play played snd:played rate snd:rate ready? snd:ready? record snd:record
Builtin  resume snd:resume seek snd:seek stop snd:stop stopall snd:stopall volume snd:volume volume? snd:volume?
Builtin  + st:+ . st:. clear st:clear dot-depth st:dot-depth len st:len list st:list ndrop st:ndrop
Builtin  new st:new op! st:op! peek st:peek pick st:pick pop st:pop push st:push roll st:roll shift st:shift
Builtin  size st:size slide st:slide swap st:swap throwing st:throwing >buf struct:>buf arr> struct:arr>
Builtin  buf struct:buf buf> struct:buf> byte struct:byte double struct:double field! struct:field!
Builtin  field@ struct:field@ float struct:float ignore struct:ignore int struct:int long struct:long
Builtin  struct; struct:struct; word struct:word ! t:! @ t:@ by-name t:by-name curtask t:curtask def-queue t:def-queue
Builtin  def-stack t:def-stack done? t:done? dtor t:dtor err! t:err! err? t:err? errno? t:errno? extra t:extra
Builtin  getq t:getq handler t:handler handler@ t:handler@ kill t:kill list t:list main t:main max-exceptions t:max-exceptions
Builtin  name! t:name! name@ t:name@ notify t:notify parent t:parent pop t:pop priority t:priority push t:push
Builtin  push! t:push! q-notify t:q-notify q-wait t:q-wait qlen t:qlen result t:result set-affinity t:set-affinity
Builtin  setq t:setq task t:task task-n t:task-n task-stop t:task-stop ticks t:ticks to? t:to? wait t:wait
Builtin  add tree:add binary tree:binary bk tree:bk btree tree:btree cmp! tree:cmp! data tree:data del tree:del
Builtin  find tree:find iter tree:iter next tree:next nodes tree:nodes parent tree:parent parse tree:parse
Builtin  prev tree:prev root tree:root search tree:search trie tree:trie ! w:! (is) w:(is) @ w:@ alias: w:alias:
Builtin  cb w:cb deprecate w:deprecate dlcall w:dlcall dlopen w:dlopen dlsym w:dlsym exec w:exec exec? w:exec?
Builtin  ffifail w:ffifail find w:find forget w:forget is w:is name w:name undo w:undo xt w:xt xt> w:xt>
Builtin  close ws:close decode ws:decode encode ws:encode encode-nomask ws:encode-nomask gen-accept-header ws:gen-accept-header
Builtin  gen-accept-key ws:gen-accept-key opcodes ws:opcodes open ws:open >s xml:>s >txt xml:>txt md-init xml:md-init
Builtin  md-parse xml:md-parse parse xml:parse parse-html xml:parse-html parse-stream xml:parse-stream
Builtin  getmsg[] zmq:getmsg[] sendmsg[] zmq:sendmsg[]


" numbers
syn keyword eighthMath decimal hex base@ base! 
syn match eighthInteger '\<-\=[0-9.]*[0-9.]\+\>'

" recognize hex and binary numbers, the '$' and '%' notation is for eighth
syn match eighthInteger '\<\$\x*\x\+\>' " *1* --- dont't mess
syn match eighthInteger '\<\x*\d\x*\>'  " *2* --- this order!
syn match eighthInteger '\<%[0-1]*[0-1]\+\>'
syn match eighthInteger "\<'.\>"

syn include @SQL syntax/sql.vim
syn region eightSQL matchgroup=Define start=/\<SQL\[\s/ end=/\<]\>/ contains=@SQL keepend
syn region eightSQL matchgroup=Define start=/\<SQL{\s/ end=/\<}\>/ contains=@SQL keepend
syn region eightSQL matchgroup=Define start=/\<SQL!\s/ end=/\<!\>/ contains=@SQL keepend

" Strings
syn region eighthString start=+\.\?\"+ skip=+"+ end=+$+
syn keyword jsonNull null
syn keyword jsonBool /\(true\|false\)/
syn region eighthString start=/\<"/ end=/"\>/ 
syn match jsonObjEntry /"\"[^"]\+\"\ze\s*:/

syn region eighthNeeds start=+needs\[+ end=+]+ matchgroup=eighthNeeds2 transparent 
syn match eighthNeeds2 /\<needs\[/
syn match eighthNeeds2 /]\>/

syn match eighthBuiltin /m:\[]!/
syn match eighthBuiltin /v:\[]/
syn match eighthBuiltin /db:bind-exec\[]/
syn match eighthBuiltin /db:exec\[]/
syn match eighthBuiltin /db:col\[]/

syn region eighthComment start="\zs\\" end="$" contains=eighthTodo,@Spell
syn region eighthComment start="\zs--\s" end="$" contains=eighthTodo,@Spell
syn region eighthComment start="\zs(\*" end="\*)\ze" contains=eightTodo,@Spell

" The default methods for highlighting. Can be overriden later.
hi def link eighthTodo Todo
hi def link eighthNeeds2 Include
hi def link eighthNeeds Error
hi def link eighthOperators Operator
hi def link eighthMath Number
hi def link eighthInteger Number
hi def link eighthStack Special
hi def link eighthFStack Special
hi def link eighthFname Operator
hi def link eighthSP Special
hi def link eighthColonDef Define
hi def link eighthColonName Operator
hi def link eighthEndOfColonDef Define
hi def link eighthDefine Define
hi def link eighthDebug Debug
hi def link eighthCharOps Character
hi def link eighthConversion String
hi def link eighthForth Statement
hi def link eighthVocs Statement
hi def link eighthString String
hi def link eighthComment Comment
hi def link eighthClassDef Define
hi def link eighthEndOfClassDef Define
hi def link eighthObjectDef Define
hi def link eighthEndOfObjectDef Define
hi def link eighthInclude Include
hi def link eighthBuiltin Define
hi def link eighthClasses Define
hi def link eighthClassWord Keyword
hi def link jsonObject Delimiter
hi def link jsonObjEntry Label
hi def link jsonArray Special
hi def link jsonNull Function
hi def link jsonBool Boolean

delcommand Builtin
let b:current_syntax = "8th"
let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ft=vim ts=4 sw=4 nocin:si 
