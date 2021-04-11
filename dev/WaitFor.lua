--[[

	WaitFor (Non-Promise version)
	Author: memothelemo
    Created: March 29, 2021 as in-house script
    Updated: April 10, 2021 (Update 3)
	
]]

--> Settings
local TIMEOUT = 5

--> Services and Dependencies
local RunService = game:GetService("RunService")

--> Variables
local isClient = RunService:IsClient()

--[[
    Informative error message feature
]]
local output do
    type OutputLevel = { nonstrict: string, traceback: string }
    local outputLevel: OutputLevel = {
        traceback = 'traceback',
        nonstrict = 'warn',
    }

    output = {}
    output.__index = output
    output.level = outputLevel
    output.scriptName = 'WaitFor'

    local function concenate(...): string
        local stringArgs = {...}
        local finalText: string = ""

        for _, text in pairs(stringArgs) do
            finalText = finalText .. text
        end

        return finalText
    end

    function output.new(level: string, text: string)
        local self = setmetatable({}, output)
        self._text = text
        self._level = level
        self._outputText = self:__compileText()

        return self
    end

    function output:__compileText(): string
        local header = "[%s]:"
        local errorHeader = "\n[%s Error]:"
        local finalHeader = self._level == output.level.traceback and errorHeader or header

        local compiledText: string = (finalHeader):format(output.scriptName)
        compiledText = concenate(compiledText, " ", self._text)

        return compiledText
    end

    function output:formatText(...)
        self._outputText = self._outputText:format(...)
    end

    function output:release()
        if (self._level == output.level.nonstrict) then
            return warn(self._outputText)
        end
        local tracebackContext = debug.traceback()
        local finalOutputText = concenate(self._outputText, "\n[Traceback]:\n", tracebackContext)
        warn(finalOutputText)
    end

    function output.error(text: string)
        return output.new(output.level.traceback, text):release()
    end
end

--[[
	Some important functions alternative ones than ROBLOX's built-in wait function
]] 
local function WaitStep(): number
	return (isClient and RunService.RenderStepped:Wait() or RunService.Heartbeat:Wait())
end

local function Wait(seconds: number | nil): number
    if (type(seconds) == 'number') then
        local i = 0
        while (i <= tonumber(seconds)) do
            local dt = WaitStep()
            i += dt
        end
        return i
    end
    return WaitStep()
end

local function spawn(callback, ...)
    local bindable = Instance.new('BindableEvent')
    local args = {...}
    local connection = nil

    connection = bindable.Event:Connect(function()
        connection:Disconnect()
        callback(unpack(args))
    end)

    bindable:Fire()
    bindable:Destroy()
end

local function makeTimer(duration: number, callback)
    local timerLeft: number = duration
    local forceStop: boolean = false
    local stopEvent: BindableEvent = Instance.new('BindableEvent')
    local connection = nil
    connection = stopEvent.Event:Connect(function()
        connection:Disconnect()
        forceStop = true
        stopEvent:Destroy()
    end)

    while true do
        if (forceStop or timerLeft <= 0) then
            break
        end
        timerLeft -= Wait()
        spawn(function()
            callback(stopEvent)
        end)
    end

    if (stopEvent) then
        connection:Disconnect()
        stopEvent:Destroy()
        return "Over"
    end
    return "Force"
end

local function check(case, output)
    if (not case) then
        error(output, 3)
    end
end

--> Constants
local ERRORS = {
    CHILD_TIMEOUT = output.new(output.level.nonstrict, 'Failed to wait a child, `%s` from the parent of %s. (Timeout)'),
    CHILDREN_TIMEOUT = output.new(output.level.nonstrict, "Failed to wait a child, `%s` from the parent of %s whilst verifying required children. (Timeout)"),
    PATH_TIMEOUT = output.new(output.level.nonstrict, 'Failed to wait a descendant child, `%s` (the ancestor of %s) from the highest ancestor %s, whilst verifying all of the descendants found in the path')
}

--> Module Call
local WaitFor = {}

--[[
    Lazy man's scanner
]]
local function ScanChildrenThenRunEach(children, callback)
    local scannedChildren = 0

    local done = false
    local queueEvent = Instance.new('BindableEvent')
    local mainEvent = Instance.new('BindableEvent')

    local queueConnection
    queueConnection = queueEvent.Event:Connect(function()
        scannedChildren += 1
        if (scannedChildren == #children) then
            queueConnection:Disconnect()
            queueEvent:Destroy()

            done = true
            mainEvent:Fire()
        end
    end)

    for index, childName in pairs(children) do
        spawn(callback, index, childName, queueEvent)
    end

    if (not done) then
        mainEvent.Event:Wait()
    end
    mainEvent:Destroy()
end

local function ScanPath(path: string, callback)
    local segments = string.split(path, ".")
    local conclusion = ""
    for _, descendant in pairs(segments) do
        --> YIELDING
        conclusion = callback(descendant)
        if (conclusion == 'break') then
            break
        end
    end
end

--[[
    Private Functions like to make the code clean
]]
local function WaitForChildSafe(parent: Instance, name: string): Instance | nil
    local child = parent:FindFirstChild(name)
    
    --> Optimization
    if (child) then
        return child
    end

    --> Using events and ChildAdded from the parent
    --> to detect if there's a new child in that object
    local childAddedConnection = nil
    local bindable: BindableEvent = Instance.new('BindableEvent')

    childAddedConnection = parent.ChildAdded:Connect(function(newChild: Instance)
        if (newChild.Name == name) then
            childAddedConnection:Disconnect()

            child = newChild
            bindable:Fire()
        end
    end)

    --> Checking again
    if (child) then
        childAddedConnection:Disconnect()
        bindable:Destroy()
        return child
    end

    --> Waiting until the child has been now found
    bindable.Event:Wait()
    bindable:Destroy()

    return child
end

local function WaitForChildStrict(parent: Instance, name: string, timeout: number | nil, ignoreError: boolean | nil): Instance | nil
    ignoreError = ignoreError or false

    local child = parent:FindFirstChild(name)
    timeout = timeout or TIMEOUT

    --> Optimization
    if (child) then
        return child
    end

    local reasonToStop: string = makeTimer(tonumber(timeout), function(stop: BindableEvent)
        child = parent:FindFirstChild(name)
        if (child) then
            stop:Fire()
        end
    end)

    --> If the timer stops abruptly then it will assume that a child has been found
    if (reasonToStop == "Force") then
        return child
    end

    --> Checking child once again to clarify if it is really found
    if (child) then
        return child
    end

    --> Output stuff
    if (not ignoreError) then
        ERRORS.CHILD_TIMEOUT:formatText(name, parent.Name)
        ERRORS.CHILD_TIMEOUT:release()
    end
    return nil
end

local function WaitForChildrenSafe(parent: Instance, children): Instance | nil
    local childrenInQueue = {}
    
    ScanChildrenThenRunEach(children, function(index: number, childName: string, queueEvent: BindableEvent)
        local child = WaitForChildSafe(parent, childName)
        childrenInQueue[index] = child
        
        queueEvent:Fire()
    end)

    return unpack(childrenInQueue)
end

local function WaitForChildrenStrict(parent: Instance, children, timeout: number | nil): Instance | nil
    timeout = timeout or TIMEOUT

    local childrenInQueue = {}
    ScanChildrenThenRunEach(children, function(index: number, childName: string, queueEvent: BindableEvent)
        local child = WaitForChildStrict(parent, childName, timeout, true)
        childrenInQueue[index] = child

        if (child == nil) then
            ERRORS.CHILDREN_TIMEOUT:formatText(childName, parent.Name)
            ERRORS.CHILDREN_TIMEOUT:release()
        end

        queueEvent:Fire()
    end)

    return unpack(childrenInQueue)
end

local function WaitForPathStrict(parent: Instance, path: string, timeout: number | nil): Instance | nil
    timeout = timeout or TIMEOUT

    local child: any = parent
    ScanPath(path, function(descendantName)
        local ancestor = child
        child = WaitForChildStrict(child, descendantName, timeout, true)
        
        if (not child) then
            ERRORS.PATH_TIMEOUT:formatText(descendantName, ancestor.Name, parent.Name)
            ERRORS.PATH_TIMEOUT:release()
            return 'break'
        end
    end)

    if (not child) then
        return nil
    end
    return child
end

local function WaitForPathSafe(parent: Instance, path: string): Instance | nil
    local child: any = parent
    ScanPath(path, function(descendantName)
        local ancestor = child
        child = WaitForChildSafe(ancestor, descendantName)
    end)
    return child
end

--> WaitFor Functions

--[[
    This function allows to wait for a child until a child is spawned
    in the designated parent without timeouts.
--]]
function WaitFor.ChildSafe(parent: Instance, name: string): Instance | nil
    check(typeof(parent) == 'Instance', '`Parent` is required')
    check(type(name) == 'string', '`Child` is required')
    return WaitForChildSafe(parent, name)
end

--[[
    Stricter version of WaitFor.ChildSafe
]]
function WaitFor.Child(parent: Instance, name: string, timeout: number | nil): Instance | nil
    check(typeof(parent) == 'Instance', '`Parent` is required')
    check(type(name) == 'string', '`Child` is required')
    check(type(timeout) == 'number' or timeout == nil, '`Timeout` must be a number or nil')
    return WaitForChildStrict(parent, name, timeout)
end

--[[
    WaitFor.ChildrenSafe is a function where it tries
    to find children each by each at the same
]]
function WaitFor.ChildrenSafe(parent: Instance, children): Instance | nil
    check(typeof(parent) == 'Instance', '`Parent` is required')
    check(typeof(children) == 'table', '`Children` is required')
    return WaitForChildrenSafe(parent, children)
end

--[[
    Stricter version of WaitFor.ChildrenSafe
]]
function WaitFor.Children(parent: Instance, children, timeout: number | nil): Instance | nil
    check(typeof(parent) == 'Instance', '`Parent` is required')
    check(typeof(children) == 'table', '`Children` is required')
    check(type(timeout) == 'number' or timeout == nil, '`Timeout` must be a number or nil')
    return WaitForChildrenStrict(parent, children, timeout)
end

--[[
    It allows to find the descendant by descendant without
	spamming the entire line of WaitFor's and WaitForChild's
	
	Inspired by: ChipioIndustries from his own module 'WaitForPath'
]]
function WaitFor.Path(parent: Instance, path: string, timeout: number | nil): Instance | nil
    check(typeof(parent) == 'Instance', '`Parent` is required')
    check(typeof(path) == 'string', '`Path` is required')
    check(type(timeout) == 'number' or timeout == nil, '`Timeout` must be a number or nil')
    return WaitForPathStrict(parent, path, timeout)
end


--[[
    Safer version of WaitFor.Path
]]
function WaitFor.PathSafe(parent: Instance, path: string): Instance | nil
    check(typeof(parent) == 'Instance', '`Parent` is required')
    check(typeof(path) == 'string', '`Path` is required')
    return WaitForPathSafe(parent, path)
end


return WaitFor