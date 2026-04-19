vim.api.nvim_create_user_command("Time", function(_)
  vim.notify(vim.fn.strftime("%Y-%m-%d %a %T"))
end, { desc = "Time..." })
