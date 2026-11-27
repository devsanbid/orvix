-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!
-- Configuration documentation can be found with `:h astrocore`

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    features = {
      large_buf = { size = 1024 * 256, lines = 10000 },
      autopairs = true,
      cmp = true,
      diagnostics = { virtual_text = false, virtual_lines = false },
      highlighturl = true,
      notifications = true,
    },
    diagnostics = {
      virtual_text = false,
      underline = true,
    },
    options = {
      opt = {
        relativenumber = false,
        number = true,
        spell = false,
        signcolumn = "no",
        wrap = false,
        scrolloff = 999,
        guicursor = "a:block",
        mouse = ""
      },
      g = {},
    },
    autocmds = {
      no_auto_comment = {
        {
          event = { "FileType", "BufEnter" },
          desc = "Disable auto comment on o/O",
          callback = function() vim.opt_local.formatoptions:remove "o" end,
        },
      },
    },
    mappings = {
      n = {
        -- disable Find lines
        ["<Leader>fl"] = false,

        -- buffer navigation
        L = { function() require("astrocore.buffer").nav(vim.v.count1) end, desc = "Next buffer" },
        H = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },

        -- move 5 lines
        ["<M-J>"] = { "5j", desc = "Move down 5 lines" },
        ["<M-K>"] = { "5k", desc = "Move up 5 lines" },

        -- window navigation (handles NeoTree + regular splits)
        ["<C-H>"] = {
          function()
            if vim.bo.filetype == "neo-tree" then return end
            local wins = vim.api.nvim_tabpage_list_wins(0)
            for _, w in ipairs(wins) do
              if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "neo-tree" then
                vim.api.nvim_set_current_win(w)
                return
              end
            end
            vim.cmd "wincmd h"
          end,
          desc = "Move to left window (NeoTree-aware)",
        },
        ["<C-L>"] = {
          function()
            if vim.bo.filetype == "neo-tree" then
              local wins = vim.api.nvim_tabpage_list_wins(0)
              for _, w in ipairs(wins) do
                if vim.bo[vim.api.nvim_win_get_buf(w)].filetype ~= "neo-tree" then
                  vim.api.nvim_set_current_win(w)
                  return
                end
              end
            end
            vim.cmd "wincmd l"
          end,
          desc = "Move to right window (NeoTree-aware)",
        },
        ["<C-J>"] = {
          function()
            if vim.bo.filetype == "neo-tree" then
              local wins = vim.api.nvim_tabpage_list_wins(0)
              for _, w in ipairs(wins) do
                if vim.bo[vim.api.nvim_win_get_buf(w)].filetype ~= "neo-tree" then
                  vim.api.nvim_set_current_win(w)
                  return
                end
              end
            end
            vim.cmd "wincmd j"
          end,
          desc = "Move to below window (NeoTree-aware)",
        },
        ["<C-K>"] = {
          function()
            if vim.bo.filetype == "neo-tree" then
              local wins = vim.api.nvim_tabpage_list_wins(0)
              for _, w in ipairs(wins) do
                if vim.bo[vim.api.nvim_win_get_buf(w)].filetype ~= "neo-tree" then
                  vim.api.nvim_set_current_win(w)
                  return
                end
              end
            end
            vim.cmd "wincmd k"
          end,
          desc = "Move to above window (NeoTree-aware)",
        },
      },
      v = {
        ["<M-J>"] = { "5j", desc = "Move down 5 lines" },
        ["<M-K>"] = { "5k", desc = "Move up 5 lines" },
      },
    },
  },
}
