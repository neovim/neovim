require 'formula'

class Neovim < Formula
  homepage 'http://neovim.org'
  head 'https://github.com/neovim/neovim.git'

  depends_on 'cmake'
  depends_on 'libtool'
  depends_on 'automake'
  depends_on 'libuv'

  def install
    system "make", "PREFIX=#{prefix}", "cmake"
    system "make", "PREFIX=#{prefix}"
  end
end
