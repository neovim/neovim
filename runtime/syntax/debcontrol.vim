" Vim syntax file
" Language:    Debian control files
" Maintainer:  Debian Vim Maintainers <pkg-vim-maintainers@lists.alioth.debian.org>
" Former Maintainers: Gerfried Fuchs <alfie@ist.org>
"                     Wichert Akkerman <wakkerma@debian.org>
" Last Change: 2017 Nov 04
" URL: https://anonscm.debian.org/cgit/pkg-vim/vim.git/plain/runtime/syntax/debcontrol.vim

" Standard syntax initialization
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Should match case except for the keys of each field
syn case match

syn iskeyword @,48-57,-,/

" Everything that is not explicitly matched by the rules below
syn match debcontrolElse "^.*$"

" Common seperators
syn match debControlComma ",[ \t]*"
syn match debControlSpace "[ \t]"

let s:kernels = ['linux', 'hurd', 'kfreebsd', 'knetbsd', 'kopensolaris', 'netbsd']
let s:archs = [
      \ 'alpha', 'amd64', 'armeb', 'armel', 'armhf', 'arm64', 'avr32', 'hppa'
      \, 'i386', 'ia64', 'lpia', 'm32r', 'm68k', 'mipsel', 'mips64el', 'mips'
      \, 'powerpcspe', 'powerpc', 'ppc64el', 'ppc64', 's390x', 's390', 'sh3eb'
      \, 'sh3', 'sh4eb', 'sh4', 'sh', 'sparc64', 'sparc', 'x32'
      \ ]
let s:pairs = [
      \ 'hurd-i386', 'kfreebsd-i386', 'kfreebsd-amd64', 'knetbsd-i386'
      \, 'kopensolaris-i386', 'netbsd-alpha', 'netbsd-i386'
      \ ]

" Define some common expressions we can use later on
syn keyword debcontrolArchitecture contained all any
exe 'syn keyword debcontrolArchitecture contained '. join(map(s:kernels, {k,v -> v .'-any'}))
exe 'syn keyword debcontrolArchitecture contained '. join(map(s:archs, {k,v -> 'any-'.v}))
exe 'syn keyword debcontrolArchitecture contained '. join(s:archs)
exe 'syn keyword debcontrolArchitecture contained '. join(s:pairs)

unlet s:kernels s:archs s:pairs

let s:sections = [
      \ 'admin', 'cli-mono', 'comm', 'database', 'debian-installer', 'debug'
      \, 'devel', 'doc', 'editors', 'education', 'electronics', 'embedded'
      \, 'fonts', 'games', 'gnome', 'gnustep', 'gnu-r', 'golang', 'graphics'
      \, 'hamradio', 'haskell', 'httpd', 'interpreters', 'introspection'
      \, 'java', 'javascript', 'kde', 'kernel', 'libs', 'libdevel', 'lisp'
      \, 'localization', 'mail', 'math', 'metapackages', 'misc', 'net'
      \, 'news', 'ocaml', 'oldlibs', 'otherosfs', 'perl', 'php', 'python'
      \, 'ruby', 'rust', 'science', 'shells', 'sound', 'text', 'tex'
      \, 'utils', 'vcs', 'video', 'web', 'x11', 'xfce', 'zope'
      \ ]

syn keyword debcontrolMultiArch contained no foreign allowed same
syn match debcontrolName contained "[a-z0-9][a-z0-9+.-]\+"
syn keyword debcontrolPriority contained extra important optional required standard
exe 'syn match debcontrolSection contained "\%(\%(contrib\|non-free\|non-US/main\|non-US/contrib\|non-US/non-free\|restricted\|universe\|multiverse\)/\)\=\%('.join(s:sections, '\|').'\)"'
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

" List of all legal keys, in order, from deb-src-control(5)
" Source fields
syn match debcontrolKey contained "^\%(Source\|Maintainer\|Uploaders\|Standards-Version\|Description\|Homepage\|Bugs\|Rules-Requires-Root\): *"
syn match debcontrolKey contained "^\%(XS-\)\=Vcs-\%(Arch\|Bzr\|Cvs\|Darcs\|Git\|Hg\|Mtn\|Svn\|Browser\): *"
syn match debcontrolKey contained "^\%(Origin\|Section\|Priority\): *"
syn match debcontrolKey contained "^Build-\%(Depends\|Conflicts\)\%(-Arch\|-Indep\)\=: *"

" Binary fields
syn match debcontrolKey contained "^\%(Package\%(-Type\)\=\|Architecture\|Build-Profiles\): *"
syn match debcontrolKey contained "^\%(\%(Build-\)\=Essential\|Multi-Arch\|Tag\): *"
syn match debcontrolKey contained "^\%(\%(Pre-\)\=Depends\|Recommends\|Suggests\|Breaks\|Enhances\|Replaces\|Conflicts\|Provides\|Built-Using\): *"
syn match debcontrolKey contained "^\%(Subarchitecture\|Kernel-Version\|Installer-Menu-Item\): *"

" User-defined fields
syn match debcontrolKey contained "^X[SBC]\{0,3\}\%(-Private\)\=-[-a-zA-Z0-9]\+: *"

syn match debcontrolDeprecatedKey contained "^\%(\%(XS-\)\=DM-Upload-Allowed\): *"

" Fields for which we do strict syntax checking
syn region debcontrolStrictField start="^Architecture" end="$" contains=debcontrolKey,debcontrolArchitecture,debcontrolSpace oneline
syn region debcontrolStrictField start="^Multi-Arch" end="$" contains=debcontrolKey,debcontrolMultiArch oneline
syn region debcontrolStrictField start="^\%(Package\|Source\)" end="$" contains=debcontrolKey,debcontrolName oneline
syn region debcontrolStrictField start="^Priority" end="$" contains=debcontrolKey,debcontrolPriority oneline
syn region debcontrolStrictField start="^Section" end="$" contains=debcontrolKey,debcontrolSection oneline
syn region debcontrolStrictField start="^\%(XC-\)\=Package-Type" end="$" contains=debcontrolKey,debcontrolPackageType oneline
syn region debcontrolStrictField start="^Homepage" end="$" contains=debcontrolKey,debcontrolHTTPUrl oneline keepend
syn region debcontrolStrictField start="^\%(XS-\)\=Vcs-\%(Browser\|Arch\|Bzr\|Darcs\|Hg\)" end="$" contains=debcontrolKey,debcontrolHTTPUrl oneline keepend
syn region debcontrolStrictField start="^\%(XS-\)\=Vcs-Svn" end="$" contains=debcontrolKey,debcontrolVcsSvn,debcontrolHTTPUrl oneline keepend
syn region debcontrolStrictField start="^\%(XS-\)\=Vcs-Cvs" end="$" contains=debcontrolKey,debcontrolVcsCvs oneline keepend
syn region debcontrolStrictField start="^\%(XS-\)\=Vcs-Git" end="$" contains=debcontrolKey,debcontrolVcsGit oneline keepend
syn region debcontrolStrictField start="^\%(XS-\)\=DM-Upload-Allowed" end="$" contains=debcontrolDeprecatedKey,debcontrolDmUpload oneline
syn region debcontrolStrictField start="^Rules-Requires-Root" end="$" contains=debcontrolKey,debcontrolR3 oneline
syn region debcontrolStrictField start="^\%(Build-\)\=Essential" end="$" contains=debcontrolKey,debcontrolYesNo oneline

" Catch-all for the other legal fields
syn region debcontrolField start="^\%(\%(XSBC-Original-\)\=Maintainer\|Standards-Version\|Bugs\|Origin\|X[SB]-Python-Version\|\%(XS-\)\=Vcs-Mtn\|\%(XS-\)\=Testsuite\|Build-Profiles\|Tag\|Subarchitecture\|Kernel-Version\|Installer-Menu-Item\):" end="$" contains=debcontrolKey,debcontrolVariable,debcontrolEmail oneline
syn region debcontrolMultiField start="^\%(Build-\%(Conflicts\|Depends\)\%(-Arch\|-Indep\)\=\|\%(Pre-\)\=Depends\|Recommends\|Suggests\|Breaks\|Enhances\|Replaces\|Conflicts\|Provides\|Built-Using\|Uploaders\|X[SBC]\{0,3\}\%(Private-\)\=-[-a-zA-Z0-9]\+\):" skip="^[ \t]" end="^$"me=s-1 end="^[^ \t#]"me=s-1 contains=debcontrolKey,debcontrolEmail,debcontrolVariable,debcontrolComment
syn region debcontrolMultiFieldSpell start="^\%(Description\):" skip="^[ \t]" end="^$"me=s-1 end="^[^ \t#]"me=s-1 contains=debcontrolKey,debcontrolEmail,debcontrolVariable,debcontrolComment,@Spell

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

let b:current_syntax = "debcontrol"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 sw=2
