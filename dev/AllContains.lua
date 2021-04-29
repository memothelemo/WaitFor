return function(tbl: table, _type: string)
    for _, value in pairs(tbl) do
        if (not typeof(value) == _type) then
            return false
        end
    end
    return true
end