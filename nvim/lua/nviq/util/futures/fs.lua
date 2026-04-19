local lib = require("nviq.util.lib")
local uv = require("nviq.util.futures.uv")

local M = {}

---Opens a text file, reads all the text in the file into a string,
---and then closes the file.
---@async
---@param path string The file to open for reading.
---@return string? content A string containing all the text in the file.
function M.read_all_text(path)
  local err, fd, stat, data
  err, fd = uv.fs_open(path, "r", 438)
  assert(not err and fd, err)
  lib.try(function()
    err, stat = uv.fs_fstat(fd)
    assert(stat and not err, err)
    err, data = uv.fs_read(fd, stat.size, 0)
    assert(data and not err, err)
  end).catch(function(ex)
    lib.warn(ex)
  end).finally(function()
    uv.fs_close(fd)
  end)
  return data
end

return M
