{
  "dep": {
    "sh": "zsh",
    "cc": "gcc",
    "py3": "/usr/bin/python3"
  },
  "tui": {
    "scheme": "nightfox",
    "style": "nord",
    "transparent": false,
    "global_statusline": true,
    "border": "rounded",
    "cmp_ghost": true,
    "auto_dim": false,
    "devicons": true,
    "animation": true,
    "show_context": true
  },
  "gui": {
    "font_half": "UbuntuMono Nerd Font Mono",
    "font_wide": "simhei",
    "font_size": 24,
    "cursor_blink": true
  },
  "lsp": {
    "clangd": true,
    "pyright": {
      "load": true,
      "settings": {
        "python": {
          "analysis": {
            "autoSearchPaths": true,
            "diagnosticMode": "workspace",
            "useLibraryCodeForTypes": true,
            "stubPath": "/path/to/stubs",
            "typeCheckingMode": "off"
          }
        }
      }
    },
    "omnisharp": {
      "load": true,
      "disable_semantic_tokens": true
    },
    "rust_analyzer": {
      "load": true,
      "disable_semantic_tokens": false
    },
    "lua_ls": {
      "load": true,
      "settings": {
        "Lua": {
          "runtime": {
            "version": "LuaJIT"
          },
          "diagnostics": {
            "globals": [
              "vim"
            ]
          },
          "workspace": {
            "library": "${vim.api.nvim_get_runtime_file('', true)}",
            "checkThirdParty": false
          },
          "telemetry": {
            "enable": false
          }
        }
      }
    },
    "vimls": true,
    "jsonls": false,
    "cmake": true
  },
  "ts": {
    "ensure_installed": [
      "bash",
      "c",
      "c_sharp",
      "comment",
      "cpp",
      "css",
      "glsl",
      "hlsl",
      "javascript",
      "json",
      "regex",
      "rust",
      "toml",
      "typescript",
      "vue",
      "html",
      "lua",
      "python"
    ]
  },
  "use_coc": true
}
