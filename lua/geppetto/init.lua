-- vmap('<leader>ai', "\"gy :terminal 'chatgpt vim.fn.getreg('g')'<cr>", '')
-- nmap('<leader>ai', ":terminal chatgpt -i<cr>", '')
-- nmap('<leader>ap', ":lua chatgpt_prompts()<cr>", '')
-- vim.keymap.set('v', '<leader>r', function() require("chatgpt").edit_with_instructions() end, { silent = true, noremap = false })
-- print("filegpt.lua loaded")

local M = {}

function M.setup()
  vim.keymap.set('n', '<leader>a', function()
    local path = M.create_new_chat_file()
    M.open_file(path)
  end, { silent = true, noremap = false })

  vim.keymap.set('v', '<leader>a', function()
    local content = M.get_selection_as_markdown()
    local path = M.create_new_chat_file(content)
    M.open_file(path)
  end, { silent = true, noremap = false })

  vim.keymap.set('n', '<leader>aa', function()
    -- M.run_on_current_file()
    M.run_stream()
  end, { silent = false, noremap = false })
end

function M.accept_prompt()
  M.copy_all_buffer()
  vim.cmd('normal! "gp')
end

function M.open_file(path)
  vim.cmd("e " .. path)
  vim.cmd('normal G')
  vim.cmd('startinsert')
end

function M.copy_all_buffer()
  vim.cmd('noau normal! ggVG"gy')
  return vim.fn.getreg("g")
end

function M.get_selection_as_markdown()
  vim.cmd('noau normal! "vy"')
  return "```\n" .. vim.fn.getreg("v") .. "\n```\n"
end

function M.get_latest_chat_file()
  local files = vim.fn.glob("/tmp/*.md", false, true)
  table.sort(files, function(a, b)
    return a > b
  end)
  return files[1]
end

function M.create_new_chat_file(content)
  local date = os.date("%Y-%m-%dT%H:%M:%S")
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

function M.run_on_current_file()
  local path = vim.fn.expand("%:p")
  local cmd = "/Users/edelprino/Projects/Personali/geppetto/target/debug/geppetto " .. path
  vim.cmd("vsplit | terminal " .. cmd)
end

function M.run_stream()
  local path = vim.fn.expand("%:p")
  local handle
  local loop = vim.loop

  local function update_last_line(buf, new_text, contains_newline)
    local line_count = vim.api.nvim_buf_line_count(buf)
    local last_line = vim.api.nvim_buf_get_lines(buf, line_count - 1, line_count, false)[1]
    if not last_line then last_line = "" end

    if contains_newline then
      -- Sostituisci l'ultima riga con il testo precedente il newline
      local text_before_newline = new_text:match("^(.-)\n")
      if not text_before_newline then text_before_newline = "" end
      vim.api.nvim_buf_set_lines(buf, line_count - 1, line_count, false, { last_line .. text_before_newline })
      -- Aggiungi una nuova riga vuota per il testo successivo
      vim.api.nvim_buf_set_lines(buf, line_count, -1, false, { "" })
    else
      -- Aggiorna l'ultima riga con il nuovo testo
      vim.api.nvim_buf_set_lines(buf, line_count - 1, line_count, false, { last_line .. new_text })
    end
  end

  local function on_read(err, data)
    if err then
      -- Gestisci errore
      print("Errore:", err)
    elseif data then
      vim.schedule(function()
        local buf = vim.api.nvim_get_current_buf()
        if data:find("\n") then
          -- Se 'data' contiene newline, gestiscila di conseguenza
          local parts = vim.split(data, "\n")
          for i, part in ipairs(parts) do
            update_last_line(buf, part, i < #parts)
          end
        else
          -- Altrimenti, aggiorna semplicemente l'ultima riga
          update_last_line(buf, data, false)
        end
      end)
    end
  end

  -- Creazione delle pipe per l'output e l'errore
  local stdout = loop.new_pipe(false)
  local stderr = loop.new_pipe(false)

  local on_exit = function(status)
    print("Process exited with status " .. status)
    vim.loop.close(handle)
    stdout:close()
    stderr:close()
  end

  vim.schedule(function()
    local buf = vim.api.nvim_get_current_buf()
    local line_count = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_buf_set_lines(buf, line_count, -1, false, { "", "---", "### Assistant" })
  end)

  handle = loop.spawn("/Users/edelprino/Projects/Personali/geppetto/target/debug/geppetto", {
    args = { path },
    stdio = { nil, stdout, stderr },
    detached = true,
  }, on_exit)
  stdout:read_start(on_read)
  stderr:read_start(on_read)
end

return M
