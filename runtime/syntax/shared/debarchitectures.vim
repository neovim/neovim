" Language:     Debian architecture information
" Maintainer:   Debian Vim Maintainers
" Last Change:  2025 Jul 05
" URL: https://salsa.debian.org/vim-team/vim-debian/blob/main/syntax/shared/debarchitectures.vim

let s:cpo = &cpo
set cpo-=C

let s:kernels = ['linux', 'hurd', 'kfreebsd', 'knetbsd', 'kopensolaris', 'netbsd']
let s:archs = [
      \ 'alpha', 'amd64', 'armeb', 'armel', 'armhf', 'arm64', 'avr32', 'hppa'
      \, 'i386', 'ia64', 'loong64', 'lpia', 'm32r', 'm68k', 'mipsel', 'mips64el', 'mips'
      \, 'powerpcspe', 'powerpc', 'ppc64el', 'ppc64', 'riscv64', 's390x', 's390', 'sh3eb'
      \, 'sh3', 'sh4eb', 'sh4', 'sh', 'sparc64', 'sparc', 'x32'
      \ ]
let s:pairs = [
      \ 'hurd-i386', 'hurd-amd64', 'kfreebsd-i386', 'kfreebsd-amd64', 'knetbsd-i386'
      \, 'kopensolaris-i386', 'netbsd-alpha', 'netbsd-i386'
      \ ]

let g:debArchitectureKernelAnyArch = map(copy(s:kernels), {k,v -> v.'-any'})
let g:debArchitectureAnyKernelArch = map(copy(s:archs), {k,v -> 'any-'.v})
let g:debArchitectureArchs = s:archs + s:pairs

unlet s:kernels s:archs s:pairs

let &cpo=s:cpo
