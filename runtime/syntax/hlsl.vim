" Converted from vim9script
" Language:    HLSL (High-Level Shader Language)
" Maintainer:  Maxim Kim <habamax@gmail.com>
" Last Change: 2026 Aug 11
" https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-reference

if exists("b:current_syntax")
    finish
endif

let s:expanded_types = [
  \ 'float', 'double', 'int', 'uint', 'bool',
  \ 'min10float', 'min16float', 'min12int', 'min16int', 'min16uint',
  \ 'float16_t', 'int16_t', 'uint16_t', 'uint64_t', 'int64_t',
  \ 'vector', 'matrix'
  \ ]

" float1, float2 ...
" ...
" int1x1, int1x2 ...
exe $"syn keyword hlslType {s:expanded_types->join()}"
for s:idxN in range(1, 4)
    let s:typeN = s:expanded_types->mapnew({_, type -> type .. s:idxN})->join()
    exe $"syn keyword hlslType {s:typeN}"
    for s:idxM in range(1, 4)
        let s:typeNxM = s:expanded_types
            \ ->mapnew({_, type -> $"{type}{s:idxN}x{s:idxM}"})->join()
        exe $"syn keyword hlslType {s:typeNxM}"
        unlet s:typeNxM
    endfor
    unlet s:idxM
    unlet s:typeN
endfor
unlet s:idxN
syn keyword hlslType void dword half string texture sampler
syn keyword hlslType extern nointerpolation precise shared groupshared static
syn keyword hlslType uniform export extern volatile const row_major column_major
syn keyword hlslType struct linear centroid noperspective sample
syn keyword hlslType typedef namespace class interface enum
syn keyword hlslType snorm unorm
syn keyword hlslType vertexfragment pixelfragment
syn keyword hlslType point line lineadj triangle triangleadj
syn keyword hlslType technique10 technique11
syn keyword hlslType cbuffer tbuffer
syn keyword hlslType Buffer StructuredBuffer AppendStructuredBuffer
syn keyword hlslType ByteAddressBuffer ConsumeStructuredBuffer
syn keyword hlslType Texture1D Texture2D Texture3D Texture1DArray Texture2DArray
syn keyword hlslType Texture2DMS Texture2DMSArray
syn keyword hlslType TextureCube TextureCubeArray
syn keyword hlslType RWBuffer RWByteAddressBuffer RWStructuredBuffer
syn keyword hlslType RWTexture1D RWTexture1DArray RWTexture2D
syn keyword hlslType RWTexture2DArray RWTexture3D
syn keyword hlslType PointStream LineStream TriangleStream
syn keyword hlslType SamplerState SamplerComparisonState
syn keyword hlslType RasterizerState DepthStencilState BlendState
syn keyword hlslType OutputPatch InputPatch
" TODO: only recognize it in function parameter list
syn keyword hlslType in out inout

" legacy
syn keyword hlslType sampler2D

syn keyword hlslCondition if else switch case default
syn keyword hlslRepeat while for do break continue
syn keyword hlslStatement return discard compile compile_fragment packoffset
syn keyword hlslStatement pass register fxgroup
syn keyword hlslConstant true false NULL

" simplified Semantic highlighting: SV_POSITION, SV_TARGET etc
syn match hlslSemantic /:\s*\zs\k\+/

" POSITIONT BINORMAL[n] BLENDINDICES[n] BLENDWEIGHT[n] COLOR[n] NORMAL[n]
" POSITION[n] PSIZE[n] TANGENT[n] TEXCOORD[n]

" SV_ClipDistance[n] SV_CullDistance[n] SV_Coverage SV_Depth
" SV_DepthGreaterEqual SV_DepthLessEqual SV_DispatchThreadID SV_DomainLocation
" SV_GroupID SV_GroupIndex SV_GroupThreadID SV_GSInstanceID SV_InnerCoverage
" SV_InsideTessFactor SV_InstanceID SV_IsFrontFace SV_OutputControlPointID
" SV_Position SV_PrimitiveID SV_RenderTargetArrayIndex SV_SampleIndex
" SV_StencilRef SV_Target[n], where 0 <= n <= 7 SV_TessFactor SV_VertexID
" SV_ViewportArrayIndex SV_ShadingRate

syntax match hlslInteger "\v-?<[0-9]+%(_[0-9]+)*[uUlL]?>" display
syntax match hlslFloat "\v-?<[0-9]+%(_[0-9]+)*%(\.[0-9]+%(_[0-9]+)*)%([eE][+-]=[0-9]+%(_[0-9]+)*)=[hHfFlL]?>" display
syntax match hlslHex "\v<0[xX][0-9A-Fa-f]+%(_[0-9A-Fa-f]+)*[uUlL]?>" display
syntax match hlslOct "\v<0[oO][0-7]+%(_[0-7]+)*[uUlL]?>" display
syntax cluster hlslNumber contains=hlslInteger,hlslFloat,hlslHex,hlslOct

syntax region hlslChar start=+'+ skip=+\\\\\|\\'+ end=+'+ contains=hlslEscape
syntax region hlslString start=+"+ skip=+\\\\\|\\'+ end=+"+ contains=hlslEscape
syntax match  hlslEscape display contained /\\\([abefnrtv\\'"]\|\o\{3}\|x\x\{2}\|u\x\{4}\|U\x\{8}\)/

" TODO: better preproc
syn region hlslPreProc start=/^\s*\zs#/ end=/$/ contains=@hlslNumber,hlslString,hlslChar,@hlslComment

syntax match   hlslTodo "TODO" contained
syntax match   hlslTodo "XXX" contained
syntax match   hlslTodo "FIXME" contained
syntax region  hlslLineComment start=/\/\// end=/$/  contains=@Spell,hlslTodo
syntax region  hlslBlockComment start=/\/\*/ end=/\*\// contains=@Spell,hlslTodo
syntax cluster hlslComment contains=hlslLineComment,hlslBlockComment

hi def link hlslType         Type
hi def link hlslStatement    Statement
hi def link hlslCondition    Statement
hi def link hlslRepeat       Statement
hi def link hlslInteger      Number
hi def link hlslFloat        Float
hi def link hlslHex          Number
hi def link hlslOct          Number
hi def link hlslLineComment  Comment
hi def link hlslBlockComment Comment
hi def link hlslTodo         Todo
hi def link hlslChar         Character
hi def link hlslString       String
hi def link hlslEscape       Special
hi def link hlslPreProc      PreProc
hi def link hlslSemantic     Identifier

let b:current_syntax = "hlsl"
