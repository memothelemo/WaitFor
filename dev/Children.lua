--[[

    Children
    Author: memothelemo (Cedcedmeranez)

    Children.Safe(parent: Instance, children: string[])
        => Instance

    Children.WithTimeout(parent: Instance, children: string[], timeout: number | nil)
        => Instance | nil

]]


local AllContains = require(script.Parent.AllContains)
local Config = require(script.Parent.Config)
local TimedResolver = require(script.Parent.TimedResolver)
local FastSpawn = require(script.Parent.FastSpawn)
local Child = require(script.Parent.Child)

local Children = {}


function Children.Safe(parent: Instance, children: table, onCancel: RBXScriptSignal)
    assert(typeof(parent) == 'Instance', '`Parent` is required and must be an Instance')
    assert(typeof(children) == 'table', '`Children` is required and must be a table')
    assert(AllContains(children, 'string'), 'All children argument table\'s value/s requires string')
    assert(typeof(onCancel) == 'RBXScriptSignal' or onCancel == nil, '`onCancel` must be a RBXScriptSignal or nil')

    local realChildren = {}

    --> OPTIMIZATION
    for _, child in pairs(children) do
        local theirRealChild = parent:FindFirstChild(child)
        if (theirRealChild) then
            table.insert(realChildren, theirRealChild)
        end
    end
    if (#realChildren == #children) then
        return unpack(realChildren)
    end

    local onChildrenFound = Instance.new('BindableEvent')
    local onResolved = Instance.new("BindableEvent")
    local isResolved = false

    local connection
    connection = onChildrenFound.Event:Connect(function()
        if (#realChildren == #children) then
            connection:Disconnect()
            isResolved = true
            onResolved:Fire()
        end
    end)

    for index, child in pairs(children) do
        FastSpawn(function()
            local childInst = Child['Safe'](parent, child)
            realChildren[index] = childInst
            onChildrenFound:Fire()
        end)
    end

    -- Manual Connection
    local cancelConnection
    if onCancel then
        cancelConnection = onCancel:Connect(function()
            cancelConnection:Disconnect()
            onResolved:Fire()
        end)
    end

    if (not isResolved) then
        onResolved.Event:Wait()
    end
    onResolved:Destroy()
    onChildrenFound:Destroy()

    if cancelConnection then
        cancelConnection:Disconnect()
    end

    return unpack(realChildren)
end


function Children.WithTimeout(parent: Instance, children: table, timeout: number, ignoreError: boolean | nil)
    --> Asserting
    assert(typeof(parent) == 'Instance', '`Parent` is required and must be an Instance')
    assert(typeof(children) == 'table', '`Children` is required and must be a table')
    assert(AllContains(children, 'string'), 'All children argument table\'s value/s requires string')
    
    assert(typeof(timeout) == 'number' or timeout == nil, "`Timeout` must be a number or nil")
    assert(typeof(ignoreError) == 'boolean', '`IgnoreError` must be a boolean or nil')

    timeout = timeout or Config.TIMEOUT

    local realChildren = {}

    --> OPTIMIZATION
    for _, child in pairs(children) do
        local theirRealChild = parent:FindFirstChild(child)
        if (theirRealChild) then
            table.insert(realChildren, theirRealChild)
        end
    end
    if (#realChildren == #children) then
        return unpack(realChildren)
    end

    local cancellationBindable = Instance.new('BindableEvent')
    local safeResolver = TimedResolver.new(timeout, function(resolve)
        pcall(function()
            realChildren = { Children['Safe'](parent, children, cancellationBindable.Event) }
            resolve()
        end)
    end, true)

    if (safeResolver:IsResolved()) then
        safeResolver:Destroy()
        cancellationBindable:Destroy()
        return unpack(realChildren)
    else
        cancellationBindable:Fire()
        cancellationBindable:Destroy()
        safeResolver:Destroy()
        if not ignoreError then
            warn(("[WaitFor]: Failed to find required children in the parent of"), parent)
        end
        return
    end
end


return Children