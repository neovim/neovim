" Vim syntax file
" Language:	fdcc or locale files
" Maintainer:	Dwayne Bailey <dwayne@translate.org.za>
" Last Change:	2004 May 16
" Remarks:      FDCC (Formal Definitions of Cultural Conventions) see ISO TR 14652

" quit when a syntax file was already loaded
if exists("b:current_syntax")
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


" Only when an item doesn't have highlighting yet

hi def link fdccBlank		 Blank

hi def link fdccTodo		 Todo
hi def link fdccComment		 Comment
hi def link fdccVariable		 Type

hi def link fdccLCIdentification	 Statement
hi def link fdccLCCtype		 Statement
hi def link fdccLCCollate		 Statement
hi def link fdccLCMonetary		 Statement
hi def link fdccLCNumeric		 Statement
hi def link fdccLCTime		 Statement
hi def link fdccLCMessages		 Statement
hi def link fdccLCPaper		 Statement
hi def link fdccLCTelephone	 Statement
hi def link fdccLCMeasurement	 Statement
hi def link fdccLCName		 Statement
hi def link fdccLCAddress		 Statement

hi def link fdccUnicodeInValid	 Error
hi def link fdccUnicodeValid	 String
hi def link fdccString		 String
hi def link fdccNumber		 Blank

hi def link fdccKeywordIdentification fdccKeyword
hi def link fdccKeywordCtype	   fdccKeyword
hi def link fdccKeywordCollate	   fdccKeyword
hi def link fdccKeywordMonetary	   fdccKeyword
hi def link fdccKeywordNumeric	   fdccKeyword
hi def link fdccKeywordTime	   fdccKeyword
hi def link fdccKeywordMessages	   fdccKeyword
hi def link fdccKeywordPaper	   fdccKeyword
hi def link fdccKeywordTelephone	   fdccKeyword
hi def link fdccKeywordMeasurement    fdccKeyword
hi def link fdccKeywordName	   fdccKeyword
hi def link fdccKeywordAddress	   fdccKeyword
hi def link fdccKeyword		   Identifier


let b:current_syntax = "fdcc"

" vim: ts=8
