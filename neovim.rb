require "formula"

class Neovim < Formula
  homepage "http://neovim.org"
  head "https://github.com/neovim/neovim.git"

  depends_on "cmake" => :build
  depends_on "libtool" => :build
  depends_on "automake" => :build
  depends_on "autoconf" => :build

  resource "libuv" do
    url "https://github.com/joyent/libuv/archive/v0.11.28.tar.gz"
    sha1 "3b70b65467ee693228b8b8385665a52690d74092"
  end

  resource "msgpack" do
    url "https://github.com/msgpack/msgpack-c/archive/ecf4b09acd29746829b6a02939db91dfdec635b4.tar.gz"
    sha1 "c160ff99f20d9d0a25bea0a57f4452f1c9bde370"
  end

  resource "luajit" do
    url "http://luajit.org/download/LuaJIT-2.0.3.tar.gz"
    sha1 "2db39e7d1264918c2266b0436c313fbd12da4ceb"
  end

  resource "luarocks" do
    url "https://github.com/keplerproject/luarocks/archive/0587afbb5fe8ceb2f2eea16f486bd6183bf02f29.tar.gz"
    sha1 "61a894fd5d61987bf7e7f9c3e0c5de16ba4b68c4"
  end

  def install
    ENV["GIT_DIR"] = cached_download/".git" if build.head?
    ENV.deparallelize

    resources.each do |r|
      r.stage(target=buildpath/".deps/build/src/#{r.name}")
    end

    system "make", "CMAKE_BUILD_TYPE=RelWithDebInfo", "CMAKE_EXTRA_FLAGS=\"-DCMAKE_INSTALL_PREFIX:PATH=#{prefix}\"", "install"
  end
end
