local api = vim.api
local util = require "markdown_runner.util"

local parser = {}

-- Returns the markdown code block on the given line for the current buffer.
function parser.get_code_block(line)
  local lines = {}
  local s = line or unpack(api.nvim_win_get_cursor(0))
  -- print("s: ", s)

  -- Get start line
  while not string.match(util.buf_get_line(s), "^```") do
    s = s - 1
    assert(s > 0, "not in a markdown code block")
  end
  -- print("s after: ", s)

  local outfile = ""
  local outformat = ""
  local post_cmd = ""
  local block_id = ""

  -- Get end line
  local start_line = util.buf_get_line(s)
  local e = s + 1
  local line_count = api.nvim_buf_line_count(0)
  while true do
    local line = util.buf_get_line(e)
    -- print("curr line: ", line)
    if string.match(line, "^```") then break end
    table.insert(lines, line)
    e = e + 1
    assert(e <= line_count, "not in a markdown code block")
    -- print("extracting meta data ...")
    outfile = util.get_comment_key_value(outfile, line, "OUTFILE")
    block_id = util.get_comment_key_value(block_id, line, "ID")
    outformat = util.get_comment_key_value(outformat, line, "OUTFORMAT")
    post_cmd = util.get_comment_key_value(post_cmd, line, "POST_CMD")
  end

  assert(#lines > 0, "code block is empty")

  local result = {
    start_line=s,
    end_line=e,
    cmd=string.match(start_line, "^```(%S+)"),
    arguments=string.match(start_line, "```%S+ (%S+)"),
    src=lines,
    meta={
      outfile=outfile,
      outformat=outformat,
      post_cmd=post_cmd,
      block_id=block_id,
      caller=vim.fn.expand('%'),
      caller_dir=util.getPath(vim.fn.expand('%'))
    }
  }
  print("PARSED")
  return result
end

-- print("nvim_markdown_runner.parser prepared")
return parser
