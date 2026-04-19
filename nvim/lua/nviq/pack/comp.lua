local lib = require("nviq.util.lib")
local packer = require("nviq.appl.packer")

------------------------------------LuaSnip-------------------------------------

packer.add {
  src = "https://github.com/L3MON4D3/LuaSnip",
  data = {
    lazy = true,
    conf = function()
      require("luasnip.loaders.from_vscode").lazy_load {
        paths = { require("nviq.appl.snippet").snippet_dir() }
      }
    end
  }
}

--------------------------------------cmp---------------------------------------

packer.add {
  src = "https://github.com/hrsh7th/nvim-cmp",
  data = {
    -- No lazy loading because capabilities should be set before lsp.
    lazy = false,
    deps = {
      "https://github.com/hrsh7th/cmp-buffer",
      "https://github.com/hrsh7th/cmp-cmdline",
      "https://github.com/hrsh7th/cmp-nvim-lsp",
      "https://github.com/hrsh7th/cmp-omni",
      "https://github.com/hrsh7th/cmp-path",
      "https://github.com/L3MON4D3/LuaSnip",
      "https://github.com/saadparwaiz1/cmp_luasnip",
    },
    conf = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup {
        completion = {
          keyword_length = 2,
        },
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end
        },
        mapping = {
          ["<C-b>"] = cmp.mapping(cmp.mapping.scroll_docs(-4), { "i" }),
          ["<C-f>"] = cmp.mapping(cmp.mapping.scroll_docs(4), { "i" }),
          ["<CR>"] = cmp.mapping {
            i = function(fallback)
              if cmp.visible() then
                cmp.confirm {
                  behavior = cmp.ConfirmBehavior.Replace,
                  select = true,
                }
              else
                fallback()
              end
            end,
          },
          ["<Tab>"] = cmp.mapping {
            i = function(fallback)
              if cmp.visible() then
                cmp.select_next_item {
                  behavior = cmp.SelectBehavior.Insert
                }
                return
              end

              if luasnip.locally_jumpable(1) then
                luasnip.jump(1)
              elseif luasnip.expandable() then
                luasnip.expand {}
              elseif lib.get_half_line(-1).b:match("[%w._:]$") and
                  vim.bo.buftype ~= "prompt" then
                cmp.complete()
              else
                fallback()
              end
            end,
            s = function(fallback)
              if luasnip.locally_jumpable(1) then
                luasnip.jump(1)
              else
                fallback()
              end
            end,
            c = function()
              if cmp.visible() then
                cmp.select_next_item {
                  behavior = cmp.SelectBehavior.Insert
                }
              else
                cmp.complete()
              end
            end
          },
          ["<S-Tab>"] = cmp.mapping {
            i = function(fallback)
              if cmp.visible() then
                cmp.select_prev_item {
                  behavior = cmp.SelectBehavior.Insert
                }
                return
              end

              if luasnip.locally_jumpable(-1) then
                luasnip.jump(-1)
              else
                fallback()
              end
            end,
            s = function(fallback)
              if luasnip.locally_jumpable(-1) then
                luasnip.jump(-1)
              else
                fallback()
              end
            end,
            c = function()
              if cmp.visible() then
                cmp.select_prev_item({
                  behavior = cmp.SelectBehavior.Insert
                })
              else
                cmp.complete()
              end
            end
          }
        },
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
        }, {
          { name = "path" },
          { name = "buffer", keyword_length = 4 },
        }),
        window = {
          completion = cmp.config.window.bordered {
            border = _G.NVIQ.settings.tui.border
          },
          documentation = cmp.config.window.bordered {
            border = _G.NVIQ.settings.tui.border
          },
        },
        experimental = {
          ghost_text = true,
        }
      }

      cmp.setup.cmdline("/", {
        sources = {
          { name = "buffer" }
        }
      })

      cmp.setup.cmdline(":", {
        sources = cmp.config.sources({
          { name = "path" }
        }, {
          { name = "cmdline" }
        })
      })

      cmp.setup.filetype("glsl", {
        formatting = {
          format = function(entry, vim_item)
            vim_item.menu = ({
              omni = "[GLSL]",
              buffer = "[Buffer]",
            })[entry.source.name]
            return vim_item
          end,
        },
        sources = {
          { name = "omni" },
          { name = "buffer" },
          { name = "path" },
        },
      })

      cmp.setup.filetype("tex", {
        formatting = {
          format = function(entry, vim_item)
            vim_item.menu = ({
              omni = (vim.inspect(vim_item.menu):gsub('%"', "")),
              buffer = "[Buffer]",
            })[entry.source.name]
            return vim_item
          end,
        },
        sources = {
          { name = "luasnip" },
          { name = "omni" },
          { name = "buffer" },
          { name = "path" },
        },
      })

      -- Set client capabilities for LSP servers in settings.

      if type(_G.NVIQ.settings.lsp) == "table" then
        for name, _ in pairs(_G.NVIQ.settings.lsp) do
          vim.lsp.config(name, {
            capabilities = require("cmp_nvim_lsp").default_capabilities()
          })
        end
      end
    end,
    event = { "InsertEnter", "CmdlineEnter" },
  }
}
