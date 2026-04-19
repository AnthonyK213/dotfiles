local packer = require("nviq.appl.packer")

------------------------------------devicons------------------------------------

if _G.NVIQ.settings.tui.devicons then
  packer.add {
    src = "https://github.com/nvim-tree/nvim-web-devicons",
    data = {
      lazy = false
    }
  }
end

------------------------------------nightfox------------------------------------

if _G.NVIQ.settings.tui.scheme == "nightfox" then
  packer.add {
    src = "https://github.com/EdenEast/nightfox.nvim",
    data = {
      lazy = false,
      conf = function()
        require("nightfox").setup {
          options = {
            compile_path = vim.fs.joinpath(vim.fn.stdpath("data"), "nightfox"),
            compile_file_suffix = "_compiled",
            transparent = _G.NVIQ.settings.tui.transparent,
            dim_inactive = _G.NVIQ.settings.tui.auto_dim,
          },
        }

        local style_table = {
          night  = { theme = "dark", inverse = "day" },
          day    = { theme = "light", inverse = "night" },
          dawn   = { theme = "light", inverse = "dusk" },
          dusk   = { theme = "dark", inverse = "dawn" },
          nord   = { theme = "dark", inverse = "day" },
          tera   = { theme = "dark", inverse = "dawn" },
          carbon = { theme = "dark", inverse = "dawn" },
        }

        -- Memorize the previous style (which "fox").
        local prev_style = {}

        _G.NVIQ.handlers.set_theme = function(theme)
          local fox_loaded = true
          local colors_name, colors_info

          if vim.g.colors_name then
            colors_name = vim.g.colors_name:match("(.+)fox")
            colors_info = style_table[colors_name]
          else
            fox_loaded = false
          end

          if not colors_info or not fox_loaded then
            fox_loaded = false
            colors_name = _G.NVIQ.settings.tui.style
            colors_info = style_table[colors_name]
          end

          if not colors_info then return end

          if theme == colors_info.theme then
            if not fox_loaded then
              vim.cmd.colorscheme(colors_name .. "fox")
            end
          else
            local colors_inverse = prev_style[theme] or colors_info.inverse
            vim.cmd.colorscheme(colors_inverse .. "fox")
          end

          prev_style[colors_info.theme] = colors_name
        end

        require("nviq.appl.theme").set_theme(_G.NVIQ.settings.tui.theme)
      end
    }
  }
end

------------------------------------lualine-------------------------------------

packer.add {
  src = "https://github.com/nvim-lualine/lualine.nvim",
  data = {
    lazy = false,
    conf = function()
      require("lualine").setup {
        options = {
          theme                = "auto",
          section_separators   = "",
          component_separators = "",
          icons_enabled        = _G.NVIQ.settings.tui.devicons,
          globalstatus         = _G.NVIQ.settings.tui.global_status
        },
        sections = {
          lualine_a = {
            { "mode", fmt = function(str) return str:sub(1, 1) end }
          },
          lualine_b = { { "b:gitsigns_head", icon = "" }, },
          lualine_c = {
            { "filename", path = 3 },
            {
              "diff",
              source = function()
                local gitsigns = vim.b.gitsigns_status_dict
                if gitsigns then
                  return {
                    added    = gitsigns.added,
                    modified = gitsigns.changed,
                    removed  = gitsigns.removed
                  }
                end
              end
            }
          },
          lualine_x = {
            { "diagnostics", sources = { "nvim_diagnostic" } },
            "filetype"
          },
          lualine_y = { "encoding", "fileformat" },
          lualine_z = { "progress", "location" },
        },
        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { "filename" },
          lualine_x = { "location" },
          lualine_y = {},
          lualine_z = {},
        },
        extensions = {
          "aerial",
          "fugitive",
          "mason",
          "nvim-dap-ui",
          "oil",
          "overseer",
          "quickfix",
        }
      }
    end
  }
}

--------------------------------indent-blankline--------------------------------

packer.add {
  src = "https://github.com/lukas-reineke/indent-blankline.nvim",
  data = {
    lazy = false,
    conf = function()
      require("ibl").setup {
        enabled = true,
        debounce = 1000,
        indent = {
          char = "▏",
        },
        viewport_buffer = {
          min = 30,
          max = 500
        },
        scope = {
          enabled            = true,
          show_start         = false,
          show_end           = false,
          injected_languages = false,
          priority           = 500,
        },
        exclude = {
          filetypes = {
            "aerial", "markdown", "presenting_markdown",
            "vimwiki", "mason", "DiffviewFiles",
          },
          buftypes = {
            "help", "quickfix", "terminal", "nofile", "acwrite",
          },
        }
      }
    end
  }
}

-----------------------------------vim-matchup----------------------------------

packer.add {
  src = "https://github.com/andymass/vim-matchup",
  data = {
    lazy = false,
    init = function()
      vim.g.matchup_matchparen_offscreen = { method = "popup", border = "none" }
      vim.g.matchup_matchparen_deferred = 1
      vim.g.matchup_matchparen_deferred_show_delay = 100
      vim.g.matchup_matchparen_deferred_hide_delay = 700
    end
  }
}
