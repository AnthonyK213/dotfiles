---@alias nviq.appl.lsp.OnAttach fun(client:vim.lsp.Client,bufnr:integer)

---@type nviq.appl.lsp.OnAttach[]
local _client_on_attach_queue = {}

local _filter_symbols_kind = {
  "Class",
  "Constructor",
  "Enum",
  "Function",
  "Interface",
  "Module",
  "Method",
  "Struct",
}

local function lsp_hover()
  local opts = require("nviq.util.lib").flex_float()
  vim.lsp.buf.hover(opts --[[@as vim.lsp.buf.hover.Opts]])
end

local function diagnostic_jump_prev()
  vim.diagnostic.jump { count = -1 }
end

local function diagnostic_jump_next()
  vim.diagnostic.jump { count = 1 }
end

---Callback invoked when client attaches to a buffer.
---@param client vim.lsp.Client
---@param bufnr integer
local function custom_attach(client, bufnr)
  ---@type vim.keymap.set.Opts
  local opt = { buf = bufnr }

  -- "<C-S>": vim.lsp.buf.signature_help
  vim.keymap.set("n", "K", lsp_hover, opt)                            -- "K"

  vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, opt)     -- "gra"
  vim.keymap.set("n", "<leader>li", vim.lsp.buf.implementation, opt)  -- "gri"
  vim.keymap.set("n", "<leader>ln", vim.lsp.buf.rename, opt)          -- "grn"
  vim.keymap.set("n", "<leader>lr", vim.lsp.buf.references, opt)      -- "grr"
  vim.keymap.set("n", "<leader>lt", vim.lsp.buf.type_definition, opt) -- "grt"

  vim.keymap.set("n", "<leader>ld", vim.lsp.buf.declaration, opt)
  vim.keymap.set("n", "<leader>lf", vim.lsp.buf.definition, opt)
  vim.keymap.set("n", "<leader>lm", vim.lsp.buf.format, opt)
  vim.keymap.set("n", "<leader>ls", vim.lsp.buf.workspace_symbol, opt)

  vim.keymap.set("n", "<leader>l[", diagnostic_jump_prev, opt)      -- "[d"
  vim.keymap.set("n", "<leader>l]", diagnostic_jump_next, opt)      -- "]d"
  vim.keymap.set("n", "<leader>lk", vim.diagnostic.open_float, opt) -- "<C-W>d"

  for _, cb in ipairs(_client_on_attach_queue) do
    cb(client, bufnr)
  end
end

---Setup an LSP server.
---@param name string Name of the language server.
---@param spec nviq.core.settings.LspSpec Server configuration from `nvimrc`.
local function setup_server(name, spec)
  if type(spec) ~= "table" then return end

  if not vim.lsp.config[name] then return end

  ---@type vim.lsp.Config
  local cfg = {}

  local on_attach = vim.lsp.config[name].on_attach
  if type(on_attach) == "function" then
    cfg.on_attach = function(client, bufnr)
      on_attach(client, bufnr)
      custom_attach(client, bufnr)
    end
  else
    cfg.on_attach = custom_attach
  end

  -- Set custom LSP configurations.
  if type(spec.settings) == "table" then
    cfg.settings = spec.settings
  end

  -- Configure the server.
  vim.lsp.config(name, cfg)

  -- Enable the server.
  if spec.enable then
    vim.lsp.enable(name)
  end
end

local M = {}

---Setup all LSP servers.
function M.setup()
  if type(_G.NVIQ.settings.lsp) ~= "table" then return end
  for name, conf in pairs(_G.NVIQ.settings.lsp) do
    setup_server(name, conf)
  end

  -- Turn off the annoying header insertion. Leave me alone!
  local clangd_cmd = vim.lsp.config.clangd.cmd --[[@as string[] ]]
  if clangd_cmd then
    table.insert(clangd_cmd, "--header-insertion=never")
    vim.lsp.config("clangd", { cmd = clangd_cmd })
  end
end

---
---@param cb nviq.appl.lsp.OnAttach
function M.register_client_on_attach(cb)
  table.insert(_client_on_attach_queue, cb)
end

---
---@return string[]
function M.servers_to_install()
  if type(_G.NVIQ.settings.lsp) ~= "table" then
    return {}
  end

  return vim.iter(_G.NVIQ.settings.lsp)
      :filter(function(_, spec)
        return type(spec) == "table" and
            spec.enable == true and
            spec.install == true
      end)
      :map(function(name, _)
        return name
      end)
      :totable()
end

---
---@return string[]
function M.filter_symbols_kind()
  return _filter_symbols_kind
end

return M
