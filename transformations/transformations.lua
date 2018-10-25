local transformations = {
  noop = assert(require 'transformations/modules/noop'),
  numerals = assert(require 'transformations/modules/numerals'), 
  strings = assert(require 'transformations/modules/strings'),
  pooling = assert(require 'transformations/modules/pooling'),
  nodotsyntax = assert(require 'transformations/modules/nodotsyntax')
} 

return transformations