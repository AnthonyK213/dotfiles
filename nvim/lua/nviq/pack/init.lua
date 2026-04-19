-- No plugins when offline.
if _G.NVIQ.settings.general.offline then return end

-- Disable some built-in plugins.

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Setup packer.

local packer = require("nviq.appl.packer")

packer.begin { confirm = false }

require("nviq.pack.ui")
require("nviq.pack.treesitter")
require("nviq.pack.kits")
require("nviq.pack.lsp")
require("nviq.pack.comp")
require("nviq.pack.git")
require("nviq.pack.dap")
require("nviq.pack.dev")
require("nviq.pack.mark")

packer.end_()

-- Packer commands.

vim.api.nvim_create_user_command("PacksUpdate", function(tbl)
  local opt = { force = false }
  if #tbl.fargs == 0 then
    vim.pack.update(nil, opt)
  else
    vim.pack.update(tbl.fargs, opt)
  end
end, {
  nargs = "*",
  complete = function()
    local plug_datas = vim.pack.get(nil, { info = false })
    return vim.iter(plug_datas):map(function(plug_data)
      if plug_data.active then
        return plug_data.spec.name
      end
      return nil
    end):filter(function(name)
      return name ~= nil
    end):totable()
  end,
  desc = "Update packages managed by vim.pack."
})

vim.api.nvim_create_user_command("PacksClean", function(_)
  local plug_datas = vim.pack.get(nil, { info = false })
  local plugs_to_del = {}
  for _, plug_data in ipairs(plug_datas) do
    if not plug_data.active then
      table.insert(plugs_to_del, plug_data.spec.name)
    end
  end
  vim.pack.del(plugs_to_del)
end, { desc = "Clean inactive packages." })

vim.api.nvim_create_user_command("PacksInfo", function(_)
  packer.info()
end, { desc = "Show information of installed packages." })
