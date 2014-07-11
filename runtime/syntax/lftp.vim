" Vim syntax file
" Language:         lftp(1) configuration file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2007-06-17

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

setlocal iskeyword+=-

syn region  lftpComment         display oneline start='#' end='$'
                                \ contains=lftpTodo,@Spell

syn keyword lftpTodo            contained TODO FIXME XXX NOTE

syn region  lftpString          contained display
                                \ start=+"+ skip=+\\$\|\\"+ end=+"+ end=+$+

syn match   lftpNumber          contained display '\<\d\+\(\.\d\+\)\=\>'

syn keyword lftpBoolean         contained yes no on off true false

syn keyword lftpInterval        contained infinity inf never forever
syn match   lftpInterval        contained '\<\(\d\+\(\.\d\+\)\=[dhms]\)\+\>'

syn keyword lftpKeywords        alias anon at bookmark cache cat cd chmod close
                                \ cls command debug du echo exit fg find get
                                \ get1 glob help history jobs kill lcd lftp
                                \ lpwd ls mget mirror mkdir module more mput
                                \ mrm mv nlist open pget put pwd queue quote
                                \ reget recls rels renlist repeat reput rm
                                \ rmdir scache site source suspend user version
                                \ wait zcat zmore

syn region  lftpSet             matchgroup=lftpKeywords
                                \ start="set" end=";" end="$"
                                \ contains=lftpString,lftpNumber,lftpBoolean,
                                \ lftpInterval,lftpSettingsPrefix,lftpSettings
syn match   lftpSettingsPrefix  contained '\<\%(bmk\|cache\|cmd\|color\|dns\):'
syn match   lftpSettingsPrefix  contained '\<\%(file\|fish\|ftp\|hftp\):'
syn match   lftpSettingsPrefix  contained '\<\%(http\|https\|mirror\|module\):'
syn match   lftpSettingsPrefix  contained '\<\%(net\|sftp\|ssl\|xfer\):'
" bmk:
syn keyword lftpSettings        contained save-p[asswords]
" cache:
syn keyword lftpSettings        contained cache-em[pty-listings] en[able]
                                \ exp[ire] siz[e]
" cmd:
syn keyword lftpSettings        contained at[-exit] cls-c[ompletion-default]
                                \ cls-d[efault] cs[h-history]
                                \ default-p[rotocol] default-t[itle]
syn keyword lftpSettings        contained fai[l-exit] in[teractive]
                                \ lo[ng-running] ls[-default] mo[ve-background]
                                \ prom[pt]
                                \ rem[ote-completion]
                                \ save-c[wd-history] save-r[l-history]
                                \ set-t[erm-status] statu[s-interval]
                                \ te[rm-status] verb[ose] verify-h[ost]
                                \ verify-path verify-path[-cached]
" color:
syn keyword lftpSettings        contained dir[-colors] use-c[olor]
" dns:
syn keyword lftpSettings        contained S[RV-query] cache-en[able]
                                \ cache-ex[pire] cache-s[ize]
                                \ fat[al-timeout] o[rder] use-fo[rk]
" file:
syn keyword lftpSettings        contained ch[arset]
" fish:
syn keyword lftpSettings        contained connect[-program] sh[ell]
" ftp:
syn keyword lftpSettings        contained acct anon-p[ass] anon-u[ser]
                                \ au[to-sync-mode] b[ind-data-socket]
                                \ ch[arset] cli[ent] dev[ice-prefix]
                                \ fi[x-pasv-address] fxp-f[orce]
                                \ fxp-p[assive-source] h[ome] la[ng]
                                \ list-e[mpty-ok] list-o[ptions]
                                \ nop[-interval] pas[sive-mode]
                                \ port-i[pv4] port-r[ange] prox[y]
                                \ rest-l[ist] rest-s[tor]
                                \ retry-530 retry-530[-anonymous]
                                \ sit[e-group] skey-a[llow]
                                \ skey-f[orce] ssl-allow
                                \ ssl-allow[-anonymous] ssl-au[th]
                                \ ssl-f[orce] ssl-protect-d[ata]
                                \ ssl-protect-l[ist] stat-[interval]
                                \ sy[nc-mode] timez[one] use-a[bor]
                                \ use-fe[at] use-fx[p] use-hf[tp]
                                \ use-mdtm use-mdtm[-overloaded]
                                \ use-ml[sd] use-p[ret] use-q[uit]
                                \ use-site-c[hmod] use-site-i[dle]
                                \ use-site-u[time] use-siz[e]
                                \ use-st[at] use-te[lnet-iac]
                                \ verify-a[ddress] verify-p[ort]
                                \ w[eb-mode]
" hftp:
syn keyword lftpSettings        contained w[eb-mode] cache prox[y]
                                \ use-au[thorization] use-he[ad] use-ty[pe]
" http:
syn keyword lftpSettings        contained accept accept-c[harset]
                                \ accept-l[anguage] cache coo[kie]
                                \ pos[t-content-type] prox[y]
                                \ put-c[ontent-type] put-m[ethod] ref[erer]
                                \ set-c[ookies] user[-agent]
" https:
syn keyword lftpSettings        contained prox[y]
" mirror:
syn keyword lftpSettings        contained exc[lude-regex] o[rder]
                                \ parallel-d[irectories]
                                \ parallel-t[ransfer-count] use-p[get-n]
" module:
syn keyword lftpSettings        contained pat[h]
" net:
syn keyword lftpSettings        contained connection-l[imit]
                                \ connection-t[akeover] id[le] limit-m[ax]
                                \ limit-r[ate] limit-total-m[ax]
                                \ limit-total-r[ate] max-ret[ries] no-[proxy]
                                \ pe[rsist-retries] reconnect-interval-b[ase]
                                \ reconnect-interval-ma[x]
                                \ reconnect-interval-mu[ltiplier]
                                \ socket-bind-ipv4 socket-bind-ipv6
                                \ socket-bu[ffer] socket-m[axseg] timeo[ut]
" sftp:
syn keyword lftpSettings        contained connect[-program]
                                \ max-p[ackets-in-flight] prot[ocol-version]
                                \ ser[ver-program] size-r[ead] size-w[rite]
" ssl:
syn keyword lftpSettings        contained ca-f[ile] ca-p[ath] ce[rt-file]
                                \ crl-f[ile] crl-p[ath] k[ey-file]
                                \ verify-c[ertificate]
" xfer:
syn keyword lftpSettings        contained clo[bber] dis[k-full-fatal]
                                \ eta-p[eriod] eta-t[erse] mak[e-backup]
                                \ max-red[irections] ra[te-period]

hi def link lftpComment         Comment
hi def link lftpTodo            Todo
hi def link lftpString          String
hi def link lftpNumber          Number
hi def link lftpBoolean         Boolean
hi def link lftpInterval        Number
hi def link lftpKeywords        Keyword
hi def link lftpSettingsPrefix  PreProc
hi def link lftpSettings        Type

let b:current_syntax = "lftp"

let &cpo = s:cpo_save
unlet s:cpo_save
