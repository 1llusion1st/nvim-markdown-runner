local api = vim.api
local util = require "markdown_runner.util"
local json2gostruct = require "json2gostruct"
local go_parser = require "markdown_runner.go_parser"
local bash_parser = require "markdown_runner.bash_parser"

local collector = {}

function collector.collect(params)
  print("callect called with params: " .. params)

  local current_buffer = api.nvim_get_current_buf()
  local text = table.concat(api.nvim_buf_get_lines(current_buffer, 0, -1, false), "\n")
  -- print("processing lines:", #(vim.split(text, "\n")))
  local requests = extract_requests(text)
  -- print("requests:", #requests, requests)
  -- print(dump(requests))
  
  local lines = {}
  local generated = {}
  local imports = {}

  local request = nil

  for i, request in ipairs(requests) do
    print("processing req: ", dump(request))
    
    process_request(generated, imports, request)
  end
  api.nvim_command("vnew")
  api.nvim_command("set syntax=go")
  local new_buffer = api.nvim_get_current_buf()
  table.insert(lines, "package generated")
  table.insert(lines, "")
  
  table.insert(lines, "import (")
  for _, import in ipairs(imports) do
    table.insert(lines, import)
  end
  table.insert(lines, ")")
  table.insert(lines, "")

  for _, line in ipairs(generated) do
    table.insert(lines, line)
  end
  table.insert(lines, "")

  print("lines:", dump(lines))

  api.nvim_buf_set_lines(new_buffer, 0, -1, false, lines)
end

function process_request(generated, imports, request)
  print("\n\tPROCESSING REQ: " .. dump(request))
  local base_code_block = request[1]
  base_code_block.code_block = util.replace_source_includes(base_code_block.code_block, util.getPath(vim.fn.expand('%')))
  print("meta: ", dump(base_code_block.meta))
  if base_code_block.code_lang == "go" then
    process_request_go(generated, imports, request)
  elseif base_code_block.code_lang == "bash" then
    process_request_bash(generated, request)
  else
    local code_lang = string.format("%s", base_code_block.code_lang)
    table.insert(generated, "// unsupported code-block type: " .. code_lang .. " for request id: " .. base_code_block.meta.id)
  end
  print("PROCESSED REQ!")
end

function process_request_go(generated, imports, request)
  print("processing GO CODE BLOCK: " .. dump(request))
  local base_code_block = request[1]
  local block_imports, code = go_parser.parse(base_code_block.code_block, true)
  for _, import in ipairs(block_imports) do
    table.insert(imports, "\t" .. import)
  end
  table.insert(generated, string.format("// %s", base_code_block.meta.id))
  for _, code_line in ipairs(vim.split(code, "\n")) do
    table.insert(generated, code_line)
  end
  table.insert(generated, "")
end

function process_request_bash(generated, request)
  print("PROCESSING BASH !!!!!!!!!!!")
  local base_code_block = request[1]
  local curl_path, curl_json = bash_parser.find_curl_command(base_code_block.code_block)
  local entity_name = json2gostruct.to_camel_case(base_code_block.meta.id)
  print("curl_path:", curl_path, "json: ", curl_json, "entity_name: ", entity_name)
  if curl_path then
    table.insert(generated, string.format("// %s", base_code_block.meta.id))
    
    local response_code_block = request[2]
    local response_go_struct = {}
    if response_code_block then
      print("CONVERTING RESPONSE CODE BLOCK", dump(response_code_block))
      local response_json = json2gostruct.decode_json(response_code_block.code_block)
      print("resonse_json: ", response_json)
      response_go_struct = json2gostruct.convert_json_to_go_struct_in_memory("Response"..entity_name, response_json)
      print("response code block lines count: ", #response_go_struct)
    end

    local base_url, path = bash_parser.parse_url(curl_path)

    if curl_json then
      -- generate post request
      print("CONVERTING REQUEST CODE BLOCK")
      local go_struct = json2gostruct.convert_json_to_go_struct_in_memory("Request" .. entity_name, json2gostruct.decode_json(curl_json))
      
      -- generate request struct code
      for _, line in ipairs(go_struct) do
        table.insert(generated, line)
      end
      table.insert(generated, "")
    
      -- generate responce struct code
      if #response_go_struct > 0 then
        for _, line in ipairs(response_go_struct) do
          table.insert(generated, line)
        end
        table.insert(generated, "")
      end

      table.insert(generated, "func (i *Impl) Do" .. entity_name .. "(ctx context.Context) (error) {")
      table.insert(generated, "\treq := Request" .. entity_name .. "{}") 
      table.insert(generated, "\tendpoint := \"" .. path .. "\"")
      table.insert(generated, "\treq := Response" .. entity_name .. "{}") 
      table.insert(generated, "\t// do some logic") 
      table.insert(generated, "\tpanic(\"not implemented\")") 
      table.insert(generated, "}")
    else
      -- generate get request
      -- generate responce struct code
      if #response_go_struct > 0 then
        for _, line in ipairs(response_go_struct) do
          table.insert(generated, line)
        end
        table.insert(generated, "")
      end

      table.insert(generated, "func (i *Impl) Do" .. entity_name .. "(ctx context.Context) (error) {")
      table.insert(generated, "\tendpoint := \"" .. path .. "\"")
      table.insert(generated, "\treq := Response" .. entity_name .. "{}") 
      table.insert(generated, "\t// do some logic") 
      table.insert(generated, "\tpanic(\"not implemented\")") 
      table.insert(generated, "}")
    end
  else
    table.insert(generated, string.format("// curl request not detected - check it"))
  end
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function extract_requests(text)
  local START_REQ = "GENERATE_REQ_BEGIN"
  local END_REQ = "GENERATE_REQ_END"
  local requests = {}
  while true do
    local start_req = text:find(START_REQ)
    if start_req == nil then break end
    -- print("start_req:", start_req)
    text = text:sub(start_req + #START_REQ)
    
    local end_req = text:find(END_REQ)
    -- print("end_req:", end_req)
    if end_req == nil then break end

    local request_block = text:sub(1, end_req - 1)
    -- print("req block: ", request_block)
    local code_blocks = extract_code_blocks(request_block)
    if #code_blocks > 0 then
      table.insert(requests, code_blocks)
      print("REQ: ", dump(code_blocks))
    end
    text = text:sub(end_req + #END_REQ)
  end
  return requests
end

function extract_code_blocks(text)
  local pattern = "```(.+)```"
  local code_blocks = {}

  while true do
    local code_start = text:find("```")
    if code_start == nil then break end
    text = text:sub(code_start + 3)
    local code_end = text:find("```")
    if code_end == nil then break end
    local code_block = text:sub(1, code_end - 1)
    text = text:sub(code_end + 3)

    local first_new_line = code_block:find("\n")
    local code_lang = code_block:sub(1, first_new_line - 1)
    code_block = code_block:sub(first_new_line + 1)
    -- print("code lang: " .. code_lang)
    -- print("code_block: " .. dump(code_block))
    table.insert(code_blocks, {
        code_lang = code_lang,
        code_block = code_block,
        meta = extract_info_from_code_block(code_block)
      })
  end
  print("code_blocks count: ", #code_blocks)
  return code_blocks
end

function extract_info_from_code_block(block)
  local keys = {
    id = "ID",
    format = "OUTFORMAT",
    file = "OUTFILE",
    post_cmd = "POST_CMD"
  }
  -- print('extracting info from ' .. type(block), #(vim.split(block, "\n")))
  local result = {}
  for _, line in ipairs(vim.split(block, "\n")) do
    for key, pattern in pairs(keys) do
    -- print("processing line " .. line .. " with patter: " .. pattern .. " for key: " .. key )
      local found = util.get_comment_key_value("", line, pattern)
      if found ~= "" then
        result[key] = found
      end
    end
  end
  return result
end

return collector
