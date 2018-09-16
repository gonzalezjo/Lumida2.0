local transformations = {
  noop = assert(require 'transformations/modules/noop'),
  -- string_comparison = assert(require 'transformations/constant_string_comparison'),
  numerals = assert(require 'transformations/modules/numerals'), 
  strings = assert(require 'transformations/modules/stringencryption'),
  pooling = assert(require 'transformations/modules/pooling'),
} 

return transformations