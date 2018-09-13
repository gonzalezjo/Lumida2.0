local function obfuscate_proto(proto)
  local function process_proto(proto)
    -- noop
  end

  return proto
end

return function(proto, verbose)
  local table_print = require 'lib/table_print'

  obfuscate_proto(proto)

  if verbose then 
    table_print(proto)
  end

  return proto
end