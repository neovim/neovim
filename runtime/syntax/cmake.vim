" Vim syntax file
" Program:      CMake - Cross-Platform Makefile Generator
" Module:       $RCSfile: cmake-syntax.vim,v $
" Language:     CMake
" Maintainer:	Dimitri Merejkowsky <d.merej@gmail.com>
" Former Maintainer:   Karthik Krishnan <karthik.krishnan@kitware.com>
" Author:       Andy Cedilnik <andy.cedilnik@kitware.com>
" Last Change:  2015 Dec 17
" Version:      $Revision: 1.10 $
"
" Licence:      The CMake license applies to this file. See
"               http://www.cmake.org/HTML/Copyright.html
"               This implies that distribution with Vim is allowed

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

syn case ignore
syn match cmakeEscaped /\(\\\\\|\\"\|\\n\|\\t\)/ contained
syn region cmakeComment start="#" end="$" contains=@Spell,cmakeTodo
syn region cmakeRegistry start=/\[/ end=/]/
            \ contained oneline contains=CONTAINED,cmakeTodo,cmakeEscaped
syn region cmakeVariableValue start=/\${/ end=/}/
            \ contained oneline contains=CONTAINED,cmakeTodo
syn region cmakeEnvironment start=/\$ENV{/ end=/}/
            \ contained oneline contains=CONTAINED,cmakeTodo
syn region cmakeString start=/"/ end=/"/
            \ contains=CONTAINED,cmakeTodo,cmakeOperators
syn region cmakeArguments start=/(/ end=/)/
            \ contains=ALLBUT,cmakeArguments,cmakeTodo
syn keyword cmakeSystemVariables
            \ WIN32 UNIX APPLE CYGWIN BORLAND MINGW MSVC MSVC_IDE MSVC60 MSVC70 MSVC71 MSVC80 MSVC90
syn keyword cmakeOperators
            \ ABSOLUTE AND BOOL CACHE COMMAND DEFINED DOC EQUAL EXISTS EXT FALSE GREATER INTERNAL LESS MATCHES NAME NAMES NAME_WE NOT OFF ON OR PATH PATHS PROGRAM STREQUAL STRGREATER STRING STRLESS TRUE
            \ contained
syn keyword cmakeDeprecated ABSTRACT_FILES BUILD_NAME SOURCE_FILES SOURCE_FILES_REMOVE VTK_MAKE_INSTANTIATOR VTK_WRAP_JAVA VTK_WRAP_PYTHON VTK_WRAP_TCL WRAP_EXCLUDE_FILES
           \ nextgroup=cmakeArguments

" The keywords are generated as:  cmake --help-command-list | tr "\n" " "
syn keyword cmakeStatement
      \ ADD_CUSTOM_COMMAND ADD_CUSTOM_TARGET ADD_DEFINITIONS ADD_DEPENDENCIES ADD_EXECUTABLE ADD_LIBRARY ADD_SUBDIRECTORY ADD_TEST AUX_SOURCE_DIRECTORY BUILD_COMMAND BUILD_NAME CMAKE_MINIMUM_REQUIRED CONFIGURE_FILE CREATE_TEST_SOURCELIST ELSE ELSEIF ENABLE_LANGUAGE ENABLE_TESTING ENDFOREACH ENDFUNCTION ENDIF ENDMACRO ENDWHILE EXEC_PROGRAM EXECUTE_PROCESS EXPORT_LIBRARY_DEPENDENCIES FILE FIND_FILE FIND_LIBRARY FIND_PACKAGE FIND_PATH FIND_PROGRAM FLTK_WRAP_UI FOREACH FUNCTION GET_CMAKE_PROPERTY GET_DIRECTORY_PROPERTY GET_FILENAME_COMPONENT GET_SOURCE_FILE_PROPERTY GET_TARGET_PROPERTY GET_TEST_PROPERTY IF INCLUDE INCLUDE_DIRECTORIES INCLUDE_EXTERNAL_MSPROJECT INCLUDE_REGULAR_EXPRESSION INSTALL INSTALL_FILES INSTALL_PROGRAMS INSTALL_TARGETS LINK_DIRECTORIES LINK_LIBRARIES LIST LOAD_CACHE LOAD_COMMAND MACRO MAKE_DIRECTORY MARK_AS_ADVANCED MATH MESSAGE OPTION OUTPUT_REQUIRED_FILES PROJECT QT_WRAP_CPP QT_WRAP_UI REMOVE REMOVE_DEFINITIONS SEPARATE_ARGUMENTS SET SET_DIRECTORY_PROPERTIES SET_SOURCE_FILES_PROPERTIES SET_TARGET_PROPERTIES SET_TESTS_PROPERTIES SITE_NAME SOURCE_GROUP STRING SUBDIR_DEPENDS SUBDIRS TARGET_LINK_LIBRARIES TRY_COMPILE TRY_RUN UNSET USE_MANGLED_MESA UTILITY_SOURCE VARIABLE_REQUIRES VTK_MAKE_INSTANTIATOR VTK_WRAP_JAVA VTK_WRAP_PYTHON VTK_WRAP_TCL WHILE WRITE_FILE
            \ nextgroup=cmakeArguments
syn keyword cmakeTodo
            \ TODO FIXME XXX
            \ contained

" Define the default highlighting.
" Only when an item doesn't have highlighting yet

hi def link cmakeStatement Statement
hi def link cmakeComment Comment
hi def link cmakeString String
hi def link cmakeVariableValue Type
hi def link cmakeRegistry Underlined
hi def link cmakeArguments Identifier
hi def link cmakeArgument Constant
hi def link cmakeEnvironment Special
hi def link cmakeOperators Operator
hi def link cmakeMacro PreProc
hi def link cmakeError Error
hi def link cmakeTodo TODO
hi def link cmakeEscaped Special


let b:current_syntax = "cmake"

let &cpo = s:keepcpo
unlet s:keepcpo

"EOF"
