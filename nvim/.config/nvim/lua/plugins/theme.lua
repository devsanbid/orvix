-- ============================================================================
-- THEME
-- ============================================================================
-- The "orvix" colorscheme (colors/orvix.lua, lua/orvix/) follows the shell
-- theme: the shell writes its palette to ~/.cache/orvix/nvim.json and runs
-- `:colorscheme orvix` in every open instance when the theme changes.

return {
    {
        dir = vim.fn.stdpath("config"),
        name = "orvix-theme",
        lazy = false,
        priority = 1000,
        config = function()
            vim.cmd.colorscheme("orvix")
        end,
    },
}
