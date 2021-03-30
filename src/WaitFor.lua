local DEFAULT_MAX_WAIT_TIME = 2

local Wait = wait
local Promise = require(script.Parent.Promise)
local WaitFor = {}

function WaitFor.Child(parent, name)
    assert(typeof(parent) == 'Instance', 'Parent argument must be an Instance')
    assert(type(name) == 'string', 'Name argument must be a string')

    return Promise.new(function(resolve, reject)
        local timer = 0
        local child = nil
        while (child == nil) do
            timer += Wait(1)
            child = parent:FindFirstChild(name)
            if (timer >= DEFAULT_MAX_WAIT_TIME) then
                break
            end
        end
        if (timer >= DEFAULT_MAX_WAIT_TIME and not child) then
            return reject(('Failed to wait a child, "%s" from the parent of %s. (Reached max time)'):format(name, parent.Name))
        end
        resolve(child)
    end)
end

function WaitFor.Children(parent, childList)
    assert(typeof(parent) == 'Instance', 'Parent argument must be an Instance')
    assert(typeof(childList) == 'table', 'Child list argument must be a table')

    --> Returning with a Promise object <--
    return Promise.new(function(resolve, reject)
        local children = {}
        for index, childName in pairs(childList) do
            WaitFor.Child(parent, childName)
                :Then(function(child)
                    children[index] = child
                    if (#children == #childList) then
                        resolve(unpack(children))
                    end
                end)
                :Catch(function()
                    reject(('Failed to wait a child, "%s" from the parent of %s whilst verifying required children. (Reached max time)'):format(childName, parent.Name))
                end)
        end
    end)
end

function WaitFor.ChildrenThenGet(parent, childList)
    local children = nil
    local resolved = Instance.new('BindableEvent')
    
    WaitFor.Children(parent, childList)
        :Then(function(...)
            children = {...}
            resolved:Fire()
        end)
        :Catch(function(err)
            error(err)
        end)
    resolved.Event:Wait()
    resolved:Destroy()

    return unpack(children)
end

return WaitFor