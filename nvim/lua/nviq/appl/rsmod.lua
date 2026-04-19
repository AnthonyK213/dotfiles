local lib = require("nviq.util.lib")
local futil = require("nviq.util.f")
local putil = require("nviq.util.p")
local futures = require("nviq.util.futures")

local M = {}

---Returns the directory stores the binaries.
---@param name string
---@return string
local function get_release_dir(name)
  return vim.fs.joinpath(vim.fn.stdpath("config"), "rust", name, "target/release")
end

---Returns dynamic library path in this config.
---@param name string
---@return string?
function M.get_dylib_path(name)
  local dylib_ext = putil.dylib_ext()
  if not dylib_ext then
    lib.warn("Unsupported OS.")
    return
  end

  local dylib_dir = get_release_dir(name)
  local dylib_prefix = lib.has_win() and "" or "lib"
  local dylib_name = name:gsub("%-", "_")
  local dylib_file = dylib_prefix .. dylib_name .. dylib_ext
  local dylib_path = vim.fs.joinpath(dylib_dir, dylib_file)
  if not futil.is_file(dylib_path) then
    lib.warn(dylib_file .. " was not found.")
    return
  end

  return dylib_path
end

---Returns binary/executable file path in this config.
---@param name string
---@return string?
function M.get_bin_path(name)
  local bin_dir = get_release_dir(name)
  local bin_ext = lib.has_win() and ".exe" or ""
  local bin_file = name .. bin_ext
  local bin_path = vim.fs.joinpath(bin_dir, bin_file)
  if not futil.is_file(bin_path) then
    lib.warn(bin_file .. " was not found.")
    return
  end

  return bin_path
end

---Finds all crates in this configuration.
---@return table<string,{path:string}> crates
function M.find_crates()
  local crates = {}
  local crates_dir = vim.fs.joinpath(vim.fn.stdpath("config"), "rust")

  for name, type_ in vim.fs.dir(crates_dir) do
    if type_ == "directory" and not vim.startswith(name, "_") then
      local dir = vim.fs.joinpath(crates_dir, name)
      crates[name] = {
        path = dir
      }
    end
  end

  return crates
end

---Builds crates in this configuration.
---@param crates table<string,{path:string}>
function M.build_crates(crates)
  if not lib.has_exe("cargo", true) then
    return
  end

  if not crates or vim.tbl_isempty(crates) then
    lib.warn("No crates to build")
    return
  end

  local build_tasks = {}

  for crate_name, crate_info in pairs(crates) do
    local task = futures.async(function()
      local code
      -- code = futures.Process.new("cargo", {
      --   args = { "update" },
      --   cwd = crate_info.path,
      -- }):await()
      -- if code ~= 0 then
      --   lib.warn(crate_name .. ": Could not update the dependencies")
      --   return
      -- end
      code = futures.Process.new("cargo", {
        args = { "build", "--release" },
        cwd = crate_info.path,
      }):await()
      if code ~= 0 then
        lib.warn(crate_name .. ": Failed to build the crate")
        return
      end
      vim.notify(crate_name .. ": Done")
    end)
    table.insert(build_tasks, task)
  end

  if vim.tbl_isempty(build_tasks) then
    vim.notify("No crates to build")
    return
  end

  futures.spawn(function()
    vim.notify("Building...")
    local handles = vim.tbl_map(function(task)
      return futures.spawn(task())
    end, build_tasks)
    for _, handle in ipairs(handles) do
      handle:await()
    end
    futures.Task.delay(1000):await()
    vim.notify("Done")
  end)
end

return M
