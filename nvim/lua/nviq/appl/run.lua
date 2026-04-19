local lib = require("nviq.util.lib")
local futil = require("nviq.util.f")
local futures = require("nviq.util.futures")

local M = {}

---@class nviq.appl.run.Args
---@field file_type string
---@field file_dir string
---@field file_name string
---@field prod_name? string

---@class nviq.appl.run.TaskSpec
---@field cmd string|string[]
---@field args string[]
---@field cmdline? boolean
---@field product? boolean

---@alias nviq.appl.run.Recipe table<string|1, nviq.appl.run.TaskSpec>

---@type table<string, nviq.appl.run.Recipe>
local _recipe_table = {
  c = {
    {
      cmd = { "clang", "gcc" },
      args = { "${file_name}", "-o", "${prod_name}" },
      product = true,
    }
  },
  cpp = {
    {
      cmd = { "clang++", "g++" },
      args = { "${file_name}", "-o", "${prod_name}" },
      product = true,
    }
  },
  cs = {
    { cmd = "dotnet", args = { "run" } },
    clean = { cmd = "dotnet", args = { "clean" } },
    test = { cmd = "dotnet", args = { "test" } },
  },
  fennel = {
    { cmd = "fennel", args = { "${file_name}" } },
    luajit = { cmd = "fennel", args = { "--use-bit-lib", "${file_name}" } }
  },
  lisp = {
    {
      cmd = "sbcl",
      args = { "--noinform", "--load", "${file_name}", "--eval", "(exit)" }
    }
  },
  lua = {
    { cmd = { "lua", "luajit" }, args = { "${file_name}" } },
    nvim = {
      cmd = "luafile",
      args = { "${file_name}" },
      cmdline = true
    },
  },
  python = { { cmd = { "python3", "python" }, args = { "${file_name}" } } },
  ruby = { { cmd = "ruby", args = { "${file_name}" } } },
  rust = {
    { cmd = "cargo", args = { "run" } },
    check = { cmd = "cargo", args = { "check" } },
    test = { cmd = "cargo", args = { "test" } },
  },
  vim = {
    {
      cmd = "source",
      args = { "${file_name}" },
      cmdline = true
    }
  },
}

---
---@param filetype string
---@return nviq.appl.run.Recipe?
function M.get_recipe(filetype)
  return _recipe_table[filetype]
end

---
---@param recipe nviq.appl.run.Recipe
---@return string[]
function M.recipe_get_options(recipe)
  local options = {}
  for option, _ in pairs(recipe) do
    if type(option) == "string" then
      table.insert(options, option)
    end
  end
  return options
end

---
---@param recipe nviq.appl.run.Recipe
---@param option? string
---@return nviq.appl.run.TaskSpec?
function M.recipe_get_task(recipe, option)
  local opt = option or 1
  return recipe[opt]
end

---Find an executable. If not found, return the first element in `cmd`.
---@param cmd string|string[]
---@return string
local function extract_cmd(cmd)
  if type(cmd) == "string" then
    return cmd
  end
  for _, exe in ipairs(cmd) do
    if vim.fn.executable(exe) == 1 then
      return exe
    end
  end
  return cmd[1]
end

---
---@param arg string
---@param arg_map nviq.appl.run.Args
---@return string?
local function extract_cmd_arg(arg, arg_map)
  local arg_name = arg:match("^%${(.+)}$")
  if not arg_name then
    return arg
  end
  local cmd_arg = arg_map[arg_name]
  if type(cmd_arg) == "string" then
    return cmd_arg
  end
  if arg_name == "prod_name" then
    local prod_name = vim.fn.strftime("nviq_run_%Y%m%d%H%M%S")
    if lib.has_win() then
      prod_name = prod_name .. ".exe"
    end
    arg_map.prod_name = prod_name
    return prod_name
  end
end

---
---@param cmd string[]
---@param options? table
---@return nviq.futures.Terminal?
local function term_new(cmd, options)
  local term = futures.Terminal.new(cmd, options)
  if not term:is_valid(true) then
    return
  end

  local height = vim.fn.winheight(0)
  local win = vim.api.nvim_open_win(0, true, {
    split  = "below",
    win    = 0,
    height = lib.clamp(math.floor(height * 0.382), 1, 15),
  })

  if win == 0 then
    lib.warn("Failed to create a new window")
    return
  end

  return term
end

---
---@param task nviq.appl.run.TaskSpec
---@param args nviq.appl.run.Args
function M.task_run(task, args)
  local cmd = extract_cmd(task.cmd)

  local cmd_args = {}
  for index, value in ipairs(task.args) do
    local cmd_arg = extract_cmd_arg(value, args)
    if not cmd_arg then
      lib.warn(string.format("Unknown argument: %s", value))
      return
    end
    cmd_args[index] = cmd_arg
  end

  if task.product then
    if not args.prod_name then return end
    local build = futures.Process.new(cmd, {
      args = cmd_args,
      cwd = args.file_dir,
    })
    build:set_record(true)
    futures.spawn(function()
      local code = build:await()
      local prod_path = vim.fs.joinpath(args.file_dir, args.prod_name)
      if code == 0 then
        local run
        if lib.has_win() then
          -- Handle negative return value on Windows.
          local cmd_wrap = string.format(
            [[".\\%s & call echo [Process exited !ERRORLEVEL!] & exit /b 0"]],
            args.prod_name
          )
          run = term_new({ "cmd", "/V:ON", "/c", cmd_wrap }, { cwd = args.file_dir })
        else
          run = term_new({ prod_path }, { cwd = args.file_dir })
        end
        if run then
          run:await()
        end
      else
        build:notify_err()
      end
      if futil.is_file(prod_path) then
        vim.fs.rm(prod_path)
      end
    end)
    return
  end

  table.insert(cmd_args, 1, cmd)

  if task.cmdline then
    vim.cmd(table.concat(cmd_args, " "))
    return
  end

  local run = term_new(cmd_args, { cwd = args.file_dir })
  if run then
    run:start()
  end
end

return M
