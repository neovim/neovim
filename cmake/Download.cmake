file(
  DOWNLOAD "${URL}" "${FILE}"
  STATUS status
  LOG log
)

list(GET status 0 status_code)
list(GET status 1 status_string)

if(NOT status_code EQUAL 0)
  if(NOT ALLOW_FAILURE)
      message(FATAL_ERROR "error: downloading '${URL}' failed
        status_code: ${status_code}
        status_string: ${status_string}
        log: ${log}
      ")
  endif()
endif()
