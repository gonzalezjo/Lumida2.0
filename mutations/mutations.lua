local mutations = {
  forprep = assert(require 'mutations/forprep'),
} 

function mutations:names()
  local names = {}

  for k, _ in pairs(self) do 
    table.insert(names, k)
  end

  return unpack(names)
end

return mutations