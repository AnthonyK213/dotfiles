local ffi = require("ffi")
local rsmod = require("nviq.appl.rsmod")

---FFI module.
---@type ffi.namespace*
local _nviq_theme = nil

local M = {}

---@enum nviq.appl.theme.Theme
M.Theme = {
  Error       = -1,
  Dark        = 0,
  Light       = 1,
  Unspecified = 2,
}

function M.init()
  if _nviq_theme then
    return true
  end

  local dylib_path = rsmod.get_dylib_path("nviq-theme")
  if not dylib_path then
    return false;
  end

  ffi.cdef [[ int nviq_theme_detect(); ]]
  _nviq_theme = ffi.load(dylib_path)
  return true
end

---
---@return nviq.appl.theme.Theme
function M.detect()
  if not M.init() then
    return M.Theme.Error
  end
  return _nviq_theme.nviq_theme_detect()
end

---
---@param theme? string
---@return "dark"|"light"
function M.normalize(theme)
  if not theme or theme == "auto" then
    if M.detect() == M.Theme.Light then
      return "light"
    else
      return "dark"
    end
  elseif theme == "dark" or theme == "light" then
    return theme
  else
    return "dark"
  end
end

---
---@param theme? string
function M.set_theme(theme)
  if vim.is_callable(_G.NVIQ.handlers.set_theme) then
    theme = M.normalize(theme)
    _G.NVIQ.handlers.set_theme(theme)
  end
end

return M
