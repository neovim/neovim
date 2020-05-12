" Vim syntax file
" Language: fstab file
" Maintainer: Radu Dineiu <radu.dineiu@gmail.com>
" URL: https://raw.github.com/rid9/vim-fstab/master/fstab.vim
" Last Change: 2019 Jun 06
" Version: 1.3
"
" Credits:
"   David Necas (Yeti) <yeti@physics.muni.cz>
"   Stefano Zacchiroli <zack@debian.org>
"   Georgi Georgiev <chutz@gg3.net>
"   James Vega <jamessan@debian.org>
"   Elias Probst <mail@eliasprobst.eu>

" Options:
"   let fstab_unknown_fs_errors = 1
"     highlight unknown filesystems as errors
"
"   let fstab_unknown_device_errors = 0
"     do not highlight unknown devices as errors

" quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

let s:cpo_save = &cpo
set cpo&vim

" General
syn cluster fsGeneralCluster contains=fsComment
syn match fsComment /\s*#.*/ contains=@Spell
syn match fsOperator /[,=:#]/

" Device
syn cluster fsDeviceCluster contains=fsOperator,fsDeviceKeyword,fsDeviceError
syn match fsDeviceError /\%([^a-zA-Z0-9_\/#@:\.-]\|^\w\{-}\ze\W\)/ contained
syn keyword fsDeviceKeyword contained none proc linproc tmpfs devpts devtmpfs sysfs usbfs
syn keyword fsDeviceKeyword contained LABEL nextgroup=fsDeviceLabel
syn keyword fsDeviceKeyword contained UUID nextgroup=fsDeviceUUID
syn keyword fsDeviceKeyword contained PARTLABEL nextgroup=fsDevicePARTLABEL
syn keyword fsDeviceKeyword contained PARTUUID nextgroup=fsDevicePARTUUID
syn keyword fsDeviceKeyword contained sshfs nextgroup=fsDeviceSshfs
syn match fsDeviceKeyword contained /^[a-zA-Z0-9.\-]\+\ze:/
syn match fsDeviceLabel contained /=[^ \t]\+/hs=s+1 contains=fsOperator
syn match fsDeviceUUID contained /=[^ \t]\+/hs=s+1 contains=fsOperator
syn match fsDevicePARTLABEL contained /=[^ \t]\+/hs=s+1 contains=fsOperator
syn match fsDevicePARTUUID contained /=[^ \t]\+/hs=s+1 contains=fsOperator
syn match fsDeviceSshfs contained /#[_=[:alnum:]\.\/+-]\+@[a-z0-9._-]\+\a\{2}:[^ \t]\+/hs=s+1 contains=fsOperator

" Mount Point
syn cluster fsMountPointCluster contains=fsMountPointKeyword,fsMountPointError
syn match fsMountPointError /\%([^ \ta-zA-Z0-9_\/#@\.-]\|\s\+\zs\w\{-}\ze\s\)/ contained
syn keyword fsMountPointKeyword contained none swap

" Type
syn cluster fsTypeCluster contains=fsTypeKeyword,fsTypeUnknown
syn match fsTypeUnknown /\s\+\zs\w\+/ contained
syn keyword fsTypeKeyword contained adfs ados affs anon_inodefs atfs audiofs auto autofs bdev befs bfs btrfs binfmt_misc cd9660 cfs cgroup cifs coda configfs cpuset cramfs devfs devpts devtmpfs e2compr efs ext2 ext2fs ext3 ext4 fdesc ffs filecore fuse fuseblk fusectl hfs hpfs hugetlbfs iso9660 jffs jffs2 jfs kernfs lfs linprocfs mfs minix mqueue msdos ncpfs nfs nfsd nilfs2 none ntfs null nwfs overlay ovlfs pipefs portal proc procfs pstore ptyfs qnx4 reiserfs ramfs romfs securityfs shm smbfs squashfs sockfs sshfs std subfs swap sysfs sysv tcfs tmpfs udf ufs umap umsdos union usbfs userfs vfat vs3fs vxfs wrapfs wvfs xenfs xfs zisofs

" Options
" -------
" Options: General
syn cluster fsOptionsCluster contains=fsOperator,fsOptionsGeneral,fsOptionsKeywords,fsTypeUnknown
syn match fsOptionsNumber /\d\+/
syn match fsOptionsNumberOctal /[0-8]\+/
syn match fsOptionsString /[a-zA-Z0-9_-]\+/
syn keyword fsOptionsYesNo yes no
syn cluster fsOptionsCheckCluster contains=fsOptionsExt2Check,fsOptionsFatCheck
syn keyword fsOptionsSize 512 1024 2048
syn keyword fsOptionsGeneral async atime auto bind current defaults dev devgid devmode devmtime devuid dirsync exec force fstab kudzu loop mand move noatime noauto noclusterr noclusterw nodev nodevmtime nodiratime noexec nomand norelatime nosuid nosymfollow nouser owner rbind rdonly relatime remount ro rq rw suid suiddir supermount sw sync union update user users wxallowed xx nofail
syn match fsOptionsGeneral /_netdev/

" Options: adfs
syn match fsOptionsKeywords contained /\<\%([ug]id\|o\%(wn\|th\)mask\)=/ nextgroup=fsOptionsNumber

" Options: affs
syn match fsOptionsKeywords contained /\<\%(set[ug]id\|mode\|reserved\)=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<\%(prefix\|volume\|root\)=/ nextgroup=fsOptionsString
syn match fsOptionsKeywords contained /\<bs=/ nextgroup=fsOptionsSize
syn keyword fsOptionsKeywords contained protect usemp verbose

" Options: btrfs
syn match fsOptionsKeywords contained /\<\%(subvol\|subvolid\|subvolrootid\|device\|compress\|compress-force\|fatal_errors\)=/ nextgroup=fsOptionsString
syn match fsOptionsKeywords contained /\<\%(max_inline\|alloc_start\|thread_pool\|metadata_ratio\|check_int_print_mask\)=/ nextgroup=fsOptionsNumber
syn keyword fsOptionsKeywords contained degraded nodatasum nodatacow nobarrier ssd ssd_spread noacl notreelog flushoncommit space_cache nospace_cache clear_cache user_subvol_rm_allowed autodefrag inode_cache enospc_debug recovery check_int check_int_data skip_balance discard

" Options: cd9660
syn keyword fsOptionsKeywords contained extatt gens norrip nostrictjoilet

" Options: devpts
" -- everything already defined

" Options: ext2
syn match fsOptionsKeywords contained /\<check=*/ nextgroup=@fsOptionsCheckCluster
syn match fsOptionsKeywords contained /\<errors=/ nextgroup=fsOptionsExt2Errors
syn match fsOptionsKeywords contained /\<\%(res[gu]id\|sb\)=/ nextgroup=fsOptionsNumber
syn keyword fsOptionsExt2Check contained none normal strict
syn keyword fsOptionsExt2Errors contained continue panic
syn match fsOptionsExt2Errors contained /\<remount-ro\>/
syn keyword fsOptionsKeywords contained acl bsddf minixdf debug grpid bsdgroups minixdf nocheck nogrpid oldalloc orlov sysvgroups nouid32 nobh user_xattr nouser_xattr

" Options: ext3
syn match fsOptionsKeywords contained /\<journal=/ nextgroup=fsOptionsExt3Journal
syn match fsOptionsKeywords contained /\<data=/ nextgroup=fsOptionsExt3Data
syn match fsOptionsKeywords contained /\<commit=/ nextgroup=fsOptionsNumber
syn keyword fsOptionsExt3Journal contained update inum
syn keyword fsOptionsExt3Data contained journal ordered writeback
syn keyword fsOptionsKeywords contained noload user_xattr nouser_xattr acl

" Options: ext4
syn match fsOptionsKeywords contained /\<journal=/ nextgroup=fsOptionsExt4Journal
syn match fsOptionsKeywords contained /\<data=/ nextgroup=fsOptionsExt4Data
syn match fsOptionsKeywords contained /\<barrier=/ nextgroup=fsOptionsExt4Barrier
syn match fsOptionsKeywords contained /\<journal_dev=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<resuid=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<resgid=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<sb=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<commit=/ nextgroup=fsOptionsNumber
syn keyword fsOptionsExt4Journal contained update inum
syn keyword fsOptionsExt4Data contained journal ordered writeback
syn match fsOptionsExt4Barrier /[0-1]/
syn keyword fsOptionsKeywords contained noload extents orlov oldalloc user_xattr nouser_xattr acl noacl reservation noreservation bsddf minixdf check=none nocheck debug grpid nogroupid sysvgroups bsdgroups quota noquota grpquota usrquota bh nobh

" Options: fat
syn match fsOptionsKeywords contained /\<blocksize=/ nextgroup=fsOptionsSize
syn match fsOptionsKeywords contained /\<\%([dfu]mask\|codepage\)=/ nextgroup=fsOptionsNumberOctal
syn match fsOptionsKeywords contained /\%(cvf_\%(format\|option\)\|iocharset\)=/ nextgroup=fsOptionsString
syn match fsOptionsKeywords contained /\<check=/ nextgroup=@fsOptionsCheckCluster
syn match fsOptionsKeywords contained /\<conv=*/ nextgroup=fsOptionsConv
syn match fsOptionsKeywords contained /\<fat=/ nextgroup=fsOptionsFatType
syn match fsOptionsKeywords contained /\<dotsOK=/ nextgroup=fsOptionsYesNo
syn keyword fsOptionsFatCheck contained r n s relaxed normal strict
syn keyword fsOptionsConv contained b t a binary text auto
syn keyword fsOptionsFatType contained 12 16 32
syn keyword fsOptionsKeywords contained quiet sys_immutable showexec dots nodots

" Options: hfs
syn match fsOptionsKeywords contained /\<\%(creator|type\)=/ nextgroup=fsOptionsString
syn match fsOptionsKeywords contained /\<\%(dir\|file\|\)_umask=/ nextgroup=fsOptionsNumberOctal
syn match fsOptionsKeywords contained /\<\%(session\|part\)=/ nextgroup=fsOptionsNumber

" Options: ffs
syn keyword fsOptionsKeyWords contained noperm softdep

" Options: hpfs
syn match fsOptionsKeywords contained /\<case=/ nextgroup=fsOptionsHpfsCase
syn keyword fsOptionsHpfsCase contained lower asis

" Options: iso9660
syn match fsOptionsKeywords contained /\<map=/ nextgroup=fsOptionsIsoMap
syn match fsOptionsKeywords contained /\<block=/ nextgroup=fsOptionsSize
syn match fsOptionsKeywords contained /\<\%(session\|sbsector\)=/ nextgroup=fsOptionsNumber
syn keyword fsOptionsIsoMap contained n o a normal off acorn
syn keyword fsOptionsKeywords contained norock nojoilet unhide cruft
syn keyword fsOptionsConv contained m mtext

" Options: jfs
syn keyword fsOptionsKeywords nointegrity integrity

" Options: nfs
syn match fsOptionsKeywords contained /\<\%(rsize\|wsize\|timeo\|retrans\|acregmin\|acregmax\|acdirmin\|acdirmax\|actimeo\|retry\|port\|mountport\|mounthost\|mountprog\|mountvers\|nfsprog\|nfsvers\|namelen\)=/ nextgroup=fsOptionsString
syn keyword fsOptionsKeywords contained bg fg soft hard intr cto ac tcp udp lock nobg nofg nosoft nohard nointr noposix nocto noac notcp noudp nolock

" Options: ntfs
syn match fsOptionsKeywords contained /\<\%(posix=*\|uni_xlate=\)/ nextgroup=fsOptionsNumber
syn keyword fsOptionsKeywords contained utf8

" Options: proc
" -- everything already defined

" Options: reiserfs
syn match fsOptionsKeywords contained /\<hash=/ nextgroup=fsOptionsReiserHash
syn match fsOptionsKeywords contained /\<resize=/ nextgroup=fsOptionsNumber
syn keyword fsOptionsReiserHash contained rupasov tea r5 detect
syn keyword fsOptionsKeywords contained hashed_relocation noborder nolog notail no_unhashed_relocation replayonly

" Options: sshfs
syn match fsOptionsKeywords contained /\<\%(BatchMode\|ChallengeResponseAuthentication\|CheckHostIP\|ClearAllForwardings\|Compression\|EnableSSHKeysign\|ForwardAgent\|ForwardX11\|ForwardX11Trusted\|GatewayPorts\|GSSAPIAuthentication\|GSSAPIDelegateCredentials\|HashKnownHosts\|HostbasedAuthentication\|IdentitiesOnly\|NoHostAuthenticationForLocalhost\|PasswordAuthentication\|PubkeyAuthentication\|RhostsRSAAuthentication\|RSAAuthentication\|TCPKeepAlive\|UsePrivilegedPort\|cache\)=/ nextgroup=fsOptionsYesNo
syn match fsOptionsKeywords contained /\<\%(ControlMaster\|StrictHostKeyChecking\|VerifyHostKeyDNS\)=/ nextgroup=fsOptionsSshYesNoAsk
syn match fsOptionsKeywords contained /\<\%(AddressFamily\|BindAddress\|Cipher\|Ciphers\|ControlPath\|DynamicForward\|EscapeChar\|GlobalKnownHostsFile\|HostKeyAlgorithms\|HostKeyAlias\|HostName\|IdentityFile\|KbdInteractiveDevices\|LocalForward\|LogLevel\|MACs\|PreferredAuthentications\|Protocol\|ProxyCommand\|RemoteForward\|RhostsAuthentication\|SendEnv\|SmartcardDevice\|User\|UserKnownHostsFile\|XAuthLocation\|comment\|workaround\|idmap\|ssh_command\|sftp_server\|fsname\)=/ nextgroup=fsOptionsString
syn match fsOptionsKeywords contained /\<\%(CompressionLevel\|ConnectionAttempts\|ConnectTimeout\|NumberOfPasswordPrompts\|Port\|ServerAliveCountMax\|ServerAliveInterval\|cache_timeout\|cache_X_timeout\|ssh_protocol\|directport\|max_read\|umask\|uid\|gid\|entry_timeout\|negative_timeout\|attr_timeout\)=/ nextgroup=fsOptionsNumber
syn keyword fsOptionsKeywords contained reconnect sshfs_sync no_readahead sshfs_debug transform_symlinks allow_other allow_root nonempty default_permissions large_read hard_remove use_ino readdir_ino direct_io kernel_cache
syn keyword fsOptionsSshYesNoAsk contained yes no ask

" Options: subfs
syn match fsOptionsKeywords contained /\<fs=/ nextgroup=fsOptionsString
syn keyword fsOptionsKeywords contained procuid

" Options: swap
syn match fsOptionsKeywords contained /\<pri=/ nextgroup=fsOptionsNumber

" Options: tmpfs
syn match fsOptionsKeywords contained /\<nr_\%(blocks\|inodes\)=/ nextgroup=fsOptionsNumber

" Options: udf
syn match fsOptionsKeywords contained /\<\%(anchor\|partition\|lastblock\|fileset\|rootdir\)=/ nextgroup=fsOptionsString
syn keyword fsOptionsKeywords contained unhide undelete strict novrs

" Options: ufs
syn match fsOptionsKeywords contained /\<ufstype=/ nextgroup=fsOptionsUfsType
syn match fsOptionsKeywords contained /\<onerror=/ nextgroup=fsOptionsUfsError
syn keyword fsOptionsUfsType contained old hp 44bsd sun sunx86 nextstep openstep
syn match fsOptionsUfsType contained /\<nextstep-cd\>/
syn keyword fsOptionsUfsError contained panic lock umount repair

" Options: usbfs
syn match fsOptionsKeywords contained /\<\%(dev\|bus\|list\)\%(id\|gid\)=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<\%(dev\|bus\|list\)mode=/ nextgroup=fsOptionsNumberOctal

" Options: vfat
syn keyword fsOptionsKeywords contained nonumtail posix utf8
syn match fsOptionsKeywords contained /shortname=/ nextgroup=fsOptionsVfatShortname
syn keyword fsOptionsVfatShortname contained lower win95 winnt mixed

" Options: xfs
syn match fsOptionsKeywords contained /\%(biosize\|logbufs\|logbsize\|logdev\|rtdev\|sunit\|swidth\)=/ nextgroup=fsOptionsString
syn keyword fsOptionsKeywords contained dmapi xdsm noalign noatime noquota norecovery osyncisdsync quota usrquota uqnoenforce grpquota gqnoenforce

" Frequency / Pass No.
syn cluster fsFreqPassCluster contains=fsFreqPassNumber,fsFreqPassError
syn match fsFreqPassError /\s\+\zs\%(\D.*\|\S.*\|\d\+\s\+[^012]\)\ze/ contained
syn match fsFreqPassNumber /\d\+\s\+[012]\s*/ contained

" Groups
syn match fsDevice /^\s*\zs.\{-1,}\s/me=e-1 nextgroup=fsMountPoint contains=@fsDeviceCluster,@fsGeneralCluster
syn match fsMountPoint /\s\+.\{-}\s/me=e-1 nextgroup=fsType contains=@fsMountPointCluster,@fsGeneralCluster contained
syn match fsType /\s\+.\{-}\s/me=e-1 nextgroup=fsOptions contains=@fsTypeCluster,@fsGeneralCluster contained
syn match fsOptions /\s\+.\{-}\s/me=e-1 nextgroup=fsFreqPass contains=@fsOptionsCluster,@fsGeneralCluster contained
syn match fsFreqPass /\s\+.\{-}$/ contains=@fsFreqPassCluster,@fsGeneralCluster contained

" Whole line comments
syn match fsCommentLine /^#.*$/ contains=@Spell

hi def link fsOperator Operator
hi def link fsComment Comment
hi def link fsCommentLine Comment

hi def link fsTypeKeyword Type
hi def link fsDeviceKeyword Identifier
hi def link fsDeviceLabel String
hi def link fsDeviceUUID String
hi def link fsDevicePARTLABEL String
hi def link fsDevicePARTUUID String
hi def link fsDeviceSshfs String
hi def link fsFreqPassNumber Number

if exists('fstab_unknown_fs_errors') && fstab_unknown_fs_errors == 1
	hi def link fsTypeUnknown Error
endif

if !exists('fstab_unknown_device_errors') || fstab_unknown_device_errors == 1
	hi def link fsDeviceError Error
endif

hi def link fsMountPointError Error
hi def link fsMountPointKeyword Keyword
hi def link fsFreqPassError Error

hi def link fsOptionsGeneral Type
hi def link fsOptionsKeywords Keyword
hi def link fsOptionsNumber Number
hi def link fsOptionsNumberOctal Number
hi def link fsOptionsString String
hi def link fsOptionsSize Number
hi def link fsOptionsExt2Check String
hi def link fsOptionsExt2Errors String
hi def link fsOptionsExt3Journal String
hi def link fsOptionsExt3Data String
hi def link fsOptionsExt4Journal String
hi def link fsOptionsExt4Data String
hi def link fsOptionsExt4Barrier Number
hi def link fsOptionsFatCheck String
hi def link fsOptionsConv String
hi def link fsOptionsFatType Number
hi def link fsOptionsYesNo String
hi def link fsOptionsHpfsCase String
hi def link fsOptionsIsoMap String
hi def link fsOptionsReiserHash String
hi def link fsOptionsSshYesNoAsk String
hi def link fsOptionsUfsType String
hi def link fsOptionsUfsError String

hi def link fsOptionsVfatShortname String

let b:current_syntax = "fstab"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 ft=vim
