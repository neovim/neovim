" Vim syntax file
" Language: Graphviz program
" Maintainer: Matthew Fernandez <matthew.fernandez@gmail.com>
" Last Change: Tue, 28 Jul 2020 17:20:44 -0700

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn keyword gvArg  ARGC ARGV
syn keyword gvBeg  BEGIN BEG_G N E END END_G
syn keyword gvFunc
  \ graph fstsubg isDirect isStrict isSubg nEdges nNodes nxtsubg subg
  \ degreeOf fstnode indegreeOf isNode isSubnode node nxtnode nxtnode_sg
    \ outDegreeOf subnode
  \ edge edge_sg fstedge fstedge_sg fstin fstin_sg fstout fstout_sg isEdge
    \ isEdge_sg isSubedge nxtedge nxtedge_sg nxtin nxtin_sg nxtout nxtout_sg opp
    \ subedge
  \ freadG fwriteG readG write[] writeG
  \ aget aset clone cloneG compOf copy[] copyA delete[] fstAttr getDflt hasAttr
    \ induce isAttr isIn kindOf lock[] nxtAttr setDflt
  \ canon gsub html index ishtml length llOf match[] rindex split[] sprintf
    \ sscanf strcmp sub substr tokens tolower toupper urOf xOf yOf
  \ closeF openF print[] printf scanf readL
  \ atan2 cos exp log MAX MIN pow sin[] sqrt
  \ in[] unset
  \ colorx exit[] rand srand system
syn keyword gvCons
  \ NULL TV_bfs TV_dfs TV_en TV_flat TV_fwd TV_ne TV_prepostdfs TV_prepostfwd
  \ TV_prepostrev TV_postdfs TV_postfwd tv_postrev TV_rev
syn keyword gvType char double float int long unsigned void
                 \ string
                 \ edge_t graph_t node_t obj_t
syn match   gvVar 
  \ "\$\(\(F\|G\|NG\|O\|T\|tgtname\|tvedge\|tvnext\|tvroot\|tvtype\)\>\)\?\(\<\)\@!"
syn keyword gvWord break continue else for forr if return switch while

" numbers adapted from c.vim's cNumbers and friends
syn match gvNums      transparent "\<\d\|\.\d" contains=gvNumber,gvFloat,gvOctal
syn match gvNumber    contained "\d\+\(u\=l\{0,2}\|ll\=u\)\>"
syn match gvNumber    contained "0x\x\+\(u\=l\{0,2}\|ll\=u\)\>"
syn match gvOctal     contained "0\o\+\(u\=l\{0,2}\|ll\=u\)\>" contains=gvOctalZero
syn match gvOctalZero contained "\<0"
syn match gvFloat     contained "\d\+f"
syn match gvFloat     contained "\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\="
syn match gvFloat     contained "\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>"
syn match gvFloat     contained "\d\+e[-+]\=\d\+[fl]\=\>"

syn region gvString start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=gvFormat,gvSpecial extend
syn region gvString start="'" skip="\\\\\|\\'" end="'" contains=gvFormat,gvSpecial extend

" adapted from c.vim's cFormat for c_no_c99
syn match gvFormat "%\(\d\+\$\)\=[-+' #0*]*\(\d*\|\*\|\*\d\+\$\)\(\.\(\d*\|\*\|\*\d\+\$\)\)\=\([hlL]\|ll\)\=\([bdiuoxXDOUfeEgGcCsSpn]\|\[\^\=.[^]]*\]\)" contained

syn match gvSpecial "\\." contained

syn region gvCComment   start="//"  skip="\\$" end="$" keepend
syn region gvCPPComment start="#"   skip="\\$" end="$" keepend
syn region gvCXXComment start="/\*" end="\*/" fold

hi def link gvArg        Identifier
hi def link gvBeg        Keyword
hi def link gvFloat      Number
hi def link gvFunc       Identifier
hi def link gvCons       Number
hi def link gvNumber     Number
hi def link gvType       Type
hi def link gvVar        Statement
hi def link gvWord       Keyword

hi def link gvString     String
hi def link gvFormat     Special
hi def link gvSpecial    Special

hi def link gvCComment   Comment
hi def link gvCPPComment Comment
hi def link gvCXXComment Comment

let b:current_syntax = "gvpr"

let &cpo = s:cpo_save
unlet s:cpo_save
