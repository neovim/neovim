# Fuzz testing targets for neovim.
#
# Build with:
#   cmake -B build -DENABLE_FUZZING=ON \
#         -DCMAKE_C_COMPILER=clang \
#         -DFUZZ_ENGINE="-fsanitize=fuzzer" \
#         -DCMAKE_C_FLAGS="-fsanitize=address,fuzzer-no-link -g -O1"
#   cmake --build build --target fuzz_vterm fuzz_base64 fuzz_mpack
#
# For OSS-Fuzz / ClusterFuzz the engine is provided via $LIB_FUZZING_ENGINE.

# ---------------------------------------------------------------------------
# fuzz_vterm  --  terminal escape sequence parser
# ---------------------------------------------------------------------------
add_executable(fuzz_vterm EXCLUDE_FROM_ALL fuzz_vterm.c)
target_link_libraries(fuzz_vterm PRIVATE libnvim ${FUZZ_ENGINE})
target_include_directories(fuzz_vterm PRIVATE
  ${PROJECT_SOURCE_DIR}/src)
set_target_properties(fuzz_vterm PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
  LINK_FLAGS "-Wl,--allow-multiple-definition")

# ---------------------------------------------------------------------------
# fuzz_base64  --  base64 encode / decode round-trip
# ---------------------------------------------------------------------------
add_executable(fuzz_base64 EXCLUDE_FROM_ALL fuzz_base64.c)
target_link_libraries(fuzz_base64 PRIVATE libnvim ${FUZZ_ENGINE})
target_include_directories(fuzz_base64 PRIVATE
  ${PROJECT_SOURCE_DIR}/src)
set_target_properties(fuzz_base64 PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
  LINK_FLAGS "-Wl,--allow-multiple-definition")

# ---------------------------------------------------------------------------
# fuzz_mpack  --  msgpack tokenizer (standalone, no libnvim dependency)
# ---------------------------------------------------------------------------
add_executable(fuzz_mpack EXCLUDE_FROM_ALL
  fuzz_mpack.c
  ${PROJECT_SOURCE_DIR}/src/mpack/mpack_core.c)
target_link_libraries(fuzz_mpack PRIVATE ${FUZZ_ENGINE})
target_include_directories(fuzz_mpack PRIVATE
  ${PROJECT_SOURCE_DIR}/src/mpack)
set_target_properties(fuzz_mpack PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

# Convenience target to build all fuzz targets at once.
add_custom_target(fuzz DEPENDS fuzz_vterm fuzz_base64 fuzz_mpack)
