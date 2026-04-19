-- File utilities.

local M = {}

---Checks whether `path` exists.
---@param path string The path.
---@return boolean
function M.exist(path)
  local stat = vim.uv.fs_stat(path)
  return (stat ~= nil) and (stat.type ~= nil)
end

---Checks whether `path` is a file.
---@param path string The path.
---@return boolean
function M.is_file(path)
  local stat = vim.uv.fs_stat(path)
  return (stat ~= nil) and (stat.type == "file")
end

---Checks whether `path` is a directory.
---@param path string The path.
---@return boolean
function M.is_dir(path)
  local stat = vim.uv.fs_stat(path)
  return (stat ~= nil) and (stat.type == "directory")
end

---Checks whether `path` is a relative path.
---@param path string The path
---@return boolean
function M.is_relative(path)
  if jit.os == "Windows" then
    if path:match("^%a:[\\/]") then
      return false
    end
  else
    if path:match("^/") then
      return false
    end
  end
  return true
end

---Opens a text file, reads all the text in the file into a string, and then
---closes the file.
---@param path string The file to open for reading.
---@return string? content A string containing all the text in the file.
function M.read_all_text(path)
  local file = io.open(path, "r")
  if file then
    local content = file:read("*a")
    file:close()
    return content
  end
end

return M
