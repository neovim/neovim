" Vim syntax file
" Language:	Software Distributor product specification file
"		(POSIX 1387.2-1995).
" Maintainer:	Rex Barzee <rex_barzee@hp.com>
" Last change:	25 Apr 2001

if version < 600
  " Remove any old syntax stuff hanging around
  syn clear
elseif exists("b:current_syntax")
  finish
endif

" Product specification files are case sensitive
syn case match

syn keyword psfObject bundle category control_file depot distribution
syn keyword psfObject end file fileset host installed_software media
syn keyword psfObject product root subproduct vendor

syn match  psfUnquotString +[^"# 	][^#]*+ contained
syn region psfQuotString   start=+"+ skip=+\\"+ end=+"+ contained

syn match  psfObjTag    "\<[-_+A-Z0-9a-z]\+\(\.[-_+A-Z0-9a-z]\+\)*" contained
syn match  psfAttAbbrev ",\<\(fa\|fr\|[aclqrv]\)\(<\|>\|<=\|>=\|=\|==\)[^,]\+" contained
syn match  psfObjTags   "\<[-_+A-Z0-9a-z]\+\(\.[-_+A-Z0-9a-z]\+\)*\(\s\+\<[-_+A-Z0-9a-z]\+\(\.[-_+A-Z0-9a-z]\+\)*\)*" contained

syn match  psfNumber    "\<\d\+\>" contained
syn match  psfFloat     "\<\d\+\>\(\.\<\d\+\>\)*" contained

syn match  psfLongDate  "\<\d\d\d\d\d\d\d\d\d\d\d\d\.\d\d\>" contained

syn keyword psfState    available configured corrupt installed transient contained
syn keyword psfPState   applied committed superseded contained

syn keyword psfBoolean  false true contained


"Some of the attributes covered by attUnquotString and attQuotString:
" architecture category_tag control_directory copyright
" create_date description directory file_permissions install_source
" install_type location machine_type mod_date number os_name os_release
" os_version pose_as_os_name pose_as_os_release readme revision
" share_link title vendor_tag
syn region psfAttUnquotString matchgroup=psfAttrib start=~^\s*[^# 	]\+\s\+[^#" 	]~rs=e-1 contains=psfUnquotString,psfComment end=~$~ keepend oneline

syn region psfAttQuotString matchgroup=psfAttrib start=~^\s*[^# 	]\+\s\+"~rs=e-1 contains=psfQuotString,psfComment skip=~\\"~ matchgroup=psfQuotString end=~"~ keepend


" These regions are defined in attempt to do syntax checking for some
" of the attributes.
syn region psfAttTag matchgroup=psfAttrib start="^\s*tag\s\+" contains=psfObjTag,psfComment end="$" keepend oneline

syn region psfAttSpec matchgroup=psfAttrib start="^\s*\(ancestor\|applied_patches\|applied_to\|contents\|corequisites\|exrequisites\|prerequisites\|software_spec\|supersedes\|superseded_by\)\s\+" contains=psfObjTag,psfAttAbbrev,psfComment end="$" keepend

syn region psfAttTags matchgroup=psfAttrib start="^\s*all_filesets\s\+" contains=psfObjTags,psfComment end="$" keepend

syn region psfAttNumber matchgroup=psfAttrib start="^\s*\(compressed_size\|instance_id\|media_sequence_number\|sequence_number\|size\)\s\+" contains=psfNumber,psfComment end="$" keepend oneline

syn region psfAttTime matchgroup=psfAttrib start="^\s*\(create_time\|ctime\|mod_time\|mtime\|timestamp\)\s\+" contains=psfNumber,psfComment end="$" keepend oneline

syn region psfAttFloat matchgroup=psfAttrib start="^\s*\(data_model_revision\|layout_version\)\s\+" contains=psfFloat,psfComment end="$" keepend oneline

syn region psfAttLongDate matchgroup=psfAttrib start="^\s*install_date\s\+" contains=psfLongDate,psfComment end="$" keepend oneline

syn region psfAttState matchgroup=psfAttrib start="^\s*\(state\)\s\+" contains=psfState,psfComment end="$" keepend oneline

syn region psfAttPState matchgroup=psfAttrib start="^\s*\(patch_state\)\s\+" contains=psfPState,psfComment end="$" keepend oneline

syn region psfAttBoolean matchgroup=psfAttrib start="^\s*\(is_kernel\|is_locatable\|is_patch\|is_protected\|is_reboot\|is_reference\|is_secure\|is_sparse\)\s\+" contains=psfBoolean,psfComment end="$" keepend oneline

syn match  psfComment "#.*$"


" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_psf_syntax_inits")
  if version < 508
    let did_psf_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink psfObject       Statement
  HiLink psfAttrib       Type
  HiLink psfQuotString   String
  HiLink psfObjTag       Identifier
  HiLink psfAttAbbrev    PreProc
  HiLink psfObjTags      Identifier

  HiLink psfComment      Comment

  delcommand HiLink
endif

" Long descriptions and copyrights confuse the syntax highlighting, so
" force vim to backup at least 100 lines before the top visible line
" looking for a sync location.
syn sync lines=100

let b:current_syntax = "psf"
