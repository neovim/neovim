" Vim syntax file
" Language:	pilrc - a resource compiler for Palm OS development
" Maintainer:	Brian Schau <brian@schau.com>
" Last change:	2003 May 11
" Available on:	http://www.schau.com/pilrcvim/pilrc.vim

" quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

syn case ignore

" Notes: TRANSPARENT, FONT and FONT ID are defined in the specials
"	 section below.   Beware of the order of the specials!
"	 Look in the syntax.txt and usr_27.txt files in vim\vim{version}\doc
"	 directory for regexps etc.

" Keywords - basic
syn keyword pilrcKeyword ALERT APPLICATION APPLICATIONICONNAME AREA
syn keyword pilrcKeyword BITMAP BITMAPCOLOR BITMAPCOLOR16 BITMAPCOLOR16K
syn keyword pilrcKeyword BITMAPFAMILY BITMAPFAMILYEX BITMAPFAMILYSPECIAL
syn keyword pilrcKeyword BITMAPGREY BITMAPGREY16 BITMAPSCREENFAMILY
syn keyword pilrcKeyword BOOTSCREENFAMILY BUTTON BUTTONS BYTELIST
syn keyword pilrcKeyword CATEGORIES CHECKBOX COUNTRYLOCALISATION
syn keyword pilrcKeyword DATA
syn keyword pilrcKeyword FEATURE FIELD FONTINDEX FORM FORMBITMAP
syn keyword pilrcKeyword GADGET GENERATEHEADER
syn keyword pilrcKeyword GRAFFITIINPUTAREA GRAFFITISTATEINDICATOR
syn keyword pilrcKeyword HEX
syn keyword pilrcKeyword ICON ICONFAMILY ICONFAMILYEX INTEGER
syn keyword pilrcKeyword KEYBOARD
syn keyword pilrcKeyword LABEL LAUNCHERCATEGORY LIST LONGWORDLIST
syn keyword pilrcKeyword MENU MENUITEM MESSAGE  MIDI
syn keyword pilrcKeyword PALETTETABLE POPUPLIST POPUPTRIGGER
syn keyword pilrcKeyword PULLDOWN PUSHBUTTON
syn keyword pilrcKeyword REPEATBUTTON RESETAUTOID
syn keyword pilrcKeyword SCROLLBAR SELECTORTRIGGER SLIDER SMALLICON
syn keyword pilrcKeyword SMALLICONFAMILY SMALLICONFAMILYEX STRING STRINGTABLE
syn keyword pilrcKeyword TABLE TITLE TRANSLATION TRAP
syn keyword pilrcKeyword VERSION
syn keyword pilrcKeyword WORDLIST

" Types
syn keyword pilrcType AT AUTOSHIFT
syn keyword pilrcType BACKGROUNDID BITMAPID BOLDFRAME BPP
syn keyword pilrcType CHECKED COLORTABLE COLUMNS COLUMNWIDTHS COMPRESS
syn keyword pilrcType COMPRESSBEST COMPRESSPACKBITS COMPRESSRLE COMPRESSSCANLINE
syn keyword pilrcType CONFIRMATION COUNTRY CREATOR CURRENCYDECIMALPLACES
syn keyword pilrcType CURRENCYNAME CURRENCYSYMBOL CURRENCYUNIQUESYMBOL
syn keyword pilrcType DATEFORMAT DAYLIGHTSAVINGS DEFAULTBTNID DEFAULTBUTTON
syn keyword pilrcType DENSITY DISABLED DYNAMICSIZE
syn keyword pilrcType EDITABLE ENTRY ERROR EXTENDED
syn keyword pilrcType FEEDBACK FILE FONTID FORCECOMPRESS FRAME
syn keyword pilrcType GRAFFITI GRAPHICAL GROUP
syn keyword pilrcType HASSCROLLBAR HELPID
syn keyword pilrcType ID INDEX INFORMATION
syn keyword pilrcType KEYDOWNCHR KEYDOWNKEYCODE KEYDOWNMODIFIERS
syn keyword pilrcType LANGUAGE LEFTALIGN LEFTANCHOR LONGDATEFORMAT
syn keyword pilrcType MAX MAXCHARS MEASUREMENTSYSTEM MENUID MIN LOCALE
syn keyword pilrcType MINUTESWESTOFGMT MODAL MULTIPLELINES
syn keyword pilrcType NAME NOCOLORTABLE NOCOMPRESS NOFRAME NONEDITABLE
syn keyword pilrcType NONEXTENDED NONUSABLE NOSAVEBEHIND NUMBER NUMBERFORMAT
syn keyword pilrcType NUMERIC
syn keyword pilrcType PAGESIZE
syn keyword pilrcType RECTFRAME RIGHTALIGN RIGHTANCHOR ROWS
syn keyword pilrcType SAVEBEHIND SEARCH SCREEN SELECTEDBITMAPID SINGLELINE
syn keyword pilrcType THUMBID TRANSPARENTINDEX TIMEFORMAT
syn keyword pilrcType UNDERLINED USABLE
syn keyword pilrcType VALUE VERTICAL VISIBLEITEMS
syn keyword pilrcType WARNING WEEKSTARTDAY

" Country
syn keyword pilrcCountry Australia Austria Belgium Brazil Canada Denmark
syn keyword pilrcCountry Finland France Germany HongKong Iceland Indian
syn keyword pilrcCountry Indonesia Ireland Italy Japan Korea Luxembourg Malaysia
syn keyword pilrcCountry Mexico Netherlands NewZealand Norway Philippines
syn keyword pilrcCountry RepChina Singapore Spain Sweden Switzerland Thailand
syn keyword pilrcCountry Taiwan UnitedKingdom UnitedStates

" Language
syn keyword pilrcLanguage English French German Italian Japanese Spanish

" String
syn match pilrcString "\"[^"]*\""

" Number
syn match pilrcNumber "\<0x\x\+\>"
syn match pilrcNumber "\<\d\+\>"

" Comment
syn region pilrcComment start="/\*" end="\*/"
syn region pilrcComment start="//" end="$"

" Constants
syn keyword pilrcConstant AUTO AUTOID BOTTOM CENTER PREVBOTTOM PREVHEIGHT
syn keyword pilrcConstant PREVLEFT PREVRIGHT PREVTOP PREVWIDTH RIGHT
syn keyword pilrcConstant SEPARATOR

" Identifier
syn match pilrcIdentifier "\<\h\w*\>"

" Specials
syn match pilrcType "\<FONT\>"
syn match pilrcKeyword "\<FONT\>\s*\<ID\>"
syn match pilrcType "\<TRANSPARENT\>"

" Function
syn keyword pilrcFunction BEGIN END

" Include
syn match pilrcInclude "\#include"
syn match pilrcInclude "\#define"
syn keyword pilrcInclude equ
syn keyword pilrcInclude package
syn region pilrcInclude start="public class" end="}"

syn sync ccomment pilrcComment


" The default methods for highlighting
hi def link pilrcKeyword		Statement
hi def link pilrcType		Type
hi def link pilrcError		Error
hi def link pilrcCountry		SpecialChar
hi def link pilrcLanguage		SpecialChar
hi def link pilrcString		SpecialChar
hi def link pilrcNumber		Number
hi def link pilrcComment		Comment
hi def link pilrcConstant		Constant
hi def link pilrcFunction		Function
hi def link pilrcInclude		SpecialChar
hi def link pilrcIdentifier		Number


let b:current_syntax = "pilrc"
