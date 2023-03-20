local api = vim.api

local util = {}

function util.readfile_string(p)
  local lines = vim.fn.readfile(p)
  return table.concat(lines, "\n")
end

function util.cookie_path()
  return vim.fn.stdpath("cache") .. "/mdr-cookies.txt"
end

function util.buf_get_line(l)
  return api.nvim_buf_get_lines(0, l-1, l, true)[1]
end

function util.echo_err(msg)
  api.nvim_echo({{"MarkdownRunner: " .. (msg or ""), "ErrorMsg"}}, false, {})
end

function util.get_comment_key_value(start_value, line, key)
	if start_value ~= "" then return start_value end
	local comment_symbols = {"#", "//", "\""}
	for i, comment_symbol in ipairs(comment_symbols) do
		-- print("comment symbol:", comment_symbol)
		local pattern = comment_symbol .. "[ \t]+" .. key .. ":[ \t]+" .. "([^$]*)"
		-- print("pattern: ", pattern)
		local match = line:match(pattern)
		-- print("match: ", match)
		if match ~= "" and match ~= nil then
			-- print(match)
			match_trimmed, n = match:gsub("^%s*(.-)%s*$", "%1")
			return match_trimmed
		end
	end
	return ""
end

-- onelined version ;)
--    getPath=function(str,sep)sep=sep or'/'return str:match("(.*"..sep..")")end
function util.getPath(str,sep)
    sep=sep or'/'
    return str:match("(.*"..sep..")")
end

-- x = "/home/user/.local/share/app/some_file"
-- y = "C:\\Program Files\\app\\some_file"
-- print(getPath(x))
-- print(getPath(y,"\\"))

-- print("nvim_markdown_runner.util prepared")
return util
