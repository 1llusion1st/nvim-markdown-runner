local io = require "io"
local api = vim.api
local util = require "markdown_runner.util"
local parser = require "markdown_runner.parser"
local runners = require "markdown_runner.runners"
local collector = require "markdown_runner.collect"

local function get_runner(block)
  local lookup = vim.tbl_extend("force", runners, vim.g.markdown_runners or {})
  if block.cmd == nil then return vim.env.SHELL end
  for k, v in pairs(lookup) do
    if vim.split(block.cmd, "%.")[1] == k then return v end
  end
  return block.cmd
end

local function run(block)
  local runner = get_runner(block)

  local input_source = table.concat(block.src, "\n")

  local pattern = "@@[(][/a-z0-9\\. -]+[)]"
  while true do
	  local match = input_source:match(pattern)
	  if match == nil then break end
	  
	  local filename = block.meta.caller_dir .. match:sub(4, -2)
	  print("filename: ", filename)
	  f = io.open(filename, "rb")
	  local file_content = ""
	  if f == nil then
	  else
		file_content = f:read("*a")
		f:close()
		if file_content:sub(#file_content, #file_content) == "\n" then
			file_content = file_content:sub(1, #file_content - 1)
		end
	  end
	  input_source = input_source:gsub(pattern, file_content)
  end

  print(input_source)
  local lines = {}
  for s in input_source:gmatch("[^\r\n]+") do
    table.insert(lines, s)
  end
  print("block.meta.caller_dir = " .. block.meta.caller_dir)
  block.src = lines
  local current_dir = vim.fn.getcwd()
  print("starting working dir running cwd:", current_dir)
  local new_cwd_path = ""
  print("block.meta.caller_dir[1] = " .. block.meta.caller_dir:sub(1, 1))
  if block.meta.caller_dir:sub(1, 1) == '/' then
	print("dirrect path")
	new_cwd_path = block.meta.caller_dir
  else
	print("path with prefix")
	new_cwd_path = current_dir .. "/" .. block.meta.caller_dir
  end
  print("moving to " .. new_cwd_path)
  vim.api.nvim_set_current_dir(new_cwd_path)
  print("before running:", vim.fn.getcwd())

  local resp = ""
  if type(runner) == "string" then
    print("running string cmd")
    resp = vim.fn.system(runner, block.src)
    print("has run string cmd")
  elseif type(runner) == "function" then
    resp = runner(block)
    if string.sub(resp, -1, -1) ~= "\n" then
      resp = resp .. "\n"
    end
  else
    error("Invalid command type")
  end
  vim.api.nvim_set_current_dir(current_dir)
  current_dir = vim.fn.getcwd()
  print("after running cwd:", current_dir)
  return resp
end

local function echo()
  print(run(parser.get_code_block()))
end

local function insert()
  -- print("getting code block")
  local block = parser.get_code_block()
  -- print("got code block")
  local outformat = "text"
  if block.meta.outformat ~= "" then
    outformat = block.meta.outformat
  end
  print("block: ", block.meta.outfile, block.meta.outformat, block.meta.block_id, block.meta.post_cmd, block.meta.caller, block.meta.caller_dir)
  -- print("outformat: ", outformat)

  local block_content = run(block)
  local content = "\n```" .. outformat .. " markdown-runner\n" .. block_content .. "\n```"
  local l = block.end_line
  local line_count = api.nvim_buf_line_count(0)

  if block.meta.outfile ~= "" then
     local f_path = block.meta.outfile
     if f_path[1] ~= '/' then
	     f_path = block.meta.caller_dir .. f_path
     end
	  
     local f, err = io.open(f_path, "w")
     if f then
	     f:write(block_content)
	     f:close()
     else
	     print("couldn't save to file: ", err)
     end
  end

  if block.meta.post_cmd ~= "" then
	  local command = "cd " .. block.meta.caller_dir .. " && " .. block.meta.post_cmd
	  executed, ret, code = os.execute(command)
	  if code ~= 0 and code ~= nil then
		  print("error running command: " .. command .. " code: ", code)
	  end
  end

  -- Delete existing results block if present
  if l + 2 < line_count and util.buf_get_line(l+1) == "" and util.buf_get_line(l+2) == "```".. outformat .. " markdown-runner" then
    local blk = parser.get_code_block(l+2)
    local end_line = blk.end_line
    if end_line + 1 < line_count and util.buf_get_line(end_line + 1) == "" then 
      end_line = end_line + 1
    end
    api.nvim_buf_set_lines(0, blk.start_line - 1, end_line, true, {})
  end
  api.nvim_buf_set_lines(0, l, l, true, vim.split(content, "\n"))
end

local function wrap_handle_error(fn)
  return function ()
    local status, err = pcall(fn)
    if not status then 
      util.echo_err(string.match(err, "^.+%:%d+%: (.*)$"))
    end
  end
end

local function clear_cache()
  vim.fn.delete(util.cookie_path())
  print("MarkdownRunner: Cleared all cached data")
end

return {
  echo=wrap_handle_error(echo),
  insert=wrap_handle_error(insert),
  clear_cache=wrap_handle_error(clear_cache),
}
