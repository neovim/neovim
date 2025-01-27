" Vim syntax file
" Language:     8th
" Version:      24.08
" Last Change:  2024 Nov 07
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
Builtin  ' G:' ( G:( (:) G:(:) (code) G:(code) (defer) G:(defer) (dump) G:(dump) (getc) G:(getc) (gets) G:(gets)
Builtin  (interp) G:(interp) (log) G:(log) (needs) G:(needs) (parseln) G:(parseln) (putc) G:(putc) (puts) G:(puts)
Builtin  (stat) G:(stat) (with) G:(with) ) G:) +hook G:+hook +ref G:+ref ,# G:,# -----BEGIN G:-----BEGIN
Builtin  -Inf G:-Inf -Inf? G:-Inf? -hook G:-hook -ref G:-ref -rot G:-rot . G:. .# G:.# .hook G:.hook
Builtin  .needs G:.needs .r G:.r .s G:.s .s-truncate G:.s-truncate .stats G:.stats .ver G:.ver .with G:.with
Builtin  0; G:0; 2dip G:2dip 2drop G:2drop 2dup G:2dup 2nip G:2nip 2over G:2over 2swap G:2swap 2tuck G:2tuck
Builtin  3drop G:3drop 3drop G:3drop 3dup G:3dup 3rev G:3rev 4drop G:4drop 8thdt? G:8thdt? 8thsku? G:8thsku?
Builtin  8thver? G:8thver? 8thvernum? G:8thvernum? : G:: ; G:; ;; G:;; ;;; G:;;; ;with G:;with >clip G:>clip
Builtin  >json G:>json >kind G:>kind >n G:>n >r G:>r >s G:>s ?: G:?: ?@ G:?@ @ G:@ BITMAP: G:BITMAP:
Builtin  ENUM: G:ENUM: FLAG: G:FLAG: I G:I Inf G:Inf Inf? G:Inf? J G:J K G:K NaN G:NaN NaN? G:NaN? SED-CHECK G:SED-CHECK
Builtin  SED: G:SED: SED: G:SED: X G:X \ G:\ _dup G:_dup _swap G:_swap actor: G:actor: again G:again
Builtin  ahead G:ahead and G:and apropos G:apropos argc G:argc args G:args array? G:array? assert G:assert
Builtin  base G:base base>n G:base>n bi G:bi bits G:bits break G:break break? G:break? breakif G:breakif
Builtin  build? G:build? buildver? G:buildver? bye G:bye c/does G:c/does case: G:case: catch G:catch
Builtin  chdir G:chdir clip> G:clip> clone G:clone clone-shallow G:clone-shallow cold G:cold compile G:compile
Builtin  compile? G:compile? compiling? G:compiling? conflict G:conflict const G:const container? G:container?
Builtin  counting-allocations G:counting-allocations cr G:cr critical: G:critical: critical; G:critical;
Builtin  curlang G:curlang curry G:curry curry: G:curry: decimal G:decimal default: G:default: defer: G:defer:
Builtin  deferred: G:deferred: deg>rad G:deg>rad depth G:depth die G:die dip G:dip drop G:drop dstack G:dstack
Builtin  dump G:dump dup G:dup dup>r G:dup>r dup? G:dup? e# G:e# enum: G:enum: error? G:error? eval G:eval
Builtin  eval! G:eval! eval0 G:eval0 exit G:exit expect G:expect extra! G:extra! extra@ G:extra@ false G:false
Builtin  fnv G:fnv fourth G:fourth free G:free func: G:func: getc G:getc getcwd G:getcwd getenv G:getenv
Builtin  gets G:gets goto G:goto handler G:handler header G:header help G:help help_db G:help_db here G:here
Builtin  hex G:hex i: G:i: i; G:i; isa? G:isa? items-used G:items-used jcall G:jcall jclass G:jclass
Builtin  jmethod G:jmethod json! G:json! json-8th> G:json-8th> json-nesting G:json-nesting json-pretty G:json-pretty
Builtin  json-throw G:json-throw json> G:json> json@ G:json@ k32 G:k32 keep G:keep l: G:l: last G:last
Builtin  lib G:lib libbin G:libbin libc G:libc libimg G:libimg literal G:literal locals: G:locals: lock G:lock
Builtin  lock-to G:lock-to locked? G:locked? log G:log log-syslog G:log-syslog log-task G:log-task log-time G:log-time
Builtin  log-time-local G:log-time-local long-days G:long-days long-months G:long-months longjmp G:longjmp
Builtin  lookup G:lookup loop G:loop loop- G:loop- map? G:map? mark G:mark mark? G:mark? mobile? G:mobile?
Builtin  n# G:n# name>os G:name>os name>sem G:name>sem ndrop G:ndrop needs G:needs needs-throws G:needs-throws
Builtin  new G:new next-arg G:next-arg nip G:nip noop G:noop not G:not nothrow G:nothrow ns G:ns ns: G:ns:
Builtin  ns>ls G:ns>ls ns>s G:ns>s ns? G:ns? null G:null null; G:null; null? G:null? nullvar G:nullvar
Builtin  number? G:number? of: G:of: off G:off on G:on onexit G:onexit only G:only op! G:op! or G:or
Builtin  os G:os os-names G:os-names os>long-name G:os>long-name os>name G:os>name over G:over p: G:p:
Builtin  pack G:pack parse G:parse parse-csv G:parse-csv parse-date G:parse-date parsech G:parsech parseln G:parseln
Builtin  parsews G:parsews pick G:pick poke G:poke pool-clear G:pool-clear pool-clear-all G:pool-clear-all
Builtin  prior G:prior private G:private process-args G:process-args process-args-fancy G:process-args-fancy
Builtin  process-args-help G:process-args-help prompt G:prompt public G:public putc G:putc puts G:puts
Builtin  quote G:quote r! G:r! r> G:r> r@ G:r@ rad>deg G:rad>deg rand-jit G:rand-jit rand-jsf G:rand-jsf
Builtin  rand-native G:rand-native rand-normal G:rand-normal rand-pcg G:rand-pcg rand-pcg-seed G:rand-pcg-seed
Builtin  rand-range G:rand-range rand-select G:rand-select randbuf-pcg G:randbuf-pcg random G:random
Builtin  rdrop G:rdrop recurse G:recurse recurse-stack G:recurse-stack ref@ G:ref@ reg! G:reg! reg@ G:reg@
Builtin  regbin@ G:regbin@ remaining-args G:remaining-args repeat G:repeat requires G:requires reset G:reset
Builtin  roll G:roll rop! G:rop! rot G:rot rpick G:rpick rreset G:rreset rroll G:rroll rstack G:rstack
Builtin  rswap G:rswap rusage G:rusage s>ns G:s>ns same? G:same? scriptdir G:scriptdir scriptfile G:scriptfile
Builtin  sem G:sem sem-post G:sem-post sem-rm G:sem-rm sem-wait G:sem-wait sem-wait? G:sem-wait? sem>name G:sem>name
Builtin  semi-throw G:semi-throw set-wipe G:set-wipe setenv G:setenv setjmp G:setjmp settings! G:settings!
Builtin  settings![] G:settings![] settings@ G:settings@ settings@? G:settings@? settings@[] G:settings@[]
Builtin  sh G:sh sh$ G:sh$ short-days G:short-days short-months G:short-months sleep G:sleep sleep-msec G:sleep-msec
Builtin  sleep-until G:sleep-until slog G:slog space G:space stack-check G:stack-check stack-size G:stack-size
Builtin  step G:step sthrow G:sthrow string? G:string? struct: G:struct: swap G:swap tab-hook G:tab-hook
Builtin  tell-conflict G:tell-conflict tempdir G:tempdir tempfilename G:tempfilename third G:third throw G:throw
Builtin  thrownull G:thrownull times G:times tlog G:tlog toggle G:toggle tri G:tri true G:true tuck G:tuck
Builtin  type-check G:type-check typeassert G:typeassert uid G:uid uname G:uname unlock G:unlock unpack G:unpack
Builtin  until G:until until! G:until! while G:while while! G:while! with: G:with: word? G:word? words G:words
Builtin  words-like G:words-like words/ G:words/ xchg G:xchg xor G:xor >auth HTTP:>auth (curry) I:(curry)
Builtin  appopts I:appopts notimpl I:notimpl sh I:sh trace-word I:trace-word call JSONRPC:call auth-string OAuth:auth-string
Builtin  gen-nonce OAuth:gen-nonce params OAuth:params call SOAP:call ! a:! + a:+ - a:- / a:/ 2each a:2each
Builtin  2len a:2len 2map a:2map 2map+ a:2map+ 2map= a:2map= <> a:<> = a:= @ a:@ @? a:@? _@ a:_@ _len a:_len
Builtin  all a:all any a:any bsearch a:bsearch centroid a:centroid clear a:clear close a:close cmp a:cmp
Builtin  diff a:diff dot a:dot each a:each each! a:each! each-par a:each-par each-slice a:each-slice
Builtin  exists? a:exists? filter a:filter filter-par a:filter-par generate a:generate group a:group
Builtin  indexof a:indexof insert a:insert intersect a:intersect join a:join len a:len map a:map map+ a:map+
Builtin  map-par a:map-par map= a:map= maxlen a:maxlen mean a:mean mean&variance a:mean&variance merge a:merge
Builtin  new a:new op! a:op! open a:open pigeon a:pigeon pivot a:pivot pop a:pop push a:push push' a:push'
Builtin  qsort a:qsort randeach a:randeach reduce a:reduce reduce+ a:reduce+ remove a:remove rev a:rev
Builtin  rindexof a:rindexof shift a:shift shuffle a:shuffle slice a:slice slice+ a:slice+ slide a:slide
Builtin  smear a:smear sort a:sort split a:split squash a:squash switch a:switch union a:union uniq a:uniq
Builtin  unzip a:unzip x a:x x-each a:x-each xchg a:xchg y a:y zip a:zip 8thdir app:8thdir asset app:asset
Builtin  atrun app:atrun atrun app:atrun atrun app:atrun basedir app:basedir basename app:basename config-file-name app:config-file-name
Builtin  current app:current datadir app:datadir display-moved app:display-moved exename app:exename
Builtin  localechanged app:localechanged lowmem app:lowmem main app:main name app:name onback app:onback
Builtin  oncrash app:oncrash opts! app:opts! opts@ app:opts@ orientation app:orientation orientation! app:orientation!
Builtin  pid app:pid post-main app:post-main pre-main app:pre-main privdir app:privdir raise app:raise
Builtin  read-config app:read-config read-config-map app:read-config-map read-config-var app:read-config-var
Builtin  request-perm app:request-perm restart app:restart resumed app:resumed signal app:signal standalone app:standalone
Builtin  standalone! app:standalone! subdir app:subdir suspended app:suspended sysquit app:sysquit terminated app:terminated
Builtin  ticks app:ticks timeout app:timeout trap app:trap dawn astro:dawn do-dawn astro:do-dawn do-dusk astro:do-dusk
Builtin  do-rise astro:do-rise dusk astro:dusk latitude astro:latitude location! astro:location! longitude astro:longitude
Builtin  sunrise astro:sunrise genkeys auth:genkeys secret auth:secret session-id auth:session-id session-key auth:session-key
Builtin  validate auth:validate ! b:! + b:+ / b:/ 1+ b:1+ 1- b:1- <> b:<> = b:= >base16 b:>base16 >base32 b:>base32
Builtin  >base64 b:>base64 >base85 b:>base85 >hex b:>hex >mpack b:>mpack @ b:@ ICONVLIBS b:ICONVLIBS
Builtin  append b:append base16> b:base16> base32> b:base32> base64> b:base64> base85> b:base85> bit! b:bit!
Builtin  bit@ b:bit@ clear b:clear compress b:compress conv b:conv each b:each each! b:each! each-slice b:each-slice
Builtin  expand b:expand fill b:fill getb b:getb hex> b:hex> len b:len mem> b:mem> move b:move mpack-compat b:mpack-compat
Builtin  mpack-date b:mpack-date mpack-ignore b:mpack-ignore mpack> b:mpack> n! b:n! n+ b:n+ n@ b:n@
Builtin  new b:new op b:op op! b:op! pad b:pad rev b:rev search b:search shmem b:shmem slice b:slice
Builtin  splice b:splice ungetb b:ungetb unpad b:unpad writable b:writable xor b:xor +block bc:+block
Builtin  .blocks bc:.blocks add-block bc:add-block block-hash bc:block-hash block@ bc:block@ first-block bc:first-block
Builtin  hash bc:hash last-block bc:last-block load bc:load new bc:new save bc:save set-sql bc:set-sql
Builtin  validate bc:validate validate-block bc:validate-block add bloom:add filter bloom:filter in? bloom:in?
Builtin  parse bson:parse LIBS bt:LIBS accept bt:accept ch! bt:ch! ch@ bt:ch@ connect bt:connect disconnect bt:disconnect
Builtin  init bt:init leconnect bt:leconnect lescan bt:lescan listen bt:listen on? bt:on? read bt:read
Builtin  scan bt:scan service? bt:service? services? bt:services? write bt:write * c:* * c:* + c:+ + c:+
Builtin  = c:= = c:= >polar c:>polar >polar c:>polar >ri c:>ri >ri c:>ri ^ c:^ ^ c:^ abs c:abs abs c:abs
Builtin  arg c:arg arg c:arg conj c:conj conj c:conj im c:im im c:im log c:log log c:log n> c:n> n> c:n>
Builtin  new c:new new c:new polar> c:polar> polar> c:polar> re c:re re c:re (.hebrew) cal:(.hebrew)
Builtin  (.islamic) cal:(.islamic) .hebrew cal:.hebrew .islamic cal:.islamic >hebepoch cal:>hebepoch
Builtin  >jdn cal:>jdn Adar cal:Adar Adar2 cal:Adar2 Av cal:Av Elul cal:Elul Heshvan cal:Heshvan Iyar cal:Iyar
Builtin  Kislev cal:Kislev Nissan cal:Nissan Shevat cal:Shevat Sivan cal:Sivan Tammuz cal:Tammuz Tevet cal:Tevet
Builtin  Tishrei cal:Tishrei days-in-hebrew-year cal:days-in-hebrew-year displaying-hebrew cal:displaying-hebrew
Builtin  fixed>hebrew cal:fixed>hebrew fixed>islamic cal:fixed>islamic gershayim cal:gershayim hanukkah cal:hanukkah
Builtin  hebrew-epoch cal:hebrew-epoch hebrew-leap-year? cal:hebrew-leap-year? hebrew>fixed cal:hebrew>fixed
Builtin  hebrewtoday cal:hebrewtoday hmonth-name cal:hmonth-name islamic.epoch cal:islamic.epoch islamic>fixed cal:islamic>fixed
Builtin  islamictoday cal:islamictoday jdn> cal:jdn> last-day-of-hebrew-month cal:last-day-of-hebrew-month
Builtin  number>hebrew cal:number>hebrew omer cal:omer pesach cal:pesach purim cal:purim rosh-chodesh? cal:rosh-chodesh?
Builtin  rosh-hashanah cal:rosh-hashanah shavuot cal:shavuot taanit-esther cal:taanit-esther tisha-beav cal:tisha-beav
Builtin  yom-haatsmaut cal:yom-haatsmaut yom-kippur cal:yom-kippur >hsva clr:>hsva complement clr:complement
Builtin  dist clr:dist gradient clr:gradient hsva> clr:hsva> invert clr:invert nearest-name clr:nearest-name
Builtin  parse clr:parse >redir con:>redir accept con:accept accept-nl con:accept-nl accept-pwd con:accept-pwd
Builtin  alert con:alert ansi? con:ansi? black con:black blue con:blue clreol con:clreol cls con:cls
Builtin  ctrld-empty con:ctrld-empty cyan con:cyan down con:down file>history con:file>history free con:free
Builtin  getxy con:getxy gotoxy con:gotoxy green con:green history-handler con:history-handler history>file con:history>file
Builtin  init con:init key con:key key? con:key? left con:left load-history con:load-history magenta con:magenta
Builtin  max-history con:max-history onBlack con:onBlack onBlue con:onBlue onCyan con:onCyan onGreen con:onGreen
Builtin  onMagenta con:onMagenta onRed con:onRed onWhite con:onWhite onYellow con:onYellow print con:print
Builtin  red con:red redir> con:redir> redir? con:redir? right con:right save-history con:save-history
Builtin  size? con:size? up con:up white con:white yellow con:yellow >aes128gcm cr:>aes128gcm >aes256gcm cr:>aes256gcm
Builtin  >cp cr:>cp >cpe cr:>cpe >decrypt cr:>decrypt >edbox cr:>edbox >encrypt cr:>encrypt >nbuf cr:>nbuf
Builtin  >rsabox cr:>rsabox >uuid cr:>uuid aad? cr:aad? aes128box-sig cr:aes128box-sig aes128gcm> cr:aes128gcm>
Builtin  aes256box-sig cr:aes256box-sig aes256gcm> cr:aes256gcm> aesgcm cr:aesgcm blakehash cr:blakehash
Builtin  chacha20box-sig cr:chacha20box-sig chachapoly cr:chachapoly cipher! cr:cipher! cipher@ cr:cipher@
Builtin  ciphers cr:ciphers cp> cr:cp> cpe> cr:cpe> decrypt cr:decrypt decrypt+ cr:decrypt+ decrypt> cr:decrypt>
Builtin  ebox-sig cr:ebox-sig ecc-curves cr:ecc-curves ecc-genkey cr:ecc-genkey ecc-secret cr:ecc-secret
Builtin  ecc-sign cr:ecc-sign ecc-verify cr:ecc-verify ed25519 cr:ed25519 ed25519-secret cr:ed25519-secret
Builtin  ed25519-sign cr:ed25519-sign ed25519-verify cr:ed25519-verify edbox-sig cr:edbox-sig edbox> cr:edbox>
Builtin  encrypt cr:encrypt encrypt+ cr:encrypt+ encrypt> cr:encrypt> ensurekey cr:ensurekey genkey cr:genkey
Builtin  hash cr:hash hash! cr:hash! hash+ cr:hash+ hash>b cr:hash>b hash>s cr:hash>s hash@ cr:hash@
Builtin  hashes cr:hashes hmac cr:hmac hotp cr:hotp iv? cr:iv? pem-read cr:pem-read pem-write cr:pem-write
Builtin  pwd-valid? cr:pwd-valid? pwd/ cr:pwd/ pwd>hash cr:pwd>hash rand cr:rand randbuf cr:randbuf
Builtin  randkey cr:randkey restore cr:restore root-certs cr:root-certs rsa_decrypt cr:rsa_decrypt rsa_encrypt cr:rsa_encrypt
Builtin  rsa_sign cr:rsa_sign rsa_verify cr:rsa_verify rsabox-sig cr:rsabox-sig rsabox> cr:rsabox> rsagenkey cr:rsagenkey
Builtin  save cr:save sbox-sig cr:sbox-sig sha1-hmac cr:sha1-hmac shard cr:shard tag? cr:tag? totp cr:totp
Builtin  totp-epoch cr:totp-epoch totp-time-step cr:totp-time-step unshard cr:unshard uuid cr:uuid uuid> cr:uuid>
Builtin  validate-pgp-sig cr:validate-pgp-sig validate-pwd cr:validate-pwd (.time) d:(.time) + d:+ +day d:+day
Builtin  +hour d:+hour +min d:+min +msec d:+msec - d:- .time d:.time / d:/ = d:= >fixed d:>fixed >hmds d:>hmds
Builtin  >hmds: d:>hmds: >msec d:>msec >unix d:>unix >ymd d:>ymd ?= d:?= Fri d:Fri Mon d:Mon Sat d:Sat
Builtin  Sun d:Sun Thu d:Thu Tue d:Tue Wed d:Wed adjust-dst d:adjust-dst alarm d:alarm approx! d:approx!
Builtin  approx? d:approx? approximates! d:approximates! between d:between cmp d:cmp d. d:d. default-now d:default-now
Builtin  doy d:doy dst-ofs d:dst-ofs dst? d:dst? dstinfo d:dstinfo dstquery d:dstquery dstzones? d:dstzones?
Builtin  elapsed-timer d:elapsed-timer elapsed-timer-hmds d:elapsed-timer-hmds elapsed-timer-msec d:elapsed-timer-msec
Builtin  elapsed-timer-seconds d:elapsed-timer-seconds first-dow d:first-dow fixed> d:fixed> fixed>dow d:fixed>dow
Builtin  format d:format join d:join last-dow d:last-dow last-month d:last-month last-week d:last-week
Builtin  last-year d:last-year leap? d:leap? mdays d:mdays msec d:msec msec> d:msec> new d:new next-dow d:next-dow
Builtin  next-month d:next-month next-week d:next-week next-year d:next-year parse d:parse parse-approx d:parse-approx
Builtin  parse-range d:parse-range prev-dow d:prev-dow rfc5322 d:rfc5322 start-timer d:start-timer ticks d:ticks
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
Builtin  trace dbg:trace trace-enter dbg:trace-enter trace-leave dbg:trace-leave pso ds:pso / f:/ >posix f:>posix
Builtin  abspath f:abspath absrel f:absrel append f:append associate f:associate atime f:atime autodel f:autodel
Builtin  canwrite? f:canwrite? chmod f:chmod close f:close copy f:copy copydir f:copydir create f:create
Builtin  ctime f:ctime dir? f:dir? dname f:dname eachbuf f:eachbuf eachline f:eachline enssep f:enssep
Builtin  eof? f:eof? exec f:exec exists? f:exists? flush f:flush fname f:fname getb f:getb getc f:getc
Builtin  getline f:getline getmod f:getmod glob f:glob glob-links f:glob-links glob-nocase f:glob-nocase
Builtin  gunz f:gunz homedir f:homedir homedir! f:homedir! include f:include ioctl f:ioctl join f:join
Builtin  launch f:launch link f:link link> f:link> link? f:link? lock f:lock mkdir f:mkdir mmap f:mmap
Builtin  mmap-range f:mmap-range mmap-range? f:mmap-range? mtime f:mtime mv f:mv name@ f:name@ open f:open
Builtin  open! f:open! open-ro f:open-ro popen f:popen popen3 f:popen3 print f:print read f:read read-buf f:read-buf
Builtin  read? f:read? relpath f:relpath rglob f:rglob rm f:rm rmdir f:rmdir seek f:seek sep f:sep size f:size
Builtin  slurp f:slurp sparse? f:sparse? spit f:spit stderr f:stderr stdin f:stdin stdout f:stdout tell f:tell
Builtin  tempfile f:tempfile times f:times tmpspit f:tmpspit trash f:trash truncate f:truncate ungetb f:ungetb
Builtin  ungetc f:ungetc unzip f:unzip unzip-entry f:unzip-entry watch f:watch write f:write writen f:writen
Builtin  zip+ f:zip+ zip@ f:zip@ zipentry f:zipentry zipnew f:zipnew zipopen f:zipopen zipsave f:zipsave
Builtin  atlas! font:atlas! atlas@ font:atlas@ default-size font:default-size default-size@ font:default-size@
Builtin  info font:info ls font:ls measure font:measure new font:new oversample font:oversample pixels font:pixels
Builtin  pixels? font:pixels? system font:system system font:system media? g:media? distance geo:distance
Builtin  km/deg-lat geo:km/deg-lat km/deg-lon geo:km/deg-lon nearest geo:nearest +edge gr:+edge +edge+w gr:+edge+w
Builtin  +node gr:+node connect gr:connect edges gr:edges edges! gr:edges! m! gr:m! m@ gr:m@ neighbors gr:neighbors
Builtin  new gr:new node-edges gr:node-edges nodes gr:nodes traverse gr:traverse weight! gr:weight!
Builtin  + h:+ clear h:clear cmp! h:cmp! len h:len max! h:max! new h:new peek h:peek pop h:pop push h:push
Builtin  unique h:unique parse html:parse arm? hw:arm? camera hw:camera camera-img hw:camera-img camera-limits hw:camera-limits
Builtin  camera? hw:camera? cpu? hw:cpu? device? hw:device? displays? hw:displays? displaysize? hw:displaysize?
Builtin  finger-match hw:finger-match finger-support hw:finger-support gpio hw:gpio gpio! hw:gpio! gpio-mmap hw:gpio-mmap
Builtin  gpio@ hw:gpio@ i2c hw:i2c i2c! hw:i2c! i2c!reg hw:i2c!reg i2c@ hw:i2c@ i2c@reg hw:i2c@reg isround? hw:isround?
Builtin  iswatch? hw:iswatch? mac? hw:mac? mem? hw:mem? model? hw:model? poll hw:poll sensor hw:sensor
Builtin  start hw:start stop hw:stop touch? hw:touch? uid? hw:uid? fetch-full imap:fetch-full fetch-uid-mail imap:fetch-uid-mail
Builtin  login imap:login logout imap:logout new imap:new search imap:search select-inbox imap:select-inbox
Builtin  >file img:>file >fmt img:>fmt copy img:copy crop img:crop data img:data desat img:desat draw img:draw
Builtin  draw-sub img:draw-sub fill img:fill fillrect img:fillrect filter img:filter flip img:flip from-svg img:from-svg
Builtin  line img:line new img:new pikchr img:pikchr pix! img:pix! pix@ img:pix@ qr-gen img:qr-gen qr-parse img:qr-parse
Builtin  rect img:rect rotate img:rotate scale img:scale scroll img:scroll size img:size countries iso:countries
Builtin  languages iso:languages utils/help library:utils/help bearing loc:bearing find loc:find sort loc:sort
Builtin  ! m:! !? m:!? + m:+ +? m:+? - m:- <> m:<> = m:= >arr m:>arr @ m:@ @? m:@? _! m:_! _@ m:_@ _@? m:_@?
Builtin  alias m:alias arr> m:arr> bitmap m:bitmap clear m:clear data m:data each m:each exists? m:exists?
Builtin  filter m:filter ic m:ic iter m:iter iter-all m:iter-all keys m:keys len m:len map m:map merge m:merge
Builtin  new m:new op! m:op! open m:open slice m:slice vals m:vals xchg m:xchg zip m:zip ! mat:! * mat:*
Builtin  + mat:+ = mat:= @ mat:@ affine mat:affine col mat:col data mat:data det mat:det dim? mat:dim?
Builtin  get-n mat:get-n ident mat:ident inv mat:inv m. mat:m. minor mat:minor n* mat:n* new mat:new
Builtin  new-minor mat:new-minor rotate mat:rotate row mat:row same-size? mat:same-size? scale mat:scale
Builtin  shear mat:shear trans mat:trans translate mat:translate xform mat:xform 2console md:2console
Builtin  2html md:2html 2nk md:2nk color meta:color console meta:console gui meta:gui meta meta:meta
Builtin  ! n:! * n:* */ n:*/ + n:+ +! n:+! - n:- / n:/ /mod n:/mod 1+ n:1+ 1- n:1- < n:< = n:= > n:>
Builtin  >bool n:>bool BIGE n:BIGE BIGPI n:BIGPI E n:E PI n:PI ^ n:^ _mod n:_mod abs n:abs acos n:acos
Builtin  acosd n:acosd acosh n:acosh andor n:andor asin n:asin asind n:asind asinh n:asinh atan n:atan
Builtin  atan2 n:atan2 atand n:atand atanh n:atanh band n:band between n:between bfloat n:bfloat bic n:bic
Builtin  bint n:bint binv n:binv bnot n:bnot bor n:bor bxor n:bxor cast n:cast ceil n:ceil clamp n:clamp
Builtin  cmp n:cmp comb n:comb cos n:cos cosd n:cosd cosh n:cosh emod n:emod erf n:erf erfc n:erfc exp n:exp
Builtin  expm1 n:expm1 expmod n:expmod float n:float floor n:floor fmod n:fmod frac n:frac gcd n:gcd
Builtin  int n:int invmod n:invmod kind? n:kind? lcm n:lcm lerp n:lerp ln n:ln ln1p n:ln1p lnerp n:lnerp
Builtin  logistic n:logistic max n:max median n:median min n:min mod n:mod neg n:neg odd? n:odd? perm n:perm
Builtin  prime? n:prime? quantize n:quantize quantize! n:quantize! r+ n:r+ range n:range rot32l n:rot32l
Builtin  rot32r n:rot32r round n:round round2 n:round2 rounding n:rounding running-variance n:running-variance
Builtin  running-variance-finalize n:running-variance-finalize sgn n:sgn shl n:shl shr n:shr sin n:sin
Builtin  sincos n:sincos sind n:sind sinh n:sinh sqr n:sqr sqrt n:sqrt tan n:tan tand n:tand tanh n:tanh
Builtin  trunc n:trunc ~= n:~= ! net:! !? net:!? - net:- >base64url net:>base64url >url net:>url @ net:@
Builtin  @? net:@? CGI net:CGI DGRAM net:DGRAM INET4 net:INET4 INET6 net:INET6 PROTO_TCP net:PROTO_TCP
Builtin  PROTO_UDP net:PROTO_UDP REMOTE_IP net:REMOTE_IP REMOTE_IP net:REMOTE_IP STREAM net:STREAM accept net:accept
Builtin  active? net:active? addrinfo>o net:addrinfo>o again? net:again? alloc-and-read net:alloc-and-read
Builtin  alloc-buf net:alloc-buf avail? net:avail? base64url> net:base64url> bind net:bind cgi-get net:cgi-get
Builtin  cgi-http-header net:cgi-http-header cgi-init net:cgi-init cgi-init-stunnel net:cgi-init-stunnel
Builtin  cgi-out net:cgi-out close net:close closed? net:closed? connect net:connect curnet net:curnet
Builtin  debug? net:debug? delete net:delete dns net:dns get net:get getaddrinfo net:getaddrinfo getpeername net:getpeername
Builtin  head net:head ifaces? net:ifaces? ipv6? net:ipv6? launch net:launch listen net:listen map>url net:map>url
Builtin  mime-type net:mime-type net-socket net:net-socket opts net:opts port-is-ssl? net:port-is-ssl?
Builtin  post net:post proxy! net:proxy! put net:put read net:read read-all net:read-all read-buf net:read-buf
Builtin  recvfrom net:recvfrom s>url net:s>url sendto net:sendto server net:server setsockopt net:setsockopt
Builtin  socket net:socket tcp-connect net:tcp-connect tlserr net:tlserr tlshello net:tlshello udp-connect net:udp-connect
Builtin  url> net:url> user-agent net:user-agent valid-email? net:valid-email? vpncheck net:vpncheck
Builtin  wait net:wait webserver net:webserver write net:write (begin) nk:(begin) (chart-begin) nk:(chart-begin)
Builtin  (chart-begin-colored) nk:(chart-begin-colored) (chart-end) nk:(chart-end) (end) nk:(end) (group-begin) nk:(group-begin)
Builtin  (group-end) nk:(group-end) (property) nk:(property) >img nk:>img GLLIBS nk:GLLIBS GLXLIBS nk:GLXLIBS
Builtin  addfont nk:addfont anti-alias nk:anti-alias any-clicked? nk:any-clicked? bounds nk:bounds bounds! nk:bounds!
Builtin  button nk:button button-color nk:button-color button-label nk:button-label button-set-behavior nk:button-set-behavior
Builtin  button-symbol nk:button-symbol button-symbol-label nk:button-symbol-label chart-add-slot nk:chart-add-slot
Builtin  chart-add-slot-colored nk:chart-add-slot-colored chart-push nk:chart-push chart-push-slot nk:chart-push-slot
Builtin  checkbox nk:checkbox circle nk:circle clicked? nk:clicked? close-this! nk:close-this! close-this? nk:close-this?
Builtin  close? nk:close? color-chooser nk:color-chooser color-picker nk:color-picker combo nk:combo
Builtin  combo-begin-color nk:combo-begin-color combo-begin-label nk:combo-begin-label combo-cb nk:combo-cb
Builtin  combo-end nk:combo-end contextual-begin nk:contextual-begin contextual-close nk:contextual-close
Builtin  contextual-end nk:contextual-end contextual-item-image-text nk:contextual-item-image-text contextual-item-symbol-text nk:contextual-item-symbol-text
Builtin  contextual-item-text nk:contextual-item-text cp! nk:cp! cp@ nk:cp@ curpos nk:curpos cursor-load nk:cursor-load
Builtin  cursor-set nk:cursor-set cursor-show nk:cursor-show display-info nk:display-info display@ nk:display@
Builtin  do nk:do down? nk:down? draw-image nk:draw-image draw-image-at nk:draw-image-at draw-image-centered nk:draw-image-centered
Builtin  draw-sub-image nk:draw-sub-image draw-text nk:draw-text draw-text-centered nk:draw-text-centered
Builtin  draw-text-high nk:draw-text-high draw-text-wrap nk:draw-text-wrap driver nk:driver drivers nk:drivers
Builtin  dropped nk:dropped dropping nk:dropping edit-focus nk:edit-focus edit-string nk:edit-string
Builtin  event nk:event event-boost nk:event-boost event-msec nk:event-msec event-wait nk:event-wait
Builtin  event? nk:event? fill-arc nk:fill-arc fill-circle nk:fill-circle fill-color nk:fill-color fill-poly nk:fill-poly
Builtin  fill-rect nk:fill-rect fill-rect-color nk:fill-rect-color fill-triangle nk:fill-triangle finger nk:finger
Builtin  flags! nk:flags! flags@ nk:flags@ flash nk:flash fullscreen nk:fullscreen gesture nk:gesture
Builtin  get nk:get get-row-height nk:get-row-height getfont nk:getfont getmap nk:getmap getmap! nk:getmap!
Builtin  gl? nk:gl? grid nk:grid grid-peek nk:grid-peek grid-push nk:grid-push group-scroll-ofs nk:group-scroll-ofs
Builtin  group-scroll-ofs! nk:group-scroll-ofs! hints nk:hints hovered? nk:hovered? hrule nk:hrule image nk:image
Builtin  init nk:init input-button nk:input-button input-key nk:input-key input-motion nk:input-motion
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
Builtin  rect>screen nk:rect>screen released? nk:released? render nk:render render-timed nk:render-timed
Builtin  rendering nk:rendering restore nk:restore rotate nk:rotate rotate-rel nk:rotate-rel rtl! nk:rtl!
Builtin  rtl? nk:rtl? save nk:save scale nk:scale scancode? nk:scancode? screen-saver nk:screen-saver
Builtin  screen-size nk:screen-size screen-win-close nk:screen-win-close selectable nk:selectable set nk:set
Builtin  set-font nk:set-font set-num-vertices nk:set-num-vertices set-radius nk:set-radius setpos nk:setpos
Builtin  setwin nk:setwin show nk:show slider nk:slider slider-int nk:slider-int space nk:space spacing nk:spacing
Builtin  stroke-arc nk:stroke-arc stroke-circle nk:stroke-circle stroke-curve nk:stroke-curve stroke-line nk:stroke-line
Builtin  stroke-polygon nk:stroke-polygon stroke-polyline nk:stroke-polyline stroke-rect nk:stroke-rect
Builtin  stroke-tri nk:stroke-tri style-from-table nk:style-from-table swipe nk:swipe swipe-dir-threshold nk:swipe-dir-threshold
Builtin  swipe-threshold nk:swipe-threshold text nk:text text-align nk:text-align text-font nk:text-font
Builtin  text-pad nk:text-pad text? nk:text? timer-delay nk:timer-delay timer? nk:timer? toast nk:toast
Builtin  tooltip nk:tooltip translate nk:translate tree-pop nk:tree-pop tree-state-push nk:tree-state-push
Builtin  triangle nk:triangle use-style nk:use-style vsync nk:vsync widget nk:widget widget-bounds nk:widget-bounds
Builtin  widget-disable nk:widget-disable widget-fitting nk:widget-fitting widget-high nk:widget-high
Builtin  widget-hovered? nk:widget-hovered? widget-mouse-click-down? nk:widget-mouse-click-down? widget-mouse-clicked? nk:widget-mouse-clicked?
Builtin  widget-pos nk:widget-pos widget-size nk:widget-size widget-size-allot nk:widget-size-allot
Builtin  widget-wide nk:widget-wide win nk:win win-bounds nk:win-bounds win-bounds! nk:win-bounds! win-close nk:win-close
Builtin  win-closed? nk:win-closed? win-collapse nk:win-collapse win-collapsed? nk:win-collapsed? win-content-bounds nk:win-content-bounds
Builtin  win-focus nk:win-focus win-focused? nk:win-focused? win-hidden? nk:win-hidden? win-high nk:win-high
Builtin  win-hovered? nk:win-hovered? win-icon! nk:win-icon! win-pos nk:win-pos win-scroll-ofs nk:win-scroll-ofs
Builtin  win-scroll-ofs! nk:win-scroll-ofs! win-show nk:win-show win-size nk:win-size win-title! nk:win-title!
Builtin  win-wide nk:win-wide win? nk:win? MAX ns:MAX ! o:! + o:+ +? o:+? ??? o:??? @ o:@ class o:class
Builtin  exec o:exec isa o:isa method o:method mutate o:mutate new o:new super o:super POSIX os:POSIX
Builtin  chroot os:chroot devname os:devname docker? os:docker? env os:env lang os:lang locales os:locales
Builtin  notify os:notify power-state os:power-state region os:region waitpid os:waitpid bezier pdf:bezier
Builtin  bezierq pdf:bezierq circle pdf:circle color pdf:color ellipse pdf:ellipse font pdf:font img pdf:img
Builtin  line pdf:line new pdf:new page pdf:page page-size pdf:page-size rect pdf:rect save pdf:save
Builtin  size pdf:size text pdf:text text-rotate pdf:text-rotate text-size pdf:text-size text-width pdf:text-width
Builtin  text-wrap pdf:text-wrap text-wrap-rotate pdf:text-wrap-rotate cast ptr:cast deref ptr:deref
Builtin  len ptr:len null? ptr:null? pack ptr:pack unpack ptr:unpack unpack_orig ptr:unpack_orig publish pubsub:publish
Builtin  qsize pubsub:qsize subscribe pubsub:subscribe + q:+ clear q:clear len q:len new q:new notify q:notify
Builtin  overwrite q:overwrite peek q:peek pick q:pick pop q:pop push q:push remove q:remove shift q:shift
Builtin  size q:size slide q:slide throwing q:throwing wait q:wait ++match r:++match +/ r:+/ +match r:+match
Builtin  / r:/ @ r:@ len r:len match r:match match[] r:match[] matchall[] r:matchall[] new r:new rx r:rx
Builtin  str r:str * rat:* + rat:+ - rat:- / rat:/ >n rat:>n >s rat:>s new rat:new proper rat:proper
Builtin  ! rect:! /high rect:/high /wide rect:/wide = rect:= >a rect:>a >pts rect:>pts >pts4 rect:>pts4
Builtin  @ rect:@ center rect:center center-pt rect:center-pt intersect rect:intersect new rect:new
Builtin  new-pt rect:new-pt ofs rect:ofs open rect:open pad rect:pad pos rect:pos pt-open rect:pt-open
Builtin  pt>a rect:pt>a pt>rect rect:pt>rect pts> rect:pts> restrict rect:restrict shrink rect:shrink
Builtin  size rect:size union rect:union ! s:! * s:* + s:+ - s:- / s:/ /scripts s:/scripts /ws s:/ws
Builtin  2len s:2len <+ s:<+ <> s:<> = s:= =ic s:=ic >base64 s:>base64 >ucs2 s:>ucs2 @ s:@ _len s:_len
Builtin  append s:append base64> s:base64> clear s:clear cmp s:cmp cmpi s:cmpi compress s:compress count-match s:count-match
Builtin  days! s:days! dist s:dist each s:each each! s:each! eachline s:eachline escape s:escape expand s:expand
Builtin  fill s:fill fold s:fold gen-uid s:gen-uid globmatch s:globmatch hexupr s:hexupr insert s:insert
Builtin  intl s:intl intl! s:intl! lang s:lang lc s:lc lc? s:lc? len s:len lsub s:lsub ltrim s:ltrim
Builtin  map s:map months! s:months! n> s:n> new s:new norm s:norm reduce s:reduce repinsert s:repinsert
Builtin  replace s:replace replace! s:replace! rev s:rev rsearch s:rsearch rsub s:rsub rtl s:rtl rtrim s:rtrim
Builtin  scan-match s:scan-match script? s:script? search s:search size s:size slice s:slice soundex s:soundex
Builtin  strfmap s:strfmap strfmt s:strfmt term s:term text-wrap s:text-wrap tr s:tr translate s:translate
Builtin  trim s:trim tsub s:tsub uc s:uc uc? s:uc? ucs2> s:ucs2> utf8? s:utf8? zt s:zt close sio:close
Builtin  enum sio:enum open sio:open opts! sio:opts! opts@ sio:opts@ read sio:read write sio:write @ slv:@
Builtin  auto slv:auto build slv:build constraint slv:constraint dump slv:dump edit slv:edit named-variable slv:named-variable
Builtin  new slv:new relation slv:relation reset slv:reset suggest slv:suggest term slv:term update slv:update
Builtin  v[] slv:v[] variable slv:variable v{} slv:v{} new smtp:new send smtp:send apply-filter snd:apply-filter
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
Builtin  setq t:setq task t:task task-n t:task-n task-stop t:task-stop ticks t:ticks wait t:wait add tree:add
Builtin  binary tree:binary bk tree:bk btree tree:btree cmp! tree:cmp! data tree:data del tree:del find tree:find
Builtin  iter tree:iter next tree:next nodes tree:nodes parent tree:parent parse tree:parse prev tree:prev
Builtin  root tree:root search tree:search trie tree:trie ! w:! (is) w:(is) @ w:@ alias: w:alias: cb w:cb
Builtin  deprecate w:deprecate dlcall w:dlcall dlopen w:dlopen dlsym w:dlsym exec w:exec exec? w:exec?
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
syn region eighthComment start="\zs(\*\_[:space:]" end="\_[:space:]\*)\ze" contains=eightTodo,@Spell

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
