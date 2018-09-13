local mutations = {
  forprep = assert(require 'mutations/modules/forprep'),
  noop = assert(require 'mutations/modules/noop'),
  nodebug = assert(require 'mutations/modules/nodebug'),
  spoofdebug = assert(require 'mutations/modules/spoofdebug'),
} 

return mutations