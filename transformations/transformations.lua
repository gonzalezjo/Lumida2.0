do
  return {} -- stub
end

local transformations = {
  string_comparison = assert(require 'transformations/constant_string_comparison'),
  numerals = assert(require 'transformations/numerals'), 
  string_encryption = assert(require 'transformations/string_encryption'),
  string_splitting = assert(require 'transformations/string_splitting'),
} 

function transformations:names()
  local names = {}

  for k, _ in pairs(self) do 
    table.insert(names, k)
  end

  return unpack(names)
end

return transformations