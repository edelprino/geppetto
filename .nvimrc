lua << EOF
-- print("Hello World")

vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("FileGPT", {clear = true}),
  pattern = "*.md",
  callback = function()
    print("Hello from autocmd this is a markdown file")
  end
})

function test()
  print("Hello from lua function")
end

-- require("lua.geppetto.init").setup()

EOF
