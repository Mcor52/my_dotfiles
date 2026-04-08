local function hl(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

local function apply()
  hl("@string", { fg = "#e78a4e" })
  hl("@string.lua", { fg = "#e78a4e" })
  hl("@string.documentation", { fg = "#d8a567" })
  hl("@string.escape", { fg = "#ea6962" })
  hl("String", { fg = "#e78a4e" })
  hl("TSString", { fg = "#e78a4e" })

  hl("@variable", { fg = "#b16286" })
  hl("@variable.lua", { fg = "#b16286" })
  hl("@lsp.type.variable", { fg = "#b16286" })

  hl("@function", { fg = "#ea6962" })
  hl("@function.call", { fg = "#ea6962" })
  hl("@function.call.lua", { fg = "#ea6962" })

  hl("@variable.member", { fg = "#e67e80" })
  hl("@variable.member.lua", { fg = "#e67e80" })
  hl("@field", { fg = "#e67e80" })

  hl("@property", { fg = "#e67e80" })
  hl("@lsp.type.property", { fg = "#e67e80" })

  hl("@parameter", { fg = "#d8a567" })
  hl("@lsp.type.parameter", { fg = "#d8a567" })

  hl("@keyword", { fg = "#ea6962" })
  hl("@keyword.function", { fg = "#ea6962" })
  hl("@keyword.return", { fg = "#ea6962" })

  hl("@type", { fg = "#d8a567" })
  hl("@type.builtin", { fg = "#d8a567" })

  hl("@number", { fg = "#e78a4e" })
  hl("@boolean", { fg = "#e78a4e" })

  hl("@constant", { fg = "#e67e80" })
  hl("@constant.builtin", { fg = "#e67e80" })
end

return {
  "sainnhe/gruvbox-material",
  priority = 1000,
  config = function()
    vim.g.gruvbox_material_background = "medium"
    vim.g.gruvbox_material_enable_italic = 1

    vim.cmd.colorscheme("gruvbox-material")

    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = function()
        apply()
      end,
    })

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client then
          client.server_capabilities.semanticTokensProvider = nil
        end
        vim.defer_fn(apply, 50)
      end,
    })

    apply()
  end,
}
