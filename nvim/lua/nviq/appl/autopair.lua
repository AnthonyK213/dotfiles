local lib = require("nviq.util.lib")
local kutil = require("nviq.util.k")
local sutil = require("nviq.util.s")

local M = {}

---@enum nviq.appl.autopair.ActionType
local ActionType = {
  Open      = 0,
  Close     = 1,
  CloseOpen = 2,
}

---Feeds keys to current buffer.
---@param str string Operation as string to feed to buffer.
local function feed_keys(str)
  kutil.feedkeys(str, "in")
end

---Determines whether a character is a numeric/alphabetic/CJK(NAC) character.
---@param char string The character.
---@return boolean result True if the character is a NAC.
local function is_nac(char)
  local nr = vim.fn.char2nr(char)
  return char:match("[%w_]") or (nr >= 0x4E00 and nr <= 0x9FFF)
end

---@class nviq.appl.autopair.PairSpec
---@field left string
---@field right string

---@class nviq.appl.autopair.Pair
---@field private m_left string Left side of the pair.
---@field private m_right string Right side of the pair.
---@field private m_len_left integer Length of the left side.
---@field private m_len_right integer Length of the right side.
local Pair = {}

Pair.__index = Pair

---
---@param spec nviq.appl.autopair.PairSpec
---@return nviq.appl.autopair.Pair
function Pair.new(spec)
  local pair = {
    m_left = spec.left,
    m_right = spec.right,
    m_len_left = sutil.len(spec.left),
    m_len_right = sutil.len(spec.right),
  }
  setmetatable(pair, Pair)
  return pair
end

---
---@return nviq.appl.autopair.Pair
function Pair.unset()
  local pair = {}
  setmetatable(pair, Pair)
  return pair
end

---
---@return boolean
function Pair:is_unset()
  return self.m_left == nil or self.m_right == nil
end

function Pair:left()
  return self.m_left
end

function Pair:right()
  return self.m_right
end

function Pair:len_left()
  return self.m_len_left
end

function Pair:len_right()
  return self.m_len_right
end

function Pair:_open()
  feed_keys(self.m_left .. self.m_right .. string.rep(kutil.dir_key("l"), self.m_len_right))
end

function Pair:_close()
  feed_keys(string.rep(kutil.dir_key("r"), self.m_len_right))
end

function Pair:open()
  if self:is_unset() then
    return false
  end

  local context = lib.get_half_line(1)
  if is_nac(sutil.sub(context.f, 1, 1)) then
    feed_keys(self.m_left)
  else
    self:_open()
  end

  return true
end

function Pair:close()
  if self:is_unset() then
    return false
  end

  local context = lib.get_half_line(1)
  if vim.startswith(context.f, self.m_right) then
    self:_close()
  else
    feed_keys(self.m_right)
  end

  return true
end

function Pair:closeopen()
  if self:is_unset() then
    return false
  end

  local context = lib.get_half_line(0)
  if vim.startswith(context.f, self.m_right) then
    self:_close()
  elseif vim.endswith(context.b, self.m_left)
      or is_nac(sutil.sub(context.b, -1, -1))
      or is_nac(sutil.sub(context.f, 1, 1)) then
    feed_keys(self.m_right)
  else
    self:_open()
  end

  return true
end

---@class nviq.appl.autopair.KeymapSpec
---@field action "open"|"close"|"closeopen"
---@field pair string|table<string, string>

---@class nviq.appl.autopair.Keymap
---@field private m_key string LHS of the key map.
---@field private m_action nviq.appl.autopair.ActionType
---@field private m_pair nviq.appl.autopair.Pair
---@field private m_ft table<string, nviq.appl.autopair.Pair>
local Keymap = {}

Keymap.__index = Keymap

---
---@param key string
---@param spec nviq.appl.autopair.KeymapSpec
---@param pair_table table<string, nviq.appl.autopair.Pair>
---@return nviq.appl.autopair.Keymap
function Keymap.new(key, spec, pair_table)
  local keymap = {
    m_key = key,
    m_ft = {},
  }

  if spec.action == "open" then
    keymap.m_action = ActionType.Open
  elseif spec.action == "close" then
    keymap.m_action = ActionType.Close
  elseif spec.action == "closeopen" then
    keymap.m_action = ActionType.CloseOpen
  else
    error("Invalid action type")
  end

  if type(spec.pair) == "string" then
    local default_pair = pair_table[spec.pair]
    if default_pair then
      keymap.m_pair = default_pair
    else
      keymap.m_pair = Pair.unset()
    end
  elseif type(spec.pair) == "table" then
    keymap.m_pair = Pair.unset()
    for ft, name in pairs(spec.pair --[[@as table<string,string>]]) do
      if ft == "_" then
        local default_pair = pair_table[name]
        if default_pair then
          keymap.m_pair = default_pair
        end
      else
        local pair = pair_table[name]
        if pair then
          keymap.m_ft[ft] = pair
        else
          keymap.m_ft[ft] = Pair.unset()
        end
      end
    end
  else
    error("Invalid pair")
  end

  setmetatable(keymap, Keymap)
  return keymap
end

function Keymap:pair()
  local pair = self.m_ft[vim.bo.filetype]
  if pair then
    return pair
  end
  return self.m_pair
end

function Keymap:action()
  local ok = false
  local pair = self:pair()
  if self.m_action == ActionType.Open then
    ok = pair:open()
  elseif self.m_action == ActionType.Close then
    ok = pair:close()
  elseif self.m_action == ActionType.CloseOpen then
    ok = pair:closeopen()
  end
  if not ok then
    feed_keys(self.m_key)
  end
end

function Keymap:set()
  vim.keymap.set("i", self.m_key, function() self:action() end)
end

---@type table<string, nviq.appl.autopair.Pair>
local _pairs = {}

---@type table<string, nviq.appl.autopair.Keymap>
local _keymaps = {}

---@class nviq.appl.autopair.Context
---@field b string The half line before the cursor (backward);
---@field f string The half line after the cursor  (forward).

---
---@param context nviq.appl.autopair.Context
---@return boolean
local function is_sur(context)
  for _, pair in pairs(_pairs) do
    if not pair:is_unset()
        and vim.endswith(context.b, pair:left())
        and vim.startswith(context.f, pair:right()) then
      return true
    end
  end
  return false
end

---Action on backspace.
---Inside a defined pair (1 character):
---  (|) -> feed <BS> -> |
local function action_backs()
  local context = lib.get_half_line()
  if is_sur(context) then
    feed_keys(kutil.dir_key("r") .. "<BS><BS>")
  else
    feed_keys [[<BS>]]
  end
end

---Action on enter.
---Inside a pair of brackets:
---  {|} -> feed <CR> -> {<br>|<br>}
local function action_enter()
  local context = lib.get_half_line()
  if is_sur(context) then
    feed_keys [[<CR><C-\><C-O>O]]
  else
    feed_keys [[<CR>]]
  end
end

---Super backspace.
---Inside a defined pair (no length limit):
---  <u>|</u> -> feed <M-BS> -> |
---Kill a word:
---  Kill a word| -> feed <M-BS> -> Kill a |
local function action_supbs()
  local context = lib.get_half_line()
  local back = context.b
  local fore = context.f
  local res = { false, 0, 0 }
  for _, pair in pairs(_pairs) do
    if not pair:is_unset()
        and vim.endswith(back, pair:left())
        and vim.startswith(fore, pair:right())
        and pair:len_left() + pair:len_right() > res[2] + res[3] then
      res = { true, pair:len_left(), pair:len_right() }
    end
  end
  if res[1] then
    feed_keys(string.rep(kutil.dir_key("l"), res[2]) .. string.rep("<Del>", res[2] + res[3]))
  elseif back:match("{%s*$") and fore:match("^%s*}") then
    feed_keys [[<C-\><C-O>"_diB]]
  else
    feed_keys [[<C-\><C-O>"_db]]
  end
end

---@class nviq.appl.autopair.Config
---@field pairs table<string, nviq.appl.autopair.PairSpec>
---@field keymaps table<string, nviq.appl.autopair.KeymapSpec>

---Setup autopair.
---@param config nviq.appl.autopair.Config
function M.setup(config)
  for name, spec in pairs(config.pairs) do
    _pairs[name] = Pair.new(spec)
  end

  for key, spec in pairs(config.keymaps) do
    _keymaps[key] = Keymap.new(key, spec, _pairs)
  end

  for _, keymap in pairs(_keymaps) do
    keymap:set()
  end

  vim.keymap.set("i", "<CR>", action_enter)
  vim.keymap.set("i", "<BS>", action_backs)
  vim.keymap.set("i", "<M-BS>", action_supbs)
end

return M
