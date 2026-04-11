-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    'brenoprata10/nvim-highlight-colors',
    {'f4z3r/gruvbox-material.nvim',
        name = 'gruvbox-material',
        lazy = false,
        priority = 1000,
        opts = {
        -- my custom gruvbox-material reddish palette
            palette_overrides = {
            blue   = '#e67e80', -- your pink
            aqua   = '#e78a4e', -- orange
            purple = '#b16286',
            red    = '#ea6962',
            yellow = '#d8a567',
            },
	},
     },
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
  checker = { enabled = true },
})

-- Make tab do 4 spaces instead of 7/8
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true

-- Show number lines color them
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.cursorline = true
vim.cmd([[highlight CursorLineNr guifg=#e78a4e gui=bold]])
vim.cmd([[highlight LineNr guifg=#555555 gui=NONE]])
