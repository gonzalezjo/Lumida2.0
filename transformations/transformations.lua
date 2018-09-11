local transformations = {
  noop = assert(require 'transformations/noop')
  -- string_comparison = assert(require 'transformations/constant_string_comparison'),
  -- numerals = assert(require 'transformations/numerals'), 
  -- string_encryption = assert(require 'transformations/string_encryption'),
  -- string_splitting = assert(require 'transformations/string_splitting'),
} 

return transformations