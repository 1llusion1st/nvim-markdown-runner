-- ```lua
local url = require("socket.url")
local cjson = require("cjson")

local M = {}

local function parse_url(input_url)
  if vim.g.debug_print == 1 then
      print("parse_url called("..input_url..")")    
  end
  
  local parsed_url = url.parse(input_url)

  local base_url = url.build({
    scheme = parsed_url.scheme,
    host = parsed_url.host,
    port = parsed_url.port,
  })
  local endpoint = parsed_url.path .. (parsed_url.query and "?" .. parsed_url.query or "")

  return base_url, endpoint
end


M.parse_url = parse_url

-- Розділяє вхідний рядок на окремі слова
local function split(str, sep)
    local result = {}
    for word in str:gmatch("([^" .. sep .. "]+)") do
        table.insert(result, word)
    end
    return result
end

-- Шукає шлях запиту в аргументах команди curl
local function find_path(args)
    for i, arg in ipairs(args) do
        if not arg:find("^%-") then
            return arg
        end
    end
    return nil
end

-- Шукає тіло JSON в аргументах команди curl
local function find_json(args)
    local json_start = false
    local json_parts = {}

    for i, arg in ipairs(args) do
        if arg == "-d" or arg == "--data" then
            json_start = true
        elseif json_start then
            if arg:find("^{") then
                json_start = false
            end
            table.insert(json_parts, arg)
        end
    end

    if #json_parts > 0 then
        return table.concat(json_parts, " ")
    else
        return nil
    end
end

local function find_json_havy(raw)
    local json_offset = 0
    local json_start = raw:find("-d '{")
    if not json_start then
        json_start = raw:find("--data '{")
        if json_start then
            json_offset = json_start + 8
        end
    else
        json_offset = json_start + 4
    end
    if not json_start then return end
    -- print("FULL RAW: ", raw)
    -- print("START_JSON = ", json_offset, raw:sub(json_offset, json_offset + 30))
    for end_ = #raw,2,-1 do
        local sym = raw:sub(end_, end_)
        -- print("end_ = ", end_, sym)
        if sym == '}' then
            local potential_json = raw:sub(json_offset, end_)
            -- print("POTENTIAL: ", potential_json)
            json_decoded = cjson.decode(potential_json)
            if json_decoded then return potential_json end
        end
    end
end

-- Парсить команду curl і повертає шлях та тіло JSON
local function parse_curl_command(curl_command)
    if vim.g.debug_print == 1 then
        print("parsing '" .. curl_command .. "'")    
    end
    
    local url = ""
    for link in string.gmatch(curl_command, "\"(https?://[ .()@$%w-_%.%?%.:/%+=&]+)\"") do
        url = link
        break
    end
    local args = split(curl_command, " ")
    local json_body = nil --find_json(args)
    if json_body == nil then
        json_body = find_json_havy(curl_command)
    end
    local path = url
    if vim.g.debug_print == 1 then
        print("path: ", path, "body: ", json_body)    
    end
    
    return path, json_body
end

M.find_curl_command = parse_curl_command

-- Тестування парсера
-- local function test_parse_curl_command()
--     -- Перевірка парсингу шляху та тіла JSON
--     print("running tests")
--     assert(parse_curl_command("export A=2\ncurl \"http://example.com/api/users\" -d '{\"name\":\"John\"\n,\"age\":30}'") == {"http://example.com/api/users", "{\"name\":\"John\"\n,\"age\":30}"})

--     assert(parse_curl_command("export A=2\ncurl \"http://$IP:$PORT/api/users\" -d '{\"name\":\"John\"\n,\"age\":30}'") == {"http://example.com/api/users", "{\"name\":\"John\",\"age\":30}"})


--     -- Перевірка парсингу тіла JSON без шляху
--     assert(parse_curl_command("curl -d '{\"name\":\"John\",\"age\":30}'") == {nil, "{\"name\":\"John\",\"age\":30}"})

--     -- Перевірка парсингу без тіла JSON та шляху
--     assert(parse_curl_command("curl") == {nil, nil})

--     -- test heavy
--     local curl_heavy1 = [[
--     bash
-- # OUTFORMAT:    json
-- export IP=65.109.11.89
-- curl -H 'Content-Type: application/json' \
--         -X POST "http://$IP:8090/v2/byron-wallets/$(cat .wallet.preprod.byron.id)/payment-fees" -d '{
--                   "payments": [
--                     {
--                       "address": "addr_test1qzcm402dr6kpw45mus23r9hx2czm34q2nnrq68n6pzx5kc4mk3rndz8ddalq27rc8lkz45grzql9x7eawx2qyzthdajqlh3ts3",
--                       "amount": {
--                         "quantity": 0,
--                         "unit": "lovelace"
--                       }
--                     }
--                   ]
-- }'  2>/dev/null | jq
--     ]]
--     local path, json = parse_curl_command(curl_heavy1)
--     print("heavy1: ", path, json)
--     print("passed?")
-- end

local function assert(expr)
  print("assert called")
  if expr ~= true then
    print("failed", expr)
  end
end
-- test_parse_curl_command()

return M

-- ```
