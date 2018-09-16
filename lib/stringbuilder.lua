local StringBuilder
do
  local _class_0
  local _base_0 = {
    __concat = function(self, operand)
      do
        local _with_0 = self
        _with_0.size, _with_0.contents[_with_0.size + 1] = _with_0.size + 1, operand
        return _with_0
      end
    end,
    __tostring = function(self)
      return table.concat(self.contents)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, ...)
      self.contents, self.size = {
        ...
      }, select('#', ...)
    end,
    __base = _base_0,
    __name = "StringBuilder"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  StringBuilder = _class_0
end
return StringBuilder
