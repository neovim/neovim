" Vim syntax file
" Language:     Novell "NCF" Batch File
" Maintainer:   Jonathan J. Miner <miner@doit.wisc.edu>
" Last Change:	Tue, 04 Sep 2001 16:20:33 CDT
" $Id: ncf.vim,v 1.1 2004/06/13 16:31:58 vimboss Exp $

" Remove any old syntax stuff hanging around
if version < 600
    syn clear
elseif exists("b:current_syntax")
    finish
endif

syn case ignore

syn keyword ncfCommands		mount load unload
syn keyword ncfBoolean		on off
syn keyword ncfCommands		set nextgroup=ncfSetCommands
syn keyword ncfTimeTypes	Reference Primary Secondary Single
syn match ncfLoad       "\(unl\|l\)oad .*"lc=4 contains=ALLBUT,Error
syn match ncfMount      "mount .*"lc=5 contains=ALLBUT,Error

syn match ncfComment    "^\ *rem.*$"
syn match ncfComment    "^\ *;.*$"
syn match ncfComment    "^\ *#.*$"

syn match ncfSearchPath "search \(add\|del\) " nextgroup=ncfPath
syn match ncfPath       "\<[^: ]\+:\([A-Za-z0-9._]\|\\\)*\>"
syn match ncfServerName "^file server name .*$"
syn match ncfIPXNet     "^ipx internal net"

" String
syn region ncfString    start=+"+  end=+"+
syn match ncfContString "= \(\(\.\{0,1}\(OU=\|O=\)\{0,1}[A-Z_]\+\)\+;\{0,1}\)\+"lc=2

syn match ncfHexNumber  "\<\d\(\d\+\|[A-F]\+\)*\>"
syn match ncfNumber     "\<\d\+\.\{0,1}\d*\>"
syn match ncfIPAddr     "\d\{1,3}\.\d\{1,3}\.\d\{1,3}\.\d\{1,3}"
syn match ncfTime       "\(+|=\)\{0,1}\d\{1,2}:\d\{1,2}:\d\{1,2}"
syn match ncfDSTTime    "([^ ]\+ [^ ]\+ \(FIRST\|LAST\)\s*\d\{1,2}:\d\{1,2}:\d\{1,2} \(AM\|PM\))"
syn match ncfTimeZone   "[A-Z]\{3}\d[A-Z]\{3}"

syn match ncfLogins     "^\([Dd]is\|[Ee]n\)able login[s]*"
syn match ncfScript     "[^ ]*\.ncf"

"  SET Commands that take a Number following
syn match ncfSetCommandsNum "\(Alert Message Nodes\)\s*="
syn match ncfSetCommandsNum "\(Auto Restart After Abend\)\s*="
syn match ncfSetCommandsNum "\(Auto Restart After Abend Delay Time\)\s*="
syn match ncfSetCommandsNum "\(Compression Daily Check Starting Hour\)\s*="
syn match ncfSetCommandsNum "\(Compression Daily Check Stop Hour\)\s*="
syn match ncfSetCommandsNum "\(Concurrent Remirror Requests\)\s*="
syn match ncfSetCommandsNum "\(Convert Compressed to Uncompressed Option\)\s*="
syn match ncfSetCommandsNum "\(Days Untouched Before Compression\)\s*="
syn match ncfSetCommandsNum "\(Decompress Free Space Warning Interval\)\s*="
syn match ncfSetCommandsNum "\(Decompress Percent Disk Space Free to Allow Commit\)\s*="
syn match ncfSetCommandsNum "\(Deleted Files Compression Option\)\s*="
syn match ncfSetCommandsNum "\(Directory Cache Allocation Wait Time\)\s*="
syn match ncfSetCommandsNum "\(Enable IPX Checksums\)\s*="
syn match ncfSetCommandsNum "\(Garbage Collection Interval\)\s*="
syn match ncfSetCommandsNum "\(IPX NetBIOS Replication Option\)\s*="
syn match ncfSetCommandsNum "\(Maximum Concurrent Compressions\)\s*="
syn match ncfSetCommandsNum "\(Maximum Concurrent Directory Cache Writes\)\s*="
syn match ncfSetCommandsNum "\(Maximum Concurrent Disk Cache Writes\)\s*="
syn match ncfSetCommandsNum "\(Maximum Directory Cache Buffers\)\s*="
syn match ncfSetCommandsNum "\(Maximum Extended Attributes per File or Path\)\s*="
syn match ncfSetCommandsNum "\(Maximum File Locks\)\s*="
syn match ncfSetCommandsNum "\(Maximum File Locks Per Connection\)\s*="
syn match ncfSetCommandsNum "\(Maximum Interrupt Events\)\s*="
syn match ncfSetCommandsNum "\(Maximum Number of Directory Handles\)\s*="
syn match ncfSetCommandsNum "\(Maximum Number of Internal Directory Handles\)\s*="
syn match ncfSetCommandsNum "\(Maximum Outstanding NCP Searches\)\s*="
syn match ncfSetCommandsNum "\(Maximum Packet Receive Buffers\)\s*="
syn match ncfSetCommandsNum "\(Maximum Physical Receive Packet Size\)\s*="
syn match ncfSetCommandsNum "\(Maximum Record Locks\)\s*="
syn match ncfSetCommandsNum "\(Maximum Record Locks Per Connection\)\s*="
syn match ncfSetCommandsNum "\(Maximum Service Processes\)\s*="
syn match ncfSetCommandsNum "\(Maximum Subdirectory Tree Depth\)\s*="
syn match ncfSetCommandsNum "\(Maximum Transactions\)\s*="
syn match ncfSetCommandsNum "\(Minimum Compression Percentage Gain\)\s*="
syn match ncfSetCommandsNum "\(Minimum Directory Cache Buffers\)\s*="
syn match ncfSetCommandsNum "\(Minimum File Cache Buffers\)\s*="
syn match ncfSetCommandsNum "\(Minimum File Cache Report Threshold\)\s*="
syn match ncfSetCommandsNum "\(Minimum Free Memory for Garbage Collection\)\s*="
syn match ncfSetCommandsNum "\(Minimum Packet Receive Buffers\)\s*="
syn match ncfSetCommandsNum "\(Minimum Service Processes\)\s*="
syn match ncfSetCommandsNum "\(NCP Packet Signature Option\)\s*="
syn match ncfSetCommandsNum "\(NDS Backlink Interval\)\s*="
syn match ncfSetCommandsNum "\(NDS Client NCP Retries\)\s*="
syn match ncfSetCommandsNum "\(NDS External Reference Life Span\)\s*="
syn match ncfSetCommandsNum "\(NDS Inactivity Synchronization Interval\)\s*="
syn match ncfSetCommandsNum "\(NDS Janitor Interval\)\s*="
syn match ncfSetCommandsNum "\(New Service Process Wait Time\)\s*="
syn match ncfSetCommandsNum "\(Number of Frees for Garbage Collection\)\s*="
syn match ncfSetCommandsNum "\(Number of Watchdog Packets\)\s*="
syn match ncfSetCommandsNum "\(Pseudo Preemption Count\)\s*="
syn match ncfSetCommandsNum "\(Read Ahead LRU Sitting Time Threshold\)\s*="
syn match ncfSetCommandsNum "\(Remirror Block Size\)\s*="
syn match ncfSetCommandsNum "\(Reserved Buffers Below 16 Meg\)\s*="
syn match ncfSetCommandsNum "\(Server Log File Overflow Size\)\s*="
syn match ncfSetCommandsNum "\(Server Log File State\)\s*="
syn match ncfSetCommandsNum "\(SMP Polling Count\)\s*="
syn match ncfSetCommandsNum "\(SMP Stack Size\)\s*="
syn match ncfSetCommandsNum "\(TIMESYNC Polling Count\)\s*="
syn match ncfSetCommandsNum "\(TIMESYNC Polling Interval\)\s*="
syn match ncfSetCommandsNum "\(TIMESYNC Synchronization Radius\)\s*="
syn match ncfSetCommandsNum "\(TIMESYNC Write Value\)\s*="
syn match ncfSetCommandsNum "\(Volume Log File Overflow Size\)\s*="
syn match ncfSetCommandsNum "\(Volume Log File State\)\s*="
syn match ncfSetCommandsNum "\(Volume Low Warning Reset Threshold\)\s*="
syn match ncfSetCommandsNum "\(Volume Low Warning Threshold\)\s*="
syn match ncfSetCommandsNum "\(Volume TTS Log File Overflow Size\)\s*="
syn match ncfSetCommandsNum "\(Volume TTS Log File State\)\s*="
syn match ncfSetCommandsNum "\(Worker Thread Execute In a Row Count\)\s*="

" SET Commands that take a Boolean (ON/OFF)

syn match ncfSetCommandsBool "\(Alloc Memory Check Flag\)\s*="
syn match ncfSetCommandsBool "\(Allow Audit Passwords\)\s*="
syn match ncfSetCommandsBool "\(Allow Change to Client Rights\)\s*="
syn match ncfSetCommandsBool "\(Allow Deletion of Active Directories\)\s*="
syn match ncfSetCommandsBool "\(Allow Invalid Pointers\)\s*="
syn match ncfSetCommandsBool "\(Allow LIP\)\s*="
syn match ncfSetCommandsBool "\(Allow Unencrypted Passwords\)\s*="
syn match ncfSetCommandsBool "\(Allow Unowned Files To Be Extended\)\s*="
syn match ncfSetCommandsBool "\(Auto Register Memory Above 16 Megabytes\)\s*="
syn match ncfSetCommandsBool "\(Auto TTS Backout Flag\)\s*="
syn match ncfSetCommandsBool "\(Automatically Repair Bad Volumes\)\s*="
syn match ncfSetCommandsBool "\(Check Equivalent to Me\)\s*="
syn match ncfSetCommandsBool "\(Command Line Prompt Default Choice\)\s*="
syn match ncfSetCommandsBool "\(Console Display Watchdog Logouts\)\s*="
syn match ncfSetCommandsBool "\(Daylight Savings Time Status\)\s*="
syn match ncfSetCommandsBool "\(Developer Option\)\s*="
syn match ncfSetCommandsBool "\(Display Incomplete IPX Packet Alerts\)\s*="
syn match ncfSetCommandsBool "\(Display Lost Interrupt Alerts\)\s*="
syn match ncfSetCommandsBool "\(Display NCP Bad Component Warnings\)\s*="
syn match ncfSetCommandsBool "\(Display NCP Bad Length Warnings\)\s*="
syn match ncfSetCommandsBool "\(Display Old API Names\)\s*="
syn match ncfSetCommandsBool "\(Display Relinquish Control Alerts\)\s*="
syn match ncfSetCommandsBool "\(Display Spurious Interrupt Alerts\)\s*="
syn match ncfSetCommandsBool "\(Enable Deadlock Detection\)\s*="
syn match ncfSetCommandsBool "\(Enable Disk Read After Write Verify\)\s*="
syn match ncfSetCommandsBool "\(Enable File Compression\)\s*="
syn match ncfSetCommandsBool "\(Enable IO Handicap Attribute\)\s*="
syn match ncfSetCommandsBool "\(Enable SECURE.NCF\)\s*="
syn match ncfSetCommandsBool "\(Fast Volume Mounts\)\s*="
syn match ncfSetCommandsBool "\(Global Pseudo Preemption\)\s*="
syn match ncfSetCommandsBool "\(Halt System on Invalid Parameters\)\s*="
syn match ncfSetCommandsBool "\(Ignore Disk Geometry\)\s*="
syn match ncfSetCommandsBool "\(Immediate Purge of Deleted Files\)\s*="
syn match ncfSetCommandsBool "\(NCP File Commit\)\s*="
syn match ncfSetCommandsBool "\(NDS Trace File Length to Zero\)\s*="
syn match ncfSetCommandsBool "\(NDS Trace to File\)\s*="
syn match ncfSetCommandsBool "\(NDS Trace to Screen\)\s*="
syn match ncfSetCommandsBool "\(New Time With Daylight Savings Time Status\)\s*="
syn match ncfSetCommandsBool "\(Read Ahead Enabled\)\s*="
syn match ncfSetCommandsBool "\(Read Fault Emulation\)\s*="
syn match ncfSetCommandsBool "\(Read Fault Notification\)\s*="
syn match ncfSetCommandsBool "\(Reject NCP Packets with Bad Components\)\s*="
syn match ncfSetCommandsBool "\(Reject NCP Packets with Bad Lengths\)\s*="
syn match ncfSetCommandsBool "\(Replace Console Prompt with Server Name\)\s*="
syn match ncfSetCommandsBool "\(Reply to Get Nearest Server\)\s*="
syn match ncfSetCommandsBool "\(SMP Developer Option\)\s*="
syn match ncfSetCommandsBool "\(SMP Flush Processor Cache\)\s*="
syn match ncfSetCommandsBool "\(SMP Intrusive Abend Mode\)\s*="
syn match ncfSetCommandsBool "\(SMP Memory Protection\)\s*="
syn match ncfSetCommandsBool "\(Sound Bell for Alerts\)\s*="
syn match ncfSetCommandsBool "\(TIMESYNC Configured Sources\)\s*="
syn match ncfSetCommandsBool "\(TIMESYNC Directory Tree Mode\)\s*="
syn match ncfSetCommandsBool "\(TIMESYNC Hardware Clock\)\s*="
syn match ncfSetCommandsBool "\(TIMESYNC RESET\)\s*="
syn match ncfSetCommandsBool "\(TIMESYNC Restart Flag\)\s*="
syn match ncfSetCommandsBool "\(TIMESYNC Service Advertising\)\s*="
syn match ncfSetCommandsBool "\(TIMESYNC Write Parameters\)\s*="
syn match ncfSetCommandsBool "\(TTS Abort Dump Flag\)\s*="
syn match ncfSetCommandsBool "\(Upgrade Low Priority Threads\)\s*="
syn match ncfSetCommandsBool "\(Volume Low Warn All Users\)\s*="
syn match ncfSetCommandsBool "\(Write Fault Emulation\)\s*="
syn match ncfSetCommandsBool "\(Write Fault Notification\)\s*="

" Set Commands that take a "string" -- NOT QUOTED

syn match ncfSetCommandsStr "\(Default Time Server Type\)\s*="
syn match ncfSetCommandsStr "\(SMP NetWare Kernel Mode\)\s*="
syn match ncfSetCommandsStr "\(Time Zone\)\s*="
syn match ncfSetCommandsStr "\(TIMESYNC ADD Time Source\)\s*="
syn match ncfSetCommandsStr "\(TIMESYNC REMOVE Time Source\)\s*="
syn match ncfSetCommandsStr "\(TIMESYNC Time Source\)\s*="
syn match ncfSetCommandsStr "\(TIMESYNC Type\)\s*="

" SET Commands that take a "Time"

syn match ncfSetCommandsTime "\(Command Line Prompt Time Out\)\s*="
syn match ncfSetCommandsTime "\(Delay Before First Watchdog Packet\)\s*="
syn match ncfSetCommandsTime "\(Delay Between Watchdog Packets\)\s*="
syn match ncfSetCommandsTime "\(Directory Cache Buffer NonReferenced Delay\)\s*="
syn match ncfSetCommandsTime "\(Dirty Directory Cache Delay Time\)\s*="
syn match ncfSetCommandsTime "\(Dirty Disk Cache Delay Time\)\s*="
syn match ncfSetCommandsTime "\(File Delete Wait Time\)\s*="
syn match ncfSetCommandsTime "\(Minimum File Delete Wait Time\)\s*="
syn match ncfSetCommandsTime "\(Mirrored Devices Are Out of Sync Message Frequency\)\s*="
syn match ncfSetCommandsTime "\(New Packet Receive Buffer Wait Time\)\s*="
syn match ncfSetCommandsTime "\(TTS Backout File Truncation Wait Time\)\s*="
syn match ncfSetCommandsTime "\(TTS UnWritten Cache Wait Time\)\s*="
syn match ncfSetCommandsTime "\(Turbo FAT Re-Use Wait Time\)\s*="
syn match ncfSetCommandsTime "\(Daylight Savings Time Offset\)\s*="

syn match ncfSetCommandsTimeDate "\(End of Daylight Savings Time\)\s*="
syn match ncfSetCommandsTimeDate "\(Start of Daylight Savings Time\)\s*="

syn match ncfSetCommandsBindCon "\(Bindery Context\)\s*=" nextgroup=ncfContString

syn cluster ncfSetCommands contains=ncfSetCommandsNum,ncfSetCommandsBool,ncfSetCommandsStr,ncfSetCommandsTime,ncfSetCommandsTimeDate,ncfSetCommandsBindCon


if exists("ncf_highlight_unknowns")
    syn match Error "[^ \t]*" contains=ALL
endif

if version >= 508 || !exists("did_ncf_syntax_inits")
    if version < 508
	let did_ncf_syntax_inits = 1
	command -nargs=+ HiLink hi link <args>
    else
	command -nargs=+ HiLink hi def link <args>
    endif

    " The default methods for highlighting.  Can be overridden later
    HiLink ncfCommands		Statement
    HiLink ncfSetCommands	ncfCommands
    HiLink ncfLogins		ncfCommands
    HiLink ncfString		String
    HiLink ncfContString	ncfString
    HiLink ncfComment		Comment
    HiLink ncfImplicit		Type
    HiLink ncfBoolean		Boolean
    HiLink ncfScript		Identifier
    HiLink ncfNumber		Number
    HiLink ncfIPAddr		ncfNumber
    HiLink ncfHexNumber		ncfNumber
    HiLink ncfTime		ncfNumber
    HiLink ncfDSTTime		ncfNumber
    HiLink ncfPath		Constant
    HiLink ncfServerName	Special
    HiLink ncfIPXNet		ncfServerName
    HiLink ncfTimeTypes		Constant
    HiLink ncfSetCommandsNum	   ncfSetCommands
    HiLink ncfSetCommandsBool	   ncfSetCommands
    HiLink ncfSetCommandsStr	   ncfSetCommands
    HiLink ncfSetCommandsTime	   ncfSetCommands
    HiLink ncfSetCommandsTimeDate  ncfSetCommands
    HiLink ncfSetCommandsBindCon   ncfSetCommands

    delcommand HiLink

endif

let b:current_syntax = "ncf"
