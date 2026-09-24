local group = vim.api.nvim_create_augroup("project.nvim", { clear = true })

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  pattern = "*",
  callback = function() require("project").write():wait() end,
  desc = "Write project.nvim history to file before closing Neovim",
})

require("project").read_history()
require("project").start_history_watcher()
