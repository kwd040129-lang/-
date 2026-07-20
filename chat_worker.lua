local requestChannel = love.thread.getChannel("chat_requests")
local responseChannel = love.thread.getChannel("chat_responses")
local endpoint = "https://2f41we25cx.onrender.com/chat"

local function escapeJsonString(value)
    return value:gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("\b", "\\b")
        :gsub("\f", "\\f")
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
end

while true do
    local message = requestChannel:demand()

    if message == "__quit__" then
        break
    end

    local requestName = "chat_request.json"
    local responseName = "chat_response.json"
    local requestPath = love.filesystem.getSaveDirectory() .. "/" .. requestName
    local responsePath = love.filesystem.getSaveDirectory() .. "/" .. responseName
    local requestBody = '{"message":"' .. escapeJsonString(message) .. '"}'
    love.filesystem.write(requestName, requestBody)
    love.filesystem.remove(responseName)

    local command = string.format(
        'curl.exe --silent --show-error --max-time 75 --request POST --header "Content-Type: application/json" --data-binary "@%s" --output "%s" --write-out "%%{http_code}" "%s" 2>&1',
        requestPath,
        responsePath,
        endpoint
    )
    local process = io.popen(command, "r")

    if not process then
        responseChannel:push("0\n채팅 프로그램을 실행할 수 없습니다.")
    else
        local commandOutput = process:read("*a") or ""
        process:close()
        local statusCode = commandOutput:match("(%d%d%d)%s*$") or "0"
        local responseBody = love.filesystem.read(responseName) or ""

        if statusCode == "0" and commandOutput ~= "" then
            responseBody = commandOutput
        end

        responseChannel:push(statusCode .. "\n" .. responseBody)
    end
end
