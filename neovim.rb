require 'formula'

class Neovim < Formula
  homepage 'http://neovim.org'
  head 'https://github.com/neovim/neovim.git'

  depends_on 'cmake'
  depends_on 'libtool'
  depends_on 'automake'
  depends_on 'libuv'

  def install
    ENV.deparallelize
    system "make", "PREFIX=#{prefix}", "cmake"
    system "make", "PREFIX=#{prefix}"
    system "make", "PREFIX=#{prefix}", "install"
  end
end
