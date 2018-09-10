local DEBUG_CODE = [[
    local a
    
    local function b() 
      local c = 1
      print(a)
    end
]]

local arguments 
do
  local argparse = require 'lib/argparse'
  local parser = argparse('lumida.lua')

  parser:argument('input', 'Input file.')

  parser:flag('--no-mutations', 'Disable bytecode mutation.')
  parser:flag('--no-transformations', 'Disable AST transformations.')
  parser:flag('-R --roblox', 'Enable ROBLOX bytecode specialization.')
  parser:flag('-D --debug', 'Run debug test suite.')
  parser:flag('-V --verbose', 'Enable verbose logging.')

  parser:option('-output', 'Output file.', 'out.luac')
  parser:option('-t --transformations', 'Source code transformations.'):args('?')
  parser:option('-m --mutations', 'Bytecode transformations.'):args('?')

  arguments = parser:parse()
end

local obfuscators = {}
do 
  obfuscators.ast = {}
  obfuscators.bytecode = {}
end

local source
do 
  local compiler = require 'compiler'

  _G.regular_lua = not arguments.roblox 

  source = arguments.debug and 
    DEBUG_CODE or 
    assert(io.open(arguments.input, 'r+b')):read('*a')

  local verbose = arguments.verbose

  if 
    not arguments.no_transformations and 
    arguments.transformations and 
    #arguments.transformations > 0 then 

    for _, v in ipairs(arguments.transformations) do 
      if not obfuscators.ast[v] then 
        error('AST obfuscator ' .. v .. ' does not exist.')
      end 

      source = obfuscators.ast[v](output, verbose)
    end
  end 

  if 
    not arguments.no_mutations
    arguments.mutations and 
    #arguments.mutations > 0 then 
    
    for _, v in ipairs(arguments.transformations) do 
      if not obfuscators.bytecode[v] then 
        error('Bytecode obfuscator ' .. v .. ' does not exist.')
      end 

      source = obfuscators.bytecode[v](output, verbose)
    end
  end 

end

do 
  local f = io.open(arguments.output, 'wb')
  f:write(source)
  f:close()

  if arguments.verbose then 
    print('\nSource code: \n' .. tostring(source))
  end
end