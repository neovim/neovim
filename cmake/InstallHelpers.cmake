# Fix CMAKE_INSTALL_MANDIR on BSD before including GNUInstallDirs. #6771
if(CMAKE_SYSTEM_NAME MATCHES "BSD" AND NOT DEFINED CMAKE_INSTALL_MANDIR)
  if(DEFINED ENV{MANPREFIX})
    set(CMAKE_INSTALL_MANDIR "$ENV{MANPREFIX}/man")
  elseif(CMAKE_INSTALL_PREFIX MATCHES "^/usr/local$")
    set(CMAKE_INSTALL_MANDIR "man")
  endif()
endif()

# For $CMAKE_INSTALL_{DATAROOT,MAN, ...}DIR
include(GNUInstallDirs)

# This will create any directories that need to be created in the destination
# path with the typical owner, group, and user permissions--independent of the
# umask setting.
function(create_install_dir_with_perms)
  cmake_parse_arguments(_install_dir
    ""
    "DESTINATION"
    "DIRECTORY_PERMISSIONS"
    ${ARGN}
  )

  if(NOT _install_dir_DESTINATION)
    message(FATAL_ERROR "Must specify DESTINATION")
  endif()

  if(NOT _install_dir_DIRECTORY_PERMISSIONS)
    set(_install_dir_DIRECTORY_PERMISSIONS
      OWNER_READ OWNER_WRITE OWNER_EXECUTE
      GROUP_READ GROUP_EXECUTE
      WORLD_READ WORLD_EXECUTE)
  endif()

  install(CODE
    "
    set(_current_dir \"\${CMAKE_INSTALL_PREFIX}/${_install_dir_DESTINATION}\")
    set(_dir_permissions \"${_install_dir_DIRECTORY_PERMISSIONS}\")

    set(_parent_dirs)
    set(_prev_dir)

    # Explicitly prepend DESTDIR when using EXISTS.
    # file(INSTALL ...) implicitly respects DESTDIR, but EXISTS does not.
    while(NOT EXISTS \$ENV{DESTDIR}\${_current_dir} AND NOT \${_prev_dir} STREQUAL \${_current_dir})
      list(APPEND _parent_dirs \${_current_dir})
      set(_prev_dir \${_current_dir})
      get_filename_component(_current_dir \${_current_dir} PATH)
    endwhile()

    if(_parent_dirs)
      list(REVERSE _parent_dirs)
    endif()

    # Create any missing folders with the useful permissions.  Note: this uses
    # a hidden option of CMake, but it's been shown to work with 2.8.11 thru
    # 3.0.2.
    foreach(_current_dir \${_parent_dirs})
      if(NOT IS_DIRECTORY \${_current_dir})
        # file(INSTALL ...) implicitly respects DESTDIR, so there's no need to
        # prepend it here.
        file(INSTALL DESTINATION \${_current_dir}
          TYPE DIRECTORY
          DIR_PERMISSIONS \${_dir_permissions}
          FILES \"\")
      endif()
    endforeach()
    ")
endfunction()

# This is to prevent the user's umask from corrupting the expected permissions
# for the parent directories.  We want to behave like the install tool here:
# preserve what's there already, but create new things with useful permissions.
function(install_helper)
  cmake_parse_arguments(_install_helper
    ""
    "DESTINATION;DIRECTORY;RENAME"
    "FILES;PROGRAMS;TARGETS;DIRECTORY_PERMISSIONS;FILE_PERMISSIONS"
    ${ARGN}
  )

  if(NOT _install_helper_DESTINATION AND NOT _install_helper_TARGETS)
    message(FATAL_ERROR "Must specify the DESTINATION path")
  endif()

  if(NOT _install_helper_FILES AND NOT _install_helper_DIRECTORY AND
     NOT _install_helper_PROGRAMS AND NOT _install_helper_TARGETS)
    message(FATAL_ERROR "Must specify FILES, PROGRAMS, TARGETS, or a DIRECTORY to install")
  endif()

  if(NOT _install_helper_DIRECTORY_PERMISSIONS)
    set(_install_helper_DIRECTORY_PERMISSIONS
      OWNER_READ OWNER_WRITE OWNER_EXECUTE
      GROUP_READ GROUP_EXECUTE
      WORLD_READ WORLD_EXECUTE)
  endif()

  if(NOT _install_helper_FILE_PERMISSIONS)
    set(_install_helper_FILE_PERMISSIONS
      OWNER_READ OWNER_WRITE
      GROUP_READ
      WORLD_READ)
  endif()

  if(NOT _install_helper_PROGRAM_PERMISSIONS)
    set(_install_helper_PROGRAM_PERMISSIONS
      OWNER_READ OWNER_WRITE OWNER_EXECUTE
      GROUP_READ GROUP_EXECUTE
      WORLD_READ WORLD_EXECUTE)
  endif()

  if(_install_helper_RENAME)
    set(RENAME RENAME ${_install_helper_RENAME})
  endif()

  if(_install_helper_TARGETS)
    set(_install_helper_DESTINATION "")
  endif()

  if(_install_helper_TARGETS)
    # Ensure the bin area exists with the correct permissions.
    create_install_dir_with_perms(DESTINATION ${CMAKE_INSTALL_BINDIR})

    install(
      TARGETS ${_install_helper_TARGETS}
      RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
  else()
    create_install_dir_with_perms(
      DESTINATION ${_install_helper_DESTINATION}
      DIRECTORY_PERMISSIONS ${_install_helper_DIRECTORY_PERMISSIONS})
  endif()

  if(_install_helper_DIRECTORY)
    install(
      DIRECTORY ${_install_helper_DIRECTORY}
      DESTINATION ${_install_helper_DESTINATION}
      DIRECTORY_PERMISSIONS ${_install_helper_DIRECTORY_PERMISSIONS}
      FILE_PERMISSIONS ${_install_helper_FILE_PERMISSIONS})
  endif()

  if(_install_helper_FILES)
    install(
      FILES ${_install_helper_FILES}
      DESTINATION ${_install_helper_DESTINATION}
      PERMISSIONS ${_install_helper_FILE_PERMISSIONS}
      ${RENAME})
  endif()

  if(_install_helper_PROGRAMS)
    install(
      PROGRAMS ${_install_helper_PROGRAMS}
      DESTINATION ${_install_helper_DESTINATION}
      PERMISSIONS ${_install_helper_PROGRAM_PERMISSIONS}
      ${RENAME})
  endif()
endfunction()
