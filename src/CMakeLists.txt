file( GLOB NEOVIM_SOURCES *.c )

foreach(sfile ${NEOVIM_SOURCES})
  get_filename_component(f ${sfile} NAME)
  if(${f} MATCHES "^(regexp_nfa.c|farsi.c|arabic.c)$")
    list(APPEND to_remove ${sfile})
  endif()
endforeach()

list(REMOVE_ITEM NEOVIM_SOURCES ${to_remove})
list(APPEND NEOVIM_SOURCES "${PROJECT_BINARY_DIR}/config/auto/pathdef.c")

file( GLOB IO_SOURCES io/*.c )

add_executable (vim ${NEOVIM_SOURCES} ${IO_SOURCES}) 

target_link_libraries (vim m termcap selinux) 
include_directories ("${PROJECT_SOURCE_DIR}/src/proto") 
