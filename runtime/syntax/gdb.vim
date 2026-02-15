" Vim syntax file
" Language:		GDB command files
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Claudio Fleiner <claudio@fleiner.com>
" Last Change:		2026 Feb 08
" Contributors:		Simon Sobisch

" WARNING: the group names are NOT stable and may change at any time

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn iskeyword @,48-57,_,128-167,224-235,-

" Include {{{1
" TODO: other languages: ada asm auto c d fortran go local minimal opencl pascal rust unknown
syn include @gdbC syntax/c.vim
unlet b:current_syntax

syn region  gdbExpression contained start="\S" skip="\\$" end="$" contains=@gdbC,gdbLineContinuation transparent

" Commands {{{1

" breakpoints {{{2
syn keyword gdbCommand contained aw[atch] nextgroup=@gdbWatchOption,gdbExpression skipwhite
syn keyword gdbCommand contained b[reak]
syn keyword gdbCommand contained break-[range]
syn keyword gdbCommand contained cat[ch] nextgroup=gdbCatchArgs skipwhite
  syn keyword gdbCatchArgs contained assert catch exception exec fork handlers load rethrow signal syscall throw unload vfork
syn keyword gdbCommand contained cl[ear] cl

syn match    gdbCommand contained "\<comm\%[ands]\>" nextgroup=gdbBreakpointNumber,gdbBreakpointRange skipwhite
  " TODO: move this and generalise to idlist or similar?  Where else are id
  " numbers and ranges used? Breakpoints include catchpoints and watchpoints.
  syn match   gdbBreakpointNumber contained "\<\d\+\>" nextgroup=gdbBreakpointNumber,gdbBreakpointRange skipwhite
  syn match   gdbBreakpointRange contained "\<\d\+-\d\+\>" nextgroup=gdbBreakpointNumber,gdbBreakpointRange skipwhite
  syn cluster gdbBreakpointNumbers contains=gdbBreakpointNumber,gdbBreakpointRange
  syn match   gdbBreakpointCount contained "-\@1<!\<\d\+\>" nextgroup=@gdbBreakpointNumbers skipwhite
  " TODO: better name
  syn keyword gdbCommandsKeyword silent contained
  hi def link gdbCommandsKeyword gdbCommand
syn region  gdbMultilineCommand contained start="\<comm\%[ands]\>" matchgroup=gdbCommand end="^\s*\zsend\ze\s*$" contains=gdbCommand,gdbComment,gdbCommandsKeyword transparent fold

syn keyword gdbCommand contained cond[ition] nextgroup=@gdbConditionOption,gdbConditionBreakpointNumber skipwhite
  syn match   gdbConditionEndOption contained "--"           nextgroup=gdbExpression skipwhite
  syn match   gdbConditionOption    contained "-f\%[orce]\>" nextgroup=gdbConditionEndOption,gdbExpression skipwhite
  syn cluster gdbConditionOption contains=gdbConditionOption,gdbConditionEndOption
  syn match   gdbConditionBreakpointNumber contained "\<\d\+\>" contains=gdbBreakpointNumber nextgroup=gdbExpression skipwhite

syn keyword gdbCommand contained del[ete] del d nextgroup=@gdbBreakpointNumbers,gdbDeleteArgs skipwhite
  syn keyword gdbDeleteArgs contained breakpoints nextgroup=@gdbBreakpointNumbers skipwhite
  syn keyword gdbDeleteArgs contained tracepoints tr nextgroup=@gdbBreakpointNumbers skipwhite
  syn keyword gdbDeleteArgs contained bookmark checkpoint display mem tvariable
syn keyword gdbCommand contained dis[able] disa dis nextgroup=@gdbBreakpointNumbers,gdbDisableArgs skipwhite
  syn keyword gdbDisableArgs contained breakpoints nextgroup=@gdbBreakpointNumbers skipwhite
  syn keyword gdbDisableArgs contained display frame-filter mem pretty-printer probes type-printer unwinder xmethod
syn keyword gdbCommand contained dp[rintf]
syn keyword gdbCommand contained e[nable] en nextgroup=gdbEnableArgs skipwhite
  syn keyword gdbEnableArgs contained display frame-filter mem pretty-printer probes type-printer unwinder xmethod
  syn keyword gdbEnableArgs contained delete once nextgroup=@gdbBreakpointNumbers skipwhite
  syn keyword gdbEnableArgs contained count nextgroup=gdbBreakpointCount skipwhite
  syn keyword gdbEnableArgs contained breakpoints nextgroup=gdbEnableBreakpointArgs,@gdbBreakpointNumbers skipwhite
    syn keyword gdbEnableBreakpointArgs contained count nextgroup=gdbBreakpointCount skipwhite
    syn keyword gdbEnableBreakpointArgs contained delete once nextgroup=@gdbBreakpointNumbers skipwhite
syn keyword gdbCommand contained ft[race]
syn keyword gdbCommand contained hb[reak]
syn keyword gdbCommand contained ig[nore]
syn keyword gdbCommand contained rb[reak]
syn keyword gdbCommand contained rw[atch] nextgroup=@gdbWatchOption,gdbExpression skipwhite
syn keyword gdbCommand contained save nextgroup=gdbSaveArgs skipwhite
  syn keyword gdbSaveArgs contained breakpoints gdb-index tracepoints
syn keyword gdbCommand contained sk[ip] nextgroup=gdbSkipArgs skipwhite
  syn keyword gdbSkipArgs contained delete disable enable file function
syn keyword gdbCommand contained str[ace]
syn keyword gdbCommand contained tb[reak]
syn keyword gdbCommand contained tc[atch]
syn keyword gdbCommand contained tc[atch] nextgroup=gdbCatchArgs skipwhite
syn keyword gdbCommand contained thb[reak]
syn keyword gdbCommand contained tr[ace] tp
syn keyword gdbCommand contained wa[tch] nextgroup=@gdbWatchOption,gdbExpression skipwhite
  syn match   gdbWatchEndOption contained "--"              nextgroup=gdbExpression skipwhite
  syn match   gdbWatchOption    contained "-l\%[ocation]\>" nextgroup=gdbWatchEndOption,gdbExpression skipwhite
  syn cluster gdbWatchOption    contains=gdbWatchOption,gdbWatchEndOption

" data {{{2
syn keyword gdbCommand contained ag[ent-printf] nextgroup=gdbString
syn keyword gdbCommand contained app[end] nextgroup=gdbAppendArgs skipwhite
  syn keyword gdbAppendArgs contained b[inary] nextgroup=gdbAppendBinaryArgs skipwhite
  syn keyword gdbAppendBinaryArgs contained m[emory] v[alue] nextgroup=gdbAppendBinaryArgs skipwhite
  syn keyword gdbAppendArgs contained m[emory] v[alue]
syn keyword gdbCommand contained ca[ll]
syn keyword gdbCommand contained disas[semble]
syn keyword gdbCommand contained disp[lay] nextgroup=gdbFormat skipwhite
syn keyword gdbCommand contained du[mp] nextgroup=gdbDumpArgs skipwhite
  " TODO: share subcommand group
  syn keyword gdbDumpArgs contained b[inary] i[hex] s[rec] t[ekhex] va[lue] ve[rilog] nextgroup=gdbDumpBinaryArgs skipwhite
  syn keyword gdbDumpArgs contained m[emory]
  syn keyword gdbDumpBinaryArgs contained m[emory] v[alue]
syn keyword gdbCommand contained explore nextgroup=gdbExploreArgs skipwhite
  syn keyword gdbExploreArgs contained t[ype] v[alue]
syn keyword gdbCommand contained find
syn keyword gdbCommand contained in[it-if-undefined]
syn keyword gdbCommand contained mem
syn keyword gdbCommand contained memo[ry-tag] nextgroup=gdbMemoryTagArgs skipwhite
  syn keyword gdbMemoryTagArgs contained c[heck]
  syn keyword gdbMemoryTagArgs contained print-a[llocation-tag]
  syn keyword gdbMemoryTagArgs contained print-l[ogical-tag]
  syn keyword gdbMemoryTagArgs contained s[et-allocation-tag]
  syn keyword gdbMemoryTagArgs contained w[ith-logical-tag]
syn keyword gdbCommand contained ou[tput]
syn keyword gdbCommand contained pr[int] ins[pect] p nextgroup=gdbPrintFormat skipwhite
  syn match   gdbPrintFormat contained "/1\=[oxdutfaicsz]\="
syn keyword gdbCommand contained print-[object] po
syn keyword gdbCommand contained printf
syn keyword gdbCommand contained pt[ype]
syn keyword gdbCommand contained resto[re]

" Set command {{{3
syn keyword gdbCommand contained set nextgroup=gdbSetArgs skipwhite

  " Value types {{{4

  " Boolean
  syn keyword gdbSetBooleanValue contained on of[f]

  " Auto-boolean
  syn keyword gdbSetAutoBooleanValue contained on of[f] a[uto]

  " Integer
  syn keyword gdbSetIntegerValue contained unlimited
  syn match   gdbSetIntegerValue contained "[+-]\=\d\+\>"

  " UInteger
  syn keyword gdbSetUIntegerValue contained unlimited
  syn match   gdbSetUIntegerValue contained "\<\d\+\>"

  " ZInteger
  syn match   gdbSetZIntegerValue contained "[+-]\=\d\+\>"

  " ZUInteger
  syn match   gdbSetZUIntegerValue contained "\<\d\+\>"

  " ZUIntegerUnlimited
  syn keyword gdbSetZUIntegerUnlimitedValue contained unlimited
  syn match   gdbSetZUIntegerUnlimitedValue contained "-1\>"
  syn match   gdbSetZUIntegerUnlimitedValue contained "\<\d\+\>"

  " Enum
  syn cluster gdbSetAskBooleanValue contains=gdbSetBooleanValue,gdbSetAskValue
  syn keyword gdbSetAskValue contained a[sk]

  " String
  syn region gdbSetStringValue contained start="\S" skip="\\$" end="\s*$" contains=gdbStringEscape
  " StringNoEscape
  syn region gdbSetStringNoEscapeValue contained start="\S" skip="\\$" end="\s*$"

  " OptionalFilename
  syn match gdbSetOptionalFilenameValue contained "\S\+\%(\s*\S\+\)*"
  " Filename
  syn match gdbSetFilenameValue contained "\S\+\%(\s*\S\+\)*"
  " TODO: better pattern?
  " syn match gdbSetFilenameValue contained "\S.\{-}\ze\%(\s*$\)"
  " syn region gdbSetFilenameValue contained start="\S" skip="\\$" end=\s*$"

  " Subcommands {{{4

  syn keyword gdbSetArgs contained ag[ent] con[firm] ed[iting] ob[server] pa[gination] remotec[ache] remotef[low] ve[rbose] wr[ite] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained hei[ght] wi[dth] nextgroup=gdbSetUIntegerValue skipwhite
  syn keyword gdbSetArgs contained an[notate] compl[aints] wa[tchdog] nextgroup=gdbSetZIntegerValue skipwhite
  syn keyword gdbSetArgs contained remotet[imeout] remotea[ddresssize] nextgroup=gdbSetZUIntegerUnlimitedValue skipwhite
  syn keyword gdbSetArgs contained cha[rset] " [charset]
  syn keyword gdbSetArgs contained end[ian] nextgroup=gdbSetEndianValue skipwhite
    syn keyword gdbSetEndianValue contained auto big little
  syn keyword gdbSetArgs contained dir[ectories] nextgroup=gdbSetOptionalFilenameValue skipwhite
  syn keyword gdbSetArgs contained la[nguage] nextgroup=gdbSetLanguageValue skipwhite
    syn keyword gdbSetLanguageValue contained ada asm auto c d fortran go local minimal modula-2 objective-c opencl pascal rust
    syn keyword gdbSetLanguageValue contained unknown
    syn match   gdbSetLanguageValue contained "\<c++\>"
  syn keyword gdbSetArgs contained arg[s] nextgroup=gdbSetStringValue skipwhite
  syn keyword gdbSetArgs contained cw[d] nextgroup=gdbSetOptionalFilenameValue skipwhite
  " TODO: worth including an architecture value?
  syn keyword gdbSetArgs contained arc[hitecture] proc[essor] nextgroup=gdbArchitecture skipwhite
  syn keyword gdbSetArgs contained env[ironment] " VAR VALUE
  syn keyword gdbSetArgs contained lis[tsize] nextgroup=gdbSetIntegerValue skipwhite
  " TODO: auto as constant?
  syn keyword gdbSetArgs contained gn[utarget] g nextgroup=gdbSetStringNoEscapeValue skipwhite
  syn keyword gdbSetArgs contained rad[ix]
  syn keyword gdbSetArgs contained os[abi] nextgroup=gdbSetOsabiValue skipwhite
    syn keyword gdbSetOsabiValue contained auto default none
  syn keyword gdbSetArgs contained pro[mpt] nextgroup=gdbSetStringValue skipwhite
  syn keyword gdbSetArgs contained remotelogb[ase] nextgroup=gdbSetRemotelogbaseValue skipwhite
    syn keyword gdbSetRemotelogbaseValue contained hex octal ascii
  syn keyword gdbSetArgs contained remotelogf[ile] nextgroup=gdbSetFilenameValue skipwhite
  " TODO: deprecated
  syn keyword gdbSetArgs contained remotew[ritesize]
  syn keyword gdbSetArgs contained vari[able] var " VAR = EXP

  syn keyword gdbSetArgs contained ad[a] nextgroup=gdbSetAdaArgs skipwhite
    syn keyword gdbSetAdaArgs contained p[rint-signatures] nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetAdaArgs contained s[ource-charset] nextgroup=gdbSetAdaSourceCharsetValue skipwhite
      syn keyword gdbSetAdaSourceCharsetValue contained CP437 CP850
      syn match   gdbSetAdaSourceCharsetValue contained "\<ISO-8859-\%([1-5]\|15\)\>"
      syn keyword gdbSetAdaSourceCharsetValue contained UTF-8
    syn keyword gdbSetAdaArgs contained t[rust-PAD-over-XVS] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained arm nextgroup=gdbSetArmArgs skipwhite
    syn keyword gdbSetArmArgs contained apcs32 nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetArmArgs contained abi nextgroup=gdbSetArmAbiValue skipwhite
      syn keyword gdbSetArmAbiValue contained AAPCS APCS auto
    syn keyword gdbSetArmArgs contained disassembler nextgroup=gdbSetArmDisassemblerValue skipwhite
      syn keyword gdbSetArmDisassemblerValue contained apcs atpcs gcc raw special-atpcs std
    syn keyword gdbSetArmArgs contained fpu nextgroup=gdbSetArmFpuValue skipwhite
      syn keyword gdbSetArmFpuValue contained auto fpa softfpa softvfp vfp
    syn keyword gdbSetArmArgs contained fallback-mode nextgroup=gdbSetArmFallbackModeValue skipwhite
      syn keyword gdbSetArmFallbackModeValue contained arm auto thumb
    syn keyword gdbSetArmArgs contained force-mode nextgroup=gdbSetArmForceModeValue skipwhite
      syn keyword gdbSetArmForceModeValue contained arm auto thumb
  syn keyword gdbSetArgs contained bac[ktrace] nextgroup=gdbSetBacktraceArgs skipwhite
    syn keyword gdbSetBacktraceArgs contained l[imit] nextgroup=gdbSetUIntegerValue skipwhite
    syn keyword gdbSetBacktraceArgs contained past-e[ntry] nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetBacktraceArgs contained past-m[ain] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained br[eakpoint] nextgroup=gdbSetBreakpointArgs skipwhite
  syn keyword gdbSetBreakpointArgs contained p[ending] nextgroup=gdbSetAutoBooleanValue skipwhite
  syn keyword gdbSetBreakpointArgs contained al[ways-inserted] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetBreakpointArgs contained au[to-hw] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetBreakpointArgs contained c[ondition-evaluation] nextgroup=gdbSetBreakpointCondtionEvaluationValue skipwhite
   syn keyword gdbSetBreakpointCondtionEvaluationValue contained auto host target
  syn keyword gdbSetArgs contained c[heck] ch c nextgroup=gdbSetCheckArgs skipwhite
    syn keyword gdbSetCheckArgs contained range nextgroup=gdbSetCheckRangeValue skipwhite
    syn keyword gdbSetCheckArgs contained type nextgroup=gdbSetBooleanValue skipwhite
      syn keyword gdbSetCheckRangeValue contained on off warn auto

  syn keyword gdbSetArgs contained dc[ache] nextgroup=gdbSetDcacheArgs skipwhite
  syn keyword gdbSetDcacheArgs contained size nextgroup=gdbSetZUIntegerValue skipwhite
  syn keyword gdbSetDcacheArgs contained line-size nextgroup=gdbSetZUIntegerValue skipwhite
  syn keyword gdbSetArgs contained debugi[nfod] nextgroup=gdbSetDebuginfodArgs skipwhite
    syn keyword gdbSetDebuginfodArgs contained enabled nextgroup=@gdbSetAskBooleanValue skipwhite
    syn keyword gdbSetDebuginfodArgs contained urls nextgroup=gdbSetStringNoEscapeValue skipwhite
    syn keyword gdbSetDebuginfodArgs contained verbose nextgroup=gdbSetZUIntegerValue skipwhite
  syn keyword gdbSetArgs contained for[tran] nextgroup=gdbSetFortranArgs skipwhite
    syn keyword gdbSetFortranArgs contained repack-array-slices nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained gu[ile] gu nextgroup=gdbSetGuileArgs skipwhite
    syn keyword gdbSetGuileArgs contained print-stack nextgroup=gdbSetGuilePrintStackValue skipwhite
      syn keyword gdbSetGuilePrintStackValue contained none full message
  syn keyword gdbSetArgs contained hi[story] nextgroup=gdbSetHistoryArgs skipwhite
    syn keyword gdbSetHistoryArgs contained expansion save nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetHistoryArgs contained filename nextgroup=gdbSetOptionalFilenameValue skipwhite
    syn keyword gdbSetHistoryArgs contained size nextgroup=gdbSetZUIntegerUnlimitedValue skipwhite
    syn keyword gdbSetHistoryArgs contained remove-duplicates nextgroup=gdbSetZUIntegerUnlimitedValue skipwhite
  syn keyword gdbSetArgs contained lo[gging] nextgroup=gdbSetLoggingArgs skipwhite
    syn keyword gdbSetLoggingArgs contained debugredirect enabled overwrite redirect nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetLoggingArgs contained file nextgroup=gdbSetFilenameValue skipwhite
  syn keyword gdbSetArgs contained me[m] nextgroup=gdbSetMemArgs skipwhite
    syn keyword gdbSetMemArgs contained inaccessible-by-default
  syn keyword gdbSetArgs contained mips nextgroup=gdbSetMipsArgs skipwhite
    syn keyword gdbSetMipsArgs contained abi nextgroup=gdbSetMipsAbiValue skipwhite
      syn keyword gdbSetMipsAbiValue contained auto eabi32 eabi64 n32 n64 o32 o64
    syn keyword gdbSetMipsArgs contained compression nextgroup=gdbSetMipsCompressionValue skipwhite
      syn keyword gdbSetMipsCompressionValue contained micromips mips16
    syn keyword gdbSetMipsArgs contained mask-address nextgroup=gdbSetAutoBooleanValue skipwhite
  syn keyword gdbSetArgs contained mipsf[pu] nextgroup=gdbSetMipsfpuValue skipwhite
    syn keyword gdbSetMipsfpuValue contained auto double none single 1 0 yes no on off
  syn keyword gdbSetArgs contained mp[x] nextgroup=gdbSetMpxArgs skipwhite
    syn keyword gdbSetMpxArgs contained bound
  syn keyword gdbSetArgs contained po[werpc] nextgroup=gdbSetPowerpcArgs skipwhite
    syn keyword gdbSetPowerpcArgs contained exact-watchpoints nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetPowerpcArgs contained soft-float nextgroup=gdbSetAutoBooleanValue skipwhite
    syn keyword gdbSetPowerpcArgs contained vector-abi nextgroup=gdbSetPowerpcVectorAbiValue skipwhite
      syn keyword gdbSetPowerpcVectorAbiValue contained altivec auto generic spe
  syn keyword gdbSetArgs contained pri[nt] pr p nextgroup=gdbSetPrintArgs skipwhite
    syn keyword gdbSetPrintArgs contained address demangle finish object pretty union vtbl nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetPrintArgs contained elements repeats nextgroup=gdbSetUIntegerValue skipwhite
    syn keyword gdbSetPrintArgs contained type nextgroup=gdbSetPrintTypeArgs skipwhite
      syn keyword gdbSetPrintTypeArgs contained hex methods typedefs nextgroup=gdbSetBooleanValue skipwhite
      syn keyword gdbSetPrintTypeArgs contained nested-type-limit nextgroup=gdbSetZUIntegerUnlimitedValue skipwhite
    syn keyword gdbSetPrintArgs contained array nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetPrintArgs contained array-indexes nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetPrintArgs contained asm-demangle nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetPrintArgs contained entry-values nextgroup=gdbSetPrintEntryValuesValue skipwhite
      syn keyword gdbSetPrintEntryValuesValue contained both compact default if-needed no only preferred
    syn keyword gdbSetPrintArgs contained frame-arguments nextgroup=gdbSetPrintFrameArgumentsValue skipwhite
      syn keyword gdbSetPrintFrameArgumentsValue contained all none presence scalars
    syn keyword gdbSetPrintArgs contained frame-info nextgroup=gdbSetPrintFrameInfoValue skipwhite
      syn keyword gdbSetPrintFrameInfoValue contained auto location location-and-address short-location source-and-location source-line
    syn keyword gdbSetPrintArgs contained inferior-events nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetPrintArgs contained max-depth nextgroup=gdbSetZUIntegerUnlimitedValue skipwhite
    syn keyword gdbSetPrintArgs contained max-symbolic-offset nextgroup=gdbSetUIntegerValue skipwhite
    syn keyword gdbSetPrintArgs contained memory-tag-violations nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetPrintArgs contained null-stop nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetPrintArgs contained pascal_static-members nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetPrintArgs contained raw-frame-arguments nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetPrintArgs contained raw-values nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetPrintArgs contained sevenbit-strings nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetPrintArgs contained static-members nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetPrintArgs contained symbol nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetPrintArgs contained symbol-filename nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetPrintArgs contained symbol-loading nextgroup=gdbSetSymbolLoadingValue skipwhite
      syn keyword gdbSetSymbolLoadingValue contained brief full off
    syn keyword gdbSetPrintArgs contained thread-events nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained py[thon] nextgroup=gdbSetPythonArgs skipwhite
    syn keyword gdbSetPythonArgs contained dont-write-bytecode nextgroup=gdbSetAutoBooleanValue skipwhite
    syn keyword gdbSetPythonArgs contained ignore-environment
    syn keyword gdbSetPythonArgs contained print-stack nextgroup=gdbSetPythonPrintStackValue skipwhite
      syn keyword gdbSetPythonPrintStackValue contained none full message
  syn keyword gdbSetArgs contained rav[enscar] nextgroup=gdbSetRavenscarArgs skipwhite
    syn keyword gdbSetRavenscarArgs contained task-switching
  syn keyword gdbSetArgs contained rec[ord] rec nextgroup=gdbSetRecordArgs skipwhite
    syn keyword gdbSetRecordArgs contained btrace nextgroup=gdbSetRecordBtraceArgs skipwhite
      syn keyword gdbSetRecordBtraceArgs contained bts nextgroup=gdbSetRecordBtraceBtsArgs skipwhite
        syn keyword gdbSetRecordBtraceBtsArgs contained buffer-size nextgroup=gdbSetUIntegerValue skipwhite
      syn keyword gdbSetRecordBtraceArgs contained cpu nextgroup=gdbSetRecordBtraceCpuArgs skipwhite
        syn keyword gdbSetRecordBtraceCpuArgs contained auto none
      syn keyword gdbSetRecordBtraceArgs contained pt nextgroup=gdbSetRecordBtracePtArgs skipwhite
        syn keyword gdbSetRecordBtracePtArgs contained buffer-size nextgroup=gdbSetUIntegerValue skipwhite
      syn keyword gdbSetRecordBtraceArgs contained replay-memory-access nextgroup=gdbSetRecordBtraceReplayMemoryAccessValue skipwhite
        syn keyword gdbSetRecordBtraceReplayMemoryAccessValue contained read-only read-write
    syn keyword gdbSetRecordArgs contained full nextgroup=gdbSetRecordFullArgs skipwhite
      syn keyword gdbSetRecordFullArgs contained insn-number-max nextgroup=gdbSetUIntegerValue skipwhite
      syn keyword gdbSetRecordFullArgs contained memory-query
      syn keyword gdbSetRecordFullArgs contained stop-at-limit
    syn keyword gdbSetRecordArgs contained function-call-history-size nextgroup=gdbSetUIntegerValue skipwhite
    syn keyword gdbSetRecordArgs contained instruction-history-size nextgroup=gdbSetUIntegerValue skipwhite
  syn keyword gdbSetArgs contained ri[scv] nextgroup=gdbSetRiscvArgs skipwhite
    syn keyword gdbSetRiscvArgs contained use-compressed-breakpoints nextgroup=gdbSetAutoBooleanValue skipwhite
  syn keyword gdbSetArgs contained se[rial] nextgroup=gdbSetSerialArgs skipwhite
    syn keyword gdbSetSerialArgs contained baud nextgroup=gdbSetZIntegerValue skipwhite
    syn keyword gdbSetSerialArgs contained parity nextgroup=gdbSetSerialParityValue skipwhite
      syn keyword gdbSetSerialParityValue contained none odd
  syn keyword gdbSetArgs contained sh nextgroup=gdbSetShArgs skipwhite
    syn keyword gdbSetShArgs contained calling-convention nextgroup=gdbSetShCallingConventionValue skipwhite
      syn keyword gdbSetShCallingConventionValue contained gcc renesas
  syn keyword gdbSetArgs contained sou[rce] nextgroup=gdbSetSourceArgs skipwhite
    syn keyword gdbSetSourceArgs contained open
  syn keyword gdbSetArgs contained sty[le] nextgroup=gdbSetStyleArgs skipwhite
    syn keyword gdbSetStyleArgs contained address nextgroup=gdbSetStyleAddressArgs skipwhite
      syn keyword gdbSetStyleAddressArgs contained background foreground intensity
    syn keyword gdbSetStyleArgs contained disassembler nextgroup=gdbSetStyleDissassemblerArgs skipwhite
      syn keyword gdbSetStyleDissassemblerArgs contained enabled nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetStyleArgs contained enabled nextgroup=gdbSetAutoBooleanValue skipwhite
    syn keyword gdbSetStyleArgs contained filename nextgroup=gdbSetStyleFilenameArgs skipwhite
      syn keyword gdbSetStyleFilenameArgs contained background foreground intensity
    syn keyword gdbSetStyleArgs contained function nextgroup=gdbSetStyleFunctionArgs skipwhite
      syn keyword gdbSetStyleFunctionArgs contained background foreground intensity
    syn keyword gdbSetStyleArgs contained highlight nextgroup=gdbSetStyleHighlightArgs skipwhite
      syn keyword gdbSetStyleHighlightArgs contained background foreground intensity
    syn keyword gdbSetStyleArgs contained metadata nextgroup=gdbSetStyleMetadataArgs skipwhite
      syn keyword gdbSetStyleMetadataArgs contained background foreground intensity
    syn keyword gdbSetStyleArgs contained sources nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetStyleArgs contained title nextgroup=gdbSetStyleTitleArgs skipwhite
      syn keyword gdbSetStyleTitleArgs contained background foreground intensity
    syn keyword gdbSetStyleArgs contained tui-active-border nextgroup=gdbSetStyleTuiActiveBorderArgs skipwhite
      syn keyword gdbSetStyleTuiActiveBorderArgs contained background foreground intensity
    syn keyword gdbSetStyleArgs contained tui-border nextgroup=gdbSetStyleTuiBorderArgs skipwhite
      syn keyword gdbSetStyleTuiBorderArgs contained background foreground intensity
    syn keyword gdbSetStyleArgs contained variable nextgroup=gdbSetStyleVariableArgs skipwhite
      syn keyword gdbSetStyleVariableArgs contained background foreground intensity
    syn keyword gdbSetStyleArgs contained version nextgroup=gdbSetStyleVersionArgs skipwhite
      syn keyword gdbSetStyleVersionArgs contained background foreground intensity
  syn keyword gdbSetArgs contained tc[p] nextgroup=gdbSetTcpArgs skipwhite
    syn keyword gdbSetTcpArgs contained auto-retry nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetTcpArgs contained connect-timeout nextgroup=gdbSetUIntegerValue skipwhite
  syn keyword gdbSetArgs contained td[esc] nextgroup=gdbSetTdescArgs skipwhite
    syn keyword gdbSetTdescArgs contained filename nextgroup=gdbSetFilenameValue skipwhite
  syn keyword gdbSetArgs contained tu[i] nextgroup=gdbSetTuiArgs skipwhite
    syn keyword gdbSetTuiArgs contained active-border-mode
    syn keyword gdbSetTuiArgs contained border-kind nextgroup=gdbSetTuiBorderKindValue skipwhite
      syn keyword gdbSetTuiBorderKindValue contained asc ascii space
    syn keyword gdbSetTuiArgs contained border-mode nextgroup=gdbSetTuiBorderModeValue skipwhite
      syn keyword gdbSetTuiBorderModeValue contained normal standout reverse half half-standout bold bold-standout
    syn keyword gdbSetTuiArgs contained compact-source
    syn keyword gdbSetTuiArgs contained tab-width nextgroup=gdbSetZUIntegerValue skipwhite

  syn keyword gdbSetArgs contained auto-c[onnect-native-target] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained auto-l[oad] nextgroup=gdbSetAutoloadValue,gdbSetAutoloadArgs skipwhite
    syn keyword gdbSetAutoloadValue contained no off 0
    syn keyword gdbSetAutoloadArgs contained gdb-scripts nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetAutoloadArgs contained guile-scripts nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetAutoloadArgs contained libthread-db nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetAutoloadArgs contained local-gdbinit nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetAutoloadArgs contained python-scripts nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetAutoloadArgs contained safe-path nextgroup=gdbSetOptionalFilenameValue skipwhite
    syn keyword gdbSetAutoloadArgs contained scripts-directory nextgroup=gdbSetOptionalFilenameValue skipwhite
  syn keyword gdbSetArgs contained auto-s[olib-add] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained bas[enames-may-differ] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained can[-use-hw-watchpoints] nextgroup=gdbSetZIntegerValue skipwhite
  syn keyword gdbSetArgs contained cas[e-sensitive] nextgroup=gdbSetAutoBooleanValue skipwhite
  syn keyword gdbSetArgs contained ci[rcular-trace-buffer] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained cod[e-cache] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained coe[rce-float-to-double] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained compile-a[rgs] nextgroup=gdbSetStringValue skipwhite
  syn keyword gdbSetArgs contained compile-g[cc] nextgroup=gdbSetOptionalFilenameValue skipwhite
  syn keyword gdbSetArgs contained cp[-abi] nextgroup=gdbSetCpAbiValue skipwhite
    syn keyword gdbSetCpAbiValue contained auto gnu-v2 gnu-v3
  syn keyword gdbSetArgs contained cris-d[warf2-cfi] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained cris-m[ode] nextgroup=gdbSetCrisModeValue skipwhite
    syn keyword gdbSetCrisModeValue contained guru normal
  syn keyword gdbSetArgs contained cris-v[ersion] nextgroup=gdbSetZUIntegerValue skipwhite
  syn keyword gdbSetArgs contained data-directory nextgroup=gdbSetFilenameValue skipwhite
  syn keyword gdbSetArgs contained debug nextgroup=gdbSetDebugArgs skipwhite
    syn keyword gdbSetDebugArgs contained arch bpf expression microblaze mips overload record serial target varobj xtensa nextgroup=gdbSetZUIntegerValue skipwhite
    syn keyword gdbSetDebugArgs contained aarch64 arc arm csky displaced frame infrun hppa jit nios2 notification observer or1k parser nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained riscv nextgroup=gdbSetDebugRiscvArgs skipwhite
      syn keyword gdbSetDebugRiscvArgs contained breakpoints gdbarch infcall unwinder nextgroup=gdbSetZUIntegerValue skipwhite
    syn keyword gdbSetDebugArgs contained skip symfile threads timestamp xml nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained aix-solib nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained auto-load nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained bfd-cache nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained check-physname nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained coff-pe-read nextgroup=gdbSetZUIntegerValue skipwhite
    syn keyword gdbSetDebugArgs contained compile nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained compile-cplus-scopes nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained compile-cplus-types nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained dwarf-die nextgroup=gdbSetZUIntegerValue skipwhite
    syn keyword gdbSetDebugArgs contained dwarf-line nextgroup=gdbSetZUIntegerValue skipwhite
    syn keyword gdbSetDebugArgs contained dwarf-read nextgroup=gdbSetZUIntegerValue skipwhite
    syn keyword gdbSetDebugArgs contained entry-values nextgroup=gdbSetZUIntegerValue skipwhite
    syn keyword gdbSetDebugArgs contained event-loop nextgroup=gdbSetDebugEventLoopValue skipwhite
      syn keyword gdbSetDebugEventLoopValue contained all all-except-ui off
    syn keyword gdbSetDebugArgs contained fortran-array-slicing nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained index-cache nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained libthread-db nextgroup=gdbSetZUIntegerValue skipwhite
    syn keyword gdbSetDebugArgs contained linux-namespaces nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained linux-nat nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained mach-o nextgroup=gdbSetZUIntegerValue skipwhite
    syn keyword gdbSetDebugArgs contained py-breakpoint nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained py-micmd nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained py-unwind nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained remote nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained remote-packet-max-chars nextgroup=gdbSetZUIntegerUnlimitedValue skipwhite
    syn keyword gdbSetDebugArgs contained separate-debug-file nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbSetDebugArgs contained solib-dsbt nextgroup=gdbSetZUIntegerValue skipwhite
    syn keyword gdbSetDebugArgs contained solib-frv nextgroup=gdbSetZUIntegerValue skipwhite
    syn keyword gdbSetDebugArgs contained stap-expression nextgroup=gdbSetZUIntegerValue skipwhite
    syn keyword gdbSetDebugArgs contained symbol-lookup nextgroup=gdbSetZUIntegerValue skipwhite
    syn keyword gdbSetDebugArgs contained symtab-create nextgroup=gdbSetZUIntegerValue skipwhite
  syn keyword gdbSetArgs contained debug-[file-directory] nextgroup=gdbSetOptionalFilenameValue skipwhite
  syn keyword gdbSetArgs contained def[ault-collect] nextgroup=gdbSetStringValue skipwhite
  syn keyword gdbSetArgs contained dem[angle-style] nextgroup=gdbSetDemangleStyleValue skipwhite
    syn keyword gdbSetDemangleStyleValue contained auto dlang gnat gnu-v3 java none rust
  syn keyword gdbSetArgs contained det[ach-on-fork] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained disab[le-randomization] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained disassemble-[next-line] nextgroup=gdbSetAutoBooleanValue skipwhite
  syn keyword gdbSetArgs contained disassembler[-options] nextgroup=gdbSetStringNoEscapeValue skipwhite
  syn keyword gdbSetArgs contained disassembly[-flavor] nextgroup=gdbSetDisassemblyFlavorValue skipwhite
    syn keyword gdbSetDisassemblyFlavorValue contained att intel
  syn keyword gdbSetArgs contained disconnected-d[printf] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained disconnected-t[racing] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained disp[laced-stepping] nextgroup=gdbSetAutoBooleanValue skipwhite
  syn keyword gdbSetArgs contained dprintf-c[hannel] nextgroup=gdbSetStringValue skipwhite
  syn keyword gdbSetArgs contained dprintf-f[unction] nextgroup=gdbSetStringValue skipwhite
  syn keyword gdbSetArgs contained dprintf-s[tyle] nextgroup=gdbSetDprintfStyleValue skipwhite
    syn keyword gdbSetDprintfStyleValue contained agent call gdb
  syn keyword gdbSetArgs contained du[mp-excluded-mappings] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained exec-di[rection] nextgroup=gdbSetExecDirectionValue skipwhite
    syn keyword gdbSetExecDirectionValue contained forward reverse
  syn keyword gdbSetArgs contained exec-do[ne-display] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained exec-f[ile-mismatch] nextgroup=gdbSetExecFileMismatchValue skipwhite
    syn keyword gdbSetExecFileMismatchValue contained ask off warn
  syn keyword gdbSetArgs contained exec-w[rapper] nextgroup=gdbSetFilenameValue skipwhite
  syn keyword gdbSetArgs contained extend[ed-prompt] nextgroup=gdbSetExtendedPromptValue skipwhite
    " TODO: move this?
    syn region gdbSetExtendedPromptValue contained start="\S" skip="\\$" end="\s*$"
      syn match  gdbStringEscape "\\[\\ efnprtvw]" containedin=gdbSetExtendedPromptValue
      syn match  gdbStringEscape "\\[fpt]{[^}]\+}" containedin=gdbSetExtendedPromptValue
      syn match  gdbStringEscape "\\\[[^]]\+]"     containedin=gdbSetExtendedPromptValue
  syn keyword gdbSetArgs contained extens[ion-language] nextgroup=gdbSetStringNoEscapeValue skipwhite
  syn keyword gdbSetArgs contained fi[lename-display] nextgroup=gdbSetFilenameDisplayValue skipwhite
  syn keyword gdbSetFilenameDisplayValue contained absolute basename relative
  syn keyword gdbSetArgs contained follow-e[xec-mode] nextgroup=gdbSetFollowExecModeValue skipwhite
    syn keyword gdbSetFollowExecModeValue contained new same
  syn keyword gdbSetArgs contained follow-f[ork-mode] nextgroup=gdbSetFollowForkModeValue skipwhite
    syn keyword gdbSetFollowForkModeValue contained child parent
  syn keyword gdbSetArgs contained fr[ame-filter] nextgroup=gdbSetFrameFilterArgs skipwhite
    syn keyword gdbSetFrameFilterArgs contained priority nextgroup=gdbSetFrameFilterPriorityValue skipwhite
      syn keyword gdbSetFrameFilterPriorityValue contained global progspace
  syn keyword gdbSetArgs contained ho[st-charset] " [charset]
  syn keyword gdbSetArgs contained heu[ristic-fence-post] nextgroup=gdbSetZIntegerValue skipwhite
  syn keyword gdbSetArgs contained ind[ex-cache] nextgroup=gdbSetIndexCacheArgs skipwhite
    syn keyword gdbSetIndexCacheArgs contained directory nextgroup=gdbSetFilenameValue skipwhite
    syn keyword gdbSetIndexCacheArgs contained enabled nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained inf[erior-tty] nextgroup=gdbSetOptionalFilenameValue skipwhite
  syn keyword gdbSetArgs contained inp[ut-radix]
  syn keyword gdbSetArgs contained int[eractive-mode] nextgroup=gdbSetAutoBooleanValue skipwhite
  syn keyword gdbSetArgs contained lib[thread-db-search-path] nextgroup=gdbSetOptionalFilenameValue skipwhite
  syn keyword gdbSetArgs contained max-c[ompletions] nextgroup=gdbSetZUIntegerUnlimitedValue skipwhite
  syn keyword gdbSetArgs contained max-u[ser-call-depth] nextgroup=gdbSetUIntegerValue skipwhite
  syn keyword gdbSetArgs contained max-v[alue-size] nextgroup=gdbSetZUIntegerUnlimitedValue skipwhite
  syn keyword gdbSetArgs contained may-c[all-functions] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained may-insert-b[reakpoints] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained may-insert-f[ast-tracepoints] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained may-insert-t[racepoints] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained may-int[errupt] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained may-write-m[emory] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained may-write-r[egisters] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained mi-[async] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained mu[ltiple-symbols] nextgroup=gdbSetMultipleSymbolsValue skipwhite
    syn keyword gdbSetMultipleSymbolsValue contained all ask cancel
  syn keyword gdbSetArgs contained no[n-stop] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained op[aque-type-resolution] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained ou[tput-radix]
  syn keyword gdbSetArgs contained ov[erload-resolution] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained ran[ge-stepping] nextgroup=gdbSetBooleanValue skipwhite
  " TODO: remote protocol specific variables?
  syn keyword gdbSetArgs contained remote nextgroup=gdbSetRemoteArgs skipwhite
    syn keyword gdbSetRemoteArgs contained TracepointSource-packet
    syn keyword gdbSetRemoteArgs contained Z-packet nextgroup=gdbSetAutoBooleanValue skipwhite
    syn keyword gdbSetRemoteArgs contained access-watchpoint-packet
    syn keyword gdbSetRemoteArgs contained agent-packet
    syn keyword gdbSetRemoteArgs contained allow-packet
    syn keyword gdbSetRemoteArgs contained attach-packet
    syn keyword gdbSetRemoteArgs contained binary-download-packet
    syn keyword gdbSetRemoteArgs contained X-packet
    syn keyword gdbSetRemoteArgs contained breakpoint-commands-packet
    syn keyword gdbSetRemoteArgs contained btrace-conf-bts-size-packet
    syn keyword gdbSetRemoteArgs contained btrace-conf-pt-size-packet
    syn keyword gdbSetRemoteArgs contained catch-syscalls-packet
    syn keyword gdbSetRemoteArgs contained conditional-breakpoints-packet
    syn keyword gdbSetRemoteArgs contained conditional-tracepoints-packet
    syn keyword gdbSetRemoteArgs contained ctrl-c-packet
    syn keyword gdbSetRemoteArgs contained disable-btrace-packet
    syn keyword gdbSetRemoteArgs contained disable-randomization-packet
    syn keyword gdbSetRemoteArgs contained enable-btrace-bts-packet
    syn keyword gdbSetRemoteArgs contained enable-btrace-pt-packet
    syn keyword gdbSetRemoteArgs contained environment-hex-encoded-packet
    syn keyword gdbSetRemoteArgs contained environment-reset-packet
    syn keyword gdbSetRemoteArgs contained environment-unset-packet
    syn keyword gdbSetRemoteArgs contained exec-event-feature-packet
    syn keyword gdbSetRemoteArgs contained exec-file nextgroup=gdbSetStringNoEscapeValue skipwhite
    syn keyword gdbSetRemoteArgs contained fast-tracepoints-packet
    syn keyword gdbSetRemoteArgs contained fetch-register-packet
    syn keyword gdbSetRemoteArgs contained p-packet
    syn keyword gdbSetRemoteArgs contained fork-event-feature-packet
    syn keyword gdbSetRemoteArgs contained get-thread-information-block-address-packet
    syn keyword gdbSetRemoteArgs contained get-thread-local-storage-address-packet
    syn keyword gdbSetRemoteArgs contained hardware-breakpoint-limit nextgroup=gdbSetZUIntegerUnlimitedValue skipwhite
    syn keyword gdbSetRemoteArgs contained hardware-breakpoint-packet
    syn keyword gdbSetRemoteArgs contained hardware-watchpoint-length-limit nextgroup=gdbSetZUIntegerUnlimitedValue skipwhite
    syn keyword gdbSetRemoteArgs contained hardware-watchpoint-limit nextgroup=gdbSetZUIntegerUnlimitedValue skipwhite
    syn keyword gdbSetRemoteArgs contained hostio-close-packet
    syn keyword gdbSetRemoteArgs contained hostio-fstat-packet
    syn keyword gdbSetRemoteArgs contained hostio-open-packet
    syn keyword gdbSetRemoteArgs contained hostio-pread-packet
    syn keyword gdbSetRemoteArgs contained hostio-pwrite-packet
    syn keyword gdbSetRemoteArgs contained hostio-readlink-packet
    syn keyword gdbSetRemoteArgs contained hostio-setfs-packet
    syn keyword gdbSetRemoteArgs contained hostio-unlink-packet
    syn keyword gdbSetRemoteArgs contained hwbreak-feature-packet
    syn keyword gdbSetRemoteArgs contained install-in-trace-packet
    syn keyword gdbSetRemoteArgs contained interrupt-on-connect
    syn keyword gdbSetRemoteArgs contained interrupt-sequence nextgroup=gdbSetRemoteInterruptSequenceValue skipwhite
      syn keyword gdbSetRemoteInterruptSequenceValue contained BREAK BREAK-g Ctrl-C
    syn keyword gdbSetRemoteArgs contained kill-packet
    syn keyword gdbSetRemoteArgs contained library-info-packet
    syn keyword gdbSetRemoteArgs contained library-info-svr4-packet
    syn keyword gdbSetRemoteArgs contained memory-map-packet
    syn keyword gdbSetRemoteArgs contained memory-read-packet-size
    syn keyword gdbSetRemoteArgs contained memory-tagging-feature-packet
    syn keyword gdbSetRemoteArgs contained memory-write-packet-size
    syn keyword gdbSetRemoteArgs contained multiprocess-feature-packet
    syn keyword gdbSetRemoteArgs contained no-resumed-stop-reply-packet
    syn keyword gdbSetRemoteArgs contained noack-packet
    syn keyword gdbSetRemoteArgs contained osdata-packet
    syn keyword gdbSetRemoteArgs contained pass-signals-packet
    syn keyword gdbSetRemoteArgs contained pid-to-exec-file-packet
    syn keyword gdbSetRemoteArgs contained program-signals-packet
    syn keyword gdbSetRemoteArgs contained query-attached-packet
    syn keyword gdbSetRemoteArgs contained read-aux-vector-packet
    syn keyword gdbSetRemoteArgs contained read-btrace-conf-packet
    syn keyword gdbSetRemoteArgs contained read-btrace-packet
    syn keyword gdbSetRemoteArgs contained read-fdpic-loadmap-packet
    syn keyword gdbSetRemoteArgs contained read-sdata-object-packet
    syn keyword gdbSetRemoteArgs contained read-siginfo-object-packet
    syn keyword gdbSetRemoteArgs contained read-watchpoint-packet
    syn keyword gdbSetRemoteArgs contained reverse-continue-packet
    syn keyword gdbSetRemoteArgs contained reverse-step-packet
    syn keyword gdbSetRemoteArgs contained run-packet
    syn keyword gdbSetRemoteArgs contained search-memory-packet
    syn keyword gdbSetRemoteArgs contained set-register-packet
    syn keyword gdbSetRemoteArgs contained P-packet
    syn keyword gdbSetRemoteArgs contained set-working-dir-packet
    syn keyword gdbSetRemoteArgs contained software-breakpoint-packet
    syn keyword gdbSetRemoteArgs contained startup-with-shell-packet
    syn keyword gdbSetRemoteArgs contained static-tracepoints-packet
    syn keyword gdbSetRemoteArgs contained supported-packets-packet
    syn keyword gdbSetRemoteArgs contained swbreak-feature-packet
    syn keyword gdbSetRemoteArgs contained symbol-lookup-packet
    syn keyword gdbSetRemoteArgs contained system-call-allowed
    syn keyword gdbSetRemoteArgs contained target-features-packet
    syn keyword gdbSetRemoteArgs contained thread-events-packet
    syn keyword gdbSetRemoteArgs contained threads-packet
    syn keyword gdbSetRemoteArgs contained trace-buffer-size-packet
    syn keyword gdbSetRemoteArgs contained trace-status-packet
    syn keyword gdbSetRemoteArgs contained traceframe-info-packet
    syn keyword gdbSetRemoteArgs contained unwind-info-block-packet
    syn keyword gdbSetRemoteArgs contained verbose-resume-packet
    syn keyword gdbSetRemoteArgs contained verbose-resume-supported-packet
    syn keyword gdbSetRemoteArgs contained vfork-event-feature-packet
    syn keyword gdbSetRemoteArgs contained write-siginfo-object-packet
    syn keyword gdbSetRemoteArgs contained write-watchpoint-packet
  syn keyword gdbSetArgs contained remote-[mips64-transfers-32bit-regs] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained schedule-[multiple] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained schedule[r-locking] nextgroup=gdbSetSchedulerLockingValue skipwhite
    syn keyword gdbSetSchedulerLockingValue contained on off replay step
  syn keyword gdbSetArgs contained scr[ipt-extension] nextgroup=gdbSetScriptExtensionValue skipwhite
    syn keyword gdbSetScriptExtensionValue contained off soft strict
  syn keyword gdbSetArgs contained solib-s[earch-path] nextgroup=gdbSetOptionalFilenameValue skipwhite
  syn keyword gdbSetArgs contained stac[k-cache] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained startup-q[uietly] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained startup-w[ith-shell] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained ste[p-mode] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained sto[p-on-solib-events] nextgroup=gdbSetZIntegerValue skipwhite
  syn keyword gdbSetArgs contained str[uct-convention] nextgroup=gdbSetStructConventionValue skipwhite
    syn keyword gdbSetStructConventionValue contained default pcc reg
  syn keyword gdbSetArgs contained sub[stitute-path] nextgroup=gdbSetFilenameValue skipwhite
  syn keyword gdbSetArgs contained sup[press-cli-notifications] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained sy[sroot] solib-a[bsolute-prefix] nextgroup=gdbSetOptionalFilenameValue skipwhite
  syn keyword gdbSetArgs contained target-c[harset] " [charset]
  syn keyword gdbSetArgs contained target-f[ile-system-kind] nextgroup=gdbSetTargetFileSystemKindValue skipwhite
    syn keyword gdbSetTargetFileSystemKindValue contained auto unix dos-based
  syn keyword gdbSetArgs contained target-w[ide-charset] " [charset]
  syn keyword gdbSetArgs contained trace-b[uffer-size] nextgroup=gdbSetZUIntegerUnlimitedValue skipwhite
  syn keyword gdbSetArgs contained trace-c[ommands] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained trace-n[otes] nextgroup=gdbSetStringValue skipwhite
  syn keyword gdbSetArgs contained trace-s[top-notes] nextgroup=gdbSetStringValue skipwhite
  syn keyword gdbSetArgs contained trace-u[ser] nextgroup=gdbSetStringValue skipwhite
  syn keyword gdbSetArgs contained tru[st-readonly-sections] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained unwind-[on-terminating-exception] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained unwindo[nsignal] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained use-c[oredump-filter] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained use-d[eprecated-index-sections] nextgroup=gdbSetBooleanValue skipwhite
  syn keyword gdbSetArgs contained vars[ize-limit] nextgroup=gdbSetZUIntegerUnlimitedValue skipwhite
  " }}}3

syn keyword gdbCommand contained und[isplay]
syn keyword gdbCommand contained wha[tis]
syn match gdbWith contained "\<\%(wit\%[h]\|w\)\>" nextgroup=gdbSetArgs skipwhite
syn region gdbWrappedCommand contained start="\<\%(wit\%[h]\|w\)\>" matchgroup=gdbCommandAnchor end="--" end="$" skip="\\$" transparent contains=gdbWith,gdbLineContinuation nextgroup=gdbCommand skipwhite keepend
syn keyword gdbCommand contained x nextgroup=gdbFormat
syn match   gdbFormat contained "/\%(-\=\d*\)\=[oxdutfaicsz]\=[bhwg]\="
syn match   gdbFormat contained "/\%(-\=\d*\)\=[bhwg]\=[oxdutfaicsz]\="

" files {{{2
syn keyword gdbCommand contained add-symbol-file
syn keyword gdbCommand contained add-symbol-file-[from-memory]
syn keyword gdbCommand contained cd
syn keyword gdbCommand contained co[re-file]
syn keyword gdbCommand contained dir[ectory]
syn keyword gdbCommand contained ed[it]
syn keyword gdbCommand contained exe[c-file]
syn keyword gdbCommand contained fil[e]
syn keyword gdbCommand contained for[ward-search] fo sea[rch]
syn keyword gdbCommand contained ge[nerate-core-file] gc[ore]
syn keyword gdbCommand contained li[st] l
syn keyword gdbCommand contained lo[ad]
syn keyword gdbCommand contained no[sharedlibrary]
syn keyword gdbCommand contained pat[h]
syn keyword gdbCommand contained pw[d]
syn keyword gdbCommand contained remot[e] nextgroup=gdbRemoteArgs skipwhite
  syn keyword gdbRemoteArgs contained d[elete] g[et] p[ut]
syn keyword gdbCommand contained remove-s[ymbol-file]
syn keyword gdbCommand contained reverse-se[arch] rev
syn keyword gdbCommand contained sec[tion]
syn keyword gdbCommand contained sha[redlibrary]
syn keyword gdbCommand contained sy[mbol-file]

" internals {{{2
syn keyword gdbCommand contained mai[ntenance] mt nextgroup=gdbMaintenanceArgs skipwhite
  syn keyword gdbMaintenanceArgs contained agent
  syn keyword gdbMaintenanceArgs contained agent-eval
  syn keyword gdbMaintenanceArgs contained agent-printf
  syn keyword gdbMaintenanceArgs contained btrace nextgroup=gdbMaintenanceBtraceArgs skipwhite
    syn keyword gdbMaintenanceBtraceArgs contained clear clear-packet-history packet-history
  syn keyword gdbMaintenanceArgs contained check nextgroup=gdbMaintenanceCheckArgs skipwhite
    syn keyword gdbMaintenanceCheckArgs contained libthread-db xml-descriptions
  syn keyword gdbMaintenanceArgs contained check-psymtabs
  syn keyword gdbMaintenanceArgs contained check-symtabs
  syn keyword gdbMaintenanceArgs contained cplus cp nextgroup=gdbMaintenanceCplusArgs skipwhite
    syn keyword gdbMaintenanceCplusArgs contained first_component
  syn keyword gdbMaintenanceArgs contained demangler-warning
  syn keyword gdbMaintenanceArgs contained deprecate
  syn keyword gdbMaintenanceArgs contained dump-me
  syn keyword gdbMaintenanceArgs contained expand-symtabs
  syn keyword gdbMaintenanceArgs contained flush nextgroup=gdbMaintenanceFlushArgs skipwhite
    syn keyword gdbMaintenanceFlushArgs contained dcache register-cache source-cache symbol-cache
  syn keyword gdbMaintenanceArgs contained info i nextgroup=gdbMaintenanceInfoArgs skipwhite
    syn keyword gdbMaintenanceInfoArgs contained bfds breakpoints btrace jit line-table program-spaces psymtabs sections selftests
    syn keyword gdbMaintenanceInfoArgs contained symtabs target-sections
  syn keyword gdbMaintenanceArgs contained internal-error
  syn keyword gdbMaintenanceArgs contained internal-warning
  syn keyword gdbMaintenanceArgs contained packet
  syn keyword gdbMaintenanceArgs contained print nextgroup=gdbMaintenancePrintArgs skipwhite
    syn keyword gdbMaintenancePrintArgs contained arc nextgroup=gdbMaintenancePrintArcArgs skipwhite
      syn keyword gdbMaintenancePrintArcArgs contained arc-instruction
    syn keyword gdbMaintenancePrintArgs contained architecture c-tdesc cooked-registers core-file-backed-mappings dummy-frames
    syn keyword gdbMaintenancePrintArgs contained msymbols objfiles psymbols raw-registers reggroups register-groups registers
    syn keyword gdbMaintenancePrintArgs contained remote-registers statistics symbol-cache symbol-cache-statistics symbols
    syn keyword gdbMaintenancePrintArgs contained target-stack type unwind user-registers xml-tdesc
  syn keyword gdbMaintenanceArgs contained selftest
  syn keyword gdbMaintenanceArgs contained set nextgroup=gdbMaintenanceSetArgs skipwhite
    syn keyword gdbMaintenanceSetArgs contained ada nextgroup=gdbMaintenanceSetAdaArgs skipwhite
      syn keyword gdbMaintenanceSetAdaArgs contained ignore-descriptive-types nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained backtrace-on-fatal-signal nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained bfd-sharing nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained btrace nextgroup=gdbMaintenanceSetBtraceArgs skipwhite
      syn keyword gdbMaintenanceSetBtraceArgs contained pt nextgroup=gdbMaintenanceSetBtracePtArgs skipwhite
        syn keyword gdbMaintenanceSetBtracePtArgs contained skip-pad nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained catch-demangler-crashes nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained check-libthread-db nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained demangler-warning nextgroup=gdbMaintenanceSetDemanglerWarningArgs skipwhite
      syn keyword gdbMaintenanceSetDemanglerWarningArgs contained quit nextgroup=@gdbSetAskBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained dwarf nextgroup=gdbMaintenanceSetDwarfArgs skipwhite
      syn keyword gdbMaintenanceSetDwarfArgs contained always-disassemble unwinders nextgroup=gdbSetBooleanValue skipwhite
      syn keyword gdbMaintenanceSetDwarfArgs contained max-cache-age nextgroup=gdbSetZIntegerValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained gnu-source-highlight nextgroup=gdbMaintenanceSetGnuSourceHighlightArgs skipwhite
      syn keyword gdbMaintenanceSetGnuSourceHighlightArgs contained enabled nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained internal-error nextgroup=gdbMaintenanceSetInternalErrorArgs skipwhite
      syn keyword gdbMaintenanceSetInternalErrorArgs contained backtrace nextgroup=gdbSetBooleanValue skipwhite
      syn keyword gdbMaintenanceSetInternalErrorArgs contained corefile quit nextgroup=@gdbSetAskBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained internal-warning nextgroup=gdbMaintenanceSetInternalWarningArgs skipwhite
      syn keyword gdbMaintenanceSetInternalWarningArgs contained backtrace nextgroup=gdbSetBooleanValue skipwhite
      syn keyword gdbMaintenanceSetInternalWarningArgs contained corefile quit nextgroup=@gdbSetAskBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained per-command nextgroup=gdbMaintenanceSetPerCommandArgs skipwhite
      syn keyword gdbMaintenanceSetPerCommandArgs contained space symtab time nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained profile nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained selftest nextgroup=gdbMaintenanceSetSelftestArgs skipwhite
      syn keyword gdbMaintenanceSetSelftestArgs contained verbose nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained show-all-tib nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained show-debug-regs nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained symbol-cache-size nextgroup=gdbSetZUIntegerUnlimitedValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained target-async nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained target-non-stop nextgroup=gdbSetAutoBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained test-settings nextgroup=gdbMaintenanceSetTestSettingsArgs skipwhite
      syn keyword gdbMaintenanceSetTestSettingsArgs contained auto-boolean nextgroup=gdbSetAutoBooleanValue skipwhite
      syn keyword gdbMaintenanceSetTestSettingsArgs contained boolean nextgroup=gdbSetBooleanValue skipwhite
      syn keyword gdbMaintenanceSetTestSettingsArgs contained enum
      syn keyword gdbMaintenanceSetTestSettingsArgs contained filename
      syn keyword gdbMaintenanceSetTestSettingsArgs contained integer nextgroup=gdbSetIntegerValue skipwhite
      syn keyword gdbMaintenanceSetTestSettingsArgs contained optional-filename
      syn keyword gdbMaintenanceSetTestSettingsArgs contained string
      syn keyword gdbMaintenanceSetTestSettingsArgs contained string-noescape
      syn keyword gdbMaintenanceSetTestSettingsArgs contained uinteger nextgroup=gdbSetUIntegerValue skipwhite
      syn keyword gdbMaintenanceSetTestSettingsArgs contained zinteger nextgroup=gdbSetZIntegerValue skipwhite
      syn keyword gdbMaintenanceSetTestSettingsArgs contained zuinteger nextgroup=gdbSetZUIntegerValue skipwhite
      syn keyword gdbMaintenanceSetTestSettingsArgs contained zuinteger-unlimited nextgroup=gdbSetZUIntegerUnlimitedValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained tui-resize-message nextgroup=gdbSetBooleanValue skipwhite
    syn keyword gdbMaintenanceSetArgs contained worker-threads nextgroup=gdbSetZUIntegerUnlimitedValue skipwhite
  syn keyword gdbMaintenanceArgs contained show nextgroup=gdbMaintenanceShowArgs,gdbMaintenanceSetArgs skipwhite
    syn keyword gdbMaintenanceShowArgs contained test-options-completion-result
  syn keyword gdbMaintenanceArgs contained space
  syn keyword gdbMaintenanceArgs contained test-options nextgroup=gdbMaintenanceTestOptionsArgs skipwhite
    syn keyword gdbMaintenanceTestOptionsArgs contained require-delimiter unknown-is-error unknown-is-operand
  syn keyword gdbMaintenanceArgs contained time
  syn keyword gdbMaintenanceArgs contained translate-address
  syn keyword gdbMaintenanceArgs contained undeprecate
  syn keyword gdbMaintenanceArgs contained with

" obscure {{{2
syn keyword gdbCommand contained ch[eckpoint]
syn keyword gdbCommand contained compa[re-sections]

" syn keyword gdbCommand contained compi[le] exp[ression]
" syn keyword gdbCommand contained compi[le] exp[ression] nextgroup=gdbCompileArgs skipwhite
" syn keyword gdbCompile contained compi[le] exp[ression] nextgroup=gdbCompileArgs skipwhite
syn match   gdbCompile contained "\<\%(compi\%[le]\|exp\%[ression]\)\>" nextgroup=gdbCompileArgs skipwhite
  syn keyword gdbCompileArgs contained c[ode] nextgroup=gdbCompileCodeOptions,@gdbC skipwhite
    syn match   gdbCompileCodeOptions contained "--\|\%(-r\%[aw]\)\(\s\+--\)\=" nextgroup=@gdbC skipwhite
  syn keyword gdbCompileArgs contained f[ile] nextgroup=gdbCompileCodeOptions skipwhite
  syn keyword gdbCompileArgs contained p[rint] nextgroup=gdbCompilePrintOptions,gdbCompilePrintFormat,@gdbC skipwhite
    " TODO: proper option support
    syn match   gdbCompilePrintOptions contained "\%(-\w\+\%(\s\+\w\+\)\=\s\+\)*--" nextgroup=@gdbC,gdbCompilePrintFormat skipwhite
    syn match   gdbCompilePrintFormat contained "/[oxdutfaicsz]" nextgroup=@gdbC skipwhite

syn region  gdbCommand contained start="\<\%(compi\%[le]\|exp\%[ression]\)\s\+c\%[ode]\ze\s" skip="\\$" end="$" contains=gdbCompile,@gdbC keepend transparent fold
syn region  gdbMultilineCommand contained start="\<\%(compi\%[le]\|exp\%[ression]\)\s\+c\%[ode]\%(\s\+-r\%[aw]\)\=\%(\s\+--\)\=\s*$" matchgroup=gdbCommand end="^\s*\zsend\ze\s*$" contains=gdbCompile,@gdbC transparent fold
syn region  gdbCommand contained start="\<\%(compi\%[le]\|exp\%[ression]\)\s\+p\%[rint]\ze\s" skip="\\$" end="$" contains=gdbCompile,@gdbC keepend transparent fold
syn region  gdbMultilineCommand contained start="\<\%(compi\%[le]\|exp\%[ression]\)\s\+p\%[rint]\%(\%(\s\+-.*\)\=\s\+--\)\=\%(\s\+/[a-z]\)\=\s*$" matchgroup=gdbCommand end="^\s*\zsend\ze\s*$" contains=gdbCompile,@gdbC transparent fold

syn keyword gdbCommand contained compl[ete]

" Guile {{{3
syn include @gdbGuile syntax/scheme.vim
unlet b:current_syntax
syn keyword gdbCommand contained guile-repl
syn keyword gdbCommand contained gr
syn region  gdbCommand contained matchgroup=gdbCommand start="\<gu\%(ile\)\=\ze\s" skip="\\$" end="$" contains=@gdbGuile keepend transparent fold
syn region  gdbMultilineCommand contained matchgroup=gdbCommand start="\<gu\%(ile\)\=\ze\s*$" end="^\s*\zsend\ze\s*$" contains=@gdbGuile transparent fold

syn keyword gdbCommand contained mo[nitor]

" Python {{{3
syn include @gdbPython syntax/python.vim
unlet b:current_syntax
syn region  gdbCommand contained matchgroup=gdbCommand start="\<py\%(thon\)\=\ze\s" start="\<\%(python-interactive\|pi\)\ze\s" skip="\\$" end="$" contains=@gdbPython keepend transparent fold
syn region  gdbMultilineCommand contained matchgroup=gdbCommand start="\<py\%(thon\)\=\ze\s*$" end="^\s*\zsend\ze\s*$" contains=@gdbPython transparent fold
syn match   gdbCommand contained "\<\%(python-interactive\|pi\)\s*$"
" }}}

syn keyword gdbCommand contained rec[ord] rec nextgroup=gdbRecordArgs skipwhite
  syn keyword gdbRecordArgs contained b[trace] nextgroup=gdbRecordBtraceArgs skipwhite
    syn keyword gdbRecordBtraceArgs contained bts pt
  syn keyword gdbRecordArgs contained bts d[elete] ful[l] pt sa[ve] st[op]
  syn keyword gdbRecordArgs contained ful[l] nextgroup=gdbRecordFullArgs skipwhite
    syn keyword gdbRecordFullArgs contained r[estore]
  syn keyword gdbRecordArgs contained g[oto] nextgroup=gdbRecordGotoArgs skipwhite
    syn keyword gdbRecordGotoArgs contained b[egin] s[tart] e[nd]
  syn keyword gdbRecordArgs contained fun[ction-call-history]
  syn keyword gdbRecordArgs contained instruction-history
syn keyword gdbCommand contained resta[rt]
syn keyword gdbCommand contained sto[p]

" running {{{2
syn keyword gdbCommand contained adv[ance]
syn keyword gdbCommand contained at[tach]
syn keyword gdbCommand contained cont[inue] fg c
syn keyword gdbCommand contained det[ach] nextgroup=gdbDetachArgs skipwhite
  syn keyword gdbDetachArgs contained checkpoint inferiors
syn keyword gdbCommand contained disc[onnect]
syn keyword gdbCommand contained fini[sh] fin
syn keyword gdbCommand contained ha[ndle]
syn keyword gdbCommand contained infe[rior]
syn keyword gdbCommand contained interr[upt]
syn keyword gdbCommand contained ju[mp] j
syn keyword gdbCommand contained k[ill] nextgroup=gdbKillArgs skipwhite
  syn keyword gdbKillArgs contained inferiors
syn keyword gdbCommand contained next n
syn keyword gdbCommand contained nexti ni
syn keyword gdbCommand contained que[ue-signal]
syn keyword gdbCommand contained reverse-c[ontinue] rc
syn keyword gdbCommand contained reverse-f[inish]
syn keyword gdbCommand contained reverse-next rn
syn keyword gdbCommand contained reverse-nexti rni
syn keyword gdbCommand contained reverse-step rs
syn keyword gdbCommand contained reverse-stepi rsi
syn keyword gdbCommand contained ru[n] r
syn keyword gdbCommand contained sig[nal]
syn keyword gdbCommand contained start s
syn keyword gdbCommand contained starti si
syn keyword gdbCommand contained step s
syn keyword gdbCommand contained stepi si
syn keyword gdbCommand contained taa[s]
syn keyword gdbCommand contained tar[get] nextgroup=gdbTargetArgs skipwhite
  syn keyword gdbTargetArgs contained c[ore] e[xec] extended-remote n[ative] record-b[trace] record-c[ore] record-f[ull] rem[ote]
  syn keyword gdbTargetArgs contained t[file]
syn keyword gdbCommand contained tas[k] nextgroup=gdbTaskArgs skipwhite
  syn keyword gdbTaskArgs contained a[pply] nextgroup=gdbTaskApplyArgs skipwhite
    syn keyword gdbTaskApplyArgs contained a[ll]
syn keyword gdbCommand contained tfa[as]
syn keyword gdbCommand contained thr[ead] t nextgroup=gdbThreadArgs skipwhite
  syn keyword gdbThreadArgs contained a[pply] nextgroup=gdbThreadApplyArgs skipwhite
    syn keyword gdbThreadApplyArgs contained a[ll]
  syn keyword gdbThreadArgs contained f[ind] n[ame]
syn keyword gdbCommand contained unt[il] u

" stack {{{2
syn keyword gdbCommand contained ba[cktrace] whe[re] bt
syn keyword gdbCommand contained do[wn]
syn keyword gdbCommand contained fa[as]
syn keyword gdbCommand contained fr[ame] f nextgroup=gdbFrameArgs skipwhite
  syn keyword gdbFrameArgs contained ad[dress] f[unction] l[evel] v[iew]
  syn keyword gdbFrameArgs contained ap[ply] nextgroup=gdbFrameApplyArgs skipwhite
  syn keyword gdbFrameApplyArgs contained a[ll] l[evel]
syn keyword gdbCommand contained ret[urn]
syn keyword gdbCommand contained sel[ect-frame] nextgroup=gdbSelectFrameArgs skipwhite
  syn keyword gdbSelectFrameArgs contained a[ddress] f[unction] l[evel] v[iew]
syn keyword gdbCommand contained up

" status {{{2
syn keyword gdbCommand contained info inf i nextgroup=gdbInfoArgs skipwhite
  syn keyword gdbInfoArgs contained ad[dress] al[l-registers] ar[gs] aux[v] bo[okmarks] br[eakpoints] b ch[eckpoints] cl[asses]
  syn keyword gdbInfoArgs contained com[mon] con[nections] cop[ying] dc[ache] di[splay] exc[eptions] ext[ensions] fi[les] fl[oat]
  syn keyword gdbInfoArgs contained frame-[filter] fu[nctions] gu[ile] gu in[feriors] io[_registers] li[ne] lo[cals] macro macros
  syn keyword gdbInfoArgs contained m[em] modules o[s] pre[tty-printer] prog[ram] rec[ord] rec reg[isters] r sc[ope] sel[ectors]
  syn keyword gdbInfoArgs contained sh[aredlibrary] dll si[gnals] handle sk[ip] source sources stac[k] s
  syn keyword gdbInfoArgs contained stat[ic-tracepoint-markers] sy[mbol] tar[get] tas[ks] te[rminal] th[reads] tp tr[acepoints]
  syn keyword gdbInfoArgs contained tv[ariables] type-[printers] types u[nwinder] va[riables] ve[ctor] vt[bl] war[ranty]
  syn keyword gdbInfoArgs contained wat[chpoints] wi[n] x[method]
  syn keyword gdbInfoArgs contained aut[o-load] nextgroup=gdbInfoAutoLoadArgs skipwhite
    syn keyword gdbInfoAutoLoadArgs contained gd[b-scripts]
    syn keyword gdbInfoAutoLoadArgs contained gu[ile-scripts]
    syn keyword gdbInfoAutoLoadArgs contained li[bthread-db]
    syn keyword gdbInfoAutoLoadArgs contained lo[cal-gdbinit]
    syn keyword gdbInfoAutoLoadArgs contained p[ython-scripts]
  syn keyword gdbInfoArgs contained frame f nextgroup=gdbInfoFrameArgs skipwhite
    syn keyword gdbInfoFrameArgs contained ad[dress] f[unction] l[evel] v[iew]
  syn keyword gdbInfoArgs contained prob[es] nextgroup=gdbInfoProbesArgs skipwhite
    syn keyword gdbInfoProbesArgs contained a[ll] d[trace] s[tap]
  syn keyword gdbInfoArgs contained proc nextgroup=gdbInfoProcArgs skipwhite
    syn keyword gdbInfoProcArgs contained a[ll] cm[dline] cw[d] e[xe] f[iles] m[appings] stat statu[s]
  syn keyword gdbInfoArgs contained module nextgroup=gdbInfoModuleArgs skipwhite
    syn keyword gdbInfoModuleArgs contained f[unctions] v[ariables]
  syn keyword gdbInfoArgs contained set nextgroup=@gdbShowArgs skipwhite
  syn keyword gdbInfoArgs contained w3[2] nextgroup=gdbInfoW32Args skipwhite
    syn keyword gdbInfoW32Args contained thread-information-block tib
syn keyword gdbCommand contained mac[ro] nextgroup=gdbMacroArgs skipwhite
  syn keyword gdbMacroArgs contained d[efine] l[ist] u[ndef]
  syn keyword gdbMacroArgs contained expand exp
  syn keyword gdbMacroArgs contained expand-[once] exp1
" TODO: disallow set values
syn keyword gdbCommand contained sho[w] nextgroup=@gdbShowArgs skipwhite
  syn keyword gdbShowArgs contained commands configuration convenience conv copying paths user values warranty version
  syn keyword gdbShowArgs contained index-cache nextgroup=gdbShowIndexCacheArgs skipwhite
    " stats is only available in a show command
    syn keyword gdbShowIndexCacheArgs contained directory enabled stats
syn cluster gdbShowArgs contains=gdbSetArgs,gdbShowArgs

" support {{{2
syn keyword gdbCommand contained add-auto-load-sa[fe-path] nextgroup=gdbSetOptionalFilenameValue skipwhite
syn keyword gdbCommand contained add-auto-load-sc[ripts-directory] nextgroup=gdbSetOptionalFilenameValue skipwhite
syn keyword gdbCommand contained adi nextgroup=gdbAdiArgs skipwhite
  syn keyword gdbAdiArgs contained a[ssign] e[xamine] x

syn keyword gdbCommand contained al[ias] nextgroup=gdbAliasOption,gdbAliasEndOption,gdbAliasName skipwhite
  syn match   gdbAliasEndOption contained "--"                nextgroup=gdbAliasName skipwhite
  syn match   gdbAliasOption    contained "-a\>"              nextgroup=gdbAliasEndOption,gdbAliasName skipwhite
  syn match   gdbAliasName      contained "\<\w\%(\w\|-\)*\>" nextgroup=gdbAliasEquals skipwhite
  syn match   gdbAliasEquals    contained "="                 nextgroup=@gdbCommands skipwhite

syn keyword gdbCommand contained apr[opos]

syn region  gdbDefine  contained matchgroup=gdbCommand start="\<def\%[ine]\>" end="^\s*\zsend\ze\s*$" contains=TOP transparent fold
syn keyword gdbCommand contained define-[prefix]
syn keyword gdbCommand contained dem[angle]

syn region  gdbDocument contained matchgroup=gdbCommand start="\<doc\%[ument]\>" end="^\s*\zsend\ze\s*$" fold contains=gdbDocumentCommand

syn keyword gdbCommand contained don[t-repeat]
syn keyword gdbCommand contained down-[silently]
syn keyword gdbCommand contained ec[ho] nextgroup=gdbUnquotedString skipwhite
  " TODO: move
  syn region gdbUnquotedString contained start="\S" skip="\\$" end="$" contains=gdbStringEscape,gdbLineContinuation
  hi def link gdbUnquotedString String
  " syn region gdbUnquotedStringNoEscape contained start="\S" skip="\\$" end="$" contains=gdbLineContinuation
  " hi def link gdbUnquotedStringNoEscape String
syn keyword gdbCommand contained he[lp] h

syn region  gdbIf contained matchgroup=gdbCommand start="\<if\>" end="\%(^\s*\)\@<=end\ze\s*$" contains=TOP transparent fold
syn keyword gdbCommand contained else containedin=gdbIf

syn keyword gdbCommand contained interp[reter-exec]
syn keyword gdbCommand contained mak[e]
syn keyword gdbCommand contained new[-ui]
syn keyword gdbCommand contained ov[erlay] ov ovly nextgroup=gdbOverlayArgs skipwhite
  syn keyword gdbOverlayArgs contained a[uto] li[st-overlays] lo[ad-target] man[ual] map[-overlay] o[ff] u[nmap-overlay]
" TODO: pi completes as pipe ignoring pi (python-interactive)
"     : sh region
syn keyword gdbCommand contained pip[e]
syn match   gdbCommand contained "|"
syn keyword gdbCommand contained qui[t] exi[t] q
syn keyword gdbCommand contained she[ll] nextgroup=gdbShellValue skipwhite
syn match   gdbCommand contained "!"     nextgroup=gdbShellValue skipwhite
  syn include @gdbSh syntax/sh.vim
  unlet b:current_syntax
  syn region gdbShellValue contained start="\S" skip="\\$" end="$" contains=@gdbSh,gdbLineContinuation keepend
syn keyword gdbCommand contained so[urce] nextgroup=gdbSourceOption skipwhite
  syn match   gdbSourceOption contained "\<-[sv]\>" nextgroup=gdbSourceOption skipwhite
syn keyword gdbCommand contained up-[silently]

syn region  gdbWhile contained matchgroup=gdbCommand start="\<whi\%[le]\>" end="\%(^\s*\)\@<=end\ze\s*$" contains=TOP transparent fold
syn keyword gdbCommand contained loop_b[reak] loop_c[ontinue] containedin=gdbWhile

" text-user-interface {{{2
syn match   gdbCommand contained "[<>+-]"
syn keyword gdbCommand contained foc[us] fs
syn keyword gdbCommand contained la[yout] nextgroup=gdbLayoutArgs skipwhite
  syn keyword gdbLayoutArgs contained a[sm] n[ext] p[rev] r[egs] sp[lit] sr[c]
syn keyword gdbCommand contained ref[resh]
syn keyword gdbCommand contained tu[i] nextgroup=gdbTuiArgs skipwhite
  syn keyword gdbTuiArgs contained d[isable] e[nable] n[ew-layout] r[eg]
syn keyword gdbCommand contained upd[ate]
syn keyword gdbCommand contained win[height] wh nextgroup=gdbWindowName skipwhite
  syn keyword gdbWindowName contained a[sm] c[md] sr[c] st[atus] r[egs]

" tracepoints {{{2
syn keyword gdbCommand contained ac[tions]
syn keyword gdbCommand contained col[lect]
syn keyword gdbCommand contained end
syn keyword gdbCommand contained pas[scount]
syn keyword gdbCommand contained t[dump]
syn keyword gdbCommand contained tev[al]
syn keyword gdbCommand contained tfi[nd] nextgroup=gdbTfindArgs skipwhite
  syn keyword gdbTfindArgs contained e[nd] l[ine] n[one] o[utside] p[c] r[ange] s[tart] t[racepoint]
syn keyword gdbCommand contained tsa[ve]
syn keyword gdbCommand contained tstar[t]
syn keyword gdbCommand contained tstat[us]
syn keyword gdbCommand contained tsto[p]
syn keyword gdbCommand contained tv[ariable]
syn keyword gdbCommand contained while-stepping stepp[ing] ws

" unclassified {{{2
syn keyword gdbCommand contained add-i[nferior]
syn keyword gdbCommand contained clo[ne-inferior]
syn keyword gdbCommand contained ev[al]
syn keyword gdbCommand contained fl[ash-erase]
syn keyword gdbCommand contained fu[nction]
syn keyword gdbCommand contained jit-reader-l[oad]
syn keyword gdbCommand contained jit-reader-u[nload]
syn keyword gdbCommand contained remove-i[nferiors]
syn keyword gdbCommand contained uns[et] nextgroup=gdbUnsetArgs skipwhite
  syn keyword gdbUnsetArgs contained environment exec-wrapper substitute-path
  syn keyword gdbUnsetArgs contained tdesc nextgroup=gdbUnsetTdescArgs skipwhite
    syn keyword gdbUnsetTdescArgs contained filename
  syn keyword gdbUnsetArgs contained exec-wrapper
  syn keyword gdbUnsetArgs contained substitute-path
syn keyword gdbCommand contained bo[okmark]
syn keyword gdbCommand contained go[to-bookmark]
" }}}

" Command syntax {{{1
syn keyword gdbPrefix contained server nextgroup=gdbCommand skipwhite

syn cluster gdbCommands contains=gdbCommand,gdbMultilineCommand,gdbCompile,gdbDefine,gdbDocument,gdbIf,gdbWhile,gdbPrefix,gdbWrappedCommand

syn match   gdbCommandAnchor "^" nextgroup=@gdbCommands skipwhite
" TODO: give higher priority than \\ in unquoted strings as \\$ matches \ escape of first char on following line
syn match   gdbLineContinuation "\\$"

" Comments {{{1
syn match   gdbComment "^\s*\zs#.*" contains=@Spell

" Variables {{{1
syn match   gdbVariable "\$\K\k*"

" Strings and constants {{{1
syn region  gdbString		start=+"+  skip=+\\\\\|\\"+  end=+"+ contains=gdbStringEscape,@Spell
syn match   gdbStringEscape	contained "\\[abfnrtv\\'" ]"
syn match   gdbStringEscape	contained "\\\o\{1,3}"
syn match   gdbCharacter	"'[^']*'" contains=gdbSpecialChar,gdbSpecialCharError
syn match   gdbCharacter	"'\\''" contains=gdbSpecialChar
syn match   gdbCharacter	"'[^\\]'"
syn match   gdbNumber		"\<[0-9_]\+\>"
syn match   gdbNumber		"\<0x[0-9a-fA-F_]\+\>"

syn match   gdbNumber		"\<0\o\+\>"
syn match   gdbNumber		"\<\d\+\>\.\="
syn match   gdbNumber		"\<0x\x\+\>"

" Architecture {{{2
syn match   gdbArchitecture contained "\<ARC600\>"
syn match   gdbArchitecture contained "\<A6\>"
syn match   gdbArchitecture contained "\<ARC601\>"
syn match   gdbArchitecture contained "\<ARC700\>"
syn match   gdbArchitecture contained "\<A7\>"
syn match   gdbArchitecture contained "\<ARCv2\>"
syn match   gdbArchitecture contained "\<EM\>"
syn match   gdbArchitecture contained "\<HS\>"
syn match   gdbArchitecture contained "\<arm\>"
syn match   gdbArchitecture contained "\<armv2\>"
syn match   gdbArchitecture contained "\<armv2a\>"
syn match   gdbArchitecture contained "\<armv3\>"
syn match   gdbArchitecture contained "\<armv3m\>"
syn match   gdbArchitecture contained "\<armv4\>"
syn match   gdbArchitecture contained "\<armv4t\>"
syn match   gdbArchitecture contained "\<armv5\>"
syn match   gdbArchitecture contained "\<armv5t\>"
syn match   gdbArchitecture contained "\<armv5te\>"
syn match   gdbArchitecture contained "\<xscale\>"
syn match   gdbArchitecture contained "\<ep9312\>"
syn match   gdbArchitecture contained "\<iwmmxt\>"
syn match   gdbArchitecture contained "\<iwmmxt2\>"
syn match   gdbArchitecture contained "\<armv5tej\>"
syn match   gdbArchitecture contained "\<armv6\>"
syn match   gdbArchitecture contained "\<armv6kz\>"
syn match   gdbArchitecture contained "\<armv6t2\>"
syn match   gdbArchitecture contained "\<armv6k\>"
syn match   gdbArchitecture contained "\<armv7\>"
syn match   gdbArchitecture contained "\<armv6-m\>"
syn match   gdbArchitecture contained "\<armv6s-m\>"
syn match   gdbArchitecture contained "\<armv7e-m\>"
syn match   gdbArchitecture contained "\<armv8-a\>"
syn match   gdbArchitecture contained "\<armv8-r\>"
syn match   gdbArchitecture contained "\<armv8-m.base\>"
syn match   gdbArchitecture contained "\<armv8-m.main\>"
syn match   gdbArchitecture contained "\<armv8.1-m.main\>"
syn match   gdbArchitecture contained "\<armv9-a\>"
syn match   gdbArchitecture contained "\<arm_any\>"
syn match   gdbArchitecture contained "\<avr\>"
syn match   gdbArchitecture contained "\<avr:1\>"
syn match   gdbArchitecture contained "\<avr:2\>"
syn match   gdbArchitecture contained "\<avr:25\>"
syn match   gdbArchitecture contained "\<avr:3\>"
syn match   gdbArchitecture contained "\<avr:31\>"
syn match   gdbArchitecture contained "\<avr:35\>"
syn match   gdbArchitecture contained "\<avr:4\>"
syn match   gdbArchitecture contained "\<avr:5\>"
syn match   gdbArchitecture contained "\<avr:51\>"
syn match   gdbArchitecture contained "\<avr:6\>"
syn match   gdbArchitecture contained "\<avr:100\>"
syn match   gdbArchitecture contained "\<avr:101\>"
syn match   gdbArchitecture contained "\<avr:102\>"
syn match   gdbArchitecture contained "\<avr:103\>"
syn match   gdbArchitecture contained "\<avr:104\>"
syn match   gdbArchitecture contained "\<avr:105\>"
syn match   gdbArchitecture contained "\<avr:106\>"
syn match   gdbArchitecture contained "\<avr:107\>"
syn match   gdbArchitecture contained "\<bfin\>"
syn match   gdbArchitecture contained "\<bpf\>"
syn match   gdbArchitecture contained "\<xbpf\>"
syn match   gdbArchitecture contained "\<cris\>"
syn match   gdbArchitecture contained "\<crisv32\>"
syn match   gdbArchitecture contained "\<cris:common_v10_v32\>"
syn match   gdbArchitecture contained "\<csky\>"
syn match   gdbArchitecture contained "\<csky:ck510\>"
syn match   gdbArchitecture contained "\<csky:ck610\>"
syn match   gdbArchitecture contained "\<csky:ck801\>"
syn match   gdbArchitecture contained "\<csky:ck802\>"
syn match   gdbArchitecture contained "\<csky:ck803\>"
syn match   gdbArchitecture contained "\<csky:ck807\>"
syn match   gdbArchitecture contained "\<csky:ck810\>"
syn match   gdbArchitecture contained "\<csky:ck860\>"
syn match   gdbArchitecture contained "\<csky:any\>"
syn match   gdbArchitecture contained "\<frv\>"
syn match   gdbArchitecture contained "\<tomcat\>"
syn match   gdbArchitecture contained "\<simple\>"
syn match   gdbArchitecture contained "\<fr550\>"
syn match   gdbArchitecture contained "\<fr500\>"
syn match   gdbArchitecture contained "\<fr450\>"
syn match   gdbArchitecture contained "\<fr400\>"
syn match   gdbArchitecture contained "\<fr300\>"
syn match   gdbArchitecture contained "\<ft32\>"
syn match   gdbArchitecture contained "\<ft32b\>"
syn match   gdbArchitecture contained "\<h8300\>"
syn match   gdbArchitecture contained "\<h8300h\>"
syn match   gdbArchitecture contained "\<h8300s\>"
syn match   gdbArchitecture contained "\<h8300hn\>"
syn match   gdbArchitecture contained "\<h8300sn\>"
syn match   gdbArchitecture contained "\<h8300sx\>"
syn match   gdbArchitecture contained "\<h8300sxn\>"
syn match   gdbArchitecture contained "\<hppa1.0\>"
syn match   gdbArchitecture contained "\<i386\>"
syn match   gdbArchitecture contained "\<i386:x86-64\>"
syn match   gdbArchitecture contained "\<i386:x64-32\>"
syn match   gdbArchitecture contained "\<i8086\>"
syn match   gdbArchitecture contained "\<i386:intel\>"
syn match   gdbArchitecture contained "\<i386:x86-64:intel\>"
syn match   gdbArchitecture contained "\<i386:x64-32:intel\>"
syn match   gdbArchitecture contained "\<iq2000\>"
syn match   gdbArchitecture contained "\<iq10\>"
syn match   gdbArchitecture contained "\<lm32\>"
syn match   gdbArchitecture contained "\<Loongarch64\>"
syn match   gdbArchitecture contained "\<Loongarch32\>"
syn match   gdbArchitecture contained "\<m16c\>"
syn match   gdbArchitecture contained "\<m32c\>"
syn match   gdbArchitecture contained "\<m32r\>"
syn match   gdbArchitecture contained "\<m32rx\>"
syn match   gdbArchitecture contained "\<m32r2\>"
syn match   gdbArchitecture contained "\<m68hc11\>"
syn match   gdbArchitecture contained "\<m68hc12\>"
syn match   gdbArchitecture contained "\<m68hc12:HCS12\>"
syn match   gdbArchitecture contained "\<m68k\>"
syn match   gdbArchitecture contained "\<m68k:68000\>"
syn match   gdbArchitecture contained "\<m68k:68008\>"
syn match   gdbArchitecture contained "\<m68k:68010\>"
syn match   gdbArchitecture contained "\<m68k:68020\>"
syn match   gdbArchitecture contained "\<m68k:68030\>"
syn match   gdbArchitecture contained "\<m68k:68040\>"
syn match   gdbArchitecture contained "\<m68k:68060\>"
syn match   gdbArchitecture contained "\<m68k:cpu32\>"
syn match   gdbArchitecture contained "\<m68k:fido\>"
syn match   gdbArchitecture contained "\<m68k:isa-a:nodiv\>"
syn match   gdbArchitecture contained "\<m68k:isa-a\>"
syn match   gdbArchitecture contained "\<m68k:isa-a:mac\>"
syn match   gdbArchitecture contained "\<m68k:isa-a:emac\>"
syn match   gdbArchitecture contained "\<m68k:isa-aplus\>"
syn match   gdbArchitecture contained "\<m68k:isa-aplus:mac\>"
syn match   gdbArchitecture contained "\<m68k:isa-aplus:emac\>"
syn match   gdbArchitecture contained "\<m68k:isa-b:nousp\>"
syn match   gdbArchitecture contained "\<m68k:isa-b:nousp:mac\>"
syn match   gdbArchitecture contained "\<m68k:isa-b:nousp:emac\>"
syn match   gdbArchitecture contained "\<m68k:isa-b\>"
syn match   gdbArchitecture contained "\<m68k:isa-b:mac\>"
syn match   gdbArchitecture contained "\<m68k:isa-b:emac\>"
syn match   gdbArchitecture contained "\<m68k:isa-b:float\>"
syn match   gdbArchitecture contained "\<m68k:isa-b:float:mac\>"
syn match   gdbArchitecture contained "\<m68k:isa-b:float:emac\>"
syn match   gdbArchitecture contained "\<m68k:isa-c\>"
syn match   gdbArchitecture contained "\<m68k:isa-c:mac\>"
syn match   gdbArchitecture contained "\<m68k:isa-c:emac\>"
syn match   gdbArchitecture contained "\<m68k:isa-c:nodiv\>"
syn match   gdbArchitecture contained "\<m68k:isa-c:nodiv:mac\>"
syn match   gdbArchitecture contained "\<m68k:isa-c:nodiv:emac\>"
syn match   gdbArchitecture contained "\<m68k:5200\>"
syn match   gdbArchitecture contained "\<m68k:5206e\>"
syn match   gdbArchitecture contained "\<m68k:5307\>"
syn match   gdbArchitecture contained "\<m68k:5407\>"
syn match   gdbArchitecture contained "\<m68k:528x\>"
syn match   gdbArchitecture contained "\<m68k:521x\>"
syn match   gdbArchitecture contained "\<m68k:5249\>"
syn match   gdbArchitecture contained "\<m68k:547x\>"
syn match   gdbArchitecture contained "\<m68k:548x\>"
syn match   gdbArchitecture contained "\<m68k:cfv4e\>"
syn match   gdbArchitecture contained "\<mep\>"
syn match   gdbArchitecture contained "\<h1\>"
syn match   gdbArchitecture contained "\<c5\>"
syn match   gdbArchitecture contained "\<MicroBlaze\>"
syn match   gdbArchitecture contained "\<mn10300\>"
syn match   gdbArchitecture contained "\<am33\>"
syn match   gdbArchitecture contained "\<am33-2\>"
syn match   gdbArchitecture contained "\<moxie\>"
syn match   gdbArchitecture contained "\<msp:14\>"
syn match   gdbArchitecture contained "\<MSP430\>"
syn match   gdbArchitecture contained "\<MSP430x11x1\>"
syn match   gdbArchitecture contained "\<MSP430x12\>"
syn match   gdbArchitecture contained "\<MSP430x13\>"
syn match   gdbArchitecture contained "\<MSP430x14\>"
syn match   gdbArchitecture contained "\<MSP430x15\>"
syn match   gdbArchitecture contained "\<MSP430x16\>"
syn match   gdbArchitecture contained "\<MSP430x20\>"
syn match   gdbArchitecture contained "\<MSP430x21\>"
syn match   gdbArchitecture contained "\<MSP430x22\>"
syn match   gdbArchitecture contained "\<MSP430x23\>"
syn match   gdbArchitecture contained "\<MSP430x24\>"
syn match   gdbArchitecture contained "\<MSP430x26\>"
syn match   gdbArchitecture contained "\<MSP430x31\>"
syn match   gdbArchitecture contained "\<MSP430x32\>"
syn match   gdbArchitecture contained "\<MSP430x33\>"
syn match   gdbArchitecture contained "\<MSP430x41\>"
syn match   gdbArchitecture contained "\<MSP430x42\>"
syn match   gdbArchitecture contained "\<MSP430x43\>"
syn match   gdbArchitecture contained "\<MSP430x44\>"
syn match   gdbArchitecture contained "\<MSP430x46\>"
syn match   gdbArchitecture contained "\<MSP430x47\>"
syn match   gdbArchitecture contained "\<MSP430x54\>"
syn match   gdbArchitecture contained "\<MSP430X\>"
syn match   gdbArchitecture contained "\<n1\>"
syn match   gdbArchitecture contained "\<n1h\>"
syn match   gdbArchitecture contained "\<n1h_v2\>"
syn match   gdbArchitecture contained "\<n1h_v3\>"
syn match   gdbArchitecture contained "\<n1h_v3m\>"
syn match   gdbArchitecture contained "\<nios2\>"
syn match   gdbArchitecture contained "\<nios2:r1\>"
syn match   gdbArchitecture contained "\<nios2:r2\>"
syn match   gdbArchitecture contained "\<or1k\>"
syn match   gdbArchitecture contained "\<or1knd\>"
syn match   gdbArchitecture contained "\<rl78\>"
syn match   gdbArchitecture contained "\<rs6000:6000\>"
syn match   gdbArchitecture contained "\<rs6000:rs1\>"
syn match   gdbArchitecture contained "\<rs6000:rsc\>"
syn match   gdbArchitecture contained "\<rs6000:rs2\>"
syn match   gdbArchitecture contained "\<powerpc:common64\>"
syn match   gdbArchitecture contained "\<powerpc:common\>"
syn match   gdbArchitecture contained "\<powerpc:603\>"
syn match   gdbArchitecture contained "\<powerpc:EC603e\>"
syn match   gdbArchitecture contained "\<powerpc:604\>"
syn match   gdbArchitecture contained "\<powerpc:403\>"
syn match   gdbArchitecture contained "\<powerpc:601\>"
syn match   gdbArchitecture contained "\<powerpc:620\>"
syn match   gdbArchitecture contained "\<powerpc:630\>"
syn match   gdbArchitecture contained "\<powerpc:a35\>"
syn match   gdbArchitecture contained "\<powerpc:rs64ii\>"
syn match   gdbArchitecture contained "\<powerpc:rs64iii\>"
syn match   gdbArchitecture contained "\<powerpc:7400\>"
syn match   gdbArchitecture contained "\<powerpc:e500\>"
syn match   gdbArchitecture contained "\<powerpc:e500mc\>"
syn match   gdbArchitecture contained "\<powerpc:e500mc64\>"
syn match   gdbArchitecture contained "\<powerpc:MPC8XX\>"
syn match   gdbArchitecture contained "\<powerpc:750\>"
syn match   gdbArchitecture contained "\<powerpc:titan\>"
syn match   gdbArchitecture contained "\<powerpc:vle\>"
syn match   gdbArchitecture contained "\<powerpc:e5500\>"
syn match   gdbArchitecture contained "\<powerpc:e6500\>"
syn match   gdbArchitecture contained "\<rx\>"
syn match   gdbArchitecture contained "\<rx:v2\>"
syn match   gdbArchitecture contained "\<rx:v3\>"
syn match   gdbArchitecture contained "\<s12z\>"
syn match   gdbArchitecture contained "\<s390:64-bit\>"
syn match   gdbArchitecture contained "\<s390:31-bit\>"
syn match   gdbArchitecture contained "\<sh\>"
syn match   gdbArchitecture contained "\<sh2\>"
syn match   gdbArchitecture contained "\<sh2e\>"
syn match   gdbArchitecture contained "\<sh-dsp\>"
syn match   gdbArchitecture contained "\<sh3\>"
syn match   gdbArchitecture contained "\<sh3-nommu\>"
syn match   gdbArchitecture contained "\<sh3-dsp\>"
syn match   gdbArchitecture contained "\<sh3e\>"
syn match   gdbArchitecture contained "\<sh4\>"
syn match   gdbArchitecture contained "\<sh4a\>"
syn match   gdbArchitecture contained "\<sh4al-dsp\>"
syn match   gdbArchitecture contained "\<sh4-nofpu\>"
syn match   gdbArchitecture contained "\<sh4-nommu-nofpu\>"
syn match   gdbArchitecture contained "\<sh4a-nofpu\>"
syn match   gdbArchitecture contained "\<sh2a\>"
syn match   gdbArchitecture contained "\<sh2a-nofpu\>"
syn match   gdbArchitecture contained "\<sh2a-nofpu-or-sh4-nommu-nofpu\>"
syn match   gdbArchitecture contained "\<sh2a-nofpu-or-sh3-nommu\>"
syn match   gdbArchitecture contained "\<sh2a-or-sh4\>"
syn match   gdbArchitecture contained "\<sh2a-or-sh3e\>"
syn match   gdbArchitecture contained "\<sparc\>"
syn match   gdbArchitecture contained "\<sparc:sparclet\>"
syn match   gdbArchitecture contained "\<sparc:sparclite\>"
syn match   gdbArchitecture contained "\<sparc:v8plus\>"
syn match   gdbArchitecture contained "\<sparc:v8plusa\>"
syn match   gdbArchitecture contained "\<sparc:sparclite_le\>"
syn match   gdbArchitecture contained "\<sparc:v9\>"
syn match   gdbArchitecture contained "\<sparc:v9a\>"
syn match   gdbArchitecture contained "\<sparc:v8plusb\>"
syn match   gdbArchitecture contained "\<sparc:v9b\>"
syn match   gdbArchitecture contained "\<sparc:v8plusc\>"
syn match   gdbArchitecture contained "\<sparc:v9c\>"
syn match   gdbArchitecture contained "\<sparc:v8plusd\>"
syn match   gdbArchitecture contained "\<sparc:v9d\>"
syn match   gdbArchitecture contained "\<sparc:v8pluse\>"
syn match   gdbArchitecture contained "\<sparc:v9e\>"
syn match   gdbArchitecture contained "\<sparc:v8plusv\>"
syn match   gdbArchitecture contained "\<sparc:v9v\>"
syn match   gdbArchitecture contained "\<sparc:v8plusm\>"
syn match   gdbArchitecture contained "\<sparc:v9m\>"
syn match   gdbArchitecture contained "\<sparc:v8plusm8\>"
syn match   gdbArchitecture contained "\<sparc:v9m8\>"
syn match   gdbArchitecture contained "\<tic6x\>"
syn match   gdbArchitecture contained "\<tilegx\>"
syn match   gdbArchitecture contained "\<tilegx32\>"
syn match   gdbArchitecture contained "\<v850:old-gcc-abi\>"
syn match   gdbArchitecture contained "\<v850e3v5:old-gcc-abi\>"
syn match   gdbArchitecture contained "\<v850e2v4:old-gcc-abi\>"
syn match   gdbArchitecture contained "\<v850e2v3:old-gcc-abi\>"
syn match   gdbArchitecture contained "\<v850e2:old-gcc-abi\>"
syn match   gdbArchitecture contained "\<v850e1:old-gcc-abi\>"
syn match   gdbArchitecture contained "\<v850e:old-gcc-abi\>"
syn match   gdbArchitecture contained "\<v850:rh850\>"
syn match   gdbArchitecture contained "\<v850e3v5\>"
syn match   gdbArchitecture contained "\<v850e2v4\>"
syn match   gdbArchitecture contained "\<v850e2v3\>"
syn match   gdbArchitecture contained "\<v850e2\>"
syn match   gdbArchitecture contained "\<v850e1\>"
syn match   gdbArchitecture contained "\<v850e\>"
syn match   gdbArchitecture contained "\<v850-rh850\>"
syn match   gdbArchitecture contained "\<vax\>"
syn match   gdbArchitecture contained "\<xstormy16\>"
syn match   gdbArchitecture contained "\<xtensa\>"
syn match   gdbArchitecture contained "\<z80\>"
syn match   gdbArchitecture contained "\<z80-strict\>"
syn match   gdbArchitecture contained "\<z80-full\>"
syn match   gdbArchitecture contained "\<r800\>"
syn match   gdbArchitecture contained "\<gbz80\>"
syn match   gdbArchitecture contained "\<z180\>"
syn match   gdbArchitecture contained "\<z80n\>"
syn match   gdbArchitecture contained "\<ez80-z80\>"
syn match   gdbArchitecture contained "\<ez80-adl\>"
syn match   gdbArchitecture contained "\<aarch64\>"
syn match   gdbArchitecture contained "\<aarch64:ilp32\>"
syn match   gdbArchitecture contained "\<aarch64:armv8-r\>"
syn match   gdbArchitecture contained "\<alpha\>"
syn match   gdbArchitecture contained "\<alpha:ev4\>"
syn match   gdbArchitecture contained "\<alpha:ev5\>"
syn match   gdbArchitecture contained "\<alpha:ev6\>"
syn match   gdbArchitecture contained "\<ia64-elf64\>"
syn match   gdbArchitecture contained "\<ia64-elf32\>"
syn match   gdbArchitecture contained "\<mips\>"
syn match   gdbArchitecture contained "\<mips:3000\>"
syn match   gdbArchitecture contained "\<mips:3900\>"
syn match   gdbArchitecture contained "\<mips:4000\>"
syn match   gdbArchitecture contained "\<mips:4010\>"
syn match   gdbArchitecture contained "\<mips:4100\>"
syn match   gdbArchitecture contained "\<mips:4111\>"
syn match   gdbArchitecture contained "\<mips:4120\>"
syn match   gdbArchitecture contained "\<mips:4300\>"
syn match   gdbArchitecture contained "\<mips:4400\>"
syn match   gdbArchitecture contained "\<mips:4600\>"
syn match   gdbArchitecture contained "\<mips:4650\>"
syn match   gdbArchitecture contained "\<mips:5000\>"
syn match   gdbArchitecture contained "\<mips:5400\>"
syn match   gdbArchitecture contained "\<mips:5500\>"
syn match   gdbArchitecture contained "\<mips:5900\>"
syn match   gdbArchitecture contained "\<mips:6000\>"
syn match   gdbArchitecture contained "\<mips:7000\>"
syn match   gdbArchitecture contained "\<mips:8000\>"
syn match   gdbArchitecture contained "\<mips:9000\>"
syn match   gdbArchitecture contained "\<mips:10000\>"
syn match   gdbArchitecture contained "\<mips:12000\>"
syn match   gdbArchitecture contained "\<mips:14000\>"
syn match   gdbArchitecture contained "\<mips:16000\>"
syn match   gdbArchitecture contained "\<mips:16\>"
syn match   gdbArchitecture contained "\<mips:mips5\>"
syn match   gdbArchitecture contained "\<mips:isa32\>"
syn match   gdbArchitecture contained "\<mips:isa32r2\>"
syn match   gdbArchitecture contained "\<mips:isa32r3\>"
syn match   gdbArchitecture contained "\<mips:isa32r5\>"
syn match   gdbArchitecture contained "\<mips:isa32r6\>"
syn match   gdbArchitecture contained "\<mips:isa64\>"
syn match   gdbArchitecture contained "\<mips:isa64r2\>"
syn match   gdbArchitecture contained "\<mips:isa64r3\>"
syn match   gdbArchitecture contained "\<mips:isa64r5\>"
syn match   gdbArchitecture contained "\<mips:isa64r6\>"
syn match   gdbArchitecture contained "\<mips:sb1\>"
syn match   gdbArchitecture contained "\<mips:loongson_2e\>"
syn match   gdbArchitecture contained "\<mips:loongson_2f\>"
syn match   gdbArchitecture contained "\<mips:gs464\>"
syn match   gdbArchitecture contained "\<mips:gs464e\>"
syn match   gdbArchitecture contained "\<mips:gs264e\>"
syn match   gdbArchitecture contained "\<mips:octeon\>"
syn match   gdbArchitecture contained "\<mips:octeon+\>"
syn match   gdbArchitecture contained "\<mips:octeon2\>"
syn match   gdbArchitecture contained "\<mips:octeon3\>"
syn match   gdbArchitecture contained "\<mips:xlr\>"
syn match   gdbArchitecture contained "\<mips:interaptiv-mr2\>"
syn match   gdbArchitecture contained "\<mips:micromips\>"
syn match   gdbArchitecture contained "\<riscv\>"
syn match   gdbArchitecture contained "\<riscv:rv64\>"
syn match   gdbArchitecture contained "\<riscv:rv32\>"

" Sync {{{1
exec "syn sync minlines=" .. get(g:, "gdb_minlines", 100)
exec "syn sync maxlines=" .. get(g:, "gdb_minlines", 200)
syn sync ccomment gdbComment
syn sync linecont "\\$"

" Default Highlighting {{{1
" Only when an item doesn't have highlighting yet
hi def link gdbCompile		gdbCommand
hi def link gdbFuncDef		Function
hi def link gdbComment		Comment
hi def link gdbCommand		Statement
hi def link gdbPrefix		gdbCommand
hi def link gdbString		String
hi def link gdbStringEscape	SpecialChar
hi def link gdbCharacter	Character
hi def link gdbVariable		Identifier
hi def link gdbWith		gdbCommand

" Command options {{{2
hi def link gdbFormat				Special
hi def link gdbPrintFormat			gdbFormat
hi def link gdbOption				Special
hi def link gdbCompileCodeOptions		gdbOption
hi def link gdbCompilePrintOptions		gdbOption
hi def link gdbCompilePrintFormat		gdbFormat

" Subcommands {{{2
hi def link gdbCommandArgs				Type
hi def link gdbAdiArgs					gdbCommandArgs
hi def link gdbAliasOption				gdbCommandArgs
hi def link gdbAliasEndOption				gdbCommandArgs
hi def link gdbAppendArgs				gdbCommandArgs
hi def link gdbAppendBinaryArgs				gdbAppendArgs
hi def link gdbCatchArgs				gdbCommandArgs
hi def link gdbCompileArgs				gdbCommandArgs
hi def link gdbConditionOption				gdbCommandArgs
hi def link gdbConditionEndOption			gdbCommandArgs
hi def link gdbDeleteArgs				gdbCommandArgs
hi def link gdbDetachArgs				gdbCommandArgs
hi def link gdbDisableArgs				gdbCommandArgs
hi def link gdbDumpArgs					gdbCommandArgs
hi def link gdbDumpBinaryArgs				gdbDumpArgs
hi def link gdbEnableArgs				gdbCommandArgs
hi def link gdbEnableBreakpointArgs			gdbEnableArgs
hi def link gdbExploreArgs				gdbCommandArgs
hi def link gdbFrameArgs				gdbCommandArgs
hi def link gdbFrameApplyArgs				gdbCommandArgs
hi def link gdbInfoArgs					gdbCommandArgs
hi def link gdbInfoAutoLoadArgs				gdbInfoArgs
hi def link gdbInfoFrameArgs				gdbInfoArgs
hi def link gdbInfoModuleArgs				gdbInfoArgs
hi def link gdbInfoProbesArgs				gdbInfoArgs
hi def link gdbInfoProcArgs				gdbInfoArgs
hi def link gdbInfoW32Args				gdbInfoArgs
hi def link gdbKillArgs					gdbCommandArgs
hi def link gdbLayoutArgs				gdbCommandArgs
hi def link gdbMacroArgs				gdbCommandArgs
hi def link gdbMaintenanceArgs				gdbCommandArgs
hi def link gdbMaintenanceBtraceArgs			gdbCommandArgs
hi def link gdbMaintenanceCheckArgs			gdbCommandArgs
hi def link gdbMaintenanceCplusArgs			gdbCommandArgs
hi def link gdbMaintenanceFlushArgs			gdbCommandArgs
hi def link gdbMaintenanceInfoArgs			gdbCommandArgs
hi def link gdbMaintenancePrintArgs			gdbCommandArgs
hi def link gdbMaintenancePrintArcArgs			gdbCommandArgs
hi def link gdbMaintenanceSetArgs			gdbCommandArgs
hi def link gdbMaintenanceSetAdaArgs			gdbCommandArgs
hi def link gdbMaintenanceSetBtraceArgs			gdbCommandArgs
hi def link gdbMaintenanceSetBtracePtArgs		gdbCommandArgs
hi def link gdbMaintenanceSetDemanglerWarningArgs	gdbCommandArgs
hi def link gdbMaintenanceSetDwarfArgs			gdbCommandArgs
hi def link gdbMaintenanceSetGnuSourceHighlightArgs	gdbCommandArgs
hi def link gdbMaintenanceSetInternalErrorArgs		gdbCommandArgs
hi def link gdbMaintenanceSetInternalErrorArgs		gdbCommandArgs
hi def link gdbMaintenanceSetInternalWarningArgs	gdbCommandArgs
hi def link gdbMaintenanceSetPerCommandArgs		gdbCommandArgs
hi def link gdbMaintenanceSetSelftestArgs		gdbCommandArgs
hi def link gdbMaintenanceSetTestSettingsArgs		gdbCommandArgs
hi def link gdbMaintenanceShowArgs			gdbCommandArgs
hi def link gdbMaintenanceTestOptionsArgs		gdbCommandArgs
hi def link gdbMemoryTagArgs				gdbCommandArgs
hi def link gdbOverlayArgs				gdbCommandArgs
hi def link gdbRecordArgs				gdbCommandArgs
hi def link gdbRecordBtraceArgs				gdbRecordArgs
hi def link gdbRecordGotoArgs				gdbRecordArgs
hi def link gdbRecordFullArgs				gdbRecordArgs
hi def link gdbRemoteArgs				gdbCommandArgs
hi def link gdbSaveArgs					gdbCommandArgs
hi def link gdbSelectFrameArgs				gdbCommandArgs
hi def link gdbSkipArgs					gdbCommandArgs
hi def link gdbSetArgs					gdbCommandArgs
hi def link gdbSetAdaArgs				gdbCommandArgs
hi def link gdbSetArmArgs				gdbCommandArgs
hi def link gdbSetAutoloadArgs				gdbCommandArgs
hi def link gdbSetBacktraceArgs				gdbCommandArgs
hi def link gdbSetBreakpointArgs			gdbCommandArgs
hi def link gdbSetCheckArgs				gdbCommandArgs
hi def link gdbSetDcacheArgs				gdbCommandArgs
hi def link gdbSetDebugArgs				gdbCommandArgs
hi def link gdbSetDebuginfodArgs			gdbCommandArgs
hi def link gdbSetDebugRiscvArgs			gdbCommandArgs
hi def link gdbSetFortranArgs				gdbCommandArgs
hi def link gdbSetFrameFilterArgs			gdbCommandArgs
hi def link gdbSetGuileArgs				gdbCommandArgs
hi def link gdbSetHistoryArgs				gdbCommandArgs
hi def link gdbSetIndexCacheArgs			gdbCommandArgs
hi def link gdbSetLoggingArgs				gdbCommandArgs
hi def link gdbSetMemArgs				gdbCommandArgs
hi def link gdbSetMipsArgs				gdbCommandArgs
hi def link gdbSetMpxArgs				gdbCommandArgs
hi def link gdbSetPowerpcArgs				gdbCommandArgs
hi def link gdbSetPrintArgs				gdbCommandArgs
hi def link gdbSetPrintTypeArgs				gdbSetPrintArgs
hi def link gdbSetPythonArgs				gdbCommandArgs
hi def link gdbSetRavenscarArgs				gdbCommandArgs
hi def link gdbSetRecordArgs				gdbCommandArgs
hi def link gdbSetRecordBtraceArgs			gdbSetRecordArgs
hi def link gdbSetRecordBtraceBtsArgs			gdbSetRecordBtraceArgs
hi def link gdbSetRecordBtraceCpuArgs			gdbSetRecordBtraceArgs
hi def link gdbSetRecordFullArgs			gdbSetRecordArgs
hi def link gdbSetRecordBtracePtArgs			gdbSetRecordBtraceArgs
hi def link gdbSetRemoteArgs				gdbCommandArgs
hi def link gdbSetRiscvArgs				gdbCommandArgs
hi def link gdbSetSerialArgs				gdbCommandArgs
hi def link gdbSetShArgs				gdbCommandArgs
hi def link gdbSetSourceArgs				gdbCommandArgs
hi def link gdbSetStyleArgs				gdbCommandArgs
hi def link gdbSetStyleAddressArgs			gdbSetStyleArgs
hi def link gdbSetStyleDissassemblerArgs		gdbSetStyleArgs
hi def link gdbSetStyleFilenameArgs			gdbSetStyleArgs
hi def link gdbSetStyleFunctionArgs			gdbSetStyleArgs
hi def link gdbSetStyleHighlightArgs			gdbSetStyleArgs
hi def link gdbSetStyleMetadataArgs			gdbSetStyleArgs
hi def link gdbSetStyleTitleArgs			gdbSetStyleArgs
hi def link gdbSetStyleTuiActiveBorderArgs		gdbSetStyleArgs
hi def link gdbSetStyleTuiBorderArgs			gdbSetStyleArgs
hi def link gdbSetStyleVariableArgs			gdbSetStyleArgs
hi def link gdbSetStyleVersionArgs			gdbSetStyleArgs
hi def link gdbSetTuiArgs				gdbCommandArgs
hi def link gdbSetTcpArgs				gdbCommandArgs
hi def link gdbSetTdescArgs				gdbCommandArgs
hi def link gdbShowArgs					gdbCommandArgs
hi def link gdbShowIndexCacheArgs			gdbCommandArgs
" TODO: dedicated option highlight group?
hi def link gdbSourceOption				gdbCommandArgs
hi def link gdbTaskArgs					gdbCommandArgs
hi def link gdbTaskApplyArgs				gdbTaskArgs
hi def link gdbTargetArgs				gdbCommandArgs
hi def link gdbTfindArgs				gdbCommandArgs
hi def link gdbThreadArgs				gdbCommandArgs
hi def link gdbThreadApplyArgs				gdbThreadArgs
hi def link gdbTuiArgs					gdbCommandArgs
hi def link gdbUnsetArgs				gdbCommandArgs
hi def link gdbUnsetTdescArgs				gdbUnsetArgs
hi def link gdbWatchOption				gdbCommandArgs
hi def link gdbWatchEndOption				gdbCommandArgs

" Set values {{{2
hi def link gdbSetValue				Constant
hi def link gdbSetAskValue			gdbSetValue
hi def link gdbSetAutoBooleanValue		gdbSetValue
hi def link gdbSetBooleanValue			gdbSetValue
hi def link gdbSetIntegerValue			gdbSetValue
hi def link gdbSetUIntegerValue			gdbSetValue
hi def link gdbSetZIntegerValue			gdbSetValue
hi def link gdbSetZUIntegerValue		gdbSetValue
hi def link gdbSetZUIntegerUnlimitedValue	gdbSetValue
hi def link gdbSetFilenameValue			gdbSetValue
hi def link gdbSetOptionalFilenameValue		gdbSetValue
hi def link gdbSetStringValue			gdbString
hi def link gdbSetStringNoEscapeValue		gdbString
hi def link gdbSetExtendedPromptValue		gdbString

" Enum values {{{3
hi def link gdbSetAdaSourceCharsetValue		      gdbSetValue
hi def link gdbSetArmAbiValue			      gdbSetValue
hi def link gdbSetArmDisassemblerValue		      gdbSetValue
hi def link gdbSetArmFallbackModeValue		      gdbSetValue
hi def link gdbSetArmForceModeValue		      gdbSetValue
hi def link gdbSetArmFpuValue			      gdbSetValue
hi def link gdbSetAutoloadValue			      gdbSetValue
hi def link gdbSetBreakpointCondtionEvaluationValue   gdbSetValue
hi def link gdbSetCheckRangeValue		      gdbSetValue
hi def link gdbSetCpAbiValue			      gdbSetValue
hi def link gdbSetCrisModeValue			      gdbSetValue
hi def link gdbSetDebugEventLoopValue		      gdbSetValue
hi def link gdbSetDemangleStyleValue		      gdbSetValue
hi def link gdbSetDisassemblyFlavorValue	      gdbSetValue
hi def link gdbSetDprintfStyleValue		      gdbSetValue
hi def link gdbSetEndianValue			      gdbSetValue
hi def link gdbSetExecDirectionValue		      gdbSetValue
hi def link gdbSetExecFileMismatchValue		      gdbSetValue
hi def link gdbSetFilenameDisplayValue		      gdbSetValue
hi def link gdbSetFollowExecModeValue		      gdbSetValue
hi def link gdbSetFollowForkModeValue		      gdbSetValue
hi def link gdbSetFrameFilterPriorityValue	      gdbSetValue
hi def link gdbSetGuilePrintStackValue		      gdbSetValue
hi def link gdbSetLanguageValue			      gdbSetValue
hi def link gdbSetMipsAbiValue			      gdbSetValue
hi def link gdbSetMipsCompressionValue		      gdbSetValue
hi def link gdbSetMipsfpuValue			      gdbSetValue
hi def link gdbSetMultipleSymbolsValue		      gdbSetValue
hi def link gdbSetOsabiValue			      gdbSetValue
hi def link gdbSetPowerpcVectorAbiValue		      gdbSetValue
hi def link gdbSetPrintEntryValuesValue		      gdbSetValue
hi def link gdbSetPrintFrameArgumentsValue	      gdbSetValue
hi def link gdbSetPrintFrameInfoValue		      gdbSetValue
hi def link gdbSetPythonPrintStackValue		      gdbSetValue
hi def link gdbSetRecordBtraceReplayMemoryAccessValue gdbSetValue
hi def link gdbSetRemoteInterruptSequenceValue	      gdbSetValue
hi def link gdbSetRemotelogbaseValue		      gdbSetValue
hi def link gdbSetSchedulerLockingValue		      gdbSetValue
hi def link gdbSetScriptExtensionValue		      gdbSetValue
hi def link gdbSetSerialParityValue		      gdbSetValue
hi def link gdbSetShCallingConventionValue	      gdbSetValue
hi def link gdbSetStructConventionValue		      gdbSetValue
hi def link gdbSetSymbolLoadingValue		      gdbSetValue
hi def link gdbSetTargetFileSystemKindValue	      gdbSetValue
hi def link gdbSetTuiBorderKindValue		      gdbSetValue
hi def link gdbSetTuiBorderModeValue		      gdbSetValue
" }}}2

hi def link gdbAliasName	Function
hi def link gdbArchitecture	Constant
hi def link gdbWindowName	Constant
hi def link gdbBreakpointCount	Number
hi def link gdbBreakpointNumber	Constant
hi def link gdbBreakpointRange	Constant

hi def link gdbDocument		Special
hi def link gdbNumber		Number
hi def link gdbLineContinuation	Special
" }}}

let b:current_syntax = "gdb"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet fdm=marker:
