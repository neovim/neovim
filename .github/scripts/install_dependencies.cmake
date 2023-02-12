cmake_minimum_required(VERSION 3.10)

if(APPLE)
  execute_process(COMMAND brew update --quiet)
  execute_process(COMMAND brew install automake ninja)
  if(TEST_DEPS)
    execute_process(COMMAND brew install cpanminus)
  endif()
else()
  # Assuming ubuntu for now. May expand if required.
  set(PACKAGES
    autoconf
    automake
    build-essential
    curl
    gettext
    libtool-bin
    locales-all
    ninja-build
    pkg-config
    unzip)
  execute_process(COMMAND sudo apt-get update)
  execute_process(COMMAND sudo apt-get install -y ${PACKAGES})
  if(TEST_DEPS)
    execute_process(COMMAND sudo apt-get install -y cpanminus)
  endif()
endif()
