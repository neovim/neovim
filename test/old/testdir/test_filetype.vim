" Test :setfiletype

func Test_backup_strip()
  filetype on
  let fname = 'Xdetect.js~~~~~~~~~~~'
  call writefile(['one', 'two', 'three'], fname, 'D')
  exe 'edit ' .. fname
  call assert_equal('javascript', &filetype)

  bwipe!
  filetype off
endfunc

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
  call writefile(['# some comment', 'must be conf'], 'Xconffile', 'D')
  augroup filetypedetect
    au BufNewFile,BufRead *	call assert_equal(0, did_filetype())
  augroup END
  split Xconffile
  call assert_equal('conf', &filetype)

  bwipe!
  filetype off
endfunc

func Test_other_type()
  filetype on
  augroup filetypedetect
    au BufNewFile,BufRead *	call assert_equal(0, did_filetype())
    au BufNewFile,BufRead Xotherfile	setf testfile
    au BufNewFile,BufRead *	call assert_equal(1, did_filetype())
  augroup END
  call writefile(['# some comment', 'must be conf'], 'Xotherfile', 'D')
  split Xotherfile
  call assert_equal('testfile', &filetype)

  bwipe!
  filetype off
endfunc

" If $XDG_CONFIG_HOME is set return "fname" expanded in a list.
" Otherwise return an empty list.
func s:WhenConfigHome(fname)
  if exists('$XDG_CONFIG_HOME')
    return [expand(a:fname)]
  endif
  return []
endfunc

" Return the name used for the $XDG_CONFIG_HOME directory.
func s:GetConfigHome()
  return getcwd() .. '/Xdg_config_home'
endfunc

" saved value of $XDG_CONFIG_HOME
let s:saveConfigHome = ''

func s:SetupConfigHome()
  " Nvim on Windows may use $XDG_CONFIG_HOME, and runnvim.sh sets it.
  " if empty(windowsversion())
    let s:saveConfigHome = $XDG_CONFIG_HOME
    call setenv("XDG_CONFIG_HOME", s:GetConfigHome())
  " endif
endfunc

" Filetypes detected just from matching the file name.
" First one is checking that these files have no filetype.
func s:GetFilenameChecks() abort
  return {
    \ 'none': ['bsd', 'some-bsd'],
    \ '8th': ['file.8th'],
    \ 'a2ps': ['/etc/a2ps.cfg', '/etc/a2ps/file.cfg', 'a2psrc', '.a2psrc', 'any/etc/a2ps.cfg', 'any/etc/a2ps/file.cfg'],
    \ 'a65': ['file.a65'],
    \ 'aap': ['file.aap'],
    \ 'abap': ['file.abap'],
    \ 'abc': ['file.abc'],
    \ 'abel': ['file.abl'],
    \ 'acedb': ['file.wrm'],
    \ 'ada': ['file.adb', 'file.ads', 'file.ada', 'file.gpr'],
    \ 'ahdl': ['file.tdf'],
    \ 'aidl': ['file.aidl'],
    \ 'alsaconf': ['.asoundrc', '/usr/share/alsa/alsa.conf', '/etc/asound.conf', 'any/etc/asound.conf', 'any/usr/share/alsa/alsa.conf'],
    \ 'aml': ['file.aml'],
    \ 'ampl': ['file.run'],
    \ 'ant': ['build.xml'],
    \ 'antlr4': ['parser.g4'],
    \ 'apache': ['.htaccess', '/etc/httpd/file.conf', '/etc/apache2/sites-2/file.com', '/etc/apache2/some.config', '/etc/apache2/conf.file/conf', '/etc/apache2/mods-some/file', '/etc/apache2/sites-some/file', '/etc/httpd/conf.d/file.config', '/etc/apache2/conf.file/file', '/etc/apache2/file.conf', '/etc/apache2/file.conf-file', '/etc/apache2/mods-file/file', '/etc/apache2/sites-file/file', '/etc/apache2/sites-file/file.com', '/etc/httpd/conf.d/file.conf', '/etc/httpd/conf.d/file.conf-file', 'access.conf', 'access.conf-file', 'any/etc/apache2/conf.file/file', 'any/etc/apache2/file.conf', 'any/etc/apache2/file.conf-file', 'any/etc/apache2/mods-file/file', 'any/etc/apache2/sites-file/file', 'any/etc/apache2/sites-file/file.com', 'any/etc/httpd/conf.d/file.conf', 'any/etc/httpd/conf.d/file.conf-file', 'any/etc/httpd/file.conf', 'apache.conf', 'apache.conf-file', 'apache2.conf', 'apache2.conf-file', 'httpd.conf', 'httpd.conf-file', 'srm.conf', 'srm.conf-file', '/etc/httpd/mods-some/file', '/etc/httpd/sites-some/file', '/etc/httpd/conf.file/conf'],
    \ 'apachestyle': ['/etc/proftpd/file.config,/etc/proftpd/conf.file/file', '/etc/proftpd/conf.file/file', '/etc/proftpd/file.conf', '/etc/proftpd/file.conf-file', 'any/etc/proftpd/conf.file/file', 'any/etc/proftpd/file.conf', 'any/etc/proftpd/file.conf-file', 'proftpd.conf', 'proftpd.conf-file'],
    \ 'applescript': ['file.scpt'],
    \ 'aptconf': ['apt.conf', '/.aptitude/config', 'any/.aptitude/config'],
    \ 'arch': ['.arch-inventory', '=tagging-method'],
    \ 'arduino': ['file.ino', 'file.pde'],
    \ 'art': ['file.art'],
    \ 'asciidoc': ['file.asciidoc', 'file.adoc'],
    \ 'asn': ['file.asn', 'file.asn1'],
    \ 'asterisk': ['asterisk/file.conf', 'asterisk/file.conf-file', 'some-asterisk/file.conf', 'some-asterisk/file.conf-file'],
    \ 'astro': ['file.astro'],
    \ 'asy': ['file.asy'],
    \ 'atlas': ['file.atl', 'file.as'],
    \ 'authzed': ['schema.zed'],
    \ 'autohotkey': ['file.ahk'],
    \ 'autoit': ['file.au3'],
    \ 'automake': ['GNUmakefile.am', 'makefile.am', 'Makefile.am'],
    \ 'ave': ['file.ave'],
    \ 'awk': ['file.awk', 'file.gawk'],
    \ 'b': ['file.mch', 'file.ref', 'file.imp'],
    \ 'basic': ['file.bas', 'file.bi', 'file.bm'],
    \ 'bass': ['file.bass'],
    \ 'bc': ['file.bc'],
    \ 'bdf': ['file.bdf'],
    \ 'beancount': ['file.beancount'],
    \ 'bib': ['file.bib'],
    \ 'bicep': ['file.bicep', 'file.bicepparam'],
    \ 'bindzone': ['named.root', '/bind/db.file', '/named/db.file', 'any/bind/db.file', 'any/named/db.file', 'foobar.zone'],
    \ 'bitbake': ['file.bb', 'file.bbappend', 'file.bbclass', 'build/conf/local.conf', 'meta/conf/layer.conf', 'build/conf/bbappend.conf', 'meta-layer/conf/distro/foo.conf'],
    \ 'blade': ['file.blade.php'],
    \ 'blank': ['file.bl'],
    \ 'blueprint': ['file.blp'],
    \ 'bp': ['Android.bp'],
    \ 'bsdl': ['file.bsd', 'file.bsdl'],
    \ 'bst': ['file.bst'],
    \ 'bzl': ['file.bazel', 'file.bzl', 'WORKSPACE', 'WORKSPACE.bzlmod'],
    \ 'bzr': ['bzr_log.any', 'bzr_log.file'],
    \ 'c': ['enlightenment/file.cfg', 'file.qc', 'file.c', 'some-enlightenment/file.cfg', 'file.mdh', 'file.epro'],
    \ 'cabal': ['file.cabal'],
    \ 'cabalconfig': ['cabal.config', expand("$HOME/.config/cabal/config")] + s:WhenConfigHome('$XDG_CONFIG_HOME/cabal/config'),
    \ 'cabalproject': ['cabal.project', 'cabal.project.local'],
    \ 'cairo': ['file.cairo'],
    \ 'calendar': ['calendar', '/.calendar/file', '/share/calendar/any/calendar.file', '/share/calendar/calendar.file', 'any/share/calendar/any/calendar.file', 'any/share/calendar/calendar.file'],
    \ 'capnp': ['file.capnp'],
    \ 'catalog': ['catalog', 'sgml.catalogfile', 'sgml.catalog', 'sgml.catalog-file'],
    \ 'cdl': ['file.cdl'],
    \ 'cdrdaoconf': ['/etc/cdrdao.conf', '/etc/defaults/cdrdao', '/etc/default/cdrdao', '.cdrdao', 'any/etc/cdrdao.conf', 'any/etc/default/cdrdao', 'any/etc/defaults/cdrdao'],
    \ 'cdrtoc': ['file.toc'],
    \ 'cedar': ['file.cedar'],
    \ 'cf': ['file.cfm', 'file.cfi', 'file.cfc'],
    \ 'cfengine': ['cfengine.conf'],
    \ 'cfg': ['file.hgrc', 'filehgrc', 'hgrc', 'some-hgrc'],
    \ 'cgdbrc': ['cgdbrc'],
    \ 'ch': ['file.chf'],
    \ 'chaiscript': ['file.chai'],
    \ 'chaskell': ['file.chs'],
    \ 'chatito': ['file.chatito'],
    \ 'chill': ['file..ch'],
    \ 'chordpro': ['file.chopro', 'file.crd', 'file.cho', 'file.crdpro', 'file.chordpro'],
    \ 'chuck': ['file.ck'],
    \ 'cl': ['file.eni'],
    \ 'clean': ['file.dcl', 'file.icl'],
    \ 'clojure': ['file.clj', 'file.cljs', 'file.cljx', 'file.cljc', 'init.trans', 'any/etc/translate-shell', '.trans'],
    \ 'cmake': ['CMakeLists.txt', 'file.cmake', 'file.cmake.in'],
    \ 'cmakecache': ['CMakeCache.txt'],
    \ 'cmod': ['file.cmod'],
    \ 'cmusrc': ['any/.cmus/autosave', 'any/.cmus/rc', 'any/.cmus/command-history', 'any/.cmus/file.theme', 'any/cmus/rc', 'any/cmus/file.theme', '/.cmus/autosave', '/.cmus/command-history', '/.cmus/file.theme', '/.cmus/rc', '/cmus/file.theme', '/cmus/rc'],
    \ 'cobol': ['file.cbl', 'file.cob'],
    \ 'coco': ['file.atg'],
    \ 'conaryrecipe': ['file.recipe'],
    \ 'conf': ['auto.master', 'file.conf', 'texdoc.cnf', '.x11vncrc', '.chktexrc', '.ripgreprc', 'ripgreprc', 'file.ctags', '.mbsyncrc'],
    \ 'config': ['configure.in', 'configure.ac', '/etc/hostname.file', 'any/etc/hostname.file'],
    \ 'confini': ['pacman.conf', 'paru.conf', 'mpv.conf', 'any/.aws/config', 'any/.aws/credentials', 'file.nmconnection'],
    \ 'context': ['tex/context/any/file.tex', 'file.mkii', 'file.mkiv', 'file.mkvi', 'file.mkxl', 'file.mklx'],
    \ 'cook': ['file.cook'],
    \ 'corn': ['file.corn'],
    \ 'cpon': ['file.cpon'],
    \ 'cpp': ['file.cxx', 'file.c++', 'file.hh', 'file.hxx', 'file.hpp', 'file.ipp', 'file.moc', 'file.tcc', 'file.inl', 'file.tlh', 'file.cppm', 'file.ccm', 'file.cxxm', 'file.c++m'],
    \ 'cqlang': ['file.cql'],
    \ 'crm': ['file.crm'],
    \ 'crontab': ['crontab', 'crontab.file', '/etc/cron.d/file', 'any/etc/cron.d/file'],
    \ 'crystal': ['file.cr'],
    \ 'cs': ['file.cs', 'file.csx'],
    \ 'csc': ['file.csc'],
    \ 'csdl': ['file.csdl'],
    \ 'csp': ['file.csp', 'file.fdr'],
    \ 'css': ['file.css'],
    \ 'cterm': ['file.con'],
    \ 'csv': ['file.csv'],
    \ 'cucumber': ['file.feature'],
    \ 'cuda': ['file.cu', 'file.cuh'],
    \ 'cue': ['file.cue'],
    \ 'cupl': ['file.pld'],
    \ 'cuplsim': ['file.si'],
    \ 'cvs': ['cvs123'],
    \ 'cvsrc': ['.cvsrc'],
    \ 'cynpp': ['file.cyn'],
    \ 'cypher': ['file.cypher'],
    \ 'd': ['file.d'],
    \ 'dafny': ['file.dfy'],
    \ 'dart': ['file.dart', 'file.drt'],
    \ 'datascript': ['file.ds'],
    \ 'dcd': ['file.dcd'],
    \ 'debchangelog': ['changelog.Debian', 'changelog.dch', 'NEWS.Debian', 'NEWS.dch', '/debian/changelog'],
    \ 'debcontrol': ['/debian/control', 'any/debian/control'],
    \ 'debcopyright': ['/debian/copyright', 'any/debian/copyright'],
    \ 'debsources': ['/etc/apt/sources.list', '/etc/apt/sources.list.d/file.list', 'any/etc/apt/sources.list', 'any/etc/apt/sources.list.d/file.list'],
    \ 'deb822sources': ['/etc/apt/sources.list.d/file.sources', 'any/etc/apt/sources.list.d/file.sources'],
    \ 'def': ['file.def'],
    \ 'denyhosts': ['denyhosts.conf'],
    \ 'desc': ['file.desc'],
    \ 'desktop': ['file.desktop', '.directory', 'file.directory'],
    \ 'dhall': ['file.dhall'],
    \ 'dictconf': ['dict.conf', '.dictrc'],
    \ 'dictdconf': ['dictd.conf', 'dictdfile.conf', 'dictd-file.conf'],
    \ 'diff': ['file.diff', 'file.rej'],
    \ 'dircolors': ['.dir_colors', '.dircolors', '/etc/DIR_COLORS', 'any/etc/DIR_COLORS'],
    \ 'dnsmasq': ['/etc/dnsmasq.conf', '/etc/dnsmasq.d/file', 'any/etc/dnsmasq.conf', 'any/etc/dnsmasq.d/file'],
    \ 'dockerfile': ['Containerfile', 'Dockerfile', 'dockerfile', 'file.Dockerfile', 'file.dockerfile', 'Dockerfile.debian', 'Containerfile.something'],
    \ 'dosbatch': ['file.bat'],
    \ 'dosini': ['/etc/yum.conf', '/etc/nfs.conf', '/etc/nfsmount.conf', 'file.ini',
    \            'npmrc', '.npmrc', 'php.ini', 'php.ini-5', 'php.ini-file',
    \            '/etc/yum.repos.d/file', 'any/etc/yum.conf', 'any/etc/yum.repos.d/file', 'file.wrap',
    \            'file.vbp', 'ja2.ini', 'JA2.INI', 'mimeapps.list', 'pip.conf', 'setup.cfg', 'pudb.cfg',
    \            '.coveragerc', '.pypirc', '.gitlint', '.oelint.cfg', 'pylintrc', '.pylintrc',
    \            '/home/user/.config/bpython/config', '/home/user/.config/mypy/config', '.wakatime.cfg', '.replyrc',
    \            'psprint.conf', 'sofficerc', 'any/.config/lxqt/globalkeyshortcuts.conf', 'any/.config/screengrab/screengrab.conf',
    \            'any/.local/share/flatpak/repo/config', '.notmuch-config'],
    \ 'dot': ['file.dot', 'file.gv'],
    \ 'dracula': ['file.drac', 'file.drc', 'file.lvs', 'file.lpe', 'drac.file'],
    \ 'dtd': ['file.dtd'],
    \ 'dtrace': ['/usr/lib/dtrace/io.d'],
    \ 'dts': ['file.dts', 'file.dtsi', 'file.dtso', 'file.its', 'file.keymap'],
    \ 'dune': ['jbuild', 'dune', 'dune-project', 'dune-workspace', 'dune-file'],
    \ 'dylan': ['file.dylan'],
    \ 'dylanintr': ['file.intr'],
    \ 'dylanlid': ['file.lid'],
    \ 'earthfile': ['Earthfile'],
    \ 'ecd': ['file.ecd'],
    \ 'edif': ['file.edf', 'file.edif', 'file.edo'],
    \ 'editorconfig': ['.editorconfig'],
    \ 'eelixir': ['file.eex', 'file.leex'],
    \ 'elinks': ['elinks.conf'],
    \ 'elixir': ['file.ex', 'file.exs', 'mix.lock'],
    \ 'elm': ['file.elm'],
    \ 'elmfilt': ['filter-rules'],
    \ 'elsa': ['file.lc'],
    \ 'elvish': ['file.elv'],
    \ 'epuppet': ['file.epp'],
    \ 'erlang': ['file.erl', 'file.hrl', 'file.yaws'],
    \ 'eruby': ['file.erb', 'file.rhtml'],
    \ 'esdl': ['file.esdl'],
    \ 'esmtprc': ['anyesmtprc', 'esmtprc', 'some-esmtprc'],
    \ 'esqlc': ['file.ec', 'file.EC'],
    \ 'esterel': ['file.strl'],
    \ 'eterm': ['anyEterm/file.cfg', 'Eterm/file.cfg', 'some-Eterm/file.cfg'],
    \ 'execline': ['/etc/s6-rc/run', './s6-rc/src/dbus-srv/up', '/sbin/s6-shutdown'],
    \ 'exim': ['exim.conf'],
    \ 'expect': ['file.exp'],
    \ 'exports': ['exports'],
    \ 'factor': ['file.factor'],
    \ 'falcon': ['file.fal'],
    \ 'fan': ['file.fan', 'file.fwt'],
    \ 'faust': ['file.dsp', 'file.lib'],
    \ 'fennel': ['file.fnl'],
    \ 'fetchmail': ['.fetchmailrc'],
    \ 'fgl': ['file.4gl', 'file.4gh', 'file.m4gl'],
    \ 'firrtl': ['file.fir'],
    \ 'fish': ['file.fish'],
    \ 'focexec': ['file.fex', 'file.focexec'],
    \ 'form': ['file.frm'],
    \ 'forth': ['file.ft', 'file.fth', 'file.4th'],
    \ 'fortran': ['file.f', 'file.for', 'file.fortran', 'file.fpp', 'file.ftn', 'file.f77', 'file.f90', 'file.f95', 'file.f03', 'file.f08'],
    \ 'fpcmake': ['file.fpc'],
    \ 'framescript': ['file.fsl'],
    \ 'freebasic': ['file.fb'],
    \ 'fsh': ['file.fsh'],
    \ 'fsharp': ['file.fs', 'file.fsi', 'file.fsx'],
    \ 'fstab': ['fstab', 'mtab'],
    \ 'func': ['file.fc'],
    \ 'fusion': ['file.fusion'],
    \ 'fvwm': ['/.fvwm/file', 'any/.fvwm/file'],
    \ 'gdb': ['.gdbinit', 'gdbinit', 'file.gdb', '.config/gdbearlyinit', '.gdbearlyinit'],
    \ 'gdmo': ['file.mo', 'file.gdmo'],
    \ 'gdresource': ['file.tscn', 'file.tres'],
    \ 'gdscript': ['file.gd'],
    \ 'gdshader': ['file.gdshader', 'file.shader'],
    \ 'gedcom': ['file.ged', 'lltxxxxx.txt', '/tmp/lltmp', '/tmp/lltmp-file', 'any/tmp/lltmp', 'any/tmp/lltmp-file'],
    \ 'gemtext': ['file.gmi', 'file.gemini'],
    \ 'gift': ['file.gift'],
    \ 'gitattributes': ['file.git/info/attributes', '.gitattributes', '/.config/git/attributes', '/etc/gitattributes', '/usr/local/etc/gitattributes', 'some.git/info/attributes'] + s:WhenConfigHome('$XDG_CONFIG_HOME/git/attributes'),
    \ 'gitcommit': ['COMMIT_EDITMSG', 'MERGE_MSG', 'TAG_EDITMSG', 'NOTES_EDITMSG', 'EDIT_DESCRIPTION'],
    \ 'gitconfig': ['file.git/config', 'file.git/config.worktree', 'file.git/worktrees/x/config.worktree', '.gitconfig', '.gitmodules', 'file.git/modules//config', '/.config/git/config', '/etc/gitconfig', '/usr/local/etc/gitconfig', '/etc/gitconfig.d/file', 'any/etc/gitconfig.d/file', '/.gitconfig.d/file', 'any/.config/git/config', 'any/.gitconfig.d/file', 'some.git/config', 'some.git/modules/any/config'] + s:WhenConfigHome('$XDG_CONFIG_HOME/git/config'),
    \ 'gitignore': ['file.git/info/exclude', '.gitignore', '/.config/git/ignore', 'some.git/info/exclude'] + s:WhenConfigHome('$XDG_CONFIG_HOME/git/ignore') + ['.prettierignore'],
    \ 'gitolite': ['gitolite.conf', '/gitolite-admin/conf/file', 'any/gitolite-admin/conf/file'],
    \ 'gitrebase': ['git-rebase-todo'],
    \ 'gitsendemail': ['.gitsendemail.msg.xxxxxx'],
    \ 'gkrellmrc': ['gkrellmrc', 'gkrellmrc_x'],
    \ 'gleam': ['file.gleam'],
    \ 'glsl': ['file.glsl', 'file.vert', 'file.tesc', 'file.tese', 'file.geom', 'file.frag', 'file.comp', 'file.rgen', 'file.rmiss', 'file.rchit', 'file.rahit', 'file.rint', 'file.rcall'],
    \ 'gn': ['file.gn', 'file.gni'],
    \ 'gnash': ['gnashrc', '.gnashrc', 'gnashpluginrc', '.gnashpluginrc'],
    \ 'gnuplot': ['file.gpi', '.gnuplot', 'file.gnuplot', '.gnuplot_history'],
    \ 'go': ['file.go'],
    \ 'gomod': ['go.mod'],
    \ 'gosum': ['go.sum', 'go.work.sum'],
    \ 'gowork': ['go.work'],
    \ 'gp': ['file.gp', '.gprc'],
    \ 'gpg': ['/.gnupg/options', '/.gnupg/gpg.conf', '/usr/any/gnupg/options.skel', 'any/.gnupg/gpg.conf', 'any/.gnupg/options', 'any/usr/any/gnupg/options.skel'],
    \ 'grads': ['file.gs'],
    \ 'graphql': ['file.graphql', 'file.graphqls', 'file.gql'],
    \ 'gretl': ['file.gretl'],
    \ 'groovy': ['file.gradle', 'file.groovy', 'Jenkinsfile'],
    \ 'group': ['any/etc/group', 'any/etc/group-', 'any/etc/group.edit', 'any/etc/gshadow', 'any/etc/gshadow-', 'any/etc/gshadow.edit', 'any/var/backups/group.bak', 'any/var/backups/gshadow.bak', '/etc/group', '/etc/group-', '/etc/group.edit', '/etc/gshadow', '/etc/gshadow-', '/etc/gshadow.edit', '/var/backups/group.bak', '/var/backups/gshadow.bak'],
    \ 'grub': ['/boot/grub/menu.lst', '/boot/grub/grub.conf', '/etc/grub.conf', 'any/boot/grub/grub.conf', 'any/boot/grub/menu.lst', 'any/etc/grub.conf'],
    \ 'gsp': ['file.gsp'],
    \ 'gtkrc': ['.gtkrc', 'gtkrc', '.gtkrc-file', 'gtkrc-file'],
    \ 'gyp': ['file.gyp', 'file.gypi'],
    \ 'hack': ['file.hack', 'file.hackpartial'],
    \ 'haml': ['file.haml'],
    \ 'hamster': ['file.hsm'],
    \ 'handlebars': ['file.hbs'],
    \ 'hare': ['file.ha'],
    \ 'haskell': ['file.hs', 'file.hsc', 'file.hs-boot', 'file.hsig'],
    \ 'haskellpersistent': ['file.persistentmodels'],
    \ 'haste': ['file.ht'],
    \ 'hastepreproc': ['file.htpp'],
    \ 'hb': ['file.hb'],
    \ 'hcl': ['file.hcl'],
    \ 'heex': ['file.heex'],
    \ 'hercules': ['file.vc', 'file.ev', 'file.sum', 'file.errsum'],
    \ 'hex': ['file.hex', 'file.ihex', 'file.ihe', 'file.ihx', 'file.int', 'file.mcs', 'file.h32', 'file.h80', 'file.h86', 'file.a43', 'file.a90'],
    \ 'hgcommit': ['hg-editor-file.txt'],
    \ 'hjson': ['file.hjson'],
    \ 'hlsplaylist': ['file.m3u', 'file.m3u8'],
    \ 'hog': ['file.hog', 'snort.conf', 'vision.conf'],
    \ 'hollywood': ['file.hws'],
    \ 'hoon': ['file.hoon'],
    \ 'hostconf': ['/etc/host.conf', 'any/etc/host.conf'],
    \ 'hostsaccess': ['/etc/hosts.allow', '/etc/hosts.deny', 'any/etc/hosts.allow', 'any/etc/hosts.deny'],
    \ 'html': ['file.html', 'file.htm', 'file.cshtml', 'file.component.html'],
    \ 'htmlm4': ['file.html.m4'],
    \ 'httest': ['file.htt', 'file.htb'],
    \ 'hurl': ['file.hurl'],
    \ 'hyprlang': ['hyprlock.conf', 'hyprland.conf', 'hypridle.conf', 'hyprpaper.conf'],
    \ 'i3config': ['/home/user/.i3/config', '/home/user/.config/i3/config', '/etc/i3/config', '/etc/xdg/i3/config'],
    \ 'ibasic': ['file.iba', 'file.ibi'],
    \ 'icemenu': ['/.icewm/menu', 'any/.icewm/menu'],
    \ 'icon': ['file.icn'],
    \ 'indent': ['.indent.pro', 'indentrc'],
    \ 'inform': ['file.inf', 'file.INF'],
    \ 'initng': ['/etc/initng/any/file.i', 'file.ii', 'any/etc/initng/any/file.i'],
    \ 'inittab': ['inittab'],
    \ 'inko': ['file.inko'],
    \ 'ipfilter': ['ipf.conf', 'ipf6.conf', 'ipf.rules'],
    \ 'iss': ['file.iss'],
    \ 'ist': ['file.ist', 'file.mst'],
    \ 'j': ['file.ijs'],
    \ 'jal': ['file.jal', 'file.JAL'],
    \ 'jam': ['file.jpl', 'file.jpr', 'JAM-file.file', 'JAM.file', 'Prl-file.file', 'Prl.file'],
    \ 'janet': ['file.janet'],
    \ 'java': ['file.java', 'file.jav'],
    \ 'javacc': ['file.jj', 'file.jjt'],
    \ 'javascript': ['file.js', 'file.jsm', 'file.javascript', 'file.es', 'file.mjs', 'file.cjs', '.node_repl_history'],
    \ 'javascript.glimmer': ['file.gjs'],
    \ 'javascriptreact': ['file.jsx'],
    \ 'jess': ['file.clp'],
    \ 'jgraph': ['file.jgr'],
    \ 'jj': ['file.jjdescription'],
    \ 'jq': ['file.jq'],
    \ 'jovial': ['file.jov', 'file.j73', 'file.jovial'],
    \ 'jproperties': ['file.properties', 'file.properties_xx', 'file.properties_xx_xx', 'some.properties_xx_xx_file', 'org.eclipse.xyz.prefs'],
    \ 'json': ['file.json', 'file.jsonp', 'file.json-patch', 'file.geojson', 'file.webmanifest', 'Pipfile.lock', 'file.ipynb', 'file.jupyterlab-settings', '.prettierrc', '.firebaserc', '.stylelintrc', '.lintstagedrc', 'file.slnf', 'file.sublime-project', 'file.sublime-settings', 'file.sublime-workspace', 'file.bd', 'file.bda', 'file.xci', 'flake.lock', 'pack.mcmeta', 'deno.lock'],
    \ 'json5': ['file.json5'],
    \ 'jsonc': ['file.jsonc', '.babelrc', '.eslintrc', '.jsfmtrc', '.jshintrc', '.jscsrc', '.vsconfig', '.hintrc', '.swrc', 'jsconfig.json', 'tsconfig.json', 'tsconfig.test.json', 'tsconfig-test.json', '.luaurc'],
    \ 'jsonl': ['file.jsonl'],
    \ 'jsonnet': ['file.jsonnet', 'file.libsonnet'],
    \ 'jsp': ['file.jsp'],
    \ 'julia': ['file.jl'],
    \ 'just': ['justfile', 'Justfile', '.justfile', 'config.just'],
    \ 'kconfig': ['Kconfig', 'Kconfig.debug', 'Kconfig.file', 'Config.in', 'Config.in.host'],
    \ 'kdl': ['file.kdl'],
    \ 'kivy': ['file.kv'],
    \ 'kix': ['file.kix'],
    \ 'kotlin': ['file.kt', 'file.ktm', 'file.kts'],
    \ 'krl': ['file.sub', 'file.Sub', 'file.SUB'],
    \ 'kscript': ['file.ks'],
    \ 'kwt': ['file.k'],
    \ 'lace': ['file.ace', 'file.ACE'],
    \ 'latte': ['file.latte', 'file.lte'],
    \ 'ld': ['file.ld', 'any/usr/lib/aarch64-xilinx-linux/ldscripts/aarch64elf32b.x'],
    \ 'ldapconf': ['ldap.conf', '.ldaprc', 'ldaprc'],
    \ 'ldif': ['file.ldif'],
    \ 'lean': ['file.lean'],
    \ 'ledger': ['file.ldg', 'file.ledger', 'file.journal'],
    \ 'less': ['file.less'],
    \ 'lex': ['file.lex', 'file.l', 'file.lxx', 'file.l++'],
    \ 'lftp': ['lftp.conf', '.lftprc', 'anylftp/rc', 'lftp/rc', 'some-lftp/rc'],
    \ 'lhaskell': ['file.lhs'],
    \ 'libao': ['/etc/libao.conf', '/.libao', 'any/.libao', 'any/etc/libao.conf'],
    \ 'lifelines': ['file.ll'],
    \ 'lilo': ['lilo.conf', 'lilo.conf-file'],
    \ 'lilypond': ['file.ly', 'file.ily'],
    \ 'limits': ['/etc/limits', '/etc/anylimits.conf', '/etc/anylimits.d/file.conf', '/etc/limits.conf', '/etc/limits.d/file.conf', '/etc/some-limits.conf', '/etc/some-limits.d/file.conf', 'any/etc/limits', 'any/etc/limits.conf', 'any/etc/limits.d/file.conf', 'any/etc/some-limits.conf', 'any/etc/some-limits.d/file.conf'],
    \ 'liquidsoap': ['file.liq'],
    \ 'liquid': ['file.liquid'],
    \ 'lisp': ['file.lsp', 'file.lisp', 'file.asd', 'file.el', 'file.cl', '.emacs', '.sawfishrc', 'sbclrc', '.sbclrc', 'file.stsg', 'any/local/share/supertux2/config'],
    \ 'lite': ['file.lite', 'file.lt'],
    \ 'litestep': ['/LiteStep/any/file.rc', 'any/LiteStep/any/file.rc'],
    \ 'logcheck': ['/etc/logcheck/file.d-some/file', '/etc/logcheck/file.d/file', 'any/etc/logcheck/file.d-some/file', 'any/etc/logcheck/file.d/file'],
    \ 'livebook': ['file.livemd'],
    \ 'loginaccess': ['/etc/login.access', 'any/etc/login.access'],
    \ 'logindefs': ['/etc/login.defs', 'any/etc/login.defs'],
    \ 'logtalk': ['file.lgt'],
    \ 'lotos': ['file.lot', 'file.lotos'],
    \ 'lout': ['file.lou', 'file.lout'],
    \ 'lpc': ['file.lpc', 'file.ulpc'],
    \ 'lsl': ['file.lsl'],
    \ 'lss': ['file.lss'],
    \ 'lua': ['file.lua', 'file.tlu', 'file.rockspec', 'file.nse', '.lua_history', '.luacheckrc', '.busted', 'rock_manifest', 'config.ld'],
    \ 'luau': ['file.luau'],
    \ 'lynx': ['lynx.cfg'],
    \ 'lyrics': ['file.lrc'],
    \ 'm3build': ['m3makefile', 'm3overrides'],
    \ 'm3quake': ['file.quake', 'cm3.cfg'],
    \ 'm4': ['file.at', '.m4_history'],
    \ 'mail': ['snd.123', '.letter', '.letter.123', '.followup', '.article', '.article.123', 'pico.123', 'mutt-xx-xxx', 'muttng-xx-xxx', 'ae123.txt', 'file.eml', 'reportbug-file'],
    \ 'mailaliases': ['/etc/mail/aliases', '/etc/aliases', 'any/etc/aliases', 'any/etc/mail/aliases'],
    \ 'mailcap': ['.mailcap', 'mailcap'],
    \ 'make': ['file.mk', 'file.mak', 'makefile', 'Makefile', 'makefile-file', 'Makefile-file', 'some-makefile', 'some-Makefile', 'Kbuild'],
    \ 'mallard': ['file.page'],
    "\ 'man': ['file.man'],
    \ 'manconf': ['/etc/man.conf', 'man.config', 'any/etc/man.conf'],
    \ 'map': ['file.map'],
    \ 'maple': ['file.mv', 'file.mpl', 'file.mws'],
    \ 'markdown': ['file.markdown', 'file.mdown', 'file.mkd', 'file.mkdn', 'file.mdwn', 'file.md'],
    \ 'mason': ['file.mason', 'file.mhtml'],
    \ 'master': ['file.mas', 'file.master'],
    \ 'matlab': ['file.m'],
    \ 'maxima': ['file.demo', 'file.dmt', 'file.dm1', 'file.dm2', 'file.dm3',
    \            'file.wxm', 'maxima-init.mac'],
    \ 'mediawiki': ['file.mw', 'file.wiki'],
    \ 'mel': ['file.mel'],
    \ 'mermaid': ['file.mmd', 'file.mmdc', 'file.mermaid'],
    \ 'meson': ['meson.build', 'meson.options', 'meson_options.txt'],
    \ 'messages': ['/log/auth', '/log/cron', '/log/daemon', '/log/debug',
    \              '/log/kern', '/log/lpr', '/log/mail', '/log/messages',
    \              '/log/news/news', '/log/syslog', '/log/user', '/log/auth.log',
    \              '/log/cron.log', '/log/daemon.log', '/log/debug.log',
    \              '/log/kern.log', '/log/lpr.log', '/log/mail.log',
    \              '/log/messages.log', '/log/news/news.log', '/log/syslog.log',
    \              '/log/user.log', '/log/auth.err', '/log/cron.err',
    \              '/log/daemon.err', '/log/debug.err', '/log/kern.err',
    \              '/log/lpr.err', '/log/mail.err', '/log/messages.err',
    \              '/log/news/news.err', '/log/syslog.err', '/log/user.err',
    \              '/log/auth.info', '/log/cron.info', '/log/daemon.info',
    \              '/log/debug.info', '/log/kern.info', '/log/lpr.info',
    \              '/log/mail.info', '/log/messages.info', '/log/news/news.info',
    \              '/log/syslog.info', '/log/user.info', '/log/auth.warn',
    \              '/log/cron.warn', '/log/daemon.warn', '/log/debug.warn',
    \              '/log/kern.warn', '/log/lpr.warn', '/log/mail.warn',
    \              '/log/messages.warn', '/log/news/news.warn',
    \              '/log/syslog.warn', '/log/user.warn', '/log/auth.crit',
    \              '/log/cron.crit', '/log/daemon.crit', '/log/debug.crit',
    \              '/log/kern.crit', '/log/lpr.crit', '/log/mail.crit',
    \              '/log/messages.crit', '/log/news/news.crit',
    \              '/log/syslog.crit', '/log/user.crit', '/log/auth.notice',
    \              '/log/cron.notice', '/log/daemon.notice', '/log/debug.notice',
    \              '/log/kern.notice', '/log/lpr.notice', '/log/mail.notice',
    \              '/log/messages.notice', '/log/news/news.notice',
    \              '/log/syslog.notice', '/log/user.notice'],
    \ 'mf': ['file.mf'],
    \ 'mgl': ['file.mgl'],
    \ 'mgp': ['file.mgp'],
    \ 'mib': ['file.mib', 'file.my'],
    \ 'mix': ['file.mix', 'file.mixal'],
    \ 'mma': ['file.nb', 'file.wl'],
    \ 'mmp': ['file.mmp'],
    \ 'modconf': ['/etc/modules.conf', '/etc/modules', '/etc/conf.modules', '/etc/modprobe.file', 'any/etc/conf.modules', 'any/etc/modprobe.file', 'any/etc/modules', 'any/etc/modules.conf'],
    \ 'modula3': ['file.m3', 'file.mg', 'file.i3', 'file.ig', 'file.lm3'],
    \ 'monk': ['file.isc', 'file.monk', 'file.ssc', 'file.tsc'],
    \ 'moo': ['file.moo'],
    \ 'moonscript': ['file.moon'],
    \ 'move': ['file.move'],
    \ 'mp': ['file.mp', 'file.mpxl', 'file.mpiv', 'file.mpvi'],
    \ 'mplayerconf': ['mplayer.conf', '/.mplayer/config', 'any/.mplayer/config'],
    \ 'mrxvtrc': ['mrxvtrc', '.mrxvtrc'],
    \ 'msidl': ['file.odl', 'file.mof'],
    \ 'msql': ['file.msql'],
    \ 'mojo': ['file.mojo', 'file.🔥'],
    \ 'msmtp': ['.msmtprc'],
    \ 'mupad': ['file.mu'],
    \ 'mush': ['file.mush'],
    \ 'mustache': ['file.mustache'],
    \ 'muttrc': ['Muttngrc', 'Muttrc', '.muttngrc', '.muttngrc-file', '.muttrc',
    \            '.muttrc-file', '/.mutt/muttngrc', '/.mutt/muttngrc-file',
    \            '/.mutt/muttrc', '/.mutt/muttrc-file', '/.muttng/muttngrc',
    \            '/.muttng/muttngrc-file', '/.muttng/muttrc',
    \            '/.muttng/muttrc-file', '/etc/Muttrc.d/file',
    \            '/etc/Muttrc.d/file.rc', 'Muttngrc-file', 'Muttrc-file',
    \            'any/.mutt/muttngrc', 'any/.mutt/muttngrc-file',
    \            'any/.mutt/muttrc', 'any/.mutt/muttrc-file',
    \            'any/.muttng/muttngrc', 'any/.muttng/muttngrc-file',
    \            'any/.muttng/muttrc', 'any/.muttng/muttrc-file',
    \            'any/etc/Muttrc.d/file', 'muttngrc', 'muttngrc-file', 'muttrc',
    \            'muttrc-file'],
    \ 'mysql': ['file.mysql', '.mysql_history'],
    \ 'n1ql': ['file.n1ql', 'file.nql'],
    \ 'named': ['namedfile.conf', 'rndcfile.conf', 'named-file.conf', 'named.conf', 'rndc-file.conf', 'rndc-file.key', 'rndc.conf', 'rndc.key'],
    \ 'nanorc': ['/etc/nanorc', 'file.nanorc', 'any/etc/nanorc'],
    \ 'natural': ['file.NSA', 'file.NSC', 'file.NSG', 'file.NSL', 'file.NSM', 'file.NSN', 'file.NSP', 'file.NSS'],
    \ 'ncf': ['file.ncf'],
    \ 'neomuttrc': ['Neomuttrc', '.neomuttrc', '.neomuttrc-file', '/.neomutt/neomuttrc', '/.neomutt/neomuttrc-file', 'Neomuttrc', 'Neomuttrc-file', 'any/.neomutt/neomuttrc', 'any/.neomutt/neomuttrc-file', 'neomuttrc', 'neomuttrc-file'],
    \ 'netrc': ['.netrc'],
    \ 'nginx': ['file.nginx', 'nginxfile.conf', 'filenginx.conf', 'any/etc/nginx/file', 'any/usr/local/nginx/conf/file', 'any/nginx/file.conf'],
    \ 'nim': ['file.nim', 'file.nims', 'file.nimble'],
    \ 'ninja': ['file.ninja'],
    \ 'nix': ['file.nix'],
    \ 'norg': ['file.norg'],
    \ 'nqc': ['file.nqc'],
    \ 'nroff': ['file.tr', 'file.nr', 'file.roff', 'file.tmac', 'file.mom', 'tmac.file'],
    \ 'nsis': ['file.nsi', 'file.nsh'],
    \ 'nu': ['file.nu'],
    \ 'obj': ['file.obj'],
    \ 'objdump': ['file.objdump', 'file.cppobjdump'],
    \ 'obse': ['file.obl', 'file.obse', 'file.oblivion', 'file.obscript'],
    \ 'ocaml': ['file.ml', 'file.mli', 'file.mll', 'file.mly', '.ocamlinit', 'file.mlt', 'file.mlp', 'file.mlip', 'file.mli.cppo', 'file.ml.cppo'],
    \ 'occam': ['file.occ'],
    \ 'octave': ['octaverc', '.octaverc', 'octave.conf', 'any/.local/share/octave/history'],
    \ 'odin': ['file.odin'],
    \ 'omnimark': ['file.xom', 'file.xin'],
    \ 'ondir': ['.ondirrc'],
    \ 'opam': ['opam', 'file.opam', 'file.opam.template', 'opam.locked', 'file.opam.locked'],
    \ 'openroad': ['file.or'],
    \ 'openscad': ['file.scad'],
    \ 'openvpn': ['file.ovpn', '/etc/openvpn/client/client.conf', '/usr/share/openvpn/examples/server.conf'],
    \ 'opl': ['file.OPL', 'file.OPl', 'file.OpL', 'file.Opl', 'file.oPL', 'file.oPl', 'file.opL', 'file.opl'],
    \ 'ora': ['file.ora'],
    \ 'org': ['file.org', 'file.org_archive'],
    \ 'pacmanlog': ['pacman.log'],
    \ 'pamconf': ['/etc/pam.conf', '/etc/pam.d/file', 'any/etc/pam.conf', 'any/etc/pam.d/file'],
    \ 'pamenv': ['/etc/security/pam_env.conf', '/home/user/.pam_environment', '.pam_environment', 'pam_env.conf'],
    \ 'pandoc': ['file.pandoc', 'file.pdk', 'file.pd', 'file.pdc'],
    \ 'papp': ['file.papp', 'file.pxml', 'file.pxsl'],
    \ 'pascal': ['file.pas', 'file.dpr', 'file.lpr'],
    \ 'passwd': ['any/etc/passwd', 'any/etc/passwd-', 'any/etc/passwd.edit', 'any/etc/shadow', 'any/etc/shadow-', 'any/etc/shadow.edit', 'any/var/backups/passwd.bak', 'any/var/backups/shadow.bak', '/etc/passwd', '/etc/passwd-', '/etc/passwd.edit', '/etc/shadow', '/etc/shadow-', '/etc/shadow.edit', '/var/backups/passwd.bak', '/var/backups/shadow.bak'],
    \ 'pbtxt': ['file.txtpb', 'file.textproto', 'file.textpb', 'file.pbtxt'],
    \ 'pccts': ['file.g'],
    \ 'pcmk': ['file.pcmk'],
    \ 'pdf': ['file.pdf'],
    \ 'pem': ['file.pem', 'file.cer', 'file.crt', 'file.csr'],
    \ 'perl': ['file.plx', 'file.al', 'file.psgi', 'gitolite.rc', '.gitolite.rc', 'example.gitolite.rc', '.latexmkrc', 'latexmkrc'],
    \ 'pf': ['pf.conf'],
    \ 'pfmain': ['main.cf', 'main.cf.proto'],
    \ 'php': ['file.php', 'file.php9', 'file.phtml', 'file.ctp', 'file.phpt', 'file.theme'],
    \ 'pike': ['file.pike', 'file.pmod'],
    \ 'pilrc': ['file.rcp'],
    \ 'pine': ['.pinerc', 'pinerc', '.pinercex', 'pinercex'],
    \ 'pinfo': ['/etc/pinforc', '/.pinforc', 'any/.pinforc', 'any/etc/pinforc'],
    \ 'pli': ['file.pli', 'file.pl1'],
    \ 'plm': ['file.plm', 'file.p36', 'file.pac'],
    \ 'plp': ['file.plp'],
    \ 'plsql': ['file.pls', 'file.plsql'],
    \ 'po': ['file.po', 'file.pot'],
    \ 'pod': ['file.pod'],
    \ 'poefilter': ['file.filter'],
    \ 'poke': ['file.pk'],
    \ 'pony': ['file.pony'],
    \ 'postscr': ['file.ps', 'file.pfa', 'file.afm', 'file.eps', 'file.epsf', 'file.epsi', 'file.ai'],
    \ 'pov': ['file.pov'],
    \ 'povini': ['.povrayrc'],
    \ 'ppd': ['file.ppd'],
    \ 'ppwiz': ['file.it', 'file.ih'],
    \ 'prisma': ['file.prisma'],
    \ 'privoxy': ['file.action'],
    \ 'proc': ['file.pc'],
    \ 'procmail': ['.procmail', '.procmailrc'],
    \ 'prolog': ['file.pdb'],
    \ 'promela': ['file.pml'],
    \ 'proto': ['file.proto'],
    \ 'protocols': ['/etc/protocols', 'any/etc/protocols'],
    \ 'ps1': ['file.ps1', 'file.psd1', 'file.psm1', 'file.pssc'],
    \ 'ps1xml': ['file.ps1xml'],
    \ 'psf': ['file.psf'],
    \ 'psl': ['file.psl'],
    \ 'pug': ['file.pug'],
    \ 'puppet': ['file.pp'],
    \ 'purescript': ['file.purs'],
    \ 'pymanifest': ['MANIFEST.in'],
    \ 'pyret': ['file.arr'],
    \ 'pyrex': ['file.pyx', 'file.pxd'],
    \ 'python': ['file.py', 'file.pyw', '.pythonstartup', '.pythonrc', '.python_history', '.jline-jython.history', 'file.ptl', 'file.pyi', 'SConstruct'],
    \ 'ql': ['file.ql', 'file.qll'],
    \ 'qml': ['file.qml', 'file.qbs'],
    \ 'qmldir': ['qmldir'],
    \ 'quake': ['anybaseq2/file.cfg', 'anyid1/file.cfg', 'quake3/file.cfg', 'baseq2/file.cfg', 'id1/file.cfg', 'quake1/file.cfg', 'some-baseq2/file.cfg', 'some-id1/file.cfg', 'some-quake1/file.cfg'],
    \ 'quarto': ['file.qmd'],
    \ 'r': ['file.r', '.Rhistory', '.Rprofile', 'Rprofile', 'Rprofile.site'],
    \ 'racket': ['file.rkt', 'file.rktd', 'file.rktl'],
    \ 'radiance': ['file.rad', 'file.mat'],
    \ 'raku': ['file.pm6', 'file.p6', 'file.t6', 'file.pod6', 'file.raku', 'file.rakumod', 'file.rakudoc', 'file.rakutest'],
    \ 'raml': ['file.raml'],
    \ 'rasi': ['file.rasi'],
    \ 'ratpoison': ['.ratpoisonrc', 'ratpoisonrc'],
    \ 'rbs': ['file.rbs'],
    \ 'rc': ['file.rc', 'file.rch'],
    \ 'rcs': ['file,v'],
    \ 'readline': ['.inputrc', 'inputrc'],
    \ 'rego': ['file.rego'],
    \ 'remind': ['.reminders', 'file.remind', 'file.rem', '.reminders-file'],
    \ 'requirements': ['file.pip', 'requirements.txt', 'dev-requirements.txt', 'constraints.txt', 'requirements.in', 'requirements/dev.txt', 'requires/dev.txt'],
    \ 'rescript': ['file.res', 'file.resi'],
    \ 'resolv': ['resolv.conf'],
    \ 'reva': ['file.frt'],
    \ 'rexx': ['file.rex', 'file.orx', 'file.rxo', 'file.rxj', 'file.jrexx', 'file.rexxj', 'file.rexx', 'file.testGroup', 'file.testUnit'],
    \ 'rhelp': ['file.rd'],
    \ 'rib': ['file.rib'],
    \ 'rmd': ['file.rmd', 'file.smd'],
    \ 'rnc': ['file.rnc'],
    \ 'rng': ['file.rng'],
    \ 'rnoweb': ['file.rnw', 'file.snw'],
    \ 'rpgle': ['file.rpgle', 'file.rpgleinc'],
    \ 'robot': ['file.robot', 'file.resource'],
    \ 'robots': ['robots.txt'],
    \ 'roc': ['file.roc'],
    \ 'ron': ['file.ron'],
    \ 'routeros': ['file.rsc'],
    \ 'rpcgen': ['file.x'],
    \ 'rpl': ['file.rpl'],
    \ 'rrst': ['file.rrst', 'file.srst'],
    \ 'rst': ['file.rst'],
    \ 'rtf': ['file.rtf'],
    \ 'ruby': ['.irbrc', 'irbrc', '.irb_history', 'irb_history', 'file.rb', 'file.rbw', 'file.gemspec', 'file.ru', 'Gemfile', 'file.builder', 'file.rxml', 'file.rjs', 'file.rant', 'file.rake', 'rakefile', 'Rakefile', 'rantfile', 'Rantfile', 'rakefile-file', 'Rakefile-file', 'Puppetfile', 'Vagrantfile'],
    \ 'rust': ['file.rs'],
    \ 'samba': ['smb.conf'],
    \ 'sas': ['file.sas'],
    \ 'sass': ['file.sass'],
    \ 'sather': ['file.sa'],
    \ 'sbt': ['file.sbt'],
    \ 'scala': ['file.scala'],
    \ 'scheme': ['file.scm', 'file.ss', 'file.sld'],
    \ 'scilab': ['file.sci', 'file.sce'],
    \ 'screen': ['.screenrc', 'screenrc'],
    \ 'scss': ['file.scss'],
    \ 'sd': ['file.sd'],
    \ 'sdc': ['file.sdc'],
    \ 'sdl': ['file.sdl', 'file.pr'],
    \ 'sed': ['file.sed'],
    \ 'sensors': ['/etc/sensors.conf', '/etc/sensors3.conf', '/etc/sensors.d/file', 'any/etc/sensors.conf', 'any/etc/sensors3.conf', 'any/etc/sensors.d/file'],
    \ 'services': ['/etc/services', 'any/etc/services'],
    \ 'setserial': ['/etc/serial.conf', 'any/etc/serial.conf'],
    \ 'sexplib': ['file.sexp'],
    \ 'sh': ['.bashrc', '.bash_profile', '.bash-profile', '.bash_logout', '.bash-logout', '.bash_aliases', '.bash-aliases', '.bash_history', '.bash-history',
    \        '/tmp/bash-fc-3Ozjlw', '/tmp/bash-fc.3Ozjlw', 'PKGBUILD', 'APKBUILD', 'file.bash', '/usr/share/doc/bash-completion/filter.sh',
    \        '/etc/udev/cdsymlinks.conf', 'any/etc/udev/cdsymlinks.conf', 'file.bats', '.ash_history', 'any/etc/neofetch/config.conf', '.xprofile',
    \        'user-dirs.defaults', 'user-dirs.dirs', 'makepkg.conf', '.makepkg.conf', 'file.mdd', 'file.cygport', '.env', '.envrc', 'devscripts.conf',
    \        '.devscripts'],
    \ 'sieve': ['file.siv', 'file.sieve'],
    \ 'sil': ['file.sil'],
    \ 'simula': ['file.sim'],
    \ 'sinda': ['file.sin', 'file.s85'],
    \ 'sisu': ['file.sst', 'file.ssm', 'file.ssi', 'file.-sst', 'file._sst', 'file.sst.meta', 'file.-sst.meta', 'file._sst.meta'],
    \ 'skill': ['file.il', 'file.ils', 'file.cdf'],
    \ 'cdc': ['file.cdc'],
    \ 'slang': ['file.sl'],
    \ 'sage': ['file.sage'],
    \ 'slice': ['file.ice'],
    \ 'slint': ['file.slint'],
    \ 'slpconf': ['/etc/slp.conf', 'any/etc/slp.conf'],
    \ 'slpreg': ['/etc/slp.reg', 'any/etc/slp.reg'],
    \ 'slpspi': ['/etc/slp.spi', 'any/etc/slp.spi'],
    \ 'slrnrc': ['.slrnrc'],
    \ 'slrnsc': ['file.score'],
    \ 'sm': ['sendmail.cf'],
    \ 'smali': ['file.smali'],
    \ 'smarty': ['file.tpl'],
    \ 'smcl': ['file.hlp', 'file.ihlp', 'file.smcl'],
    \ 'smith': ['file.smt', 'file.smith'],
    \ 'smithy': ['file.smithy'],
    \ 'sml': ['file.sml'],
    \ 'snakemake': ['file.smk', 'Snakefile'],
    \ 'snobol4': ['file.sno', 'file.spt'],
    \ 'solidity': ['file.sol'],
    \ 'solution': ['file.sln'],
    \ 'sparql': ['file.rq', 'file.sparql'],
    \ 'spec': ['file.spec'],
    \ 'spice': ['file.sp', 'file.spice'],
    \ 'spup': ['file.speedup', 'file.spdata', 'file.spd'],
    \ 'spyce': ['file.spy', 'file.spi'],
    \ 'sql': ['file.tyb', 'file.tyc', 'file.pkb', 'file.pks', '.sqlite_history'],
    \ 'sqlj': ['file.sqlj'],
    \ 'prql': ['file.prql'],
    \ 'sqr': ['file.sqr', 'file.sqi'],
    \ 'squid': ['squid.conf'],
    \ 'squirrel': ['file.nut'],
    \ 'srec': ['file.s19', 'file.s28', 'file.s37', 'file.mot', 'file.srec'],
    \ 'srt': ['file.srt'],
    \ 'ssa': ['file.ass', 'file.ssa'],
    \ 'sshconfig': ['ssh_config', '/.ssh/config', '/etc/ssh/ssh_config.d/file.conf', 'any/etc/ssh/ssh_config.d/file.conf', 'any/.ssh/config', 'any/.ssh/file.conf'],
    \ 'sshdconfig': ['sshd_config', '/etc/ssh/sshd_config.d/file.conf', 'any/etc/ssh/sshd_config.d/file.conf'],
    \ 'st': ['file.st'],
    \ 'starlark': ['file.ipd', 'file.star', 'file.starlark'],
    \ 'stata': ['file.ado', 'file.do', 'file.imata', 'file.mata'],
    \ 'stp': ['file.stp'],
    \ 'stylus': ['a.styl', 'file.stylus'],
    \ 'sudoers': ['any/etc/sudoers', 'sudoers.tmp', '/etc/sudoers', 'any/etc/sudoers.d/file'],
    \ 'supercollider': ['file.quark'],
    \ 'surface': ['file.sface'],
    \ 'svelte': ['file.svelte'],
    \ 'svg': ['file.svg'],
    \ 'svn': ['svn-commitfile.tmp', 'svn-commit-file.tmp', 'svn-commit.tmp'],
    \ 'swayconfig': ['/home/user/.sway/config', '/home/user/.config/sway/config', '/etc/sway/config', '/etc/xdg/sway/config'],
    \ 'swift': ['file.swift'],
    \ 'swiftgyb': ['file.swift.gyb'],
    \ 'swig': ['file.swg', 'file.swig'],
    \ 'sysctl': ['/etc/sysctl.conf', '/etc/sysctl.d/file.conf', 'any/etc/sysctl.conf', 'any/etc/sysctl.d/file.conf'],
    \ 'systemd': ['any/systemd/file.automount', 'any/systemd/file.dnssd',
    \             'any/systemd/file.link', 'any/systemd/file.mount',
    \             'any/systemd/file.netdev', 'any/systemd/file.network',
    \             'any/systemd/file.nspawn', 'any/systemd/file.path',
    \             'any/systemd/file.service', 'any/systemd/file.slice',
    \             'any/systemd/file.socket', 'any/systemd/file.swap',
    \             'any/systemd/file.target', 'any/systemd/file.timer',
    \             '/etc/systemd/some.conf.d/file.conf',
    \             '/etc/systemd/system/some.d/file.conf',
    \             '/etc/systemd/system/some.d/.#file',
    \             '/etc/systemd/system/.#otherfile',
    \             '/home/user/.config/systemd/user/some.d/mine.conf',
    \             '/home/user/.config/systemd/user/some.d/.#file',
    \             '/home/user/.config/systemd/user/.#otherfile',
    \             '/.config/systemd/user/.#', '/.config/systemd/user/.#-file',
    \             '/.config/systemd/user/file.d/.#',
    \             '/.config/systemd/user/file.d/.#-file',
    \             '/.config/systemd/user/file.d/file.conf',
    \             '/etc/systemd/file.conf.d/file.conf', '/etc/systemd/system/.#',
    \             '/etc/systemd/system/.#-file', '/etc/systemd/system/file.d/.#',
    \             '/etc/systemd/system/file.d/.#-file',
    \             '/etc/systemd/system/file.d/file.conf',
    \             '/systemd/file.automount', '/systemd/file.dnssd',
    \             '/systemd/file.link', '/systemd/file.mount',
    \             '/systemd/file.netdev', '/systemd/file.network',
    \             '/systemd/file.nspawn', '/systemd/file.path',
    \             '/systemd/file.service', '/systemd/file.slice',
    \             '/systemd/file.socket', '/systemd/file.swap',
    \             '/systemd/file.target', '/systemd/file.timer',
    \             'any/.config/systemd/user/.#',
    \             'any/.config/systemd/user/.#-file',
    \             'any/.config/systemd/user/file.d/.#',
    \             'any/.config/systemd/user/file.d/.#-file',
    \             'any/.config/systemd/user/file.d/file.conf',
    \             'any/etc/systemd/file.conf.d/file.conf',
    \             'any/etc/systemd/system/.#', 'any/etc/systemd/system/.#-file',
    \             'any/etc/systemd/system/file.d/.#',
    \             'any/etc/systemd/system/file.d/.#-file',
    \             'any/etc/systemd/system/file.d/file.conf'],
    \ 'systemverilog': ['file.sv', 'file.svh'],
    \ 'trace32': ['file.cmm', 'file.t32'],
    \ 'tags': ['tags'],
    \ 'tak': ['file.tak'],
    \ 'tal': ['file.tal'],
    \ 'taskdata': ['pending.data', 'completed.data', 'undo.data'],
    \ 'taskedit': ['file.task'],
    \ 'tcl': ['file.tcl', 'file.tm', 'file.tk', 'file.itcl', 'file.itk', 'file.jacl', '.tclshrc', 'tclsh.rc', '.wishrc', '.tclsh-history', '.xsctcmdhistory', '.xsdbcmdhistory'],
    \ 'tablegen': ['file.td'],
    \ 'teal': ['file.tl'],
    \ 'templ': ['file.templ'],
    \ 'template': ['file.tmpl'],
    \ 'teraterm': ['file.ttl'],
    \ 'terminfo': ['file.ti'],
    \ 'terraform-vars': ['file.tfvars'],
    \ 'tex': ['file.latex', 'file.sty', 'file.dtx', 'file.ltx', 'file.bbl', 'any/.texlive/texmf-config/tex/latex/file/file.cfg', 'file.pgf', 'file.nlo', 'file.nls', 'file.thm', 'file.eps_tex', 'file.pygtex', 'file.pygstyle', 'file.clo', 'file.aux', 'file.brf', 'file.ind', 'file.lof', 'file.loe', 'file.nav', 'file.vrb', 'file.ins', 'file.tikz', 'file.bbx', 'file.cbx', 'file.beamer', 'file.pdf_tex'],
    \ 'texinfo': ['file.texinfo', 'file.texi', 'file.txi'],
    \ 'texmf': ['texmf.cnf'],
    \ 'text': ['file.text', 'file.txt', 'README', 'LICENSE', 'COPYING', 'AUTHORS', '/usr/share/doc/bash-completion/AUTHORS', '/etc/apt/apt.conf.d/README', '/etc/Muttrc.d/README'],
    \ 'tf': ['file.tf', '.tfrc', 'tfrc'],
    \ 'thrift': ['file.thrift'],
    \ 'tidy': ['.tidyrc', 'tidyrc', 'tidy.conf'],
    \ 'tilde': ['file.t.html'],
    \ 'tla': ['file.tla'],
    \ 'tli': ['file.tli'],
    \ 'tmux': ['tmuxfile.conf', '.tmuxfile.conf', '.tmux-file.conf', '.tmux.conf', 'tmux-file.conf', 'tmux.conf', 'tmux.conf.local'],
    \ 'toml': ['file.toml', 'Gopkg.lock', 'Pipfile', '/home/user/.cargo/config', '.black'],
    \ 'tpp': ['file.tpp'],
    \ 'treetop': ['file.treetop'],
    \ 'trustees': ['trustees.conf'],
    \ 'tsalt': ['file.slt'],
    \ 'tsscl': ['file.tsscl'],
    \ 'tssgm': ['file.tssgm'],
    \ 'tssop': ['file.tssop'],
    \ 'tsv': ['file.tsv'],
    \ 'twig': ['file.twig'],
    \ 'typescript': ['file.mts', 'file.cts', '.ts_node_repl_history'],
    \ 'typescript.glimmer': ['file.gts'],
    \ 'typescriptreact': ['file.tsx'],
    \ 'typespec': ['file.tsp'],
    \ 'ungrammar': ['file.ungram'],
    \ 'uc': ['file.uc'],
    \ 'udevconf': ['/etc/udev/udev.conf', 'any/etc/udev/udev.conf'],
    \ 'udevperm': ['/etc/udev/permissions.d/file.permissions', 'any/etc/udev/permissions.d/file.permissions'],
    \ 'udevrules': ['/etc/udev/rules.d/file.rules', '/usr/lib/udev/rules.d/file.rules', '/lib/udev/rules.d/file.rules'],
    \ 'uil': ['file.uit', 'file.uil'],
    \ 'unison': ['file.u', 'file.uu'],
    \ 'updatedb': ['/etc/updatedb.conf', 'any/etc/updatedb.conf'],
    \ 'upstart': ['/usr/share/upstart/file.conf', '/usr/share/upstart/file.override', '/etc/init/file.conf', '/etc/init/file.override', '/.init/file.conf', '/.init/file.override', '/.config/upstart/file.conf', '/.config/upstart/file.override', 'any/.config/upstart/file.conf', 'any/.config/upstart/file.override', 'any/.init/file.conf', 'any/.init/file.override', 'any/etc/init/file.conf', 'any/etc/init/file.override', 'any/usr/share/upstart/file.conf', 'any/usr/share/upstart/file.override'],
    \ 'upstreamdat': ['upstream.dat', 'UPSTREAM.DAT', 'upstream.file.dat', 'UPSTREAM.FILE.DAT', 'file.upstream.dat', 'FILE.UPSTREAM.DAT'],
    \ 'upstreaminstalllog': ['upstreaminstall.log', 'UPSTREAMINSTALL.LOG', 'upstreaminstall.file.log', 'UPSTREAMINSTALL.FILE.LOG', 'file.upstreaminstall.log', 'FILE.UPSTREAMINSTALL.LOG'],
    \ 'upstreamlog': ['fdrupstream.log', 'upstream.log', 'UPSTREAM.LOG', 'upstream.file.log', 'UPSTREAM.FILE.LOG', 'file.upstream.log', 'FILE.UPSTREAM.LOG', 'UPSTREAM-file.log', 'UPSTREAM-FILE.LOG'],
    \ 'urlshortcut': ['file.url'],
    \ 'usd': ['file.usda', 'file.usd'],
    \ 'usserverlog': ['usserver.log', 'USSERVER.LOG', 'usserver.file.log', 'USSERVER.FILE.LOG', 'file.usserver.log', 'FILE.USSERVER.LOG'],
    \ 'usw2kagtlog': ['usw2kagt.log', 'USW2KAGT.LOG', 'usw2kagt.file.log', 'USW2KAGT.FILE.LOG', 'file.usw2kagt.log', 'FILE.USW2KAGT.LOG'],
    \ 'v': ['file.vsh', 'file.vv'],
    \ 'vala': ['file.vala'],
    \ 'vb': ['file.sba', 'file.vb', 'file.vbs', 'file.dsm', 'file.ctl', 'file.dob', 'file.dsr'],
    \ 'vdf': ['file.vdf'],
    \ 'vdmpp': ['file.vpp', 'file.vdmpp'],
    \ 'vdmrt': ['file.vdmrt'],
    \ 'vdmsl': ['file.vdm', 'file.vdmsl'],
    \ 'vento': ['file.vto'],
    \ 'vera': ['file.vr', 'file.vri', 'file.vrh'],
    \ 'verilogams': ['file.va', 'file.vams'],
    \ 'vgrindefs': ['vgrindefs'],
    \ 'vhdl': ['file.hdl', 'file.vhd', 'file.vhdl', 'file.vbe', 'file.vst', 'file.vhdl_123', 'file.vho', 'some.vhdl_1', 'some.vhdl_1-file'],
    \ 'vhs': ['file.tape'],
    \ 'vim': ['file.vim', '.exrc', '_exrc', 'some-vimrc', 'some-vimrc-file', 'vimrc', 'vimrc-file', '.netrwhist'],
    \ 'viminfo': ['.viminfo', '_viminfo'],
    \ 'vmasm': ['file.mar'],
    \ 'voscm': ['file.cm'],
    \ 'vrml': ['file.wrl'],
    \ 'vroom': ['file.vroom'],
    \ 'vue': ['file.vue'],
    \ 'wat': ['file.wat', 'file.wast'],
    \ 'wdl': ['file.wdl'],
    \ 'webmacro': ['file.wm'],
    \ 'wget': ['.wgetrc', 'wgetrc'],
    \ 'wget2': ['.wget2rc', 'wget2rc'],
    \ 'wgsl': ['file.wgsl'],
    \ 'winbatch': ['file.wbt'],
    \ 'wit': ['file.wit'],
    \ 'wml': ['file.wml'],
    \ 'wsh': ['file.wsf', 'file.wsc'],
    \ 'wsml': ['file.wsml'],
    \ 'wvdial': ['wvdial.conf', '.wvdialrc'],
    \ 'xcompose': ['.XCompose', 'Compose'],
    \ 'xdefaults': ['.Xdefaults', '.Xpdefaults', '.Xresources', 'xdm-config', 'file.ad', '/Xresources/file', '/app-defaults/file', 'Xresources', 'Xresources-file', 'any/Xresources/file', 'any/app-defaults/file'],
    \ 'xf86conf': ['xorg.conf', 'xorg.conf-4'],
    \ 'xhtml': ['file.xhtml', 'file.xht'],
    \ 'xinetd': ['/etc/xinetd.conf', '/etc/xinetd.d/file', 'any/etc/xinetd.conf', 'any/etc/xinetd.d/file'],
    \ 'xkb': ['/usr/share/X11/xkb/compat/pc', '/usr/share/X11/xkb/geometry/pc', '/usr/share/X11/xkb/keycodes/evdev', '/usr/share/X11/xkb/symbols/pc', '/usr/share/X11/xkb/types/pc'],
    \ 'xmath': ['file.msc', 'file.msf'],
    \ 'xml': ['/etc/blkid.tab', '/etc/blkid.tab.old', 'file.xmi', 'file.csproj', 'file.csproj.user', 'file.fsproj', 'file.fsproj.user', 'file.vbproj', 'file.vbproj.user', 'file.ui', 'file.tpm', '/etc/xdg/menus/file.menu', 'fglrxrc', 'file.xlf', 'file.xliff', 'file.xul', 'file.wsdl', 'file.wpl', 'any/etc/blkid.tab', 'any/etc/blkid.tab.old', 'any/etc/xdg/menus/file.menu', 'file.atom', 'file.rss', 'file.cdxml', 'file.psc1', 'file.mpd', 'fonts.conf', 'file.xcu', 'file.xlb', 'file.xlc', 'file.xba', 'file.xpr', 'file.xpfm', 'file.spfm', 'file.bxml'],
    \ 'xmodmap': ['anyXmodmap', 'Xmodmap', 'some-Xmodmap', 'some-xmodmap', 'some-xmodmap-file', 'xmodmap', 'xmodmap-file'],
    \ 'xpm': ['file.xpm'],
    \ 'xpm2': ['file.xpm2'],
    \ 'xquery': ['file.xq', 'file.xql', 'file.xqm', 'file.xquery', 'file.xqy'],
    \ 'xs': ['file.xs'],
    \ 'xsd': ['file.xsd'],
    \ 'xslt': ['file.xsl', 'file.xslt'],
    \ 'yacc': ['file.yy', 'file.yxx', 'file.y++'],
    \ 'yaml': ['file.yaml', 'file.yml', 'file.eyaml', 'any/.bundle/config', '.clangd', '.clang-format', '.clang-tidy', 'file.mplstyle', 'matplotlibrc', 'yarn.lock'],
    \ 'yang': ['file.yang'],
    \ 'yuck': ['file.yuck'],
    \ 'z8a': ['file.z8a'],
    \ 'zathurarc': ['zathurarc'],
    \ 'zig': ['file.zig', 'build.zig.zon'],
    \ 'zimbu': ['file.zu'],
    \ 'zimbutempl': ['file.zut'],
    \ 'zserio': ['file.zs'],
    \ 'zsh': ['.zprofile', '/etc/zprofile', '.zfbfmarks', 'file.zsh', 'file.zsh-theme', 'file.zunit',
    \         '.zcompdump', '.zlogin', '.zlogout', '.zshenv', '.zshrc', '.zsh_history',
    \         '.zcompdump-file', '.zlog', '.zlog-file', '.zsh', '.zsh-file',
    \         'any/etc/zprofile', 'zlog', 'zlog-file', 'zsh', 'zsh-file'],
    \
    \ 'help': [$VIMRUNTIME .. '/doc/help.txt'],
    \ }
endfunc

func s:GetFilenameCaseChecks() abort
  return {
    \ 'modula2': ['file.DEF'],
    \ 'bzl': ['file.BUILD', 'BUILD', 'BUCK'],
    \ }
endfunc

func CheckItems(checks)
  set noswapfile
  for [ft, names] in items(a:checks)
    for i in range(0, len(names) - 1)
      new
      try
        exe 'edit ' .. fnameescape(names[i])
      catch
	call assert_report('cannot edit "' .. names[i] .. '": ' .. v:exception)
      endtry
      if &filetype == '' && &readonly
	" File exists but not able to edit it (permission denied)
      else
        let expected = ft == 'none' ? '' : ft
	call assert_equal(expected, &filetype, 'with file name: ' .. names[i])
      endif
      bwipe!
    endfor
  endfor

  set swapfile&
endfunc

func Test_filetype_detection()
  call s:SetupConfigHome()
  if !empty(s:saveConfigHome)
    defer setenv("XDG_CONFIG_HOME", s:saveConfigHome)
  endif
  call mkdir(s:GetConfigHome(), 'R')

  filetype on
  call CheckItems(s:GetFilenameChecks())
  if has('fname_case')
    call CheckItems(s:GetFilenameCaseChecks())
  endif
  filetype off
endfunc

" Content lines that should not result in filetype detection
func s:GetFalsePositiveChecks() abort
  return {
      \ '': [['test execve("/usr/bin/pstree", ["pstree"], 0x7ff0 /* 63 vars */) = 0']],
      \ }
endfunc

" Filetypes detected from the file contents by scripts.vim
func s:GetScriptChecks() abort
  return {
      \ 'virata': [['% Virata'],
      \            ['', '% Virata'],
      \            ['', '', '% Virata'],
      \            ['', '', '', '% Virata'],
      \            ['', '', '', '', '% Virata']],
      \ 'strace': [['execve("/usr/bin/pstree", ["pstree"], 0x7ff0 /* 63 vars */) = 0'],
      \            ['15:17:47 execve("/usr/bin/pstree", ["pstree"], ... "_=/usr/bin/strace"]) = 0'],
      \            ['__libc_start_main and something']],
      \ 'clojure': [['#!/path/clojure']],
      \ 'scala': [['#!/path/scala']],
      \ 'sh':  [['#!/path/sh'],
      \         ['#!/path/bash'],
      \         ['#!/path/bash2'],
      \         ['#!/path/dash'],
      \         ['#!/path/ksh'],
      \         ['#!/path/ksh93']],
      \ 'csh': [['#!/path/csh']],
      \ 'tcsh': [['#!/path/tcsh']],
      \ 'zsh': [['#!/path/zsh']],
      \ 'tcl': [['#!/path/tclsh'],
      \         ['#!/path/wish'],
      \         ['#!/path/expectk'],
      \         ['#!/path/itclsh'],
      \         ['#!/path/itkwish']],
      \ 'expect': [['#!/path/expect']],
      \ 'execline': [['#!/sbin/execlineb -S0'], ['#!/usr/bin/execlineb']],
      \ 'gnuplot': [['#!/path/gnuplot']],
      \ 'make': [['#!/path/make']],
      \ 'nix': [['#!/path/nix-shell']],
      \ 'pike': [['#!/path/pike'],
      \          ['#!/path/pike0'],
      \          ['#!/path/pike9']],
      \ 'lua': [['#!/path/lua']],
      \ 'raku': [['#!/path/raku']],
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
      \ 'sed': [['#!/path/sed'], ['#n'], ['#n comment']],
      \ 'ocaml': [['#!/path/ocaml']],
      \ 'awk': [['#!/path/awk'],
      \         ['#!/path/gawk']],
      \ 'wml': [['#!/path/wml']],
      \ 'scheme': [['#!/path/scheme'],
      \            ['#!/path/guile']],
      \ 'cfengine': [['#!/path/cfengine']],
      \ 'erlang': [['#!/path/escript']],
      \ 'haskell': [['#!/path/haskell']],
      \ 'cpp': [['// Standard iostream objects -*- C++ -*-'],
      \         ['// -*- C++ -*-']],
      \ 'yaml': [['%YAML 1.2']],
      \ 'pascal': [['#!/path/instantfpc']],
      \ 'fennel': [['#!/path/fennel']],
      \ 'routeros': [['#!/path/rsc']],
      \ 'fish': [['#!/path/fish']],
      \ 'forth': [['#!/path/gforth']],
      \ 'icon': [['#!/path/icon']],
      \ 'crystal': [['#!/path/crystal']],
      \ 'rexx': [['#!/path/rexx'],
      \          ['#!/path/regina']],
      \ 'janet':  [['#!/path/janet']],
      \ 'dart':   [['#!/path/dart']],
      \ 'vim':   [['#!/path/vim']],
      \ }
endfunc

" Various forms of "env" optional arguments.
func s:GetScriptEnvChecks() abort
  return {
      \ 'perl': [['#!/usr/bin/env VAR=val perl']],
      \ 'scala': [['#!/usr/bin/env VAR=val VVAR=vval scala']],
      \ 'awk': [['#!/usr/bin/env VAR=val -i awk']],
      \ 'execline': [['#!/usr/bin/env execlineb']],
      \ 'scheme': [['#!/usr/bin/env VAR=val --ignore-environment scheme']],
      \ 'python': [['#!/usr/bin/env VAR=val -S python -w -T']],
      \ 'wml': [['#!/usr/bin/env VAR=val --split-string wml']],
      \ 'nix': [['#!/usr/bin/env nix-shell']],
      \ }
endfunc

func Run_script_detection(test_dict)
  filetype on
  for [ft, files] in items(a:test_dict)
    for file in files
      call writefile(file, 'Xtest', 'D')
      split Xtest
      call assert_equal(ft, &filetype, 'for text: ' . string(file))
      bwipe!
    endfor
  endfor
  filetype off
endfunc

func Test_script_detection()
  call Run_script_detection(s:GetFalsePositiveChecks())
  call Run_script_detection(s:GetScriptChecks())
  call Run_script_detection(s:GetScriptEnvChecks())
endfunc

func Test_setfiletype_completion()
  call feedkeys(":setfiletype java\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"setfiletype java javacc javascript javascriptreact', @:)
endfunc

" Test for ':filetype detect' command for a buffer without a file
func Test_emptybuf_ftdetect()
  new
  call setline(1, '#!/bin/sh')
  call assert_equal('', &filetype)
  filetype detect
  call assert_equal('sh', &filetype)
  " close the swapfile
  bw!
endfunc

" Test for ':filetype indent on' and ':filetype indent off' commands
func Test_filetype_indent_off()
  new Xtest.vim
  filetype indent on
  call assert_equal(1, g:did_indent_on)
  call assert_equal(['filetype detection:ON  plugin:OFF  indent:ON'],
        \ execute('filetype')->split("\n"))
  filetype indent off
  call assert_equal(0, exists('g:did_indent_on'))
  call assert_equal(['filetype detection:ON  plugin:OFF  indent:OFF'],
        \ execute('filetype')->split("\n"))
  close
endfunc

"""""""""""""""""""""""""""""""""""""""""""""""""
" Tests for specific extensions and filetypes.
" Keep sorted.
"""""""""""""""""""""""""""""""""""""""""""""""""

func Test_bas_file()
  filetype on

  call writefile(['looks like BASIC'], 'Xfile.bas', 'D')
  split Xfile.bas
  call assert_equal('basic', &filetype)
  bwipe!

  " Test dist#ft#FTbas()

  let g:filetype_bas = 'freebasic'
  split Xfile.bas
  call assert_equal('freebasic', &filetype)
  bwipe!
  unlet g:filetype_bas

  " FreeBASIC

  call writefile(["/' FreeBASIC multiline comment '/"], 'Xfile.bas')
  split Xfile.bas
  call assert_equal('freebasic', &filetype)
  bwipe!

  call writefile(['#define TESTING'], 'Xfile.bas')
  split Xfile.bas
  call assert_equal('freebasic', &filetype)
  bwipe!

  call writefile(['option byval'], 'Xfile.bas')
  split Xfile.bas
  call assert_equal('freebasic', &filetype)
  bwipe!

  call writefile(['extern "C"'], 'Xfile.bas')
  split Xfile.bas
  call assert_equal('freebasic', &filetype)
  bwipe!

  " QB64

  call writefile(['$LET TESTING = 1'], 'Xfile.bas')
  split Xfile.bas
  call assert_equal('qb64', &filetype)
  bwipe!

  call writefile(['OPTION _EXPLICIT'], 'Xfile.bas')
  split Xfile.bas
  call assert_equal('qb64', &filetype)
  bwipe!

  " Visual Basic

  call writefile(['Attribute VB_NAME = "Testing"', 'Enum Foo', 'End Enum'], 'Xfile.bas')
  split Xfile.bas
  call assert_equal('vb', &filetype)
  bwipe!

  filetype off
endfunc

" Test dist#ft#FTcfg()
func Test_cfg_file()
  filetype on

  " *.cfg defaults to cfg
  call writefile(['looks like cfg'], 'cfgfile.cfg', 'D')
  split cfgfile.cfg
  call assert_equal('cfg', &filetype)

  let g:filetype_cfg = 'other'
  edit
  call assert_equal('other', &filetype)
  bwipe!
  unlet g:filetype_cfg

  " RAPID cfg
  let ext = 'cfg'
  for i in ['EIO', 'MMC', 'MOC', 'PROC', 'SIO', 'SYS']
    call writefile([i .. ':CFG'], 'cfgfile.' .. ext)
    execute "split cfgfile." .. ext
    call assert_equal('rapid', &filetype)
    bwipe!
    call delete('cfgfile.' .. ext)
    " check different case of file extension
    let ext = substitute(ext, '\(\l\)', '\u\1', '')
  endfor

  " clean up
  filetype off
endfunc

func Test_d_file()
  filetype on

  call writefile(['looks like D'], 'Xfile.d', 'D')
  split Xfile.d
  call assert_equal('d', &filetype)
  bwipe!

  call writefile(['#!/some/bin/dtrace'], 'Xfile.d')
  split Xfile.d
  call assert_equal('dtrace', &filetype)
  bwipe!

  call writefile(['#pragma  D  option'], 'Xfile.d')
  split Xfile.d
  call assert_equal('dtrace', &filetype)
  bwipe!

  call writefile([':some:thing:'], 'Xfile.d')
  split Xfile.d
  call assert_equal('dtrace', &filetype)
  bwipe!

  call writefile(['module this', '#pragma  D  option'], 'Xfile.d')
  split Xfile.d
  call assert_equal('d', &filetype)
  bwipe!

  call writefile(['import that', '#pragma  D  option'], 'Xfile.d')
  split Xfile.d
  call assert_equal('d', &filetype)
  bwipe!

  " clean up
  filetype off
endfunc

func Test_dat_file()
  filetype on

  " KRL header start with "&WORD", but is not always present.
  call writefile(['&ACCESS'], 'datfile.dat')
  split datfile.dat
  call assert_equal('krl', &filetype)
  bwipe!
  call delete('datfile.dat')

  " KRL defdat with leading spaces, for KRL file extension is not case
  " sensitive.
  call writefile(['  DEFDAT datfile'], 'datfile.Dat')
  split datfile.Dat
  call assert_equal('krl', &filetype)
  bwipe!
  call delete('datfile.Dat')

  " KRL defdat with embedded spaces, file starts with empty line(s).
  call writefile(['', 'defdat  datfile  public'], 'datfile.DAT')
  split datfile.DAT
  call assert_equal('krl', &filetype)
  bwipe!

  " User may overrule file inspection
  let g:filetype_dat = 'dat'
  split datfile.DAT
  call assert_equal('dat', &filetype)
  bwipe!
  call delete('datfile.DAT')
  unlet g:filetype_dat

  filetype off
endfunc

func Test_dep3patch_file()
  filetype on

  call assert_true(mkdir('debian/patches', 'pR'))

  " series files are not patches
  call writefile(['Description: some awesome patch'], 'debian/patches/series')
  split debian/patches/series
  call assert_notequal('dep3patch', &filetype)
  bwipe!

  " diff/patch files without the right headers should still show up as ft=diff
  call writefile([], 'debian/patches/foo.diff')
  split debian/patches/foo.diff
  call assert_equal('diff', &filetype)
  bwipe!

  " Files with the right headers are detected as dep3patch, even if they don't
  " have a diff/patch extension
  call writefile(['Subject: dep3patches'], 'debian/patches/bar')
  split debian/patches/bar
  call assert_equal('dep3patch', &filetype)
  bwipe!

  " Files in sub-directories are detected
  call assert_true(mkdir('debian/patches/s390x', 'p'))
  call writefile(['Subject: dep3patches'], 'debian/patches/s390x/bar')
  split debian/patches/s390x/bar
  call assert_equal('dep3patch', &filetype)
  bwipe!

  " The detection stops when seeing the "header end" marker
  call writefile(['---', 'Origin: the cloud'], 'debian/patches/baz')
  split debian/patches/baz
  call assert_notequal('dep3patch', &filetype)
  bwipe!
endfunc

func Test_dsl_file()
  filetype on

  call writefile(['  <!doctype dsssl-spec ['], 'dslfile.dsl', 'D')
  split dslfile.dsl
  call assert_equal('dsl', &filetype)
  bwipe!

  call writefile(['workspace {'], 'dslfile.dsl')
  split dslfile.dsl
  call assert_equal('structurizr', &filetype)
  bwipe!

  filetype off
endfunc

func Test_ex_file()
  filetype on

  call writefile(['arbitrary content'], 'Xfile.ex', 'D')
  split Xfile.ex
  call assert_equal('elixir', &filetype)
  bwipe!
  let g:filetype_euphoria = 'euphoria4'
  split Xfile.ex
  call assert_equal('euphoria4', &filetype)
  bwipe!
  unlet g:filetype_euphoria

  call writefile(['-- filetype euphoria comment'], 'Xfile.ex')
  split Xfile.ex
  call assert_equal('euphoria3', &filetype)
  bwipe!

  call writefile(['--filetype euphoria comment'], 'Xfile.ex')
  split Xfile.ex
  call assert_equal('euphoria3', &filetype)
  bwipe!

  call writefile(['ifdef '], 'Xfile.ex')
  split Xfile.ex
  call assert_equal('euphoria3', &filetype)
  bwipe!

  call writefile(['include '], 'Xfile.ex')
  split Xfile.ex
  call assert_equal('euphoria3', &filetype)
  bwipe!

  filetype off
endfunc

func Test_f_file()
  filetype on

  call writefile(['looks like Fortran'], 'Xfile.f', 'D')
  split Xfile.f
  call assert_equal('fortran', &filetype)
  bwipe!

  let g:filetype_f = 'forth'
  split Xfile.f
  call assert_equal('forth', &filetype)
  bwipe!
  unlet g:filetype_f

  " Test dist#ft#FTf()

  " Forth

  call writefile(['( Forth inline comment )'], 'Xfile.f')
  split Xfile.f
  call assert_equal('forth', &filetype)
  bwipe!

  call writefile(['\ Forth line comment'], 'Xfile.f')
  split Xfile.f
  call assert_equal('forth', &filetype)
  bwipe!

  call writefile([': squared ( n -- n^2 )', 'dup * ;'], 'Xfile.f')
  split Xfile.f
  call assert_equal('forth', &filetype)
  bwipe!

  " SwiftForth

  call writefile(['{ ================', 'Header comment', '================ }'], 'Xfile.f')
  split Xfile.f
  call assert_equal('forth', &filetype)
  bwipe!

  call writefile(['OPTIONAL Maybe Descriptive text'], 'Xfile.f')
  split Xfile.f
  call assert_equal('forth', &filetype)
  bwipe!

  filetype off
endfunc

func Test_foam_file()
  filetype on
  call assert_true(mkdir('0', 'pR'))
  call assert_true(mkdir('0.orig', 'pR'))

  call writefile(['FoamFile {', '    object something;'], 'Xfile1Dict', 'D')
  split Xfile1Dict
  call assert_equal('foam', &filetype)
  bwipe!

  call writefile(['FoamFile {', '    object something;'], 'Xfile1Dict.something', 'D')
  split Xfile1Dict.something
  call assert_equal('foam', &filetype)
  bwipe!

  call writefile(['FoamFile {', '    object something;'], 'XfileProperties', 'D')
  split XfileProperties
  call assert_equal('foam', &filetype)
  bwipe!

  call writefile(['FoamFile {', '    object something;'], 'XfileProperties.something', 'D')
  split XfileProperties.something
  call assert_equal('foam', &filetype)
  bwipe!

  call writefile(['FoamFile {', '    object something;'], 'XfileProperties')
  split XfileProperties
  call assert_equal('foam', &filetype)
  bwipe!

  call writefile(['FoamFile {', '    object something;'], 'XfileProperties.something')
  split XfileProperties.something
  call assert_equal('foam', &filetype)
  bwipe!

  call writefile(['FoamFile {', '    object something;'], '0/Xfile')
  split 0/Xfile
  call assert_equal('foam', &filetype)
  bwipe!

  call writefile(['FoamFile {', '    object something;'], '0.orig/Xfile')
  split 0.orig/Xfile
  call assert_equal('foam', &filetype)
  bwipe!

  filetype off
endfunc

func Test_frm_file()
  filetype on

  call writefile(['looks like FORM'], 'Xfile.frm', 'D')
  split Xfile.frm
  call assert_equal('form', &filetype)
  bwipe!

  " Test dist#ft#FTfrm()

  let g:filetype_frm = 'form'
  split Xfile.frm
  call assert_equal('form', &filetype)
  bwipe!
  unlet g:filetype_frm

  " Visual Basic

  call writefile(['VERSION 5.00', 'Begin VB.Form Form1'], 'Xfile.frm')
  split Xfile.frm
  call assert_equal('vb', &filetype)
  bwipe!

  filetype off
endfunc

func Test_fs_file()
  filetype on

  call writefile(['looks like F#'], 'Xfile.fs', 'D')
  split Xfile.fs
  call assert_equal('fsharp', &filetype)
  bwipe!

  let g:filetype_fs = 'forth'
  split Xfile.fs
  call assert_equal('forth', &filetype)
  bwipe!
  unlet g:filetype_fs

  " Test dist#ft#FTfs()

  " Forth

  call writefile(['( Forth inline comment )'], 'Xfile.fs')
  split Xfile.fs
  call assert_equal('forth', &filetype)
  bwipe!

  call writefile(['\ Forth line comment'], 'Xfile.fs')
  split Xfile.fs
  call assert_equal('forth', &filetype)
  bwipe!

  call writefile([': squared ( n -- n^2 )', 'dup * ;'], 'Xfile.fs')
  split Xfile.fs
  call assert_equal('forth', &filetype)
  bwipe!

  " SwiftForth

  call writefile(['{ ================', 'Header comment', '================ }'], 'Xfile.fs')
  split Xfile.fs
  call assert_equal('forth', &filetype)
  bwipe!

  call writefile(['OPTIONAL Maybe Descriptive text'], 'Xfile.fs')
  split Xfile.fs
  call assert_equal('forth', &filetype)
  bwipe!

  filetype off
endfunc

func Test_git_file()
  filetype on

  call assert_true(mkdir('Xrepo.git', 'pR'))

  call writefile([], 'Xrepo.git/HEAD')
  split Xrepo.git/HEAD
  call assert_equal('', &filetype)
  bwipe!

  call writefile(['0000000000000000000000000000000000000000'], 'Xrepo.git/HEAD')
  split Xrepo.git/HEAD
  call assert_equal('git', &filetype)
  bwipe!

  call writefile(['0000000000000000000000000000000000000000000000000000000000000000'], 'Xrepo.git/HEAD')
  split Xrepo.git/HEAD
  call assert_equal('git', &filetype)
  bwipe!

  call writefile(['ref: refs/heads/master'], 'Xrepo.git/HEAD')
  split Xrepo.git/HEAD
  call assert_equal('git', &filetype)
  bwipe!

  filetype off
endfunc

func Test_haredoc_file()
  filetype on
  call assert_true(mkdir('foo/bar', 'pR'))

  call writefile([], 'README', 'D')
  split README
  call assert_notequal('haredoc', &filetype)
  bwipe!

  let g:filetype_haredoc = 1
  split README
  call assert_notequal('haredoc', &filetype)
  bwipe!

  call writefile([], 'foo/quux.ha')
  split README
  call assert_equal('haredoc', &filetype)
  bwipe!
  call delete('foo/quux.ha')

  call writefile([], 'foo/bar/baz.ha', 'D')
  split README
  call assert_notequal('haredoc', &filetype)
  bwipe!

  let g:haredoc_search_depth = 2
  split README
  call assert_equal('haredoc', &filetype)
  bwipe!
  unlet g:filetype_haredoc
  unlet g:haredoc_search_depth

  filetype off
endfunc

func Test_hook_file()
  filetype on

  call writefile(['[Trigger]', 'this is pacman config'], 'Xfile.hook', 'D')
  split Xfile.hook
  call assert_equal('confini', &filetype)
  bwipe!

  call writefile(['not pacman'], 'Xfile.hook')
  split Xfile.hook
  call assert_notequal('confini', &filetype)
  bwipe!

  filetype off
endfunc

func Test_html_file()
  filetype on

  " HTML Angular
  let content = ['@for (item of items; track item.name) {', '  <li> {{ item.name }}</li>', '} @empty {', '  <li> There are no items.</li>', '}']
  call writefile(content, 'Xfile.html', 'D')
  split Xfile.html
  call assert_equal('htmlangular', &filetype)
  bwipe!

  " Django Template
  let content = ['{% if foobar %}',
      \ '    <ul>',
      \ '    {% for question in list %}',
      \ '        <li><a href="/polls/{{ question.id }}/">{{ question.question_text }}</a></li>',
      \ '    {% endfor %}',
      \ '    </ul>',
      \ '{% else %}',
      \ '    <p>No polls are available.</p>',
      \ '{% endif %}']
  call writefile(content, 'Xfile.html', 'D')
  split Xfile.html
  call assert_equal('htmldjango', &filetype)
  bwipe!

  " regular HTML
  let content = ['<!DOCTYPE html>', '<html>', '    <head>Foobar</head>', '    <body>Content', '    </body>', '</html>']
  call writefile(content, 'Xfile.html', 'D')
  split Xfile.html
  call assert_equal('html', &filetype)
  bwipe!

  filetype off
endfunc

func Test_m_file()
  filetype on

  call writefile(['looks like Matlab'], 'Xfile.m', 'D')
  split Xfile.m
  call assert_equal('matlab', &filetype)
  bwipe!

  let g:filetype_m = 'octave'
  split Xfile.m
  call assert_equal('octave', &filetype)
  bwipe!
  unlet g:filetype_m

  " Test dist#ft#FTm()

  " Objective-C

  call writefile(['// Objective-C line comment'], 'Xfile.m')
  split Xfile.m
  call assert_equal('objc', &filetype)
  bwipe!

  call writefile(['/* Objective-C block comment */'], 'Xfile.m')
  split Xfile.m
  call assert_equal('objc', &filetype)
  bwipe!

  call writefile(['#import "test.m"'], 'Xfile.m')
  split Xfile.m
  call assert_equal('objc', &filetype)
  bwipe!

  call writefile(['#include <header.h>'], 'Xfile.m')
  split Xfile.m
  call assert_equal('objc', &filetype)
  bwipe!

  call writefile(['#define FORTY_TWO'], 'Xfile.m')
  split Xfile.m
  call assert_equal('objc', &filetype)
  bwipe!

  " Octave

  call writefile(['# Octave line comment'], 'Xfile.m')
  split Xfile.m
  call assert_equal('octave', &filetype)
  bwipe!

  call writefile(['%!test "Octave test"'], 'Xfile.m')
  split Xfile.m
  call assert_equal('octave', &filetype)
  bwipe!

  call writefile(['unwind_protect'], 'Xfile.m')
  split Xfile.m
  call assert_equal('octave', &filetype)
  bwipe!

  call writefile(['try; 42; end_try_catch'], 'Xfile.m')
  split Xfile.m
  call assert_equal('octave', &filetype)
  bwipe!

  " Mathematica

  call writefile(['(* Mathematica comment'], 'Xfile.m')
  split Xfile.m
  call assert_equal('mma', &filetype)
  bwipe!

  " MATLAB

  call writefile(['% MATLAB line comment'], 'Xfile.m')
  split Xfile.m
  call assert_equal('matlab', &filetype)
  bwipe!

  " Murphi

  call writefile(['-- Murphi comment'], 'Xfile.m')
  split Xfile.m
  call assert_equal('murphi', &filetype)
  bwipe!

  call writefile(['/* Murphi block comment */', 'Type'], 'Xfile.m')
  split Xfile.m
  call assert_equal('murphi', &filetype)
  bwipe!

  call writefile(['Type'], 'Xfile.m')
  split Xfile.m
  call assert_equal('murphi', &filetype)
  bwipe!

  filetype off
endfunc

func Test_mod_file()
  filetype on

  " *.mod defaults to Modsim III
  call writefile(['locks like Modsim III'], 'Xfile.mod', 'D')
  split Xfile.mod
  call assert_equal('modsim3', &filetype)
  bwipe!

  " Users preference set by g:filetype_mod
  let g:filetype_mod = 'lprolog'
  split Xfile.mod
  call assert_equal('lprolog', &filetype)
  unlet g:filetype_mod
  bwipe!

  " LambdaProlog module
  call writefile(['module lpromod.'], 'Xfile.mod')
  split Xfile.mod
  call assert_equal('lprolog', &filetype)
  bwipe!

  " LambdaProlog with comment and empty lines prior module
  call writefile(['', '% with',  '% comment', '', 'module lpromod.'], 'Xfile.mod')
  split Xfile.mod
  call assert_equal('lprolog', &filetype)
  bwipe!

  " RAPID header start with a line containing only "%%%",
  " but is not always present.
  call writefile(['%%%'], 'Xfile.mod')
  split Xfile.mod
  call assert_equal('rapid', &filetype)
  bwipe!

  " RAPID supports umlauts in module names, leading spaces,
  " the .mod extension is not case sensitive.
  call writefile(['  module ÜmlautModule'], 'Xfile.Mod', 'D')
  split Xfile.Mod
  call assert_equal('rapid', &filetype)
  bwipe!

  " RAPID is not case sensitive, embedded spaces, sysmodule,
  " file starts with empty line(s).
  call writefile(['', 'MODULE  rapidmödüle  (SYSMODULE,NOSTEPIN)'], 'Xfile.MOD', 'D')
  split Xfile.MOD
  call assert_equal('rapid', &filetype)
  bwipe!

  " Modula-2 MODULE not start of line
  call writefile(['IMPLEMENTATION MODULE Module2Mod;'], 'Xfile.mod')
  split Xfile.mod
  call assert_equal('modula2', &filetype)
  call assert_equal('pim', b:modula2.dialect)
  bwipe!

  " Modula-2 with comment and empty lines prior MODULE
  call writefile(['', '(* with',  ' comment *)', '', 'MODULE Module2Mod;'], 'Xfile.mod')
  split Xfile.mod
  call assert_equal('modula2', &filetype)
  call assert_equal('pim', b:modula2.dialect)
  bwipe!

  " Modula-2 program MODULE with priority (and uppercase extension)
  call writefile(['MODULE Module2Mod [42];'], 'Xfile.MOD')
  split Xfile.MOD
  call assert_equal('modula2', &filetype)
  call assert_equal('pim', b:modula2.dialect)
  bwipe!

  " Modula-2 implementation MODULE with priority (and uppercase extension)
  call writefile(['IMPLEMENTATION MODULE Module2Mod [42];'], 'Xfile.MOD')
  split Xfile.MOD
  call assert_equal('modula2', &filetype)
  call assert_equal('pim', b:modula2.dialect)
  bwipe!

  " go.mod
  call writefile(['module example.com/M'], 'go.mod', 'D')
  split go.mod
  call assert_equal('gomod', &filetype)
  bwipe!

  call writefile(['module M'], 'go.mod')
  split go.mod
  call assert_equal('gomod', &filetype)
  bwipe!

  filetype off
endfunc

func Test_patch_file()
  filetype on

  call writefile([], 'Xfile.patch', 'D')
  split Xfile.patch
  call assert_equal('diff', &filetype)
  bwipe!

  call writefile(['From 0000000000000000000000000000000000000000 Mon Sep 17 00:00:00 2001'], 'Xfile.patch')
  split Xfile.patch
  call assert_equal('gitsendemail', &filetype)
  bwipe!

  call writefile(['From 0000000000000000000000000000000000000000000000000000000000000000 Mon Sep 17 00:00:00 2001'], 'Xfile.patch')
  split Xfile.patch
  call assert_equal('gitsendemail', &filetype)
  bwipe!

  filetype off
endfunc

func Test_perl_file()
  filetype on

  " only tests one case, should do more
  let lines =<< trim END

    use a
  END
  call writefile(lines, "Xfile.t", 'D')
  split Xfile.t
  call assert_equal('perl', &filetype)
  bwipe

  filetype off
endfunc

func Test_pp_file()
  filetype on

  call writefile(['looks like puppet'], 'Xfile.pp', 'D')
  split Xfile.pp
  call assert_equal('puppet', &filetype)
  bwipe!

  let g:filetype_pp = 'pascal'
  split Xfile.pp
  call assert_equal('pascal', &filetype)
  bwipe!
  unlet g:filetype_pp

  " Test dist#ft#FTpp()
  call writefile(['{ pascal comment'], 'Xfile.pp')
  split Xfile.pp
  call assert_equal('pascal', &filetype)
  bwipe!

  call writefile(['procedure pascal'], 'Xfile.pp')
  split Xfile.pp
  call assert_equal('pascal', &filetype)
  bwipe!

  filetype off
endfunc

" Test dist#ft#FTprg()
func Test_prg_file()
  filetype on

  " *.prg defaults to clipper
  call writefile(['looks like clipper'], 'prgfile.prg')
  split prgfile.prg
  call assert_equal('clipper', &filetype)
  bwipe!

  " Users preference set by g:filetype_prg
  let g:filetype_prg = 'eviews'
  split prgfile.prg
  call assert_equal('eviews', &filetype)
  unlet g:filetype_prg
  bwipe!

  " RAPID header start with a line containing only "%%%",
  " but is not always present.
  call writefile(['%%%'], 'prgfile.prg')
  split prgfile.prg
  call assert_equal('rapid', &filetype)
  bwipe!
  call delete('prgfile.prg')

  " RAPID supports umlauts in module names, leading spaces,
  " the .prg extension is not case sensitive.
  call writefile(['  module ÜmlautModule'], 'prgfile.Prg')
  split prgfile.Prg
  call assert_equal('rapid', &filetype)
  bwipe!
  call delete('prgfile.Prg')

  " RAPID is not case sensitive, embedded spaces, sysmodule,
  " file starts with empty line(s).
  call writefile(['', 'MODULE  rapidmödüle  (SYSMODULE,NOSTEPIN)'], 'prgfile.PRG')
  split prgfile.PRG
  call assert_equal('rapid', &filetype)
  bwipe!
  call delete('prgfile.PRG')

  filetype off
endfunc

" Test dist#ft#FTsc()
func Test_sc_file()
  filetype on

  " SC classes are defined with '+ Class {}'
  call writefile(['+ SCNvim {', '*methodArgs {|method|'], 'srcfile.sc')
  split srcfile.sc
  call assert_equal('supercollider', &filetype)
  bwipe!
  call delete('srcfile.sc')

  " Some SC class files start with comment and define methods many lines later
  call writefile(['// Query', '//Method','^this {'], 'srcfile.sc')
  split srcfile.sc
  call assert_equal('supercollider', &filetype)
  bwipe!
  call delete('srcfile.sc')

  " Some SC class files put comments between method declaration after class
  call writefile(['PingPong {', '//comment','*ar { arg'], 'srcfile.sc')
  split srcfile.sc
  call assert_equal('supercollider', &filetype)
  bwipe!
  call delete('srcfile.sc')

  filetype off
endfunc

" Test dist#ft#FTscd()
func Test_scd_file()
  filetype on

  call writefile(['ijq(1)'], 'srcfile.scd', 'D')
  split srcfile.scd
  call assert_equal('scdoc', &filetype)

  bwipe!
  filetype off
endfunc

func Test_src_file()
  filetype on

  " KRL header start with "&WORD", but is not always present.
  call writefile(['&ACCESS'], 'srcfile.src')
  split srcfile.src
  call assert_equal('krl', &filetype)
  bwipe!
  call delete('srcfile.src')

  " KRL def with leading spaces, for KRL file extension is not case sensitive.
  call writefile(['  DEF srcfile()'], 'srcfile.Src')
  split srcfile.Src
  call assert_equal('krl', &filetype)
  bwipe!
  call delete('srcfile.Src')

  " KRL global deffct with embedded spaces, file starts with empty line(s).
  for text in ['global  def  srcfile()', 'global  deffct  srcfile()']
    call writefile(['', text], 'srcfile.SRC')
    split srcfile.SRC
    call assert_equal('krl', &filetype, text)
    bwipe!
  endfor

  " User may overrule file inspection
  let g:filetype_src = 'src'
  split srcfile.SRC
  call assert_equal('src', &filetype)
  bwipe!
  call delete('srcfile.SRC')
  unlet g:filetype_src

  filetype off
endfunc

func Test_sys_file()
  filetype on

  " *.sys defaults to Batch file for MSDOS
  call writefile(['looks like dos batch'], 'sysfile.sys')
  split sysfile.sys
  call assert_equal('bat', &filetype)
  bwipe!

  " Users preference set by g:filetype_sys
  let g:filetype_sys = 'sys'
  split sysfile.sys
  call assert_equal('sys', &filetype)
  unlet g:filetype_sys
  bwipe!

  " RAPID header start with a line containing only "%%%",
  " but is not always present.
  call writefile(['%%%'], 'sysfile.sys')
  split sysfile.sys
  call assert_equal('rapid', &filetype)
  bwipe!
  call delete('sysfile.sys')

  " RAPID supports umlauts in module names, leading spaces,
  " the .sys extension is not case sensitive.
  call writefile(['  module ÜmlautModule'], 'sysfile.Sys')
  split sysfile.Sys
  call assert_equal('rapid', &filetype)
  bwipe!
  call delete('sysfile.Sys')

  " RAPID is not case sensitive, embedded spaces, sysmodule,
  " file starts with empty line(s).
  call writefile(['', 'MODULE  rapidmödüle  (SYSMODULE,NOSTEPIN)'], 'sysfile.SYS')
  split sysfile.SYS
  call assert_equal('rapid', &filetype)
  bwipe!
  call delete('sysfile.SYS')

  filetype off
endfunc

func Test_tex_file()
  filetype on

  call writefile(['%& pdflatex'], 'Xfile.tex')
  split Xfile.tex
  call assert_equal('tex', &filetype)
  bwipe

  call writefile(['\newcommand{\test}{some text}'], 'Xfile.tex')
  split Xfile.tex
  call assert_equal('tex', &filetype)
  bwipe

  " tex_flavor is unset
  call writefile(['%& plain'], 'Xfile.tex')
  split Xfile.tex
  call assert_equal('plaintex', &filetype)
  bwipe

  let g:tex_flavor = 'plain'
  call writefile(['just some text'], 'Xfile.tex')
  split Xfile.tex
  call assert_equal('plaintex', &filetype)
  bwipe

  let lines =<< trim END
      % This is a comment.

      \usemodule[translate]
  END
  call writefile(lines, 'Xfile.tex')
  split Xfile.tex
  call assert_equal('context', &filetype)
  bwipe

  let g:tex_flavor = 'context'
  call writefile(['just some text'], 'Xfile.tex')
  split Xfile.tex
  call assert_equal('context', &filetype)
  bwipe
  unlet g:tex_flavor

  call delete('Xfile.tex')
  filetype off
endfunc

func Test_tf_file()
  filetype on

  call writefile([';;; TF MUD client is super duper cool'], 'Xfile.tf', 'D')
  split Xfile.tf
  call assert_equal('tf', &filetype)
  bwipe!

  call writefile(['provider "azurerm" {'], 'Xfile.tf')
  split Xfile.tf
  call assert_equal('terraform', &filetype)
  bwipe!

  filetype off
endfunc

func Test_ts_file()
  filetype on

  call writefile(['<?xml version="1.0" encoding="utf-8"?>'], 'Xfile.ts', 'D')
  split Xfile.ts
  call assert_equal('xml', &filetype)
  bwipe!

  call writefile(['// looks like Typescript'], 'Xfile.ts')
  split Xfile.ts
  call assert_equal('typescript', &filetype)
  bwipe!

  filetype off
endfunc

func Test_ttl_file()
  filetype on

  call writefile(['@base <http://example.org/> .'], 'Xfile.ttl', 'D')
  split Xfile.ttl
  call assert_equal('turtle', &filetype)
  bwipe!

  call writefile(['looks like Tera Term Language'], 'Xfile.ttl')
  split Xfile.ttl
  call assert_equal('teraterm', &filetype)
  bwipe!

  filetype off
endfunc

func Test_v_file()
  filetype on

  call writefile(['module tb; // Looks like a Verilog'], 'Xfile.v', 'D')
  split Xfile.v
  call assert_equal('verilog', &filetype)
  bwipe!

  call writefile(['module main'], 'Xfile.v')
  split Xfile.v
  call assert_equal('v', &filetype)
  bwipe!

  call writefile(['Definition x := 10.  (*'], 'Xfile.v')
  split Xfile.v
  call assert_equal('coq', &filetype)
  bwipe!

  filetype off
endfunc

func Test_xpm_file()
  filetype on

  call writefile(['this is XPM2'], 'file.xpm', 'D')
  split file.xpm
  call assert_equal('xpm2', &filetype)
  bwipe!

  filetype off
endfunc

func Test_cls_file()
  filetype on

  call writefile(['looks like Smalltalk'], 'Xfile.cls', 'D')
  split Xfile.cls
  call assert_equal('st', &filetype)
  bwipe!

  " Test dist#ft#FTcls()

  let g:filetype_cls = 'vb'
  split Xfile.cls
  call assert_equal('vb', &filetype)
  bwipe!
  unlet g:filetype_cls

  " TeX

  call writefile(['%'], 'Xfile.cls')
  split Xfile.cls
  call assert_equal('tex', &filetype)
  bwipe!

  call writefile(['\NeedsTeXFormat{LaTeX2e}'], 'Xfile.cls')
  split Xfile.cls
  call assert_equal('tex', &filetype)
  bwipe!

  " Rexx

  call writefile(['#!/usr/bin/rexx'], 'Xfile.cls')
  split Xfile.cls
  call assert_equal('rexx', &filetype)
  bwipe!

  call writefile(['#!/usr/bin/regina'], 'Xfile.cls')
  split Xfile.cls
  call assert_equal('rexx', &filetype)
  bwipe!

  call writefile(['/* Comment */'], 'Xfile.cls')
  split Xfile.cls
  call assert_equal('rexx', &filetype)
  bwipe!

  call writefile(['::class Foo subclass Bar public'], 'Xfile.cls')
  split Xfile.cls
  call assert_equal('rexx', &filetype)
  bwipe!

  " Visual Basic

  call writefile(['VERSION 1.0 CLASS'], 'Xfile.cls')
  split Xfile.cls
  call assert_equal('vb', &filetype)
  bwipe!

  filetype off
endfunc

func Test_sig_file()
  filetype on

  call writefile(['this is neither Lambda Prolog nor SML'], 'Xfile.sig', 'D')
  split Xfile.sig
  call assert_equal('', &filetype)
  bwipe!

  " Test dist#ft#FTsig()

  let g:filetype_sig = 'sml'
  split Xfile.sig
  call assert_equal('sml', &filetype)
  bwipe!
  unlet g:filetype_sig

  " Lambda Prolog

  call writefile(['sig foo.'], 'Xfile.sig')
  split Xfile.sig
  call assert_equal('lprolog', &filetype)
  bwipe!

  call writefile(['/* ... */'], 'Xfile.sig')
  split Xfile.sig
  call assert_equal('lprolog', &filetype)
  bwipe!

  call writefile(['% ...'], 'Xfile.sig')
  split Xfile.sig
  call assert_equal('lprolog', &filetype)
  bwipe!

  " SML signature file

  call writefile(['signature FOO ='], 'Xfile.sig')
  split Xfile.sig
  call assert_equal('sml', &filetype)
  bwipe!

  call writefile(['structure FOO ='], 'Xfile.sig')
  split Xfile.sig
  call assert_equal('sml', &filetype)
  bwipe!

  call writefile(['(* ... *)'], 'Xfile.sig')
  split Xfile.sig
  call assert_equal('sml', &filetype)
  bwipe!

  filetype off
endfunc

" Test dist#ft#FTsil()
func Test_sil_file()
  filetype on

  split Xfile.sil
  call assert_equal('sil', &filetype)
  bwipe!

  let lines =<< trim END
  // valid
  let protoErasedPathA = \ABCProtocol.a

  // also valid
  let protoErasedPathA =
          \ABCProtocol.a
  END
  call writefile(lines, 'Xfile.sil', 'D')

  split Xfile.sil
  call assert_equal('sil', &filetype)
  bwipe!

  " SILE

  call writefile(['% some comment'], 'Xfile.sil')
  split Xfile.sil
  call assert_equal('sile', &filetype)
  bwipe!

  call writefile(['\begin[papersize=a6]{document}foo\end{document}'], 'Xfile.sil')
  split Xfile.sil
  call assert_equal('sile', &filetype)
  bwipe!

  filetype off
endfunc

func Test_inc_file()
  filetype on

  call writefile(['this is the fallback'], 'Xfile.inc', 'D')
  split Xfile.inc
  call assert_equal('pov', &filetype)
  bwipe!

  let g:filetype_inc = 'foo'
  split Xfile.inc
  call assert_equal('foo', &filetype)
  bwipe!
  unlet g:filetype_inc

  " aspperl
  call writefile(['perlscript'], 'Xfile.inc')
  split Xfile.inc
  call assert_equal('aspperl', &filetype)
  bwipe!

  " aspvbs
  call writefile(['<% something'], 'Xfile.inc')
  split Xfile.inc
  call assert_equal('aspvbs', &filetype)
  bwipe!

  " php
  call writefile(['<?php'], 'Xfile.inc')
  split Xfile.inc
  call assert_equal('php', &filetype)
  bwipe!

  " pascal
  call writefile(['program'], 'Xfile.inc')
  split Xfile.inc
  call assert_equal('pascal', &filetype)
  bwipe!

  " bitbake
  call writefile(['require foo'], 'Xfile.inc')
  split Xfile.inc
  call assert_equal('bitbake', &filetype)
  bwipe!

  call writefile(['S = "${WORKDIR}"'], 'Xfile.inc')
  split Xfile.inc
  call assert_equal('bitbake', &filetype)
  bwipe!

  call writefile(['DEPENDS:append = " somedep"'], 'Xfile.inc')
  split Xfile.inc
  call assert_equal('bitbake', &filetype)
  bwipe!

  call writefile(['MACHINE ??= "qemu"'], 'Xfile.inc')
  split Xfile.inc
  call assert_equal('bitbake', &filetype)
  bwipe!

  call writefile(['PROVIDES := "test"'], 'Xfile.inc')
  split Xfile.inc
  call assert_equal('bitbake', &filetype)
  bwipe!

  call writefile(['RDEPENDS_${PN} += "bar"'], 'Xfile.inc')
  split Xfile.inc
  call assert_equal('bitbake', &filetype)
  bwipe!

  " asm
  call writefile(['asmsyntax=foo'], 'Xfile.inc')
  split Xfile.inc
  call assert_equal('foo', &filetype)
  bwipe!

  filetype off
endfunc

func Test_lsl_file()
  filetype on

  call writefile(['looks like Linden Scripting Language'], 'Xfile.lsl', 'D')
  split Xfile.lsl
  call assert_equal('lsl', &filetype)
  bwipe!

  " Test dist#ft#FTlsl()

  let g:filetype_lsl = 'larch'
  split Xfile.lsl
  call assert_equal('larch', &filetype)
  bwipe!
  unlet g:filetype_lsl

  " Larch Shared Language

  call writefile(['% larch comment'], 'Xfile.lsl')
  split Xfile.lsl
  call assert_equal('larch', &filetype)
  bwipe!

  call writefile(['foo: trait'], 'Xfile.lsl')
  split Xfile.lsl
  call assert_equal('larch', &filetype)
  bwipe!

  filetype off
endfunc

func Test_typ_file()
  filetype on

  " SQL type file

  call writefile(['CASE = LOWER'], 'Xfile.typ', 'D')
  split Xfile.typ
  call assert_equal('sql', &filetype)
  bwipe!

  call writefile(['TYPE foo'], 'Xfile.typ')
  split Xfile.typ
  call assert_equal('sql', &filetype)
  bwipe!

  " typst document

  call writefile(['this is a fallback'], 'Xfile.typ')
  split Xfile.typ
  call assert_equal('typst', &filetype)
  bwipe!

  let g:filetype_typ = 'typst'
  split test.typ
  call assert_equal('typst', &filetype)
  bwipe!
  unlet g:filetype_typ

  filetype off
endfunc

func Test_dsp_file()
  filetype on

  " Microsoft Developer Studio Project file

  call writefile(['# Microsoft Developer Studio Project File'], 'Xfile.dsp', 'D')
  split Xfile.dsp
  call assert_equal('make', &filetype)
  bwipe!

  let g:filetype_dsp = 'make'
  split test.dsp
  call assert_equal('make', &filetype)
  bwipe!
  unlet g:filetype_dsp

  " Faust

  call writefile(['this is a fallback'], 'Xfile.dsp')
  split Xfile.dsp
  call assert_equal('faust', &filetype)
  bwipe!

  filetype off
endfunc

func Test_vba_file()
  filetype on

  " Test dist#ft#FTvba()

  " Visual Basic

  call writefile(['looks like Visual Basic'], 'Xfile.vba', 'D')
  split Xfile.vba
  call assert_equal('vb', &filetype)
  bwipe!

  " Vimball Archiver (ft=vim)

  call writefile(['" Vimball Archiver by Charles E. Campbell, Ph.D.', 'UseVimball', 'finish'], 'Xfile.vba', 'D')
  split Xfile.vba
  call assert_equal('vim', &filetype)
  bwipe!

  filetype off
endfunc

func Test_i_file()
  filetype on

  " Swig: keyword
  call writefile(['%module mymodule', '/* a comment */'], 'Xfile.i', 'D')
  split Xfile.i
  call assert_equal('swig', &filetype)
  bwipe!

  " Swig: verbatim block
  call writefile(['%{', '#include <header.hpp>', '%}'], 'Xfile.i', 'D')
  split Xfile.i
  call assert_equal('swig', &filetype)
  bwipe!

  " ASM
  call writefile(['; comment', ';'], 'Xfile.i', 'D')
  split Xfile.i
  call assert_equal('asm', &filetype)
  bwipe!

  " *.i defaults to progress
  call writefile(['looks like progress'], 'Xfile.i', 'D')
  split Xfile.i
  call assert_equal('progress', &filetype)
  bwipe!

  filetype off
endfunc

func Test_def_file()
  filetype on

  call writefile(['this is the fallback'], 'Xfile.def', 'D')
  split Xfile.def
  call assert_equal('def', &filetype)
  bwipe!

  " Test dist#ft#FTdef()

  let g:filetype_def = 'modula2'
  split Xfile.def
  call assert_equal('modula2', &filetype)
  call assert_equal('pim', b:modula2.dialect)
  bwipe!
  unlet g:filetype_def

  " Modula-2

  call writefile(['(* a Modula-2 comment *)'], 'Xfile.def')
  split Xfile.def
  call assert_equal('modula2', &filetype)
  call assert_equal('pim', b:modula2.dialect)
  bwipe!

  call writefile(['IMPLEMENTATION MODULE Module2Mod;'], 'Xfile.def')
  split Xfile.def
  call assert_equal('modula2', &filetype)
  call assert_equal('pim', b:modula2.dialect)
  bwipe!

  filetype off
endfunc

func Test_uci_file()
  filetype on

  call mkdir('any/etc/config', 'pR')
  call writefile(['config firewall'], 'any/etc/config/firewall', 'D')
  split any/etc/config/firewall
  call assert_equal('uci', &filetype)
  bwipe!

  call writefile(['# config for nginx here'], 'any/etc/config/firewall', 'D')
  split any/etc/config/firewall
  call assert_notequal('uci', &filetype)
  bwipe!

  call writefile(['# Copyright Cool Cats 1997', 'config firewall'], 'any/etc/config/firewall', 'D')
  split any/etc/config/firewall
  call assert_equal('uci', &filetype)
  bwipe!

  filetype off
endfunc

func Test_pro_file()
  filetype on

  "Prolog
  call writefile([':-module(test/1,'], 'Xfile.pro', 'D')
  split Xfile.pro
  call assert_equal('prolog', &filetype)
  bwipe!

  call writefile(['% comment'], 'Xfile.pro', 'D')
  split Xfile.pro
  call assert_equal('prolog', &filetype)
  bwipe!

  call writefile(['/* multiline comment'], 'Xfile.pro', 'D')
  split Xfile.pro
  call assert_equal('prolog', &filetype)
  bwipe!

  call writefile(['rule(test, 1.7).'], 'Xfile.pro', 'D')
  split Xfile.pro
  call assert_equal('prolog', &filetype)
  bwipe!

  " IDL
  call writefile(['x = findgen(100)/10'], 'Xfile.pro', 'D')
  split Xfile.pro
  call assert_equal('idlang', &filetype)

  filetype off
endfunc


func Test_pl_file()
  filetype on

  "Prolog
  call writefile([':-module(test/1,'], 'Xfile.pl', 'D')
  split Xfile.pl
  call assert_equal('prolog', &filetype)
  bwipe!

  call writefile(['% comment'], 'Xfile.pl', 'D')
  split Xfile.pl
  call assert_equal('prolog', &filetype)
  bwipe!

  call writefile(['/* multiline comment'], 'Xfile.pl', 'D')
  split Xfile.pl
  call assert_equal('prolog', &filetype)
  bwipe!

  call writefile(['rule(test, 1.7).'], 'Xfile.pl', 'D')
  split Xfile.pl
  call assert_equal('prolog', &filetype)
  bwipe!

  " Perl
  call writefile(['%data = (1, 2, 3);'], 'Xfile.pl', 'D')
  split Xfile.pl
  call assert_equal('perl', &filetype)

  filetype off
endfunc

" vim: shiftwidth=2 sts=2 expandtab
