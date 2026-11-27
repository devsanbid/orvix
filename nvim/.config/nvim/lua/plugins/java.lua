---@type LazySpec
return {
  {
    "mfussenegger/nvim-jdtls",
    opts = function(_, opts)
      -- Pack computes root once and only looks for .git/mvnw/gradlew.
      -- Keep a fallback so its FileType check does not abort before our config runs.
      opts.root_dir = opts.root_dir or vim.fn.getcwd()

      -- AstroCommunity pack starts jdtls with -Xms1g and no -Xmx. On JDK 17+
      -- the default max heap is ~25% of RAM, so each instance can grow to
      -- several GB. Cap it; one LSP for DSA files does not need more.
      if type(opts.cmd) == "table" then
        local cmd = {}
        local inserted_heap = false
        for _, arg in ipairs(opts.cmd) do
          if type(arg) == "string" and arg:match "^%-Xms" then
            vim.list_extend(cmd, { "-Xms128m", "-Xmx1g", "-XX:+UseG1GC", "-XX:+UseStringDeduplication" })
            inserted_heap = true
          elseif type(arg) == "string" and (arg:match "^%-Xmx" or arg == "-XX:+UseG1GC" or arg == "-XX:+UseStringDeduplication") then
            -- skip, already handled with -Xms
          elseif arg == "-Dlog.level=ALL" then
            table.insert(cmd, "-Dlog.level=WARN")
          else
            table.insert(cmd, arg)
          end
        end
        if not inserted_heap then
          vim.list_extend(cmd, { "-Xms128m", "-Xmx1g", "-XX:+UseG1GC", "-XX:+UseStringDeduplication" })
        end
        opts.cmd = cmd
      end

      opts.settings = opts.settings or {}
      opts.settings.java = vim.tbl_deep_extend("force", opts.settings.java or {}, {
        eclipse = { downloadSources = false },
        maven = { downloadSources = false },
        implementationsCodeLens = { enabled = false },
        referencesCodeLens = { enabled = false },
        inlayHints = { parameterNames = { enabled = "none" } },
      })

      return opts
    end,
    config = function(_, opts)
      local markers = {
        -- multi-module
        "mvnw",
        "gradlew",
        "settings.gradle",
        "settings.gradle.kts",
        -- single-module
        "pom.xml",
        "build.gradle",
        "build.gradle.kts",
        "build.xml",
        ".git",
      }

      local function java_root(bufnr)
        local fname = vim.api.nvim_buf_get_name(bufnr)
        if fname == "" then return vim.fn.getcwd() end
        -- Prefer Maven/Gradle/git. For loose files (DSA folders with no
        -- marker), share one jdtls per nvim working directory instead of
        -- spawning a new JVM for every exercise folder.
        return vim.fs.root(fname, markers) or vim.fn.getcwd()
      end

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "java",
        desc = "Start jdtls for Java buffers",
        callback = function(args)
          local root = java_root(args.buf)
          if not root or root == "" then
            require("astrocore").notify("jdtls: root_dir not found. Please specify a root marker", vim.log.levels.ERROR)
            return
          end

          local project_name = vim.fn.fnamemodify(root, ":p:h:t")
          local workspace_dir = vim.fn.stdpath "data" .. "/site/java/workspace-root/" .. project_name
          vim.fn.mkdir(workspace_dir, "p")

          local config = vim.deepcopy(opts)
          config.root_dir = root
          if type(config.cmd) == "table" then
            for i, arg in ipairs(config.cmd) do
              if arg == "-data" then
                config.cmd[i + 1] = workspace_dir
                break
              end
            end
          end

          require("jdtls").start_or_attach(config)
        end,
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        pattern = "*.java",
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == "jdtls" then require("jdtls.dap").setup_dap_main_class_configs() end
        end,
      })
    end,
  },
}
