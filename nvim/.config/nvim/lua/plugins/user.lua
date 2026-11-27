---@type LazySpec
return {
  {
    "CRAG666/code_runner.nvim",
    cmd = { "RunCode", "RunFile", "RunProject", "RunClose" },
    ft = { "java", "python", "dart" },
    opts = {
      mode = "term",
      focus = true,
      startinsert = false,
      term = {
        position = "bot",
        size = 14,
      },
      filetype = {
        java = function()
          local dir = vim.fn.expand "%:p:h"
          local id
          for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, 40, false)) do
            id = line:match "ID:%s*([%w%-]+)"
            if id then break end
          end
          if id and vim.fn.filereadable(dir .. "/problem.md") == 1 then
            local root = dir
            for _ = 1, 12 do
              if vim.fn.filereadable(root .. "/practice.py") == 1 then
                return {
                  "cd $dir &&",
                  "python3 " .. vim.fn.shellescape(root .. "/practice.py") .. " run " .. id,
                }
              end
              local parent = vim.fn.fnamemodify(root, ":h")
              if parent == root then break end
              root = parent
            end
          end
          return { "cd $dir &&", "java $fileName" }
        end,
        python = "python3 -u",
        dart = "dart",
      },
    },
    dependencies = {
      {
        "AstroNvim/astrocore",
        opts = function(_, opts)
          local maps = opts.mappings
          maps.n["<Leader>r"] = { desc = "Run" }
          maps.n["<Leader>rr"] = { "<Cmd>RunCode<CR>", desc = "Run code / DSA tests" }
          maps.n["<Leader>rf"] = { "<Cmd>RunFile<CR>", desc = "Run file" }
          maps.n["<Leader>rp"] = { "<Cmd>RunProject<CR>", desc = "Run project" }
          maps.n["<Leader>rc"] = { "<Cmd>RunClose<CR>", desc = "Close runner" }
        end,
      },
    },
  },
}
