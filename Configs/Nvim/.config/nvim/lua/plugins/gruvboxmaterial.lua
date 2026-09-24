return {
  {
    "sainnhe/gruvbox-material",
    lazy = false,
    priority = 1000,
    config = function()
      -- Optional setup options before loading:
      -- vim.g.gruvbox_material_background = "hard" -- "hard", "medium", or "soft"
      -- vim.g.gruvbox_material_foreground = "material" -- "material", "mix", or "original"
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox-material",
    },
  },
}
