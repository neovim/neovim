" SiSU Vim syntax file
" SiSU Maintainer: Ralph Amissah <ralph.amissah@gmail.com>
" SiSU Markup:     SiSU (sisu-5.6.7)
" Last Change:     2017 Jun 22
" URL: <http://git.sisudoc.org/gitweb/?p=code/sisu.git;a=blob;f=data/sisu/conf/editor-syntax-etc/vim/syntax/sisu.vim;hb=HEAD>
"      <http://git.sisudoc.org/gitweb/?p=code/sisu.git;a=blob_plain;f=data/sisu/conf/editor-syntax-etc/vim/syntax/sisu.vim;hb=HEAD>
"(originally looked at Ruby Vim by Mirko Nasato)

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif
let s:cpo_save = &cpo
set cpo&vim

"% "Errors:
syn match sisu_error contains=sisu_link,sisu_error_wspace "<![^ei]\S\+!>"

"% "Markers Identifiers:
if !exists("sisu_no_identifiers")
  syn match   sisu_mark_endnote                                           "\~^"
  syn match   sisu_break               contains=@NoSpell                  " \\\\\( \|$\)\|<br>\|<br />"
  syn match   sisu_control             contains=@NoSpell                  "^\(-\\\\-\|=\\\\=\|-\.\.-\|<:p[bn]>\)\s*$"
  syn match   sisu_control             contains=@NoSpell                  "^<:\(bo\|---\)>\s*$"
  syn match   sisu_marktail            contains=@NoSpell                  "^--[+~-]#\s*$"
  syn match   sisu_marktail                                               "[~-]#"
  syn match   sisu_control                                                "\""
  syn match   sisu_underline                                              "\(^\| \)_[a-zA-Z0-9]\+_\([ .,]\|$\)"
  syn match   sisu_number              contains=@NoSpell                  "[0-9a-f]\{32\}\|[0-9a-f]\{64\}"
  syn match   sisu_link                contains=@NoSpell                  "\(_\?https\?://\|\.\.\/\)\S\+"
  syn match   sisu_link                                                   " \*\~\S\+"
  syn match   sisu_require             contains=@NoSpell                  "^<<\s*[a-zA-Z0-9^./_-]\+\.ss[it]$"
  syn match   sisu_structure                                              "^:A\~$"

"% "Document Sub Headers:
  syn match   sisu_sub_header_title                                       "^\s\+:\(subtitle\|short\|edition\|language\|lang_char\|note\):\s" "group=sisu_header_content
  syn match   sisu_sub_header_creator                                     "^\s\+:\(author\|editor\|contributor\|illustrator\|photographer\|translator\|digitized_by\|prepared_by\|audio\|video\):\s"                               " &hon &institution
  syn match   sisu_sub_header_rights                                      "^\s\+:\(copyright\|text\|translation\|illustrations\|photographs\|preparation\|digitization\|audio\|video\|license\|all\):\s"                   " access_rights license
  syn match   sisu_sub_header_classify                                    "^\s\+:\(topic_register\|keywords\|subject\|dewey\|loc\):\s"
  syn match   sisu_sub_header_identifier                                  "^\s\+:\(oclc\|isbn\):\s"
  syn match   sisu_sub_header_date                                        "^\s\+:\(added_to_site\|available\|created\|issued\|modified\|published\|valid\|translated\|original_publication\):\s"
  syn match   sisu_sub_header_original                                    "^\s\+:\(publisher\|date\|language\|lang_char\|institution\|nationality\|source\):\s"
  syn match   sisu_sub_header_make                                        "^\s\+:\(headings\|num_top\|breaks\|language\|italics\|bold\|emphasis\|substitute\|omit\|plaintext_wrap\|texpdf_font_mono\|texpdf_font\|stamp\|promo\|ad\|manpage\|home_button_text\|home_button_image\|cover_image\|footer\):\s"
  syn match   sisu_sub_header_notes                                       "^\s\+:\(description\|abstract\|comment\|coverage\|relation\|source\|history\|type\|format\|prefix\|prefix_[ab]\|suffix\):\s"
  syn match   sisu_within_index_ignore                                    "\S\+[:;]\(\s\+\|$\)"
  syn match   sisu_within_index                                           "[:|;]\|+\d\+"

"% "semantic markers: (ignore)
  syn match   sisu_sem_marker                                             ";{\|};[a-z._]*[a-z]"
  syn match   sisu_sem_marker_block                                       "\([a-z][a-z._]*\|\):{\|}:[a-z._]*[a-z]"
  syn match   sisu_sem_ex_marker                                          ";\[\|\];[a-z._]*[a-z]"
  syn match   sisu_sem_ex_marker_block                                    "\([a-z][a-z._]*\|\):\[\|\]:[a-z._]*[a-z]"
  syn match   sisu_sem_block contains=sisu_error,sisu_error_wspace,sisu_content_alt,sisu_link,sisu_linked,sisu_break,sisu_sem_block,sisu_sem_content,sisu_sem_marker_block,sisu_sem_marker,sisu_sem_ex_marker_block,sisu_sem_ex_marker,sisu_mark_endnote,sisu_content_endnote "\([a-z]*\):{[^}].\{-}}:\1"
  syn match   sisu_sem_content contains=sisu_error,sisu_error_wspace,sisu_content_alt,sisu_link,sisu_linked,sisu_break,sisu_sem_marker_block,sisu_sem_marker,sisu_sem_ex_marker_block,sisu_sem_ex_marker ";{[^}].\{-}};[a-z]\+"
  syn match   sisu_sem_ex_block contains=sisu_error,sisu_error_wspace,sisu_content_alt,sisu_link,sisu_linked,sisu_break,sisu_sem_block,sisu_sem_content,sisu_sem_marker_block,sisu_sem_marker,sisu_sem_ex_marker_block,sisu_sem_ex_marker,sisu_mark_endnote,sisu_content_endnote "\([a-z]*\):\[[^}].\{-}\]:\1"
  syn match   sisu_sem_ex_content contains=sisu_error,sisu_error_wspace,sisu_content_alt,sisu_link,sisu_linked,sisu_break,sisu_sem_marker_block,sisu_sem_marker,sisu_sem_ex_marker_block,sisu_sem_ex_marker ";\[[^}].\{-}\];[a-z]\+"
endif

"% "URLs Numbers And ASCII Codes:
syn match   sisu_number                              "\<\(0x\x\+\|0b[01]\+\|0\o\+\|0\.\d\+\|0\|[1-9][\.0-9_]*\)\>"
syn match   sisu_number                              "?\(\\M-\\C-\|\\c\|\\C-\|\\M-\)\=\(\\\o\{3}\|\\x\x\{2}\|\\\=\w\)"

"% "Tuned Error: (is error if not already matched)
syn match sisu_error             contains=sisu_error "[\~/\*!_]{\|}[\~/\*!_]"
syn match sisu_error             contains=sisu_error "<a href\|</a>]"

"% "Simple Paired Enclosed Markup:
"url/link
syn region sisu_link contains=sisu_error,sisu_error_wspace matchgroup=sisu_action start="^<<\s*|[a-zA-Z0-9^._-]\+|@|[a-zA-Z0-9^._-]\+|"rs=s+2 end="$"

"% "Document Header:
" title
syn region sisu_header_content contains=sisu_error,sisu_comment,sisu_break,sisu_link,sisu_sub_header_title matchgroup=sisu_header start="^[@]title:[+-]\?\(\s\|\n\)"rs=e-1 end="\n$"
" creator
syn region sisu_header_content contains=sisu_error,sisu_comment,sisu_break,sisu_link,sisu_sub_header_creator matchgroup=sisu_header start="^[@]creator:[+-]\?\(\s\|\n\)"rs=e-1 end="\n$"
" dates
syn region sisu_header_content contains=sisu_error,sisu_comment,sisu_break,sisu_link,sisu_sub_header_date matchgroup=sisu_header start="^[@]date:[+-]\?\(\s\|\n\)"rs=e-1 end="\n$"
" publisher
syn region sisu_header_content contains=sisu_error,sisu_comment,sisu_break,sisu_link,sisu_sub_header_publisher matchgroup=sisu_header start="^[@]publisher:[+-]\?\(\s\|\n\)"rs=e-1 end="\n$"
" rights
syn region sisu_header_content contains=sisu_error,sisu_comment,sisu_break,sisu_link,sisu_sub_header_rights matchgroup=sisu_header start="^[@]rights:[+-]\?\(\s\|\n\)"rs=e-1 end="\n$"
" classify document
syn region sisu_header_content contains=sisu_error,sisu_comment,sisu_break,sisu_link,sisu_sub_header_classify matchgroup=sisu_header start="^[@]classify:[+-]\?\(\s\|\n\)"rs=e-1 end="\n$"
" identifier document
syn region sisu_header_content contains=sisu_error,sisu_comment,sisu_break,sisu_link,sisu_sub_header_identifier matchgroup=sisu_header start="^[@]identifier:[+-]\?\(\s\|\n\)"rs=e-1 end="\n$"
" original language (depreciated)
syn region sisu_header_content contains=sisu_error,sisu_comment,sisu_break,sisu_link,sisu_sub_header_original matchgroup=sisu_header start="^[@]original:[+-]\?\(\s\|\n\)"rs=e-1 end="\n$"
" notes
syn region sisu_header_content contains=sisu_error,sisu_comment,sisu_break,sisu_link,sisu_sub_header_notes matchgroup=sisu_header start="^[@]notes:[+-]\?\(\s\|\n\)"rs=e-1 end="\n$"
" links of interest
syn region sisu_header_content contains=sisu_error,sisu_comment,sisu_break,sisu_linked,sisu_sub_header_links matchgroup=sisu_header start="^[@]links:[+-]\?\(\s\|\n\)"rs=e-1 end="\n$"
" make, processing instructions
syn region sisu_header_content contains=sisu_error,sisu_comment,sisu_break,sisu_link,sisu_sub_header_make matchgroup=sisu_header start="^[@]make:[+-]\?\(\s\|\n\)"rs=e-1 end="\n$"

"% "Headings:
syn region sisu_heading contains=sisu_mark_endnote,sisu_content_endnote,sisu_marktail,sisu_strikeout,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_ocn,sisu_error,sisu_error_wspace matchgroup=sisu_structure start="^\([1-4]\|:\?[A-D]\)\~\(\S\+\|[^-]\)" end="$"

"% "Block Group Text:
" table
syn region sisu_content_alt contains=sisu_strikeout,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_contain start="^table{.\+" end="}table"
" table
syn region sisu_content_alt contains=sisu_strikeout,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_contain start="^```\s\+table" end="^```\(\s\|$\)"
syn region sisu_content_alt contains=sisu_strikeout,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_contain start="^{\(t\|table\)\(\~h\)\?\(\sc[0-9]\+;\)\?[0-9; ]*}" end="\n$"
" block, group, poem, alt
syn region sisu_content_alt contains=sisu_mark_endnote,sisu_content_endnote,sisu_link,sisu_mark,sisu_strikeout,sisu_number,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_contain start="^\z(block\|group\|poem\|alt\){" end="^}\z1"
syn region sisu_content_alt contains=sisu_mark_endnote,sisu_content_endnote,sisu_link,sisu_mark,sisu_strikeout,sisu_number,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_contain start="^```\s\+\(block\|group\|poem\|alt\)" end="^```\(\s\|$\)"
" box
syn region sisu_content_alt contains=sisu_mark_endnote,sisu_content_endnote,sisu_link,sisu_mark,sisu_strikeout,sisu_number,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_contain start="^box\(\.[a-z]\+\)\?{" end="^}box"
syn region sisu_content_alt contains=sisu_mark_endnote,sisu_content_endnote,sisu_link,sisu_mark,sisu_strikeout,sisu_number,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_contain start="^```\s\+\box\(\.[a-z]\+\)\?" end="^```\(\s\|$\)"
" code
syn region sisu_content_alt contains=sisu_error,@NoSpell matchgroup=sisu_contain start="^code\(\.[a-z][0-9a-z_]\+\)\?{" end="^}code"
syn region sisu_content_alt contains=sisu_error,@NoSpell matchgroup=sisu_contain start="^```\s\+code\(\.[a-z][0-9a-z_]\+\)\?" end="^```\(\s\|$\)"
" quote
syn region sisu_normal contains=sisu_fontface,sisu_bold,sisu_control,sisu_identifier,sisu_content_endnote,sisu_mark_endnote,sisu_link,sisu_sem_block,sisu_sem_content,sisu_sem_marker_block,sisu_sem_marker,sisu_sem_ex_marker_block,sisu_sem_ex_marker,sisu_linked,sisu_error,sisu_error_wspace matchgroup=sisu_contain start="^```\s\+quote" end="^```\(\s\|$\)"

"% "Endnotes:
" regular endnote or asterisk or plus sign endnote
syn region sisu_content_endnote contains=sisu_link,sisu_strikeout,sisu_underline,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_error,sisu_error_wspace,sisu_mark,sisu_break,sisu_sem_block,sisu_sem_content,sisu_sem_marker_block,sisu_sem_marker,sisu_sem_ex_marker_block,sisu_sem_ex_marker matchgroup=sisu_mark_endnote start="\~{[*+]*" end="}\~" skip="\n"
" numbered asterisk or plus sign endnote
syn region sisu_content_endnote contains=sisu_link,sisu_strikeout,sisu_underline,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_error,sisu_error_wspace,sisu_mark,sisu_break,sisu_sem_block,sisu_sem_content,sisu_sem_marker matchgroup=sisu_mark_endnote start="\~\[[*+]*" end="\]\~" skip="\n"
" endnote content marker (for binary content marking)
syn region sisu_content_endnote contains=sisu_strikeout,sisu_number,sisu_bold,sisu_control,sisu_link,sisu_identifier,sisu_error,sisu_error_wspace,sisu_mark,sisu_break matchgroup=sisu_mark_endnote start="\^\~" end="\n$"

"% "Links And Images:
" image with url link (and possibly footnote of url)
syn region sisu_linked contains=sisu_fontface,sisu_strikeout,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_sem_block,sisu_sem_content,sisu_sem_marker_block,sisu_sem_marker,sisu_sem_ex_marker_block,sisu_sem_ex_marker,sisu_sem_block,sisu_error matchgroup=sisu_link start="{\(\~^\s\)\?" end="}\(https\?:/\/\|:\|\.\.\/\|#\)\S\+" oneline
" sisu outputs, short notation
syn region sisu_linked contains=sisu_fontface,sisu_strikeout,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_sem_block,sisu_sem_content,sisu_sem_marker_block,sisu_sem_marker,sisu_sem_ex_marker_block,sisu_sem_ex_marker,sisu_sem_block,sisu_error matchgroup=sisu_link start="{\(\~^\s\)\?" end="\[[1-5][sS]*\]}\S\+\.ss[tm]" oneline
" image
syn region sisu_linked contains=sisu_fontface,sisu_strikeout,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_link start="{" end="}image" oneline

"% "Some Line Operations:
" bold line
syn region sisu_bold contains=sisu_strikeout,sisu_identifier,sisu_content_endnote,sisu_mark_endnote,sisu_error,sisu_error_wspace matchgroup=sisu_markpara start="^!_ " end=" \\\\\|$"
" indent and bullet paragraph
syn region sisu_normal contains=sisu_fontface,sisu_bold,sisu_control,sisu_identifier,sisu_content_endnote,sisu_mark_endnote,sisu_link,sisu_sem_block,sisu_sem_content,sisu_sem_marker_block,sisu_sem_marker,sisu_sem_ex_marker_block,sisu_sem_ex_marker,sisu_linked,sisu_error,sisu_error_wspace matchgroup=sisu_markpara start="^_\([1-9*]\|[1-9]\*\) " end="$"
" indent and bullet (bold start) paragraph
syn region sisu_bold contains=sisu_fontface,sisu_bold,sisu_control,sisu_identifier,sisu_content_endnote,sisu_mark_endnote,sisu_link,sisu_sem_block,sisu_sem_content,sisu_sem_marker_block,sisu_sem_marker,sisu_sem_ex_marker_block,sisu_sem_ex_marker,sisu_linked,sisu_error,sisu_error_wspace matchgroup=sisu_markpara start="^_\([1-9*]\|[1-9]\*\)!_\? " end=" \\\\\|$"
" hanging indent paragraph [proposed]
syn region sisu_normal contains=sisu_fontface,sisu_bold,sisu_control,sisu_identifier,sisu_content_endnote,sisu_mark_endnote,sisu_link,sisu_sem_block,sisu_sem_content,sisu_sem_marker_block,sisu_sem_marker,sisu_sem_ex_marker_block,sisu_sem_ex_marker,sisu_linked,sisu_error,sisu_error_wspace matchgroup=sisu_markpara start="^_[0-9]\?_[0-9] " end="$"
" hanging indent (bold start/ definition) paragraph [proposed]
syn region sisu_bold contains=sisu_fontface,sisu_bold,sisu_control,sisu_identifier,sisu_content_endnote,sisu_mark_endnote,sisu_link,sisu_sem_block,sisu_sem_content,sisu_sem_marker_block,sisu_sem_marker,sisu_sem_ex_marker_block,sisu_sem_ex_marker,sisu_linked,sisu_error,sisu_error_wspace matchgroup=sisu_markpara start="^_[0-9]\?_[0-9]!_\? " end=" \\\\\|$"
" list numbering
syn region sisu_normal contains=sisu_strikeout,sisu_identifier,sisu_content_endnote,sisu_mark_endnote,sisu_link,sisu_linked,sisu_error,sisu_error_wspace matchgroup=sisu_markpara start="^\(#[ 1]\|_# \)" end="$"

"% "Font Face Curly Brackets:
"syn region sisu_identifier contains=sisu_strikeout,sisu_number,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_sem start="\S\+:{" end="}:[^<>,.!?:; ]\+" oneline
" book index:
syn region sisu_index contains=sisu_within_index_ignore,sisu_within_index matchgroup=sisu_index_block start="^={" end="}"
" emphasis:
syn region sisu_bold contains=sisu_strikeout,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_fontface start="\*{" end="}\*"
" bold:
syn region sisu_bold contains=sisu_strikeout,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_fontface start="!{" end="}!"
" underscore:
syn region sisu_underline contains=sisu_strikeout,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_fontface start="_{" end="}_"
" italics:
syn region sisu_identifier contains=sisu_strikeout,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_fontface start="/{" end="}/"
" added:
syn region sisu_underline contains=sisu_strikeout,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_fontface start="+{" end="}+"
" superscript:
syn region sisu_identifier contains=sisu_strikeout,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_fontface start="\^{" end="}\^"
" subscript:
syn region sisu_identifier contains=sisu_strikeout,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_fontface start=",{" end="},"
" monospace:
syn region sisu_identifier contains=sisu_strikeout,sisu_number,sisu_bold,sisu_control,sisu_identifier,sisu_error matchgroup=sisu_fontface start="#{" end="}#"
" strikethrough:
syn region sisu_strikeout contains=sisu_error matchgroup=sisu_fontface start="-{" end="}-"

"% "Single Words Bold Italicise Etc: (depreciated)
syn region sisu_bold contains=sisu_error matchgroup=sisu_bold start="\([ (]\|^\)\*[^\|{\n\~\\]"hs=e-1 end="\*"he=e-0 skip="[a-zA-Z0-9']" oneline
syn region sisu_identifier contains=sisu_error matchgroup=sisu_content_alt start="\([ ]\|^\)/[^{ \|\n\\]"hs=e-1 end="/\[ \.\]" skip="[a-zA-Z0-9']" oneline
"misc
syn region sisu_identifier contains=sisu_error matchgroup=sisu_fontface start="\^[^ {\|\n\\]"rs=s+1 end="\^[ ,.;:'})\\\n]" skip="[a-zA-Z0-9']" oneline

"% "Expensive Mode:
if !exists("sisu_no_expensive")
else " not Expensive
  syn region  sisu_content_alt  matchgroup=sisu_control start="^\s*def\s" matchgroup=NONE end="[?!]\|\>" skip="\.\|\(::\)" oneline
endif " Expensive?

"% "Headers And Headings: (Document Instructions)
syn match sisu_control contains=sisu_error,sisu_error_wspace "4\~! \S\+"
syn region  sisu_markpara contains=sisu_error,sisu_error_wspace start="^=begin" end="^=end.*$"

"% "Errors:
syn match sisu_error_wspace contains=sisu_error_wspace "^\s\+[^:]"
syn match sisu_error_wspace contains=sisu_error_wspace "\s\s\+"
syn match sisu_error_wspace contains=sisu_error_wspace "\s\+$"
syn match sisu_error contains=sisu_error_wspace "\t\+"
syn match sisu_error contains=sisu_error,sisu_error_wspace "\([^ (][_\\]\||[^ (}]\)https\?:\S\+"
syn match sisu_error contains=sisu_error "_\?https\?:\S\+[}><]"
syn match sisu_error contains=sisu_error "\([!*/_\+,^]\){\([^(\}\1)]\)\{-}\n$"
syn match sisu_error contains=sisu_error "^[\~]{[^{]\{-}\n$"
syn match sisu_error contains=sisu_error "\s\+.{{"
syn match sisu_error contains=sisu_error "^\~\s*$"
syn match sisu_error contains=sisu_error "^0\~.*"
syn match sisu_error contains=sisu_error "^[1-9]\~\s*$"
syn match sisu_error contains=sisu_error "^[1-9]\~\S\+\s*$"
syn match sisu_error contains=sisu_error "[^{]\~\^[^ \)]"
syn match sisu_error contains=sisu_error "\~\^\s\+\.\s*"
syn match sisu_error contains=sisu_error "{\~^\S\+"
syn match sisu_error contains=sisu_error "[_/\*!^]{[ .,:;?><]*}[_/\*!^]"
syn match sisu_error contains=sisu_error "[^ (\"'(\[][_/\*!]{\|}[_/\*!][a-zA-Z0-9)\]\"']"
syn match sisu_error contains=sisu_error "<dir>"
"errors for filetype sisu, though not error in 'metaverse':
syn match sisu_error contains=sisu_error,sisu_match,sisu_strikeout,sisu_contain,sisu_content_alt,sisu_mark,sisu_break,sisu_number "<[a-zA-Z\/]\+>"
syn match sisu_error  "/\?<\([biu]\)>[^(</\1>)]\{-}\n$"

"% "Error Exceptions:
syn match sisu_control "\n$" "contains=ALL
"syn match sisu_control " //"
syn match sisu_error   "%{"
syn match sisu_error   "<br>_\?https\?:\S\+\|_\?https\?:\S\+<br>"
syn match sisu_error   "[><]_\?https\?:\S\+\|_\?https\?:\S\+[><]"
syn match sisu_comment "^%\{1,2\}.\+"

"% "Definitions Default Highlighting:
hi def link sisu_normal                Normal
hi def link sisu_bold                  Statement
hi def link sisu_header                PreProc
hi def link sisu_header_content        Normal
hi def link sisu_sub_header_title      Statement
hi def link sisu_sub_header_creator    Statement
hi def link sisu_sub_header_date       Statement
hi def link sisu_sub_header_publisher  Statement
hi def link sisu_sub_header_rights     Statement
hi def link sisu_sub_header_classify   Statement
hi def link sisu_sub_header_identifier Statement
hi def link sisu_sub_header_original   Statement
hi def link sisu_sub_header_links      Statement
hi def link sisu_sub_header_notes      Statement
hi def link sisu_sub_header_make       Statement
hi def link sisu_heading               Title
hi def link sisu_structure             Operator
hi def link sisu_contain               Include
hi def link sisu_mark_endnote          Delimiter
hi def link sisu_require               NonText
hi def link sisu_link                  NonText
hi def link sisu_linked                String
hi def link sisu_fontface              Delimiter
hi def link sisu_strikeout             DiffDelete
hi def link sisu_content_alt           Special
hi def link sisu_sem_content           SpecialKey
hi def link sisu_sem_block             Special
hi def link sisu_sem_marker            Visual
"hi def link sisu_sem_marker            Structure
hi def link sisu_sem_marker_block      MatchParen
hi def link sisu_sem_ex_marker         FoldColumn
hi def link sisu_sem_ex_marker_block   Folded
hi def link sisu_sem_ex_content        Comment
"hi def link sisu_sem_ex_content        SpecialKey
hi def link sisu_sem_ex_block          Comment
hi def link sisu_index                 SpecialKey
hi def link sisu_index_block           Visual
hi def link sisu_content_endnote       Special
hi def link sisu_control               Delimiter
hi def link sisu_within_index          Delimiter
hi def link sisu_within_index_ignore   SpecialKey
hi def link sisu_ocn                   Include
hi def link sisu_number                Number
hi def link sisu_identifier            Function
hi def link sisu_underline             Underlined
hi def link sisu_markpara              Include
hi def link sisu_marktail              Include
hi def link sisu_mark                  Identifier
hi def link sisu_break                 Structure
hi def link sisu_html                  Type
hi def link sisu_action                Identifier
hi def link sisu_comment               Comment
hi def link sisu_error_sem_marker      Error
hi def link sisu_error_wspace          Error
hi def link sisu_error                 Error
let b:current_syntax = "sisu"
let &cpo = s:cpo_save
unlet s:cpo_save
