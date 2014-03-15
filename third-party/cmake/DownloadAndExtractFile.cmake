if(NOT DEFINED PREFIX)
  message(FATAL_ERROR "PREFIX must be defined.")
endif()

if(NOT DEFINED URL)
  message(FATAL_ERROR "URL must be defined.")
endif()

if(NOT DEFINED DOWNLOAD_DIR)
  message(FATAL_ERROR "DOWNLOAD_DIR must be defined.")
endif()

if(NOT DEFINED EXPECTED_MD5)
  message(FATAL_ERROR "EXPECTED_MD5 must be defined.")
endif()

if(NOT DEFINED TARGET)
  message(FATAL_ERROR "TARGET must be defined.")
endif()

# Taken from ExternalProject_Add.  Let's hope we can drop this one day when
# ExternalProject_Add allows you to disable SHOW_PROGRESS on the file download.
if(TIMEOUT)
  set(timeout_args TIMEOUT ${timeout})
  set(timeout_msg "${timeout} seconds")
else()
  set(timeout_args "# no TIMEOUT")
  set(timeout_msg "none")
endif()

string(REGEX MATCH "[^/\\?]*$" fname "${URL}")
if(NOT "${fname}" MATCHES "(\\.|=)(bz2|tar|tgz|tar\\.gz|zip)$")
  string(REGEX MATCH "([^/\\?]+(\\.|=)(bz2|tar|tgz|tar\\.gz|zip))/.*$" match_result "${URL}")
  set(fname "${CMAKE_MATCH_1}")
endif()
if(NOT "${fname}" MATCHES "(\\.|=)(bz2|tar|tgz|tar\\.gz|zip)$")
  message(FATAL_ERROR "Could not extract tarball filename from url:\n  ${url}")
endif()
string(REPLACE ";" "-" fname "${fname}")

set(file ${DOWNLOAD_DIR}/${fname})
message(STATUS "file: ${file}")

message(STATUS "downloading...
     src='${URL}'
     dst='${file}'
     timeout='${timeout_msg}'")

file(DOWNLOAD ${URL} ${file}
  ${timeout_args}
  EXPECTED_MD5 ${EXPECTED_MD5}
  STATUS status
  LOG log)

list(GET status 0 status_code)
list(GET status 1 status_string)

if(NOT status_code EQUAL 0)
  message(FATAL_ERROR "error: downloading '${URL}' failed
  status_code: ${status_code}
  status_string: ${status_string}
  log: ${log}
")
endif()

message(STATUS "downloading... done")

set(SRC_DIR ${PREFIX}/src/${TARGET})

# Slurped from a generated extract-TARGET.cmake file.
message(STATUS "extracting...
     src='${file}'
     dst='${SRC_DIR}'")

if(NOT EXISTS "${file}")
  message(FATAL_ERROR "error: file to extract does not exist: '${file}'")
endif()

# Prepare a space for extracting:
#
set(i 1234)
while(EXISTS "${SRC_DIR}/../ex-${TARGET}${i}")
  math(EXPR i "${i} + 1")
endwhile()
set(ut_dir "${SRC_DIR}/../ex-${TARGET}${i}")
file(MAKE_DIRECTORY "${ut_dir}")

# Extract it:
#
message(STATUS "extracting... [tar xfz]")
execute_process(COMMAND ${CMAKE_COMMAND} -E tar xfz ${file}
  WORKING_DIRECTORY ${ut_dir}
  RESULT_VARIABLE rv)

if(NOT rv EQUAL 0)
  message(STATUS "extracting... [error clean up]")
  file(REMOVE_RECURSE "${ut_dir}")
  message(FATAL_ERROR "error: extract of '${file}' failed")
endif()

# Analyze what came out of the tar file:
#
message(STATUS "extracting... [analysis]")
file(GLOB contents "${ut_dir}/*")
list(LENGTH contents n)
if(NOT n EQUAL 1 OR NOT IS_DIRECTORY "${contents}")
  set(contents "${ut_dir}")
endif()

# Move "the one" directory to the final directory:
#
message(STATUS "extracting... [rename]")
file(REMOVE_RECURSE ${SRC_DIR})
get_filename_component(contents ${contents} ABSOLUTE)
file(RENAME ${contents} ${SRC_DIR})

# Clean up:
#
message(STATUS "extracting... [clean up]")
file(REMOVE_RECURSE "${ut_dir}")

message(STATUS "extracting... done")

