" Vim syntax file
" Language: fstab file
" Maintainer: Radu Dineiu <radu.dineiu@gmail.com>
" URL: https://raw.github.com/rid9/vim-fstab/master/syntax/fstab.vim
" Last Change: 2024 Jul 11
" Version: 1.6.4
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
syn keyword fsDeviceKeyword contained none proc linproc tmpfs devpts devtmpfs sysfs usbfs tracefs overlay
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
syn keyword fsTypeKeyword contained adfs ados affs anon_inodefs atfs audiofs auto autofs bdev befs bfs btrfs binfmt_misc cd9660 ceph cfs cgroup cifs coda coherent configfs cpuset cramfs debugfs devfs devpts devtmpfs dlmfs e2compr ecryptfs efivarfs efs erofs exfat ext2 ext2fs ext3 ext4 f2fs fdesc ffs filecore fuse fuseblk fusectl gfs2 hfs hfsplus hpfs hugetlbfs iso9660 jffs jffs2 jfs kernfs lfs linprocfs mfs minix mqueue msdos ncpfs nfs nfs4 nfsd nilfs2 none ntfs ntfs3 null nwfs ocfs2 omfs overlay ovlfs pipefs portal proc procfs pstore ptyfs pvfs2 qnx4 qnx6 reiserfs ramfs romfs rpc_pipefs securityfs shm smbfs spufs squashfs sockfs sshfs std subfs swap sysfs sysv tcfs tmpfs tracefs ubifs udf ufs umap umsdos union usbfs userfs v9fs vfat virtiofs vs3fs vxfs wrapfs wvfs xenfs xenix xfs zisofs zonefs

" Options
" -------
" Options: General
syn cluster fsOptionsCluster contains=fsOperator,fsOptionsGeneral,fsOptionsKeywords,fsTypeUnknown
syn match fsOptionsNumber /\d\+/
syn match fsOptionsNumberSigned /[-+]\?\d\+/
syn match fsOptionsNumberOctal /[0-8]\+/
syn match fsOptionsString /[a-zA-Z0-9_-]\+/
syn keyword fsOptionsTrueFalse true false
syn keyword fsOptionsYesNo yes no
syn keyword fsOptionsYN y n
syn keyword fsOptions01 0 1
syn cluster fsOptionsCheckCluster contains=fsOptionsExt2Check,fsOptionsFatCheck
syn keyword fsOptionsSize 512 1024 2048
syn keyword fsOptionsGeneral async atime auto bind current defaults dev devgid devmode devmtime devuid dirsync exec force fstab kudzu loop managed mand move noatime noauto noclusterr noclusterw nodev nodevmtime nodiratime noexec nomand norelatime nosuid nosymfollow nouser owner pamconsole rbind rdonly relatime remount ro rq rw suid suiddir supermount sw sync union update user users wxallowed xx nofail failok lazytime
syn match fsOptionsGeneral /_netdev/

syn match fsOptionsKeywords contained /\<x-systemd\.\%(requires\|before\|after\|wanted-by\|required-by\|requires-mounts-for\|idle-timeout\|device-timeout\|mount-timeout\)=/ nextgroup=fsOptionsString
syn match fsOptionsKeywords contained /\<x-systemd\.\%(device-bound\|automount\|makefs\|growfs\|rw-only\)/
syn match fsOptionsKeywords contained /\<x-initrd\.mount/

syn match fsOptionsKeywords contained /\<cache=/ nextgroup=fsOptionsCache
syn keyword fsOptionsCache contained yes no none strict loose fscache mmap

syn match fsOptionsKeywords contained /\<dax=/ nextgroup=fsOptionsDax
syn keyword fsOptionsDax contained inode never always

syn match fsOptionsKeywords contained /\<errors=/ nextgroup=fsOptionsErrors
syn keyword fsOptionsErrors contained continue panic withdraw remount-ro recover zone-ro zone-offline repair

syn match fsOptionsKeywords contained /\<\%(sec\)=/ nextgroup=fsOptionsSecurityMode
syn keyword fsOptionsSecurityMode contained none krb5 krb5i ntlm ntlmi ntlmv2 ntlmv2i ntlmssp ntlmsspi sys lkey lkeyi lkeyp spkm spkmi spkmp

" Options: adfs
syn match fsOptionsKeywords contained /\<\%([ug]id\|o\%(wn\|th\)mask\)=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<ftsuffix=/ nextgroup=fsOptions01

" Options: affs
syn match fsOptionsKeywords contained /\<mode=/ nextgroup=fsOptionsString
syn match fsOptionsKeywords contained /\<\%(set[ug]id\|reserved\)=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<\%(prefix\|volume\|root\)=/ nextgroup=fsOptionsString
syn match fsOptionsKeywords contained /\<bs=/ nextgroup=fsOptionsSize
syn keyword fsOptionsKeywords contained protect usemp verbose nofilenametruncate mufs

" Options: btrfs
syn match fsOptionsKeywords contained /\<\%(subvol\|subvolid\|subvolrootid\|device\|compress\|compress-force\|check_int_print_mask\|space_cache\)=/ nextgroup=fsOptionsString
syn match fsOptionsKeywords contained /\<\%(max_inline\|alloc_start\|thread_pool\|metadata_ratio\|check_int_print_mask\)=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<discard=/ nextgroup=fsOptionsBtrfsDiscard
syn keyword fsOptionsBtrfsDiscard sync async
syn match fsOptionsKeywords contained /\<fatal_errors=/ nextgroup=fsOptionsBtrfsFatalErrors
syn keyword fsOptionsBtrfsFatalErrors bug panic
syn match fsOptionsKeywords contained /\<fragment=/ nextgroup=fsOptionsBtrfsFragment
syn keyword fsOptionsBtrfsFragment data metadata all
syn keyword fsOptionsKeywords contained degraded datasum nodatasum datacow nodatacow barrier nobarrier ssd ssd_spread nossd nossd_spread noacl treelog notreelog flushoncommit noflushoncommit space_cache nospace_cache clear_cache user_subvol_rm_allowed autodefrag noautodefrag inode_cache noinode_cache enospc_debug noenospc_debug recovery check_int check_int_data skip_balance discard nodiscard compress compress-force nologreplay rescan_uuid_tree rescue usebackuproot

" Options: cd9660
syn keyword fsOptionsKeywords contained extatt gens norrip nostrictjoilet

" Options: ceph
syn match fsOptionsKeywords contained /\<\%(mon_addr\|fsid\|rasize\|mount_timeout\|caps_max\)=/ nextgroup=fsOptionsString
syn keyword fsOptionsKeywords contained rbytes norbytes nocrc dcache nodcache noasyncreaddir noquotadf nocopyfrom
syn match fsOptionsKeywords contained /\<recover_session=/ nextgroup=fsOptionsCephRecoverSession
syn keyword fsOptionsCephRecoverSession contained no clean

" Options: cifs
syn match fsOptionsKeywords contained /\<\%(user\|password\|credentials\|servernetbiosname\|servern\|netbiosname\|file_mode\|dir_mode\|ip\|domain\|prefixpath\)=/ nextgroup=fsOptionsString
syn match fsOptionsKeywords contained /\<\%(cruid\|backupuid\|backupgid\)=/ nextgroup=fsOptionsNumber
syn keyword fsOptionsKeywords contained forceuid forcegid guest setuids nosetuids perm noperm dynperm strictcache rwpidforward mapchars nomapchars cifsacl nocase ignorecase nobrl sfu serverino noserverino nounix fsc multiuser posixpaths noposixpaths

" Options: devpts
" -- everything already defined

" Options: ecryptfs
syn match fsOptionsKeywords contained /\<\%(ecryptfs_\%(sig\|fnek_sig\|cipher\|key_bytes\)\|key\)=/ nextgroup=fsOptionsString
syn keyword fsOptionsKeywords contained ecryptfs_passthrough no_sig_cache ecryptfs_encrypted_view ecryptfs_xattr
syn match fsOptionsKeywords contained /\<ecryptfs_enable_filename_crypto=/ nextgroup=fsOptionsYN
syn match fsOptionsKeywords contained /\<verbosity=/ nextgroup=fsOptions01

" Options: erofs
syn match fsOptionsKeywords contained /\<cache_strategy=/ nextgroup=fsOptionsEroCacheStrategy
syn keyword fsOptionsEroCacheStrategy contained disabled readahead readaround

" Options: ext2
syn match fsOptionsKeywords contained /\<check=*/ nextgroup=@fsOptionsCheckCluster
syn match fsOptionsKeywords contained /\<\%(res[gu]id\|sb\)=/ nextgroup=fsOptionsNumber
syn keyword fsOptionsExt2Check contained none normal strict
syn match fsOptionsErrors contained /\<remount-ro\>/
syn keyword fsOptionsKeywords contained acl bsddf minixdf debug grpid bsdgroups minixdf nocheck nogrpid oldalloc orlov sysvgroups nouid32 nobh user_xattr nouser_xattr

" Options: ext3
syn match fsOptionsKeywords contained /\<journal=/ nextgroup=fsOptionsExt3Journal
syn match fsOptionsKeywords contained /\<data=/ nextgroup=fsOptionsExt3Data
syn match fsOptionsKeywords contained /\<data_err=/ nextgroup=fsOptionsExt3DataErr
syn match fsOptionsKeywords contained /\<commit=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<jqfmt=/ nextgroup=fsOptionsExt3Jqfmt
syn match fsOptionsKeywords contained /\<\%(usrjquota\|grpjquota\)=/ nextgroup=fsOptionsString
syn keyword fsOptionsExt3Journal contained update inum
syn keyword fsOptionsExt3Data contained journal ordered writeback
syn keyword fsOptionsExt3DataErr contained ignore abort
syn keyword fsOptionsExt3Jqfmt contained vfsold vfsv0 vfsv1
syn keyword fsOptionsKeywords contained noload user_xattr nouser_xattr acl

" Options: ext4
syn match fsOptionsKeywords contained /\<journal=/ nextgroup=fsOptionsExt4Journal
syn match fsOptionsKeywords contained /\<data=/ nextgroup=fsOptionsExt4Data
syn match fsOptionsKeywords contained /\<barrier=/ nextgroup=fsOptions01
syn match fsOptionsKeywords contained /\<journal_dev=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<resuid=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<resgid=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<sb=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<\%(commit\|inode_readahead_blks\|stripe\|max_batch_time\|min_batch_time\|init_itable\|max_dir_size_kb\)=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<journal_ioprio=/ nextgroup=fsOptionsExt4JournalIoprio
syn keyword fsOptionsExt4Journal contained update inum
syn keyword fsOptionsExt4Data contained journal ordered writeback
syn keyword fsOptionsExt4JournalIoprio contained 0 1 2 3 4 5 6 7
syn keyword fsOptionsKeywords contained noload extents orlov oldalloc user_xattr nouser_xattr acl noacl reservation noreservation bsddf minixdf check=none nocheck debug grpid nogroupid sysvgroups bsdgroups quota noquota grpquota usrquota bh nobh journal_checksum nojournal_checksum journal_async_commit delalloc nodelalloc auto_da_alloc noauto_da_alloc noinit_itable block_validity noblock_validity dioread_lock dioread_nolock i_version nombcache prjquota

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

" Options: fuse
syn match fsOptionsKeywords contained /\<\%(fd\|user_id\|group_id\|blksize\)=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<\%(rootmode\)=/ nextgroup=fsOptionsString

" Options: hfs
syn match fsOptionsKeywords contained /\<\%(creator\|type\)=/ nextgroup=fsOptionsString
syn match fsOptionsKeywords contained /\<\%(dir\|file\|\)_umask=/ nextgroup=fsOptionsNumberOctal
syn match fsOptionsKeywords contained /\<\%(session\|part\)=/ nextgroup=fsOptionsNumber

" Options: hfsplus
syn match fsOptionsKeywords contained /\<nls=/ nextgroup=fsOptionsString
syn keyword fsOptionsKeywords contained decompose nodecompose

" Options: f2fs
syn match fsOptionsKeywords contained /\<background_gc=/ nextgroup=fsOptionsF2fsBackgroundGc
syn keyword fsOptionsF2fsBackgroundGc contained on off sync
syn match fsOptionsKeywords contained /\<active_logs=/ nextgroup=fsOptionsF2fsActiveLogs
syn keyword fsOptionsF2fsActiveLogs contained 2 4 6
syn match fsOptionsKeywords contained /\<alloc_mode=/ nextgroup=fsOptionsF2fsAllocMode
syn keyword fsOptionsF2fsAllocMode contained reuse default
syn match fsOptionsKeywords contained /\<fsync_mode=/ nextgroup=fsOptionsF2fsFsyncMode
syn keyword fsOptionsF2fsFsyncMode contained posix strict nobarrier
syn match fsOptionsKeywords contained /\<compress_mode=/ nextgroup=fsOptionsF2fsCompressMode
syn keyword fsOptionsF2fsCompressMode contained fs user
syn match fsOptionsKeywords contained /\<discard_unit=/ nextgroup=fsOptionsF2fsDiscardUnit
syn keyword fsOptionsF2fsDiscardUnit contained block segment section
syn match fsOptionsKeywords contained /\<memory=/ nextgroup=fsOptionsF2fsMemory
syn keyword fsOptionsF2fsMemory contained normal low
syn match fsOptionsKeywords contained /\<\%(inline_xattr_size\|reserve_root\|fault_injection\|fault_type\|io_bits\|compress_log_size\)=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<\%(prjjquota\|test_dummy_encryption\|checkpoint\|compress_algorithm\|compress_extension\|nocompress_extension\)=/ nextgroup=fsOptionsString
syn keyword fsOptionsKeyWords contained gc_merge nogc_merge disable_roll_forward no_heap disable_ext_identify inline_xattr noinline_xattr inline_data noinline_data inline_dentry noinline_dentry flush_merge fastboot extent_cache noextent_cache data_flush offusrjquota offgrpjquota offprjjquota test_dummy_encryption checkpoint_merge nocheckpoint_merge compress_chksum compress_cache inlinecrypt atgc

" Options: ffs
syn keyword fsOptionsKeyWords contained noperm softdep

" Options: gfs2
syn match fsOptionsKeywords contained /\<\%(lockproto\|locktable\)=/ nextgroup=fsOptionsString
syn match fsOptionsKeywords contained /\<\%(quota_quantum\|statfs_quantum\|statfs_percent\)=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<quota=/ nextgroup=fsOptionsGfs2Quota
syn keyword fsOptionsGfs2Quota contained off account on
syn keyword fsOptionsKeywords contained localcaching localflocks ignore_local_fs upgrade spectator meta

" Options: hpfs
syn match fsOptionsKeywords contained /\<case=/ nextgroup=fsOptionsHpfsCase
syn keyword fsOptionsHpfsCase contained lower asis
syn match fsOptionsKeywords contained /\<chkdsk=/ nextgroup=fsOptionsHpfsChkdsk
syn keyword fsOptionsHpfsChkdsk contained no errors always
syn match fsOptionsKeywords contained /\<eas=/ nextgroup=fsOptionsHpfsEas
syn keyword fsOptionsHpfsEas contained no ro rw
syn match fsOptionsKeywords contained /\<timeshift=/ nextgroup=fsOptionsNumberSigned

" Options: iso9660
syn match fsOptionsKeywords contained /\<map=/ nextgroup=fsOptionsIsoMap
syn match fsOptionsKeywords contained /\<block=/ nextgroup=fsOptionsSize
syn match fsOptionsKeywords contained /\<\%(session\|sbsector\|dmode\)=/ nextgroup=fsOptionsNumber
syn keyword fsOptionsIsoMap contained n o a normal off acorn
syn keyword fsOptionsKeywords contained norock nojoliet hide unhide cruft overriderockperm showassoc
syn keyword fsOptionsConv contained m mtext

" Options: jfs
syn keyword fsOptionsKeywords nointegrity integrity

" Options: nfs
syn match fsOptionsKeywords contained /\<lookupcache=/ nextgroup=fsOptionsNfsLookupCache
syn keyword fsOptionsNfsLookupCache contained all none pos positive
syn match fsOptionsKeywords contained /\<local_lock=/ nextgroup=fsOptionsNfsLocalLock
syn keyword fsOptionsNfsLocalLock contained all flock posix none
syn match fsOptionsKeywords contained /\<\%(mounthost\|mountprog\|nfsprog\|namelen\|proto\|mountproto\|clientaddr\)=/ nextgroup=fsOptionsString
syn match fsOptionsKeywords contained /\<\%(timeo\|retrans\|[rw]size\|acregmin\|acregmax\|acdirmin\|acdirmax\|actimeo\|retry\|port\|mountport\|mountvers\|namlen\|nfsvers\|vers\|minorversion\)=/ nextgroup=fsOptionsNumber
syn keyword fsOptionsKeywords contained bg fg soft hard intr cto ac tcp udp lock nobg nofg nosoft nohard nointr noposix nocto noac notcp noudp nolock sharecache nosharecache resvport noresvport rdirplus nordirplus

" Options: nilfs2
syn match fsOptionsKeywords contained /\<order=/ nextgroup=fsOptionsNilfs2Order
syn keyword fsOptionsNilfs2Order contained relaxed strict
syn match fsOptionsKeywords contained /\<\%([cp]p\)=/ nextgroup=fsOptionsNumber
syn keyword fsOptionsKeywords contained nogc

" Options: ntfs
syn match fsOptionsKeywords contained /\<mft_zone_multiplier=/ nextgroup=fsOptionsNtfsMftZoneMultiplier
syn keyword fsOptionsNtfsMftZoneMultiplier contained 1 2 3 4
syn match fsOptionsKeywords contained /\<\%(posix=*\|uni_xlate=\)/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<\%(sloppy\|show_sys_files\|case_sensitive\|disable_sparse\)=/ nextgroup=fsOptionsTrueFalse
syn keyword fsOptionsKeywords contained utf8

" Options: ntfs3
syn keyword fsOptionsKeywords contained noacsrules nohidden sparse showmeta prealloc

" Options: ntfs-3g
syn match fsOptionsKeywords contained /\<\%(usermapping\|locale\|streams_interface\)=/ nextgroup=fsOptionsString
syn keyword fsOptionsKeywords contained permissions inherit recover norecover ignore_case remove_hiberfile hide_hid_files hide_dot_files windows_names silent no_def_opts efs_raw compression nocompression no_detach

" Options: ocfs2
syn match fsOptionsKeywords contained /\<\%(resv_level\|dir_resv_level\)=/ nextgroup=fsOptionsOcfs2ResvLevel
syn keyword fsOptionsOcfs2ResvLevel contained 0 1 2 3 4 5 6 7 8
syn match fsOptionsKeywords contained /\<coherency=/ nextgroup=fsOptionsOcfs2Coherency
syn keyword fsOptionsOcfs2Coherency contained full buffered
syn match fsOptionsKeywords contained /\<\%(atime_quantum\|preferred_slot\|localalloc\)=/ nextgroup=fsOptionsNumber
syn keyword fsOptionsKeywords contained strictatime inode64

" Options: overlay
syn match fsOptionsKeywords contained /\<\%(index\|uuid\|nfs_export\|metacopy\)=/ nextgroup=fsOptionsOverlayBool
syn keyword fsOptionsOverlayBool contained on off
syn match fsOptionsKeywords contained /\<\%(lowerdir\|upperdir\|workdir\)=/ nextgroup=fsOptionsOverlayDir
syn match fsOptionsOverlayDir contained /[^,[:space:]]*/
syn match fsOptionsKeywords contained /\<redirect_dir=/ nextgroup=fsOptionsOverlayRedirectDir
syn keyword fsOptionsOverlayRedirectDir contained on follow off nofollow
syn match fsOptionsKeywords contained /\<xino=/ nextgroup=fsOptionsOverlayXino
syn keyword fsOptionsOverlayXino contained on off auto
syn keyword fsOptionsKeywords contained userxattr volatile

" Options: proc
syn match fsOptionsKeywords contained /\<\%(hidepid\|subset\)=/ nextgroup=fsOptionsString

" Options: qnx4
syn match fsOptionsKeywords contained /\<bitmap=/ nextgroup=fsOptionsQnx4Bitmap
syn keyword fsOptionsQnx4Bitmap contained always lazy nonrmv
syn keyword fsOptionsKeywords contained grown noembed overalloc unbusy

" Options: qnx6
syn match fsOptionsKeywords contained /\<hold=/ nextgroup=fsOptionsQnx6Hold
syn keyword fsOptionsQnx6Hold contained allow root deny
syn match fsOptionsKeywords contained /\<sync=/ nextgroup=fsOptionsQnx6Sync
syn keyword fsOptionsQnx6Sync contained mandatory optional none
syn match fsOptionsKeywords contained /\<snapshot=/ nextgroup=fsOptionsNumber
syn keyword fsOptionsKeywords contained alignio

" Options: reiserfs
syn match fsOptionsKeywords contained /\<hash=/ nextgroup=fsOptionsReiserHash
syn match fsOptionsKeywords contained /\<resize=/ nextgroup=fsOptionsNumber
syn keyword fsOptionsReiserHash contained rupasov tea r5 detect
syn keyword fsOptionsKeywords contained hashed_relocation noborder nolog notail no_unhashed_relocation replayonly

" Options: sshfs
syn match fsOptionsKeywords contained /\<\%(BatchMode\|ChallengeResponseAuthentication\|CheckHostIP\|ClearAllForwardings\|Compression\|EnableSSHKeysign\|ForwardAgent\|ForwardX11\|ForwardX11Trusted\|GatewayPorts\|GSSAPIAuthentication\|GSSAPIDelegateCredentials\|HashKnownHosts\|HostbasedAuthentication\|IdentitiesOnly\|NoHostAuthenticationForLocalhost\|PasswordAuthentication\|PubkeyAuthentication\|RhostsRSAAuthentication\|RSAAuthentication\|TCPKeepAlive\|UsePrivilegedPort\)=/ nextgroup=fsOptionsYesNo
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

" Options: ubifs
syn match fsOptionsKeywords contained /\<\%(compr\|auth_key\|auth_hash_name\)=/ nextgroup=fsOptionsString
syn keyword fsOptionsKeywords contained bulk_read no_bulk_read chk_data_crc no_chk_data_crc

" Options: tmpfs
syn match fsOptionsKeywords contained /\<huge=/ nextgroup=fsOptionsTmpfsHuge
syn keyword fsOptionsTmpfsHuge contained never always within_size advise deny force
syn match fsOptionsKeywords contained /\<\%(size\|mpol\)=/ nextgroup=fsOptionsString
syn match fsOptionsKeywords contained /\<nr_\%(blocks\|inodes\)=/ nextgroup=fsOptionsNumber

" Options: udf
syn match fsOptionsKeywords contained /\<\%(anchor\|partition\|lastblock\|fileset\|rootdir\)=/ nextgroup=fsOptionsString
syn keyword fsOptionsKeywords contained unhide undelete strict nostrict novrs adinicb noadinicb shortad longad

" Options: ufs
syn match fsOptionsKeywords contained /\<ufstype=/ nextgroup=fsOptionsUfsType
syn match fsOptionsKeywords contained /\<onerror=/ nextgroup=fsOptionsUfsError
syn keyword fsOptionsUfsType contained old hp 44bsd sun sunx86 nextstep openstep
syn match fsOptionsUfsType contained /\<nextstep-cd\>/
syn keyword fsOptionsUfsError contained panic lock umount repair

" Options: usbfs
syn match fsOptionsKeywords contained /\<\%(dev\|bus\|list\)\%(id\|gid\)=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<\%(dev\|bus\|list\)mode=/ nextgroup=fsOptionsNumberOctal

" Options: v9fs
syn match fsOptionsKeywords contained /\<\%(trans\)=/ nextgroup=fsOptionsV9Trans
syn keyword fsOptionsV9Trans unix tcp fd virtio rdma
syn match fsOptionsKeywords contained /\<debug=/ nextgroup=fsOptionsV9Debug
syn keyword fsOptionsV9Debug 0x01 0x02 0x04 0x08 0x10 0x20 0x40 0x80 0x100 0x200 0x400 0x800
syn match fsOptionsKeywords contained /\<version=/ nextgroup=fsOptionsV9Version
syn keyword fsOptionsV9Version 9p2000 9p2000.u 9p2000.L
syn match fsOptionsKeywords contained /\<\%([ua]name\|[rw]fdno\|access\)=/ nextgroup=fsOptionsString
syn match fsOptionsKeywords contained /\<msize=/ nextgroup=fsOptionsNumber
syn keyword fsOptionsKeywords contained noextend dfltuid dfltgid afid nodevmap cachetag

" Options: vfat
syn match fsOptionsKeywords contained /\<shortname=/ nextgroup=fsOptionsVfatShortname
syn keyword fsOptionsVfatShortname contained lower win95 winnt mixed
syn match fsOptionsKeywords contained /\<nfs=/ nextgroup=fsOptionsVfatNfs
syn keyword fsOptionsVfatNfs contained stale_rw nostale_ro
syn match fsOptionsKeywords contained /\<\%(tz\|dos1xfloppy\)=/ nextgroup=fsOptionsString
syn match fsOptionsKeywords contained /\<\%(allow_utime\|codepage\)=/ nextgroup=fsOptionsNumber
syn match fsOptionsKeywords contained /\<time_offset=/ nextgroup=fsOptionsNumberSigned
syn keyword fsOptionsKeywords contained nonumtail posix utf8 usefree flush rodir

" Options: xfs
syn match fsOptionsKeywords contained /\<logbufs=/ nextgroup=fsOptionsXfsLogBufs
syn keyword fsOptionsXfsLogBufs contained 2 3 4 5 6 7 8
syn match fsOptionsKeywords contained /\%(allocsize\|biosize\|logbsize\|logdev\|rtdev\|sunit\|swidth\)=/ nextgroup=fsOptionsString
syn keyword fsOptionsKeywords contained dmapi xdsm noalign noatime noquota norecovery osyncisdsync quota usrquota uqnoenforce grpquota gqnoenforce attr2 noattr2 filestreams ikeep noikeep inode32 inode64 largeio nolargeio nouuid uquota qnoenforce gquota pquota pqnoenforce swalloc wsync

" Frequency / Pass No.
syn cluster fsFreqPassCluster contains=fsFreqPassNumber,fsFreqPassError
syn match fsFreqPassError /\s\+\zs\%(\D.*\|\S.*\|\d\+\s\+[^012]\)\ze/ contained
syn match fsFreqPassNumber /\d\+\s\+[012]\s*/ contained

" Groups
syn match fsDevice /^\s*\zs.\{-1,}\s/me=e-1 nextgroup=fsMountPoint contains=@fsDeviceCluster,@fsGeneralCluster
syn match fsMountPoint /\s\+.\{-}\s/me=e-1 nextgroup=fsType contains=@fsMountPointCluster,@fsGeneralCluster contained
syn match fsType /\s\+.\{-}\s/me=e-1 nextgroup=fsOptions contains=@fsTypeCluster,@fsGeneralCluster contained
syn match fsOptions /\s\+.\{-}\%(\s\|$\)/ nextgroup=fsFreqPass contains=@fsOptionsCluster,@fsGeneralCluster contained
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

hi def link fsOptionsBtrfsDiscard String
hi def link fsOptionsBtrfsFatalErrors String
hi def link fsOptionsBtrfsFragment String
hi def link fsOptionsCache String
hi def link fsOptionsCephRecoverSession String
hi def link fsOptionsConv String
hi def link fsOptionsDax String
hi def link fsOptionsEroCacheStrategy String
hi def link fsOptionsErrors String
hi def link fsOptionsExt2Check String
hi def link fsOptionsExt3Data String
hi def link fsOptionsExt3DataErr String
hi def link fsOptionsExt3Journal String
hi def link fsOptionsExt3Jqfmt String
hi def link fsOptionsExt4Data String
hi def link fsOptionsExt4Journal String
hi def link fsOptionsExt4JournalIoprio Number
hi def link fsOptionsF2fsActiveLogs Number
hi def link fsOptionsF2fsAllocMode String
hi def link fsOptionsF2fsBackgroundGc String
hi def link fsOptionsF2fsCompressMode String
hi def link fsOptionsF2fsDiscardUnit String
hi def link fsOptionsF2fsFsyncMode String
hi def link fsOptionsF2fsMemory String
hi def link fsOptionsFatCheck String
hi def link fsOptionsFatType Number
hi def link fsOptionsGeneral Type
hi def link fsOptionsGfs2Quota String
hi def link fsOptionsHpfsCase String
hi def link fsOptionsHpfsChkdsk String
hi def link fsOptionsHpfsEas String
hi def link fsOptionsIsoMap String
hi def link fsOptionsKeywords Keyword
hi def link fsOptionsNfsLocalLock String
hi def link fsOptionsNfsLookupCache String
hi def link fsOptionsNilfs2Order String
hi def link fsOptionsNtfsMftZoneMultiplier Number
hi def link fsOptionsNumber Number
hi def link fsOptionsNumberOctal Number
hi def link fsOptionsNumberSigned Number
hi def link fsOptionsOcfs2Coherency String
hi def link fsOptionsOcfs2ResvLevel Number
hi def link fsOptionsOverlayBool Boolean
hi def link fsOptionsOverlayDir String
hi def link fsOptionsOverlayRedirectDir String
hi def link fsOptionsOverlayXino String
hi def link fsOptionsQnx4Bitmap String
hi def link fsOptionsQnx6Hold String
hi def link fsOptionsQnx6Sync String
hi def link fsOptionsReiserHash String
hi def link fsOptionsSecurityMode String
hi def link fsOptionsSize Number
hi def link fsOptionsSshYesNoAsk String
hi def link fsOptionsString String
hi def link fsOptionsTmpfsHuge String
hi def link fsOptionsUfsError String
hi def link fsOptionsUfsType String
hi def link fsOptionsV9Debug String
hi def link fsOptionsV9Trans String
hi def link fsOptionsV9Version String
hi def link fsOptionsVfatNfs String
hi def link fsOptionsVfatShortname String
hi def link fsOptionsXfsLogBufs Number

hi def link fsOptionsTrueFalse Boolean
hi def link fsOptionsYesNo String
hi def link fsOptionsYN String
hi def link fsOptions01 Number

let b:current_syntax = "fstab"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 noet ft=vim
