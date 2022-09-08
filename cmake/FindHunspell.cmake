# - Try to find hunspell
# Once done, this will define
#
#  Hunspell_FOUND        - system has hunspell
#  Hunspell_INCLUDE_DIRS - the hunspell include directories
#  Hunspell_LIBRARIES    - link these to use hunspell

include(LibFindMacros)

libfind_pkg_detect(Hunspell hunspell FIND_PATH hunspell/hunspell.h FIND_LIBRARY hunspell)
libfind_process(Hunspell)
