" Vim syntax file
" Language:	Fortran 2023 (and Fortran 2018, 2008, 2003, 95, 90, and 77)
" Version:	(v109) 2023 December 29
" Maintainers:	Ajit J. Thakkar <ajit@unb.ca>; <https://ajit.ext.unb.ca/>
" 	        Joshua Hollett <j.hollett@uwinnipeg.ca>
" Usage:	For instructions, do :help fortran-syntax from Vim
" Credits:
"  Version 0.1 for Fortran 95 was created in April 2000 by Ajit Thakkar from an
"  older Fortran 77 syntax file by Mario Eusebio and Preben Guldberg.
"  Since then, useful suggestions and contributions have been made, in order, by:
"  Andrej Panjkov, Bram Moolenaar, Thomas Olsen, Michael Sternberg, Christian Reile,
"  Walter Dieudonne, Alexander Wagner, Roman Bertle, Charles Rendleman,
"  Andrew Griffiths, Joe Krahn, Hendrik Merx, Matt Thompson, Jan Hermann,
"  Stefano Zaghi, Vishnu V. Krishnan, Judicael Grasset, Takuma Yoshida,
"  Eisuke Kawashima, Andre Chalella, Fritz Reese, Karl D. Hammond,
"  and Michele Esposito Marzino.

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Choose between fixed and free source form if this hasn't been done yet
if !exists("b:fortran_fixed_source")
  if exists("fortran_free_source")
    " User guarantees free source form for all fortran files
    let b:fortran_fixed_source = 0
  elseif exists("fortran_fixed_source")
    " User guarantees fixed source form for all fortran files
    let b:fortran_fixed_source = 1
  elseif expand("%:e") =~? '^f\%(90\|95\|03\|08\)$'
    " Free-form file extension defaults as in Intel ifort, gcc(gfortran), NAG, Pathscale, and Cray compilers
    let b:fortran_fixed_source = 0
  elseif expand("%:e") =~? '^\%(f\|f77\|for\)$'
    " Fixed-form file extension defaults
    let b:fortran_fixed_source = 1
  else
    " Modern fortran compilers still allow both free and fixed source form.
    " Assume fixed source form unless signs of free source form
    " are detected in the first five columns of the first s:lmax lines.
    " Detection becomes more accurate and time-consuming if more lines
    " are checked. Increase the limit below if you keep lots of comments at
    " the very top of each file and you have a fast computer.
    let s:lmax = 500
    if ( s:lmax > line("$") )
      let s:lmax = line("$")
    endif
    let b:fortran_fixed_source = 1
    let s:ln=1
    while s:ln <= s:lmax
      let s:test = strpart(getline(s:ln),0,5)
      if s:test !~ '^[Cc*]' && s:test !~ '^ *[!#]' && s:test =~ '[^ 0-9\t]' && s:test !~ '^[ 0-9]*\t'
        let b:fortran_fixed_source = 0
        break
      endif
      let s:ln = s:ln + 1
    endwhile
    unlet! s:lmax s:ln s:test
  endif
endif

syn case ignore

if b:fortran_fixed_source == 1
  syn match fortranConstructName	"^\s\{6,}\zs\a\w*\ze\s*:"
else
  syn match fortranConstructName	"^\s*\zs\a\w*\ze\s*:"
endif
syn match fortranConstructName          "\(\<end\s*do\s\+\)\@11<=\a\w*"
syn match fortranConstructName          "\(\<end\s*if\s\+\)\@11<=\a\w*"
syn match fortranConstructName          "\(\<end\s*select\s\+\)\@15<=\a\w*"
syn match fortranConstructName          "\(\<end\s*where\s\+\)\@14<=\a\w*"
syn match fortranConstructName          "\(\<end\s*block\s\+\)\@14<=\a\w*"
syn match fortranConstructName          "\(\<\%(exit\|cycle\)\s\+\)\@11<=\a\w*"
syn match fortranConstructName          "\(\<end\s*forall\s\+\)\@15<=\a\w*\>"
syn match fortranConstructName          "\(\<end\s*critical\s\+\)\@17<=\a\w*\>"
syn match fortranConstructName          "\(\<end\s*associate\s\+\)\@18<=\a\w*\>"

syn match fortranUnitName               "\(\(end\s*\)\?\(subroutine\|function\|module\|program\|submodule\)\s\+\)\@12<=\a\w\+"
syn match fortranUnitHeader             "\<end\s*$"

syn keyword fortranIntrinsic	abs acos aimag aint anint asin atan atan2 char cmplx conjg cos cosh exp ichar index int log log10 max min nint sign sin sinh sqrt tan tanh
syn keyword fortranIntrinsicR	achar iachar transfer dble dprod dim lge lgt lle llt mod
syn keyword fortranIntrinsic    command_argument_count get_command get_command_argument get_environment_variable is_iostat_end is_iostat_eor move_alloc new_line same_type_as extends_type_of
syn keyword fortranIntrinsic    selected_real_kind selected_int_kind selected_logical_kind selected_char_kind
syn keyword fortranIntrinsic    acosh asinh atanh bessel_j0 bessel_j1 bessel_jn bessel_y0 bessel_y1 bessel_yn erf erfc erfc_scaled gamma log_gamma hypot norm2
syn keyword fortranIntrinsic    adjustl adjustr all allocated any associated bit_size btest ceiling cshift date_and_time digits
syn keyword fortranIntrinsic    dot_product eoshift exponent floor fraction iand ibclr ibits ibset ieor ior ishft ishftc lbound len_trim matmul maxexponent maxloc merge minexponent minloc
syn keyword fortranIntrinsic    modulo mvbits nearest pack precision present radix random_number random_seed range repeat reshape rrspacing scale scan set_exponent shape size spacing
"syn keyword fortranIntrinsic    count epsilon maxval minval product sum huge tiny
" intrinsic names often used for variables in older Fortran code
syn match fortranIntrinsic      '\<\(count\|epsilon\|maxval\|minval\|product\|sum\|huge\|tiny\)\>\ze\s*('
syn keyword fortranIntrinsic    spread system_clock transpose trim ubound unpack verify
syn keyword fortranIntrinsic    atomic_define atomic_ref execute_command_line leadz trailz storage_size merge_bits
syn keyword fortranIntrinsic    bge bgt ble blt dshiftl dshiftr findloc iall iany iparity image_index lcobound ucobound maskl maskr num_images parity popcnt poppar shifta shiftl shiftr this_image
syn keyword fortranIntrinsic    null cpu_time failed_images stopped_images image_status co_broadcast co_max co_min co_sum co_reduce
syn keyword fortranIntrinsic    atomic_add atomic_and atomic_or atomic_xor atomic_fetch_add atomic_fetch_and atomic_fetch_or atomic_fetch_xor atomic_cas
syn keyword fortranIntrinsic    ieee_arithmetic ieee_support_underflow_control ieee_get_underflow_mode ieee_set_underflow_mode
syn keyword fortranIntrinsic    ieee_max ieee_max_mag ieee_min ieee_min_mag split tokenize ieee_support_subnormal ieee_get_modes ieee_set_modes
syn keyword fortranIntrinsic    ieee_set_status ieee_get_rounding_mode ieee_set_rounding_mode
syn keyword fortranIntrinsic    iso_c_binding c_loc c_funloc c_sizeof c_associated c_f_pointer c_f_procpointer
syn keyword fortranIntrinsic	out_of_range reduce random_init coshape
syn keyword fortranIntrinsic    acosd asind atand atan2d cosd sind tand acospi asinpi atanpi atan2pi cospi sinpi tanpi
syn keyword fortranIntrinsic    compiler_options compiler_version get_team team_number
syn match fortranIntrinsic	"\<real\s*("me=s+4
syn match fortranIntrinsic	"\<logical\s*("me=s+7
syn match fortranIntrinsic      "\<not\s*("me=s+3
syn match fortranIntrinsic	"\<len\s*("me=s+3
syn match fortranIntrinsic	"\<kind\s*("me=s+4
" obsolescent type-specific intrinsics
syn keyword fortranIntrinsicOb	alog alog10 amax0 amax1 amin0 amin1 amod cabs ccos cexp clog csin csqrt dabs dacos dasin datan datan2 dcos dcosh ddim dexp dint dlog dlog10 dmax1 dmin1 dmod dnint dsign dsin dsinh dsqrt dtan dtanh float iabs idim idint idnint ifix isign max0 max1 min0 min1 sngl
" Extra intrinsics provided by some vendors
syn keyword fortranExtraIntrinsic	algama cdabs cdcos cdexp cdlog cdsin cdsqrt cqabs cqcos cqexp cqlog cqsin cqsqrt dcmplx dconjg derf derfc dfloat dgamma dimag dlgama iqint qabs qacos qasin qatan qatan2 qcmplx qconjg qcos qcosh qdim qerf qerfc qexp qgamma qimag qlgama qlog qlog10 qmax1 qmin1 qmod qnint qsign qsin qsinh qsqrt qtan qtanh

syn keyword fortranType         generic final enumerator import
syn keyword fortranType         c_ptr c_funptr elemental pure impure recursive non_recursive
syn match fortranTypeOb         "^\s*\(character\s*\)\@15<=\*"
syn match fortranType           "^\s*\(implicit \)\?\s*\(real\|integer\|logical\|complex\|character\|type\)\>"
syn match fortranType           "^\s*implicit\s\+none"
syn match fortranType           "\(class\|type\)\(of\)\?"
syn match fortranType           "\(end\s*\)\?\<interface\>"
syn match fortranType           "\<enum\s*,\s*bind\s*(\s*c\s*)"
syn match fortranType           "\<end\s*\(enum\|type\)\>"
syn match fortranType           "\(end\s*\)\?enumeration\s\+type"
syn match fortranType           "\(end\s*\)\?\(\<module\s\+\)\?procedure\>"
syn match fortranTypeR	       	display "double\s*precision"
syn match fortranTypeR  	display "double\s\+complex"
syn keyword fortranAttribute    value bind deferred contiguous intrinsic non_intrinsic
syn keyword fortranAttribute    asynchronous nopass non_overridable pass volatile extends
syn keyword fortranAttribute    abstract external private public protected intent optional
syn keyword fortranAttribute	pointer target allocatable dimension codimension sequence parameter save

syn keyword fortranUnitHeader	result operator assignment
syn match fortranUnitHeader     "\<\(end\s*\)\?\(subroutine\|function\|module\|program\|submodule\)\>"
syn match fortranBlock          "\<\(end\s*\)\?\(block\|critical\|associate\)\>"
syn match fortranCalled		"\(call\s\+\)\@7<=\a\w*"
syn match fortranRepeat		"\<do\>"
syn keyword fortranRepeat       concurrent
syn keyword fortranRepeatR	while
syn match fortranRepeat         "\<end\s*do"
syn keyword fortranRepeatOb	forall
syn match fortranRepeatOb	"\<end\s*forall\>"

syn keyword fortranTodo		contained bug note debug todo fixme

"Catch errors caused by too many right parentheses
syn region fortranParen transparent start="(" end=")" contains=ALLBUT,fortranParenError,@fortranCommentGroup,cIncluded,@spell
syn match  fortranParenError   ")"

syn match fortranOperator	"\.\s*n\=eqv\s*\."
syn match fortranOperator	"\.\s*\(and\|or\|not\)\s*\."
syn match fortranOperator	"\(+\|-\|/\|\*\)"
syn match fortranOperator	"\(\(>\|<\)=\=\|==\|/=\|=\)"
syn match fortranOperator	"\(%\|?\|=>\)"
syn match fortranOperator       "\([\|]\)"
syn match fortranOperatorR	"\.\s*[gl][et]\s*\."
syn match fortranOperatorR	"\.\s*\(eq\|ne\)\s*\."

syn keyword fortranReadWrite	print flush
syn match fortranReadWrite	'\<\(backspace\|close\|endfile\|inquire\|open\|read\|rewind\|write\)\ze\s*('

"If tabs are allowed then the left margin checks do not work
if exists("fortran_have_tabs")
  syn match fortranTab		"\t"  transparent
else
  syn match fortranTab		"\t"
endif

"Numbers of various sorts
" Integers
syn match fortranNumber	display "\<\d\+\(_\a\w*\)\=\>"
" floating point number, without a decimal point
syn match fortranFloatIll	display	"\<\d\+[deq][-+]\=\d\+\(_\a\w*\)\=\>"
" floating point number, starting with a decimal point
syn match fortranFloatIll	display	"\.\d\+\([deq][-+]\=\d\+\)\=\(_\a\w*\)\=\>"
" floating point number, no digits after decimal
syn match fortranFloatIll	display	"\<\d\+\.\([deq][-+]\=\d\+\)\=\(_\a\w*\)\=\>"
" floating point number, D or Q exponents
syn match fortranFloatIll	display	"\<\d\+\.\d\+\([dq][-+]\=\d\+\)\=\(_\a\w*\)\=\>"
" floating point number
syn match fortranFloat	display	"\<\d\+\.\d\+\(e[-+]\=\d\+\)\=\(_\a\w*\)\=\>"
" binary number
syn match fortranBinary	display	"b["'][01]\+["']"
" octal number
syn match fortranOctal	display	"o["'][0-7]\+["']"
" hexadecimal number
syn match fortranHex	display	"z["'][0-9A-F]\+["']"
" Numbers in formats
syn match fortranFormatSpec	display	"\d*f\d\+\.\d\+"
syn match fortranFormatSpec	display	"\d*e[sn]\=\d\+\.\d\+\(e\d+\>\)\="
syn match fortranFormatSpec	display	"\d*\(d\|q\|g\)\d\+\.\d\+\(e\d+\)\="
syn match fortranFormatSpec	display	"\d\+x\>"
" The next match cannot be used because it would pick up identifiers as well
" syn match fortranFormatSpec	display	"\<\(a\|i\)\d\+"
" Numbers as labels
syn match fortranLabelNumber	display	"^\d\{1,5}\s"me=e-1
syn match fortranLabelNumber	display	"^ \d\{1,4}\s"ms=s+1,me=e-1
syn match fortranLabelNumber	display	"^  \d\{1,3}\s"ms=s+2,me=e-1
syn match fortranLabelNumber	display	"^   \d\d\=\s"ms=s+3,me=e-1
syn match fortranLabelNumber	display	"^    \d\s"ms=s+4,me=e-1
" Numbers as targets
syn match fortranTarget	display	"\(\<if\s*(.\+)\s*\)\@<=\(\d\+\s*,\s*\)\{2}\d\+\>"
syn match fortranTarget	display	"\(\<do\s\+\)\@11<=\d\+\>"
syn match fortranTarget	display	"\(\<go\s*to\s*(\=\)\@11<=\(\d\+\s*,\s*\)*\d\+\>"

syn match fortranBoolean	"\.\s*\(true\|false\)\s*\."

syn match fortranKeyword	"call"
syn keyword fortranKeyword 	use only contains
syn match fortranKeyword        "fail\s\+image\>"
syn match fortranKeyword	"\(error\s\+\)\=stop"
syn match fortranKeyword	"\<continue\>"
syn match fortranKeyword	"^\s*\d\+\s\+continue\>"
syn match fortranKeyword  	"\<go\s*to\>"
syn match fortranKeywordDel  	"\<go\s*to\ze\s\+.*,\s*(.*$"
syn match fortranKeywordOb  	"\<go\s*to\ze\s*(\d\+.*$"
syn keyword fortranKeywordDel	assign pause
syn keyword fortranKeyword	allocate deallocate nullify return cycle exit

syn region fortranString 	start=+'+ end=+'+	contains=fortranLeftMargin,fortranContinueMark,fortranSerialNumber
syn region fortranString	start=+"+ end=+"+	contains=fortranLeftMargin,fortranContinueMark,fortranSerialNumber

syn match fortranIO		'\%(\((\|,\|, *&\n\)\s*\)\@<=\(access\|blank\|direct\|exist\|file\|fmt\|form\|formatted\|iostat\|name\|named\|nextrec\|number\|opened\|rec\|recl\|sequential\|status\|unformatted\|unit\)\ze\s*='
syn keyword fortranIOR		format namelist
syn keyword fortranIO		pad position action delim readwrite
syn keyword fortranIO		eor advance nml
syn keyword fortranIO           newunit decimal round iomsg
syn match   fortranIO		contains=fortranOperator "\<e\(nd\|rr\)\s*=\s*\d\+"

syn keyword fortranConditional	else then where elsewhere
syn match fortranConditional    "\<if\>"
syn match fortranConditional    "\<else\s*if"
syn match fortranConditional    "\(end\s*\)\?\(if\|where\|select\)"
syn match fortranConditional    "\<select\s\+\(case\|rank\|type\)"
syn match fortranConditional    "\(class\|type\)\s\+is\>"
syn match fortranConditional    "\(case\|rank\)\(\s\+default\)\?"
syn match fortranConditionalDel	"\<if\s*(.*)\s*\d\+\s*,\s*\d\+\s*,\s*\d\+\s*$"

syn keyword fortranInclude		include

syn match fortranImageControl   "sync\s\+\(all\|images\|memory\|team\)\>"
syn match fortranImageControl   "\(change\|form\|end\)\s\+team\>"
syn match fortranImageControl   "event\s\+\(post\|wait\)"
syn match fortranImageControl   "\(un\)\?lock\ze\s*("
syn match fortranImageControl   "notify\s\+wait\ze\s*("

syn keyword fortranUnitHeaderOb	entry
syn match fortranUnitHeaderOb	display "block\s*data"

syn keyword fortranStorageClass	        in out
syn match  fortranStorageClass          "\<in\s*out\>"
syn match fortranStorageClass           "\<kind\s*="me=s+4
syn match fortranStorageClass           "\<len\s*="me=s+3
syn match fortranStorageClass           "^\s*data\>\(\s\+\a\w*\s*/\)\@="
syn match fortranStorageClassOb         "^\s*common\>"
syn match fortranStorageClassOb         "^\s*common\>\(\s*/\)\@="
syn keyword fortranStorageClassOb	equivalence

syn keyword fortranConstant         c_null_char c_alert c_backspace c_form_feed c_new_line c_carriage_return c_horizontal_tab c_vertical_tab
syn keyword fortranConstant         c_int c_short c_long c_long_long c_signed_char c_size_t c_int8_t c_int16_t c_int32_t c_int64_t c_int_least8_t c_int_least16_t c_int_least32_t c_int_least64_t c_int_fast8_t c_int_fast16_t c_int_fast32_t c_int_fast64_t c_intmax_t C_intptr_t c_float c_double c_long_double c_float_complex c_double_complex c_long_double_complex c_bool c_char c_null_ptr c_null_funptr
syn keyword fortranConstant         iso_fortran_env character_storage_size error_unit file_storage_size input_unit iostat_end iostat_eor numeric_storage_size output_unit stat_failed_image stat_unlocked_failed_image
syn keyword fortranConstant         int8 int16 int32 int64 real16 real32 real64 real128 character_kinds integer_kinds logical_kinds real_kinds iostat_inquire_internal_unit
syn keyword fortranConstant         ieee_negative_subnormal ieee_positive_subnormal

" CUDA fortran
if exists("fortran_CUDA")
  syn match fortranTypeCUDA           "\<attributes\>"
  syn keyword fortranTypeCUDA         host global device
  syn keyword fortranTypeCUDA         shared constant pinned texture
  syn keyword fortranTypeCUDA         dim1 dim2 dim3 dim4
  syn keyword fortranTypeCUDA         cudadeviceprop cuda_count_kind cuda_stream_kind
  syn keyword fortranTypeCUDA         cudaEvent cudaFuncAttributes cudaArrayPtr
  syn keyword fortranTypeCUDA         cudaSymbol cudaChannelFormatDesc cudaPitchedPtr
  syn keyword fortranTypeCUDA         cudaExtent cudaMemcpy3DParms
  syn keyword fortranTypeCUDA         cudaFuncCachePreferNone cudaFuncCachePreferShared
  syn keyword fortranTypeCUDA         cudaFuncCachePreferL1 cudaLimitStackSize
  syn keyword fortranTypeCUDA         cudaLimitPrintfSize cudaLimitMallocHeapSize
  syn keyword fortranTypeCUDA         cudaSharedMemBankSizeDefault cudaSharedMemBankSizeFourByte cudaSharedMemBankSizeEightByte
  syn keyword fortranTypeCUDA         cudaEventDefault cudaEventBlockingSync cudaEventDisableTiming
  syn keyword fortranTypeCUDA         cudaMemcpyHostToDevice cudaMemcpyDeviceToHost
  syn keyword fortranTypeCUDA         cudaMemcpyDeviceToDevice
  syn keyword fortranTypeCUDA         cudaErrorNotReady cudaSuccess cudaErrorInvalidValue
  syn keyword fortranTypeCUDA         c_devptr

  syn match fortranStringCUDA         "blockidx%[xyz]"
  syn match fortranStringCUDA         "blockdim%[xyz]"
  syn match fortranStringCUDA         "griddim%[xyz]"
  syn match fortranStringCUDA         "threadidx%[xyz]"

  syn keyword fortranIntrinsicCUDA    warpsize syncthreads syncthreads_and syncthreads_count syncthreads_or threadfence threadfence_block threadfence_system gpu_time allthreads anythread ballot
  syn keyword fortranIntrinsicCUDA    atomicadd atomicsub atomicmax atomicmin atomicand atomicor atomicxor atomicexch atomicinc atomicdec atomiccas sizeof __shfl __shfl_up __shfl_down __shfl_xor
  syn keyword fortranIntrinsicCUDA    cudaChooseDevice cudaDeviceGetCacheConfig cudaDeviceGetLimit cudaDeviceGetSharedMemConfig cudaDeviceReset cudaDeviceSetCacheConfig cudaDeviceSetLimit cudaDeviceSetSharedMemConfig cudaDeviceSynchronize cudaGetDevice cudaGetDeviceCount cudaGetDeviceProperties cudaSetDevice cudaSetDeviceFlags cudaSetValidDevices
  syn keyword fortranIntrinsicCUDA    cudaThreadExit cudaThreadSynchronize cudaGetLastError cudaGetErrorString cudaPeekAtLastError cudaStreamCreate cudaStreamDestroy cudaStreamQuery cudaStreamSynchronize cudaStreamWaitEvent cudaEventCreate cudaEventCreateWithFlags cudaEventDestroy cudaEventElapsedTime cudaEventQuery cudaEventRecord cudaEventSynchronize
  syn keyword fortranIntrinsicCUDA    cudaFuncGetAttributes cudaFuncSetCacheConfig cudaFuncSetSharedMemConfig cudaSetDoubleForDevice cudaSetDoubleForHost cudaFree cudaFreeArray cudaFreeHost cudaGetSymbolAddress cudaGetSymbolSize
  syn keyword fortranIntrinsicCUDA    cudaHostAlloc cudaHostGetDevicePointer cudaHostGetFlags cudaHostRegister cudaHostUnregister cudaMalloc cudaMallocArray cudaMallocHost cudaMallocPitch cudaMalloc3D cudaMalloc3DArray
  syn keyword fortranIntrinsicCUDA    cudaMemcpy cudaMemcpyArraytoArray cudaMemcpyAsync cudaMemcpyFromArray cudaMemcpyFromSymbol cudaMemcpyFromSymbolAsync cudaMemcpyPeer cudaMemcpyPeerAsync cudaMemcpyToArray cudaMemcpyToSymbol cudaMemcpyToSymbolAsync cudaMemcpy2D cudaMemcpy2DArrayToArray cudaMemcpy2DAsync cudaMemcpy2DFromArray cudaMemcpy2DToArray cudaMemcpy3D cudaMemcpy3DAsync
  syn keyword fortranIntrinsicCUDA    cudaMemGetInfo cudaMemset cudaMemset2D cudaMemset3D cudaDeviceCanAccessPeer cudaDeviceDisablePeerAccess cudaDeviceEnablePeerAccess cudaPointerGetAttributes cudaDriverGetVersion cudaRuntimeGetVersion
endif

syn region none matchgroup=fortranType start="<<<" end=">>>" contains=ALLBUT,none

syn cluster fortranCommentGroup contains=fortranTodo

if (b:fortran_fixed_source == 1)
  if !exists("fortran_have_tabs")
    if exists("fortran_extended_line_length")
    " Vendor extensions allow lines with a text width of 132
      syn match fortranSerialNumber	excludenl "^.\{133,}$"lc=132
    else
    " Standard requires fixed format to have a text width of 72,
    " but all current compilers use 80 instead
      syn match fortranSerialNumber	excludenl "^.\{81,}$"lc=80
    endif
    "Flag left margin errors
    syn match fortranLabelError	"^.\{-,4}[^0-9 ]" contains=fortranTab
    syn match fortranLabelError	"^.\{4}\d\S"
  endif
  syn match fortranComment		excludenl "^[!c*].*$" contains=@fortranCommentGroup,@spell
  syn match fortranLeftMargin		transparent "^ \{5}"
  syn match fortranContinueMark		display "^.\{5}\S"lc=5
else
  syn match fortranContinueMark		display "&"
endif

syn match fortranComment	excludenl "!.*$" contains=@fortranCommentGroup,@spell
syn match fortranOpenMP		excludenl 		"^\s*!\$\(OMP\)\=&\=\s.*$"
syn match fortranEndStatement   display ";"

"cpp is often used with Fortran
syn match	cPreProc		"^\s*#\s*\(define\|ifdef\)\>.*"
syn match	cPreProc		"^\s*#\s*\(elif\|if\)\>.*"
syn match	cPreProc		"^\s*#\s*\(ifndef\|undef\)\>.*"
syn match	cPreCondit		"^\s*#\s*\(else\|endif\)\>.*"
syn region	cIncluded	contained start=+"[^("]+ skip=+\\\\\|\\"+ end=+"+ contains=fortranLeftMargin,fortranContinueMark,fortranSerialNumber
"syn region	cIncluded	        contained start=+"[^("]+ skip=+\\\\\|\\"+ end=+"+
syn match	cIncluded		contained "<[^>]*>"
syn match	cInclude		"^\s*#\s*include\>\s*["<]" contains=cIncluded

"Synchronising limits assume that comment and continuation lines are not mixed
if exists("fortran_fold")
  syn sync fromstart
elseif (b:fortran_fixed_source == 0)
  syn sync linecont "&" minlines=30
else
  syn sync minlines=30
endif

if exists("fortran_fold")

  if has("folding")
    setlocal foldmethod=syntax
  endif
  if (b:fortran_fixed_source == 1)
    syn region fortranProgram transparent fold keepend start="^\s*program\s\+\z(\a\w*\)" skip="^\([!c*]\|\s*#\).*$" excludenl end="\<end\s*\(program\(\s\+\z1\>\)\=\|$\)" contains=ALLBUT,fortranModule
    syn region fortranModule transparent fold keepend start="^\s*submodule\s\+(\a\w*\s*\(:\a\w*\s*\)*)\s*\z\(\a\w*\)" skip="^\([!c*]\|\s*#\).*$" excludenl end="\<end\s*\(submodule\(\s\+\z1\>\)\=\|$\)" contains=ALLBUT,fortranProgram,fortranModule
    syn region fortranModule transparent fold keepend start="^\s*module\s\+\(procedure\)\@!\z(\a\w*\)" skip="^\([!c*]\|\s*#\).*$" excludenl end="\<end\s*\(module\(\s\+\z1\>\)\=\|$\)" contains=ALLBUT,fortranProgram
    syn region fortranFunction transparent fold keepend extend start="^\s*\(elemental \|pure \|impure \|module \|recursive \)\=\s*\(\(\(real \|integer \|logical \|complex \|double \s*precision \)\s*\((\(\s*kind\s*=\)\=\s*\w\+\s*)\)\=\)\|type\s\+(\s*\w\+\s*) \|character \((\(\s*len\s*=\)\=\s*\d\+\s*)\|(\(\s*kind\s*=\)\=\s*\w\+\s*)\)\=\)\=\s*function\s\+\z(\a\w*\)" skip="^\([!c*]\|\s*#\).*$" excludenl end="\<end\s*\($\|function\(\s\+\z1\>\)\=\)" contains=ALLBUT,fortranProgram,fortranModule
    syn region fortranSubroutine transparent fold keepend extend start="^\s*\(elemental \|pure \|impure \|module \|recursive \)\=\s*subroutine\s\+\z(\a\w*\)" skip="^\([!c*]\|\s*#\).*$" excludenl end="\<end\s*\($\|subroutine\(\s\+\z1\>\)\=\)" contains=ALLBUT,fortranProgram,fortranModule
    syn region fortranBlockData transparent fold keepend start="\<block\>" skip="^\s*[!#].*$" excludenl end="\<end\s*block\>" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortran77Loop,fortranCase,fortran90Loop,fortranIfBlock
    syn region fortranAssociate transparent fold keepend start="^\s*\<associate\s\+" skip="^\([!c*]\|\s*#\).*$" excludenl end="\<end\s*associate" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction
    syn region fortranCritical transparent fold keepend start="^\s*\<critical\s\+" skip="^\([!c*]\|\s*#\).*$" excludenl end="\<end\s*critical" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction
    syn region fortranTeam transparent fold keepend start="^\s*\<change\s\+team\>" skip="^\([!c*]\|\s*#\).*$" excludenl end="\<end\s*team\>" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction
    syn region fortranInterface transparent fold keepend extend start="^\s*\(abstract \)\=\s*interface\>" skip="^\([!c*]\|\s*#\).*$" excludenl end="\<end\s*interface\>" contains=ALLBUT,fortranProgram,fortranModule,fortran77Loop,fortranCase,fortran90Loop,fortranIfBlock
    syn region fortranTypeDef transparent fold keepend extend start="^\s*type\s*\(,\s*\(public\|private\|abstract\)\)\=\s*::" skip="^\([!c*]\|\s*#\).*$" excludenl end="\<end\s*type\>" contains=ALLBUT,fortranProgram,fortranModule,fortran77Loop,fortranCase,fortran90Loop,fortranIfBlock,fortranInterface
  else
    syn region fortranProgram transparent fold keepend start="^\s*program\s\+\z(\a\w*\)" skip="^\s*[!#].*$" excludenl end="\<end\s*\(program\(\s\+\z1\>\)\=\|$\)" contains=ALLBUT,fortranModule
    syn region fortranModule transparent fold keepend start="^\s*submodule\s\+(\a\w*\s*\(:\a\w*\s*\)*)\s*\z\(\a\w*\)" skip="^\s*[!#].*$" excludenl end="\<end\s*\(submodule\(\s\+\z1\>\)\=\|$\)" contains=ALLBUT,fortranProgram,fortranModule
    syn region fortranModule transparent fold keepend start="^\s*module\s\+\(procedure\)\@!\z(\a\w*\)" skip="^\s*[!#].*$" excludenl end="\<end\s*\(module\(\s\+\z1\>\)\=\|$\)" contains=ALLBUT,fortranProgram
    syn region fortranFunction transparent fold keepend extend start="^\s*\(elemental \|pure \|impure \|module \|recursive \)\=\s*\(\(\(real \|integer \|logical \|complex \|double \s*precision \)\s*\((\(\s*kind\s*=\)\=\s*\w\+\s*)\)\=\)\|type\s\+(\s*\w\+\s*) \|character \((\(\s*len\s*=\)\=\s*\d\+\s*)\|(\(\s*kind\s*=\)\=\s*\w\+\s*)\)\=\)\=\s*function\s\+\z(\a\w*\)" skip="^\s*[!#].*$" excludenl end="\<end\s*\($\|function\(\s\+\z1\>\)\=\)" contains=ALLBUT,fortranProgram,fortranModule
    syn region fortranSubroutine transparent fold keepend extend start="^\s*\(elemental \|pure \|impure \|module \|recursive \)\=\s*subroutine\s\+\z(\a\w*\)" skip="^\s*[!#].*$" excludenl end="\<end\s*\($\|subroutine\(\s\+\z1\>\)\=\)" contains=ALLBUT,fortranProgram,fortranModule
    syn region fortranBlockData transparent fold keepend start="\<block\>" skip="^\s*[!#].*$" excludenl end="\<end\s*block\>" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortran77Loop,fortranCase,fortran90Loop,fortranIfBlock
    syn region fortranAssociate transparent fold keepend start="\<associate\>" skip="^\s*[!#].*$" excludenl end="\<end\s*associate\>" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction
    syn region fortranCritical transparent fold keepend start="\<critical\>" skip="^\s*[!#].*$" excludenl end="\<end\s*critical\>" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction
    syn region fortranTeam transparent fold keepend start="\<change\s\+team\>" skip="^\s*[!#].*$" excludenl end="\<end\s*team\>" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction
    syn region fortranInterface transparent fold keepend extend start="^\s*\(abstract \)\=\s*interface\>" skip="^\s*[!#].*$" excludenl end="\<end\s*interface\>" contains=ALLBUT,fortranProgram,fortranModule,fortran77Loop,fortranCase,fortran90Loop,fortranIfBlock
    syn region fortranTypeDef transparent fold keepend extend start="^\s*type\s*\(,\s*\(public\|private\|abstract\)\)\=\s*::" skip="^\s*[!#].*$" excludenl end="\<end\s*type\>" contains=ALLBUT,fortranProgram,fortranModule,fortran77Loop,fortranCase,fortran90Loop,fortranIfBlock,fortranInterface
  endif

  if exists("fortran_fold_conditionals")
    if (b:fortran_fixed_source == 1)
      syn region fortran77Loop transparent fold keepend start="\<do\s\+\z(\d\+\)" end="^\s*\z1\>" contains=ALLBUT,fortranUnitHeader,fortranAttribute,fortranStorageClass,fortranType,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortranBlockData
      syn region fortran90Loop transparent fold keepend extend start="\(\<end\s\+\)\@<!\<do\(\s\+\a\|\s*$\)" skip="^\([!c*]\|\s*#\).*$" excludenl end="\<end\s*do\>" contains=ALLBUT,fortranUnitHeader,fortranAttribute,fortranStorageClass,fortranType,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortranBlockData
      syn region fortranIfBlock transparent fold keepend extend start="\(\<e\(nd\|lse\)\s\+\)\@<!\<if\s*(.\+)\s*then\>" skip="^\([!c*]\|\s*#\).*$" end="\<end\s*if\>" contains=ALLBUT,fortranUnitHeader,fortranAttribute,fortranStorageClass,fortranType,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortranBlockData
      syn region fortranCase transparent fold keepend extend start="\<select\s*\(case\|type\|rank\)\>" skip="^\([!c*]\|\s*#\).*$" end="\<end\s*select\>" contains=ALLBUT,fortranUnitHeader,fortranAttribute,fortranStorageClass,fortranType,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortranBlockData
    else
      syn region fortran77Loop transparent fold keepend start="\<do\s\+\z(\d\+\)" end="^\s*\z1\>" contains=ALLBUT,fortranUnitHeader,fortranAttribute,fortranStorageClass,fortranType,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortranBlockData
      syn region fortran90Loop transparent fold keepend extend start="\(\<end\s\+\)\@<!\<do\(\s\+\a\|\s*$\)" skip="^\s*[!#].*$" excludenl end="\<end\s*do\>" contains=ALLBUT,fortranUnitHeader,fortranAttribute,fortranStorageClass,fortranType,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortranBlockData
      syn region fortranIfBlock transparent fold keepend extend start="\(\<e\(nd\|lse\)\s\+\)\@<!\<if\s*(\(.\|&\s*\n\)\+)\(\s\|&\s*\n\)*then\>" skip="^\s*[!#].*$" end="\<end\s*if\>" contains=ALLBUT,fortranUnitHeader,fortranAttribute,fortranStorageClass,fortranType,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortranBlockData
      syn region fortranCase transparent fold keepend extend start="\<select\s*\(case\|type\|rank\)\>" skip="^\s*[!#].*$" end="\<end\s*select\>" contains=ALLBUT,fortranUnitHeader,fortranAttribute,fortranStorageClass,fortranType,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortranBlockData
    endif
  endif

  if exists("fortran_fold_multilinecomments")
    if (b:fortran_fixed_source == 1)
      syn match fortranMultiLineComments transparent fold "\(^[!c*].*\(\n\|\%$\)\)\{4,}" contains=ALLBUT,fortranMultiCommentLines
    else
      syn match fortranMultiLineComments transparent fold "\(^\s*!.*\(\n\|\%$\)\)\{4,}" contains=ALLBUT,fortranMultiCommentLines
    endif
  endif
endif

" Define the default highlighting.
" Transparent groups:
" fortranParen, fortranLeftMargin
" fortranProgram, fortranModule, fortranSubroutine, fortranFunction,
" fortranBlockData
" fortran77Loop, fortran90Loop, fortranIfBlock, fortranCase
" fortranMultiCommentLines
hi def link fortranKeyword 	        Keyword
hi def link fortranConstructName	Identifier
hi def link fortranConditional	        Conditional
hi def link fortranRepeat	        Repeat
hi def link fortranTodo		        Todo
hi def link fortranContinueMark	        Special
hi def link fortranEndStatement	        Special
hi def link fortranString	        String
hi def link fortranNumber	        Number
hi def link fortranBinary	        Number
hi def link fortranOctal	        Number
hi def link fortranHex  	        Number
hi def link fortranOperator	        Operator
hi def link fortranBoolean	        Boolean
hi def link fortranLabelError	        Error
hi def link fortranObsolescent	        Todo
hi def link fortranType		        Type
hi def link fortranAttribute	        Type
hi def link fortranBlock                fortranConditional
hi def link fortranImageControl         Keyword
hi def link fortranStorageClass         StorageClass
hi def link fortranIntrinsic            Function
hi def link fortranCalled               Function
hi def link fortranUnitName     	Function
hi def link fortranUnitHeader           fortranPreCondit
hi def link fortranReadWrite            Keyword
hi def link fortranIO                   Keyword
hi def link fortranConstant     	Constant

hi def link fortranInclude              Include
hi def link fortranLabelNumber          Special
hi def link fortranTarget               Special
hi def link fortranFloatIll             fortranFloat

" Redundant features which may one day become obsolescent
hi def link fortranIntrinsicR   	fortranIntrinsic
hi def link fortranTypeR		fortranType
hi def link fortranStorageClassR	fortranStorageClass
hi def link fortranOperatorR	        fortranOperator
hi def link fortranIOR  		fortranIO
hi def link fortranRepeatR  		fortranRepeat

" features deleted or declared obsolescent in Fortran 2023
if (b:fortran_fixed_source == 1)
  hi def link fortranUnitHeaderOb    fortranUnitHeader
  hi def link fortranKeywordOb       fortranKeyword
  hi def link fortranKeywordDel      fortranKeyword
  hi def link fortranConditionalDel  fortranConditional
  hi def link fortranTypeOb          fortranType
  hi def link fortranStorageClassOb  fortranStorageClass
  hi def link fortranRepeatOb        fortranRepeat
  hi def link fortranIntrinsicOb     fortranIntrinsic
else
  hi def link fortranUnitHeaderOb    fortranObsolescent
  hi def link fortranKeywordOb       fortranObsolescent
  hi def link fortranKeywordDel      fortranObsolescent
  hi def link fortranConditionalDel  fortranObsolescent
  hi def link fortranTypeOb          fortranObsolescent
  hi def link fortranStorageClassOb  fortranObsolescent
  hi def link fortranRepeatOb        fortranObsolescent
  hi def link fortranIntrinsicOb     fortranObsolescent
endif

hi def link fortranFormatSpec	Identifier
hi def link fortranFloat	Float
hi def link fortranPreCondit	PreCondit
hi def link cIncluded		fortranString
hi def link cInclude		Include
hi def link cPreProc		PreProc
hi def link cPreCondit		PreCondit
hi def link fortranOpenMP       PreProc
hi def link fortranParenError	Error
hi def link fortranComment	Comment
hi def link fortranSerialNumber	Todo
hi def link fortranTab		Error

if exists("fortran_CUDA")
  hi def link fortranIntrinsicCUDA        fortranIntrinsic
  hi def link fortranTypeCUDA             fortranType
  hi def link fortranStringCUDA           fortranString
endif

if exists("fortran_vendor_intrinsics")
  hi def link fortranExtraIntrinsic	Function
endif

let b:current_syntax = "fortran"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8 tw=132
