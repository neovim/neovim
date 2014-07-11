" Vim syntax file
" Language:	3D wavefront's obj file
" Maintainer:	Vincent Berthoux <twinside@gmail.com>
" File Types:	.obj (used in 3D)
" Last Change:  2010 May 18
"
" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn match       objError        "^\a\+"

syn match       objKeywords     "^cstype\s"
syn match       objKeywords     "^ctech\s"
syn match       objKeywords     "^stech\s"
syn match       objKeywords     "^deg\s"
syn match       objKeywords     "^curv\(2\?\)\s"
syn match       objKeywords     "^parm\s"
syn match       objKeywords     "^surf\s"
syn match       objKeywords     "^end\s"
syn match       objKeywords     "^bzp\s"
syn match       objKeywords     "^bsp\s"
syn match       objKeywords     "^res\s"
syn match       objKeywords     "^cdc\s"
syn match       objKeywords     "^con\s"

syn match       objKeywords     "^shadow_obj\s"
syn match       objKeywords     "^trace_obj\s"
syn match       objKeywords     "^usemap\s"
syn match       objKeywords     "^lod\s"
syn match       objKeywords     "^maplib\s"
syn match       objKeywords     "^d_interp\s"
syn match       objKeywords     "^c_interp\s"
syn match       objKeywords     "^bevel\s"
syn match       objKeywords     "^mg\s"
syn match       objKeywords     "^s\s"
syn match       objKeywords     "^con\s"
syn match       objKeywords     "^trim\s"
syn match       objKeywords     "^hole\s"
syn match       objKeywords     "^scrv\s"
syn match       objKeywords     "^sp\s"
syn match       objKeywords     "^step\s"
syn match       objKeywords     "^bmat\s"
syn match       objKeywords     "^csh\s"
syn match       objKeywords     "^call\s"

syn match       objComment      "^#.*"
syn match       objVertex       "^v\s"
syn match       objFace         "^f\s"
syn match       objVertice      "^vt\s"
syn match       objNormale      "^vn\s"
syn match       objGroup        "^g\s.*"
syn match       objMaterial     "^usemtl\s.*"
syn match       objInclude      "^mtllib\s.*"

syn match       objFloat        "-\?\d\+\.\d\+\(e\(+\|-\)\d\+\)\?"
syn match       objInt          "\d\+"
syn match       objIndex        "\d\+\/\d*\/\d*"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_cabal_syn_inits")
  if version < 508
    let did_cabal_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink objError           Error
  HiLink objComment         Comment
  HiLink objInclude         PreProc
  HiLink objFloat           Float
  HiLink objInt             Number
  HiLink objGroup           Structure
  HiLink objIndex           Constant
  HiLink objMaterial        Label

  HiLink objVertex          Keyword
  HiLink objNormale         Keyword
  HiLink objVertice         Keyword
  HiLink objFace            Keyword
  HiLink objKeywords        Keyword


  delcommand HiLink
endif

let b:current_syntax = "obj"

" vim: ts=8
