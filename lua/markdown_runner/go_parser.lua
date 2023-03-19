-- ```lua
local function parseGo(code, skip_main)
  local imports = {}
  local importPattern = 'import%s*%b()'
  local singleImportPattern = 'import%s+("[^"]+)"'
  -- local singleImportNamedPattern = 'import(%s+%w+%s+%s+"[^"]+)"'
  local singleImportNamedPattern = 'import%s+(%w+%s+"[^"]+)"'
  local singleImportUnNamedPattern = 'import%s+(_%s+"[^"]+)"'
  local multilineImportPattern = 'import%s*%((.-)%s*%)'

  code = code:gsub("package %w+\n", "")

	local simpleImportCode = code
	for simpleImport in string.gmatch(code, singleImportPattern) do
		table.insert(imports, simpleImport .. "\"")
	end
	code = code:gsub(singleImportPattern, "")
	for simpleImport in string.gmatch(code, singleImportNamedPattern) do
		table.insert(imports, simpleImport .. "\"")
	end
	code = code:gsub(singleImportNamedPattern, "")
	for simpleImport in string.gmatch(code, singleImportUnNamedPattern) do
		table.insert(imports, simpleImport .. "\"")
	end
	code = code:gsub(singleImportUnNamedPattern, "")
  for importBlock in string.gmatch(code, importPattern) do
		-- print("import block: ", importBlock)
    local singleImport = string.match(importBlock, singleImportPattern)
    if singleImport then
      table.insert(imports, singleImport)
    else
			for _, line in ipairs(importBlock:split("\n")) do
				if line ~= "import (" then
					if line == ")" then break end
					table.insert(imports, line)
				end
			end
      -- local multilineImport = string.match(importBlock, multilineImportPattern)
      -- if multilineImport then
      --   for importLine in string.gmatch(multilineImport, '"([^"]+)"') do
      --     table.insert(imports, "\"" .. importLine .. "\"")
      --   end
      -- end
    end
		code = code:gsub(importPattern, "")
  end

	-- print("rest code: " .. code)
	local trimmed_imports = {}
	for _, import in ipairs(imports) do
		table.insert(trimmed_imports, all_trim(import))
	end

  if skip_main then
    local result_lines = {}
    local code_lines = code:split("\n")
    local in_main = false

    for _, code_line in ipairs(code_lines) do
      local comment_found = false
      -- print("line: '" .. code_line .. "'" .. " in_main: ", in_main)
      for _, remove_prefix in ipairs({"// ID:", "// OUTFORMAT:", "// OUTFILE:", "// POST_CMD", "// COLLECT"}) do
        if code_line:sub(1, #remove_prefix) == remove_prefix then
          comment_found = true
          break
        end
      end
      if not comment_found then
        if in_main == false then
          if code_line == "func main() {" or code_line == "func main(){" then
            in_main = true
          else
            table.insert(result_lines, code_line)
          end
        else
          if code_line == "}" then in_main = false end
        end
      end
    end
    code = table.concat(result_lines, "\n")
  end

  return trimmed_imports, code
end

function all_trim(s)
   return s:match( "^%s*(.-)%s*$" )
end

function string:split(delimiter)
  local result = { }
  local from  = 1
  local delim_from, delim_to = string.find( self, delimiter, from  )
  while delim_from do
    table.insert( result, string.sub( self, from , delim_from-1 ) )
    from  = delim_to + 1
    delim_from, delim_to = string.find( self, delimiter, from  )
  end
  table.insert( result, string.sub( self, from  ) )
  return result
end

-- -- Example usage:
-- local goCode = [[
-- package main

-- import "fmt"
-- import pkg0 "net/http"
-- import _ "mysql"
-- import (
--   "os"
--   "strconv"
-- 	pk1 "some-package"
-- 	_ "postgres"
-- )

-- func someAnotherFunc() {
--   fmt.Println("AAAAAAAAAAA")
-- }

-- func main() {
--   fmt.Println("Hello, world!")
-- }
-- ]]

--  local imports, code = parseGo(goCode, true)
--  print("imports: ", #imports)
--  for _, importItem in ipairs(imports) do
--    print(importItem)
--  end
--  print("REST CODE: ".. code)
-- ```

return {
  parse = parseGo,
  str_trim = all_trim
}
