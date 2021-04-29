--[[
    
    NextSteps
    Author: memothelemo (Cedcedmeranez)
    
]]



local RunService = game:GetService("RunService")
local isClient = RunService:IsClient()

local Heartbeat = RunService.Heartbeat
local Stepped = RunService.Stepped
local RenderStep = isClient and RunService.RenderStepped or nil

local NextSteps = {}

function NextSteps.Heartbeat()
    return Heartbeat:Wait()
end

function NextSteps.RenderStep()
    if not isClient then
        return error("Clients can only run WaitFor.NextRenderStep", 3)
    end
    return RenderStep:Wait()
end

function NextSteps.BeforeHeartbeat()
    return Stepped:Wait()
end

function NextSteps.Default()
    if isClient then
        return NextSteps['RenderStep']()
    end
    return NextSteps['Heartbeat']()
end

return NextSteps