require "formula"

class Neovim < Formula
  homepage "http://neovim.org"
  head "https://github.com/neovim/neovim.git"

  depends_on "cmake" => :build
  depends_on "libtool" => :build
  depends_on "automake" => :build
  depends_on "autoconf" => :build

  def install
    ENV.deparallelize
    system "make", "deps"
    system "cmake", "-DCMAKE_BUILD_TYPE=Debug", "-DCMAKE_PREFIX_PATH=.deps/usr", "-DLibUV_USE_STATIC=YES", "-DCMAKE_INSTALL_PREFIX:PATH=#{prefix}"
    system "make", "install"
  end
end
