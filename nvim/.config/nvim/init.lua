-- This file simply bootstraps the installation of Lazy.nvim and then calls other files for execution
-- This file doesn't necessarily need to be touched, BE CAUTIOUS editing this file and proceed at your own risk.
local lazypath = vim.env.LAZY or vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not (vim.env.LAZY or (vim.uv or vim.loop).fs_stat(lazypath)) then
  -- stylua: ignore
  local result = vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
  if vim.v.shell_error ~= 0 then
    -- stylua: ignore
    vim.api.nvim_echo({ { ("Error cloning lazy.nvim:\n%s\n"):format(result), "ErrorMsg" }, { "Press any key to exit...", "MoreMsg" } }, true, {})
    vim.fn.getchar()
    vim.cmd.quit()
  end
end

vim.opt.rtp:prepend(lazypath)

-- validate that lazy is available
if not pcall(require, "lazy") then
  -- stylua: ignore
  vim.api.nvim_echo({ { ("Unable to load lazy from: %s\n"):format(lazypath), "ErrorMsg" }, { "Press any key to exit...", "MoreMsg" } }, true, {})
  vim.fn.getchar()
  vim.cmd.quit()
end

require "lazy_setup"
require "polish"
-- Integrates the `recol` CLI with Neovim.
-- Commands: :Recol [args] (-i/--interactive opens a floating terminal),
--           :RecolOpen (shortcut for interactive mode).
-- Config is reloaded automatically after recol runs.
if vim.fn.executable("recol") == 1 then
    local function reload_config()
        local ok, err = pcall(vim.cmd.source, vim.fn.stdpath("config") .. "/init.lua")
        if not ok then
            vim.notify("Recol: config reload failed: " .. tostring(err), vim.log.levels.ERROR)
        end
    end
    local function launch_interactive_mode()
        local width = math.floor(vim.o.columns * 0.75)
        local height = math.floor(vim.o.lines * 0.75)
        local buf = vim.api.nvim_create_buf(false, true)
        local win = vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = width,
            height = height,
            row = math.floor((vim.o.lines - height - 3) / 2),
            col = math.floor((vim.o.columns - width) / 2),
            border = "rounded",
            title = " Recol ",
            title_pos = "center",
        })
        vim.bo[buf].bufhidden = "wipe"
        -- Use --target nvim to apply themes to Neovim only.
        local job_id = vim.fn.termopen({ "recol", "-i", "--quit-on-select" }, {
            on_exit = function(_, code)
                vim.schedule(function()
                    if vim.api.nvim_win_is_valid(win) then
                        vim.api.nvim_win_close(win, true)
                    end
                    if code == 0 then
                        reload_config()
                    end
                end)
            end,
        })
        if job_id <= 0 then
            vim.notify("Recol: failed to start process", vim.log.levels.ERROR)
            vim.api.nvim_win_close(win, true)
            return
        end
        vim.cmd.startinsert()
    end
    vim.api.nvim_create_user_command("Recol", function(opts)
        local args = vim.split(opts.args, "%s+", { trimempty = true })
        if vim.tbl_contains(args, "-i") or vim.tbl_contains(args, "--interactive") then
            return launch_interactive_mode()
        end
        local cmd = vim.list_extend({ "recol" }, args)
        vim.system(cmd, { text = true }, function(res)
            vim.schedule(function()
                if res.code ~= 0 then
                    vim.notify("Recol: exit " .. res.code .. "\n" .. (res.stderr or ""), vim.log.levels.ERROR)
                end
                reload_config()
            end)
        end)
    end, { nargs = "*", desc = "Run recol (-i for interactive mode)" })
    vim.api.nvim_create_user_command("RecolOpen", launch_interactive_mode,
        { nargs = 0, desc = "Open recol interactively" })
end

-- recol:start
-- Citruszest
local function applyRecolTheme()
    vim.cmd("highlight clear")
    if vim.fn.has("syntax_on") then vim.cmd("syntax reset") end
    local P = {
        black   = { "#404040", "#808080" },
        red     = { "#ff7873", "#ff6aa9" },
        green   = { "#00cc7a", "#1affa3" },
        yellow  = { "#e5bd00", "#ffff00" },
        blue    = { "#00bfff", "#33cfff" },
        magenta = { "#ff90fe", "#ffb2fe" },
        cyan    = { "#48d1cc", "#00fff2" },
        white   = { "#bfbfbf", "#f9f9f9" },
        orange  = { "#f49d4e", "#ffbc82" },
        pink    = { "#dd908a", "#dd90ac" },
        bg = { "#070707", "#121212", "#212121", "#323232", "#525252" },
        fg = { "#cecece", "#bfbfbf", "#878787", "#565656" },
        sel = { "#2d2d2d", "#1f1f1f" },
        cur = { "#666666", "#f9f9f9" },
        comment = "#7a7a7a",
        diff = {
            add = "#096f46",
            del = "#894543",
            change = "#096989",
            txt = "#714470",
        }
    }
    for group, opts in pairs({
        Normal             = { bg = P.bg[2], fg = P.fg[2] },
        NormalNC           = "Normal",
        NormalFloat        = { bg = P.bg[1], fg = P.fg[2] },
        FloatBorder        = { bg = P.bg[1], fg = P.fg[4] },
        FloatTitle         = { bg = P.bg[1], fg = P.blue[2], bold = true },
        FloatFooter        = { bg = P.bg[1], fg = P.fg[4] },
        FloatShadow        = { bg = P.black[1], blend = 80 },
        FloatShadowThrough = { bg = P.black[1], blend = 100 },
        Directory          = { fg = P.blue[1] },
        EndOfBuffer        = { fg = P.bg[2] },
        NonText            = { fg = P.comment },

        Cursor        = { bg = P.cur[1], fg = P.cur[2] },
        lCursor       = { bg = P.cyan[1], fg = P.cur[2] },
        CursorIM      = { bg = P.magenta[1], fg = P.cur[2] },
        TermCursor    = { bg = P.cur[1], fg = P.cur[2] },
        CursorLine    = { bg = P.bg[3] },
        CursorColumn  = "CursorColumn",
        Visual        = { bg = P.sel[1] },
        VisualNOS     = { bg = P.sel[2] },
        MatchParen    = { fg = P.orange[1], bg = P.bg[4], bold = true },
        MCursor       = { bg = P.pink[1], fg = P.cur[2] },
        MCursorVisual = { bg = P.sel[2] },

        LineNr         = { fg = P.fg[4] },
        LineNrAbove    = "LineNr",
        LineNrBelow    = "LineNr",
        CursorLineNr   = { fg = P.cur[1], bg = P.bg[3], bold = true },
        SignColumn     = { bg = P.bg[2], fg = P.fg[4] },
        FoldColumn     = { bg = P.bg[2], fg = P.fg[4] },
        CursorLineSign = { bg = P.bg[3] },
        CursorLineFold = { bg = P.bg[3], fg = P.fg[3] },

        WinSeparator = { fg = P.bg[5] },
        WinBar       = { fg = P.fg[2], bg = P.bg[2] },
        WinBarNC     = { fg = P.fg[4], bg = P.bg[1] },
        TabLine      = { fg = P.fg[3], bg = P.bg[3] },
        TabLineSel   = { fg = P.cur[1], bg = P.bg[2], bold = true },
        TabLineFill  = { bg = P.bg[1] },

        Search     = { bg = P.diff.txt, fg = P.fg[1] },
        CurSearch  = { bg = P.yellow[1], fg = P.cur[2], bold = true },
        IncSearch  = { bg = P.orange[1], fg = P.cur[2], bold = true },
        Substitute = { bg = P.red[1], fg = P.fg[1], bold = true },

        Pmenu                = { bg = P.bg[3], fg = P.fg[2] },
        PmenuSel             = { bg = P.bg[5], fg = P.fg[1], bold = true },
        PmenuMatch           = { fg = P.blue[2], bold = true },
        PmenuMatchSel        = { fg = P.yellow[2], bold = true },
        PmenuKind            = { fg = P.magenta[1] },
        PmenuKindSel         = { fg = P.magenta[2], bold = true },
        PmenuExtra           = { fg = P.fg[4] },
        PmenuExtraSel        = { fg = P.fg[3] },
        PmenuBorder          = { bg = P.bg[3], fg = P.fg[4] },
        PmenuSbar            = { bg = P.bg[4] },
        PmenuThumb           = { bg = P.fg[4] },
        PmenuShadow          = { bg = P.black[1], blend = 80 },
        PmenuShadowThrough   = { bg = P.black[1], blend = 100 },
        ComplMatchIns        = { fg = P.fg[3] },
        PreInsert            = { fg = P.fg[3], bg = P.bg[4] },
        ComplHint            = { fg = P.comment, italic = true },
        ComplHintMore        = { fg = P.fg[4], italic = true },
        WildMenu             = { bg = P.bg[5], fg = P.fg[1], bold = true },
        SnippetTabstop       = { bg = P.bg[4] },
        SnippetTabstopActive = { bg = P.diff.change, fg = P.fg[1] },

        SpellBad   = { undercurl = true, sp = P.red[1] },
        SpellCap   = { undercurl = true, sp = P.yellow[1] },
        SpellLocal = { underdotted = true, sp = P.cyan[1] },
        SpellRare  = { underdotted = true, sp = P.magenta[1] },

        MsgArea      = { bg = P.bg[2], fg = P.fg[2] },
        MsgSeparator = { bg = P.bg[3], fg = P.bg[5] },
        OkMsg        = { fg = P.green[1] },
        Question     = { fg = P.blue[1], bold = true },
        MoreMsg      = { fg = P.cyan[1], bold = true },
        ModeMsg      = { fg = P.yellow[1], bold = true },
        WarningMsg   = { fg = P.yellow[1] },
        ErrorMsg     = { fg = P.red[1], bold = true },
        StdoutMsg    = { fg = P.fg[2] },
        StderrMsg    = { fg = P.red[2] },

        DiffAdd     = { bg = P.diff.add },
        DiffChange  = { bg = P.diff.change },
        DiffDelete  = { bg = P.diff.del },
        DiffText    = { bg = P.diff.txt, bold = true },
        DiffTextAdd = { bg = P.diff.add, bold = true },

        Folded       = { bg = P.bg[3], fg = P.fg[3], italic = true },
        QuickFixLine = { bg = P.sel[2], fg = P.yellow[2], bold = true },

        StatusLine       = { bg = P.bg[3], fg = P.fg[2] },
        StatusLineNC     = { bg = P.bg[1], fg = P.fg[4] },
        StatusLineTerm   = { bg = P.bg[3], fg = P.green[1] },
        StatusLineTermNC = { bg = P.bg[1], fg = P.fg[4] },
        StatusLineRemote = { bg = P.bg[3], fg = P.orange[1], bold = true },
        Title            = { fg = P.blue[1], bold = true },

        Menu      = { bg = P.bg[3], fg = P.fg[2] },
        Scrollbar = { bg = P.bg[3], fg = P.fg[4] },
        Tooltip   = { bg = P.bg[3], fg = P.fg[2] },

        ColorColumn = { bg = P.bg[3] },
        SpecialKey  = { fg = P.cyan[1] },
        Whitespace  = { fg = P.bg[5] },

        Comment        = { fg = P.comment },
        SpecialComment = { fg = P.cyan[2] },
        Constant       = { fg = P.orange[1] },
        String         = { fg = P.green[1] },
        Character      = { fg = P.green[2] },
        Number         = "Constant",
        Float          = "Constant",
        Boolean        = "Constant",
        Regexp         = { fg = P.cyan[2] },
        Identifier     = { fg = P.fg[2] },
        Function       = { fg = P.blue[1] },
        Statement      = { fg = P.magenta[1] },
        Conditional    = { fg = P.magenta[1] },
        Repeat         = { fg = P.magenta[1] },
        Label          = { fg = P.magenta[2] },
        Keyword        = { fg = P.magenta[1] },
        Exception      = { fg = P.pink[1] },
        Operator       = { fg = P.fg[3] },
        PreProc        = { fg = P.pink[1] },
        Include        = { fg = P.red[1] },
        Define         = { fg = P.pink[1] },
        Macro          = { fg = P.pink[2] },
        PreCondit      = { fg = P.pink[1] },
        Type           = { fg = P.yellow[1] },
        StorageClass   = { fg = P.magenta[2] },
        Structure      = { fg = P.yellow[1] },
        Typedef        = { fg = P.yellow[1] },
        Special        = { fg = P.cyan[1] },
        SpecialChar    = { fg = P.yellow[2], bold = true },
        Tag            = { fg = P.blue[2] },
        Delimiter      = { fg = P.fg[3] },
        Debug          = { fg = P.orange[1] },
        Underlined     = { fg = P.blue[1], underline = true },
        Bold           = { bold = true },
        Italic         = { italic = true },
        BoldItalic     = { bold = true, italic = true },
        Dimmed         = { fg = P.fg[4] },
        Ignore         = { fg = P.bg[2] },
        Error          = { fg = P.red[1] },
        Todo           = { bg = P.yellow[1], fg = P.black[1], bold = true },
        Added          = { fg = P.green[1] },
        Changed        = { fg = P.blue[1] },
        Removed        = { fg = P.red[1] },

        healthError   = { fg = P.red[1] },
        healthSuccess = { fg = P.green[1] },
        healthWarning = { fg = P.yellow[1] },

        DiagnosticError = { fg = P.red[1] },
        DiagnosticWarn  = { fg = P.yellow[1] },
        DiagnosticInfo  = { fg = P.blue[1] },
        DiagnosticHint  = { fg = P.cyan[1] },
        DiagnosticOk    = { fg = P.green[1] },

        ["@variable"]                   = { fg = P.fg[2] },
        ["@variable.builtin"]           = { fg = P.red[1] },
        ["@variable.parameter"]         = { fg = P.fg[2] },
        ["@variable.parameter.builtin"] = { fg = P.red[1] },
        ["@variable.member"]            = { fg = P.blue[2] },
        ["@constant"]                   = "Constant",
        ["@constant.builtin"]           = "Constant",
        ["@constant.macro"]             = { fg = P.pink[2] },
        ["@module"]                     = { fg = P.cyan[2] },
        ["@module.builtin"]             = { fg = P.cyan[1] },
        ["@label"]                      = { fg = P.magenta[2] },
        ["@string"]                     = { fg = P.green[1] },
        ["@string.documentation"]       = { fg = P.green[2] },
        ["@string.regexp"]              = "Regexp",
        ["@string.escape"]              = "SpecialChar",
        ["@string.special"]             = "Special",
        ["@string.special.symbol"]      = { fg = P.magenta[1] },
        ["@string.special.url"]         = { fg = P.blue[1], underline = true },
        ["@string.special.path"]        = { fg = P.blue[2] },
        ["@character.special"]          = { fg = P.cyan[2] },
        ["@character"]                  = "Character",
        ["@boolean"]                    = "Boolean",
        ["@number"]                     = "Number",
        ["@number.float"]               = "Float",
        ["@type"]                       = "Type",
        ["@type.builtin"]               = { fg = P.cyan[2] },
        ["@type.definition"]            = "Typedef",
        ["@attribute"]                  = { fg = P.pink[2] },
        ["@attribute.builtin"]          = { fg = P.pink[1] },
        ["@property"]                   = { fg = P.blue[2] },
        ["@function"]                   = "Function",
        ["@function.builtin"]           = { fg = P.red[1] },
        ["@function.call"]              = "Function",
        ["@function.macro"]             = { fg = P.red[1] },
        ["@function.method"]            = "Function",
        ["@function.method.call"]       = "Function",
        ["@constructor"]                = { fg = P.cyan[1] },
        ["@operator"]                   = "Operator",

        ["@keyword"]                     = "Keyword",
        ["@keyword.coroutine"]           = "Keyword",
        ["@keyword.function"]            = "Keyword",
        ["@keyword.operator"]            = "Operator",
        ["@keyword.import"]              = "Include",
        ["@keyword.type"]                = "Keyword",
        ["@keyword.modifier"]            = "Keyword",
        ["@keyword.repeat"]              = "Repeat",
        ["@keyword.return"]              = { fg = P.red[1] },
        ["@keyword.debug"]               = "Debug",
        ["@keyword.exception"]           = "Exception",
        ["@keyword.conditional"]         = "Conditional",
        ["@keyword.conditional.ternary"] = { fg = P.cyan[1] },
        ["@keyword.directive"]           = "PreProc",
        ["@keyword.directive.define"]    = "Define",

        ["@punctuation.delimiter"] = "Delimiter",
        ["@punctuation.bracket"]   = { fg = P.fg[3] },
        ["@punctuation.special"]   = { fg = P.cyan[2] },

        ["@comment"]               = "Comment",
        ["@comment.documentation"] = { fg = P.comment },
        ["@comment.error"]         = { bg = P.red[1], fg = P.black[1], bold = true },
        ["@comment.warning"]       = { bg = P.yellow[1], fg = P.black[1], bold = true },
        ["@comment.todo"]          = "Todo",
        ["@comment.note"]          = { bg = P.blue[1], fg = P.black[1], bold = true },

        ["@markup.strong"]         = { fg = P.red[1], bold = true },
        ["@markup.italic"]         = { italic = true },
        ["@markup.strikethrough"]  = { strikethrough = true },
        ["@markup.underline"]      = { underline = true },
        ["@markup.heading"]        = { fg = P.blue[1], bold = true },
        ["@markup.quote"]          = { fg = P.fg[3] },
        ["@markup.math"]           = { fg = P.cyan[2] },
        ["@markup.link"]           = { fg = P.magenta[1] },
        ["@markup.link.label"]     = { fg = P.blue[2] },
        ["@markup.link.url"]       = { fg = P.magenta[2], underline = true },
        ["@markup.raw"]            = { fg = P.green[2], bg = P.bg[3] },
        ["@markup.raw.block"]      = { fg = P.fg[2] },
        ["@markup.list"]           = { fg = P.cyan[2] },
        ["@markup.list.checked"]   = { fg = P.green[1] },
        ["@markup.list.unchecked"] = { fg = P.fg[4] },

        ["@diff.plus"]     = { fg = P.green[1] },
        ["@diff.minus"]    = { fg = P.red[1] },
        ["@diff.delta"]    = { fg = P.blue[1] },
        ["@tag"]           = { fg = P.red[1] },
        ["@tag.builtin"]   = { fg = P.red[1] },
        ["@tag.attribute"] = { fg = P.orange[2] },
        ["@tag.delimiter"] = { fg = P.fg[3] },

        ["@constructor.lua"]      = { fg = P.fg[3] },
        ["@field.rust"]           = { fg = P.fg[3] },
        ["@label.json"]           = "@property",
        ["@variable.member.yaml"] = "@property",

        ["@lsp.type.comment"]      = {},
        ["@lsp.type.keyword"]      = {},
        ["@lsp.type.modifier"]     = {},
        ["@lsp.type.number"]       = {},
        ["@lsp.type.operator"]     = {},
        ["@lsp.type.regexp"]       = {},
        ["@lsp.type.string"]       = {},
        ["@lsp.type.variable"]     = {},
        ["@lsp.type.namespace.go"] = {},

        ["@lsp.type.interface"]                  = { fg = P.red[1] },
        ["@lsp.type.boolean"]                    = "@boolean",
        ["@lsp.type.builtinConstant"]            = "@constant.builtin",
        ["@lsp.type.generic"]                    = "@type",
        ["@lsp.type.builtinType"]                = "@type.builtin",
        ["@lsp.type.enum"]                       = "@type",
        ["@lsp.type.enumMember"]                 = "@constant",
        ["@lsp.type.escapeSequence"]             = "@string.escape",
        ["@lsp.type.formatSpecifier"]            = "@punctuation.special",
        ["@lsp.type.namespace"]                  = "@module",
        ["@lsp.type.parameter"]                  = "@parameter",
        ["@lsp.type.property"]                   = "@property",
        ["@lsp.type.selfKeyword"]                = "@variable.builtin",
        ["@lsp.type.typeAlias"]                  = "@type.definition",
        ["@lsp.type.unresolvedReference"]        = "@error",
        ["@lsp.typemod.function.defaultLibrary"] = "@function.builtin",
        ["@lsp.typemod.function.builtin"]        = "@function.builtin",

        ["@lsp.type.selfParameter.python"] = "@variable.builtin",
        ["@lsp.type.clsParameter.python"]  = "@variable.builtin",

        ["@lsp.type.table.toml"]          = "@property",
        ["@lsp.type.key.toml"]            = "@property",
        ["@lsp.type.boolean.toml"]        = "Boolean",
        ["@lsp.type.offsetDateTime.toml"] = "Special",
        ["@lsp.type.localDateTime.toml"]  = "Special",
        ["@lsp.type.localDate.toml"]      = "Special",
        ["@lsp.type.localTime.toml"]      = "Special",
    }) do
        if type(opts) == "string" then
            opts = { link = opts }
        end
        vim.api.nvim_set_hl(0, group, opts)
    end
end
applyRecolTheme()
-- recol:end
