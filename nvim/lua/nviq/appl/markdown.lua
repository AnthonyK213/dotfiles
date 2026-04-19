local lib = require("nviq.util.lib")
local Deque = require("nviq.util.collections").Deque
-- local Syntax = require("nviq.util.syntax").Syntax

local M = {}

---@enum nviq.appl.markdown.LineType
local LineType = {
  None   = 0,
  List   = 1,
  Empty  = 2,
  Ignore = 3,
}

---@class nviq.appl.markdown.LineInfo
---@field type nviq.appl.markdown.LineType
---@field lnum integer Line number (0-based).
---@field indent integer

---
---@param bufnr integer
---@param lnum integer Line number (0-based).
---@return nviq.appl.markdown.LineInfo
local function get_line_info(bufnr, lnum)
  ---@type nviq.appl.markdown.LineInfo
  local info = {
    type = LineType.None,
    lnum = lnum,
    indent = 0,
  }

  local s, e

  -- if Syntax.get(bufnr, lnum, 0):match {
  --       syntax = "\\v(markdownHighlight|markdownCode|textSnip)",
  --       treesitter = "\\vraw\\.block",
  --     } then
  --   info.type = LineType.Ignore
  --   return info
  -- end

  s, e = vim.regex("\\v^\\s*$"):match_line(bufnr, lnum)
  if s and e then
    info.type = LineType.Empty
    return info
  end

  s, e = vim.regex("\\v^\\s*(\\-|\\*|\\d+\\.)\\s+"):match_line(bufnr, lnum)
  if s and e then
    info.type = LineType.List
  end

  info.indent = vim.fn.indent(lnum + 1)
  return info
end

---
---@param line string
---@return string? bullet
---@return integer b_s Start byte pos (0-based, inclusive)
---@return integer b_e End byte pos (0-base, exclusive)
---@return boolean ordered
local function get_list_bullet(line)
  local bullet, s, e

  s, bullet, e = line:match("^%s*()([%-%*])()%s+.*$")
  if bullet then
    return bullet, s - 1, e - 1, false
  end

  s, bullet, e = line:match("^%s*()(%d+%.)()%s+.*$")
  if bullet then
    return bullet, s - 1, e - 1, true
  end

  return nil, 0, 0, false
end

---
---@param bullet string
---@return string?
function M.bullet_decrement(bullet)
  local index = tonumber(bullet:match("%d+"))
  if not index or index <= 1 then return end
  return tostring(index - 1) .. "."
end

---
---@param bullet string
---@return string?
function M.bullet_increment(bullet)
  local index = tonumber(bullet:match("%d+"))
  if not index then return end
  return tostring(index + 1) .. "."
end

---@class nviq.appl.markdown.ListItemRegion
---@field bufnr integer
---@field bullet string
---@field b_s integer Bullet byte start pos (0-based, inclusive).
---@field b_e integer Bullet byte end pos (0-based, exclusive).
---@field ordered boolean
---@field begin integer (0-based, inclusive).
---@field end_ integer (0-based, exclusive).
---@field indent integer
local ListItemRegion = {}

ListItemRegion.__index = ListItemRegion

---
---@param bufnr integer Buffer number.
---@param lnum? integer Line number (0-based).
---@return nviq.appl.markdown.ListItemRegion?
function ListItemRegion.get(bufnr, lnum)
  bufnr = lib.bufnr(bufnr)
  lnum = lnum or (vim.api.nvim_win_get_cursor(0)[1] - 1)

  local region = {
    bufnr   = bufnr,
    bullet  = "",
    b_s     = 0,
    b_e     = 0,
    ordered = false,
    begin   = 0,
    end_    = 0,
    indent  = 0,
  }

  local info = get_line_info(bufnr, lnum)

  -- Search for the beginning.

  local indent = (info.type == LineType.Empty or info.type == LineType.Ignore) and 1e8 or info.indent
  if info.type ~= LineType.List then
    for l = lnum - 1, 0, -1 do
      local i = get_line_info(bufnr, l)
      if i.indent < indent then
        if i.type == LineType.List then
          info = i
          break
        elseif i.type == LineType.None then
          indent = i.indent
        end
      end
    end
  end

  if info.type ~= LineType.List then return end

  region.begin = info.lnum
  region.indent = info.indent

  -- Get the bullet.

  local line = vim.api.nvim_buf_get_lines(bufnr, region.begin, region.begin + 1, true)[1]
  local bullet, b_s, b_e, ordered = get_list_bullet(line)
  if not bullet then return end
  region.bullet = bullet
  region.b_s = b_s
  region.b_e = b_e
  region.ordered = ordered

  -- Search for the ending.

  local lcnt = vim.api.nvim_buf_line_count(bufnr)
  local empty_flag = false
  for l = lnum + 1, lcnt - 1, 1 do
    local i = get_line_info(bufnr, l)
    -- Find the last non-empty line.
    if i.type == LineType.Empty then
      if not empty_flag then
        region.end_ = l
        empty_flag = true
      end
    elseif i.type ~= LineType.Ignore and i.indent <= info.indent then
      if not empty_flag then
        region.end_ = l
      end
      break
    else
      empty_flag = false
    end
  end

  if region.end_ <= 0 then
    region.end_ = lcnt
  end

  setmetatable(region, ListItemRegion)
  return region
end

---
---@param new_bullet string
function ListItemRegion:set_bullet(new_bullet)
  if self.bullet == new_bullet then return end
  vim.api.nvim_buf_set_text(self.bufnr, self.begin, self.b_s, self.begin, self.b_e, { new_bullet })
  self.b_e = self.b_e + #new_bullet - self.bullet
  self.bullet = new_bullet
end

---
---@param bufnr? integer
---@param lnum? integer Line numebr (0-based)
---@param options? { forward_only:boolean? }
function M.regen_ordered_list(bufnr, lnum, options)
  bufnr = lib.bufnr(bufnr)
  options = options or {}

  local curr = ListItemRegion.get(bufnr, lnum)
  if not curr or not curr.ordered then return end

  local regions = Deque(curr)
  local index

  if not options.forward_only then
    local l = curr.begin - 1
    while l >= 0 do
      local region = ListItemRegion.get(bufnr, l)
      if not region or region.indent < curr.indent then
        break
      end
      if region.ordered and region.indent == curr.indent then
        regions:push_front(region)
      end
      l = region.begin - 1
    end

    for i, region in regions:iter() do
      region:set_bullet(tostring(i) .. ".")
    end
    index = regions:count()
  else
    index = tonumber(curr.bullet:match("%d+"))
    if not index then return end
  end

  local l = curr.end_
  local lcnt = vim.api.nvim_buf_line_count(bufnr)
  while l < lcnt do
    local info = get_line_info(bufnr, l)
    if info.type == LineType.Empty then
      l = l + 1
    else
      local region = ListItemRegion.get(bufnr, l)
      if not region or
          not region.ordered or
          region.indent < curr.indent or
          region.begin <= curr.begin then
        break
      end
      if region.indent == curr.indent then
        index = index + 1
        region:set_bullet(tostring(index) .. ".")
      end
      l = region.end_
    end
  end
end

M.ListItemRegion = ListItemRegion

return M
