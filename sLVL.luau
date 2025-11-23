local function try(fn, ...)
    local success, _ = pcall(fn, ...)
    return success
end

local function randomString()
    local length = math.random(10, 20)
    local array = {}
    for i = 1, length do
        array[i] = string.char(math.random(32, 126))
    end
    return table.concat(array)
end

local capabilities = {
    Plugin = try(function() return #game:GetService("CoreGui"):GetChildren() > 0 and workspace.RobloxLocked end),
    LocalUser = try(function() return game.DataCost end),
    WritePlayer = not try(function() Instance.new("Player", workspace) end),
    RobloxScript = try(function() return game:GetService("CorePackages").Name and game:GetService("CoreGui").SelectionImageObject end),
    RobloxEngine = try(function() return Instance.new("SurfaceAppearance").TexturePack and game:GetService("CSGDictionaryService").Name end),
    NotAccessible = try(function() Instance.new("MeshPart").MeshContent = Content.none() end) and try(function() game:GetService("Chat").LoadDefaultChat = game:GetService("Chat").LoadDefaultChat end),
    Assistant = try(function() return game:GetService("StreamingService") end) and try(function()
        local _, errMsg = pcall(game:GetService("StreamingService").ExecuteCommandAsync, game:GetService("StreamingService"))
        return not string.find(tostring(errMsg), "lacking permission")
    end),
    InternalTest = try(Instance.new, "CustomLog"),
    OpenCloud = try(function()
        local s1, s2, s3 = randomString(), randomString(), randomString()
        local scr1 = Instance.new("ModuleScript")
        scr1.Source = s1
        local scr2 = Instance.new("LocalScript")
        scr2.Source = s2
        local scr3 = Instance.new("Script")
        scr3.Source = s3
        return scr1.Source == s1 and scr2.Source == s2 and scr3.Source == s3
    end)
}

local identityNames = {
    [0] = "Anonymous",
    [1] = "LocalGui",
    [2] = "GameScript",
    [3] = "ElevatedGameScript",
    [4] = "CommandBar",
    [5] = "StudioPlugin",
    [6] = "ElevatedStudioPlugin",
    [7] = "COM",
    [8] = "WebService",
    [9] = "Replicator",
    [10] = "Assistant",
    [11] = "OpenCloudSession",
    [12] = "TestingGameScript"
}

local identityRequirements = {
    [0]  = {},
    [1]  = {Plugin=true, LocalUser=true},
    [2]  = {},
    [3]  = {Plugin=true, LocalUser=true, RobloxScript=true},
    [4]  = {Plugin=true, LocalUser=true},
    [5]  = {Plugin=true},
    [6]  = {Plugin=true, LocalUser=true, RobloxScript=true, Assistant=true},
    [7]  = {Plugin=true, LocalUser=true, WritePlayer=true, RobloxScript=true, RobloxEngine=true, NotAccessible=true},
    [8]  = {
        {Plugin=true, LocalUser=true, WritePlayer=true, RobloxScript=true, RobloxEngine=true, NotAccessible=true},
        {OpenCloud=true, LocalUser=true, WritePlayer=true, RobloxScript=true, RobloxEngine=true, NotAccessible=true},
        {Plugin=true, OpenCloud=true, LocalUser=true, WritePlayer=true, RobloxScript=true, RobloxEngine=true, NotAccessible=true}
    },
    [9]  = {WritePlayer=true, RobloxScript=true},
    [10] = {Plugin=true, LocalUser=true, Assistant=true},
    [11] = {OpenCloud=true},
    [12] = {InternalTest=true}
}

local actualCapsSet = {}
local actualCapsList = {}
local actualCapsCount = 0
for cap, success in pairs(capabilities) do
    if success then
        actualCapsSet[cap] = true
        actualCapsCount = actualCapsCount + 1
        table.insert(actualCapsList, cap)
    end
end

local function findCandidates(capsSet, capsCount)
    local foundCandidates = {}
    for id, reqs in pairs(identityRequirements) do
        local setsToTest = {}
        if type(reqs[1]) == "table" then
            setsToTest = reqs
        else
            table.insert(setsToTest, reqs)
        end

        for _, reqSet in ipairs(setsToTest) do
            local reqCount = 0
            for _ in pairs(reqSet) do reqCount = reqCount + 1 end
            
            if reqCount == capsCount then
                local isMatch = true
                for cap in pairs(reqSet) do
                    if not capsSet[cap] then
                        isMatch = false
                        break
                    end
                end
                if isMatch then
                    table.insert(foundCandidates, id)
                    break
                end
            end
        end
    end
    return foundCandidates
end

local candidates = findCandidates(actualCapsSet, actualCapsCount)

printidentity()
task.wait(0.1) 

local logHistory = game:GetService('LogService'):GetLogHistory()
local detectedIdentity
for i = #logHistory, 1, -1 do
    local idStr = string.match(logHistory[i].message, "Current identity is (%d+)")
    if idStr then
        detectedIdentity = tonumber(idStr)
        break
    end
end

local getthreadidentity = getthreadidentity or function() return nil end
local isSpoofed = getthreadidentity() and getthreadidentity() ~= detectedIdentity
local finalIdentity = -1
local isSpoofedViaOpenCloud = false

if actualCapsSet.OpenCloud then
    local tempCapsSet = {}
    for cap, _ in pairs(actualCapsSet) do
        if cap ~= "OpenCloud" then
            tempCapsSet[cap] = true
        end
    end
    local tempCapsCount = actualCapsCount - 1

    local lowerCandidates = findCandidates(tempCapsSet, tempCapsCount)
    if #lowerCandidates == 1 and lowerCandidates[1] < 8 then
        isSpoofedViaOpenCloud = true
        finalIdentity = 8 
    end
end

if finalIdentity == -1 then
    if #candidates == 1 then
        finalIdentity = candidates[1]
    elseif #candidates > 1 and detectedIdentity and table.find(candidates, detectedIdentity) then
        finalIdentity = detectedIdentity
    end
end

local outputLines = {}
local candidateText = #candidates == 1 and "candidate" or "candidates"
table.insert(outputLines, string.format("%d %s found.", #candidates, candidateText))

if isSpoofedViaOpenCloud then
    local finalName = identityNames[8]
    local reason = "Note: OpenCloud capability appears to be spoofed onto a lower identity."
    table.insert(outputLines, string.format("❎ Your executor's real identity is %d (%s), but it is spoofed.\n    %s", finalIdentity, finalName, reason))
elseif finalIdentity ~= -1 then
    local finalName = identityNames[finalIdentity] or "Unknown"
    local detectedName = (detectedIdentity and identityNames[detectedIdentity]) or "N/A"
    
    if finalIdentity == detectedIdentity then
        table.insert(outputLines, string.format("✅ Your executor's identity is %d (%s). Matches printidentity().", finalIdentity, finalName))
    else
        local reason = isSpoofed and "Note: setthreadidentity() may have been used." or "Note: Your executor is likely spoofing its identity."
        table.insert(outputLines, string.format("❎ Your executor's identity is %d (%s). Doesn't match printidentity() (%d - %s).\n    %s", finalIdentity, finalName, detectedIdentity, detectedName, reason))
    end
else
    local detectedName = (detectedIdentity and identityNames[detectedIdentity]) or "N/A"
    local detectedText = detectedIdentity and string.format("%d (%s)", detectedIdentity, detectedName) or "N/A"
    table.insert(outputLines, string.format("❌ Executor identity could not be determined. printidentity() reports %s.", detectedText))
end

table.insert(outputLines, string.format("\nDetected Capabilities: %s", table.concat(actualCapsList, ", ")))

print(("\n"):rep(50))
print(table.concat(outputLines, "\n"))
