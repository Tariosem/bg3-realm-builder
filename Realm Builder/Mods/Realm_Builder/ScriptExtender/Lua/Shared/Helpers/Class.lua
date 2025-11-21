--- @class Class
--- @field __name string
--- @field __parent Class
--- @field __index table
--- @field __init fun(self:Class, ...):nil
--- @field new fun(self:Class, ...):Class
--- @field isInstance fun(self:Class, obj:any):boolean

--- @param name any
--- @param parent any
function _Class(name, parent)
    local cls = {}
    cls.__name = name
    cls.__parent = parent

    if parent then
        setmetatable(cls, { __index = parent })
    end

    cls.__index = cls

    function cls.new(...)
        local instance = setmetatable({}, cls)
        if instance.__init then
            instance:__init(...)
        end
        return instance
    end

    function cls:IsInstance(obj)
        return getmetatable(obj) == self
    end

    return cls
end