if not vim.g.vscode then return end

local vscode = require("vscode")

-- Options

vim.o.loadplugins = false

vim.cmd.filetype("on")
vim.cmd.filetype("indent", "off")
vim.cmd.filetype("plugin", "off")
vim.cmd.syntax("off")

vim.o.shada = ""
vim.o.colorcolumn = ""
vim.o.cmdheight = 37 -- Stop the output panel from popping up on messages.

vim.g.clipboard = vim.g.vscode_clipboard
vim.notify = vscode.notify

-- Mappings

---
---@param mode "n"|"v"
---@param lhs string Left-hand-side of the mapping.
---@param cmd string VSCode command.
---@param block? boolean Whether to block or not.
local function kbd(mode, lhs, cmd, block)
  local execute = block and vscode.call or vscode.action
  if mode == "n" then
    vim.keymap.set(mode, lhs, function() execute(cmd) end)
  elseif mode == "v" then
    vim.keymap.set(mode, lhs, function()
      require("nviq.util.k").to_normal()
      execute(cmd, {
        range = {
          vim.api.nvim_buf_get_mark(0, "<")[1] - 1,
          vim.api.nvim_buf_get_mark(0, ">")[1] - 1,
        }
      })
    end)
  end
end

-- Buffer
kbd("n", "<leader>bd", "workbench.action.closeActiveEditor")
kbd("n", "<leader>bn", "workbench.action.nextEditor")
kbd("n", "<leader>bp", "workbench.action.previousEditor")
-- Find
kbd("n", "<leader>fa", "workbench.action.gotoSymbol")
kbd("n", "<leader>ff", "workbench.action.quickOpen")
kbd("n", "<leader>fg", "workbench.view.search")
-- Fold
kbd("n", "za", "editor.toggleFold")
kbd("n", "zc", "editor.fold")
kbd("n", "zo", "editor.unfold")
kbd("n", "zC", "editor.foldRecursively")
kbd("n", "zM", "editor.foldAll")
kbd("n", "zO", "editor.unfoldRecursively")
kbd("n", "zR", "editor.unfoldAll")
-- Git
kbd("n", "<leader>gj", "workbench.action.editor.nextChange")
kbd("n", "<leader>gk", "workbench.action.editor.previousChange")
kbd("n", "<leader>gn", "workbench.view.scm")
-- Comment
kbd("n", "<leader>kc", "editor.action.addCommentLine")
kbd("n", "<leader>ku", "editor.action.removeCommentLine")
kbd("v", "<leader>kc", "editor.action.addCommentLine")
kbd("v", "<leader>ku", "editor.action.removeCommentLine")
-- Open
kbd("n", "<leader>op", "workbench.action.toggleSidebarVisibility")
kbd("n", "<leader>on", "workbench.action.terminal.new")
kbd("n", "<leader>ot", "workbench.action.terminal.focus")
kbd("n", "<leader>ou", "editor.action.openLink")
-- LSP
kbd("n", "K", "editor.action.showHover")
kbd("n", "<leader>la", "editor.action.quickFix")
kbd("n", "<leader>ld", "editor.action.goToDeclaration")
kbd("n", "<leader>lf", "editor.action.revealDefinition")
kbd("n", "<leader>li", "editor.action.goToImplementation")
kbd("n", "<leader>lm", "editor.action.formatDocument")
kbd("n", "<leader>ln", "editor.action.rename")
kbd("n", "<leader>lr", "editor.action.goToReferences")
kbd("n", "<leader>l[", "editor.action.marker.prev")
kbd("n", "<leader>l]", "editor.action.marker.next")
-- MISC
kbd("n", "<leader>mv", "outline.focus")
kbd("n", "<leader>pt", "markdown.showPreviewToSide")
