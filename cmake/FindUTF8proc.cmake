find_path2(UTF8PROC_INCLUDE_DIR utf8proc.h)
find_library2(UTF8PROC_LIBRARY NAMES utf8proc utf8proc_static)
find_package_handle_standard_args(UTF8proc DEFAULT_MSG
  UTF8PROC_LIBRARY UTF8PROC_INCLUDE_DIR)
mark_as_advanced(UTF8PROC_LIBRARY UTF8PROC_INCLUDE_DIR)

add_library(utf8proc INTERFACE)
target_include_directories(utf8proc SYSTEM BEFORE INTERFACE ${UTF8PROC_INCLUDE_DIR})
target_link_libraries(utf8proc INTERFACE ${UTF8PROC_LIBRARY})

#TODO(dundargoc): this is a hack that should ideally be hardcoded into the utf8proc project via configure_command
target_compile_definitions(utf8proc INTERFACE "UTF8PROC_STATIC")
