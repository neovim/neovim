#!/bin/bash

ARCH=native

while (($# > 0)); do
  case $1 in
  --test) # install test dependencies
    TEST=1
    shift
    ;;
  --arch)
    shift
    ARCH="$1"
    shift
    ;;
  esac
done

os=$(uname -s)
if [[ $os == Linux ]]; then
  sudo dpkg --add-architecture "$ARCH"
  sudo apt-get update
  for i in "build-essential:$ARCH" cmake curl gettext ninja-build; do
    sudo apt-get install -y "$i"
  done

  if [[ $CC == clang ]]; then
    DEFAULT_CLANG_VERSION=$(echo |  clang -dM -E - | grep __clang_major | awk '{print $3}')
    CLANG_VERSION=17
    if ((DEFAULT_CLANG_VERSION >= CLANG_VERSION)); then
      echo "Default clang version is $DEFAULT_CLANG_VERSION, which equal or larger than wanted version $CLANG_VERSION. Aborting!"
      exit 1
    fi

    wget https://apt.llvm.org/llvm.sh
    chmod +x llvm.sh
    sudo ./llvm.sh $CLANG_VERSION
    sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-$CLANG_VERSION 100
    sudo update-alternatives --set clang /usr/bin/clang-$CLANG_VERSION
  fi

  if [[ -n $TEST ]]; then
    for i in locales-all cpanminus attr libattr1-dev:"$ARCH" gdb; do
      sudo apt-get install -y "$i"
    done
  fi
elif [[ $os == Darwin ]]; then
  brew update --quiet
  brew install ninja
  if [[ -n $TEST ]]; then
    brew install cpanminus
  fi
fi
