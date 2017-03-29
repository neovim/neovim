include(LibFindMacros)

find_path(WINPTY_INCLUDE_DIR winpty.h)
set(WINPTY_INCLUDE_DIRS ${WINPTY_INCLUDE_DIR})

find_library(WINPTY_LIBRARY winpty)
find_program(WINPTY_AGENT_EXE winpty-agent.exe)
set(WINPTY_LIBRARIES ${WINPTY_LIBRARY})

find_package_handle_standard_args(Winpty DEFAULT_MSG WINPTY_LIBRARY WINPTY_INCLUDE_DIR)
