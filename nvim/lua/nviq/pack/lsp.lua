local packer = require("nviq.appl.packer")

---------------------------------mason-lspconfig--------------------------------

packer.add {
  src = "https://github.com/mason-org/mason-lspconfig.nvim",
  data = {
    lazy = true,
    event = { "BufReadPre", "BufNewFile" },
    deps = {
      "https://github.com/neovim/nvim-lspconfig",
      "https://github.com/mason-org/mason.nvim",
    },
    conf = function()
      require("mason-lspconfig").setup {
        ensure_installed = require("nviq.appl.lsp").servers_to_install(),
        automatic_enable = false,
      }

      require("nviq.appl.lsp").setup()
    end
  }
}
