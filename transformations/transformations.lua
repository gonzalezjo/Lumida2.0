local transformations = {
  noop = assert(require 'transformations/modules/noop'),
  numbers = assert(require 'transformations/modules/numbers'), 
  strings = assert(require 'transformations/modules/strings'),
  pooling = assert(require 'transformations/modules/pooling'),
  improveparsability = assert(require 'transformations/modules/improveparsability')
} 

return transformations