```
${NVIM_VERSION}
```

## Install

### Windows

1. Extract **nvim-win64.zip**
2. Run `nvim-qt.exe`

### macOS

1. Download **nvim-macos.tar.gz**
2. Extract: `tar xzvf nvim-macos.tar.gz`
3. Run `./nvim-osx64/bin/nvim`

### Linux (x64)

1. Download **nvim.appimage**
2. Run `chmod u+x nvim.appimage && ./nvim.appimage`
   - If your system does not have FUSE you can [extract the appimage](https://github.com/AppImage/AppImageKit/wiki/FUSE#type-2-appimage):
     ```
     ./nvim.appimage --appimage-extract
     ./squashfs-root/usr/bin/nvim
     ```

### Other

- Install by [package manager](https://github.com/neovim/neovim/wiki/Installing-Neovim)

## SHA256 Checksums

```
${SHA_LINUX_64}
${SHA_APP_IMAGE}
${SHA_APP_IMAGE_ZSYNC}
${SHA_MACOS}
${SHA_WIN_64}
```
