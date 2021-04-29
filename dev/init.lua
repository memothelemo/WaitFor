--[[
    
    WaitFor (1.0.3 - Beta 2)
    Author: memothelemo (Cedcedmeranez)

]]

local Children = require(script.Children)
local Child = require(script.Child)
local Path = require(script.Path)
local Event = require(script.Event)
local Time = require(script.Time)
local NextSteps = require(script.NextSteps)

local function merge(root, extented)
    local result = root
    for k, v in pairs(extented) do
        result[k] = v
    end
    return result
end

local WaitFor = {

    --> Child
    ChildSafe = Child["Safe"],
    Child = Child["WithTimeout"],
    
    childSafe = Child["Safe"],
    child = Child["WithTimeout"],

    --> Children
    ChildrenSafe = Children["Safe"],
    Children = Children["WithTimeout"],

    childrenSafe = Children["Safe"],
    children = Children["WithTimeout"],

    --> Path
    PathSafe = Path["Safe"],
    Path = Path["WithTimeout"],

    pathSafe = Path["Safe"],
    path = Path["WithTimeout"],

    --> Event
    EventSafe = Event["Safe"],
    Event = Event["WithTimeout"],

    eventSafe= Event["Safe"],
    event = Event["WithTimeout"],

    --> Seconds
    Seconds = Time,
    seconds = Time,

    --> Steps
    NextHeartbeat = NextSteps["Heartbeat"],
    NextRenderStep = NextSteps["RenderStep"],
    BeforeHeartbeat = NextSteps["BeforeHeartbeat"],

    nextHeartbeat = NextSteps["Heartbeat"],
    nextRenderStep = NextSteps["RenderStep"],
    beforeHeartbeat = NextSteps["BeforeHeartbeat"],

}

--> Making sure if there's WFPromise and Promise <-
if (script:FindFirstChild("Promise") and script:FindFirstChild("WFPromise")) then
    local WFPromise = require(script.WFPromise)
    local promisesFunctions = {
        ChildSafePromise = WFPromise["ChildSafe"],
        ChildPromise = WFPromise["ChildTimeout"],
    
        childSafePromise = WFPromise["ChildSafe"],
        childPromise = WFPromise["ChildTimeout"],

        ChildrenSafePromise = WFPromise["ChildrenSafe"],
        ChildrenPromise = WFPromise["ChildrenTimeout"],
    
        childrenSafePromise = WFPromise["ChildrenSafe"],
        childrenPromise = WFPromise["ChildrenTimeout"],

        PathSafePromise = WFPromise["PathSafe"],
        PathPromise = WFPromise["PathTimeout"],

        pathSafePromise = WFPromise["PathSafe"],
        pathPromise = WFPromise["PathTimeout"],
    }
    WaitFor = merge(WaitFor, promisesFunctions)
end

return WaitFor