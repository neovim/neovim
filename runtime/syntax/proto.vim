" Protocol Buffers - Google's data interchange format
" Copyright 2008 Google Inc.  All rights reserved.
" https://developers.google.com/protocol-buffers/
"
" Redistribution and use in source and binary forms, with or without
" modification, are permitted provided that the following conditions are
" met:
"
"     * Redistributions of source code must retain the above copyright
" notice, this list of conditions and the following disclaimer.
"     * Redistributions in binary form must reproduce the above
" copyright notice, this list of conditions and the following disclaimer
" in the documentation and/or other materials provided with the
" distribution.
"     * Neither the name of Google Inc. nor the names of its
" contributors may be used to endorse or promote products derived from
" this software without specific prior written permission.
"
" THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
" "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
" LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
" A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
" OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
" SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
" LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
" DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
" THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
" (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
" OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

" This is the Vim syntax file for Google Protocol Buffers as found at
" https://github.com/protocolbuffers/protobuf
" Last update: 2020 Oct 29

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

syn case match

syn keyword protoTodo       contained TODO FIXME XXX
syn cluster protoCommentGrp contains=protoTodo

syn keyword protoSyntax     syntax import option
syn keyword protoStructure  package message group oneof
syn keyword protoRepeat     optional required repeated
syn keyword protoDefault    default
syn keyword protoExtend     extend extensions to max reserved
syn keyword protoRPC        service rpc returns

syn keyword protoType      int32 int64 uint32 uint64 sint32 sint64
syn keyword protoType      fixed32 fixed64 sfixed32 sfixed64
syn keyword protoType      float double bool string bytes
syn keyword protoTypedef   enum
syn keyword protoBool      true false

syn match   protoInt     /-\?\<\d\+\>/
syn match   protoInt     /\<0[xX]\x+\>/
syn match   protoFloat   /\<-\?\d*\(\.\d*\)\?/
syn region  protoComment start="\/\*" end="\*\/" contains=@pbCommentGrp,@Spell
syn region  protoComment start="//" skip="\\$" end="$" keepend contains=@pbCommentGrp,@Spell
syn region  protoString  start=/"/ skip=/\\./ end=/"/ contains=@Spell
syn region  protoString  start=/'/ skip=/\\./ end=/'/ contains=@Spell

hi def link protoTodo         Todo

hi def link protoSyntax       Include
hi def link protoStructure    Structure
hi def link protoRepeat       Repeat
hi def link protoDefault      Keyword
hi def link protoExtend       Keyword
hi def link protoRPC          Keyword
hi def link protoType         Type
hi def link protoTypedef      Typedef
hi def link protoBool         Boolean

hi def link protoInt          Number
hi def link protoFloat        Float
hi def link protoComment      Comment
hi def link protoString       String

let b:current_syntax = "proto"
