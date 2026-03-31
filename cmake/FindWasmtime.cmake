find_path2(WASMTIME_INCLUDE_DIR wasmtime.h)
find_library2(WASMTIME_LIBRARY wasmtime)

if(WASMTIME_INCLUDE_DIR AND EXISTS "${WASMTIME_INCLUDE_DIR}/wasmtime.h")
  file(STRINGS ${WASMTIME_INCLUDE_DIR}/wasmtime.h WASMTIME_VERSION REGEX "#define WASMTIME_VERSION")
  string(REGEX MATCH "[0-9]+\.[0-9]\.[0-9]" WASMTIME_VERSION ${WASMTIME_VERSION})
endif()

find_package_handle_standard_args(Wasmtime
  REQUIRED_VARS WASMTIME_INCLUDE_DIR WASMTIME_LIBRARY
  VERSION_VAR WASMTIME_VERSION)

add_library(wasmtime INTERFACE)
target_include_directories(wasmtime SYSTEM BEFORE INTERFACE ${WASMTIME_INCLUDE_DIR})
target_link_libraries(wasmtime INTERFACE ${WASMTIME_LIBRARY})

if(MSVC)
  target_compile_options(wasmtime INTERFACE -DWASM_API_EXTERN= -DWASI_API_EXTERN=)
  target_link_libraries(wasmtime INTERFACE ws2_32 advapi32 userenv ntdll shell32 ole32 bcrypt)
endif()

mark_as_advanced(WASMTIME_INCLUDE_DIR WASMTIME_LIBRARY)
