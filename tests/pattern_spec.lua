local project = require("project_nvim.project")
local project_nvim = require("project_nvim")

---@module 'plenary.busted'
describe("pattern_spec", function()
  it("Find project root with default patterns", function()
    project_nvim.setup()

    vim.cmd.edit("./tests/scratch/src/app/init.lua")
    local root = project.find_pattern_root()
    local expected = vim.fn.expand("%:p:h:h:h:h:h")
    assert.equals(expected, root)
  end)
  it("Find project root, stop on root directory", function()
    project_nvim.setup({ patterns = {} })

    vim.cmd.edit("./tests/scratch/src/app/init.lua")
    local root = project.find_pattern_root()
    assert.is_nil(root)
  end)
  it("Pattern = should match", function()
    project_nvim.setup({ patterns = { "=src" } })

    vim.cmd.edit("./tests/scratch/src/app/init.lua")
    local root = project.find_pattern_root()
    local expected = vim.fn.expand("%:p:h:h")
    assert.equals(expected, root)
  end)
  it("Pattern ^ should match", function()
    project_nvim.setup({ patterns = { "^scratch" } })

    vim.cmd.edit("./tests/scratch/src/app/init.lua")
    local root = project.find_pattern_root()
    local expected = vim.fn.expand("%:p:h")
    assert.equals(expected, root)
  end)
  it("Pattern > should match", function()
    project_nvim.setup({ patterns = { ">src" } })

    vim.cmd.edit("./tests/scratch/src/app/init.lua")
    local root = project.find_pattern_root()
    local expected = vim.fn.expand("%:p:h")
    assert.equals(expected, root)
  end)
  it("Pattern ! should match", function()
    project_nvim.setup({ patterns = { "!src", ">scratch" } })

    vim.cmd.edit("./tests/scratch/tests/app/init.lua")
    local root = project.find_pattern_root()
    local expected = vim.fn.expand("%:p:h:h")
    assert.equals(expected, root)
  end)
  it("Pattern ! should not match", function()
    project_nvim.setup({ patterns = { "!=src", ">scratch" } })

    vim.cmd.edit("./tests/scratch/src/app/init.lua")
    local root = project.find_pattern_root()
    assert.is_nil(root)
  end)
end)
