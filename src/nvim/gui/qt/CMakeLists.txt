# Nvim's built-in GUI (`nvim --gui`, ENABLE_GUI): its Qt side, a C++
# library of its own (Nvim's C flags are not for C++), talking to the
# editor through gui/bridge.h.

find_package(Qt6 REQUIRED COMPONENTS Widgets Svg)

add_library(nvim_gui_qt STATIC
  app.cpp
  camera.cpp
  canvas.cpp
  card_painter.cpp
  gridpaint.cpp
  keys.cpp
  messages.cpp
  messages_panel.cpp
  overlays.cpp
  picker_panel.cpp
  popups.cpp
  screen.cpp
  stage.cpp
  state.cpp
  status_bar.cpp
  theme.cpp
  tree_panel.cpp
  value.cpp
  window.cpp
  resources.qrc)
set_target_properties(nvim_gui_qt PROPERTIES
  AUTOMOC ON
  AUTORCC ON
  CXX_STANDARD 20
  CXX_STANDARD_REQUIRED ON
  POSITION_INDEPENDENT_CODE ON)
target_include_directories(nvim_gui_qt PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/../../..)
target_compile_options(nvim_gui_qt PRIVATE -Wall -Wextra -Wno-unused-parameter)
target_link_libraries(nvim_gui_qt PUBLIC Qt6::Widgets Qt6::Svg)
