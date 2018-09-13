return function(proto, verbose)
  if verbose then 
    print 'Disabling debug information'
  end

  _G.spoof_debug = true 

  return proto
end