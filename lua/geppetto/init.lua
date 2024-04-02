-- vmap('<leader>ai', "\"gy :terminal 'chatgpt vim.fn.getreg('g')'<cr>", '')
-- nmap('<leader>ai', ":terminal chatgpt -i<cr>", '')
-- nmap('<leader>ap', ":lua chatgpt_prompts()<cr>", '')
-- vim.keymap.set('v', '<leader>r', function() require("chatgpt").edit_with_instructions() end, { silent = true, noremap = false })
-- print("filegpt.lua loaded")

local M = {}

function M.setup()
  vim.keymap.set('n', '<leader>a', function()
    local path = M.CreateNewChatFile()
    vim.cmd("e " .. path)
    vim.cmd('normal G')
    vim.cmd('startinsert')
  end, { silent = true, noremap = false })

  vim.keymap.set('v', '<leader>a', function()
    local path = M.CreateNewChatFile("```\n" .. M.GetVisualSelection() .. "\n```")
    vim.cmd("e " .. path)
    vim.cmd('normal G')
    vim.cmd('startinsert')
  end, { silent = true, noremap = false })

  vim.keymap.set('n', '<leader>aa', function()
    M.Run()
  end, { silent = false, noremap = false })
end

function M.GetVisualSelection()
  vim.cmd('noau normal! "vy"')
  vim.print(vim.fn.getreg("v"))
  return vim.fn.getreg("v")
end

function M.CreateNewChatFile(content)
  local date = os.date("%Y.%m.%d-%H.%M.%S")
  local path = "/tmp/" .. date .. ".md"
  local file, errore = io.open(path, "w")
  if not file then
    error("Impossibile aprire il file: " .. errore)
  end
  if content == nil then
    content = ""
  end
  local lines = {
    "Sei un assistente virtuale, rispondi a tutte le mie domande in maniera concisa e precisa.",
    "",
    "---",
    "### User",
    content,
    "",
  }
  file:write(table.concat(lines, "\n"))
  file:close()
  return path
end

function M.Run()
  local path = vim.fn.expand("%:p")
  local cmd = "/Users/edelprino/Projects/Personali/geppetto/target/debug/geppetto " .. path
  vim.cmd("vsplit | terminal " .. cmd)
end

return M
