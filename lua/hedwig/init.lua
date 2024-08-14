local M = {}

function M.setup()
  -- Support for .http and .rest files
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = { "*.http", "*.rest" },
    callback = function()
      vim.bo.filetype = "http"
    end,
  })
end

function M.run()
  print("Running the request...")
end

return M
