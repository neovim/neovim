```
${NVIM_VERSION}
```

## Install

### Windows

#### Zip

1. Download **nvim-win64.zip**
2. Extract the zip
3. Run `nvim.exe` on your CLI of choice

#### MSI

1. Download **nvim-win64.msi**
2. Run the MSI
3. Run `nvim.exe` on your CLI of choice

Note: On Windows "Server" you may need to [install vcruntime140.dll](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170).

### macOS (x86_64)

1. Download **nvim-macos-x86_64.tar.gz**
2. Run `xattr -c ./nvim-macos-x86_64.tar.gz` (to avoid "unknown developer" warning)
3. Extract: `tar xzvf nvim-macos-x86_64.tar.gz`
4. Run `./nvim-macos-x86_64/bin/nvim`

### macOS (arm64)

1. Download **nvim-macos-arm64.tar.gz**
2. Run `xattr -c ./nvim-macos-arm64.tar.gz` (to avoid "unknown developer" warning)
3. Extract: `tar xzvf nvim-macos-arm64.tar.gz`
4. Run `./nvim-macos-arm64/bin/nvim`

### Linux (x64)

glibc 2.31 or newer is required. Or you may try the (unsupported) [builds for older glibc](https://github.com/neovim/neovim-releases).

#### AppImage

1. Download **nvim.appimage**
2. Run `chmod u+x nvim.appimage && ./nvim.appimage`
   - If your system does not have FUSE you can [extract the appimage](https://github.com/AppImage/AppImageKit/wiki/FUSE#type-2-appimage):
     ```
     ./nvim.appimage --appimage-extract
     ./squashfs-root/usr/bin/nvim
     ```

#### Tarball

1. Download **nvim-linux64.tar.gz**
2. Extract: `tar xzvf nvim-linux64.tar.gz`
3. Run `./nvim-linux64/bin/nvim`

### Other

- Install by [package manager](https://github.com/neovim/neovim/blob/master/INSTALL.md#install-from-package)

## SHA256 Checksums

```
${SHA_LINUX_64_TAR}
${SHA_APP_IMAGE}
${SHA_APP_IMAGE_ZSYNC}
${SHA_MACOS_X86_64}
${SHA_MACOS_ARM64}
${SHA_WIN_64_ZIP}
${SHA_WIN_64_MSI}
```
