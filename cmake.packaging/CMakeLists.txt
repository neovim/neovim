set(CPACK_PACKAGE_NAME "Neovim")
set(CPACK_PACKAGE_VENDOR "neovim.io")
set(CPACK_PACKAGE_FILE_NAME "nvim")
set(CPACK_PACKAGE_DIRECTORY ${PROJECT_BINARY_DIR})

# From the GitHub About section
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Vim-fork focused on extensibility and usability.")

set(CPACK_PACKAGE_INSTALL_DIRECTORY ${CPACK_PACKAGE_NAME})

# Pull the versions defined with the top level CMakeLists.txt
set(CPACK_PACKAGE_VERSION_MAJOR ${NVIM_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${NVIM_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${NVIM_VERSION_PATCH})

# CPACK_VERBATIM_VARIABLES ensures that the variables prefixed with *CPACK_*
# are correctly passed to the cpack program.
# This should always be set to true.
set(CPACK_VERBATIM_VARIABLES TRUE)

set(CPACK_RESOURCE_FILE_LICENSE "${PROJECT_SOURCE_DIR}/LICENSE.txt")
set(CPACK_RESOURCE_FILE_README ${PROJECT_SOURCE_DIR}/README.md)


if(WIN32)
  set(CPACK_PACKAGE_FILE_NAME "nvim-win64")
  set(CPACK_GENERATOR ZIP WIX)

  # WIX
  # CPACK_WIX_UPGRADE_GUID should be set, but should never change.
  # CPACK_WIX_PRODUCT_GUID should not be set (leave as default to auto-generate).

  # The following guid is just a randomly generated guid that's been pasted here.
  # It has no special meaning other than to supply it to WIX.
  set(CPACK_WIX_UPGRADE_GUID "207A1A70-7B0C-418A-A153-CA6883E38F4D")
  set(CPACK_WIX_PRODUCT_ICON ${PROJECT_SOURCE_DIR}/runtime/neovim.ico)

  # Create start menu and desktop shortcuts
  set(CPACK_WIX_PROGRAM_MENU_FOLDER "${CPACK_PACKAGE_NAME}")
  set(CPACK_PACKAGE_EXECUTABLES "nvim" "Neovim")
  set(CPACK_WIX_INSTALL_SCOPE "perMachine")

  set(CPACK_WIX_UI_REF "WixUI_CustomInstallDir")
  list(APPEND CPACK_WIX_EXTRA_SOURCES ${CMAKE_CURRENT_LIST_DIR}/WixUI_CustomInstallDir.wxs)
  list(APPEND CPACK_WIX_EXTRA_SOURCES ${CMAKE_CURRENT_LIST_DIR}/CustomInstallDirDlg.wxs)

  # We use a wix patch to add further options to the installer.
  # See: https://cmake.org/cmake/help/v3.7/module/CPackWIX.html#variable:CPACK_WIX_PATCH_FILE
  list(APPEND CPACK_WIX_EXTENSIONS WixUtilExtension)
  list(APPEND CPACK_WIX_PATCH_FILE ${CMAKE_CURRENT_LIST_DIR}/WixPatch.xml)
elseif(APPLE)
  set(CPACK_PACKAGE_FILE_NAME "nvim-macos-${CMAKE_SYSTEM_PROCESSOR}")
  set(CPACK_GENERATOR TGZ)
  set(CPACK_PACKAGE_ICON ${CMAKE_CURRENT_LIST_DIR}/neovim.icns)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(CPACK_PACKAGE_FILE_NAME "nvim-linux-${CMAKE_SYSTEM_PROCESSOR}")
  set(CPACK_GENERATOR TGZ DEB)
  set(CPACK_DEBIAN_PACKAGE_NAME "Neovim") # required
  set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Neovim.io") # required

  # Automatically compute required shared lib dependencies.
  # Unfortunately, you "just need to know" that this has a hidden
  # dependency on dpkg-shlibdeps whilst using a debian based host.
  set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS TRUE)
else()
  set(CPACK_GENERATOR TGZ)
endif()

# CPack variables are loaded in on the call to include(CPack). If you set
# variables *after* the inclusion, they don't get updated within the CPack
# config. Note that some CPack commands should still be run after it, such
# as cpack_add_component().
include(CPack)
