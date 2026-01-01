" Vim syntax file
" Language:        Vim syntax file for SNMPv1 and SNMPv2 MIB and SMI files
" Maintainer:      Martin Smat <msmat@post.cz>
" Original Author: David Pascoe <pascoedj@spamcop.net>
" Written:     	   Wed Jan 28 14:37:23 GMT--8:00 1998
" Last Changed:    Mon Mar 23 2010

if exists("b:current_syntax")
  finish
endif

setlocal iskeyword=@,48-57,_,128-167,224-235,-

syn keyword mibImplicit ACCESS ANY AUGMENTS BEGIN BIT BITS BOOLEAN CHOICE
syn keyword mibImplicit COMPONENTS CONTACT-INFO DEFINITIONS DEFVAL
syn keyword mibImplicit DESCRIPTION DISPLAY-HINT END ENTERPRISE EXTERNAL FALSE
syn keyword mibImplicit FROM GROUP IMPLICIT IMPLIED IMPORTS INDEX
syn keyword mibImplicit LAST-UPDATED MANDATORY-GROUPS MAX-ACCESS
syn keyword mibImplicit MIN-ACCESS MODULE MODULE-COMPLIANCE MODULE-IDENTITY
syn keyword mibImplicit NOTIFICATION-GROUP NOTIFICATION-TYPE NOTIFICATIONS
syn keyword mibImplicit NULL OBJECT-GROUP OBJECT-IDENTITY OBJECT-TYPE
syn keyword mibImplicit OBJECTS OF OPTIONAL ORGANIZATION REFERENCE
syn keyword mibImplicit REVISION SEQUENCE SET SIZE STATUS SYNTAX
syn keyword mibImplicit TEXTUAL-CONVENTION TRAP-TYPE TRUE UNITS VARIABLES
syn keyword mibImplicit WRITE-SYNTAX
syn keyword mibValue accessible-for-notify current DisplayString
syn keyword mibValue deprecated mandatory not-accessible obsolete optional
syn keyword mibValue read-create read-only read-write write-only INTEGER
syn keyword mibValue Counter Gauge IpAddress OCTET STRING experimental mib-2
syn keyword mibValue TimeTicks RowStatus TruthValue UInteger32 snmpModules
syn keyword mibValue Integer32 Counter32 TestAndIncr TimeStamp InstancePointer
syn keyword mibValue OBJECT IDENTIFIER Gauge32 AutonomousType Counter64
syn keyword mibValue PhysAddress TimeInterval MacAddress StorageType RowPointer
syn keyword mibValue TDomain TAddress ifIndex

" Epilogue SMI extensions
syn keyword mibEpilogue FORCE-INCLUDE EXCLUDE cookie get-function set-function
syn keyword mibEpilogue test-function get-function-async set-function-async
syn keyword mibEpilogue test-function-async next-function next-function-async
syn keyword mibEpilogue leaf-name
syn keyword mibEpilogue DEFAULT contained

syn match  mibOperator  "::="
syn match  mibComment   "\ *--.\{-}\(--\|$\)"
syn match  mibNumber    "\<['0-9a-fA-FhH]*\>"
syn region mibDescription start="\"" end="\"" contains=DEFAULT

hi def link mibImplicit	     Statement
hi def link mibOperator      Statement
hi def link mibComment       Comment
hi def link mibConstants     String
hi def link mibNumber        Number
hi def link mibDescription   Identifier
hi def link mibEpilogue	     SpecialChar
hi def link mibValue         Structure

let b:current_syntax = "mib"
