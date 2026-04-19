local packer = require("nviq.appl.packer")

---------------------------------nvim-treesitter--------------------------------

packer.add {
  src = "https://github.com/nvim-treesitter/nvim-treesitter",
  version = "main",
  data = {
    lazy = false,
    conf = function()
      local ts = require("nviq.appl.treesitter")

      local parsers = ts.get_parsers()
      if not parsers or #parsers == 0 then
        return
      end

      if vim.fn.executable("tree-sitter") == 1 then
        require("nvim-treesitter").install(parsers)
      end

      ts.setup {
        parsers = parsers,
        -- indentexpr = [[v:lua.require("nvim-treesitter").indentexpr()]],
      }
    end
  }
}
