local DEFAULT_TIMEOUT = 30

local TIMEOUT_ERROR = 'Failed to wait a child, "%s" from the parent of %s. (Timeout)'
local TIMEOUT_CHILDREN_ERROR = 'Failed to wait a child, "%s" from the parent of %s whilst verifying required children. (Timeout)'
local WAITFOR_CHILDREN_FAILED = 'Failed to wait the required children from the parent of %s whilst verifying all of them.'

local Promise = require(script.Parent.Promise)

local RunService = game:GetService("RunService")
local isClient = RunService:IsClient()

local function WaitStep()
    return (isClient and RunService.RenderStepped:Wait() or RunService.Heartbeat:Wait())
end

local function Wait(seconds)
    local i = 0
    while (i <= seconds) do
        local dt = WaitStep()
        i += dt
    end
    return i
end

--> WaitFor Module Call
local WaitFor = {}

--> WaitFor.Child
function WaitFor.Child(parent, name, ignoreError)
    --> Verifying for arguments
    assert(typeof(parent) == 'Instance', 'Parent argument must be an Instance')
    assert(type(name) == 'string', 'Name argument must be a string')

    --> Variables
    local timer = 0
    local child = nil
    local timeout = false

    --> Attempting to find a child
    while (child == nil) do
        timer += Wait(1)
        child = parent:FindFirstChild(name)
        timeout = timer >= DEFAULT_TIMEOUT

        if timeout then
            break
        end
    end

    local success = (not timeout and child)
    if not success and not ignoreError then
        warn(TIMEOUT_ERROR:format(name, parent.Name))
        return nil
    end
    
    return child
end
WaitFor.child = WaitFor.Child

--> WaitFor.Child with Promise implementation
function WaitFor.ChildPromise(parent, name, ignoreError)
    assert(typeof(parent) == 'Instance', 'Parent argument must be an Instance')
    assert(type(name) == 'string', 'Name argument must be a string')

    return Promise.new(function(resolve, reject)
        
        local timer = 0
        local child = nil
        local timeout = false

        while (child == nil) do
            timer += Wait(1)
            child = parent:FindFirstChild(name)
            timeout = timer >= DEFAULT_TIMEOUT

            if timeout then
                break
            end
        end

        local success = (not timeout and child)
        local result = success and child or TIMEOUT_ERROR:format(name, parent.Name)
        ;(success and resolve or reject)(result)

    end)
end
WaitFor.childPromise = WaitFor.ChildPromise

--> WaitFor.Children
function WaitFor.Children(parent, children)
    assert(typeof(parent) == 'Instance', 'Parent argument must be an Instance')
    assert(typeof(children) == 'table', 'Children argument must be a table')

    local childrenInQueue = {}
    for index, childName in pairs(children) do
        local child = WaitFor.Child(parent, childName, true)
        childrenInQueue[index] = child

        if (child == nil) then
            warn(TIMEOUT_CHILDREN_ERROR:format(childName, parent.Name))
        end
    end

    return unpack(childrenInQueue)
end
WaitFor.children = WaitFor.Children

--> WaitFor.Children promise implementation
function WaitFor.ChildrenPromise(parent, children)
    assert(typeof(parent) == 'Instance', 'Parent argument must be an Instance')
    assert(typeof(children) == 'table', 'Children argument must be a table')

    return Promise.new(function(resolve, reject)
        local bindable = Instance.new('BindableEvent')
        local scannedChildren = 0
        local childrenInQueue = {}

        for index, childName in pairs(children) do
            WaitFor.ChildPromise(parent, childName, true):Then(function(child)
                childrenInQueue[index] = child
            end):Catch(function(promiseError)
                if not promiseError then
                    warn(TIMEOUT_CHILDREN_ERROR:format(childName, parent.Name))
                else
                    warn(("Promise error! %s"):format(tostring(promiseError)))
                end

                childrenInQueue[index] = nil
            end):Finally(function()
                scannedChildren += 1
                bindable:Fire()
            end)
        end    
        
        local connection = nil
        connection = bindable.Event:Connect(function()
            if (#childrenInQueue == #children or scannedChildren == #children) then
                connection:Disconnect()

                local emptyTable = (childrenInQueue == {})
                if emptyTable then
                    return reject(WAITFOR_CHILDREN_FAILED:format(parent.Name))
                else
                    return resolve(unpack(childrenInQueue))
                end
            end
        end)
    end)
end
WaitFor.childrenPromise = WaitFor.ChildrenPromise

--> WaitFor.Second, does it make sense?
function WaitFor.Seconds(second)
    assert(typeof(second) == 'number', 'Seconds argument must be a number')
    return Wait(second)
end
WaitFor.seconds = WaitFor.Seconds

--> WaitFor.NextStep
function WaitFor.NextStep()
    return WaitStep()
end
WaitFor.nextStep = WaitFor.NextStep

--> WaitFor.NextStep promise implementation
function WaitFor.NextStepPromise()
    return Promise.new(function(resolve)
        resolve(WaitStep())
    end)
end
WaitFor.nextStepPromise = WaitFor.NextStepPromise

--> WaitFor.EventTriggered
function WaitFor.Event(event, execution)
    local isRBXScriptSignal = typeof(event) == 'RBXScriptSignal'
    local isTable = typeof(event) == 'table'
    assert(isTable or isRBXScriptSignal, 'Event argument must be on a table or RBXScriptSignal')

    --> It supports Signal class :D
    local isSignal = isTable and type(event['Connect']) == 'function'

    local isAnEvent = isRBXScriptSignal or isSignal
    assert(isAnEvent, 'Event argument must be RBXScriptSignal or Signal class')
    
    --> Creating new bindable for the eventful something
    local bindable = Instance.new('BindableEvent')
    local connection = nil

    connection = event:Connect(function(...)
        connection:Disconnect()

        local arguments = {...}
        if (execution) then
            spawn(function()
                execution(unpack(arguments))
            end)
        end
        bindable:Fire()
    end)

    bindable.Event:Wait()
    bindable:Destroy()
end
WaitFor.event = WaitFor.Event

--> WaitFor.eventTriggered Promise implementation
function WaitFor.EventPromise(event)
    local isRBXScriptSignal = typeof(event) == 'RBXScriptSignal'
    local isTable = typeof(event) == 'table'
    assert(isTable or isRBXScriptSignal, 'Event argument must be on a table or RBXScriptSignal')

    --> It supports Signal class :D
    local isSignal = isTable and type(event['Connect']) == 'function'

    local isAnEvent = isRBXScriptSignal or isSignal
    assert(isAnEvent, 'Event argument must be RBXScriptSignal or Signal class')

    return Promise.new(function(resolve)
        local connection = nil
        connection = event:Connect(function(...)
            connection:Disconnect()

            local arguments = {...}
            spawn(function()
                resolve(unpack(arguments))
            end)
        end)
    end)
end
WaitFor.eventPromise = WaitFor.EventPromise

return WaitFor