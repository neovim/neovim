" Vim syntax file
" Language:    Debian control files
" Maintainer:  Debian Vim Maintainers
" Former Maintainers: Gerfried Fuchs <alfie@ist.org>
"                     Wichert Akkerman <wakkerma@debian.org>
" Last Change: 2023 Jan 16
" URL: https://salsa.debian.org/vim-team/vim-debian/blob/main/syntax/debcontrol.vim

" Standard syntax initialization
if exists('b:current_syntax')
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Should match case except for the keys of each field
syn case match

syn iskeyword @,48-57,-

" Everything that is not explicitly matched by the rules below
syn match debcontrolElse "^.*$"

" Common separators
syn match debControlComma ",[ \t]*"
syn match debControlSpace "[ \t]"

let s:kernels = ['linux', 'hurd', 'kfreebsd', 'knetbsd', 'kopensolaris', 'netbsd']
let s:archs = [
      \ 'alpha', 'amd64', 'armeb', 'armel', 'armhf', 'arm64', 'avr32', 'hppa'
      \, 'i386', 'ia64', 'lpia', 'm32r', 'm68k', 'mipsel', 'mips64el', 'mips'
      \, 'powerpcspe', 'powerpc', 'ppc64el', 'ppc64', 'riscv64', 's390x', 's390', 'sh3eb'
      \, 'sh3', 'sh4eb', 'sh4', 'sh', 'sparc64', 'sparc', 'x32'
      \ ]
let s:pairs = [
      \ 'hurd-i386', 'kfreebsd-i386', 'kfreebsd-amd64', 'knetbsd-i386'
      \, 'kopensolaris-i386', 'netbsd-alpha', 'netbsd-i386'
      \ ]

" Define some common expressions we can use later on
syn keyword debcontrolArchitecture contained all any
exe 'syn keyword debcontrolArchitecture contained '. join(map(copy(s:kernels), {k,v -> v .'-any'}))
exe 'syn keyword debcontrolArchitecture contained '. join(map(copy(s:archs), {k,v -> 'any-'.v}))
exe 'syn keyword debcontrolArchitecture contained '. join(s:archs)
exe 'syn keyword debcontrolArchitecture contained '. join(s:pairs)

unlet s:kernels s:archs s:pairs

" Keep in sync with https://metadata.ftp-master.org/sections.822
" curl -q https://metadata.ftp-master.debian.org/sections.822 2>/dev/null| grep-dctrl -n --not -FSection -sSection  / -
let s:sections = [
      \ 'admin', 'cli-mono', 'comm', 'database', 'debian-installer', 'debug'
      \, 'devel', 'doc', 'editors', 'education', 'electronics', 'embedded'
      \, 'fonts', 'games', 'gnome', 'gnu-r', 'gnustep', 'golang', 'graphics'
      \, 'hamradio', 'haskell', 'httpd', 'interpreters', 'introspection'
      \, 'java', 'javascript', 'kde', 'kernel', 'libdevel', 'libs', 'lisp'
      \, 'localization', 'mail', 'math', 'metapackages', 'misc', 'net', 'news'
      \, 'ocaml', 'oldlibs', 'otherosfs', 'perl', 'php', 'python', 'raku'
      \, 'ruby', 'rust', 'science', 'shells', 'sound', 'tasks', 'tex', 'text'
      \, 'utils', 'vcs', 'video', 'web', 'x11', 'xfce', 'zope'
      \ ]

syn keyword debcontrolMultiArch contained no foreign allowed same
syn match debcontrolName contained "[a-z0-9][a-z0-9+.-]\+"
syn keyword debcontrolPriority contained extra important optional required standard
exe 'syn match debcontrolSection contained "\%(\%(contrib\|non-free\|non-US/main\|non-US/contrib\|non-US/non-free\|restricted\|universe\|multiverse\)/\)\=\<\%('.join(s:sections, '\|').'\)\>"'
syn keyword debcontrolPackageType contained udeb deb
syn match debcontrolVariable contained "\${.\{-}}"
syn keyword debcontrolDmUpload contained yes
syn keyword debcontrolYesNo contained yes no
syn match debcontrolR3 contained "\<\%(no\|binary-targets\|[[:graph:]]\+/[[:graph:]]\+\%( \+[[:graph:]]\+/[[:graph:]]\+\)*\)\>"

unlet s:sections

" A URL (using the domain name definitions from RFC 1034 and 1738), right now
" only enforce protocol and some sanity on the server/path part;
syn match debcontrolHTTPUrl contained "\vhttps?://[[:alnum:]][-[:alnum:]]*[[:alnum:]]?(\.[[:alnum:]][-[:alnum:]]*[[:alnum:]]?)*\.[[:alpha:]][-[:alnum:]]*[[:alpha:]]?(:\d+)?(/[^[:space:]]*)?$"
syn match debcontrolVcsSvn contained "\vsvn%(\+ssh)?://[[:alnum:]][-[:alnum:]]*[[:alnum:]]?(\.[[:alnum:]][-[:alnum:]]*[[:alnum:]]?)*\.[[:alpha:]][-[:alnum:]]*[[:alpha:]]?(:\d+)?(/[^[:space:]]*)?$"
syn match debcontrolVcsCvs contained "\v%(\-d *)?:pserver:[^@]+\@[[:alnum:]][-[:alnum:]]*[[:alnum:]]?(\.[[:alnum:]][-[:alnum:]]*[[:alnum:]]?)*\.[[:alpha:]][-[:alnum:]]*[[:alpha:]]?:/[^[:space:]]*%( [^[:space:]]+)?$"
syn match debcontrolVcsGit contained "\v%(git|https?)://[[:alnum:]][-[:alnum:]]*[[:alnum:]]?(\.[[:alnum:]][-[:alnum:]]*[[:alnum:]]?)*\.[[:alpha:]][-[:alnum:]]*[[:alpha:]]?(:\d+)?(/[^[:space:]]*)?%(\s+-b\s+[^ ~^:?*[\\]+)?$"

" An email address
syn match	debcontrolEmail	"[_=[:alnum:]\.+-]\+@[[:alnum:]\./\-]\+"
syn match	debcontrolEmail	"<.\{-}>"

" #-Comments
syn match debcontrolComment "^#.*$" contains=@Spell

syn case ignore

" Handle all fields from deb-src-control(5)

" Catch-all for the legal fields
syn region debcontrolField matchgroup=debcontrolKey start="^\%(\%(XSBC-Original-\)\=Maintainer\|Standards-Version\|Bugs\|Origin\|X[SB]-Python-Version\|\%(XS-\)\=Vcs-Mtn\|\%(XS-\)\=Testsuite\%(-Triggers\)\=\|Build-Profiles\|Tag\|Subarchitecture\|Kernel-Version\|Installer-Menu-Item\): " end="$" contains=debcontrolVariable,debcontrolEmail oneline
syn region debcontrolMultiField matchgroup=debcontrolKey start="^\%(Build-\%(Conflicts\|Depends\)\%(-Arch\|-Indep\)\=\|\%(Pre-\)\=Depends\|Recommends\|Suggests\|Breaks\|Enhances\|Replaces\|Conflicts\|Provides\|Built-Using\|Uploaders\|X[SBC]\{0,3\}\%(Private-\)\=-[-a-zA-Z0-9]\+\): *" skip="^[ \t]" end="^$"me=s-1 end="^[^ \t#]"me=s-1 contains=debcontrolEmail,debcontrolVariable,debcontrolComment
syn region debcontrolMultiFieldSpell matchgroup=debcontrolKey start="^Description: *" skip="^[ \t]" end="^$"me=s-1 end="^[^ \t#]"me=s-1 contains=debcontrolEmail,debcontrolVariable,debcontrolComment,@Spell

" Fields for which we do strict syntax checking
syn region debcontrolStrictField matchgroup=debcontrolKey start="^Architecture: *" end="$" contains=debcontrolArchitecture,debcontrolSpace oneline
syn region debcontrolStrictField matchgroup=debcontrolKey start="^Multi-Arch: *" end="$" contains=debcontrolMultiArch oneline
syn region debcontrolStrictField matchgroup=debcontrolKey start="^\%(Package\|Source\): *" end="$" contains=debcontrolName oneline
syn region debcontrolStrictField matchgroup=debcontrolKey start="^Priority: *" end="$" contains=debcontrolPriority oneline
syn region debcontrolStrictField matchgroup=debcontrolKey start="^Section: *" end="$" contains=debcontrolSection oneline
syn region debcontrolStrictField matchgroup=debcontrolKey start="^\%(XC-\)\=Package-Type: *" end="$" contains=debcontrolPackageType oneline
syn region debcontrolStrictField matchgroup=debcontrolKey start="^Homepage: *" end="$" contains=debcontrolHTTPUrl oneline keepend
syn region debcontrolStrictField matchgroup=debcontrolKey start="^\%(XS-[-a-zA-Z0-9]\+-\)\=Vcs-\%(Browser\|Arch\|Bzr\|Darcs\|Hg\): *" end="$" contains=debcontrolHTTPUrl oneline keepend
syn region debcontrolStrictField matchgroup=debcontrolKey start="^\%(XS-[-a-zA-Z0-9]\+-\)\=Vcs-Svn: *" end="$" contains=debcontrolVcsSvn,debcontrolHTTPUrl oneline keepend
syn region debcontrolStrictField matchgroup=debcontrolKey start="^\%(XS-[-a-zA-Z0-9]\+-\)\=Vcs-Cvs: *" end="$" contains=debcontrolVcsCvs oneline keepend
syn region debcontrolStrictField matchgroup=debcontrolKey start="^\%(XS-[-a-zA-Z0-9]\+-\)\=Vcs-Git: *" end="$" contains=debcontrolVcsGit oneline keepend
syn region debcontrolStrictField matchgroup=debcontrolKey start="^Rules-Requires-Root: *" end="$" contains=debcontrolR3 oneline
syn region debcontrolStrictField matchgroup=debcontrolKey start="^\%(Build-\)\=Essential: *" end="$" contains=debcontrolYesNo oneline

syn region debcontrolStrictField matchgroup=debcontrolDeprecatedKey start="^\%(XS-\)\=DM-Upload-Allowed: *" end="$" contains=debcontrolDmUpload oneline

" Associate our matches and regions with pretty colours
hi def link debcontrolKey           Keyword
hi def link debcontrolField         Normal
hi def link debcontrolStrictField   Error
hi def link debcontrolDeprecatedKey Error
hi def link debcontrolMultiField    Normal
hi def link debcontrolArchitecture  Normal
hi def link debcontrolMultiArch     Normal
hi def link debcontrolName          Normal
hi def link debcontrolPriority      Normal
hi def link debcontrolSection       Normal
hi def link debcontrolPackageType   Normal
hi def link debcontrolVariable      Identifier
hi def link debcontrolEmail         Identifier
hi def link debcontrolVcsSvn        Identifier
hi def link debcontrolVcsCvs        Identifier
hi def link debcontrolVcsGit        Identifier
hi def link debcontrolHTTPUrl       Identifier
hi def link debcontrolDmUpload      Identifier
hi def link debcontrolYesNo         Identifier
hi def link debcontrolR3            Identifier
hi def link debcontrolComment       Comment
hi def link debcontrolElse          Special

let b:current_syntax = 'debcontrol'

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 sw=2
