local packer = require("nviq.appl.packer")

-------------------------------------crates-------------------------------------

packer.add {
  src = "https://github.com/saecki/crates.nvim",
  version = "stable",
  data = {
    lazy = true,
    conf = function()
      local crates = require("crates")
      local option = {
        popup = {
          border = _G.NVIQ.settings.tui.border,
        },
        lsp = {
          enabled = true,
          on_attach = function(_, bufnr)
            ---@type vim.keymap.set.Opts
            local opts = { buf = bufnr, silent = true }
            vim.keymap.set("n", "K", crates.show_popup, opts)
            vim.keymap.set("n", "<leader>cu", crates.update_crate, opts)
            vim.keymap.set("v", "<leader>cu", crates.update_crates, opts)
            vim.keymap.set("n", "<leader>ca", crates.update_all_crates, opts)
            vim.keymap.set("n", "<leader>cU", crates.upgrade_crate, opts)
            vim.keymap.set("v", "<leader>cU", crates.upgrade_crates, opts)
            vim.keymap.set("n", "<leader>cA", crates.upgrade_all_crates, opts)
          end,
          actions = true,
          completion = true,
          hover = true,
        }
      }

      if not _G.NVIQ.settings.tui.devicons then
        option.text = {
          loading    = "  Loading...",
          version    = "  %s",
          prerelease = "  %s",
          yanked     = "  %s yanked",
          nomatch    = "  Not found",
          upgrade    = "  %s",
          error      = "  Error fetching crate",
        }
        option.popup.text = {
          title                     = "# %s",
          pill_left                 = "",
          pill_right                = "",
          created_label             = "created        ",
          updated_label             = "updated        ",
          downloads_label           = "downloads      ",
          homepage_label            = "homepage       ",
          repository_label          = "repository     ",
          documentation_label       = "documentation  ",
          crates_io_label           = "crates.io      ",
          lib_rs_label              = "lib.rs         ",
          categories_label          = "categories     ",
          keywords_label            = "keywords       ",
          version                   = "%s",
          prerelease                = "%s pre-release",
          yanked                    = "%s yanked",
          enabled                   = "* s",
          transitive                = "~ s",
          normal_dependencies_title = "  Dependencies",
          build_dependencies_title  = "  Build dependencies",
          dev_dependencies_title    = "  Dev dependencies",
          optional                  = "? %s",
          loading                   = " ...",
        }
        option.completion = {
          text = {
            prerelease = " pre-release ",
            yanked     = " yanked ",
          }
        }
      end

      crates.setup(option)
    end,
    ft = "toml"
  }
}

-----------------------------------cmake-tools----------------------------------

packer.add {
  src = "https://github.com/Civitasv/cmake-tools.nvim",
  data = {
    lazy = true,
    deps = {
      "https://github.com/nvim-lua/plenary.nvim",
      "https://github.com/mfussenegger/nvim-dap",
    },
    conf = function()
      require("cmake-tools").setup {
        cmake_regenerate_on_save = false,
        cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" },
        cmake_build_directory = "build",
        cmake_compile_commands_options = {
          action = "none",
          target = vim.uv.cwd()
        },
        cmake_dap_configuration = {
          name = "cpp",
          type = "codelldb",
          request = "launch",
          stopOnEntry = false,
          runInTerminal = true,
          console = "integratedTerminal",
        },
        cmake_executor = {
          name = "quickfix",
          default_opts = {
            quickfix = {
              auto_close_when_success = false,
            },
          },
        },
        cmake_runner = {
          name = "terminal",
        },
      }
    end,
    cmd = {
      "CMakeGenerate", "CMakeBuild", "CMakeRun", "CMakeDebug", "CMakeRunTest",
      "CMakeInstall", "CMakeClean"
    }
  }
}
