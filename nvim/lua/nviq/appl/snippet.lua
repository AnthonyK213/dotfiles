local futil = require("nviq.util.f")

---@class nviq.appl.snippet.Snippet
---@field prefix string
---@field body string
---@field desc string

---@type table<string, nviq.appl.snippet.Snippet[]>
local _snippets = {}

---Loads all snippets in snippet_dir.
---@param snippet_dir string
local function load_snippets(snippet_dir)
  local package_json_path = vim.fs.joinpath(snippet_dir, "package.json")
  local package_json = futil.read_all_text(package_json_path)
  if not package_json then return end

  local pkg_ok, pkg = pcall(vim.json.decode, package_json)
  if not pkg_ok then return end

  local snippet_entries = vim.tbl_get(pkg, "contributes", "snippets")

  for _, entry in ipairs(snippet_entries) do
    local snippet_json_path = vim.fs.joinpath(snippet_dir, entry.path)
    local snippet_json = futil.read_all_text(snippet_json_path)
    if snippet_json then
      local snip_ok, snips = pcall(vim.json.decode, snippet_json)
      if snip_ok then
        local langs = type(entry.language) == "table" and entry.language or { entry.language }
        for _, lang in ipairs(langs) do
          local lang_snips = _snippets[lang]
          if not lang_snips then
            lang_snips = {}
            _snippets[lang] = lang_snips
          end
          for name, data in pairs(snips) do
            table.insert(lang_snips, {
              prefix = data.prefix,
              body = type(data.body) == "table" and table.concat(data.body, "\n") or data.body,
              desc = data.description or name
            })
          end
        end
      end
    end
  end
end

---Returns all snippets by language.
---@param lang string
---@return lsp.CompletionItem[]
local function get_snippet_items(lang)
  local items = {}

  local snips = _snippets[lang]
  for _, snip in ipairs(snips) do
    table.insert(items, {
      label = snip.prefix,
      kind = vim.lsp.protocol.CompletionItemKind.Snippet,
      insertText = snip.body,
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
    })
  end

  return items
end

local M = {}

---
---@return string
function M.snippet_dir()
  return vim.fs.joinpath(vim.fn.stdpath("config"), "snip")
end

---
function M.setup()
  load_snippets(M.snippet_dir())

  ---@type vim.lsp.Config
  local config = {
    cmd = function(dispatchers)
      local closing = false
      ---@type vim.lsp.rpc.PublicClient
      return {
        request = function(method, params, callback, _)
          if closing then return false, nil end
          if method == vim.lsp.protocol.Methods.initialize then
            callback(nil, {
              capabilities = {
                completionProvider = {
                  resolveProvider = false,
                },
              },
            }, 1)
          elseif method == vim.lsp.protocol.Methods.textDocument_completion then
            local bufnr = (params and params.textDocument and params.textDocument.uri)
                and vim.uri_to_bufnr(params.textDocument.uri)
                or vim.api.nvim_get_current_buf()
            local items = get_snippet_items(vim.bo[bufnr].filetype)
            callback(nil, { isIncomplete = false, items = items }, 1)
          elseif method == vim.lsp.protocol.Methods.shutdown then
            callback(nil, nil, 1)
          else
            return false, nil
          end
          return true, 1
        end,
        notify = function(method, _)
          if method == "exit" then
            closing = true
            dispatchers.on_exit(0, 15)
          end
          return true
        end,
        is_closing = function()
          return closing
        end,
        terminate = function()
          closing = true
        end
      }
    end,
    filetypes = vim.tbl_keys(_snippets),
    root_markers = {},
    root_dir = vim.fn.getcwd(),
    reuse_client = function(client, config)
      return client.name == config.name
    end,
    capabilities = {
      textDocument = {
        completion = {
          completionItem = {
            snippetSupport = true,
          }
        }
      }
    },
    on_attach = function(client, bufnr)
      vim.lsp.completion.enable(true, client.id, bufnr, { autotrigger = true })
    end
  }

  vim.lsp.config("nviq-snippet", config)
  vim.lsp.enable("nviq-snippet")
end

return M
