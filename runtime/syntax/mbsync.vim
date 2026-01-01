" Vim syntax file
" Language:	mbsyncrc
" Maintainer:	Pierrick Guillaume  <pguillaume@fymyte.com>
" Last Change:	2025 Apr 13
" 2025 Jun 04 by Vim project: match TLSType configuration variable
"
" Syntax support for mbsync config file

" This file is based on the mbsync manual (isync v1.4.4)
" https://isync.sourceforge.io/mbsync.html

if exists('b:current_syntax')
  finish
endif

let b:current_syntax = 'mbsync'

let s:cpo_save = &cpo
set cpo&vim

syn match mbsError    '.*'

syn match mbsCommentL '^#.*$'

" Properties {{{

syn match   mbsNumber   '[0-9]\+' display contained
syn match   mbsPath     '\%([A-Za-z0-9/._+#$%~=\\{}\[\]:@!-]\|\\.\)\+' display contained
syn match   mbsPath     '"\%([A-Za-z0-9/._+#$%~=\\{}\[\]:@! -]\|\\.\)\+"' display contained
syn match   mbsName     '\%([A-Za-z0-9/._+#$%~=\\{}\[\]:@!-]\|\\.\)\+' display contained
syn match   mbsName     '"\%([A-Za-z0-9/._+#$%~=\\{}\[\]:@! -]\|\\.\)\+"' display contained
syn match   mbsCommand  '+\?.*$' display contained contains=mbsCommandPrompt
syn match   mbsCommandPrompt '+' display contained
syn region  mbsString   start=+"+ skip=+\\"+ end=+"+ display contained
syn match   mbsSizeUnit '[kKmMbB]' display contained
syn match   mbsSize     '[0-9]\+' display contained contains=mbsNumber nextgroup=mbsSizeUnit
syn keyword mbsBool     yes no contained

" }}}


" Stores {{{
" Global Store Config Items
syn match mbsGlobConfPath     '^Path\s\+\ze.*$'      contains=mbsGlobConfItemK contained nextgroup=mbsPath transparent
syn match mbsGlobConfMaxSize  '^MaxSize\s\+\ze.*$'   contains=mbsGlobConfItemK contained nextgroup=mbsSize transparent
syn match mbsGlobConfMapInbox '^MapInbox\s\+\ze.*$'  contains=mbsGlobConfItemK contained nextgroup=mbsPath transparent
syn match mbsGlobConfFlatten  '^Flatten\s\+\ze.*$'   contains=mbsGlobConfItemK contained nextgroup=mbsPath transparent
syn match mbsGlobConfTrash    '^Trash\s\+\ze.*$'     contains=mbsGlobConfItemK contained nextgroup=mbsPath transparent
syn match mbsGlobConfTrashNO  '^TrashNewOnly\s\+\ze.*$'   contains=mbsGlobConfItemK contained nextgroup=mbsBool transparent
syn match mbsGlobConfTrashRN  '^TrashRemoteNew\s\+\ze.*$' contains=mbsGlobConfItemK contained nextgroup=mbsBool transparent
syn keyword mbsGlobConfItemK  Path MaxSize MapInbox Flatten Trash TrashNewOnly TrashRemoteNew contained

syn cluster mbsGlobConfItem contains=mbsGlobConfPath,mbsGlobConfMaxSize,mbsGlobConfMapInbox,mbsGlobConfFlatten,mbsCommentL,mbsGlobConfTrash.*


"   MaildirStore
syn match mbsMdSConfStMaildirStore  '^MaildirStore\s\+\ze.*$'   contains=mbsMdSConfItemK contained nextgroup=mbsName transparent
syn match mbsMdSConfStAltMap        '^AltMap\s\+\ze.*$'         contains=mbsMdSConfItemK contained nextgroup=mbsBool transparent
syn match mbsMdsConfStInbox         '^Inbox\s\+\ze.*$'          contains=mbsMdSConfItemK contained nextgroup=mbsPath transparent
syn match mbsMdsConfStInfoDelimiter '^InfoDelimiter\s\+\ze.*$'  contains=mbsMdSConfItemK contained nextgroup=mbsPath transparent
syn keyword mbsMdSConfSubFoldersOpt  Verbatim Legacy contained
syn match mbsMdSConfSubFoldersOpt   'Maildir++' display contained
syn match mbsMdsConfStSubFolders    '^SubFolders\s\+\ze.*$'     contains=mbsMdSConfItemK contained nextgroup=mbsMdSConfSubFoldersOpt transparent

syn cluster mbsMdSConfItem contains=mbsMdSConfSt.*

syn keyword mbsMdSConfItemK   MaildirStore AltMap Inbox InfoDelimiter SubFolders contained

syn region mbsMaildirStore start="^MaildirStore" end="^$" end='\%$' contains=@mbsGlobConfItem,mbsCommentL,@mbsMdSConfItem,mbsError transparent


"   IMAP4Accounts
syn match mbsIAConfStIMAPAccount  '^IMAPAccount\s\+\ze.*$'    contains=mbsIAConfItemK contained nextgroup=mbsName transparent
syn match mbsIAConfStHost         '^Host\s\+\ze.*$'           contains=mbsIAConfItemK contained nextgroup=mbsPath transparent
syn match mbsIAConfStPort         '^Port\s\+\ze.*$'           contains=mbsIAConfItemK contained nextgroup=mbsNumber transparent
syn match mbsIAConfStTimeout      '^Timeout\s\+\ze.*$'        contains=mbsIAConfItemK contained nextgroup=mbsNumber transparent
syn match mbsIAConfStUser         '^User\s\+\ze.*$'           contains=mbsIAConfItemK contained nextgroup=mbsPath transparent
syn match mbsIAConfStUserCmd      '^UserCmd\s\+\ze.*$'        contains=mbsIAConfItemK contained nextgroup=mbsCommand transparent
syn match mbsIAConfStPass         '^Pass\s\+\ze.*$'           contains=mbsIAConfItemK contained nextgroup=mbsPath transparent
syn match mbsIAConfStPassCmd      '^PassCmd\s\+\ze.*$'        contains=mbsIAConfItemK contained nextgroup=mbsCommand transparent
syn match mbsIAConfStUseKeychain  '^UseKeychain\s\+\ze.*$'    contains=mbsIAConfItemK contained nextgroup=mbsBool transparent
syn match mbsIAConfStTunnel       '^Tunnel\s\+\ze.*$'         contains=mbsIAConfItemK contained nextgroup=mbsCommand transparent
syn match mbsIAConfStAuthMechs    '^AuthMechs\s\+\ze.*$'      contains=mbsIAConfItemK contained nextgroup=mbsPath transparent
syn keyword mbsIAConfTLSTypeOpt None STARTTLS IMAPS contained
syn match mbsIAConfStSSLType      '^SSLType\s\+\ze.*$'        contains=mbsIAConfItemK contained nextgroup=mbsIAConfTLSTypeOpt transparent
syn match mbsIAConfStTLSType      '^TLSType\s\+\ze.*$'        contains=mbsIAConfItemK contained nextgroup=mbsIAConfTLSTypeOpt transparent
syn match mbsIAConfSSLVersionsOpt '\%(SSLv3\|TLSv1\%(.[123]\)\?\)\%(\s\+\%(SSLv3\|TLSv1\%(.[123]\)\?\)\)*' contained
syn match mbsIAConfStSSLVersions  '^SSLVersions\s\+\ze.*$'    contains=mbsIAConfItemK contained nextgroup=mbsIAConfSSLVersionsOpt transparent
syn match mbsIAConfStSystemCertificates  '^SystemCertificates\s\+\ze.*$'    contains=mbsIAConfItemK contained nextgroup=mbsBool transparent
syn match mbsIAConfStCertificateFile  '^CertificateFile\s\+\ze.*$'    contains=mbsIAConfItemK contained nextgroup=mbsPath transparent
syn match mbsIAConfStClientCertificate  '^ClientCertificate\s\+\ze.*$'    contains=mbsIAConfItemK contained nextgroup=mbsPath transparent
syn match mbsIAConfStClientKey    '^ClientKey\s\+\ze.*$'       contains=mbsIAConfItemK contained nextgroup=mbsPath transparent
syn match mbsIAConfStCipherString '^CipherString\s\+\ze.*$'    contains=mbsIAConfItemK contained nextgroup=mbsString transparent
syn match mbsIAConfStPipelineDepth '^PipelineDepth\s\+\ze.*$'  contains=mbsIAConfItemK contained nextgroup=mbsNumber transparent
syn match mbsIAConfStDisableExtensions '^DisableExtensions\?\s\+\ze.*$'  contains=mbsIAConfItemK contained nextgroup=mbsPath transparent

syn cluster mbsIAConfItem contains=mbsIAConfSt.*

syn keyword mbsIAConfItemK
  \ IMAPAccount Host Port Timeout User UserCmd Pass PassCmd UseKeychain Tunnel
  \ AuthMechs SSLType TLSType SSLVersions SystemCertificates CertificateFile ClientCertificate
  \ ClientKey CipherString PipelineDepth DisableExtension[s] contained

syn region mbsIMAP4AccontsStore start="^IMAPAccount" end="^$" end="\%$" contains=@mbsGlobConfItem,mbsCommentL,@mbsIAConfItem,mbsError transparent


"   IMAPStores
syn match mbsISConfStIMAPStore    '^IMAPStore\s\+\ze.*$'      contains=mbsISConfItemK contained nextgroup=mbsName transparent
syn match mbsISConfStAccount      '^Account\s\+\ze.*$'        contains=mbsISConfItemK contained nextgroup=mbsName transparent
syn match mbsISConfStUseNamespace '^UseNamespace\s\+\ze.*$'   contains=mbsISConfItemK contained nextgroup=mbsBool transparent
syn match mbsISConfStPathDelimiter '^PathDelimiter\s\+\ze.*$'   contains=mbsISConfItemK contained nextgroup=mbsPath transparent
syn match mbsISConfStSubscribedOnly '^SubscribedOnly\s\+\ze.*$'   contains=mbsISConfItemK contained nextgroup=mbsBool transparent

syn cluster mbsISConfItem contains=mbsISConfSt.*

syn keyword mbsISConfItemK  IMAPStore Account UseNamespace PathDelimiter SubscribedOnly contained

syn region mbsIMAPStore start="^IMAPStore" end="^$" end="\%$" contains=@mbsGlobConfItem,mbsCommentL,@mbsISConfItem,mbsError transparent

" }}}

" Channels {{{

syn match mbsCConfStChannel       '^Channel\s\+\ze.*$'        contains=mbsCConfItemK contained nextgroup=mbsName transparent
syn region mbsCConfProxOpt matchgroup=mbsCConfProxOptOp start=':' matchgroup=mbsCConfProxOptOp end=':' contained contains=mbsName nextgroup=mbsPath keepend
syn match mbsCConfStFar           '^Far\s\+\ze.*$'            contains=mbsCConfItemK contained nextgroup=mbsCConfProxOpt transparent
syn match mbsCConfStNear          '^Near\s\+\ze.*$'           contains=mbsCConfItemK contained nextgroup=mbsCConfProxOpt transparent
syn match mbsCConfPatternOptOp '[*%!]' display contained
syn match mbsCConfPatternOpt  '.*$' display contained contains=mbsCConfPatternOptOp
syn match mbsCConfStPattern       '^Patterns\?\s\+\ze.*$'     contains=mbsCConfItemK contained nextgroup=mbsCConfPatternOpt transparent
syn match mbsCConfStMaxSize       '^MaxSize\s\+\ze.*$'        contains=mbsCConfItemK contained nextgroup=mbsSize transparent
syn match mbsCConfStMaxMessages   '^MaxMessages\s\+\ze.*$'    contains=mbsCConfItemK contained nextgroup=mbsNumber transparent
syn match mbsCConfStExpireUnread  '^ExpireUnread\s\+\ze.*$'   contains=mbsCConfItemK contained nextgroup=mbsBool transparent
syn match mbsCConfSyncOpt 'None\|All\|\%(\s\+\%(Pull\|Push\|New\|ReNew\|Delete\|Flags\)\)\+' display contained
syn match mbsCConfStSync          '^Sync\s\+\ze.*$'           contains=mbsCConfItemK contained nextgroup=mbsCConfSyncOpt transparent
syn keyword mbsCConfManipOpt  None Far Near Both contained
syn match mbsCConfStCreate        '^Create\s\+\ze.*$'         contains=mbsCConfItemK contained nextgroup=mbsCConfManipOpt transparent
syn match mbsCConfStRemove        '^Remove\s\+\ze.*$'         contains=mbsCConfItemK contained nextgroup=mbsCConfManipOpt transparent
syn match mbsCConfStExpunge       '^Expunge\s\+\ze.*$'        contains=mbsCConfItemK contained nextgroup=mbsCConfManipOpt transparent
syn match mbsCConfStCopyArrivalDate '^CopyArrivalDate\s\+\ze.*$' contains=mbsCConfItemK contained nextgroup=mbsBool transparent
syn match mbsCConfSyncStateOpt  '\*\|.*$' display contained contains=mbsCConfSyncStateOptOp,mbsPath transparent
syn match mbsCConfSyncStateOptOp  '\*' display contained
syn match mbsCConfStSyncState     '^SyncState\s\+\ze.*$'      contains=mbsCConfItemK contained nextgroup=mbsCConfSyncStateOpt transparent

syn cluster mbsCConfItem contains=mbsCConfSt.*

syn keyword mbsCConfItemK
  \ Channel Far Near Pattern[s] MaxSize MaxMessages ExpireUnread Sync Create
  \ Remove Expunge CopyArrivalDate SyncState contained

syn region mbsChannel start="^Channel" end="^$" end="\%$" contains=@mbsCConfItem,mbsCommentL,mbsError transparent

" }}}

" Groups {{{

syn match mbsGConfGroupOpt  '\%([A-Za-z0-9/._+#$%~=\\{}\[\]:@!-]\|\\.\)\+' display contained contains=mbsName nextgroup=mbsGConfChannelOpt
syn match mbsGConfStGroup         '^Group\s\+\ze.*$'          contains=mbsGConfItemK contained nextgroup=mbsGConfGroupOpt transparent
syn match mbsGConfChannelOpt '.*$' display contained
syn match mbsGConfStChannel       '^Channels\?\s\+\ze.*$'     contains=mbsGConfItemK contained nextgroup=mbsGConfChannelOpt transparent

syn cluster mbsGConfItem contains=mbsGConfSt.*

syn keyword mbsGConfItemK  Group Channel[s] contained

syn region mbsGroup start="^Group" end="^$" end="\%$" contains=@mbsGConfItem,mbsError transparent

" }}}

" Global Options {{{

syn match mbsFSync                '^FSync\s\+\ze.*$'          contains=mbsGlobOptItemK nextgroup=mbsBool transparent
syn match mbsFieldDelimiter       '^FieldDelimiter\s\+\ze.*$' contains=mbsGlobOptItemK nextgroup=mbsPath transparent
syn match mbsBufferLimit          '^BufferLimit\s\+\ze.*$'    contains=mbsGlobOptItemK nextgroup=mbsSize transparent

syn keyword mbsGlobOptItemK FSync FieldDelimiter BufferLimit contained
" }}}

" Highlights {{{

hi def link mbsError      Error

hi def link mbsCommentL   Comment

hi def link mbsNumber     Number
hi def link mbsSizeUnit   Type
hi def link mbsPath       String
hi def link mbsString     String
hi def link mbsCommand    String
hi def link mbsCommandPrompt Operator
hi def link mbsName       Constant
hi def link mbsBool       Boolean

hi def link mbsGlobConfItemK  Statement

hi def link mbsMdSConfItemK   Statement
hi def link mbsMdSConfSubFoldersOpt Keyword

hi def link mbsIAConfItemK    Statement
hi def link mbsIAConfTLSTypeOpt Keyword
hi def link mbsIAConfSSLVersionsOpt Keyword

hi def link mbsISConfItemK    Statement

hi def link mbsCConfItemK     Statement
hi def link mbsCConfProxOptOp Operator
hi def link mbsCConfPatternOpt String
hi def link mbsCConfPatternOptOp Operator
hi def link mbsCConfSyncOpt   Keyword
hi def link mbsCConfManipOpt  Keyword
hi def link mbsCConfSyncStateOptOp Operator

hi def link mbsGConfItemK     Statement
hi def link mbsGConfChannelOpt  String

hi def link mbsGlobOptItemK   Statement
" }}}

let &cpo = s:cpo_save
unlet s:cpo_save
