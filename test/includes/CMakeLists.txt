# Generate FFI headers for unit tests. Header files will be placed
# in <builddir>/ffi-headers/. The path structure under relative_to
# is preserved.
macro(GenerateFFIHeaders glob_expr relative_to)
  file(GLOB_RECURSE ffi_headers
    RELATIVE ${relative_to}
    ${glob_expr})
  foreach(hdr ${ffi_headers})
    # Ignore os defs and tui
    if(${hdr} MATCHES "^src/nvim/os/(unix|win)_defs.h$")
      list(REMOVE_ITEM ffi_headers ${hdr})
    endif()
    if(${hdr} MATCHES "^src/nvim/tui/.*.h$")
      list(REMOVE_ITEM ffi_headers ${hdr})
    endif()
  endforeach()

  foreach(hdr ${ffi_headers})
    set(out_file ${CMAKE_CURRENT_BINARY_DIR}/ffi-headers/${hdr}.i)
    get_filename_component(out_path ${out_file} PATH)
    add_custom_command(
      OUTPUT ${out_file}
      COMMAND ${CMAKE_COMMAND} -E make_directory ${out_path}
      COMMAND ${CMAKE_C_COMPILER} -std=c99 -E -P
        ${relative_to}/${hdr}
        -I${PROJECT_SOURCE_DIR}/src
        -I${PROJECT_BINARY_DIR}/include
        -I${LIBUV_INCLUDE_DIRS}
        -Daligned\(ARGS\)=
        -D__attribute__\(ARGS\)=
        -D__asm\(ARGS\)=
        -D__asm__\(...\)=
        -D__inline__=
        -DEXTERN=extern
        -DINIT\(...\)=
        -D_GNU_SOURCE
        -DINCLUDE_GENERATED_DECLARATIONS
        # Needed for FreeBSD
        -D_Thread_local=
        -o ${out_file}
	VERBATIM)
    list(APPEND FFI_HEADERS ${out_file})
  endforeach()
endmacro()

GenerateFFIHeaders(${CMAKE_SOURCE_DIR}/src/nvim/*.h ${CMAKE_SOURCE_DIR})
GenerateFFIHeaders(${CMAKE_SOURCE_DIR}/test/unit/fixtures/*.h ${CMAKE_SOURCE_DIR})
GenerateFFIHeaders(${CMAKE_CURRENT_SOURCE_DIR}/pre/*.h ${CMAKE_CURRENT_SOURCE_DIR}/pre)

add_custom_target(unittest-headers DEPENDS ${FFI_HEADERS})
