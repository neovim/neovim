" Vim syntax file
" Language:	Upstart job files
" Maintainer:	Michael Biebl <biebl@debian.org>
"		James Hunt <james.hunt@ubuntu.com>
" Last Change:	2012 Jan 16
" License:	The Vim license
" Version:	0.4
" Remark:	Syntax highlighting for Upstart (init(8)) job files.
"
" It is inspired by the initng syntax file and includes sh.vim to do the
" highlighting of script blocks.

if version < 600
	syntax clear
elseif exists("b:current_syntax")
	finish
endif

let is_bash = 1
syn include @Shell syntax/sh.vim

syn case match

" avoid need to use 'match' for most events
setlocal iskeyword+=-

syn match upstartComment /#.*$/ contains=upstartTodo
syn keyword upstartTodo TODO FIXME contained

syn region upstartString start=/"/ end=/"/ skip=/\\"/

syn region upstartScript matchgroup=upstartStatement start="script" end="end script" contains=@upstartShellCluster

syn cluster upstartShellCluster contains=@Shell

" one argument
syn keyword upstartStatement description author version instance expect
syn keyword upstartStatement pid kill normal console env exit export
syn keyword upstartStatement umask nice oom chroot chdir exec

" two arguments
syn keyword upstartStatement limit

" one or more arguments (events)
syn keyword upstartStatement emits

syn keyword upstartStatement on start stop

" flag, no parameter
syn keyword upstartStatement respawn service instance manual debug task

" prefix for exec or script 
syn keyword upstartOption pre-start post-start pre-stop post-stop

" option for kill
syn keyword upstartOption timeout
" option for oom
syn keyword upstartOption never
" options for console
syn keyword upstartOption output owner
" options for expect
syn keyword upstartOption fork daemon
" options for limit
syn keyword upstartOption unlimited

" 'options' for start/stop on
syn keyword upstartOption and or

" Upstart itself and associated utilities
syn keyword upstartEvent runlevel
syn keyword upstartEvent started
syn keyword upstartEvent starting
syn keyword upstartEvent startup
syn keyword upstartEvent stopped
syn keyword upstartEvent stopping
syn keyword upstartEvent control-alt-delete
syn keyword upstartEvent keyboard-request
syn keyword upstartEvent power-status-changed

" D-Bus
syn keyword upstartEvent dbus-activation

" Display Manager (ie gdm)
syn keyword upstartEvent desktop-session-start
syn keyword upstartEvent login-session-start

" mountall
syn keyword upstartEvent all-swaps
syn keyword upstartEvent filesystem
syn keyword upstartEvent mounted
syn keyword upstartEvent mounting
syn keyword upstartEvent local-filesystems
syn keyword upstartEvent remote-filesystems
syn keyword upstartEvent virtual-filesystems

" SysV umountnfs.sh
syn keyword upstartEvent mounted-remote-filesystems

" upstart-udev-bridge and ifup/down
syn match   upstartEvent /\<\i\{-1,}-device-\(added\|removed\|up\|down\)/

" upstart-socket-bridge
syn keyword upstartEvent socket

hi def link upstartComment   Comment
hi def link upstartTodo	     Todo
hi def link upstartString    String
hi def link upstartStatement Statement
hi def link upstartOption    Type
hi def link upstartEvent     Define

let b:current_syntax = "upstart"
