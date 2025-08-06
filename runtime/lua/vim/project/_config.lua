local config = {
  autochdir = false, -- Automatically change the working directory to the project root
  lsp_root_detect = true, -- Detect LSP root directories
  root_markers = { -- Filetype-specific root markers
    global = { ".nvim", ".git", ".hv", ".svn" }, -- Global root markers for all filetypes
    c = { "CMakeLists.txt", "Makefile", "meson.build"  },
    cpp = { "CMakeLists.txt", "Makefile", "meson.build" },
    deno = { "deno.json" },
    flutter = { "pubspec.yaml" },
    go = { "go.mod" },
    haskell = { "stack.yaml", "cabal.project" },
    java = { "pom.xml", "build.gradle" },
    javascript = { "package.json" },
    kotlin = { "build.gradle.kts", "settings.gradle.kts" },
    php = { "composer.json" },
    python = { "pyproject.toml", "setup.py", "requirements.txt" },
    ruby = { "Gemfile" },
    rust = { "Cargo.toml" },
    typescript = { "package.json" },
  }
}

return config
