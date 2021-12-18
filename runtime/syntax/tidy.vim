" Vim syntax file
" Language:	HMTL Tidy Configuration
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2020 Sep 4

" Preamble {{{1
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn iskeyword @,48-57,-,_

" Values {{{1
syn match tidyWordSeparator	contained ",\|\s" nextgroup=tidyWord   skipwhite skipnl
syn match tidyMuteIDSeparator	contained ",\|\s" nextgroup=tidyMuteID skipwhite skipnl

syn case ignore
syn keyword	tidyBoolean	contained t[rue] f[alse] y[es] n[o] 1 0
syn keyword	tidyAutoBoolean	contained t[rue] f[alse] y[es] n[o] 1 0 auto
syn case match
syn keyword	tidyCustomTags	contained no blocklevel empty inline pre
syn keyword	tidyDoctype	contained html5 omit auto strict loose transitional user
syn keyword	tidyEncoding	contained raw ascii latin0 latin1 utf8 iso2022 mac win1252 ibm858 utf16le utf16be utf16 big5 shiftjis
syn keyword	tidyNewline	contained LF CRLF CR
syn match	tidyNumber	contained "\<\d\+\>"
syn keyword	tidyRepeat	contained keep-first keep-last
syn keyword	tidySorter	contained alpha none
syn region	tidyString	contained start=+"+ skip=+\\\\\|\\"+ end=+"+ oneline
syn region	tidyString	contained start=+'+ skip=+\\\\\|\\'+ end=+'+ oneline
" Tag and attribute lists
syn match	tidyWord	contained "\<\k\+\>:\@!" nextgroup=tidyWordSeparator skipwhite skipnl

" Mute Message IDs {{{2
syn keyword tidyMuteID ADDED_MISSING_CHARSET ANCHOR_DUPLICATED
	\ ANCHOR_NOT_UNIQUE APOS_UNDEFINED APPLET_MISSING_ALT AREA_MISSING_ALT
	\ ASCII_REQUIRES_DESCRIPTION ASSOCIATE_LABELS_EXPLICITLY
	\ ASSOCIATE_LABELS_EXPLICITLY_FOR ASSOCIATE_LABELS_EXPLICITLY_ID
	\ ATTRIBUTE_IS_NOT_ALLOWED ATTRIBUTE_VALUE_REPLACED
	\ ATTR_VALUE_NOT_LCASE AUDIO_MISSING_TEXT_AIFF AUDIO_MISSING_TEXT_AU
	\ AUDIO_MISSING_TEXT_RA AUDIO_MISSING_TEXT_RM AUDIO_MISSING_TEXT_SND
	\ AUDIO_MISSING_TEXT_WAV BACKSLASH_IN_URI BAD_ATTRIBUTE_VALUE
	\ BAD_ATTRIBUTE_VALUE_REPLACED BAD_CDATA_CONTENT BAD_SUMMARY_HTML5
	\ BAD_SURROGATE_LEAD BAD_SURROGATE_PAIR BAD_SURROGATE_TAIL
	\ CANT_BE_NESTED COERCE_TO_ENDTAG COLOR_CONTRAST_ACTIVE_LINK
	\ COLOR_CONTRAST_LINK COLOR_CONTRAST_TEXT COLOR_CONTRAST_VISITED_LINK
	\ CONTENT_AFTER_BODY CUSTOM_TAG_DETECTED DATA_TABLE_MISSING_HEADERS
	\ DATA_TABLE_MISSING_HEADERS_COLUMN DATA_TABLE_MISSING_HEADERS_ROW
	\ DATA_TABLE_REQUIRE_MARKUP_COLUMN_HEADERS
	\ DATA_TABLE_REQUIRE_MARKUP_ROW_HEADERS DISCARDING_UNEXPECTED
	\ DOCTYPE_AFTER_TAGS DOCTYPE_MISSING DUPLICATE_FRAMESET
	\ ELEMENT_NOT_EMPTY ELEMENT_VERS_MISMATCH_ERROR
	\ ELEMENT_VERS_MISMATCH_WARN ENCODING_MISMATCH
	\ ENSURE_PROGRAMMATIC_OBJECTS_ACCESSIBLE_APPLET
	\ ENSURE_PROGRAMMATIC_OBJECTS_ACCESSIBLE_EMBED
	\ ENSURE_PROGRAMMATIC_OBJECTS_ACCESSIBLE_OBJECT
	\ ENSURE_PROGRAMMATIC_OBJECTS_ACCESSIBLE_SCRIPT ESCAPED_ILLEGAL_URI
	\ FILE_CANT_OPEN FILE_CANT_OPEN_CFG FILE_NOT_FILE FIXED_BACKSLASH
	\ FOUND_STYLE_IN_BODY FRAME_MISSING_LONGDESC FRAME_MISSING_NOFRAMES
	\ FRAME_MISSING_TITLE FRAME_SRC_INVALID FRAME_TITLE_INVALID_NULL
	\ FRAME_TITLE_INVALID_SPACES HEADERS_IMPROPERLY_NESTED
	\ HEADER_USED_FORMAT_TEXT ID_NAME_MISMATCH ILLEGAL_NESTING
	\ ILLEGAL_URI_CODEPOINT ILLEGAL_URI_REFERENCE
	\ IMAGE_MAP_SERVER_SIDE_REQUIRES_CONVERSION
	\ IMG_ALT_SUSPICIOUS_FILENAME IMG_ALT_SUSPICIOUS_FILE_SIZE
	\ IMG_ALT_SUSPICIOUS_PLACEHOLDER IMG_ALT_SUSPICIOUS_TOO_LONG
	\ IMG_BUTTON_MISSING_ALT IMG_MAP_CLIENT_MISSING_TEXT_LINKS
	\ IMG_MAP_SERVER_REQUIRES_TEXT_LINKS IMG_MISSING_ALT IMG_MISSING_DLINK
	\ IMG_MISSING_LONGDESC IMG_MISSING_LONGDESC_DLINK
	\ INFORMATION_NOT_CONVEYED_APPLET INFORMATION_NOT_CONVEYED_IMAGE
	\ INFORMATION_NOT_CONVEYED_INPUT INFORMATION_NOT_CONVEYED_OBJECT
	\ INFORMATION_NOT_CONVEYED_SCRIPT INSERTING_AUTO_ATTRIBUTE
	\ INSERTING_TAG INVALID_ATTRIBUTE INVALID_NCR INVALID_SGML_CHARS
	\ INVALID_UTF16 INVALID_UTF8 INVALID_XML_ID JOINING_ATTRIBUTE
	\ LANGUAGE_INVALID LANGUAGE_NOT_IDENTIFIED
	\ LAYOUT_TABLES_LINEARIZE_PROPERLY LAYOUT_TABLE_INVALID_MARKUP
	\ LINK_TEXT_MISSING LINK_TEXT_NOT_MEANINGFUL
	\ LINK_TEXT_NOT_MEANINGFUL_CLICK_HERE LINK_TEXT_TOO_LONG
	\ LIST_USAGE_INVALID_LI LIST_USAGE_INVALID_OL LIST_USAGE_INVALID_UL
	\ MALFORMED_COMMENT MALFORMED_COMMENT_DROPPING MALFORMED_COMMENT_EOS
	\ MALFORMED_COMMENT_WARN MALFORMED_DOCTYPE METADATA_MISSING
	\ METADATA_MISSING_REDIRECT_AUTOREFRESH MISMATCHED_ATTRIBUTE_ERROR
	\ MISMATCHED_ATTRIBUTE_WARN MISSING_ATTRIBUTE MISSING_ATTR_VALUE
	\ MISSING_DOCTYPE MISSING_ENDTAG_BEFORE MISSING_ENDTAG_FOR
	\ MISSING_ENDTAG_OPTIONAL MISSING_IMAGEMAP MISSING_QUOTEMARK
	\ MISSING_QUOTEMARK_OPEN MISSING_SEMICOLON MISSING_SEMICOLON_NCR
	\ MISSING_STARTTAG MISSING_TITLE_ELEMENT MOVED_STYLE_TO_HEAD
	\ MULTIMEDIA_REQUIRES_TEXT NESTED_EMPHASIS NESTED_QUOTATION
	\ NEWLINE_IN_URI NEW_WINDOWS_REQUIRE_WARNING_BLANK
	\ NEW_WINDOWS_REQUIRE_WARNING_NEW NOFRAMES_CONTENT
	\ NOFRAMES_INVALID_CONTENT NOFRAMES_INVALID_LINK
	\ NOFRAMES_INVALID_NO_VALUE NON_MATCHING_ENDTAG OBJECT_MISSING_ALT
	\ OBSOLETE_ELEMENT OPTION_REMOVED OPTION_REMOVED_APPLIED
	\ OPTION_REMOVED_UNAPPLIED POTENTIAL_HEADER_BOLD
	\ POTENTIAL_HEADER_ITALICS POTENTIAL_HEADER_UNDERLINE
	\ PREVIOUS_LOCATION PROGRAMMATIC_OBJECTS_REQUIRE_TESTING_APPLET
	\ PROGRAMMATIC_OBJECTS_REQUIRE_TESTING_EMBED
	\ PROGRAMMATIC_OBJECTS_REQUIRE_TESTING_OBJECT
	\ PROGRAMMATIC_OBJECTS_REQUIRE_TESTING_SCRIPT PROPRIETARY_ATTRIBUTE
	\ PROPRIETARY_ATTR_VALUE PROPRIETARY_ELEMENT REMOVED_HTML5
	\ REMOVE_AUTO_REDIRECT REMOVE_AUTO_REFRESH REMOVE_BLINK_MARQUEE
	\ REMOVE_FLICKER_ANIMATED_GIF REMOVE_FLICKER_APPLET
	\ REMOVE_FLICKER_EMBED REMOVE_FLICKER_OBJECT REMOVE_FLICKER_SCRIPT
	\ REPEATED_ATTRIBUTE REPLACE_DEPRECATED_HTML_APPLET
	\ REPLACE_DEPRECATED_HTML_BASEFONT REPLACE_DEPRECATED_HTML_CENTER
	\ REPLACE_DEPRECATED_HTML_DIR REPLACE_DEPRECATED_HTML_FONT
	\ REPLACE_DEPRECATED_HTML_ISINDEX REPLACE_DEPRECATED_HTML_MENU
	\ REPLACE_DEPRECATED_HTML_S REPLACE_DEPRECATED_HTML_STRIKE
	\ REPLACE_DEPRECATED_HTML_U REPLACING_ELEMENT REPLACING_UNEX_ELEMENT
	\ SCRIPT_MISSING_NOSCRIPT SCRIPT_NOT_KEYBOARD_ACCESSIBLE_ON_CLICK
	\ SCRIPT_NOT_KEYBOARD_ACCESSIBLE_ON_MOUSE_DOWN
	\ SCRIPT_NOT_KEYBOARD_ACCESSIBLE_ON_MOUSE_MOVE
	\ SCRIPT_NOT_KEYBOARD_ACCESSIBLE_ON_MOUSE_OUT
	\ SCRIPT_NOT_KEYBOARD_ACCESSIBLE_ON_MOUSE_OVER
	\ SCRIPT_NOT_KEYBOARD_ACCESSIBLE_ON_MOUSE_UP SKIPOVER_ASCII_ART
	\ SPACE_PRECEDING_XMLDECL STRING_ARGUMENT_BAD STRING_CONTENT_LOOKS
	\ STRING_DOCTYPE_GIVEN STRING_MISSING_MALFORMED STRING_MUTING_TYPE
	\ STRING_NO_SYSID STRING_UNKNOWN_OPTION
	\ STYLESHEETS_REQUIRE_TESTING_LINK
	\ STYLESHEETS_REQUIRE_TESTING_STYLE_ATTR
	\ STYLESHEETS_REQUIRE_TESTING_STYLE_ELEMENT
	\ STYLE_SHEET_CONTROL_PRESENTATION SUSPECTED_MISSING_QUOTE
	\ TABLE_MAY_REQUIRE_HEADER_ABBR TABLE_MAY_REQUIRE_HEADER_ABBR_NULL
	\ TABLE_MAY_REQUIRE_HEADER_ABBR_SPACES TABLE_MISSING_CAPTION
	\ TABLE_MISSING_SUMMARY TABLE_SUMMARY_INVALID_NULL
	\ TABLE_SUMMARY_INVALID_PLACEHOLDER TABLE_SUMMARY_INVALID_SPACES
	\ TAG_NOT_ALLOWED_IN TEXT_EQUIVALENTS_REQUIRE_UPDATING_APPLET
	\ TEXT_EQUIVALENTS_REQUIRE_UPDATING_OBJECT
	\ TEXT_EQUIVALENTS_REQUIRE_UPDATING_SCRIPT TOO_MANY_ELEMENTS
	\ TOO_MANY_ELEMENTS_IN TRIM_EMPTY_ELEMENT UNESCAPED_AMPERSAND
	\ UNEXPECTED_ENDTAG UNEXPECTED_ENDTAG_ERR UNEXPECTED_ENDTAG_IN
	\ UNEXPECTED_END_OF_FILE UNEXPECTED_END_OF_FILE_ATTR
	\ UNEXPECTED_EQUALSIGN UNEXPECTED_GT UNEXPECTED_QUOTEMARK
	\ UNKNOWN_ELEMENT UNKNOWN_ELEMENT_LOOKS_CUSTOM UNKNOWN_ENTITY
	\ USING_BR_INPLACE_OF VENDOR_SPECIFIC_CHARS WHITE_IN_URI
	\ XML_DECLARATION_DETECTED XML_ID_SYNTAX
	\ contained nextgroup=tidyMuteIDSeparator skipwhite skipnl

" Options {{{1
syn keyword tidyCustomTagsOption custom-tags contained nextgroup=tidyCustomTagsDelimiter
syn match tidyCustomTagsDelimiter ":" nextgroup=tidyCustomTags contained skipwhite

syn keyword tidyBooleanOption add-meta-charset add-xml-decl
	\ add-xml-pi add-xml-space anchor-as-name ascii-chars
	\ assume-xml-procins bare break-before-br clean coerce-endtags
	\ decorate-inferred-ul drop-empty-paras drop-empty-elements
	\ drop-font-tags drop-proprietary-attributes enclose-block-text
	\ enclose-text escape-cdata escape-scripts fix-backslash
	\ fix-style-tags fix-uri force-output gdoc gnu-emacs hide-comments
	\ hide-endtags indent-attributes indent-cdata indent-with-tabs
	\ input-xml join-classes join-styles keep-tabs keep-time language
	\ literal-attributes logical-emphasis lower-literals markup
	\ merge-emphasis mute-id ncr numeric-entities omit-optional-tags
	\ output-html output-xhtml output-xml preserve-entities
	\ punctuation-wrap quiet quote-ampersand quote-marks quote-nbsp raw
	\ replace-color show-filename show-info show-meta-change show-warnings
	\ skip-nested split strict-tags-attributes tidy-mark
	\ uppercase-attributes uppercase-tags warn-proprietary-attributes
	\ word-2000 wrap-asp wrap-attributes wrap-jste wrap-php
	\ wrap-script-literals wrap-sections write-back
	\ contained nextgroup=tidyBooleanDelimiter

syn match tidyBooleanDelimiter ":" nextgroup=tidyBoolean contained skipwhite

syn keyword tidyAutoBooleanOption fix-bad-comments indent merge-divs merge-spans output-bom show-body-only vertical-space contained nextgroup=tidyAutoBooleanDelimiter
syn match tidyAutoBooleanDelimiter ":" nextgroup=tidyAutoBoolean contained skipwhite

syn keyword tidyCSSSelectorOption css-prefix contained nextgroup=tidyCSSSelectorDelimiter
syn match tidyCSSSelectorDelimiter ":" nextgroup=tidyCSSSelector contained skipwhite

syn keyword tidyDoctypeOption doctype contained nextgroup=tidyDoctypeDelimiter
syn match tidyDoctypeDelimiter ":" nextgroup=tidyDoctype,tidyString contained skipwhite

syn keyword tidyEncodingOption char-encoding input-encoding output-encoding contained nextgroup=tidyEncodingDelimiter
syn match tidyEncodingDelimiter ":" nextgroup=tidyEncoding contained skipwhite

syn keyword tidyIntegerOption accessibility-check doctype-mode indent-spaces show-errors tab-size wrap contained nextgroup=tidyIntegerDelimiter
syn match tidyIntegerDelimiter ":" nextgroup=tidyNumber contained skipwhite

syn keyword tidyNameOption slide-style contained nextgroup=tidyNameDelimiter
syn match tidyNameDelimiter ":" nextgroup=tidyName contained skipwhite

syn keyword tidyNewlineOption newline contained nextgroup=tidyNewlineDelimiter
syn match tidyNewlineDelimiter ":" nextgroup=tidyNewline contained skipwhite

syn keyword tidyAttributesOption priority-attributes contained nextgroup=tidyAttributesDelimiter
syn match tidyAttributesDelimiter ":" nextgroup=tidyWord contained skipwhite

syn keyword tidyTagsOption new-blocklevel-tags new-empty-tags new-inline-tags new-pre-tags contained nextgroup=tidyTagsDelimiter
syn match tidyTagsDelimiter ":" nextgroup=tidyWord contained skipwhite

syn keyword tidyRepeatOption repeated-attributes contained nextgroup=tidyRepeatDelimiter
syn match tidyRepeatDelimiter ":" nextgroup=tidyRepeat contained skipwhite

syn keyword tidySorterOption sort-attributes contained nextgroup=tidySorterDelimiter
syn match tidySorterDelimiter ":" nextgroup=tidySorter contained skipwhite

syn keyword tidyStringOption alt-text error-file gnu-emacs-file output-file contained nextgroup=tidyStringDelimiter
syn match tidyStringDelimiter ":" nextgroup=tidyString contained skipwhite

syn keyword tidyMuteOption mute contained nextgroup=tidyMuteDelimiter
syn match tidyMuteDelimiter ":" nextgroup=tidyMuteID contained skipwhite

syn cluster tidyOptions contains=tidy.*Option

" Option line anchor {{{1
syn match tidyStart "^" nextgroup=@tidyOptions
" Long standing bug - option lines (except the first) with leading whitespace
" are silently ignored.
syn match tidyErrorStart '^\s\+\ze\S'

" Comments {{{1
syn match	tidyComment	"^\s*//.*$" contains=tidyTodo
syn match	tidyComment	"^\s*#.*$"  contains=tidyTodo
syn keyword	tidyTodo	TODO NOTE FIXME XXX contained

" Default highlighting {{{1
hi def link tidyAttributesOption	Identifier
hi def link tidyAutoBooleanOption	Identifier
hi def link tidyBooleanOption		Identifier
hi def link tidyCSSSelectorOption	Identifier
hi def link tidyCustomTagsOption	Identifier
hi def link tidyDoctypeOption		Identifier
hi def link tidyEncodingOption		Identifier
hi def link tidyIntegerOption		Identifier
hi def link tidyMuteOption		Identifier
hi def link tidyNameOption		Identifier
hi def link tidyNewlineOption		Identifier
hi def link tidyRepeatOption		Identifier
hi def link tidySorterOption		Identifier
hi def link tidyStringOption		Identifier
hi def link tidyTagsOption		Identifier

hi def link tidyAttributesDelimiter	Special
hi def link tidyAutoBooleanDelimiter	Special
hi def link tidyBooleanDelimiter	Special
hi def link tidyCSSSelectorDelimiter	Special
hi def link tidyCustomTagsDelimiter	Special
hi def link tidyDoctypeDelimiter	Special
hi def link tidyEncodingDelimiter	Special
hi def link tidyIntegerDelimiter	Special
hi def link tidyMuteDelimiter		Special
hi def link tidyNameDelimiter		Special
hi def link tidyNewlineDelimiter	Special
hi def link tidyRepeatDelimiter		Special
hi def link tidySorterDelimiter		Special
hi def link tidyStringDelimiter		Special
hi def link tidyTagsDelimiter		Special

hi def link tidyAutoBoolean		Boolean
hi def link tidyBoolean			Boolean
hi def link tidyCustomTags		Constant
hi def link tidyDoctype			Constant
hi def link tidyEncoding		Constant
hi def link tidyMuteID			Constant
hi def link tidyNewline			Constant
hi def link tidyNumber			Number
hi def link tidyRepeat			Constant
hi def link tidySorter			Constant
hi def link tidyString			String
hi def link tidyWord			Constant

hi def link tidyComment			Comment
hi def link tidyTodo			Todo

hi def link tidyErrorStart		Error

" Postscript {{{1
let b:current_syntax = "tidy"

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=8 fdm=marker
