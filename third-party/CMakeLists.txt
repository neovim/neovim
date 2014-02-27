# libuv
option (USE_INCLUDED_LibUV "build and use internal static version of libuv" OFF)
if (USE_INCLUDED_LibUV)
  set (LibUV_SOURCE_DIR ${CMAKE_SOURCE_DIR}/third-party/libuv)
  set (LibUV_INSTALL_DIR ${CMAKE_SOURCE_DIR}/${CMAKE_PREFIX_PATH})
  set (LibUV_INCLUDE_DIRS ${LibUV_INSTALL_DIR}/include PARENT_SCOPE)
  if (LibUV_USE_STATIC MATCHES "YES")
    set (LibUV_LIBRARIES ${LibUV_INSTALL_DIR}/lib/libuv.a PARENT_SCOPE)
  else()
    set (LibUV_LIBRARIES ${LibUV_INSTALL_DIR}/lib/libuv.so PARENT_SCOPE)
  endif()
  externalproject_add (LibUV
    GIT_REPOSITORY "https://github.com/joyent/libuv.git"
    GIT_TAG "v0.11.21"
    BUILD_IN_SOURCE 1
    CONFIGURE_COMMAND "./autogen.sh" "&&" "./configure" "--prefix=${LibUV_INSTALL_DIR}"
    BUILD_COMMAND "make" "&&" "make" "install"
  )
else ()
  find_package (LibUV REQUIRED)
  set (LibUV_INCLUDE_DIRS ${LibUV_INCLUDE_DIRS} PARENT_SCOPE)
  set (LibUV_LIBRARIES ${LibUV_LIBRARIES} PARENT_SCOPE)
endif ()

