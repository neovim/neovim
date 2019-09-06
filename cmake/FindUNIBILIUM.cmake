# - Try to find unibilium
# Once done this will define
#  UNIBILIUM_FOUND - System has unibilium
#  UNIBILIUM_INCLUDE_DIRS - The unibilium include directories
#  UNIBILIUM_LIBRARIES - The libraries needed to use unibilium

include(LibFindMacros)

libfind_pkg_detect(UNIBILIUM unibilium
  FIND_PATH unibilium.h
  FIND_LIBRARY unibilium)
libfind_process(UNIBILIUM)
