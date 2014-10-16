require "formula"

class Neovim < Formula
  homepage "http://neovim.org"
  head "https://github.com/neovim/neovim.git"

  depends_on "cmake" => :build
  depends_on "libtool" => :build
  depends_on "automake" => :build
  depends_on "autoconf" => :build

  def install
    ENV["GIT_DIR"] = cached_download/".git" if build.head?
    ENV.deparallelize
    system "make", "CMAKE_EXTRA_FLAGS=\"-DCMAKE_INSTALL_PREFIX:PATH=#{prefix}\"", "install"
  end
end
