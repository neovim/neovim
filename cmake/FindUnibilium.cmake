# - Try to find unibilium
# Once done this will define
#  Unibilium_FOUND - System has unibilium
#  Unibilium_INCLUDE_DIRS - The unibilium include directories
#  Unibilium_LIBRARIES - The libraries needed to use unibilium

include(LibFindMacros)

libfind_pkg_detect(Unibilium unibilium
  FIND_PATH unibilium.h
  FIND_LIBRARY unibilium)
libfind_process(Unibilium)
