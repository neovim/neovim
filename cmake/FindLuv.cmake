find_path2(LUV_INCLUDE_DIR luv/luv.h PATH_SUFFIXES lua5.1)
find_library2(LUV_LIBRARY NAMES luv_a luv PATH_SUFFIXES lua/5.1)

find_package_handle_standard_args(Luv DEFAULT_MSG
  LUV_LIBRARY LUV_INCLUDE_DIR)
mark_as_advanced(LUV_INCLUDE_DIR LUV_LIBRARY)
