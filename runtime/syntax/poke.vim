" Copyright (C) 2021 Matthew T. Ihlenfield.
"
" This program is free software: you can redistribute it and/or modify
" it under the terms of the GNU General Public License as published by
" the Free Software Foundation, either version 3 of the License, or
" (at your option) any later version.
"
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
"
" You should have received a copy of the GNU General Public License
" along with this program.  If not, see <http://www.gnu.org/licenses/>.
"
" Vim syntax file
" Language: Poke
" Maintainer: Matt Ihlenfield <mtihlenfield@protonmail.com>
" Filenames: *.pk
" Latest Revision: 10 March 2021

if exists('b:current_syntax')
    finish
endif

" Poke statement
syn keyword pokeStatement assert break continue return
syn keyword pokeStatement type unit fun method nextgroup=pokeFunction skipwhite
syn keyword pokeStatement var nextgroup=pokeVar skipWhite

" Identifiers
syn match pokeVar '\h\w*' display contained

" User defined functions
syn match pokeFunction '\h\w*' display contained

" Poke operators
syn keyword pokeOperator in sizeof as isa unmap

" Conditionals
syn keyword pokeConditional if else where

" Structures, unions, etc...
syn keyword pokeStructure struct union pinned

" Loops
syn keyword pokeRepeat while for

" Imports
syn keyword pokeLoad load

" Exceptions
syn keyword pokeException try catch until raise

" Exception types
syn keyword pokeExceptionType Exception E_generic E_out_of_bounds
syn keyword pokeExceptionType E_eof E_elem E_constraint
syn keyword pokeExceptionType E_conv E_map_bounds E_map
syn keyword pokeExceptionType E_div_by_zero E_no_ios E_no_return
syn keyword pokeExceptionType E_io E_io_flags E_assert E_overflow

" Exception codes
syn keyword pokeExceptionCode EC_generic EC_out_of_bounds
syn keyword pokeExceptionCode EC_eof EC_elem EC_constraint
syn keyword pokeExceptionCode EC_conv EC_map_bounds EC_map
syn keyword pokeExceptionCode EC_div_by_zero EC_no_ios EC_no_return
syn keyword pokeExceptionCode EC_io EC_io_flags EC_assert EC_overflow

" Poke builtin types
syn keyword pokeBuiltinType string void int uint bit nibble
syn keyword pokeBuiltinType byte char ushort short ulong long
syn keyword pokeBuiltinType uint8 uint16 uint32 uint64
syn keyword pokeBuiltinType off64 uoff64 offset
syn keyword pokeBuiltinType Comparator POSIX_Time32 POSIX_Time64
syn keyword pokeBuiltinType big little any

" Poke constants
syn keyword pokeConstant ENDIAN_LITTLE ENDIAN_BIG
syn keyword pokeConstant IOS_F_READ IOS_F_WRITE IOS_F_TRUNCATE IOS_F_CREATE
syn keyword pokeConstant IOS_M_RDONLY IOS_M_WRONLY IOS_M_RDWR
syn keyword pokeConstant load_path NULL OFFSET

" Poke std lib
syn keyword pokeBuiltinFunction print printf catos stoca atoi ltos reverse
syn keyword pokeBuiltinFunction ltrim rtrim strchr qsort crc32 alignto
syn keyword pokeBuiltinFunction open close flush get_ios set_ios iosize
syn keyword pokeBuiltinFunction rand get_endian set_endian strace exit
syn keyword pokeBuiltinFunction getenv

" Formats

" Special chars
syn match pokeSpecial "\\\([nt\\]\|\o\{1,3}\)" display contained

" Chars
syn match pokeChar "'[^']*'" contains=pokeSpecial

" Attributes
syn match pokeAttribute "\h\w*'\h\w"

" Strings
syn region pokeString skip=+\\\\\|\\"+ start=+"+ end=+"+ contains=pokeSpecial

" Integer literals
syn match pokeInteger "\<\d\+_*\d*\([LlHhBbNn]\=[Uu]\=\|[Uu]\=[LlHhBbNn]\=\)\>"
syn match pokeInteger "\<0[Xx]\x\+_*\x*\([LlHhBbNn]\=[Uu]\=\|[Uu]\=[LlHhBbNn]\=\)\>"
syn match pokeInteger "\<0[Oo]\o\+_*\o*\([LlHhBbNn]\=[Uu]\=\|[Uu]\=[LlHhBbNn]\=\)\>"
syn match pokeInteger "\<0[Bb][01]\+_*[01]*\([LlHhBbNn]\=[Uu]\=\|[Uu]\=[LlHhBbNn]\=\)\>"

" Units
syn keyword pokeBuiltinUnit b M B
syn keyword pokeBuiltinUnit Kb KB Mb MB Gb GB
syn keyword pokeBuiltinUnit Kib KiB Mib MiB Gib GiB

" Offsets
syn match pokeOffset "#\h\w*" contains=pokeBuiltinUnit

" Comments
syn keyword pokeCommentTodo TODO FIXME XXX TBD contained
syn match pokeLineComment "\/\/.*" contains=pokeCommentTodo,@Spell extend
syn region pokeComment start="/\*"  end="\*/" contains=pokeCommentTodo,@Spell fold extend

" Allow folding of blocks
syn region pokeBlock start="{" end="}" transparent fold

" Highlight groups
hi def link pokeBuiltinFunction Function
hi def link pokeBuiltinType Type
hi def link pokeBuiltinUnit Keyword
hi def link pokeChar Character
hi def link pokeComment Comment
hi def link pokeCommentTodo Todo
hi def link pokeConditional Conditional
hi def link pokeConstant Constant
hi def link pokeException Exception
hi def link pokeExceptionCode Constant
hi def link pokeExceptionType Type
hi def link pokeFunction Function
hi def link pokeInteger Number
hi def link pokeLineComment Comment
hi def link pokeLoad Include
hi def link pokeOffset StorageClass
hi def link pokeOperator Operator
hi def link pokeSpecial SpecialChar
hi def link pokeStatement Statement
hi def link pokeString String
hi def link pokeStructure Structure
hi def link pokeRepeat Repeat
hi def link pokeVar Identifier

let b:current_syntax = 'poke'
