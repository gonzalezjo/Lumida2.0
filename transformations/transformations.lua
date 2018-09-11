do
  return {} -- stub
end

local transformations = {
  string_comparison = assert(require 'transformations/constant_string_comparison.lua'),
  numerals = assert(require 'transformations/numerals.lua'), 
  string_encryption = assert(require 'transformations/string_encryption.lua'),
  string_splitting = assert(require 'transformations/string_splitting.lua'),
} 

return transformations