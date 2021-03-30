local DEFAULT_TIMEOUT = 30

local TIMEOUT_ERROR = 'Failed to wait a child, "%s" from the parent of %s. (Timeout)'
local TIMEOUT_CHILDREN_ERROR = 'Failed to wait a child, "%s" from the parent of %s whilst verifying required children. (Timeout)'
local WAITFOR_CHILDREN_FAILED = 'Failed to wait the required children from the parent of %s whilst verifying all of them.'

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

return WaitFor