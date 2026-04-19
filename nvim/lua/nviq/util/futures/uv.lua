local _uv_callback_index = {
  fs_opendir = 2,
}

---Async wrapper of `vim.uv`.
---CAVEATS: The return values are the the `callback`'s arguments of the async
---version of a uv function, different from the sync version.
---@type table<string, function>
local M = {}

setmetatable(M, {
  __index = function(_, k)
    local obj = vim.uv[k]

    if vim.is_callable(obj) then
      return function(...)
        return require("nviq.util.futures.task").new(obj, ...)
            :set_async(_uv_callback_index[k] or true):await()
      end
    end

    return obj
  end
})

return M
