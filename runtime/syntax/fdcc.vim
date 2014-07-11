" Vim syntax file
" Language:	fdcc or locale files
" Maintainer:	Dwayne Bailey <dwayne@translate.org.za>
" Last Change:	2004 May 16
" Remarks:      FDCC (Formal Definitions of Cultural Conventions) see ISO TR 14652

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn sync minlines=150
setlocal iskeyword+=-

" Numbers
syn match fdccNumber /[0-9]*/ contained

" Unicode codings and strings
syn match fdccUnicodeInValid /<[^<]*>/ contained
syn match fdccUnicodeValid /<U[0-9A-F][0-9A-F][0-9A-F][0-9A-F]>/ contained
syn region fdccString start=/"/ end=/"/ contains=fdccUnicodeInValid,fdccUnicodeValid

" Valid LC_ Keywords
syn keyword fdccKeyword escape_char comment_char
syn keyword fdccKeywordIdentification title source address contact email tel fax language territory revision date category
syn keyword fdccKeywordCtype copy space translit_start include translit_end outdigit class
syn keyword fdccKeywordCollate copy script order_start order_end collating-symbol reorder-after reorder-end collating-element symbol-equivalence
syn keyword fdccKeywordMonetary copy int_curr_symbol currency_symbol mon_decimal_point mon_thousands_sep mon_grouping positive_sign negative_sign int_frac_digits frac_digits p_cs_precedes p_sep_by_space n_cs_precedes n_sep_by_space p_sign_posn n_sign_posn int_p_cs_precedes int_p_sep_by_space int_n_cs_precedes int_n_sep_by_space  int_p_sign_posn int_n_sign_posn
syn keyword fdccKeywordNumeric copy decimal_point thousands_sep grouping
syn keyword fdccKeywordTime copy abday day abmon mon d_t_fmt d_fmt t_fmt am_pm t_fmt_ampm date_fmt era_d_fmt first_weekday first_workday week cal_direction time_zone era alt_digits era_d_t_fmt
syn keyword fdccKeywordMessages copy yesexpr noexpr yesstr nostr
syn keyword fdccKeywordPaper copy height width
syn keyword fdccKeywordTelephone copy tel_int_fmt int_prefix tel_dom_fmt int_select
syn keyword fdccKeywordMeasurement copy measurement
syn keyword fdccKeywordName copy name_fmt name_gen name_mr name_mrs name_miss name_ms
syn keyword fdccKeywordAddress copy postal_fmt country_name country_post country_ab2 country_ab3  country_num country_car  country_isbn lang_name lang_ab lang_term lang_lib

" Comments
syn keyword fdccTodo TODO FIXME contained
syn match fdccVariable /%[a-zA-Z]/ contained
syn match fdccComment /[#%].*/ contains=fdccTodo,fdccVariable

" LC_ Groups
syn region fdccBlank matchgroup=fdccLCIdentification start=/^LC_IDENTIFICATION$/ end=/^END LC_IDENTIFICATION$/ contains=fdccKeywordIdentification,fdccString,fdccComment
syn region fdccBlank matchgroup=fdccLCCtype start=/^LC_CTYPE$/ end=/^END LC_CTYPE$/ contains=fdccKeywordCtype,fdccString,fdccComment,fdccUnicodeInValid,fdccUnicodeValid
syn region fdccBlank matchgroup=fdccLCCollate start=/^LC_COLLATE$/ end=/^END LC_COLLATE$/ contains=fdccKeywordCollate,fdccString,fdccComment,fdccUnicodeInValid,fdccUnicodeValid
syn region fdccBlank matchgroup=fdccLCMonetary start=/^LC_MONETARY$/ end=/^END LC_MONETARY$/ contains=fdccKeywordMonetary,fdccString,fdccComment,fdccNumber
syn region fdccBlank matchgroup=fdccLCNumeric start=/^LC_NUMERIC$/ end=/^END LC_NUMERIC$/ contains=fdccKeywordNumeric,fdccString,fdccComment,fdccNumber
syn region fdccBlank matchgroup=fdccLCTime start=/^LC_TIME$/ end=/^END LC_TIME$/ contains=fdccKeywordTime,fdccString,fdccComment,fdccNumber
syn region fdccBlank matchgroup=fdccLCMessages start=/^LC_MESSAGES$/ end=/^END LC_MESSAGES$/ contains=fdccKeywordMessages,fdccString,fdccComment
syn region fdccBlank matchgroup=fdccLCPaper start=/^LC_PAPER$/ end=/^END LC_PAPER$/ contains=fdccKeywordPaper,fdccString,fdccComment,fdccNumber
syn region fdccBlank matchgroup=fdccLCTelephone start=/^LC_TELEPHONE$/ end=/^END LC_TELEPHONE$/ contains=fdccKeywordTelephone,fdccString,fdccComment
syn region fdccBlank matchgroup=fdccLCMeasurement start=/^LC_MEASUREMENT$/ end=/^END LC_MEASUREMENT$/ contains=fdccKeywordMeasurement,fdccString,fdccComment,fdccNumber
syn region fdccBlank matchgroup=fdccLCName start=/^LC_NAME$/ end=/^END LC_NAME$/ contains=fdccKeywordName,fdccString,fdccComment
syn region fdccBlank matchgroup=fdccLCAddress start=/^LC_ADDRESS$/ end=/^END LC_ADDRESS$/ contains=fdccKeywordAddress,fdccString,fdccComment,fdccNumber


" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_fdcc_syn_inits")
  if version < 508
    let did_fdcc_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink fdccBlank		 Blank

  HiLink fdccTodo		 Todo
  HiLink fdccComment		 Comment
  HiLink fdccVariable		 Type

  HiLink fdccLCIdentification	 Statement
  HiLink fdccLCCtype		 Statement
  HiLink fdccLCCollate		 Statement
  HiLink fdccLCMonetary		 Statement
  HiLink fdccLCNumeric		 Statement
  HiLink fdccLCTime		 Statement
  HiLink fdccLCMessages		 Statement
  HiLink fdccLCPaper		 Statement
  HiLink fdccLCTelephone	 Statement
  HiLink fdccLCMeasurement	 Statement
  HiLink fdccLCName		 Statement
  HiLink fdccLCAddress		 Statement

  HiLink fdccUnicodeInValid	 Error
  HiLink fdccUnicodeValid	 String
  HiLink fdccString		 String
  HiLink fdccNumber		 Blank

  HiLink fdccKeywordIdentification fdccKeyword
  HiLink fdccKeywordCtype	   fdccKeyword
  HiLink fdccKeywordCollate	   fdccKeyword
  HiLink fdccKeywordMonetary	   fdccKeyword
  HiLink fdccKeywordNumeric	   fdccKeyword
  HiLink fdccKeywordTime	   fdccKeyword
  HiLink fdccKeywordMessages	   fdccKeyword
  HiLink fdccKeywordPaper	   fdccKeyword
  HiLink fdccKeywordTelephone	   fdccKeyword
  HiLink fdccKeywordMeasurement    fdccKeyword
  HiLink fdccKeywordName	   fdccKeyword
  HiLink fdccKeywordAddress	   fdccKeyword
  HiLink fdccKeyword		   Identifier

  delcommand HiLink
endif

let b:current_syntax = "fdcc"

" vim: ts=8
