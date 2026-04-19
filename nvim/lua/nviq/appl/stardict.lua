local ffi = require("ffi")
local lib = require("nviq.util.lib")
local futil = require("nviq.util.f")
local rsmod = require("nviq.appl.rsmod")
local futures = require("nviq.util.futures")

local _stardict_path = vim.uv.os_homedir() .. "/.stardict/dic/"

---Opened floating window.
local _bufnr, _winid = -1, -1

local function try_focus()
  if vim.api.nvim_buf_is_valid(_bufnr)
      and vim.api.nvim_win_is_valid(_winid) then
    vim.api.nvim_set_current_win(_winid)
    return true
  end
  return false
end

---Shows lookup result in floating window.
---@param result { dict:string, word:string, definition:string }
local function show(result)
  local def = result.definition:gsub("^[\n\r]?%*", "\r")
  def = string.format("# %s\r\n__%s__\n%s", result.dict, result.word, def)
  local contents = vim.split(def, "[\r\n]")

  if vim.g.vscode then
    vim.notify(table.concat(contents, "\n"), vim.log.levels.INFO)
  else
    local float_opts = lib.flex_float()
    float_opts.wrap = true
    _bufnr, _winid = vim.lsp.util.open_floating_preview(contents, "markdown", float_opts)
  end
end

---@param data string
local function on_stdout(data)
  local ok, results = pcall(vim.json.decode, data)
  if not ok then
    lib.warn(results)
    return
  end
  if #results == 0 then
    lib.warn("No information available")
  elseif #results == 1 then
    show(results[1])
  else
    futures.spawn(function()
      local choice, indice = futures.ui.select(results, {
        prompt = "Select one result:",
        format_item = function(item)
          return item.word
        end
      })
      if not choice then return end
      show(results[indice])
    end)
  end
end

---Checks whether any local dictionaries exist. If not, prompt to download.
---@return boolean
local function check_dict()
  local n_dics = 0
  if futil.is_dir(_stardict_path) then
    for _, type_ in vim.fs.dir(_stardict_path) do
      if type_ == "directory" then
        n_dics = n_dics + 1
      end
    end
    if n_dics > 0 then
      vim.notify("Found " .. n_dics .. " dictionar" .. (n_dics == 1 and "y" or "ies") .. ".", vim.log.levels.INFO)
      return true
    end
  end
  futures.spawn(function()
    local yes_no = futures.ui.input {
      prompt = "No local dictionary found, get one? [Y/n] "
    }
    if yes_no and yes_no:lower() == "y" then
      vim.ui.open("https://github.com/AnthonyK213/.stardict")
    end
  end)
  return false
end

---FFI module.
---@type ffi.namespace*
local _nviq_stardict = nil

local M = {}

---@private
---Dictionaries.
M.library = nil

---@private
---@return boolean
function M:init()
  if not _nviq_stardict then
    local dylib_path = rsmod.get_dylib_path("nviq-stardict")
    if not dylib_path then
      lib.warn("Dynamic library was not found")
      return false
    end

    ffi.cdef [[
void *nviq_stardict_library_new(const char *dict_dir);
char *nviq_stardict_library_lookup(void *library, const char *word);
void nviq_stardict_library_drop(void *library);
void nviq_stardict_cstr_free(char *cstr);
]]

    _nviq_stardict = ffi.load(dylib_path)
  end

  if not self.library then
    if not _stardict_path or not check_dict() then
      return false
    end
    self.library = _nviq_stardict.nviq_stardict_library_new(_stardict_path)

    if not self.library then
      lib.warn("Failed to load dictionaries")
      return false
    end

    ffi.gc(self.library, _nviq_stardict.nviq_stardict_library_drop)
  end

  return true
end

---@private
---@param word string
---@return string
function M:lookup(word)
  if not self:init() then
    return "[]"
  end

  if word:match("^%s*$") then
    return "[]"
  end

  local c_str = _nviq_stardict.nviq_stardict_library_lookup(self.library, word)
  if not c_str then
    return "[]"
  end

  local result = ffi.string(c_str)
  _nviq_stardict.nviq_stardict_cstr_free(c_str)

  return result
end

---
---@param word string
function M.stardict(word)
  if try_focus() then
    return
  end

  if lib.has_exe("sdcv") then
    local p = futures.Process.new("sdcv", { args = { "-n", "-j", word } })
    p:on_stdout(function(_, data) on_stdout(data) end)
    p:start()
  else
    local result = M:lookup(word)
    vim.schedule_wrap(on_stdout)(result)
  end
end

return M
