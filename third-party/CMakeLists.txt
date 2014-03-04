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
    DOWNLOAD_NAME "libuv.tar.gz"
    URL "https://github.com/joyent/libuv/archive/v0.11.21.tar.gz"
    URL_HASH "SHA512=511bec3d69f22c506034705cc97936abda7bfa847ecd367a5063edec917b52c65712249c2a9eccf5ebbbb4b0c1e9c0139c451b27f9b69c2a8c45436e77e3f250"
    BUILD_IN_SOURCE 1
    CONFIGURE_COMMAND "./autogen.sh" "&&" "./configure" "--prefix=${LibUV_INSTALL_DIR}" "--with-pic"
    BUILD_COMMAND "make" "&&" "make" "install"
  )
else ()
  find_package (LibUV REQUIRED)
  set (LibUV_INCLUDE_DIRS ${LibUV_INCLUDE_DIRS} PARENT_SCOPE)
  set (LibUV_LIBRARIES ${LibUV_LIBRARIES} PARENT_SCOPE)
endif ()

