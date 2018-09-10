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

  parser:flag('-Nm --no-bytecode', 'Disable bytecode mutation.')
  parser:flag('-Nt --no-transformations', 'Disable AST transformations.')
  parser:flag('-R --roblox', 'Enable ROBLOX bytecode specialization.')
  parser:flag('-D --debug', 'Run debug test suite.')
  parser:flag('-V --verbose', 'Enable verbose logging.')

  parser:option('-output', 'Output file.', 'out.luac')
  parser:option('-t --transformations', 'Source code transformations.'):args('?')
  parser:option('-m --mutation', 'Bytecode transformations.'):args('?')

  arguments = parser:parse()
end

local obfuscators = {}
do 
  obfuscators.ast = {}
  obfuscators.bytecode = {}
end

do 
  local compiler = require 'compiler'

  _G.regular_lua = not arguments.roblox 

  local code_target = (arguments.debug and DEBUG_CODE) or (io.open(input, 'r+b')):('*a')

  local verbose = arguments.verbose

  local output = _G.code_target
  if arguments.transformations and #arguments.transformations > 0 then 
    output = _G.code_target
    for _, v in ipairs(arguments.transformations) do 
      source = obfuscators.ast(_G.verbosity)
    end
  end 

  -- if arguments.
end