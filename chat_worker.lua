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

local function runCurlWithoutWindow(command)
    if jit and jit.os == "Windows" then
        local ffi = require("ffi")
        ffi.cdef[[
            typedef struct {
                unsigned long cb; char *lpReserved; char *lpDesktop; char *lpTitle;
                unsigned long dwX; unsigned long dwY; unsigned long dwXSize; unsigned long dwYSize;
                unsigned long dwXCountChars; unsigned long dwYCountChars; unsigned long dwFillAttribute;
                unsigned long dwFlags; unsigned short wShowWindow; unsigned short cbReserved2;
                unsigned char *lpReserved2; void *hStdInput; void *hStdOutput; void *hStdError;
            } STARTUPINFOA;
            typedef struct { void *hProcess; void *hThread; unsigned long dwProcessId; unsigned long dwThreadId; } PROCESS_INFORMATION;
            int CreateProcessA(const char *, char *, void *, void *, int, unsigned long, void *, const char *, STARTUPINFOA *, PROCESS_INFORMATION *);
            unsigned long WaitForSingleObject(void *, unsigned long);
            int GetExitCodeProcess(void *, unsigned long *);
            int CloseHandle(void *);
        ]]

        local startupInfo = ffi.new("STARTUPINFOA")
        startupInfo.cb = ffi.sizeof(startupInfo)
        local processInfo = ffi.new("PROCESS_INFORMATION")
        local commandBuffer = ffi.new("char[?]", #command + 1)
        ffi.copy(commandBuffer, command)
        local CREATE_NO_WINDOW = 0x08000000
        local success = ffi.C.CreateProcessA(nil, commandBuffer, nil, nil, 0, CREATE_NO_WINDOW, nil, nil, startupInfo, processInfo)

        if success == 0 then
            return false, -1
        end

        ffi.C.WaitForSingleObject(processInfo.hProcess, 0xFFFFFFFF)
        local exitCode = ffi.new("unsigned long[1]")
        ffi.C.GetExitCodeProcess(processInfo.hProcess, exitCode)
        ffi.C.CloseHandle(processInfo.hThread)
        ffi.C.CloseHandle(processInfo.hProcess)
        return true, tonumber(exitCode[0])
    end

    local result = os.execute(command)
    return result == true or result == 0, result
end

while true do
    local request = requestChannel:demand()

    if request == "__quit__" then
        break
    end

    local message = type(request) == "table" and request.message or request
    local userSummary = type(request) == "table" and request.user_summary or ""
    message = type(message) == "string" and message or ""
    userSummary = type(userSummary) == "string" and userSummary or ""

    local requestName = "chat_request.json"
    local responseName = "chat_response.json"
    local requestPath = love.filesystem.getSaveDirectory() .. "/" .. requestName
    local responsePath = love.filesystem.getSaveDirectory() .. "/" .. responseName
    local requestBody = '{"message":"' .. escapeJsonString(message)
        .. '","user_summary":"' .. escapeJsonString(userSummary) .. '"}'
    love.filesystem.write(requestName, requestBody)
    love.filesystem.remove(responseName)

    local command = string.format(
        'curl.exe --silent --show-error --fail-with-body --max-time 75 --request POST --header "Content-Type: application/json" --data-binary "@%s" --output "%s" "%s"',
        requestPath,
        responsePath,
        endpoint
    )
    local started, exitCode = runCurlWithoutWindow(command)
    local responseBody = love.filesystem.read(responseName) or ""

    if not started then
        responseChannel:push("0\n채팅 프로그램을 실행할 수 없습니다.")
    elseif exitCode == 0 then
        responseChannel:push("200\n" .. responseBody)
    else
        responseChannel:push("500\n" .. responseBody)
    end
end
