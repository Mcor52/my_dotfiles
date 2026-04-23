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
-- This is also a good place to setup other settings (vim.opt) vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
  spec = {

    {'brenoprata10/nvim-highlight-colors',
        config = function()
        vim.opt.termguicolors = true
        require('nvim-highlight-colors').setup({
            render = 'background',
            enable_hex = true,
            enable_short_hex = true,
            enable_rgb = true,
            enable_named_colors = true,
        })
        end
    },

    {"monkoose/neocodeium",
    event = "VeryLazy",
    config = function()
        local neocodeium = require("neocodeium")
        neocodeium.setup()
        vim.keymap.set("i", "<A-f>", neocodeium.accept)
    end,
    },

    {'nvim-treesitter/nvim-treesitter',
  	lazy = false,
  	build = ':TSUpdate'
    },

    { "catppuccin/nvim", name = "catppuccin", priority = 1000 
    },
    
    {'f4z3r/gruvbox-material.nvim',
        name = 'gruvbox-material',
        lazy = false,
        priority = 1000,
        opts = {
            italics = true,
            comments = {
                italics = true,
            },
            contrast = "soft",
            background = {
                transparent = true
            },
        },
    },

    {'windwp/nvim-autopairs',
    	event = "InsertEnter",
    	config = true
    },

    {"jay-babu/mason-nvim-dap.nvim",
    	dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
    	config = function()
    	require("mason-nvim-dap").setup({
        ensure_installed = { "python", "codelldb", "js" }, -- pick what you need
        automatic_installation = true,
    	})
  	end,
    },

    {"mfussenegger/nvim-dap",
    	dependencies = {
        	"rcarriga/nvim-dap-ui",
        	"theHamsta/nvim-dap-virtual-text",
        	"nvim-neotest/nvim-nio", -- required by dap-ui
    },
    	config = function()
    	local dap = require("dap")
    	local dapui = require("dapui")

    	-- UI setup
    	dapui.setup()
    	require("nvim-dap-virtual-text").setup()

        -- Auto open/close UI (feels like VS Code)
    	dap.listeners.after.event_initialized["dapui_config"] = function()
      		dapui.open()
    	end
    	dap.listeners.before.event_terminated["dapui_config"] = function()
      		dapui.close()
    	end
    	dap.listeners.before.event_exited["dapui_config"] = function()
      		dapui.close()
    	end

    	vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint)
    	vim.keymap.set("n", "<leader>dc", dap.continue)
    	vim.keymap.set("n", "<leader>do", dap.step_over)
    	vim.keymap.set("n", "<leader>di", dap.step_into)
    	vim.keymap.set("n", "<leader>dO", dap.step_out)
    	vim.keymap.set("n", "<leader>dr", dap.repl.open)
    	end,
    },

    { "nvim-tree/nvim-web-devicons",
    	opts = {}
    },

    {'MeanderingProgrammer/render-markdown.nvim',
    	dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
	---@module 'render-markdown'
    	---@type render.md.UserConfig
    	opts = {},
    },
    {"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {},
  	config = function(_, opts) require("which-key").setup(opts) end,
  	keys = {
    {
	"<leader>?",
      	function()
            require("which-key").show({ global = false })
      	end,
      desc = "Buffer Local Keymaps (which-key)",
    },
  },
    {"max397574/better-escape.nvim",
        config = function()
        require("better_escape").setup()
    end,
    },
}

},
  install = { colorscheme = { "habamax" } },
  checker = { enabled = true },
})

-- Make tab do 4 spaces instead of 7/8
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true

-- When in insert mode, check if I have a neocodeium suggestion and if so, press tab to accept, but if not, tab indents 4 spaces as per above
vim.keymap.set('i', '<Tab>', function()
  local neocodeium = require('neocodeium')
  if neocodeium.visible() then
    neocodeium.accept()
  else
    vim.api.nvim_feedkeys(
      vim.api.nvim_replace_termcodes('<Tab>', true, false, true),
      'n',
      false
    )
  end
end, { silent = true })

-- Show number lines and color them
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.cursorline = true
vim.cmd([[highlight CursorLineNr guifg=#e78a4e gui=bold]])
vim.cmd([[highlight LineNr guifg=#555555 gui=NONE]])

-- Bring in the theme file I symlinked from my dark/light scripts to set as my theme
require("themes.current")
