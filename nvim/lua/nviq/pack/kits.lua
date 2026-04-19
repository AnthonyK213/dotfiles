local packer = require("nviq.appl.packer")
local tui_border = _G.NVIQ.settings.tui.border

--------------------------------------mason-------------------------------------

packer.add {
  src = "https://github.com/mason-org/mason.nvim",
  data = {
    lazy = true,
    cmd = { "Mason" },
    conf = function()
      require("mason").setup { ui = { border = tui_border } }
    end
  }
}

-------------------------------------aerial-------------------------------------

packer.add {
  src = "https://github.com/stevearc/aerial.nvim",
  data = {
    lazy = false,
    conf = function()
      require("aerial").setup {
        backends = {
          ["_"]    = { "lsp", "treesitter" },
          markdown = { "markdown" },
        },
        close_automatic_events = {},
        close_on_select = false,
        manage_folds = false,
        filter_kind = require("nviq.appl.lsp").filter_symbols_kind(),
        nerd_font = false,
        highlight_closest = false,
        on_attach = function(bufnr)
          ---@type vim.keymap.set.Opts
          local opt = { buf = bufnr }
          vim.keymap.set("n", "{", require("aerial").prev, opt)
          vim.keymap.set("n", "}", require("aerial").next, opt)
          vim.keymap.set("n", "[[", require("aerial").prev_up, opt)
          vim.keymap.set("n", "]]", require("aerial").next_up, opt)
          vim.keymap.set("n", "<leader>mv", require("aerial").toggle, opt)
          vim.keymap.set("n", "<leader>fa", "<Cmd>Telescope aerial<CR>", opt)
        end,
        float = {
          border     = tui_border,
          relative   = "win",
          min_height = { 8, 0.1 },
          max_height = 0.9,
          height     = nil,
          override   = function(conf, _) return conf end,
        },
      }
    end
  }
}

--------------------------------------oil---------------------------------------

packer.add {
  src = "https://github.com/stevearc/oil.nvim",
  data = {
    lazy = true,
    conf = function()
      require("oil").setup {
        float = {
          border = tui_border,
        },
        confirmation = {
          border = tui_border,
        },
        progress = {
          border = tui_border,
        },
        ssh = {
          border = tui_border,
        },
        keymaps = {
          ["<C-y>"] = "actions.yank_entry",
          ["<M-y>"] = {
            mode = "n",
            callback = function()
              local oil = require("oil")
              local entry = oil.get_cursor_entry()
              if not entry or not entry.name then return end
              local cwd = oil.get_current_dir()
              if not cwd then return end
              local path = vim.fs.joinpath(cwd, entry.name)
              if entry.type == "directory" then
                path = path .. "/"
              end
              vim.fn.setreg("+", path)
              vim.notify("Yanked filepath to the system clipboard")
            end,
            desc = "Yank the filepath of the entry under the cursor to the system clipboard"
          },
          ["gx"] = {
            mode = "n",
            callback = function()
              local oil = require("oil")
              local entry = oil.get_cursor_entry()
              if not entry or not entry.name then return end
              local cwd = oil.get_current_dir()
              if not cwd then return end
              local path = vim.fs.joinpath(cwd, entry.name)
              require("nviq.util.lib").open(path)
            end
          },
        },
        keymaps_help = {
          border = tui_border,
        },
      }
    end,
    keymap = {
      { mode = "n", lhs = "<leader>op", rhs = function()
        local oil = require("oil")
        if vim.bo.filetype == "oil" then
          oil.close()
        else
          oil.open()
        end
      end, desc = "Toggle oil buffer" }
    }
  }
}

------------------------------------overseer------------------------------------

packer.add {
  src = "https://github.com/stevearc/overseer.nvim",
  data = {
    lazy = true,
    cmd = { "OverseerRun" },
    conf = function()
      require("overseer").setup { dap = false }
    end
  }
}

-----------------------------------telescope------------------------------------

packer.add {
  src = "https://github.com/nvim-telescope/telescope.nvim",
  data = {
    lazy = false, -- This is a basic UI component, no lazy loading.
    deps = {
      "https://github.com/nvim-lua/plenary.nvim",
      "https://github.com/nvim-telescope/telescope-ui-select.nvim",
      "https://github.com/debugloop/telescope-undo.nvim",
    },
    conf = function()
      local border_sources = {
        bold    = { "━", "┃", "━", "┃", "┏", "┓", "┛", "┗", "┣", "┫" },
        double  = { "═", "║", "═", "║", "╔", "╗", "╝", "╚", "╠", "╣" },
        rounded = { "─", "│", "─", "│", "╭", "╮", "╯", "╰", "├", "┤" },
        single  = { "─", "│", "─", "│", "┌", "┐", "┘", "└", "├", "┤" },
      }
      local border_source = border_sources[tui_border]

      ---
      ---@param source string[]
      ---@param recipe integer[]?
      ---@return string[]?
      local function border_chars(source, recipe)
        if not source then
          return
        end
        local chars = {}
        if recipe then
          for i = 1, 8 do
            chars[i] = source[recipe[i]]
          end
        else
          for i = 1, 8 do
            chars[i] = source[i]
          end
        end
        return chars
      end

      require("telescope").setup {
        defaults = {
          mappings = {
            i = {
              ["<C-Down>"] = require("telescope.actions").cycle_history_next,
              ["<C-Up>"] = require("telescope.actions").cycle_history_prev,
            },
          },
          border = border_source ~= nil,
          borderchars = border_chars(border_source),
        },
        extensions = {
          aerial = {},
          ["ui-select"] = {
            require("telescope.themes").get_dropdown {
              border = border_source ~= nil,
              borderchars = {
                prompt = border_chars(border_source),
                results = border_chars(border_source, { 1, 2, 3, 4, 9, 10, 7, 8 }),
              }
            }
          },
          undo = {},
        }
      }

      ---Find workspace symbols.
      local function find_workspace_symbols()
        require("telescope.builtin").lsp_dynamic_workspace_symbols {
          symbols = require("nviq.appl.lsp").filter_symbols_kind()
        }
      end

      require("nviq.appl.lsp").register_client_on_attach(function(_, bufnr)
        ---@type vim.keymap.set.Opts
        local opt = { buf = bufnr }
        local picker = require("telescope.builtin")

        vim.keymap.set("n", "<F12>", picker.lsp_definitions, opt)
        vim.keymap.set("n", "<S-F12>", picker.lsp_references, opt)
        vim.keymap.set("n", "<F24>", picker.lsp_references, opt)
        vim.keymap.set("n", "<C-F12>", picker.lsp_implementations, opt)
        vim.keymap.set("n", "<F36>", picker.lsp_implementations, opt)

        vim.keymap.set("n", "<leader>fs", find_workspace_symbols, opt)
      end)

      require("telescope").load_extension("aerial")
      require("telescope").load_extension("ui-select")
      require("telescope").load_extension("undo")
    end,
    keymap = {
      { mode = "n", lhs = "<leader>fb", rhs = function()
        require("telescope.builtin").buffers()
      end, desc = "Pick buffers" },
      { mode = "n", lhs = "<leader>ff", rhs = function()
        require("telescope.builtin").find_files()
      end, desc = "Find files" },
      { mode = "n", lhs = "<leader>fg", rhs = function()
        require("telescope.builtin").live_grep()
      end, desc = "Live grep" },
      { mode = "n", lhs = "<leader>fu", rhs = function()
        require("telescope").extensions.undo.undo()
      end, desc = "Undo tree" },
    }
  }
}

-----------------------------neovim-session-manager-----------------------------

packer.add {
  src = "https://github.com/stevearc/resession.nvim",
  data = {
    lazy = true,
    cmd = { "SessionSave", "SessionLoad", "SessionDelete" },
    conf = function()
      require("resession").setup()
      vim.api.nvim_create_user_command("SessionSave", function(tbl)
        local name = tbl.fargs[1] or vim.uv.cwd()
        require("resession").save(name)
      end, { nargs = "?" })
      vim.api.nvim_create_user_command("SessionLoad", function(_)
        require("resession").load()
      end, {})
      vim.api.nvim_create_user_command("SessionDelete", function(_)
        require("resession").delete()
      end, {})
    end,
  }
}
