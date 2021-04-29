return function(callback, ...)
    local args = {...}
    local bindable = Instance.new('BindableEvent')
    local connection
    connection = bindable.Event:Connect(function()
        connection:Disconnect()
        callback(unpack(args))
    end)

    bindable:Fire()
    game:GetService('Debris'):AddItem(bindable, 1)

    args = nil
end