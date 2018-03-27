#### Partial comes from https://github.com/conda-forge/winpty-feedstock/blob/master/recipe/CMakeLists.txt
project(winpty)

cmake_minimum_required (VERSION 2.8)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${CMAKE_CURRENT_SOURCE_DIR})

option(BUILD_EXECUTABLE "build the winpty executable" ON)
option(BUILD_STATIC "build the static library" ON)
option(BUILD_SHARED "build the shared library" OFF)

#prepare process
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/${ADDITIONAL_LIB}/GenVersion.h")
  execute_process(COMMAND cmd /c "cd ${CMAKE_CURRENT_SOURCE_DIR}/src/shared && GetCommitHash.bat"
                  OUTPUT_VARIABLE WINPTY_COMMIT_HASH)
  execute_process(COMMAND cmd /c "cd ${CMAKE_CURRENT_SOURCE_DIR}/src/shared && UpdateGenVersion.bat ${WINPTY_COMMIT_HASH}"
                  OUTPUT_VARIABLE ADDITIONAL_LIB OUTPUT_STRIP_TRAILING_WHITESPACE)
endif()

SET (EXECUTABLE_OUTPUT_PATH ${CMAKE_BINARY_DIR}/bin)
SET (LIBRARY_OUTPUT_PATH ${CMAKE_BINARY_DIR}/lib)

#sources for winpty-agent
SET(agent_sources
  "src/agent/Agent.cc"
  "src/agent/AgentCreateDesktop.cc"
  "src/agent/ConsoleFont.cc"
  "src/agent/ConsoleInput.cc"
  "src/agent/ConsoleInputReencoding.cc"
  "src/agent/ConsoleLine.cc"
  "src/agent/DebugShowInput.cc"
  "src/agent/DefaultInputMap.cc"
  "src/agent/EventLoop.cc"
  "src/agent/InputMap.cc"
  "src/agent/LargeConsoleRead.cc"
  "src/agent/NamedPipe.cc"
  "src/agent/Scraper.cc"
  "src/agent/Terminal.cc"
  "src/agent/Win32Console.cc"
  "src/agent/Win32ConsoleBuffer.cc"
  "src/agent/main.cc"
  "src/shared/BackgroundDesktop.cc"
  "src/shared/Buffer.cc"
  "src/shared/DebugClient.cc"
  "src/shared/GenRandom.cc"
  "src/shared/OwnedHandle.cc"
  "src/shared/StringUtil.cc"
  "src/shared/WindowsSecurity.cc"
  "src/shared/WindowsVersion.cc"
  "src/shared/WinptyAssert.cc"
  "src/shared/WinptyException.cc"
  "src/shared/WinptyVersion.cc"
)

SET(agent_headers
  "src/agent/Agent.h"
  "src/agent/AgentCreateDesktop.h"
  "src/agent/ConsoleFont.h"
  "src/agent/ConsoleInput.h"
  "src/agent/ConsoleInputReencoding.h"
  "src/agent/ConsoleLine.h"
  "src/agent/Coord.h"
  "src/agent/DebugShowInput.h"
  "src/agent/DefaultInputMap.h"
  "src/agent/DsrSender.h"
  "src/agent/EventLoop.h"
  "src/agent/InputMap.h"
  "src/agent/LargeConsoleRead.h"
  "src/agent/NamedPipe.h"
  "src/agent/Scraper.h"
  "src/agent/SimplePool.h"
  "src/agent/SmallRect.h"
  "src/agent/Terminal.h"
  "src/agent/UnicodeEncoding.h"
  "src/agent/Win32Console.h"
  "src/agent/Win32ConsoleBuffer.h"
  "src/shared/AgentMsg.h"
  "src/shared/BackgroundDesktop.h"
  "src/shared/Buffer.h"
  "src/shared/DebugClient.h"
  "src/shared/GenRandom.h"
  "src/shared/OsModule.h"
  "src/shared/OwnedHandle.h"
  "src/shared/StringBuilder.h"
  "src/shared/StringUtil.h"
  "src/shared/UnixCtrlChars.h"
  "src/shared/WindowsSecurity.h"
  "src/shared/WindowsVersion.h"
  "src/shared/WinptyAssert.h"
  "src/shared/WinptyException.h"
  "src/shared/WinptyVersion.h"
  "src/shared/winpty_snprintf.h"
)

#sources for winpty library
SET(winpty_sources
  "src/libwinpty/AgentLocation.cc"
  "src/libwinpty/winpty.cc"
  "src/shared/BackgroundDesktop.cc"
  "src/shared/Buffer.cc"
  "src/shared/DebugClient.cc"
  "src/shared/GenRandom.cc"
  "src/shared/OwnedHandle.cc"
  "src/shared/StringUtil.cc"
  "src/shared/WindowsSecurity.cc"
  "src/shared/WindowsVersion.cc"
  "src/shared/WinptyAssert.cc"
  "src/shared/WinptyException.cc"
  "src/shared/WinptyVersion.cc"
)

SET(winpty_headers
  "src/include/winpty.h"
  "src/libwinpty/AgentLocation.h"
  "src/shared/AgentMsg.h"
  "src/shared/BackgroundDesktop.h"
  "src/shared/Buffer.h"
  "src/shared/DebugClient.h"
  "src/shared/GenRandom.h"
  "src/shared/OsModule.h"
  "src/shared/OwnedHandle.h"
  "src/shared/StringBuilder.h"
  "src/shared/StringUtil.h"
  "src/shared/WindowsSecurity.h"
  "src/shared/WindowsVersion.h"
  "src/shared/WinptyAssert.h"
  "src/shared/WinptyException.h"
  "src/shared/WinptyVersion.h"
  "src/shared/winpty_snprintf.h"
)

#sources for debugserver
SET(debugserver_sources
  "src/debugserver/DebugServer.cc"
  "src/shared/DebugClient.cc"
  "src/shared/OwnedHandle.cc"
  "src/shared/StringUtil.cc"
  "src/shared/WindowsSecurity.cc"
  "src/shared/WindowsVersion.cc"
  "src/shared/WinptyAssert.cc"
  "src/shared/WinptyException.cc"
)

SET(debugserver_headers
  "src/shared/DebugClient.h"
  "src/shared/OwnedHandle.h"
  "src/shared/OsModule.h"
  "src/shared/StringBuilder.h"
  "src/shared/StringUtil.h"
  "src/shared/WindowsSecurity.h"
  "src/shared/WindowsVersion.h"
  "src/shared/WinptyAssert.h"
  "src/shared/WinptyException.h"
  "src/shared/winpty_snprintf.h"
)

######################################################################################
include_directories(src/include)
include_directories(src/${ADDITIONAL_LIB})
add_definitions(
  -D_CRT_SECURE_NO_WARNINGS
  -DUNICODE
  -D_UNICODE
  -D_WIN32_WINNT=0x0600
  -DNOMINMAX
)

if(MSVC)
  add_definitions(-D_CRT_SECURE_NO_WARNINGS)
endif(MSVC)
if(MINGW)
  set(CMAKE_EXE_LINKER_FLAGS "-static-libgcc -static-libstdc++ -static -lpthread")
  set(CMAKE_SHARED_LINKER_FLAGS ${CMAKE_EXE_LINKER_FLAGS})
endif(MINGW)
######################################################################################

SET(TARGETS "winpty-agent" "winpty-debugserver" "winpty-shared" "winpty")

if(BUILD_SHARED)
  add_library(winpty-shared SHARED ${winpty_sources} ${winpty_headers})
  set_target_properties(winpty-shared PROPERTIES COMPILE_DEFINITIONS "COMPILING_WINPTY_DLL;")
  target_link_libraries(winpty-shared OUTPUT_NAME vterm "-ladvapi32" "-luser32")
  install(TARGETS winpty-shared RUNTIME DESTINATION bin
                                LIBRARY DESTINATION lib
                                ARCHIVE DESTINATION lib)
endif(BUILD_SHARED)

if(BUILD_STATIC)
  add_library(winpty STATIC ${winpty_sources} ${winpty_headers})
  set_target_properties(winpty PROPERTIES COMPILE_DEFINITIONS "COMPILING_WINPTY_DLL;")
  target_link_libraries(winpty "-ladvapi32" "-luser32")
  install(TARGETS winpty RUNTIME DESTINATION bin
                         LIBRARY DESTINATION lib
                         ARCHIVE DESTINATION lib)
endif(BUILD_STATIC)

if(BUILD_EXECUTABLE)
  add_executable(winpty-agent ${agent_sources} ${agent_headers})
  set_target_properties(winpty-agent PROPERTIES COMPILE_DEFINITIONS "WINPTY_AGENT_ASSERT;")
  target_link_libraries(winpty-agent "-ladvapi32" "-lshell32" "-luser32")
  install(TARGETS winpty-agent RUNTIME DESTINATION bin
                               LIBRARY DESTINATION lib
                               ARCHIVE DESTINATION lib)

  add_executable(winpty-debugserver ${debugserver_sources} ${debugserver_headers})
  set_target_properties(winpty-debugserver PROPERTIES COMPILE_DEFINITIONS "")
  target_link_libraries(winpty-debugserver "-ladvapi32")
  install(TARGETS winpty-debugserver RUNTIME DESTINATION bin
                                     LIBRARY DESTINATION lib
                                     ARCHIVE DESTINATION lib)
endif(BUILD_EXECUTABLE)

install(FILES src/include/winpty.h src/include/winpty_constants.h DESTINATION include)
