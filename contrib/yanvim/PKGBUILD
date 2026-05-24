# Maintainer: Rodericuss <minetalebr@gmail.com>
pkgname=yanvim-git
pkgver=0.12.2.r0.gDIRTY
pkgrel=1
pkgdesc="Neovim fork with built-in Helix-style selection-first editing paradigm"
arch=('x86_64' 'aarch64')
url="https://github.com/Rodericuss/Yet-another-neovim"
license=('Apache-2.0' 'Vim')
depends=(
  'libuv'
  'luajit'
  'libvterm>=0.3'
  'unibilium'
  'tree-sitter>=0.25.0'
  'utf8proc'
)
makedepends=(
  'git'
  'cmake'
  'ninja'
  'lua51-lpeg'
  'lua51-mpack'
)
optdepends=(
  'python-pynvim: python remote plugin support'
  'xclip: clipboard support on X11'
  'wl-clipboard: clipboard support on Wayland'
)
provides=('yanvim')
conflicts=('yanvim')
source=("${pkgname}::git+${url}.git#branch=stable")
sha256sums=('SKIP')

pkgver() {
  cd "${pkgname}"
  git describe --long --tags 2>/dev/null | sed 's/^v//;s/-/.r/;s/-/./g' \
    || printf "0.12.2.r%s.g%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

build() {
  cd "${pkgname}"
  cmake -B build \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX=/usr
  cmake --build build
}

package() {
  cd "${pkgname}"
  DESTDIR="${pkgdir}" cmake --install build
}
