local lib = require("nviq.util.lib")
local futil = require("nviq.util.f")
local futures = require("nviq.util.futures")

local M = {}

---Returns the root directory of this repository.
---@return string?
function M.get_root()
  return vim.fs.root(0, function(name, path)
    return name == ".git" and futil.is_dir(vim.fs.joinpath(path, name))
  end)
end

---Returns the current branch name.
---@param git_root string The root directory of the repository.
---@return string? result The current branch name.
function M.get_branch(git_root)
  local head_file = vim.fs.joinpath(git_root, "/.git/HEAD")

  local file = io.open(head_file)
  if file then
    local gitdir_line = file:read("*l")
    file:close()
    if gitdir_line then
      local branch = gitdir_line:match("^ref:%s.+/([^%s]-)$")
      if branch and #branch > 0 then
        return branch
      end
    end
  end
end

---@type vim.lpeg.Pattern?
local blame_info_pattern = nil

---
---@param info string
---@return table<string, string>?
local function parse_blame_info(info)
  if not blame_info_pattern then
    blame_info_pattern = vim.re.compile([[
      blame <- {| head (%nl field)* (%nl) code |}
      head <- {:hash: [0-9a-f]^40 :} %s {:lnum_origin: %d+ :} %s {:lnum_final: %d+ :} %s {:lcnt: %d+ :}
      field <- {| {[%a-]+} (" ")? {[^%nl]*} |}
      code <- %t {:code: ([^%nl]*) :}
    ]], { t = "\t" })
  end

  local captures = vim.re.match(info, blame_info_pattern)
  if not captures then
    return
  end

  for _, v in ipairs(captures --[[@as table]]) do
    captures[v[1]] = v[2]
  end

  return captures --[[@as table<string, string>]]
end

---To blame someone :)
function M.blame_line()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local file = vim.api.nvim_buf_get_name(0)
  local cwd = lib.buf_dir(0)
  local range = string.format("%d,%d", lnum, lnum)
  local blame = futures.Process.new("git", {
    args = { "blame", "--line-porcelain", "-L", range, file },
    cwd = cwd,
  })
  blame:set_record(true)
  futures.spawn(function()
    local code = blame:await()
    if code ~= 0 or vim.tbl_isempty(blame:stdout_buf()) then
      vim.notify("No one to blame...")
      return
    end
    local blame_info = parse_blame_info(blame:stdout_buf()[1])
    if blame_info then
      local hash = blame_info["hash"]
      if hash:match("^0+$") then
        vim.print("Not Committed Yet")
        return
      end
      vim.print(string.format("%s %s (%s): %s",
        hash:sub(1, 8),
        blame_info["author"],
        os.date("%Y-%m-%d %H:%M", tonumber(blame_info["author-time"])),
        blame_info["summary"]
      ))
    end
  end)
end

function M.commit()
  local root = M.get_root()
  if not root then
    lib.warn("Not a git repository.")
    return
  end

  futures.spawn(function()
    local message = futures.ui.input { prompt = "Commit message: " }
    if not message then
      lib.warn("Canceled")
      return
    end

    local commit = futures.Process.new("git", {
      args = { "commit", "-m", message },
      cwd = root,
    })
    commit:set_record(true)

    if commit:await() == 0 then
      vim.notify(table.concat(commit:stdout_buf(), "\n"))
    else
      commit:notify_err()
    end
  end)
end

---
---@param job nviq.futures.Job
---@param data string
local function prompt_default(job, data)
  local prompt = data:gsub("[\r\n]", "")
  local user_input = vim.fn.input { prompt = prompt }
  pcall(job.send, job, user_input .. "\n")
end

---
---@param job nviq.futures.Job
---@param data string
local function prompt_secret(job, data)
  vim.fn.inputsave()
  local prompt = data:gsub("[\r\n]", "")
  local user_input = vim.fn.inputsecret(prompt)
  vim.fn.inputrestore()
  pcall(job.send, job, user_input .. "\n")
end

---
---@param job nviq.futures.Job
---@param data string[]
local function on_pty_stdout(job, data)
  if #data == 1 and data[1] == "" then return --[[EOF]] end
  for _, d in ipairs(data --[=[@as string[]]=]) do
    local raw_data = d:gsub("\27%[[%d;?]*[FGHJKhlm]", "")
    if raw_data:match("^Username for ") then
      prompt_default(job, raw_data)
    elseif raw_data:match("^Enter passphrase") or
        raw_data:match("'s password:") or
        raw_data:match("^Password for ") then
      prompt_secret(job, raw_data)
    elseif raw_data:match("^\27]0;") then
      -- Start of an Operating System Command, just ignore it.
    elseif raw_data:match("^Are you sure you want to continue connecting ") or
        raw_data:match("Please type .+:") then
      prompt_default(job, raw_data)
    else
      table.insert(job:stdout_buf(), raw_data)
    end
  end
end

---
---@param job nviq.futures.Job
---@param data integer
local function on_pty_exit(job, data)
  local message = table.concat(job:stdout_buf(), "\n")
  if data == 0 then
    vim.notify(message)
  else
    lib.warn(message)
  end
end

---
---@return nviq.futures.Job?
function M.pull()
  local root = M.get_root()
  if not root then
    lib.warn("Not a git repository.")
    return
  end

  local pull_job = futures.Job.new({ "git", "pull" }, { cwd = root, pty = true })
  pull_job:on_stdout(on_pty_stdout)
  pull_job:continue_with(on_pty_exit)

  return pull_job
end

---
---@return nviq.futures.Job?
function M.push()
  local root = M.get_root()
  if not root then
    lib.warn("Not a git repository.")
    return
  end

  local push_job = futures.Job.new({ "git", "push" }, { cwd = root, pty = true })
  push_job:on_stdout(on_pty_stdout)
  push_job:continue_with(on_pty_exit)

  return push_job
end

return M
