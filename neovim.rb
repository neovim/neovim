require 'formula'

class Neovim < Formula
  homepage 'http://neovim.org'
  head 'https://github.com/neovim/neovim.git'

  depends_on 'md5sha1sum'
  depends_on 'cmake'
  depends_on 'libtool'
  depends_on 'automake'

  def install
    ENV.deparallelize
    system "make", "deps"
    system "cmake", "-DCMAKE_BUILD_TYPE=Debug", "-DCMAKE_PREFIX_PATH=.deps/usr", "-DLibUV_USE_STATIC=YES", "-DCMAKE_INSTALL_PREFIX:PATH=#{prefix}"
    system "make", "install"
  end
end
