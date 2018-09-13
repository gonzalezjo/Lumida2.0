local function obfuscate_proto(pr)
  local function process_proto(p)
  end

  return pr
end

return function(proto, verbose)
  local table_print = require 'lib/table_print'

  obfuscate_proto(proto)

  if verbose then 
    table_print(proto)
  end

  return proto
end