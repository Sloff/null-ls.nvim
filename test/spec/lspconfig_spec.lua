local stub = require("luassert.stub")

local methods = require("null-ls.methods")
local sources = require("null-ls.sources")
local c = require("null-ls.config")
local u = require("null-ls.utils")

local tu = require("test.utils")

describe("lspconfig", function()
    local lspconfig = require("null-ls.lspconfig")

    after_each(function()
        c.reset()
        sources.reset()
        tu.wipeout()
    end)

    -- this has side effects so we can only do it once
    lspconfig.setup()

    describe("setup", function()
        it("should set up default config", function()
            local null_ls_config = require("lspconfig.configs")["null-ls"]
            assert.truthy(null_ls_config)

            local default_config = null_ls_config.document_config.default_config
            assert.equals(default_config.name, "null-ls")
            assert.equals(default_config.autostart, false)
            assert.same(default_config.cmd, { "nvim" })
            assert.same(default_config.flags, { debounce_text_changes = c.get().debounce })
            assert.same(default_config.filetypes, {})
            assert.truthy(type(default_config.root_dir) == "function")
        end)

        describe("root_dir", function()
            it("should return root dir", function()
                local cwd = vim.fn.getcwd()

                local root_dir = require("lspconfig.configs")["null-ls"].document_config.default_config.root_dir

                assert.equals(root_dir(cwd), cwd)
            end)
        end)
    end)

    describe("on_register_source", function()
        local mock_source
        local notify_client, try_add
        before_each(function()
            mock_source = {
                filetypes = { ["lua"] = true },
                methods = { [methods.internal.DIAGNOSTICS] = true },
                generator = {},
            }

            notify_client = stub(u, "notify_client")
            try_add = stub(lspconfig, "try_add")
        end)
        after_each(function()
            vim.bo.filetype = ""
            notify_client:revert()
            try_add:revert()
        end)

        it("should call try_add with bufnr", function()
            lspconfig.on_register_source(mock_source)
            vim.wait(0)

            assert.stub(try_add).was_called_with(vim.api.nvim_get_current_buf())
        end)

        it("should call client.notify if source is available", function()
            vim.bo.filetype = "lua"

            lspconfig.on_register_source(mock_source)
            vim.wait(0)

            assert.stub(notify_client).was_called_with(methods.lsp.DID_CHANGE, {
                textDocument = {
                    uri = vim.uri_from_bufnr(vim.api.nvim_get_current_buf()),
                },
            })
        end)
    end)

    describe("on_register_sources", function()
        after_each(function()
            require("lspconfig")["null-ls"].filetypes = {}
        end)

        it("should update config.filetypes", function()
            sources.register(require("null-ls.builtins")._test.mock_code_action)

            lspconfig.on_register_sources()

            local filetypes = require("lspconfig")["null-ls"].filetypes
            assert.equals(#filetypes, 1)
            assert.truthy(vim.tbl_contains(filetypes, "lua"))
        end)
    end)

    describe("try_add", function()
        local try_add = stub.new()
        require("lspconfig")["null-ls"].manager = { try_add = try_add }

        before_each(function()
            tu.edit_test_file("test-file.lua")
        end)

        after_each(function()
            vim.cmd("bufdo! bdelete!")
            vim.bo.buftype = ""
            vim.bo.filetype = ""
            try_add:clear()
        end)

        it("should attach when source matches", function()
            sources.register(require("null-ls.builtins")._test.mock_code_action)

            lspconfig.try_add()

            assert.stub(try_add).was_called_with(vim.api.nvim_get_current_buf())
        end)

        it("should not attach when source is not available", function()
            sources.register(require("null-ls.builtins")._test.mock_hover)

            lspconfig.try_add()

            assert.stub(try_add).was_not_called()
        end)

        it("should not attach when no sources", function()
            lspconfig.try_add()

            assert.stub(try_add).was_not_called()
        end)

        it("should not attach when buftype is not empty string", function()
            vim.bo.buftype = "nofile"
            sources.register(require("null-ls.builtins")._test.mock_code_action)

            lspconfig.try_add()

            assert.stub(try_add).was_not_called()
        end)

        it("should not attach when buffer has no name", function()
            tu.wipeout()
            vim.bo.filetype = "lua"
            sources.register(require("null-ls.builtins")._test.mock_code_action)

            lspconfig.try_add()

            assert.stub(try_add).was_not_called()
        end)
    end)
end)
