local ffi = require("ffi")
local rsmod = require("nviq.appl.rsmod")

---FFI module.
---@type ffi.namespace*
local _nviq_ime = nil

local function init()
  if _nviq_ime then
    return true
  end

  local dylib_path = rsmod.get_dylib_path("nviq-ime")
  if not dylib_path then
    return false
  end

  ffi.cdef [[
typedef uint32_t Source;
Source nviq_ime_get();
void nviq_ime_set(Source source);
]]

  _nviq_ime = ffi.load(dylib_path)

  return true
end

---@alias nviq.appl.ime.Source integer

---@enum nviq.appl.ime.Layout
local Layout = {
  None                = 0x0000,
  US                  = 0x0409,
  Chinese_Simplified  = 0x0804,
  Chinese_Traditional = 0x0404,
  Japanese            = 0x0411,
  Korean              = 0x0412,
}

local M = {}

M.Layout = Layout

---Returns the current input source.
---@return nviq.appl.ime.Source
function M.get()
  if init() then
    return _nviq_ime.nviq_ime_get()
  end
  return Layout.None
end

---Sets the current input source.
---@param source nviq.appl.ime.Source
function M.set(source)
  if init() then
    _nviq_ime.nviq_ime_set(source)
  end
end

return M
