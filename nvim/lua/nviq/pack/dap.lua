local packer = require("nviq.appl.packer")

---------------------------------------dap--------------------------------------

packer.add {
  src = "https://github.com/mfussenegger/nvim-dap",
  data = {
    lazy = true,
    deps = {
      "https://github.com/stevearc/overseer.nvim"
    },
    conf = function()
      local dap = require("dap")
      local has_win = jit.os == "Windows"
      local mason_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "mason")

      ---@class nviq.pack.dap.Adapter
      ---@field typename string
      ---@field filetype string|string[]
      ---@field option table
      ---@field configuration table
      local Adapter = {}

      Adapter.__index = Adapter

      ---Constructor.
      ---@param filetype string|string[]
      ---@param typename string
      ---@param option table
      ---@param configuration table[]
      ---@return nviq.pack.dap.Adapter
      function Adapter.new(filetype, typename, option, configuration)
        local adapter = {
          filetype = filetype,
          typename = typename,
          option = option,
          configuration = configuration,
        }
        setmetatable(adapter, Adapter)
        return adapter
      end

      ---Setup the adapter.
      function Adapter:setup()
        dap.adapters[self.typename] = self.option
        for _, config in ipairs(self.configuration) do
          config.type = self.typename
        end
        local filetype = self.filetype
        if type(filetype) == "string" then
          dap.configurations[filetype] = self.configuration
        elseif type(filetype) == "table" then
          for _, t in ipairs(filetype) do
            dap.configurations[t] = self.configuration
          end
        end
      end

      ---@type table<string, nviq.pack.dap.Adapter>
      local adapters = {}

      adapters.codelldb = Adapter.new({ "c", "cpp", "rust" }, "codelldb", {
        type = "executable",
        command = vim.fs.joinpath(mason_dir, "packages/codelldb/extension/adapter/codelldb"),
        name = "codelldb",
        detached = not has_win,
      }, {
        {
          name = "Launch",
          type = "codelldb",
          request = "launch",
          program = function()
            return vim.fn.input {
              prompt = "Path to executable: ",
              default = vim.uv.cwd() .. "/",
              completion = "file"
            }
          end,
          cwd = "${workspaceFolder}",
          stopOnEntry = false,
          args = {},
        }
      })

      local function get_netcoredbg_path()
        if has_win then
          return vim.fs.joinpath(mason_dir, "packages/netcoredbg/netcoredbg/netcoredbg")
        else
          return vim.fs.joinpath(mason_dir, "bin/netcoredbg")
        end
      end

      adapters.coreclr = Adapter.new("cs", "coreclr", {
        type = "executable",
        command = get_netcoredbg_path(),
        args = { "--interpreter=vscode" }
      }, {
        {
          name = "Launch",
          type = "coreclr",
          request = "launch",
          program = function()
            return vim.fn.input {
              prompt = "Path to dll: ",
              default = vim.uv.cwd() .. "/",
              completion = "file"
            }
          end,
        },
        {
          name = "Attach",
          type = "coreclr",
          request = "attach",
          processId = require("dap.utils").pick_process,
          args = {}
        }
      })

      local function get_python_path()
        local dir = has_win and "Scripts" or "bin"
        return vim.fs.joinpath(mason_dir, "packages/debugpy/venv", dir, "python")
      end

      adapters.python = Adapter.new("python", "python", {
        type = "executable",
        command = get_python_path(),
        args = { "-m", "debugpy.adapter" }
      }, {
        {
          type = "python",
          name = "Launch",
          request = "launch",
          program = "${file}",
          pythonPath = get_python_path,
        }
      })

      -- Setup adapters.
      if type(_G.NVIQ.settings.dap) == "table" then
        for type_, spec in pairs(_G.NVIQ.settings.dap) do
          if type(spec) == "table" and spec.enable then
            local adapter = adapters[type_]
            if adapter then
              adapter:setup()
            end
          end
        end
      end

      -- Enable overseer integration.
      require("overseer").enable_dap()

      -- dap-repl
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("nviq.pack.dap", { clear = true }),
        pattern = "dap-repl",
        callback = function(event)
          require("dap.ext.autocompl").attach()
          ---@type vim.keymap.set.Opts
          local opt = { buf = event.buf }
          vim.keymap.set("i", "<Tab>", "<C-N>", opt)
          vim.keymap.set("i", "<S-Tab>", "<C-P>", opt)
          vim.keymap.set({ "n", "i" }, "<M-d>", "<C-\\><C-N><Cmd>bd!<CR>", opt)
        end,
      })
    end
  }
}

---------------------------------mason-nvim-dap---------------------------------

packer.add {
  src = "https://github.com/jay-babu/mason-nvim-dap.nvim",
  data = {
    lazy = true,
    deps = {
      "https://github.com/mfussenegger/nvim-dap",
      "https://github.com/mason-org/mason.nvim",
    },
    conf = function()
      ---
      ---@return string[]
      local function adapters_to_install()
        if type(_G.NVIQ.settings.dap) ~= "table" then
          return {}
        end

        return vim.iter(_G.NVIQ.settings.dap)
            :filter(function(_, spec)
              -- TODO: `spec.install`
              return type(spec) == "table" and
                  spec.enable == true
            end)
            :map(function(name, _)
              return name
            end)
            :totable()
      end

      require("mason-nvim-dap").setup {
        ensure_installed = adapters_to_install(),
        automatic_installation = false,
      }
    end
  }
}

-------------------------------------dap-ui-------------------------------------

packer.add {
  src = "https://github.com/rcarriga/nvim-dap-ui",
  data = {
    lazy = true,
    deps = {
      "https://github.com/mfussenegger/nvim-dap",
      "https://github.com/jay-babu/mason-nvim-dap.nvim",
      "https://github.com/nvim-neotest/nvim-nio",
    },
    conf = function()
      local dap = require("dap")
      local dapui = require("dapui")

      local dap_opt = {}

      if not _G.NVIQ.settings.tui.devicons then
        dap_opt.controls = {
          icons = {
            disconnect = "Q",
            pause      = "||",
            play       = "|>",
            run_last   = "R",
            step_back  = "<=",
            step_into  = "->",
            step_out   = "<-",
            step_over  = "=>",
            terminate  = "X"
          }
        }
        dap_opt.icons = {
          collapsed     = ">",
          current_frame = ">",
          expanded      = "v"
        }
      end

      dapui.setup(dap_opt)

      dap.listeners.before.attach.dapui_config = function() dapui.open() end
      dap.listeners.before.launch.dapui_config = function() dapui.open() end
      dap.listeners.before.event_terminated.dapui_config = function() dapui.close() end
      dap.listeners.before.event_exited.dapui_config = function() dapui.close() end
    end,
    keymap = {
      { mode = "n", lhs = "<F5>",       rhs = function() require("dap").continue() end },
      { mode = "n", lhs = "<F10>",      rhs = function() require("dap").step_over() end },
      { mode = "n", lhs = "<F23>",      rhs = function() require("dap").step_into() end },
      { mode = "n", lhs = "<S-F11>",    rhs = function() require("dap").step_into() end },
      { mode = "n", lhs = "<F47>",      rhs = function() require("dap").step_out() end },
      { mode = "n", lhs = "<S-C-F11>",  rhs = function() require("dap").step_out() end },
      { mode = "n", lhs = "<leader>db", rhs = function() require("dap").toggle_breakpoint() end },
      { mode = "n", lhs = "<leader>dc", rhs = function() require("dap").clear_breakpoints() end },
      { mode = "n", lhs = "<leader>dl", rhs = function() require("dap").run_last() end },
      { mode = "n", lhs = "<leader>dr", rhs = function() require("dap").repl.toggle() end },
      { mode = "n", lhs = "<leader>dt", rhs = function() require("dap").terminate() end },
      { mode = "n", lhs = "<leader>dn", rhs = function() require("dapui").toggle() end },
      { mode = "n", lhs = "<leader>df", rhs = function() require("dapui").float_element() end },
      { mode = "x", lhs = "<leader>dv", rhs = function() require("dapui").eval() end },
    }
  }
}
