local NextSteps = require(script.Parent.NextSteps)

return function(duration: number)
    assert(type(duration) == 'number' or duration == nil, '`Duration` argument must be nil or number')
    
    if duration then
        local clock = os.clock
        local lastTime = clock()
        while true do
            NextSteps.Default()
            
            if ((clock() - lastTime) >= duration) then
                break
            end
        end
        return clock() - lastTime
    else
        return NextSteps.Default()
    end
end