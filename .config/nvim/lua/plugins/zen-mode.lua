return {
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    opts = {
      plugins = {
        options = {
          laststatus = 0,
        },
        twilight = {
          enabled = false,
        },
        tmux = true,
        kitty = {
          enabled = false,
          font = "+2",
        },
      },
      on_open = function()
        require("package-info").hide()
      end,
    },
    keys = {
      { "<leader>z", "<cmd>ZenMode<cr>", desc = "Toggle Zen Mode" },
    },
  },
}
