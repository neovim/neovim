" Vim syntax file for Godot shading language
" Language:     gdshader
" Maintainer:   Maxim Kim <habamax@gmail.com>
" Filenames:    *.gdshader

if exists("b:current_syntax")
    finish
endif

syn keyword gdshaderConditional if else switch case default
syn keyword gdshaderRepeat for while do
syn keyword gdshaderStatement return discard
syn keyword gdshaderBoolean true false

syn keyword gdshaderKeyword shader_type render_mode
syn keyword gdshaderKeyword in out inout
syn keyword gdshaderKeyword lowp mediump highp
syn keyword gdshaderKeyword uniform varying const
syn keyword gdshaderKeyword flat smooth

syn keyword gdshaderType float vec2 vec3 vec4
syn keyword gdshaderType uint uvec2 uvec3 uvec4
syn keyword gdshaderType int ivec2 ivec3 ivec4
syn keyword gdshaderType void bool
syn keyword gdshaderType bvec2 bvec3 bvec4
syn keyword gdshaderType mat2 mat3 mat4
syn keyword gdshaderType sampler2D isampler2D usampler2D samplerCube

syn match gdshaderMember "\v<(\.)@<=[a-z_]+\w*>"
syn match gdshaderBuiltin "\v<[A-Z_]+[A-Z0-9_]*>"
syn match gdshaderFunction "\v<\w*>(\()@="

syn match gdshaderNumber "\v<\d+(\.)@!>"
syn match gdshaderFloat "\v<\d*\.\d+(\.)@!>"
syn match gdshaderFloat "\v<\d*\.=\d+(e-=\d+)@="
syn match gdshaderExponent "\v(\d*\.=\d+)@<=e-=\d+>"

syn match gdshaderComment "\v//.*$" contains=@Spell
syn region gdshaderComment start="/\*" end="\*/" contains=@Spell
syn keyword gdshaderTodo TODO FIXME XXX NOTE BUG HACK OPTIMIZE containedin=gdshaderComment

hi def link gdshaderConditional Conditional
hi def link gdshaderRepeat Repeat
hi def link gdshaderStatement Statement
hi def link gdshaderBoolean Boolean
hi def link gdshaderKeyword Keyword
hi def link gdshaderMember Identifier
hi def link gdshaderBuiltin Identifier
hi def link gdshaderFunction Function
hi def link gdshaderType Type
hi def link gdshaderNumber Number
hi def link gdshaderFloat Float
hi def link gdshaderExponent Special
hi def link gdshaderComment Comment
hi def link gdshaderTodo Todo

let b:current_syntax = "gdshader"
