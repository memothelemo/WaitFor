--[[

    Child
    Author: memothelemo (Cedcedmeranez)

    Child.Safe(parent: Instance, child: string, onCancel: RBXScriptSignal)
        => Instance | nil (if canceled)

    Child.WithTimeout(parent: Instance, child: string, timeout: number | nil)
        => Instance | nil

]]

local Config = require(script.Parent.Config)
local TimedResolver = require(script.Parent.TimedResolver)

local Child = {}


function Child.Safe(parent: Instance, child: string, onCancel: RBXScriptSignal | nil)
    --> Asserting
    assert(typeof(parent) == 'Instance', '`Parent` is required and must be an Instance')
    assert(typeof(child) == 'string', '`Child` is required and must be a string')
    assert(typeof(onCancel) == 'RBXScriptSignal' or onCancel == nil, '`onCancel` must be a RBXScriptSignal or nil')

    --> Attempting to find that child
    local realChild = parent:FindFirstChild(child)
    if realChild then
        return realChild
    end

    --> Some bindable unsense
    local bindable = Instance.new('BindableEvent')
    local childAddedConnection
    childAddedConnection = parent.ChildAdded:Connect(function(newChild)
        if (newChild.Name == child) then
            realChild = newChild

            childAddedConnection:Disconnect()
            bindable:Fire()
        end
    end)

    if (realChild) then
        bindable:Destroy()
        return realChild
    end

    --[[
        Manual cancellation because there are some cases
        such as the strict version of Child. It needs to stop if it
        cannot resolved it
    ]]
    local cancelConnection
    if onCancel then
        cancelConnection = onCancel:Connect(function()
            cancelConnection:Disconnect()
            bindable:Fire()
        end)
    end

    bindable.Event:Wait()
    bindable:Destroy()

    if cancelConnection then
        cancelConnection:Disconnect()
    end

    return realChild
end


function Child.WithTimeout(parent: Instance, child: string, timeout: number, ignoreError: boolean | nil)
    --> Asserting
    assert(typeof(parent) == 'Instance', '`Parent` is required and must be an Instance')
    assert(typeof(child) == 'string', '`Child` is required and must be a string')
    assert(typeof(timeout) == 'number' or timeout == nil, "`Timeout` must be a number or nil")
    assert(typeof(ignoreError) == 'boolean' or ignoreError == nil, '`IgnoreError` must be a boolean or nil')
    timeout = timeout or Config.TIMEOUT

    --> To not waste time
    local realChild = parent:FindFirstChild(child)
    if realChild then
        return realChild
    end
    
    local cancellationBindable = Instance.new('BindableEvent')
    local safeResolver = TimedResolver.new(timeout, function(resolve)
        realChild = Child['Safe'](parent, child, cancellationBindable.Event)
        resolve()
    end, true)

    if (safeResolver:IsResolved()) then
        safeResolver:Destroy()
        cancellationBindable:Destroy()

        return realChild
    else
        --> Cancel of finding that child
        cancellationBindable:Fire()

        --> Destroying the bindable?
        cancellationBindable:Destroy()

        safeResolver:Destroy()
        if not ignoreError then
            warn(("[WaitFor]: Failed to find a child (%s) in the parent of"):format(child), parent)
        end
        return nil
    end
end

return Child