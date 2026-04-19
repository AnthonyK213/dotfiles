local packer = require("nviq.appl.packer")

------------------------------------fugitive------------------------------------

packer.add {
  src = "https://github.com/tpope/vim-fugitive",
  data = {
    lazy = true,
    conf = function()
      local function git_pull()
        local bufnr = vim.api.nvim_get_current_buf()
        require("nviq.util.futures").spawn(function()
          local job = require("nviq.appl.git").pull()
          if job then
            vim.notify("Pulling...")
            if job:await() == 0 then
              vim.api.nvim_buf_call(bufnr, function() vim.cmd("Git") end)
            end
          end
        end)
      end

      local function git_push()
        local bufnr = vim.api.nvim_get_current_buf()
        require("nviq.util.futures").spawn(function()
          local job = require("nviq.appl.git").push()
          if job then
            vim.notify("Pushing...")
            if job:await() == 0 then
              vim.api.nvim_buf_call(bufnr, function() vim.cmd("Git") end)
            end
          end
        end)
      end

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("nviq.pack.git.fugitive", { clear = true }),
        pattern = "fugitive",
        callback = function(event)
          ---@type vim.keymap.set.Opts
          local opt = { buf = event.buf }
          vim.keymap.set("n", "<leader>gp", git_pull, opt)
          vim.keymap.set("n", "<leader>gP", git_push, opt)
        end
      })
    end,
    cmd = { "G", "Git" },
    keymap = {
      { mode = "n", lhs = "<leader>gn", rhs = "<Cmd>Git<CR>" }
    },
  }
}

------------------------------------gitsigns------------------------------------

packer.add {
  src = "https://github.com/lewis6991/gitsigns.nvim",
  data = {
    lazy = false,
    conf = function()
      local function nav_hunk_next()
        require("gitsigns").nav_hunk("next")
      end

      local function nav_hunk_prev()
        require("gitsigns").nav_hunk("prev")
      end

      require("gitsigns").setup {
        signs = {
          add          = { text = "│" },
          change       = { text = "│" },
          delete       = { text = "_" },
          topdelete    = { text = "‾" },
          changedelete = { text = "~" },
          untracked    = { text = "┆" },
        },
        signcolumn = true,
        numhl = false,
        linehl = false,
        word_diff = false,
        watch_gitdir = {
          follow_files = true
        },
        auto_attach = true,
        attach_to_untracked = false,
        current_line_blame = false,
        current_line_blame_opts = {
          virt_text          = true,
          virt_text_pos      = "eol",
          delay              = 1000,
          ignore_whitespace  = false,
          virt_text_priority = 100,
        },
        current_line_blame_formatter = "<author>, <author_time:%R> - <summary>",
        sign_priority = 6,
        update_debounce = 100,
        status_formatter = nil,
        max_file_length = 40000,
        preview_config = {
          border = _G.NVIQ.settings.tui.border,
          style = "minimal",
          relative = "cursor",
          row = 0,
          col = 1
        },
        on_attach = function(bufnr)
          ---@type vim.keymap.set.Opts
          local opt = { buf = bufnr }
          vim.keymap.set("n", "<leader>gj", nav_hunk_next, opt)
          vim.keymap.set("n", "<leader>gk", nav_hunk_prev, opt)
          vim.keymap.set("n", "<leader>gp", require("gitsigns").preview_hunk, opt)
          vim.keymap.set("n", "<leader>gb", require("gitsigns").blame_line, opt)
        end
      }
    end
  }
}
