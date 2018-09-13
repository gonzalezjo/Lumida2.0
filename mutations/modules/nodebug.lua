return function(proto, verbose)
  if verbose then 
    print 'Disabling debug information'
  end

  _G.strip_debug = true 

  return proto
end