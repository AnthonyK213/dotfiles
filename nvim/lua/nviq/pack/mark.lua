local packer = require("nviq.appl.packer")

--------------------------------markdown-preview--------------------------------

-- packer.add {
--   src = "https://github.com/iamcco/markdown-preview.nvim",
--   data = {
--     lazy = true,
--     init = function()
--       vim.g.mkdp_auto_start = 0
--       vim.g.mkdp_auto_close = 1
--       vim.g.mkdp_preview_options = {
--         mkit = {},
--         katex = {},
--         uml = {},
--         maid = {},
--         disable_sync_scroll = 0,
--         sync_scroll_type = "relative",
--         hide_yaml_meta = 1,
--         sequence_diagrams = {},
--         flowchart_diagrams = {},
--         content_editable = false,
--         disable_filename = 0
--       }
--       vim.g.mkdp_filetypes = { "markdown" }
--     end,
--     conf = function()
--       vim.api.nvim_create_autocmd("FileType", {
--         group = vim.api.nvim_create_augroup("nviq.pack.mark.markdown-preview", { clear = true }),
--         pattern = { "markdown" },
--         callback = function(event)
--           vim.b[event.buf].nviq_handler_preview_toggle = function()
--             if vim.fn.exists(":MarkdownPreviewToggle") ~= 0 then
--               vim.cmd.MarkdownPreviewToggle()
--             end
--           end
--         end,
--       })
--     end,
--     hook = {
--       post = function(ev)
--         if ev.kind == "install" then
--           vim.cmd [[packadd markdown-preview.nvim]]
--           vim.cmd [[call mkdp#util#install()]]
--         end
--       end
--     },
--     ft = "markdown"
--   },
-- }

---------------------------------vim-table-mode---------------------------------

packer.add {
  src = "https://github.com/dhruvasagar/vim-table-mode",
  data = {
    lazy = true,
    keymap = {
      { mode = "n", lhs = "<leader>ta", rhs = "<Cmd>TableAddFormula<CR>" },
      { mode = "n", lhs = "<leader>tc", rhs = "<Cmd>TableEvalFormulaLine<CR>" },
      { mode = "n", lhs = "<leader>tf", rhs = "<Cmd>TableModeRealign<CR>" },
      { mode = "n", lhs = "<leader>tm", rhs = "<Cmd>TableModeToggle<CR>" },
    }
  }
}

-------------------------------------vimtex-------------------------------------

packer.add {
  src = "https://github.com/lervag/vimtex",
  data = {
    lazy = true,
    init = function()
      vim.g.tex_flavor = "latex"
      vim.g.vimtex_toc_config = {
        split_pos = "vert rightbelow",
        split_width = 30,
        show_help = 0,
      }
      if jit.os == "Windows" then
        vim.g.vimtex_view_general_viewer = "SumatraPDF"
        vim.g.vimtex_view_general_options = "-reuse-instance -forward-search @tex @line @pdf"
      elseif jit.os == "Linux" then
        vim.g.vimtex_view_method = "zathura"
      elseif jit.os == "OSX" then
        vim.g.vimtex_view_method = "skim"
      end
    end,
    conf = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("nviq.pack.mark.vimtex", { clear = true }),
        pattern = "tex",
        callback = function(event)
          vim.keymap.set("n", "<leader>mv", "<Cmd>VimtexTocToggle<CR>", { buf = event.buf })
        end
      })
    end,
    ft = "tex"
  }
}

------------------------------------wiki.vim------------------------------------

packer.add {
  src = "https://github.com/lervag/wiki.vim",
  data = {
    lazy = true,
    init = function()
      vim.g.wiki_root = vim.fs.normalize(_G.NVIQ.settings.path.vimwiki)
      vim.g.wiki_filetypes = { "md" }
    end,
    keymap = {
      { mode = "n", lhs = "<leader>ww" },
      { mode = "n", lhs = "<leader>w<leader>w" },
      { mode = "n", lhs = "<leader>wn" },
    }
  }
}
