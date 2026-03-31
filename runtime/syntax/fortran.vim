" Vim syntax file
" Language:	Fortran 2023 (and Fortran 2018, 2008, 2003, 95, 90, and 77)
" Version:	(v113) 2024 February 01
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
    " User guarantees free source form for all Fortran files
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
    " Modern Fortran compilers still allow both free and fixed source form.
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

" Group names ending in 'Del' and 'Ob', respectively, indicate features deleted and obsolescent in Fortran 2018 and later
" Deleted features are highlighted as errors
" Obsolescent features are highlighted as todo items
syn case ignore

if b:fortran_fixed_source == 1
  syn match fortranConstructName	"^\s\{6,}\zs\a\w*\ze\s*:"
else
  syn match fortranConstructName	"^\s*\zs\a\w*\ze\s*:"
endif
syn match fortranConstructName          "\%(\<end\s*do\s\+\)\@11<=\a\w*"
syn match fortranConstructName          "\%(\<end\s*if\s\+\)\@11<=\a\w*"
syn match fortranConstructName          "\%(\<end\s*select\s\+\)\@15<=\a\w*"
syn match fortranConstructName          "\%(\<end\s*where\s\+\)\@14<=\a\w*"
syn match fortranConstructName          "\%(\<end\s*block\s\+\)\@14<=\a\w*"
syn match fortranConstructName          "\%(\<\%(exit\|cycle\)\s\+\)\@11<=\a\w*"
syn match fortranConstructName          "\%(\<end\s*forall\s\+\)\@15<=\a\w*\>"
syn match fortranConstructName          "\%(\<end\s*critical\s\+\)\@17<=\a\w*\>"
syn match fortranConstructName          "\%(\<end\s*associate\s\+\)\@18<=\a\w*\>"

syn match fortranUnitName               "\%(\<\%(end\s*\)\?\%(subroutine\|function\|module\|program\|submodule\)\s\+\)\@12<=\a\w*"
syn match fortranUnitHeader             "\<end\>\ze\s*\%(!.*\)\?$"

syn keyword fortranIntrinsic	abs acos aimag aint anint asin atan atan2 cmplx conjg cos cosh exp ichar index int log log10 max min nint sin sinh sqrt tan tanh
syn keyword fortranIntrinsicR	achar iachar transfer dble dprod dim lge lgt lle llt mod
syn keyword fortranIntrinsic    command_argument_count get_command get_command_argument get_environment_variable is_iostat_end is_iostat_eor move_alloc new_line same_type_as extends_type_of
syn keyword fortranIntrinsic    selected_real_kind selected_int_kind selected_logical_kind selected_char_kind next previous
syn keyword fortranIntrinsic    acosh asinh atanh bessel_j0 bessel_j1 bessel_jn bessel_y0 bessel_y1 bessel_yn erf erfc erfc_scaled gamma log_gamma hypot norm2
syn keyword fortranIntrinsic    adjustl adjustr all allocated any associated bit_size btest ceiling cshift date_and_time digits
syn keyword fortranIntrinsic    dot_product eoshift exponent floor fraction iand ibclr ibits ibset ieor ior ishft ishftc lbound len_trim matmul maxexponent maxloc merge minexponent minloc
syn keyword fortranIntrinsic    modulo mvbits nearest pack precision present radix random_number random_seed range repeat reshape rrspacing scale scan set_exponent shape spacing
" intrinsic names often used for variables in older Fortran code
syn match fortranIntrinsic      '\<\%(count\|epsilon\|maxval\|minval\|product\|sum\|huge\|tiny\|char\)\>\ze\s*('
syn keyword fortranIntrinsic    spread system_clock transpose trim ubound unpack verify is_contiguous event_query
syn keyword fortranIntrinsic    atomic_define atomic_ref execute_command_line leadz trailz storage_size merge_bits
syn keyword fortranIntrinsic    bge bgt ble blt dshiftl dshiftr findloc iall iany iparity image_index lcobound ucobound maskl maskr num_images parity popcnt poppar shifta shiftl shiftr this_image
syn keyword fortranIntrinsic    null cpu_time failed_images stopped_images image_status co_broadcast co_max co_min co_sum co_reduce
syn keyword fortranIntrinsic    atomic_add atomic_and atomic_or atomic_xor atomic_fetch_add atomic_fetch_and atomic_fetch_or atomic_fetch_xor atomic_cas
syn keyword fortranIntrinsic    ieee_arithmetic ieee_features ieee_exceptions
syn keyword fortranIntrinsic	ieee_class ieee_copy_sign ieee_fma ieee_get_rounding_mode ieee_get_underflow_mode ieee_int ieee_is_finite
syn keyword fortranIntrinsic	ieee_is_nan ieee_is_negative ieee_is_normal ieee_logb ieee_max ieee_max_mag ieee_max_num ieee_max_num_mag
syn keyword fortranIntrinsic	ieee_min ieee_min_mag ieee_min_num ieee_min_num_mag ieee_next_after ieee_next_down ieee_next_up ieee_quiet_eq
syn keyword fortranIntrinsic	ieee_quiet_ge ieee_quiet_gt ieee_quiet_le ieee_quiet_lt ieee_quiet_ne ieee_real ieee_rem ieee_rint ieee_scalb
syn keyword fortranIntrinsic	ieee_selected_real_kind ieee_set_rounding_mode ieee_set_underflow_mode ieee_signaling_eq ieee_signaling_ge
syn keyword fortranIntrinsic	ieee_signaling_gt ieee_signaling_le ieee_signaling_lt ieee_signaling_ne ieee_signbit ieee_support_datatype
syn keyword fortranIntrinsic	ieee_support_denormal ieee_support_divide ieee_support_inf ieee_support_io ieee_support_nan ieee_support_rounding
syn keyword fortranIntrinsic	ieee_support_sqrt ieee_support_subnormal ieee_support_standard ieee_support_underflow_control
syn keyword fortranIntrinsic	ieee_unordered ieee_value ieee_get_flag ieee_get_halting_mode ieee_get_modes ieee_get_status
syn keyword fortranIntrinsic	ieee_set_flag ieee_set_halting_mode ieee_set_modes ieee_set_status ieee_support_flag ieee_support_halting
syn keyword fortranIntrinsic    iso_c_binding c_loc c_funloc c_sizeof c_associated c_f_pointer c_f_procpointer c_f_strpointer f_c_string
syn keyword fortranIntrinsic    iso_fortran_env compiler_options compiler_version
syn keyword fortranIntrinsic	out_of_range reduce random_init coshape get_team split tokenize
syn keyword fortranIntrinsic    acosd asind atand atan2d cosd sind tand acospi asinpi atanpi atan2pi cospi sinpi tanpi
syn match fortranIntrinsic      "\%(^\s*\|type *is *(\s*\)\@12<!\<real\ze\s*("
syn match fortranIntrinsic      '\<\%(logical\|not\|len\|kind\|rank\)\>\ze\s*('
syn match fortranIntrinsic      '\<\%(sign\|size\|team_number\)\>\ze\s*('
" Obsolescent type-specific intrinsics
syn keyword fortranIntrinsicOb	alog alog10 amax0 amax1 amin0 amin1 amod cabs ccos cexp clog csin csqrt dabs dacos dasin datan datan2 dcos dcosh ddim dexp dint dlog dlog10 dmax1 dmin1 dmod dnint dsign dsin dsinh dsqrt dtan dtanh float iabs idim idint idnint ifix isign max0 max1 min0 min1 sngl
if exists("fortran_vendor_intrinsics")
  syn keyword fortranIntrinsicVen	algama cdabs cdcos cdexp cdlog cdsin cdsqrt cqabs cqcos cqexp cqlog cqsin cqsqrt dcmplx dconjg derf derfc dfloat dgamma dimag dlgama iqint qabs qacos qasin qatan qatan2 qcmplx qconjg qcos qcosh qdim qerf qerfc qexp qgamma qimag qlgama qlog qlog10 qmax1 qmin1 qmod qnint qsign qsin qsinh qsqrt qtan qtanh
endif

syn keyword fortranType         generic final enumerator import classof typeof team_type event_type lock_type notify_type
syn keyword fortranType 	ieee_flag_type ieee_modes_type ieee_status_type ieee_class_type ieee_round_type ieee_features_type
syn keyword fortranType         c_ptr c_funptr elemental pure impure recursive non_recursive simple
syn match fortranType           "^\s*\%(implicit\s\+\)\?\%(real\|double\s*precision\|integer\|logical\|complex\|character\|type\)\>"
syn match fortranTypeOb         "^\s*\%(character\s*\)\@15<=\*"
syn match fortranType           "^\s*\zsimplicit\s\+none\>"
syn match fortranType           "\<class\>"
syn match fortranType           "\%(\<type\s\+is\s\+[(]\s*\)\@15<=\%(real\|double\s*precision\|integer\|logical\|complex\|character\)\>"
syn match fortranType           "\<\%(end\s*\)\?interface\>"
syn match fortranType           "\<enum\s*,\s*bind\s*(\s*c\s*)"
syn match fortranType           "\<end\s*\%(enum\|type\)\>"
syn match fortranType           "\<\%(end\s*\)\?enumeration\s\+type\>"
syn match fortranType           "\<\%(end\s*\)\?\%(module\s\+\)\?procedure\>"
syn match fortranType           "\%(simple \|pure \|impure \|recursive \|non_recursive \|elemental \|module \)\@17<=\%(real\|double precision\|integer\|logical\|complex\|character\)"
syn match fortranTypeR	       	display "\<double\s*precision\>"
syn match fortranTypeR  	display "\<double\s\+complex\>"
syn keyword fortranAttribute    abstract allocatable bind codimension contiguous deferred dimension extends
syn keyword fortranAttribute    external intent intrinsic non_intrinsic non_overridable nopass optional parameter pass
syn keyword fortranAttribute    pointer private protected public save sequence target value volatile
syn match fortranAttribute      "\<asynchronous\>\ze\s*\%(::\|,\|(\)"

syn keyword fortranUnitHeader	result operator assignment
syn match fortranUnitHeader     "\<\%(end\s*\)\?\%(subroutine\|function\|module\|program\|submodule\)\>"
syn match fortranBlock          "\<\%(end\s*\)\?\%(block\|critical\|associate\)\>"
syn match fortranCalled		"\<\%(call\s\+\)\@7<=\a\w*"
syn match fortranRepeat		"\<do\>"
syn keyword fortranRepeat       concurrent
syn keyword fortranRepeatR	while
syn match fortranRepeat         "\<end\s*do\>"
syn keyword fortranRepeatOb	forall
syn match fortranRepeatOb	"\<end\s*forall\>"

syn keyword fortranTodo		contained bug note debug todo fixme

"Catch errors caused by too many right parentheses
syn region fortranParen transparent start="(" end=")" contains=ALLBUT,fortranParenError,@fortranCommentGroup,cIncluded,@spell
syn match  fortranParenError   ")"

syn match fortranOperator	"\.\s*n\?eqv\s*\."
syn match fortranOperator	"\.\s*\%(and\|or\|not\)\s*\."
syn match fortranOperator	"\%(+\|-\|/\|\*\)"
syn match fortranOperator	"\%(\%(>\|<\)=\?\|==\|/=\|=\)"
syn match fortranOperator	"\%(%\|?\|=>\)"
syn match fortranOperator       "\%([\|]\)"
syn match fortranOperatorR	"\.\s*[gl][et]\s*\."
syn match fortranOperatorR	"\.\s*\%(eq\|ne\)\s*\."

syn keyword fortranReadWrite	print flush
syn match fortranReadWrite	'\<\%(backspace\|close\|endfile\|inquire\|open\|read\|rewind\|wait\|write\)\ze\s*('

"If tabs are allowed then the left margin checks do not work
if exists("fortran_have_tabs")
  syn match fortranTab		"\t"  transparent
else
  syn match fortranTab		"\t"
endif

"Numbers of various sorts
" Integers
syn match fortranNumber	display "\<\d\+\%(_\a\w*\)\?\>"
" floating point number, without a decimal point
syn match fortranFloatIll	display	"\<\d\+[deq][-+]\?\d\+\%(_\a\w*\)\?\>"
" floating point number, starting with a decimal point
syn match fortranFloatIll	display	"\.\d\+\%([deq][-+]\?\d\+\)\?\%(_\a\w*\)\?\>"
" floating point number, no digits after decimal
syn match fortranFloatIll	display	"\<\d\+\.\%([deq][-+]\?\d\+\)\?\%(_\a\w*\)\?\>"
" floating point number, D or Q exponents
syn match fortranFloatIll	display	"\<\d\+\.\d\+\%([dq][-+]\?\d\+\)\?\%(_\a\w*\)\?\>"
" floating point number
syn match fortranFloat	display	"\<\d\+\.\d\+\%(e[-+]\?\d\+\)\?\%(_\a\w*\)\?\>"
" binary number
syn match fortranBinary	display	"b["'][01]\+["']"
" octal number
syn match fortranOctal	display	"o["'][0-7]\+["']"
" hexadecimal number
syn match fortranHex	display	"z["'][0-9A-F]\+["']"
" Numbers in formats
syn match fortranFormatSpec	display	"\d*f\d\+\.\d\+"
syn match fortranFormatSpec	display	"\d*e[sn]\?\d\+\.\d\+\%(e\d+\>\)\?"
syn match fortranFormatSpec	display	"\d*\%(d\|q\|g\)\d\+\.\d\+\%(e\d+\)\?"
syn match fortranFormatSpec	display	"\d\+x\>"
" The next match cannot be used because it would pick up identifiers as well
" syn match fortranFormatSpec	display	"\<\%(a\|i\)\d\+"
" Numbers as labels
if (b:fortran_fixed_source == 1)
  syn match fortranLabelNumber	display	"^\zs\d\{1,5}\ze\s"
  syn match fortranLabelNumber	display	"^ \zs\d\{1,4}\ze\s"
  syn match fortranLabelNumber	display	"^  \zs\d\{1,3}\ze\s"
  syn match fortranLabelNumber	display	"^   \zs\d\d\?\ze\s"
  syn match fortranLabelNumber	display	"^    \zs\d\ze\s"
else
  syn match fortranLabelNumber	        display	"^\s*\zs\d\{1,5}\ze\s*\a"
  syn match fortranLabelNumberOb	display	"^\s*\zs\d\{1,5}\ze *end\s*\%(do\|if\)\>\ze"
endif
" Numbers as targets
syn match fortranTarget 	display	"\%(\<if\s*(.\+)\s*\)\@<=\%(\d\+\s*,\s*\)\{2}\d\+\>"
syn match fortranTargetOb	display	"\%(\<do\s*,\?\s*\)\@11<=\d\+\>"
syn match fortranTarget 	display	"\%(\<go\s*to\s*(\?\)\@11<=\%(\d\+\s*,\s*\)*\d\+\>"

syn match fortranBoolean	"\.\s*\%(true\|false\)\s*\."

syn keyword fortranKeyword      call use only continue allocate deallocate nullify return cycle exit contains
syn match fortranKeyword        "\<fail\s\+image\>"
syn match fortranKeyword	"\<\%(error\s\+\)\?stop\>"
syn match fortranKeyword  	"\<go\s*to\>"
syn match fortranKeywordDel  	"\<go\s*to\ze\s\+.*,\s*(.*$"
syn match fortranKeywordOb  	"\<go\s*to\ze\s*(\d\+.*$"
syn keyword fortranKeywordDel	pause
syn match fortranKeywordDel	"assign\s*\d\+\s*to\s\+\a\w*"

syn match fortranStringDel      display "[/(,] *\d\+H"
syn region fortranString 	start=+'+ end=+'+	contains=fortranLeftMargin,fortranContinueMark,fortranSerialNumber
syn region fortranString	start=+"+ end=+"+	contains=fortranLeftMargin,fortranContinueMark,fortranSerialNumber

syn match fortranSpecifier     	'\%(\%((\|,\|, *&\n\)\s*\)\@<=\%(access\|acquired_lock\|action\|advance\|asynchronous\|blank\|decimal\|delim\|direct\|encoding\|end\|eor\|err\)\ze\s*='
syn match fortranSpecifier     	'\%(\%((\|,\|, *&\n\)\s*\)\@<=\%(errmsg\|exist\|file\|fmt\|form\|formatted\|id\|iolength\|iomsg\|iostat\|leading_zero\|mold\|name\|named\)\ze\s*='
syn match fortranSpecifier     	'\%(\%((\|,\|, *&\n\)\s*\)\@<=\%(new_index\|newunit\|nextrec\|nml\|notify\|number\|opened\|pad\|pending\|pos\|position\|quiet\)\ze\s*='
syn match fortranSpecifier     	'\%(\%((\|,\|, *&\n\)\s*\)\@<=\%(read\|readwrite\|rec\|recl\|round\|sequential\|sign\|size\)\ze\s*='
syn match fortranSpecifier     	'\%(\%((\|,\|, *&\n\)\s*\)\@<=\%(source\|stat\|status\|stream\|team\|team_number\|unformatted\|unit\|until_count\|write\)\ze\s*='
syn match fortranSpecifier      "\%((\s*\)\@<=\%(un\)\?formatted\ze\s*)"
syn match fortranSpecifier      "\%(local\|local_init\|reduce\|shared\)\ze\s*("
syn match fortranSpecifier      "\<default\s*(\s*none\s*)"
syn keyword fortranIOR		format namelist

syn keyword fortranConditional	else then where elsewhere
syn match fortranConditional    "\<\%(else\s*\)\?if\>"
syn match fortranConditional    "\<\%(end\s*\)\?\%(if\|where\|select\)\>"
syn match fortranConditional    "\<select\s*\%(case\|rank\|type\)\>"
syn match fortranConditional    "\<\%(case\|rank\|class\)\s\+default\>"
syn match fortranConditional    "^\s*\zs\%(case\|rank\)\ze\s\+("
syn match fortranConditional    "\<\%(class\|type\)\s\+is\>"
syn match fortranConditionalDel	"\<if\s*(.*)\s*\d\+\s*,\s*\d\+\s*,\s*\d\+\s*$"

syn keyword fortranInclude		include

syn match fortranImageControl   "\<sync\s\+\%(all\|images\|memory\|team\)\>"
syn match fortranImageControl   "\<\%(change\|form\|end\)\s\+team\>"
syn match fortranImageControl   "\<event\s\+\%(post\|wait\)"
syn match fortranImageControl   "\<\%(un\)\?lock\ze\s*("
syn match fortranImageControl   "\<notify\s\+wait\ze\s*("

syn keyword fortranUnitHeaderOb	entry
syn match fortranUnitHeaderOb	display "\<block\s*data\>"

syn keyword fortranStorageClass	        in out inout
syn match fortranStorageClass           '\<\%(kind\|len\)\>\ze\s*='
syn match fortranStorageClass           "^\s*data\>\ze\%(\s\+\a\)\@="
syn match fortranStorageClassOb         "\<common\>\%(\s*\%(/\|\a\)\)\@="
syn match fortranStorageClassOb         "\<equivalence\>\%(\s*(\)\@="

syn keyword fortranConstant             c_null_char c_alert c_backspace c_form_feed c_new_line c_carriage_return c_horizontal_tab c_vertical_tab c_ptrdiff_t
syn keyword fortranConstant             c_int c_short c_long c_long_long c_signed_char c_size_t c_int8_t c_int16_t c_int32_t c_int64_t c_int_least8_t c_int_least16_t c_int_least32_t c_int_least64_t c_int_fast8_t c_int_fast16_t c_int_fast32_t c_int_fast64_t c_intmax_t C_intptr_t c_float c_double c_long_double c_float_complex c_double_complex c_long_double_complex c_bool c_char c_null_ptr c_null_funptr
syn keyword fortranConstant             character_storage_size error_unit file_storage_size input_unit iostat_end iostat_eor numeric_storage_size output_unit stat_failed_image stat_locked stat_locked_other_image stat_stopped_image stat_unlocked stat_unlocked_failed_image
syn keyword fortranConstant             int8 int16 int32 int64 real16 real32 real64 real128 character_kinds integer_kinds logical_kinds real_kinds iostat_inquire_internal_unit initial_team current_team parent_team
syn keyword fortranConstant             ieee_invalid ieee_overflow ieee_divide_by_zero ieee_underflow ieee_inexact ieee_usual ieee_all
syn keyword fortranConstant             ieee_signaling_nan ieee_quiet_nan ieee_negative_inf ieee_negative_normal ieee_negative_subnormal
syn keyword fortranConstant             ieee_negative_zero ieee_positive_zero ieee_positive_subnormal ieee_positive_normal ieee_positive_inf
syn keyword fortranConstant             ieee_other_value ieee_negative_denormal ieee_positive_denormal ieee_negative_subnormal
syn keyword fortranConstant             ieee_positive_subnormal ieee_nearest ieee_to_zero ieee_up ieee_down ieee_away ieee_other ieee_datatype
syn keyword fortranConstant             ieee_denormal ieee_divide ieee_halting ieee_inexact_flag ieee_inf ieee_invalid_flag ieee_nan
syn keyword fortranConstant             ieee_rounding ieee_sqrt ieee_subnormal ieee_underflow_flag
syn match fortranConstant	        "\.\s*nil\s*\."

" CUDA Fortran
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

  syn match fortranStringCUDA         "\<blockidx%[xyz]\>"
  syn match fortranStringCUDA         "\<blockdim%[xyz]\>"
  syn match fortranStringCUDA         "\<griddim%[xyz]\>"
  syn match fortranStringCUDA         "\<threadidx%[xyz]\>"

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
syn match fortranOpenMP		excludenl 		"^\s*\zs!\$\%(OMP\)\?&\?\s.*$"
syn match fortranEndStatement   display ";"

"cpp is often used with Fortran
syn match	cPreProc		"^\s*#\s*\%(define\|ifdef\)\>.*"
syn match	cPreProc		"^\s*#\s*\%(elif\|if\)\>.*"
syn match	cPreProc		"^\s*#\s*\%(ifndef\|undef\)\>.*"
syn match	cPreCondit		"^\s*#\s*\%(else\|endif\)\>.*"
syn region	cIncluded	contained start=+"[^("]+ skip=+\\\\\|\\"+ end=+"+ contains=fortranLeftMargin,fortranContinueMark,fortranSerialNumber
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
    syn region fortranProgram transparent fold keepend start="^\s*program\s\+\z(\a\w*\)" skip="^\%([!c*]\|\s*#\).*$" excludenl end="\<end\s*\%(program\%(\s\+\z1\>\)\?\|$\)" contains=ALLBUT,fortranModule
    syn region fortranModule transparent fold keepend start="^\s*submodule\s\+(\a\w*\s*\%(:\a\w*\s*\)*)\s*\z\(\a\w*\)" skip="^\%([!c*]\|\s*#\).*$" excludenl end="\<end\s*\%(submodule\%(\s\+\z1\>\)\?\|$\)" contains=ALLBUT,fortranProgram,fortranModule
    syn region fortranModule transparent fold keepend start="^\s*module\s\+\%(procedure\)\@9!\z(\a\w*\)" skip="^\%([!c*]\|\s*#\).*$" excludenl end="\<end\s*\%(module\%(\s\+\z1\>\)\?\|$\)" contains=ALLBUT,fortranProgram
    syn region fortranFunction transparent fold keepend extend start="\<function\s\+\z(\a\w*\)" skip="^\%([!c*]\|\s*#\).*$" excludenl end="\<end\s*\%($\|function\%(\s\+\z1\>\)\?\)" contains=ALLBUT,fortranProgram,fortranModule
    syn region fortranSubroutine transparent fold keepend extend start="\<subroutine\s\+\z(\a\w*\)" skip="^\%([!c*]\|\s*#\).*$" excludenl end="\<end\s*\%($\|subroutine\%(\s\+\z1\>\)\?\)" contains=ALLBUT,fortranProgram,fortranModule
    syn region fortranBlockData transparent fold keepend start="\<block\>" skip="^\%([!c*]\|\s*#\).*$" excludenl end="\<end\s*block\>" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortran77Loop,fortranCase,fortran90Loop,fortranIfBlock
    syn region fortranAssociate transparent fold keepend start="\<associate\s\+" skip="^\%([!c*]\|\s*#\).*$" excludenl end="\<end\s*associate" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction
    syn region fortranCritical transparent fold keepend start="\<critical\s\+" skip="^\%([!c*]\|\s*#\).*$" excludenl end="\<end\s*critical" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction
    syn region fortranTeam transparent fold keepend start="\<change\s\+team\>" skip="^\%([!c*]\|\s*#\).*$" excludenl end="\<end\s*team\>" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction
    syn region fortranInterface transparent fold keepend extend start="\<\%(abstract \)\?\s*interface\>" skip="^\%([!c*]\|\s*#\).*$" excludenl end="\<end\s*interface\>" contains=ALLBUT,fortranProgram,fortranModule,fortran77Loop,fortranCase,fortran90Loop,fortranIfBlock
    syn region fortranTypeDef transparent fold keepend extend start="^\s*type\s*\%(,\s*\%(abstract\|private\|public\|bind(c)\|extends(\a\w*)\)\)\{0,4}\s*::\s*\z(\a\w*\)" skip="^\%([!c*]\|\s*#\).*$" excludenl end="\<end\s*type\>\%(\s\+\z1\>\)\?" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction
    syn region fortranMultiComments fold  start="^\zs[!c*].*\_s*[!c*]"	skip="^[!c*]"	end='^\ze\s*[^!c*]'
  else
    syn region fortranProgram transparent fold keepend start="^\s*program\s\+\z(\a\w*\)" skip="^\s*[!#].*$" excludenl end="\<end\s*\%(program\%(\s\+\z1\>\)\?\|$\)" contains=ALLBUT,fortranModule
    syn region fortranModule transparent fold keepend start="^\s*submodule\s\+(\a\w*\s*\%(:\a\w*\s*\)*)\s*\z\(\a\w*\)" skip="^\s*[!#].*$" excludenl end="\<end\s*\%(submodule\%(\s\+\z1\>\)\?\|$\)" contains=ALLBUT,fortranProgram,fortranModule
    syn region fortranModule transparent fold keepend start="^\s*module\s\+\%(procedure\)\@9!\z(\a\w*\)" skip="^\s*[!#].*$" excludenl end="\<end\s*\%(module\%(\s\+\z1\>\)\?\|$\)" contains=ALLBUT,fortranProgram
    syn region fortranFunction transparent fold keepend extend start="\<function\s\+\z(\a\w*\)" skip="^\s*[!#].*$" excludenl end="\<end\s*\%($\|function\%(\s\+\z1\>\)\?\)" contains=ALLBUT,fortranProgram,fortranModule
    syn region fortranSubroutine transparent fold keepend extend start="\<subroutine\s\+\z(\a\w*\)" skip="^\s*[!#].*$" excludenl end="\<end\s*\%($\|subroutine\%(\s\+\z1\>\)\?\)" contains=ALLBUT,fortranProgram,fortranModule
    syn region fortranBlockData transparent fold keepend start="\<block\>" skip="^\s*[!#].*$" excludenl end="\<end\s*block\>" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortran77Loop,fortranCase,fortran90Loop,fortranIfBlock
    syn region fortranAssociate transparent fold keepend start="\<associate\>" skip="^\s*[!#].*$" excludenl end="\<end\s*associate\>" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction
    syn region fortranCritical transparent fold keepend start="\<critical\>" skip="^\s*[!#].*$" excludenl end="\<end\s*critical\>" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction
    syn region fortranTeam transparent fold keepend start="\<change\s\+team\>" skip="^\s*[!#].*$" excludenl end="\<end\s*team\>" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction
    syn region fortranInterface transparent fold keepend extend start="\<\%(abstract \)\?\s*interface\>" skip="^\s*[!#].*$" excludenl end="\<end\s*interface\>" contains=ALLBUT,fortranProgram,fortranModule,fortran77Loop,fortranCase,fortran90Loop,fortranIfBlock
    syn region fortranTypeDef transparent fold keepend extend start="^\s*type\s*\%(,\s*\%(abstract\|private\|public\|bind(c)\|extends(\a\w*)\)\)\{0,4}\s*::\s*\z(\a\w*\)" skip="^\s*[!#].*$" excludenl end="\<end\s*type\>\%(\s\+\z1\>\)\?" contains=ALLBUT,fortranProgram,fortranModule,fortranSubroutine,fortranFunction
    syn region fortranMultiComments fold  start="^\zs\s*!.*\_s*!"	skip="^\s*!"	end='^\ze\s*[^!]'
  endif

  if exists("fortran_fold_conditionals")
    if (b:fortran_fixed_source == 1)
      syn region fortran77Loop transparent fold keepend start="\<do\s\+\z(\d\+\)" end="^\s*\z1\>" contains=ALLBUT,fortranUnitHeader,fortranAttribute,fortranStorageClass,fortranType,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortranBlockData
      syn region fortran90Loop transparent fold keepend extend start="\%(\<end\s\+\)\@5<!\<do\%(\s\+\a\|\s*$\)" skip="^\%([!c*]\|\s*#\).*$" excludenl end="\<end\s*do\>" contains=ALLBUT,fortranUnitHeader,fortranAttribute,fortranStorageClass,fortranType,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortranBlockData
      syn region fortranIfBlock transparent fold keepend extend start="\%(\<e\%(nd\|lse\)\s\+\)\@6<!\<if\s*(.\+)\s*then\>" skip="^\%([!c*]\|\s*#\).*$" end="\<end\s*if\>" contains=ALLBUT,fortranUnitHeader,fortranAttribute,fortranStorageClass,fortranType,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortranBlockData
      syn region fortranCase transparent fold keepend extend start="\<select\s*\%(case\|type\|rank\)\>" skip="^\%([!c*]\|\s*#\).*$" end="\<end\s*select\>" contains=ALLBUT,fortranUnitHeader,fortranAttribute,fortranStorageClass,fortranType,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortranBlockData
    else
      syn region fortran77Loop transparent fold keepend start="\<do\s\+\z(\d\+\)" end="^\s*\z1\>" contains=ALLBUT,fortranUnitHeader,fortranAttribute,fortranStorageClass,fortranType,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortranBlockData
      syn region fortran90Loop transparent fold keepend extend start="\%(\<end\s\+\)\@5<!\<do\%(\s\+\a\|\s*$\)" skip="^\s*[!#].*$" excludenl end="\<end\s*do\>" contains=ALLBUT,fortranUnitHeader,fortranAttribute,fortranStorageClass,fortranType,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortranBlockData
      syn region fortranIfBlock transparent fold keepend extend start="\%(\<e\%(nd\|lse\)\s\+\)\@6<!\<if\s*(\%(.\|&\s*\n\)\+)\%(\s\|&\s*\n\)*then\>" skip="^\s*[!#].*$" end="\<end\s*if\>" contains=ALLBUT,fortranUnitHeader,fortranAttribute,fortranStorageClass,fortranType,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortranBlockData
      syn region fortranCase transparent fold keepend extend start="\<select\s*\%(case\|type\|rank\)\>" skip="^\s*[!#].*$" end="\<end\s*select\>" contains=ALLBUT,fortranUnitHeader,fortranAttribute,fortranStorageClass,fortranType,fortranProgram,fortranModule,fortranSubroutine,fortranFunction,fortranBlockData
    endif
  endif

endif

" Define the default highlighting.
hi def link fortranBoolean	        Boolean
hi def link fortranComment     		Comment
hi def link fortranMultiComments        Comment
hi def link fortranBlock                Conditional
hi def link fortranConditional	        Conditional
hi def link fortranConstant     	Constant
hi def link fortranConditionalDel 	Error
hi def link fortranKeywordDel     	Error
hi def link fortranLabelError	        Error
hi def link fortranParenError  		Error
hi def link fortranStringDel            Error
hi def link fortranTab		        Error
hi def link fortranFloat       		Float
hi def link fortranFloatIll             Float
hi def link fortranCalled               Function
hi def link fortranIntrinsic            Function
hi def link fortranIntrinsicCUDA        Function
hi def link fortranIntrinsicR   	Function
hi def link fortranIntrinsicVen 	Function
hi def link fortranUnitName     	Function
hi def link fortranConstructName	Identifier
hi def link fortranFormatSpec  		Identifier
hi def link cInclude    		Include
hi def link fortranInclude              Include
hi def link fortranIOR  		Keyword
hi def link fortranImageControl         Keyword
hi def link fortranKeyword 	        Keyword
hi def link fortranReadWrite            Keyword
hi def link fortranSpecifier		Keyword
hi def link fortranBinary	        Number
hi def link fortranHex  	        Number
hi def link fortranNumber	        Number
hi def link fortranBinary	        Number
hi def link fortranOctal	        Number
hi def link fortranOperator	        Operator
hi def link fortranOperatorR	        Operator
hi def link cPreCondit  		PreCondit
hi def link fortranUnitHeader           PreCondit
hi def link fortranOpenMP      		PreProc
hi def link cPreProc    		PreProc
hi def link fortranRepeat	        Repeat
hi def link fortranRepeatR  		Repeat
hi def link fortranContinueMark	        Special
hi def link fortranEndStatement	        Special
hi def link fortranLabelNumber          Special
hi def link fortranTarget               Special
hi def link fortranStorageClass         StorageClass
hi def link cIncluded   		String
hi def link fortranString	        String
hi def link fortranStringCUDA           String
hi def link fortranIntrinsicOb    	Todo
hi def link fortranKeywordOb      	Todo
hi def link fortranLabelNumberOb        Todo
hi def link fortranRepeatOb       	Todo
hi def link fortranSerialNumber	        Todo
hi def link fortranStorageClassOb 	Todo
hi  def link fortranTargetOb         	Todo
hi def link fortranTodo		        Todo
hi def link fortranTypeOb         	Todo
hi def link fortranUnitHeaderOb   	Todo
hi def link fortranAttribute	        Type
hi def link fortranType		        Type
hi def link fortranTypeCUDA             Type
hi def link fortranTypeR		Type

let b:current_syntax = "fortran"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8 tw=132
