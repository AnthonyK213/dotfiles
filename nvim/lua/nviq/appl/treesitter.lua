local M = {}

---@class nviq.appl.treesitter.Options
---@field parsers string[]?
---@field indentexpr string?

---
---@return string[]?
function M.get_parsers()
  return vim.tbl_get(_G.NVIQ.settings, "ts", "parsers")
end

---
---@param opts? nviq.appl.treesitter.Options
function M.setup(opts)
  opts = opts or {}

  local parsers = opts.parsers or M.get_parsers()
  if not parsers or #parsers == 0 then
    return
  end

  local filetypes = {}
  for _, parser in ipairs(parsers) do
    local langs = vim.treesitter.language.get_filetypes(parser)
    for _, lang in ipairs(langs) do
      table.insert(filetypes, lang)
    end
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("nviq.appl.treesitter", { clear = true }),
    pattern = filetypes,
    callback = function()
      if pcall(vim.treesitter.start) then
        vim.wo.foldexpr = [[v:lua.vim.treesitter.foldexpr()]]
        if opts.indentexpr then
          vim.bo.indentexpr = opts.indentexpr
        end
      end
    end,
  })
end

return M
