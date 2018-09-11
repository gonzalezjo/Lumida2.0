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
  parser:option('-output', 'Output file.', 'out.luac')

  parser:flag('-R --roblox', 'Enable ROBLOX bytecode specialization.')
  parser:flag('-D --debug', 'Run debug test suite.')
  parser:flag('-V --verbose', 'Enable verbose logging.')

  parser:option('-t --transformations', 'Source code transformations.'):args('?')
  parser:option('-m --mutations', 'Bytecode transformations.', 'forprep'):args('?')
  parser:flag('--no-mutations', 'Completely disable bytecode mutations.')
  parser:flag('--no-transformations', 'Completely disable AST transformations.')
  parser:flag('--pretty-bytecode', 'Return loadstring(...)() call.')

  arguments = parser:parse()
  _G.regular_lua = not arguments.roblox -- globals :\\\\/\/\/\//\/

  if verbose then 
    print('Arguments: ')
    
    for k, v in pairs(arguments) do 
      print(k, v)
    end

    print('')
  end 
end

local obfuscators = {}
do 
  obfuscators.ast = require 'transformations/transformations'
  obfuscators.bytecode = require 'mutations/mutations'
end

local source
do 
  source = arguments.debug and 
    DEBUG_CODE or 
    assert(io.open(arguments.input, 'r+b')):read('*a')

  local verbose = arguments.verbose

  if 
    not arguments.no_transformations and 
    arguments.transformations and 
    #arguments.transformations > 0 then 

    for _, v in ipairs(arguments.transformations) do 
      assert(obfuscators.bytecode[v], 'No AST transformer: ' .. v)

      if arguments.verbose then 
        print('Running source transformation: ' .. v)
      end

      source = obfuscators.ast[v](output, verbose)
    end
  elseif arguments.verbose then 
    print 'Skipping AST transformations.'
  end 

  assert(source and loadstring(source), 'Invalid AST transformations.')

  if 
    not arguments.no_mutations and
    arguments.mutations and 
    #arguments.mutations > 0 then 

    local compiler 
    compiler, _G.regular_lua = require 'compiler', not arguments.roblox
    source = compiler.compile_to_proto(source, '=lumida')

    for _, v in ipairs(arguments.mutations) do 
      assert(obfuscators.bytecode[v], 'No bytecode mutator: ' .. v)
      
      if arguments.verbose then 
        print('Running bytecode mutation: ' .. v)
      end

      source = obfuscators.bytecode[v](output, verbose)
    end

    source = assert(compiler.compile_proto(proto), 'Failed to compile proto.')

    assert(loadstring(source), 'Invalid bytecode transformations.')

    if arguments.pretty_bytecode then 
      local dump = {
        source:byte(1, 9e9) -- please do not write 9e9 + 1 instructions worth of code. 
      }

      source = 'loadstring(' .. table.concat(dump, '\\') .. ')()'
    end
  elseif arguments.verbose then  
    print 'Skipping bytecode mutations.'
  end
end

do 
  local f = io.open(arguments.output, 'wb')
  f:write(source)
  f:close()

  if arguments.verbose then 
    print(
      '------------------\nOutput: \n------------------\n\n' 
      .. tostring(source) .. 
      '\n------------------')
  end
end