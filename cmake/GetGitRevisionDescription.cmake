# https://github.com/rpavlik/cmake-modules
#
# - Returns a version string from Git
#
# These functions force a re-configure on each git commit so that you can
# trust the values of the variables in your build system.
#
#  get_git_head_revision(<refspecvar> <hashvar> [<additional arguments to git describe> ...])
#
# Returns the refspec and sha hash of the current head revision
#
#  git_describe(<var> [<additional arguments to git describe> ...])
#
# Returns the results of git describe on the source tree, and adjusting
# the output so that it tests false if an error occurs.
#
#  git_get_exact_tag(<var> [<additional arguments to git describe> ...])
#
# Returns the results of git describe --exact-match on the source tree,
# and adjusting the output so that it tests false if there was no exact
# matching tag.
#
# Requires CMake 2.6 or newer (uses the 'function' command)
#
# Original Author:
# 2009-2010 Ryan Pavlik <rpavlik@iastate.edu> <abiryan@ryand.net>
# http://academic.cleardefinition.com
# Iowa State University HCI Graduate Program/VRAC
#
# Copyright Iowa State University 2009-2010.
# Distributed under the Boost Software License, Version 1.0.
# (See accompanying file LICENSE_1_0.txt or copy at
# http://www.boost.org/LICENSE_1_0.txt)

if(__get_git_revision_description)
  return()
endif()
set(__get_git_revision_description YES)

# We must run the following at "include" time, not at function call time,
# to find the path to this module rather than the path to a calling list file
get_filename_component(_gitdescmoddir ${CMAKE_CURRENT_LIST_FILE} PATH)

function(get_git_head_revision _refspecvar _hashvar)
  set(GIT_PARENT_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
  set(GIT_DIR "${GIT_PARENT_DIR}/.git")
  while(NOT EXISTS "${GIT_DIR}")	# .git dir not found, search parent directories
    set(GIT_PREVIOUS_PARENT "${GIT_PARENT_DIR}")
    get_filename_component(GIT_PARENT_DIR ${GIT_PARENT_DIR} PATH)
    if(GIT_PARENT_DIR STREQUAL GIT_PREVIOUS_PARENT)
      # We have reached the root directory, we are not in git
      set(${_refspecvar} "GITDIR-NOTFOUND" PARENT_SCOPE)
      set(${_hashvar} "GITDIR-NOTFOUND" PARENT_SCOPE)
      return()
    endif()
    set(GIT_DIR "${GIT_PARENT_DIR}/.git")
  endwhile()
  # check if this is a submodule
  if(NOT IS_DIRECTORY ${GIT_DIR})
    file(READ ${GIT_DIR} submodule)
    string(REGEX REPLACE "gitdir: (.*)\n$" "\\1" GIT_DIR_RELATIVE ${submodule})
    get_filename_component(SUBMODULE_DIR ${GIT_DIR} PATH)
    get_filename_component(GIT_DIR ${SUBMODULE_DIR}/${GIT_DIR_RELATIVE} ABSOLUTE)
  endif()
  set(GIT_DATA "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/git-data")
  if(NOT EXISTS "${GIT_DATA}")
    file(MAKE_DIRECTORY "${GIT_DATA}")
  endif()

  if(NOT EXISTS "${GIT_DIR}/HEAD")
    return()
  endif()
  set(HEAD_FILE "${GIT_DATA}/HEAD")
  configure_file("${GIT_DIR}/HEAD" "${HEAD_FILE}" COPYONLY)

  configure_file("${_gitdescmoddir}/GetGitRevisionDescription.cmake.in"
    "${GIT_DATA}/grabRef.cmake"
    @ONLY)
  include("${GIT_DATA}/grabRef.cmake")

  set(${_refspecvar} "${HEAD_REF}" PARENT_SCOPE)
  set(${_hashvar} "${HEAD_HASH}" PARENT_SCOPE)
endfunction()

function(git_describe _var)
  if(NOT GIT_FOUND)
    find_package(Git QUIET)
  endif()
  get_git_head_revision(refspec hash)
  if(NOT GIT_FOUND)
    set(${_var} "GIT-NOTFOUND" PARENT_SCOPE)
    return()
  endif()
  if(NOT hash)
    set(${_var} "HEAD-HASH-NOTFOUND" PARENT_SCOPE)
    return()
  endif()

  # TODO sanitize
  #if((${ARGN}" MATCHES "&&") OR
  #	(ARGN MATCHES "||") OR
  #	(ARGN MATCHES "\\;"))
  #	message("Please report the following error to the project!")
  #	message(FATAL_ERROR "Looks like someone's doing something nefarious with git_describe! Passed arguments ${ARGN}")
  #endif()

  #message(STATUS "Arguments to execute_process: ${ARGN}")

  execute_process(COMMAND
    "${GIT_EXECUTABLE}"
    describe
    ${hash}
    ${ARGN}
    WORKING_DIRECTORY
    "${CMAKE_SOURCE_DIR}"
    RESULT_VARIABLE
    res
    OUTPUT_VARIABLE
    out
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT res EQUAL 0)
    set(out "${out}-${res}-NOTFOUND")
  endif()

  set(${_var} "${out}" PARENT_SCOPE)
endfunction()

function(git_timestamp _var)
  if(NOT GIT_FOUND)
    find_package(Git QUIET)
  endif()
  get_git_head_revision(refspec hash)
  if(NOT GIT_FOUND)
    set(${_var} "GIT-NOTFOUND" PARENT_SCOPE)
    return()
  endif()
  if(NOT hash)
    set(${_var} "HEAD-HASH-NOTFOUND" PARENT_SCOPE)
    return()
  endif()

  execute_process(COMMAND "${GIT_EXECUTABLE}" log -1 --format="%ci" ${hash} ${ARGN}
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    RESULT_VARIABLE res
    OUTPUT_VARIABLE out
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(NOT res EQUAL 0)
    set(out "${out}-${res}-NOTFOUND")
  endif()
  string(REGEX REPLACE "[-\" :]" "" out ${out})
  string(SUBSTRING ${out} 0 12 out)

  set(${_var} ${out} PARENT_SCOPE)
endfunction()

function(git_get_exact_tag _var)
  git_describe(out --exact-match ${ARGN})
  set(${_var} "${out}" PARENT_SCOPE)
endfunction()
