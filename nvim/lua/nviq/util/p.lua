-- Platform utilities.

local M = {}

---@type nviq.util.p.OS
local _current_os = nil

---@enum nviq.util.p.OS
M.OS = {
  Unknown = 0,
  Linux   = 1,
  Windows = 2,
  MacOS   = 3,
}

---Returns the extension of a dynamic library file.
---@return string?
function M.dylib_ext()
  return ({
    [M.OS.Windows] = ".dll",
    [M.OS.Linux]   = ".so",
    [M.OS.MacOS]   = ".dylib",
  })[M.os_type()]
end

---Returns the type of current OS.
---@return nviq.util.p.OS os_type Type of current OS.
function M.os_type()
  if _current_os then return _current_os end

  local name = vim.uv.os_uname().sysname
  if name == "Linux" then
    _current_os = M.OS.Linux
  elseif name == "Windows_NT" then
    _current_os = M.OS.Windows
  elseif name == "Darwin" then
    _current_os = M.OS.MacOS
  else
    _current_os = M.OS.Unknown
  end

  return _current_os
end

return M
