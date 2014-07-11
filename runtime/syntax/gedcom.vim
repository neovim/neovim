" Vim syntax file
" Language:	Gedcom
" Maintainer:	Paul Johnson (pjcj@transeda.com)
" Version 1.059 - 23rd December 1999

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syntax case match

syntax keyword gedcom_record ABBR ADDR ADOP ADR1 ADR2 AFN AGE AGNC ALIA ANCE
syntax keyword gedcom_record ANCI ANUL ASSO AUTH BAPL BAPM BARM BASM BIRT BLES
syntax keyword gedcom_record BLOB BURI CALN CAST CAUS CENS CHAN CHAR CHIL CHR
syntax keyword gedcom_record CHRA CITY CONC CONF CONL CONT COPR CORP CREM CTRY
syntax keyword gedcom_record DATA DEAT DESC DESI DEST DIV DIVF DSCR EDUC EMIG
syntax keyword gedcom_record ENDL ENGA EVEN FAM FAMC FAMF FAMS FCOM FILE FORM
syntax keyword gedcom_record GEDC GIVN GRAD HEAD HUSB IDNO IMMI INDI LANG MARB
syntax keyword gedcom_record MARC MARL MARR MARS MEDI NATI NATU NCHI NICK NMR
syntax keyword gedcom_record NOTE NPFX NSFX OBJE OCCU ORDI ORDN PAGE PEDI PHON
syntax keyword gedcom_record PLAC POST PROB PROP PUBL QUAY REFN RELA RELI REPO
syntax keyword gedcom_record RESI RESN RETI RFN RIN ROLE SEX SLGC SLGS SOUR
syntax keyword gedcom_record SPFX SSN STAE STAT SUBM SUBN SURN TEMP TEXT TIME
syntax keyword gedcom_record TITL TRLR TYPE VERS WIFE WILL
syntax keyword gedcom_record DATE nextgroup=gedcom_date
syntax keyword gedcom_record NAME nextgroup=gedcom_name

syntax case ignore

syntax region gedcom_id start="@" end="@" oneline contains=gedcom_ii, gedcom_in
syntax match gedcom_ii "\I\+" contained nextgroup=gedcom_in
syntax match gedcom_in "\d\+" contained
syntax region gedcom_name start="" end="$" skipwhite oneline contains=gedcom_cname, gedcom_surname contained
syntax match gedcom_cname "\i\+" contained
syntax match gedcom_surname "/\(\i\|\s\)*/" contained
syntax match gedcom_date "\d\{1,2}\s\+\(jan\|feb\|mar\|apr\|may\|jun\|jul\|aug\|sep\|oct\|nov\|dec\)\s\+\d\+"
syntax match gedcom_date ".*" contained

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_gedcom_syntax_inits")
  if version < 508
    let did_gedcom_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink gedcom_record Statement
  HiLink gedcom_id Comment
  HiLink gedcom_ii PreProc
  HiLink gedcom_in Type
  HiLink gedcom_name PreProc
  HiLink gedcom_cname Type
  HiLink gedcom_surname Identifier
  HiLink gedcom_date Constant

  delcommand HiLink
endif

let b:current_syntax = "gedcom"
