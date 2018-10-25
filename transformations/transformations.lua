local transformations = {
  noop = assert(require 'transformations/modules/noop'),
  numbers = assert(require 'transformations/modules/numbers'), 
  strings = assert(require 'transformations/modules/strings'),
  pooling = assert(require 'transformations/modules/pooling'),
  nodotsyntax = assert(require 'transformations/modules/nodotsyntax')
} 

return transformations