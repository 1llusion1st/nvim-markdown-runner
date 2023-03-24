local M = {}

function M.run_sql(block)
  if vim.g.debug_print == 1 then
    print("running sql '"..(block.arguments or "").."': ", block)  
  end
  
  -- process only if passed db-server credentials
  if block.arguments == nil then return "" end
  local schema, user, password, host, port, dbname = block.arguments:match("^(%w+)://([^:]+):([^@]+)@([^:]+):(%d+)/(.+)$")
  if schema == "postgres" then
    return table.concat(run_psql_query(schema, user, password, host, port, dbname, block.src), "\n")
  elseif schema == "mysql" then
    print("not implemented yet")
    return ""
  else
    print("unknown schema: " .. (schema or ""))
    return ""
  end
end

function run_psql_query(schema, user, password, host, port, dbname, query)
    local psql_command = string.format(
        'PGPASSWORD="%s"' .. ' psql -h %s -p %s -U %s -d %s -c "%s"',
        password, host, port, user, dbname, table.concat(query, " \n")
    )
    if vim.g.debug_print == 1 then
      print("psql_command: " .. psql_command)  
    end
    

    local result = vim.fn.system(vim.env.SHELL, string.split(psql_command, "\n"))
    if vim.g.debug_print == 1 then
      print("result: ", type(result), result)  
    end
    

    return string.split(result, "\n")
end

return M
