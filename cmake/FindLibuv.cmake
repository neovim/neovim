find_path(LIBUV_INCLUDE_DIR uv.h)
find_library(LIBUV_LIBRARY NAMES uv_a uv)

set(LIBUV_LIBRARIES ${LIBUV_LIBRARY})

check_library_exists(dl dlopen "dlfcn.h" HAVE_LIBDL)
if(HAVE_LIBDL)
  list(APPEND LIBUV_LIBRARIES dl)
endif()

check_library_exists(kstat kstat_lookup "kstat.h" HAVE_LIBKSTAT)
if(HAVE_LIBKSTAT)
  list(APPEND LIBUV_LIBRARIES kstat)
endif()

check_library_exists(kvm kvm_open "kvm.h" HAVE_LIBKVM)
if(HAVE_LIBKVM AND NOT CMAKE_SYSTEM_NAME STREQUAL "OpenBSD")
  list(APPEND LIBUV_LIBRARIES kvm)
endif()

check_library_exists(nsl gethostbyname "nsl.h" HAVE_LIBNSL)
if(HAVE_LIBNSL)
  list(APPEND LIBUV_LIBRARIES nsl)
endif()

check_library_exists(perfstat perfstat_cpu "libperfstat.h" HAVE_LIBPERFSTAT)
if(HAVE_LIBPERFSTAT)
  list(APPEND LIBUV_LIBRARIES perfstat)
endif()

check_library_exists(rt clock_gettime "time.h" HAVE_LIBRT)
if(HAVE_LIBRT)
  list(APPEND LIBUV_LIBRARIES rt)
endif()

check_library_exists(sendfile sendfile "" HAVE_LIBSENDFILE)
if(HAVE_LIBSENDFILE)
  list(APPEND LIBUV_LIBRARIES sendfile)
endif()

if(WIN32)
  # check_library_exists() does not work for Win32 API calls in X86 due to name
  # mangling calling conventions
  list(APPEND LIBUV_LIBRARIES iphlpapi)
  list(APPEND LIBUV_LIBRARIES psapi)
  list(APPEND LIBUV_LIBRARIES userenv)
  list(APPEND LIBUV_LIBRARIES ws2_32)
endif()

find_package(Threads)
if(Threads_FOUND)
  # TODO: Fix the cmake file to properly handle static deps for bundled builds.
  # Meanwhile just include the threads library if CMake tells us there's one to
  # use.
  list(APPEND LIBUV_LIBRARIES ${CMAKE_THREAD_LIBS_INIT})
endif()

find_package_handle_standard_args(Libuv DEFAULT_MSG
                                  LIBUV_LIBRARY LIBUV_INCLUDE_DIR)

mark_as_advanced(LIBUV_INCLUDE_DIR LIBUV_LIBRARY)
