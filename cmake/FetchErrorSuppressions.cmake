# Download error supressions from github.com:neovim/doc

include(ExternalProject)

function(FetchErrorSuppressions)
  cmake_parse_arguments(_fetch
    ""
    "TARGET"
    "DOWNLOAD_DIR"
    ${ARGN}
  )

  if(NOT ${_DOWNLOAD_DIR})
    set(_DOWNLOAD_DIR ${PROJECT_BINARY_DIR}/errors)
  endif()

  ExternalProject_Add("${_fetch_TARGET}"
    GIT_REPOSITORY    https://github.com/neovim/doc.git
    GIT_TAG           gh-pages
    GIT_SHALLOW       true
    GIT_PROGRESS      true
    PREFIX            "${_fetch_TARGET}"
    BUILD_IN_SOURCE   true
    CONFIGURE_COMMAND ""
    BUILD_COMMAND     ""
    UPDATE_COMMAND    "" # slow operation; it's unlikely that these will be updated that often
    INSTALL_COMMAND   ${CMAKE_COMMAND} -E make_directory "${_fetch_DOWNLOAD_DIR}"
    COMMAND           ${CMAKE_COMMAND} -E copy_directory reports/clint "${_fetch_DOWNLOAD_DIR}"
  )
endfunction()
