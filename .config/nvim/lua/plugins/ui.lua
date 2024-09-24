return {
  {
    "folke/noice.nvim",
    enabled = false,
  },

  {
    "j-hui/fidget.nvim",
    opts = {
      notification = {
        window = {
          winblend = 0,
          border = "rounded",
        },
      },
    },
  },
  {
    "rcarriga/nvim-notify",
    opts = {
      timeout = 500,
      render = "compact",
      max_height = function()
        return math.floor(vim.o.lines * 0.75)
      end,
      max_width = function()
        return math.floor(vim.o.columns * 0.25)
      end,
      on_open = function(win)
        vim.api.nvim_win_set_config(win, { zindex = 100 })
      end,
    },
  },

  -- show filename in top-right
  {
    "b0o/incline.nvim",
    dependencies = { "catppuccin/nvim" },
    event = "BufReadPre",
    priority = 1200,
    config = function()
      local colors = require("catppuccin.palettes").get_palette("mocha")
      require("incline").setup({
        highlight = {
          groups = {
            InclineNormal = { guibg = colors.surface0, guifg = colors.text },
            InclineNormalNC = { guibg = colors.base, guifg = colors.overlay0 },
          },
        },
        window = { margin = { vertical = 0, horizontal = 1 } },
        hide = { cursorline = true },
        render = function(props)
          local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
          if vim.bo[props.buf].modified then
            filename = "[*]" .. filename
          end

          local icon, color = require("nvim-web-devicons").get_icon_color(filename)

          return { { icon, guifg = color }, { " " }, { filename } }
        end,
      })
    end,
  },

  -- bufferline
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        mode = "tabs",
        show_buffer_close_icons = false,
        show_close_icon = false,
      },
    },
  },

  -- dim inactive split panes
  {
    "levouh/tint.nvim",
    event = "VeryLazy",
    config = function()
      local tint = require("tint")
      local transforms = require("tint.transforms")
      tint.setup({
        transforms = {
          transforms.tint_with_threshold(-10, "#1a1a1a", 7),
          transforms.saturate(0.65),
        },
        tint_background_colors = true,
        highlight_ignore_patterns = {
          "SignColumn",
          "LineNr",
          "CursorLine",
          "WinSeparator",
          "VertSplit",
          "StatusLineNC",
        },
      })
      vim.api.nvim_create_autocmd("FocusGained", {
        callback = function()
          tint.untint(vim.api.nvim_get_current_win())
        end,
      })
      vim.api.nvim_create_autocmd("FocusLost", {
        callback = function()
          tint.tint(vim.api.nvim_get_current_win())
        end,
      })
    end,
  },
}
