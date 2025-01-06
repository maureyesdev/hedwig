local M = {}

-- Trim leading and ending white space from a string
-- @param s string: The string to be trim
-- @return string: The trimmed string
local function trim_string(s)
  -- ? Is this validation necessary?
  if type(s) ~= "string" then
    error("trim_string: Expected a string, got " .. type(s))
  end
  return s:match("^%s*(.-)%s*$")
end

-- Execute a curl request
local function execute_curl_request(lines)
  -- Combine lines into a single command
  local request = table.concat(lines, "\n")

  -- Handle line continuations (`\`) and trim excess whitespace
  request = request:gsub("\\%s*\n", " "):gsub("\n", " ")
  request = trim_string(request)

  -- Add the '-s' flag if not present
  if not request:find("%-s") then
    request = request .. " -s"
  end

  -- Execute the curl command
  local output = vim.fn.systemlist(request)
  return output
end

local function parse_http_request(lines)
  -- Extract method and URL from the first line and trim leading and ending white space
  local method, url = trim_string(lines[1]):match("^(%w+)%s+(.-)$")
  -- ? Should I need a validation here?

  -- Initialize headers and body containers
  local headers = {}
  local body = {}
  local is_body = false

  -- Loop through the lines to separate headers and body
  for i = 2, #lines do
    if lines[i] == "" then
      -- Empty line indicates the start of the body
      is_body = true
    elseif is_body then
      -- Collect the lines as body content
      table.insert(body, lines[i])
    else
      -- Collect the lines as headers
      local header_key, header_value = lines[i]:match("^(.-):%s*(.-)$")
      if header_key and header_value then
        table.insert(
          headers,
          string.format("-H '%s: %s'", header_key, header_value)
        )
        -- ? Should I need a validation here?
      end
    end
  end

  return method, url, headers, table.concat(body, "\n")
end

-- Execute a HTTP request
local function execute_http_request(lines)
  local method, url, headers, body = parse_http_request(lines)
  local curl_command = {
    "curl -sS",
    string.format("-X %s", method),
    table.concat(headers, " "),
    string.format("-d '%s'", body),
    string.format("'%s'", url),
  }
  local output = vim.fn.systemlist(table.concat(curl_command, " "))

  return output
end

-- Request factory to handle curl request and HTTP syntax request
-- TODO: Can I do JS object mapping return?
local function request_factory(lines)
  local is_curl = trim_string(lines[1]):lower():find("^curl") == 1
  if is_curl then
    return {
      execute = function()
        return execute_curl_request(lines)
      end,
    }
  end

  return {
    execute = function()
      return execute_http_request(lines)
    end,
  }
end

-- Open a new vertical split and display the output
local function display_output(output)
  vim.api.nvim_command("vsplit")
  local bfrnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, bfrnr)
  vim.api.nvim_buf_set_lines(bfrnr, 0, -1, false, output)
end

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
  -- Read the current buffer
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  -- ? Is this a right place to handle the error of empty buffer or no lines?

  local request = request_factory(lines)
  local output = request.execute()

  -- TODO: Probably need to handle more ways to display the output
  display_output(output)
end

return M
