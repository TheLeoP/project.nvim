local group = vim.api.nvim_create_augroup("project_nvim", { clear = true })

vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter" }, {
  group = group,
  pattern = "*",
  callback = function()
    if require("project_nvim.config").options.manual_mode then return end
    require("project_nvim.project").on_buf_enter()
  end,
  desc = "Change cwd to project root using patterns",
})

vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  pattern = "*",
  callback = function()
    if not vim.list_contains(require("project_nvim.config").options.detection_methods, "lsp") then return end
    require("project_nvim.project").on_buf_enter()
  end,
  desc = "Change cwd to project root using LSP",
})

vim.api.nvim_create_user_command("ProjectRoot", function() require("project_nvim.project").on_buf_enter() end, {})

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  pattern = "*",
  callback = require("project_nvim.utils.history").write_projects_to_history,
  desc = "Write project.nvim history to file before closing Neovim",
})

coroutine.wrap(function()
  require("project_nvim.utils.history").read_projects_from_history()
  require("project_nvim.utils.history").start_history_watcher()
end)()
