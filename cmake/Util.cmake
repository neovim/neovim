# Defines a target that depends on FILES and the files found by globbing
# when using GLOB_PAT and GLOB_DIRS. The target will rerun if any files it
# depends on has changed. Which files the target will run the command on
# depends on the value of TOUCH_STRATEGY.
#
# Options:
# REQUIRED            - Abort if COMMAND doesn't exist.
#
# Single value arguments:
# TARGET         - Name of the target
# COMMAND        - Path of the command to be run
# GLOB_PAT       - Glob pattern to use. Only used if GLOB_DIRS is specified
# TOUCH_STRATEGY - Specify touch strategy, meaning decide how to group files
#                  and connect them to a specific touch file.
#
# For example, let us say we have file A and B and that we create a touch file
# for each of them, TA and TB. This would essentially make file A and B
# independent of each other, meaning that if I change file A and run the
# target, then the target will only run its commands for file A and ignore
# file B.
#
# Another example: let's say we have file A and B, but now we create only a
# single touch file T for both of them. This would mean that if I change
# either file A or B, then the target will run its commands on both A and B.
# Meaning that even if I only change file A, the target will still run
# commands on both A and B.
#
# The more touch files we create for a target, the fewer commands we'll need
# to rerun, and by extension, the more time we'll save. Unfortunately, the
# more touch files we create the more intermediary targets will be created,
# one for each touch file. This makes listing all targets with
# `cmake --build build --target help` less useful since each touch file will
# be listed. The tradeoff that needs to be done here is between performance
# and "discoverability". As a general guideline: the more popular a target is
# and the more time it takes to run it, the more granular you want your touch
# files to be. Conversely, if a target rarely needs to be run or if it's fast,
# then you should create fewer targets.
#
# Possible values for TOUCH_STRATEGY:
# "SINGLE":   create a single touch file for all files.
# "PER_FILE": create a touch file for each file. Defaults to this if
#             TOUCH_STRATEGY isn't specified.
# "PER_DIR":  create a touch file for each directory.
#
# List arguments:
# FLAGS     - List of flags to use after COMMAND
# FILES     - List of files to use COMMAND on. It's possible to combine this
#             with GLOB_PAT and GLOB_DIRS; the files found by globbing will
#             simple be added to FILES
# GLOB_DIRS - The directories to recursively search for files with extension
#             GLOB_PAT
#
function(add_glob_targets)
  cmake_parse_arguments(ARG
    "REQUIRED"
    "TARGET;COMMAND;GLOB_PAT;TOUCH_STRATEGY"
    "FLAGS;FILES;GLOB_DIRS"
    ${ARGN}
  )

  if(NOT ARG_COMMAND)
    add_custom_target(${ARG_TARGET})
    if(ARG_REQUIRED)
      add_custom_command(TARGET ${ARG_TARGET}
        COMMAND ${CMAKE_COMMAND} -E echo "${ARG_TARGET}: ${ARG_COMMAND} not found"
        COMMAND false)
    else()
      add_custom_command(TARGET ${ARG_TARGET}
        COMMAND ${CMAKE_COMMAND} -E echo "${ARG_TARGET} SKIP: ${ARG_COMMAND} not found")
    endif()
    return()
  endif()

  foreach(gd ${ARG_GLOB_DIRS})
    file(GLOB_RECURSE globfiles ${PROJECT_SOURCE_DIR}/${gd}/${ARG_GLOB_PAT})
    list(APPEND ARG_FILES ${globfiles})
  endforeach()

  if(NOT ARG_TOUCH_STRATEGY)
    set(ARG_TOUCH_STRATEGY PER_FILE)
  endif()
  set(POSSIBLE_TOUCH_STRATEGIES SINGLE PER_FILE PER_DIR)
  if(NOT ARG_TOUCH_STRATEGY IN_LIST POSSIBLE_TOUCH_STRATEGIES)
    message(FATAL_ERROR "Unrecognized value for TOUCH_STRATEGY: ${ARG_TOUCH_STRATEGY}")
  endif()

  if(ARG_TOUCH_STRATEGY STREQUAL SINGLE)
    set(touch_file ${TOUCHES_DIR}/ran-${ARG_TARGET})
    add_custom_command(
      OUTPUT ${touch_file}
      COMMAND ${CMAKE_COMMAND} -E touch ${touch_file}
      COMMAND ${ARG_COMMAND} ${ARG_FLAGS} ${ARG_FILES}
      WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
      DEPENDS ${ARG_FILES})
    list(APPEND touch_list ${touch_file})
  elseif(ARG_TOUCH_STRATEGY STREQUAL PER_FILE)
    set(touch_dir ${TOUCHES_DIR}/${ARG_TARGET})
    file(MAKE_DIRECTORY ${touch_dir})
    foreach(f ${ARG_FILES})
      string(REGEX REPLACE "^${PROJECT_SOURCE_DIR}/" "" tf ${f})
      string(REGEX REPLACE "[/.]" "-" tf ${tf})
      set(touch_file ${touch_dir}/ran-${tf})
      add_custom_command(
        OUTPUT ${touch_file}
        COMMAND ${CMAKE_COMMAND} -E touch ${touch_file}
        COMMAND ${ARG_COMMAND} ${ARG_FLAGS} ${f}
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${f})
      list(APPEND touch_list ${touch_file})
    endforeach()
  elseif(ARG_TOUCH_STRATEGY STREQUAL PER_DIR)
    set(touch_dirs)
    foreach(f ${ARG_FILES})
      get_filename_component(out ${f} DIRECTORY)
      list(APPEND touch_dirs ${out})
    endforeach()
    list(REMOVE_DUPLICATES touch_dirs)

    foreach(touch_dir ${touch_dirs})
      set(relevant_files)
      foreach(f ${ARG_FILES})
        get_filename_component(out ${f} DIRECTORY)
        if(${touch_dir} STREQUAL ${out})
          list(APPEND relevant_files ${f})
        endif()
      endforeach()

      set(td ${TOUCHES_DIR}/${ARG_TARGET})
      file(MAKE_DIRECTORY ${td})
      string(REGEX REPLACE "^${PROJECT_SOURCE_DIR}/" "" tf ${touch_dir})
      string(REGEX REPLACE "[/.]" "-" tf ${tf})
      set(touch_file ${td}/ran-${tf})

      add_custom_command(
        OUTPUT ${touch_file}
        COMMAND ${CMAKE_COMMAND} -E touch ${touch_file}
        COMMAND ${ARG_COMMAND} ${ARG_FLAGS} ${relevant_files}
        WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
        DEPENDS ${relevant_files})
      list(APPEND touch_list ${touch_file})
    endforeach()
  endif()

  add_custom_target(${ARG_TARGET} DEPENDS ${touch_list})
endfunction()
