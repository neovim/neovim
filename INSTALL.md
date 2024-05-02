You can install Neovim from [download](#install-from-download), [package](#install-from-package), or [source](#install-from-source) in just a few seconds.

---

- To start Neovim, run `nvim` (not `neovim`).
    - [Discover plugins](https://github.com/neovim/neovim/wiki/Related-projects#plugins).
- Before upgrading to a new version, **check [Breaking Changes](https://neovim.io/doc/user/news.html#news-breaking).**
- For config (vimrc) see [the FAQ](https://neovim.io/doc/user/faq.html#faq-general).

---

Install from download
=====================

Downloads are available on the [Releases](https://github.com/neovim/neovim/releases) page.

* Latest [stable release](https://github.com/neovim/neovim/releases/latest)
    * [macOS](https://github.com/neovim/neovim/releases/latest/download/nvim-macos.tar.gz)
    * [Linux](https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz)
    * [Windows](https://github.com/neovim/neovim/releases/latest/download/nvim-win64.msi)
* Latest [development prerelease](https://github.com/neovim/neovim/releases/nightly)


Install from package
====================

Packages are listed below. (You can also [build Neovim from source](#install-from-source).)

## Windows

Windows 8+ is required. Windows 7 or older is not supported.

### [Winget](https://docs.microsoft.com/en-us/windows/package-manager/winget/)

- **Release:** `winget install Neovim.Neovim`

### [Chocolatey](https://chocolatey.org)

- **Latest Release:** `choco install neovim` (use -y for automatically skipping confirmation messages)
- **Development (pre-release):** `choco install neovim --pre`

### [Scoop](https://scoop.sh/)
```
scoop bucket add main
scoop install neovim
```
- **Release:** `scoop install neovim`

Several Neovim GUIs are available from scoop (extras): [scoop.sh/#/apps?q=neovim](https://scoop.sh/#/apps?q=neovim)

### Pre-built archives

0. If you are missing `VCRUNTIME140.dll`, install the [Visual Studio 2015 C++ redistributable](https://support.microsoft.com/en-us/kb/2977003) (choose x86_64 or x86 depending on your system).
1. Choose a package (**nvim-winXX.zip**) from the [releases page](https://github.com/neovim/neovim/releases).
2. Unzip the package. Any location is fine, administrator privileges are _not_ required.
    - `$VIMRUNTIME` will be set to that location automatically.
3. Double-click `nvim-qt.exe`.

**Optional** steps:

- Add the `bin` folder (e.g. `C:\Program Files\nvim\bin`) to your PATH.
    - This makes it easy to run `nvim` and `nvim-qt` from anywhere.
- If `:set spell` does not work, create the `C:/Users/foo/AppData/Local/nvim/site/spell` folder.
  You can then copy your spell files over (for English, located
  [here](https://github.com/vim/vim/blob/master/runtime/spell/en.utf-8.spl) and
  [here](https://github.com/vim/vim/blob/master/runtime/spell/en.utf-8.sug));
- For Python plugins you need the `pynvim` module. "Virtual envs" are recommended. After activating the virtual env do `pip install pynvim` (in *both*). Edit your `init.vim` so that it contains the path to the env's Python executable:
    ```vim
    let g:python3_host_prog='C:/Users/foo/Envs/neovim3/Scripts/python.exe'
    ```
    - Run `:checkhealth` and read `:help provider-python`.
- **init.vim ("vimrc"):** If you already have Vim installed you can copy `%userprofile%\_vimrc` to `%userprofile%\AppData\Local\nvim\init.vim` to use your Vim config with Neovim.


## macOS / OS X

### Pre-built archives

The [Releases](https://github.com/neovim/neovim/releases) page provides pre-built binaries for macOS 10.15+.

For x86_64:

    curl -LO https://github.com/neovim/neovim/releases/download/nightly/nvim-macos-x86_64.tar.gz
    tar xzf nvim-macos-x86_64.tar.gz
    ./nvim-macos-x86_64/bin/nvim

For arm64:

    curl -LO https://github.com/neovim/neovim/releases/download/nightly/nvim-macos-arm64.tar.gz
    tar xzf nvim-macos-arm64.tar.gz
    ./nvim-macos-arm64/bin/nvim

### [Homebrew](https://brew.sh) on macOS or Linux

    brew install neovim

### [MacPorts](https://www.macports.org/)

    sudo port selfupdate
    sudo port install neovim

## Linux

### Pre-built archives

The [Releases](https://github.com/neovim/neovim/releases) page provides pre-built binaries for Linux systems.

```sh
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux64.tar.gz
sudo rm -rf /opt/nvim
sudo tar -C /opt -xzf nvim-linux64.tar.gz
```

After this step add this to `~/.bashrc`:

    export PATH="$PATH:/opt/nvim-linux64/bin"

### AppImage ("universal" Linux package)

The [Releases](https://github.com/neovim/neovim/releases) page provides an [AppImage](https://appimage.org) that runs on most Linux systems. No installation is needed, just download `nvim.appimage` and run it. (It might not work if your Linux distribution is more than 4 years old.)

    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
    chmod u+x nvim.appimage
    ./nvim.appimage

To expose nvim globally:

    mkdir -p /opt/nvim
    mv nvim.appimage /opt/nvim/nvim

And the following line to `~/.bashrc`:

    export PATH="$PATH:/opt/nvim/"

If the `./nvim.appimage` command fails, try:
```sh
./nvim.appimage --appimage-extract
./squashfs-root/AppRun --version

# Optional: exposing nvim globally.
sudo mv squashfs-root /
sudo ln -s /squashfs-root/AppRun /usr/bin/nvim
nvim
```

### Arch Linux

Neovim can be installed from the community repository:

    sudo pacman -S neovim

Alternatively, Neovim can be also installed using the PKGBUILD [`neovim-git`](https://aur.archlinux.org/packages/neovim-git), available on the [AUR](https://wiki.archlinux.org/index.php/Arch_User_Repository).

Alternatively, Neovim Nightly builds can be also installed using the PKGBUILD [`neovim-nightly-bin`](https://aur.archlinux.org/packages/neovim-nightly-bin), available on the [AUR](https://wiki.archlinux.org/index.php/Arch_User_Repository).

The Python module is available from the community repository:

    sudo pacman -S python-pynvim

Ruby modules (currently only supported in `neovim-git`) are available from the AUR as [`ruby-neovim`](https://aur.archlinux.org/packages/ruby-neovim).

### CentOS 8 / RHEL 8

Neovim is available through [EPEL (Extra Packages for Enterprise Linux)](https://fedoraproject.org/wiki/EPEL)

    yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
    yum install -y neovim python3-neovim

### Clear Linux OS

Neovim is available through the [neovim bundle](https://github.com/clearlinux/clr-bundles/blob/master/bundles/neovim)

    sudo swupd bundle-add neovim

Python (`:python`) support is available if the [python-basic bundle](https://github.com/clearlinux/clr-bundles/blob/master/bundles/python-basic) is installed.

    sudo swupd bundle-add python-basic

### Debian

Neovim is in [Debian](https://packages.debian.org/search?keywords=neovim).

    sudo apt-get install neovim

Python (`:python`) support is installable via the package manager on Debian unstable.

    sudo apt-get install python3-neovim

### Exherbo Linux

Exhereses for scm and released versions are currently available in repository `::medvid`. Python client (with GTK+ GUI included) and Qt5 GUI are also available as suggestions:

    cave resolve app-editors/neovim --take dev-python/neovim-python --take app-editors/neovim-qt

### Fedora

Neovim is in [Fedora](https://src.fedoraproject.org/rpms/neovim) starting with Fedora 25:

    sudo dnf install -y neovim python3-neovim

You can also get nightly builds of git master from the [Copr automated build system](https://copr.fedoraproject.org/coprs/agriffis/neovim-nightly/):

    dnf copr enable agriffis/neovim-nightly
    dnf install -y neovim python3-neovim

See the [blog post](https://arongriffis.com/2019/03/02/neovim-nightly-builds) for information on how these are built.

### Flatpak

You can find Neovim on [Flathub](https://flathub.org/apps/details/io.neovim.nvim). Providing you have Flatpak [set up](https://flatpak.org/setup/):

    flatpak install flathub io.neovim.nvim
    flatpak run io.neovim.nvim

You can add `/var/lib/flatpak/exports/bin` (or `~/.local/share/flatpak/exports/bin` if you used `--user`) to the `$PATH` and run it with `io.neovim.nvim`.

Note that Flatpak'ed Neovim will look for `init.vim` in `~/.var/app/io.neovim.nvim/config/nvim` instead of `~/.config/nvim`.

### Gentoo Linux

An ebuild is available in Gentoo's official portage repository:

    emerge -a app-editors/neovim

### GNU Guix

Neovim can be installed with:

    guix install neovim

### GoboLinux

Neovim can be installed with:

    sudo -H Compile NeoVim

### Nix / NixOS

Neovim can be installed with:

    nix-env -iA nixpkgs.neovim

Or alternatively, if you use flakes:

    nix profile install nixpkgs#neovim

### Mageia 7

    urpmi neovim

To install the Python modules:

    urpmi python3-pynvim

### makedeb Package Repository (MPR)

Neovim is available inside the [MPR](https://mpr.makedeb.org/packages/neovim). You can install it with:

    git clone https://mpr.makedeb.org/neovim
    cd neovim/
    makedeb -si

### OpenSUSE

Neovim can be installed with:

    sudo zypper in neovim

To install the Python modules:

    sudo zypper in python-neovim python3-neovim

### PLD Linux

Neovim is in [PLD Linux](https://github.com/pld-linux/neovim):

    poldek -u neovim
    poldek -u python-neovim python3-neovim
    poldek -u python-neovim-gui python3-neovim-gui

### Slackware

See [neovim on SlackBuilds](https://slackbuilds.org/apps/neovim/).

### Source Mage

Neovim can be installed using the Sorcery package manager:

    cast neovim

### Solus

Neovim can be installed using the default package manager in Solus (eopkg):

    sudo eopkg install neovim

### Snap

Neovim nightly and stable are available on the [snap store](https://snapcraft.io/nvim).

**Stable Builds**

```sh
sudo snap install --beta nvim --classic
```

**Nightly Builds**

```sh
sudo snap install --edge nvim --classic
```

### Ubuntu
As in Debian, Neovim is in [Ubuntu](https://packages.ubuntu.com/search?keywords=neovim).

    sudo apt install neovim

Python (`:python`) support seems to be automatically installed

    sudo apt install python3-neovim

Neovim has been added to a "Personal Package Archive" (PPA). This allows you to install it with `apt-get`. Follow the links to the PPAs to see which versions of Ubuntu are currently available via the PPA. Choose **stable** or **unstable**:

- [https://launchpad.net/~neovim-ppa/+archive/ubuntu/**stable**](https://launchpad.net/~neovim-ppa/+archive/ubuntu/stable)
- [https://launchpad.net/~neovim-ppa/+archive/ubuntu/**unstable**](https://launchpad.net/~neovim-ppa/+archive/ubuntu/unstable)

**Important:** The Neovim team does not maintain the PPA packages. For problems or questions about the PPA specifically contact https://launchpad.net/~neovim-ppa.

To be able to use **add-apt-repository** you may need to install software-properties-common:

    sudo apt-get install software-properties-common

If you're using an older version Ubuntu you must use:

    sudo apt-get install python-software-properties

Run the following commands:

    sudo add-apt-repository ppa:neovim-ppa/stable
    sudo apt-get update
    sudo apt-get install neovim

Prerequisites for the Python modules:

    sudo apt-get install python-dev python-pip python3-dev python3-pip

If you're using an older version Ubuntu you must use:

    sudo apt-get install python-dev python-pip python3-dev
    sudo apt-get install python3-setuptools
    sudo easy_install3 pip

### Void-Linux

Neovim can be installed using the xbps package manager

    sudo xbps-install -S neovim

### Alpine Linux

Neovim can be installed using the apk package manager

    sudo apk add neovim

## BSD

### FreeBSD

Neovim can be installed using [`pkg(8)`](https://www.freebsd.org/cgi/man.cgi?query=pkg&sektion=8&n=1):

    pkg install neovim

or [from the ports tree](https://www.freshports.org/editors/neovim/):

    cd /usr/ports/editors/neovim/ && make install clean

To install the pynvim Python modules using [`pkg(8)`](https://www.freebsd.org/cgi/man.cgi?query=pkg&sektion=8&n=1) run:

    pkg install py36-pynvim

### OpenBSD

Neovim can be installed using [`pkg_add(1)`](https://man.openbsd.org/pkg_add):

    pkg_add neovim

or [from the ports tree](https://cvsweb.openbsd.org/cgi-bin/cvsweb/ports/editors/neovim/):

    cd /usr/ports/editors/neovim/ && make install

## Android

[Termux](https://github.com/termux/termux-app) offers a Neovim package.


Install from source
===================

If a package is not provided for your platform, you can build Neovim from source. See [BUILD.md](./BUILD.md) for details.  If you have the [prerequisites](./BUILD.md#build-prerequisites) then building is easy:

    make CMAKE_BUILD_TYPE=Release
    sudo make install

For Unix-like systems this installs Neovim to `/usr/local`, while for Windows to `C:\Program Files`. Note, however, that this can complicate uninstallation. The following example avoids this by isolating an installation under `$HOME/neovim`:

    rm -r build/  # clear the CMake cache
    make CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$HOME/neovim"
    make install
    export PATH="$HOME/neovim/bin:$PATH"

## Uninstall

There is a CMake target to _uninstall_ after `make install`:

```sh
sudo cmake --build build/ --target uninstall
```

Alternatively, just delete the `CMAKE_INSTALL_PREFIX` artifacts:

```sh
sudo rm /usr/local/bin/nvim
sudo rm -r /usr/local/share/nvim/
```
