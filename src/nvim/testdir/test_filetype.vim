" Test :setfiletype

func Test_detection()
  filetype on
  augroup filetypedetect
    au BufNewFile,BufRead *	call assert_equal(1, did_filetype())
  augroup END
  new something.vim
  call assert_equal('vim', &filetype)

  bwipe!
  filetype off
endfunc

func Test_conf_type()
  filetype on
  call writefile(['# some comment', 'must be conf'], 'Xfile')
  augroup filetypedetect
    au BufNewFile,BufRead *	call assert_equal(0, did_filetype())
  augroup END
  split Xfile
  call assert_equal('conf', &filetype)

  bwipe!
  call delete('Xfile')
  filetype off
endfunc

func Test_other_type()
  filetype on
  augroup filetypedetect
    au BufNewFile,BufRead *	call assert_equal(0, did_filetype())
    au BufNewFile,BufRead Xfile	setf testfile
    au BufNewFile,BufRead *	call assert_equal(1, did_filetype())
  augroup END
  call writefile(['# some comment', 'must be conf'], 'Xfile')
  split Xfile
  call assert_equal('testfile', &filetype)

  bwipe!
  call delete('Xfile')
  filetype off
endfunc

" Filetypes detected just from matching the file name.
let s:filename_checks = {
    \ '8th': ['file.8th'],
    \ 'a2ps': ['/etc/a2ps.cfg', '/etc/a2ps/file.cfg', 'a2psrc', '.a2psrc'],
    \ 'a65': ['file.a65'],
    \ 'aap': ['file.aap'],
    \ 'abap': ['file.abap'],
    \ 'abc': ['file.abc'],
    \ 'abel': ['file.abl'],
    \ 'acedb': ['file.wrm'],
    \ 'ada': ['file.adb', 'file.ads', 'file.ada', 'file.gpr'],
    \ 'ahdl': ['file.tdf'],
    \ 'aidl': ['file.aidl'],
    \ 'alsaconf': ['.asoundrc', '/usr/share/alsa/alsa.conf', '/etc/asound.conf'],
    \ 'aml': ['file.aml'],
    \ 'ampl': ['file.run'],
    \ 'ant': ['build.xml'],
    \ 'apache': ['.htaccess', '/etc/httpd/file.conf', '/etc/apache2/sites-2/file.com', '/etc/apache2/some.config', '/etc/apache2/conf.file/conf', '/etc/apache2/mods-some/file', '/etc/apache2/sites-some/file', '/etc/httpd/conf.d/file.config'],
    \ 'apachestyle': ['/etc/proftpd/file.config,/etc/proftpd/conf.file/file'],
    \ 'applescript': ['file.scpt'],
    \ 'aptconf': ['apt.conf', '/.aptitude/config'],
    \ 'arch': ['.arch-inventory'],
    \ 'arduino': ['file.ino', 'file.pde'],
    \ 'art': ['file.art'],
    \ 'asciidoc': ['file.asciidoc', 'file.adoc'],
    \ 'asn': ['file.asn', 'file.asn1'],
    \ 'atlas': ['file.atl', 'file.as'],
    \ 'autohotkey': ['file.ahk'],
    \ 'autoit': ['file.au3'],
    \ 'automake': ['GNUmakefile.am'],
    \ 'ave': ['file.ave'],
    \ 'awk': ['file.awk', 'file.gawk'],
    \ 'b': ['file.mch', 'file.ref', 'file.imp'],
    \ 'bzl': ['file.bazel', 'file.bzl', 'WORKSPACE'],
    \ 'bc': ['file.bc'],
    \ 'bdf': ['file.bdf'],
    \ 'bib': ['file.bib'],
    \ 'beancount': ['file.beancount'],
    \ 'bindzone': ['named.root'],
    \ 'blank': ['file.bl'],
    \ 'bsdl': ['file.bsd', 'file.bsdl'],
    \ 'bst': ['file.bst'],
    \ 'bzr': ['bzr_log.any'],
    \ 'c': ['enlightenment/file.cfg', 'file.qc', 'file.c'],
    \ 'cabal': ['file.cabal'],
    \ 'cabalconfig': ['cabal.config'],
    \ 'cabalproject': ['cabal.project', 'cabal.project.local'],
    \ 'calendar': ['calendar'],
    \ 'catalog': ['catalog', 'sgml.catalogfile'],
    \ 'cdl': ['file.cdl'],
    \ 'cdrdaoconf': ['/etc/cdrdao.conf', '/etc/defaults/cdrdao', '/etc/default/cdrdao', '.cdrdao'],
    \ 'cdrtoc': ['file.toc'],
    \ 'cf': ['file.cfm', 'file.cfi', 'file.cfc'],
    \ 'cfengine': ['cfengine.conf'],
    \ 'cfg': ['file.cfg', 'file.hgrc', 'filehgrc'],
    \ 'ch': ['file.chf'],
    \ 'chaiscript': ['file.chai'],
    \ 'chaskell': ['file.chs'],
    \ 'chill': ['file..ch'],
    \ 'chordpro': ['file.chopro', 'file.crd', 'file.cho', 'file.crdpro', 'file.chordpro'],
    \ 'cl': ['file.eni'],
    \ 'clean': ['file.dcl', 'file.icl'],
    \ 'clojure': ['file.clj', 'file.cljs', 'file.cljx', 'file.cljc'],
    \ 'cmake': ['CMakeLists.txt', 'file.cmake', 'file.cmake.in'],
    \ 'cmusrc': ['any/.cmus/autosave', 'any/.cmus/rc', 'any/.cmus/command-history', 'any/.cmus/file.theme', 'any/cmus/rc', 'any/cmus/file.theme'],
    \ 'cobol': ['file.cbl', 'file.cob', 'file.lib'],
    \ 'coco': ['file.atg'],
    \ 'conaryrecipe': ['file.recipe'],
    \ 'conf': ['auto.master'],
    \ 'config': ['configure.in', 'configure.ac', 'Pipfile'],
    \ 'context': ['tex/context/any/file.tex', 'file.mkii', 'file.mkiv', 'file.mkvi', 'file.mkxl', 'file.mklx'],
    \ 'cpp': ['file.cxx', 'file.c++', 'file.hh', 'file.hxx', 'file.hpp', 'file.ipp', 'file.moc', 'file.tcc', 'file.inl', 'file.tlh'],
    \ 'crm': ['file.crm'],
    \ 'cs': ['file.cs'],
    \ 'csc': ['file.csc'],
    \ 'csdl': ['file.csdl'],
    \ 'csp': ['file.csp', 'file.fdr'],
    \ 'css': ['file.css'],
    \ 'cterm': ['file.con'],
    \ 'cucumber': ['file.feature'],
    \ 'cuda': ['file.cu'],
    \ 'cupl': ['file.pld'],
    \ 'cuplsim': ['file.si'],
    \ 'cvs': ['cvs123'],
    \ 'cvsrc': ['.cvsrc'],
    \ 'cynpp': ['file.cyn'],
    \ 'dart': ['file.dart', 'file.drt'],
    \ 'datascript': ['file.ds'],
    \ 'dcd': ['file.dcd'],
    \ 'debchangelog': ['changelog.Debian', 'changelog.dch', 'NEWS.Debian', 'NEWS.dch', '/debian/changelog'],
    \ 'debcontrol': ['/debian/control'],
    \ 'debsources': ['/etc/apt/sources.list', '/etc/apt/sources.list.d/file.list'],
    \ 'def': ['file.def'],
    \ 'denyhosts': ['denyhosts.conf'],
    \ 'desc': ['file.desc'],
    \ 'desktop': ['file.desktop', '.directory', 'file.directory'],
    \ 'dictconf': ['dict.conf', '.dictrc'],
    \ 'dictdconf': ['dictd.conf'],
    \ 'diff': ['file.diff', 'file.rej'],
    \ 'dircolors': ['.dir_colors', '.dircolors', '/etc/DIR_COLORS'],
    \ 'dnsmasq': ['/etc/dnsmasq.conf'],
    \ 'dockerfile': ['Dockerfile', 'file.Dockerfile'],
    \ 'dosbatch': ['file.bat', 'file.sys'],
    \ 'dosini': ['.editorconfig', '/etc/pacman.conf', '/etc/yum.conf', 'file.ini', 'npmrc', '.npmrc', 'php.ini', 'php.ini-5'],
    \ 'dot': ['file.dot', 'file.gv'],
    \ 'dracula': ['file.drac', 'file.drc', 'filelvs', 'filelpe'],
    \ 'dsl': ['file.dsl'],
    \ 'dtd': ['file.dtd'],
    \ 'dts': ['file.dts', 'file.dtsi'],
    \ 'dune': ['jbuild', 'dune', 'dune-project', 'dune-workspace'],
    \ 'dylan': ['file.dylan'],
    \ 'dylanintr': ['file.intr'],
    \ 'dylanlid': ['file.lid'],
    \ 'ecd': ['file.ecd'],
    \ 'edif': ['file.edf', 'file.edif', 'file.edo'],
    \ 'elinks': ['elinks.conf'],
    \ 'elm': ['file.elm'],
    \ 'elmfilt': ['filter-rules'],
    \ 'epuppet': ['file.epp'],
    \ 'erlang': ['file.erl', 'file.hrl', 'file.yaws'],
    \ 'eruby': ['file.erb', 'file.rhtml'],
    \ 'esmtprc': ['anyesmtprc'],
    \ 'esqlc': ['file.ec', 'file.EC'],
    \ 'esterel': ['file.strl'],
    \ 'eterm': ['anyEterm/file.cfg'],
    \ 'exim': ['exim.conf'],
    \ 'expect': ['file.exp'],
    \ 'exports': ['exports'],
    \ 'factor': ['file.factor'],
    \ 'falcon': ['file.fal'],
    \ 'fan': ['file.fan', 'file.fwt'],
    \ 'fennel': ['file.fnl'],
    \ 'fetchmail': ['.fetchmailrc'],
    \ 'fgl': ['file.4gl', 'file.4gh', 'file.m4gl'],
    \ 'focexec': ['file.fex', 'file.focexec'],
    \ 'forth': ['file.fs', 'file.ft', 'file.fth'],
    \ 'fortran': ['file.f', 'file.for', 'file.fortran', 'file.fpp', 'file.ftn', 'file.f77', 'file.f90', 'file.f95', 'file.f03', 'file.f08'],
    \ 'framescript': ['file.fsl'],
    \ 'freebasic': ['file.fb', 'file.bi'],
    \ 'fstab': ['fstab', 'mtab'],
    \ 'gdb': ['.gdbinit'],
    \ 'gdmo': ['file.mo', 'file.gdmo'],
    \ 'gedcom': ['file.ged', 'lltxxxxx.txt'],
    \ 'gift': ['file.gift'],
    \ 'gitcommit': ['COMMIT_EDITMSG', 'MERGE_MSG', 'TAG_EDITMSG'],
    \ 'gitconfig': ['file.git/config', '.gitconfig', '.gitmodules', 'file.git/modules//config', '/.config/git/config', '/etc/gitconfig'],
    \ 'gitolite': ['gitolite.conf'],
    \ 'gitrebase': ['git-rebase-todo'],
    \ 'gitsendemail': ['.gitsendemail.msg.xxxxxx'],
    \ 'gkrellmrc': ['gkrellmrc', 'gkrellmrc_x'],
    \ 'gnash': ['gnashrc', '.gnashrc', 'gnashpluginrc', '.gnashpluginrc'],
    \ 'gnuplot': ['file.gpi'],
    \ 'go': ['file.go'],
    \ 'gp': ['file.gp', '.gprc'],
    \ 'gpg': ['/.gnupg/options', '/.gnupg/gpg.conf', '/usr/any/gnupg/options.skel'],
    \ 'grads': ['file.gs'],
    \ 'gretl': ['file.gretl'],
    \ 'groovy': ['file.gradle', 'file.groovy'],
    \ 'group': ['any/etc/group', 'any/etc/group-', 'any/etc/group.edit', 'any/etc/gshadow', 'any/etc/gshadow-', 'any/etc/gshadow.edit', 'any/var/backups/group.bak', 'any/var/backups/gshadow.bak'],
    \ 'grub': ['/boot/grub/menu.lst', '/boot/grub/grub.conf', '/etc/grub.conf'],
    \ 'gsp': ['file.gsp'],
    \ 'gtkrc': ['.gtkrc', 'gtkrc'],
    \ 'haml': ['file.haml'],
    \ 'hamster': ['file.hsm'],
    \ 'haskell': ['file.hs', 'file.hsc', 'file.hs-boot'],
    \ 'haste': ['file.ht'],
    \ 'hastepreproc': ['file.htpp'],
    \ 'hb': ['file.hb'],
    \ 'hercules': ['file.vc', 'file.ev', 'file.sum', 'file.errsum'],
    \ 'hex': ['file.hex', 'file.h32'],
    \ 'hgcommit': ['hg-editor-file.txt'],
    \ 'hog': ['file.hog', 'snort.conf', 'vision.conf'],
    \ 'hollywood': ['file.hws'],
    \ 'hostconf': ['/etc/host.conf'],
    \ 'hostsaccess': ['/etc/hosts.allow', '/etc/hosts.deny'],
    \ 'template': ['file.tmpl'],
    \ 'htmlm4': ['file.html.m4'],
    \ 'httest': ['file.htt', 'file.htb'],
    \ 'ibasic': ['file.iba', 'file.ibi'],
    \ 'icemenu': ['/.icewm/menu'],
    \ 'icon': ['file.icn'],
    \ 'indent': ['.indent.pro', 'indentrc'],
    \ 'inform': ['file.inf', 'file.INF'],
    \ 'initng': ['/etc/initng/any/file.i', 'file.ii'],
    \ 'inittab': ['inittab'],
    \ 'ipfilter': ['ipf.conf', 'ipf6.conf', 'ipf.rules'],
    \ 'iss': ['file.iss'],
    \ 'ist': ['file.ist', 'file.mst'],
    \ 'j': ['file.ijs'],
    \ 'jal': ['file.jal', 'file.JAL'],
    \ 'jam': ['file.jpl', 'file.jpr'],
    \ 'java': ['file.java', 'file.jav'],
    \ 'javacc': ['file.jj', 'file.jjt'],
    \ 'javascript': ['file.js', 'file.javascript', 'file.es', 'file.mjs', 'file.cjs'],
    \ 'javascriptreact': ['file.jsx'],
    \ 'jess': ['file.clp'],
    \ 'jgraph': ['file.jgr'],
    \ 'jovial': ['file.jov', 'file.j73', 'file.jovial'],
    \ 'jproperties': ['file.properties', 'file.properties_xx', 'file.properties_xx_xx'],
    \ 'json': ['file.json', 'file.jsonp', 'file.webmanifest', 'Pipfile.lock'],
    \ 'jsp': ['file.jsp'],
    \ 'kconfig': ['Kconfig', 'Kconfig.debug'],
    \ 'kivy': ['file.kv'],
    \ 'kix': ['file.kix'],
    \ 'kotlin': ['file.kt', 'file.ktm', 'file.kts'],
    \ 'kscript': ['file.ks'],
    \ 'kwt': ['file.k'],
    \ 'lace': ['file.ace', 'file.ACE'],
    \ 'latte': ['file.latte', 'file.lte'],
    \ 'ld': ['file.ld'],
    \ 'ldif': ['file.ldif'],
    \ 'less': ['file.less'],
    \ 'lex': ['file.lex', 'file.l', 'file.lxx', 'file.l++'],
    \ 'lftp': ['lftp.conf', '.lftprc', 'anylftp/rc'],
    \ 'lhaskell': ['file.lhs'],
    \ 'libao': ['/etc/libao.conf', '/.libao'],
    \ 'lifelines': ['file.ll'],
    \ 'lilo': ['lilo.conf'],
    \ 'limits': ['/etc/limits', '/etc/anylimits.conf', '/etc/anylimits.d/file.conf'],
    \ 'liquid': ['file.liquid'],
    \ 'lisp': ['file.lsp', 'file.lisp', 'file.el', 'file.cl', '.emacs', '.sawfishrc', 'sbclrc', '.sbclrc'],
    \ 'lite': ['file.lite', 'file.lt'],
    \ 'litestep': ['/LiteStep/any/file.rc'],
    \ 'loginaccess': ['/etc/login.access'],
    \ 'logindefs': ['/etc/login.defs'],
    \ 'logtalk': ['file.lgt'],
    \ 'lotos': ['file.lot', 'file.lotos'],
    \ 'lout': ['file.lou', 'file.lout'],
    \ 'lprolog': ['file.sig'],
    \ 'lsl': ['file.lsl'],
    \ 'lss': ['file.lss'],
    \ 'lua': ['file.lua', 'file.rockspec', 'file.nse'],
    \ 'lynx': ['lynx.cfg'],
    \ 'm4': ['file.at'],
    \ 'mail': ['snd.123', '.letter', '.letter.123', '.followup', '.article', '.article.123', 'pico.123', 'mutt-xx-xxx', 'muttng-xx-xxx', 'ae123.txt', 'file.eml'],
    \ 'mailaliases': ['/etc/mail/aliases', '/etc/aliases'],
    \ 'mailcap': ['.mailcap', 'mailcap'],
    \ 'make': ['file.mk', 'file.mak', 'file.dsp'],
    \ 'mallard': ['file.page'],
    \ 'manconf': ['/etc/man.conf', 'man.config'],
    \ 'map': ['file.map'],
    \ 'maple': ['file.mv', 'file.mpl', 'file.mws'],
    \ 'markdown': ['file.markdown', 'file.mdown', 'file.mkd', 'file.mkdn', 'file.mdwn', 'file.md'],
    \ 'mason': ['file.mason', 'file.mhtml', 'file.comp'],
    \ 'master': ['file.mas', 'file.master'],
    \ 'mel': ['file.mel'],
    \ 'meson': ['meson.build', 'meson_options.txt'],
    \ 'messages': ['/log/auth', '/log/cron', '/log/daemon', '/log/debug', '/log/kern', '/log/lpr', '/log/mail', '/log/messages', '/log/news/news', '/log/syslog', '/log/user',
    \     '/log/auth.log', '/log/cron.log', '/log/daemon.log', '/log/debug.log', '/log/kern.log', '/log/lpr.log', '/log/mail.log', '/log/messages.log', '/log/news/news.log', '/log/syslog.log', '/log/user.log',
    \     '/log/auth.err', '/log/cron.err', '/log/daemon.err', '/log/debug.err', '/log/kern.err', '/log/lpr.err', '/log/mail.err', '/log/messages.err', '/log/news/news.err', '/log/syslog.err', '/log/user.err',
    \      '/log/auth.info', '/log/cron.info', '/log/daemon.info', '/log/debug.info', '/log/kern.info', '/log/lpr.info', '/log/mail.info', '/log/messages.info', '/log/news/news.info', '/log/syslog.info', '/log/user.info',
    \      '/log/auth.warn', '/log/cron.warn', '/log/daemon.warn', '/log/debug.warn', '/log/kern.warn', '/log/lpr.warn', '/log/mail.warn', '/log/messages.warn', '/log/news/news.warn', '/log/syslog.warn', '/log/user.warn',
    \      '/log/auth.crit', '/log/cron.crit', '/log/daemon.crit', '/log/debug.crit', '/log/kern.crit', '/log/lpr.crit', '/log/mail.crit', '/log/messages.crit', '/log/news/news.crit', '/log/syslog.crit', '/log/user.crit',
    \      '/log/auth.notice', '/log/cron.notice', '/log/daemon.notice', '/log/debug.notice', '/log/kern.notice', '/log/lpr.notice', '/log/mail.notice', '/log/messages.notice', '/log/news/news.notice', '/log/syslog.notice', '/log/user.notice'],
    \ 'mf': ['file.mf'],
    \ 'mgl': ['file.mgl'],
    \ 'mgp': ['file.mgp'],
    \ 'mib': ['file.mib', 'file.my'],
    \ 'mix': ['file.mix', 'file.mixal'],
    \ 'mma': ['file.nb'],
    \ 'mmp': ['file.mmp'],
    \ 'modconf': ['/etc/modules.conf', '/etc/modules', '/etc/conf.modules'],
    \ 'modula2': ['file.m2', 'file.mi'],
    \ 'monk': ['file.isc', 'file.monk', 'file.ssc', 'file.tsc'],
    \ 'moo': ['file.moo'],
    \ 'mp': ['file.mp'],
    \ 'mplayerconf': ['mplayer.conf', '/.mplayer/config'],
    \ 'mrxvtrc': ['mrxvtrc', '.mrxvtrc'],
    \ 'msidl': ['file.odl', 'file.mof'],
    \ 'msql': ['file.msql'],
    \ 'mupad': ['file.mu'],
    \ 'mush': ['file.mush'],
    \ 'muttrc': ['Muttngrc', 'Muttrc'],
    \ 'mysql': ['file.mysql'],
    \ 'n1ql': ['file.n1ql', 'file.nql'],
    \ 'named': ['namedfile.conf', 'rndcfile.conf'],
    \ 'nanorc': ['/etc/nanorc', 'file.nanorc'],
    \ 'ncf': ['file.ncf'],
    \ 'netrc': ['.netrc'],
    \ 'ninja': ['file.ninja'],
    \ 'nqc': ['file.nqc'],
    \ 'nroff': ['file.tr', 'file.nr', 'file.roff', 'file.tmac', 'file.mom'],
    \ 'nsis': ['file.nsi', 'file.nsh'],
    \ 'obj': ['file.obj'],
    \ 'ocaml': ['file.ml', 'file.mli', 'file.mll', 'file.mly', '.ocamlinit', 'file.mlt', 'file.mlp', 'file.mlip', 'file.mli.cppo', 'file.ml.cppo'],
    \ 'occam': ['file.occ'],
    \ 'omnimark': ['file.xom', 'file.xin'],
    \ 'opam': ['opam', 'file.opam', 'file.opam.template'],
    \ 'openroad': ['file.or'],
    \ 'ora': ['file.ora'],
    \ 'pamconf': ['/etc/pam.conf'],
    \ 'pamenv': ['/etc/security/pam_env.conf', '/home/user/.pam_environment'],
    \ 'papp': ['file.papp', 'file.pxml', 'file.pxsl'],
    \ 'pascal': ['file.pas', 'file.dpr', 'file.lpr'],
    \ 'passwd': ['any/etc/passwd', 'any/etc/passwd-', 'any/etc/passwd.edit', 'any/etc/shadow', 'any/etc/shadow-', 'any/etc/shadow.edit', 'any/var/backups/passwd.bak', 'any/var/backups/shadow.bak'],
    \ 'pbtxt': ['file.pbtxt'],
    \ 'pccts': ['file.g'],
    \ 'pdf': ['file.pdf'],
    \ 'perl': ['file.plx', 'file.al', 'file.psgi', 'gitolite.rc', '.gitolite.rc', 'example.gitolite.rc'],
    \ 'perl6': ['file.p6', 'file.pm6', 'file.pl6', 'file.raku', 'file.rakumod'],
    \ 'pf': ['pf.conf'],
    \ 'pfmain': ['main.cf'],
    \ 'php': ['file.php', 'file.php9', 'file.phtml', 'file.ctp'],
    \ 'lpc': ['file.lpc', 'file.ulpc'],
    \ 'pike': ['file.pike', 'file.pmod'],
    \ 'cmod': ['file.cmod'],
    \ 'pilrc': ['file.rcp'],
    \ 'pine': ['.pinerc', 'pinerc', '.pinercex', 'pinercex'],
    \ 'pinfo': ['/etc/pinforc', '/.pinforc'],
    \ 'pli': ['file.pli', 'file.pl1'],
    \ 'plm': ['file.plm', 'file.p36', 'file.pac'],
    \ 'plp': ['file.plp'],
    \ 'plsql': ['file.pls', 'file.plsql'],
    \ 'po': ['file.po', 'file.pot'],
    \ 'pod': ['file.pod'],
    \ 'pod6': ['file.pod6'],
    \ 'poke': ['file.pk'],
    \ 'postscr': ['file.ps', 'file.pfa', 'file.afm', 'file.eps', 'file.epsf', 'file.epsi', 'file.ai'],
    \ 'pov': ['file.pov'],
    \ 'povini': ['.povrayrc'],
    \ 'ppd': ['file.ppd'],
    \ 'ppwiz': ['file.it', 'file.ih'],
    \ 'privoxy': ['file.action'],
    \ 'proc': ['file.pc'],
    \ 'procmail': ['.procmail', '.procmailrc'],
    \ 'prolog': ['file.pdb'],
    \ 'promela': ['file.pml'],
    \ 'proto': ['file.proto'],
    \ 'protocols': ['/etc/protocols'],
    \ 'psf': ['file.psf'],
    \ 'puppet': ['file.pp'],
    \ 'pyrex': ['file.pyx', 'file.pxd'],
    \ 'python': ['file.py', 'file.pyw', '.pythonstartup', '.pythonrc', 'file.ptl', 'file.pyi', 'SConstruct'],
    \ 'quake': ['anybaseq2/file.cfg', 'anyid1/file.cfg', 'quake3/file.cfg'],
    \ 'radiance': ['file.rad', 'file.mat'],
    \ 'ratpoison': ['.ratpoisonrc', 'ratpoisonrc'],
    \ 'rbs': ['file.rbs'],
    \ 'rc': ['file.rc', 'file.rch'],
    \ 'rcs': ['file,v'],
    \ 'readline': ['.inputrc', 'inputrc'],
    \ 'remind': ['.reminders', 'file.remind', 'file.rem'],
    \ 'rego': ['file.rego'],
    \ 'resolv': ['resolv.conf'],
    \ 'reva': ['file.frt'],
    \ 'rexx': ['file.rex', 'file.orx', 'file.rxo', 'file.rxj', 'file.jrexx', 'file.rexxj', 'file.rexx', 'file.testGroup', 'file.testUnit'],
    \ 'rib': ['file.rib'],
    \ 'rnc': ['file.rnc'],
    \ 'rng': ['file.rng'],
    \ 'robots': ['robots.txt'],
    \ 'rpcgen': ['file.x'],
    \ 'rpl': ['file.rpl'],
    \ 'rst': ['file.rst'],
    \ 'rtf': ['file.rtf'],
    \ 'ruby': ['.irbrc', 'irbrc', 'file.rb', 'file.rbw', 'file.gemspec', 'file.ru', 'Gemfile', 'file.builder', 'file.rxml', 'file.rjs', 'file.rant', 'file.rake', 'rakefile', 'Rakefile', 'rantfile', 'Rantfile', 'rakefile-file', 'Rakefile-file', 'Puppetfile'],
    \ 'rust': ['file.rs'],
    \ 'samba': ['smb.conf'],
    \ 'sas': ['file.sas'],
    \ 'sass': ['file.sass'],
    \ 'sather': ['file.sa'],
    \ 'sbt': ['file.sbt'],
    \ 'scala': ['file.scala'],
    \ 'scheme': ['file.scm', 'file.ss', 'file.rkt'],
    \ 'scilab': ['file.sci', 'file.sce'],
    \ 'screen': ['.screenrc', 'screenrc'],
    \ 'sexplib': ['file.sexp'],
    \ 'scss': ['file.scss'],
    \ 'sd': ['file.sd'],
    \ 'sdc': ['file.sdc'],
    \ 'sdl': ['file.sdl', 'file.pr'],
    \ 'sed': ['file.sed'],
    \ 'sensors': ['/etc/sensors.conf', '/etc/sensors3.conf'],
    \ 'services': ['/etc/services'],
    \ 'setserial': ['/etc/serial.conf'],
    \ 'sh': ['/etc/udev/cdsymlinks.conf'],
    \ 'sieve': ['file.siv', 'file.sieve'],
    \ 'simula': ['file.sim'],
    \ 'sinda': ['file.sin', 'file.s85'],
    \ 'sisu': ['file.sst', 'file.ssm', 'file.ssi', 'file.-sst', 'file._sst', 'file.sst.meta', 'file.-sst.meta', 'file._sst.meta'],
    \ 'skill': ['file.il', 'file.ils', 'file.cdf'],
    \ 'slang': ['file.sl'],
    \ 'slice': ['file.ice'],
    \ 'slpconf': ['/etc/slp.conf'],
    \ 'slpreg': ['/etc/slp.reg'],
    \ 'slpspi': ['/etc/slp.spi'],
    \ 'slrnrc': ['.slrnrc'],
    \ 'slrnsc': ['file.score'],
    \ 'sm': ['sendmail.cf'],
    \ 'svelte': ['file.svelte'],
    \ 'smarty': ['file.tpl'],
    \ 'smcl': ['file.hlp', 'file.ihlp', 'file.smcl'],
    \ 'smith': ['file.smt', 'file.smith'],
    \ 'sml': ['file.sml'],
    \ 'snobol4': ['file.sno', 'file.spt'],
    \ 'sparql': ['file.rq', 'file.sparql'],
    \ 'spec': ['file.spec'],
    \ 'spice': ['file.sp', 'file.spice'],
    \ 'spup': ['file.speedup', 'file.spdata', 'file.spd'],
    \ 'spyce': ['file.spy', 'file.spi'],
    \ 'sql': ['file.tyb', 'file.typ', 'file.tyc', 'file.pkb', 'file.pks'],
    \ 'sqlj': ['file.sqlj'],
    \ 'sqr': ['file.sqr', 'file.sqi'],
    \ 'squid': ['squid.conf'],
    \ 'srec': ['file.s19', 'file.s28', 'file.s37', 'file.mot', 'file.srec'],
    \ 'sshconfig': ['ssh_config', '/.ssh/config', '/etc/ssh/ssh_config.d/file.conf', 'any/etc/ssh/ssh_config.d/file.conf'],
    \ 'sshdconfig': ['sshd_config', '/etc/ssh/sshd_config.d/file.conf', 'any/etc/ssh/sshd_config.d/file.conf'],
    \ 'st': ['file.st'],
    \ 'stata': ['file.ado', 'file.do', 'file.imata', 'file.mata'],
    \ 'stp': ['file.stp'],
    \ 'sudoers': ['any/etc/sudoers', 'sudoers.tmp'],
    \ 'svg': ['file.svg'],
    \ 'svn': ['svn-commitfile.tmp'],
    \ 'swift': ['file.swift'],
    \ 'swiftgyb': ['file.swift.gyb'],
    \ 'sil': ['file.sil'],
    \ 'sysctl': ['/etc/sysctl.conf', '/etc/sysctl.d/file.conf'],
    \ 'systemd': ['any/systemd/file.automount', 'any/systemd/file.dnssd', 'any/systemd/file.link', 'any/systemd/file.mount', 'any/systemd/file.netdev', 'any/systemd/file.network', 'any/systemd/file.nspawn', 'any/systemd/file.path', 'any/systemd/file.service', 'any/systemd/file.slice', 'any/systemd/file.socket', 'any/systemd/file.swap', 'any/systemd/file.target', 'any/systemd/file.timer', '/etc/systemd/some.conf.d/file.conf', '/etc/systemd/system/some.d/file.conf', '/etc/systemd/system/some.d/.#file', '/etc/systemd/system/.#otherfile', '/home/user/.config/systemd/user/some.d/mine.conf', '/home/user/.config/systemd/user/some.d/.#file', '/home/user/.config/systemd/user/.#otherfile'],
    \ 'systemverilog': ['file.sv', 'file.svh'],
    \ 'tags': ['tags'],
    \ 'tak': ['file.tak'],
    \ 'taskdata': ['pending.data', 'completed.data', 'undo.data'],
    \ 'taskedit': ['file.task'],
    \ 'tcl': ['file.tcl', 'file.tk', 'file.itcl', 'file.itk', 'file.jacl'],
    \ 'teraterm': ['file.ttl'],
    \ 'terminfo': ['file.ti'],
    \ 'tex': ['file.latex', 'file.sty', 'file.dtx', 'file.ltx', 'file.bbl'],
    \ 'texinfo': ['file.texinfo', 'file.texi', 'file.txi'],
    \ 'texmf': ['texmf.cnf'],
    \ 'text': ['file.text', 'README'],
    \ 'tf': ['file.tf', '.tfrc', 'tfrc'],
    \ 'tidy': ['.tidyrc', 'tidyrc', 'tidy.conf'],
    \ 'tilde': ['file.t.html'],
    \ 'tli': ['file.tli'],
    \ 'tmux': ['tmuxfile.conf', '.tmuxfile.conf'],
    \ 'toml': ['file.toml'],
    \ 'tpp': ['file.tpp'],
    \ 'treetop': ['file.treetop'],
    \ 'trustees': ['trustees.conf'],
    \ 'tsalt': ['file.slt'],
    \ 'tsscl': ['file.tsscl'],
    \ 'tssgm': ['file.tssgm'],
    \ 'tssop': ['file.tssop'],
    \ 'twig': ['file.twig'],
    \ 'typescriptreact': ['file.tsx'],
    \ 'uc': ['file.uc'],
    \ 'udevconf': ['/etc/udev/udev.conf'],
    \ 'udevperm': ['/etc/udev/permissions.d/file.permissions'],
    \ 'udevrules': ['/etc/udev/rules.d/file.rules', '/usr/lib/udev/rules.d/file.rules', '/lib/udev/rules.d/file.rules'],
    \ 'uil': ['file.uit', 'file.uil'],
    \ 'updatedb': ['/etc/updatedb.conf'],
    \ 'upstart': ['/usr/share/upstart/file.conf', '/usr/share/upstart/file.override', '/etc/init/file.conf', '/etc/init/file.override', '/.init/file.conf', '/.init/file.override', '/.config/upstart/file.conf', '/.config/upstart/file.override'],
    \ 'upstreamdat': ['upstream.dat', 'UPSTREAM.DAT', 'upstream.file.dat', 'UPSTREAM.FILE.DAT', 'file.upstream.dat', 'FILE.UPSTREAM.DAT'],
    \ 'upstreaminstalllog': ['upstreaminstall.log', 'UPSTREAMINSTALL.LOG', 'upstreaminstall.file.log', 'UPSTREAMINSTALL.FILE.LOG', 'file.upstreaminstall.log', 'FILE.UPSTREAMINSTALL.LOG'],
    \ 'upstreamlog': ['fdrupstream.log', 'upstream.log', 'UPSTREAM.LOG', 'upstream.file.log', 'UPSTREAM.FILE.LOG', 'file.upstream.log', 'FILE.UPSTREAM.LOG', 'UPSTREAM-file.log', 'UPSTREAM-FILE.LOG'],
    \ 'usserverlog': ['usserver.log', 'USSERVER.LOG', 'usserver.file.log', 'USSERVER.FILE.LOG', 'file.usserver.log', 'FILE.USSERVER.LOG'],
    \ 'usw2kagtlog': ['usw2kagt.log', 'USW2KAGT.LOG', 'usw2kagt.file.log', 'USW2KAGT.FILE.LOG', 'file.usw2kagt.log', 'FILE.USW2KAGT.LOG'],
    \ 'vb': ['file.sba', 'file.vb', 'file.vbs', 'file.dsm', 'file.ctl'],
    \ 'vera': ['file.vr', 'file.vri', 'file.vrh'],
    \ 'verilog': ['file.v'],
    \ 'verilogams': ['file.va', 'file.vams'],
    \ 'vgrindefs': ['vgrindefs'],
    \ 'vhdl': ['file.hdl', 'file.vhd', 'file.vhdl', 'file.vbe', 'file.vst', 'file.vhdl_123', 'file.vho'],
    \ 'vim': ['file.vim', 'file.vba', '.exrc', '_exrc'],
    \ 'viminfo': ['.viminfo', '_viminfo'],
    \ 'vmasm': ['file.mar'],
    \ 'voscm': ['file.cm'],
    \ 'vrml': ['file.wrl'],
    \ 'vroom': ['file.vroom'],
    \ 'vue': ['file.vue'],
    \ 'wast': ['file.wast', 'file.wat'],
    \ 'webmacro': ['file.wm'],
    \ 'wget': ['.wgetrc', 'wgetrc'],
    \ 'winbatch': ['file.wbt'],
    \ 'wml': ['file.wml'],
    \ 'wsml': ['file.wsml'],
    \ 'wvdial': ['wvdial.conf', '.wvdialrc'],
    \ 'xdefaults': ['.Xdefaults', '.Xpdefaults', '.Xresources', 'xdm-config', 'file.ad'],
    \ 'xhtml': ['file.xhtml', 'file.xht'],
    \ 'xinetd': ['/etc/xinetd.conf'],
    \ 'xmath': ['file.msc', 'file.msf'],
    \ 'xml': ['/etc/blkid.tab', '/etc/blkid.tab.old', 'file.xmi', 'file.csproj', 'file.csproj.user', 'file.ui', 'file.tpm', '/etc/xdg/menus/file.menu', 'fglrxrc', 'file.xlf', 'file.xliff', 'file.xul', 'file.wsdl'],
    \ 'xmodmap': ['anyXmodmap'],
    \ 'xf86conf': ['xorg.conf', 'xorg.conf-4'],
    \ 'xpm2': ['file.xpm2'],
    \ 'xquery': ['file.xq', 'file.xql', 'file.xqm', 'file.xquery', 'file.xqy'],
    \ 'xs': ['file.xs'],
    \ 'xsd': ['file.xsd'],
    \ 'xslt': ['file.xsl', 'file.xslt'],
    \ 'yacc': ['file.yy', 'file.yxx', 'file.y++'],
    \ 'yaml': ['file.yaml', 'file.yml'],
    \ 'raml': ['file.raml'],
    \ 'z8a': ['file.z8a'],
    \ 'zimbu': ['file.zu'],
    \ 'zimbutempl': ['file.zut'],
    \ 'zsh': ['.zprofile', '/etc/zprofile', '.zfbfmarks', 'file.zsh'],
    \
    \ 'help': [$VIMRUNTIME . '/doc/help.txt'],
    \ 'xpm': ['file.xpm'],
    \ }

let s:filename_case_checks = {
    \ 'modula2': ['file.DEF', 'file.MOD'],
    \ 'bzl': ['file.BUILD', 'BUILD'],
    \ }

func CheckItems(checks)
  set noswapfile
  for [ft, names] in items(a:checks)
    for i in range(0, len(names) - 1)
      new
      try
        exe 'edit ' . fnameescape(names[i])
      catch
	call assert_report('cannot edit "' . names[i] . '": ' . v:exception)
      endtry
      if &filetype == '' && &readonly
	" File exists but not able to edit it (permission denied)
      else
	call assert_equal(ft, &filetype, 'with file name: ' . names[i])
      endif
      bwipe!
    endfor
  endfor
  set swapfile&
endfunc

func Test_filetype_detection()
  filetype on
  call CheckItems(s:filename_checks)
  if has('fname_case')
    call CheckItems(s:filename_case_checks)
  endif
  filetype off
endfunc

" Filetypes detected from the file contents by scripts.vim
let s:script_checks = {
      \ 'virata': [['% Virata'],
      \		['', '% Virata'],
      \		['', '', '% Virata'],
      \		['', '', '', '% Virata'],
      \		['', '', '', '', '% Virata']],
      \ 'strace': [['execve("/usr/bin/pstree", ["pstree"], 0x7ff0 /* 63 vars */) = 0'],
      \		['15:17:47 execve("/usr/bin/pstree", ["pstree"], ... "_=/usr/bin/strace"]) = 0'],
      \		['__libc_start_main and something']],
      \ 'clojure': [['#!/path/clojure']],
      \ 'scala': [['#!/path/scala']],
      \ 'tcsh': [['#!/path/tcsh']],
      \ 'zsh': [['#!/path/zsh']],
      \ 'tcl': [['#!/path/tclsh'],
      \         ['#!/path/wish'],
      \         ['#!/path/expectk'],
      \         ['#!/path/itclsh'],
      \         ['#!/path/itkwish']],
      \ 'expect': [['#!/path/expect']],
      \ 'gnuplot': [['#!/path/gnuplot']],
      \ 'make': [['#!/path/make']],
      \ 'pike': [['#!/path/pike'],
      \          ['#!/path/pike0'],
      \          ['#!/path/pike9']],
      \ 'lua': [['#!/path/lua']],
      \ 'perl6': [['#!/path/perl6']],
      \ 'perl': [['#!/path/perl']],
      \ 'php': [['#!/path/php']],
      \ 'python': [['#!/path/python'],
      \            ['#!/path/python2'],
      \            ['#!/path/python3']],
      \ 'groovy': [['#!/path/groovy']],
      \ 'ruby': [['#!/path/ruby']],
      \ 'javascript': [['#!/path/node'],
      \                ['#!/path/js'],
      \                ['#!/path/nodejs'],
      \                ['#!/path/rhino']],
      \ 'bc': [['#!/path/bc']],
      \ 'sed': [['#!/path/sed']],
      \ 'ocaml': [['#!/path/ocaml']],
      \ 'awk': [['#!/path/awk'],
      \         ['#!/path/gawk']],
      \ 'wml': [['#!/path/wml']],
      \ 'scheme': [['#!/path/scheme']],
      \ 'cfengine': [['#!/path/cfengine']],
      \ 'erlang': [['#!/path/escript']],
      \ 'haskell': [['#!/path/haskell']],
      \ 'cpp': [['// Standard iostream objects -*- C++ -*-'],
      \         ['// -*- C++ -*-']],
      \ 'yaml': [['%YAML 1.2']],
      \ 'pascal': [['#!/path/instantfpc']],
      \ 'fennel': [['#!/path/fennel']],
      \ }

" Various forms of "env" optional arguments.
let s:script_env_checks = {
      \ 'perl': [['#!/usr/bin/env VAR=val perl']],
      \ 'scala': [['#!/usr/bin/env VAR=val VVAR=vval scala']],
      \ 'awk': [['#!/usr/bin/env VAR=val -i awk']],
      \ 'scheme': [['#!/usr/bin/env VAR=val --ignore-environment scheme']],
      \ 'python': [['#!/usr/bin/env VAR=val -S python -w -T']],
      \ 'wml': [['#!/usr/bin/env VAR=val --split-string wml']],
      \ }

func Run_script_detection(test_dict)
  filetype on
  for [ft, files] in items(a:test_dict)
    for file in files
      call writefile(file, 'Xtest')
      split Xtest
      call assert_equal(ft, &filetype, 'for text: ' . string(file))
      bwipe!
    endfor
  endfor
  call delete('Xtest')
  filetype off
endfunc

func Test_script_detection()
  call Run_script_detection(s:script_checks)
  call Run_script_detection(s:script_env_checks)
endfunc

func Test_setfiletype_completion()
  call feedkeys(":setfiletype java\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"setfiletype java javacc javascript javascriptreact', @:)
endfunc

func Test_hook_file()
  filetype on

  call writefile(['[Trigger]', 'this is pacman config'], 'Xfile.hook')
  split Xfile.hook
  call assert_equal('dosini', &filetype)
  bwipe!

  call writefile(['not pacman'], 'Xfile.hook')
  split Xfile.hook
  call assert_notequal('dosini', &filetype)
  bwipe!

  call delete('Xfile.hook')
  filetype off
endfunc

func Test_ts_file()
  filetype on

  call writefile(['<?xml version="1.0" encoding="utf-8"?>'], 'Xfile.ts')
  split Xfile.ts
  call assert_equal('xml', &filetype)
  bwipe!

  call writefile(['// looks like Typescript'], 'Xfile.ts')
  split Xfile.ts
  call assert_equal('typescript', &filetype)
  bwipe!

  call delete('Xfile.hook')
  filetype off
endfunc

func Test_ttl_file()
  filetype on

  call writefile(['@base <http://example.org/> .'], 'Xfile.ttl')
  split Xfile.ttl
  call assert_equal('turtle', &filetype)
  bwipe!

  call writefile(['looks like Tera Term Language'], 'Xfile.ttl')
  split Xfile.ttl
  call assert_equal('teraterm', &filetype)
  bwipe!

  call delete('Xfile.ttl')
  filetype off
endfunc

func Test_pp_file()
  filetype on

  call writefile(['looks like puppet'], 'Xfile.pp')
  split Xfile.pp
  call assert_equal('puppet', &filetype)
  bwipe!

  let g:filetype_pp = 'pascal'
  split Xfile.pp
  call assert_equal('pascal', &filetype)
  bwipe!

  " Test dist#ft#FTpp()
  call writefile(['{ pascal comment'], 'Xfile.pp')
  split Xfile.pp
  call assert_equal('pascal', &filetype)
  bwipe!

  call writefile(['procedure pascal'], 'Xfile.pp')
  split Xfile.pp
  call assert_equal('pascal', &filetype)
  bwipe!

  call delete('Xfile.pp')
  filetype off
endfunc


" vim: shiftwidth=2 sts=2 expandtab
