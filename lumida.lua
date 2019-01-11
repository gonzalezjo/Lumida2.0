math.randomseed(os.time() + os.clock())

local DEBUG_CODE = [[
  print("a")
  print'a'
]]

local ffi = require'ffi'

ffi.cdef[[

  struct RetStruct { 
    int success;  
    size_t len;
    char str[0];
  };

  int ValidateBytecode(const char* s, unsigned int l);
  struct RetStruct* CompileToBytecode(const char* s, unsigned int l);
  void free(void *ptr);

]]

local LumidaCompiler = ffi.load("C:\\Users\\slapzor\\source\\repos\\LumidaCompiler\\Release\\LumidaCompiler.dll")
local bytecode_parser = require'bytecode_parser'

local function compile_source(src)
  local retstruct = LumidaCompiler.CompileToBytecode(DEBUG_CODE, #DEBUG_CODE)
  local bc = ffi.string(ffi.cast("void*", retstruct.str), retstruct.len)
  local chunk = bytecode_parser.decode_chunk(bc)
  ffi.C.free(retstruct)
  return chunk
end

--print(compile_source(DEBUG_CODE))

--[[local retstruct = LumidaCompiler.CompileToBytecode(DEBUG_CODE, #DEBUG_CODE)
local bc = ffi.string(ffi.cast("void*", retstruct.str), retstruct.len)


local chunk = bytecode_parser.decode_chunk(bc)
table.foreach(chunk, print)
print'-----------------']]

--print("test:", LumidaCompiler.ValidateBytecode(bc, #bc + 1));

local obfuscators = {}
do 
  obfuscators.ast = require 'transformations/transformations'
  obfuscators.bytecode = require 'mutations/mutations'
end

local arguments 
do
  local argparse = require 'lib/argparse'
  local parser = argparse('lumida.lua')

  parser:argument('input', 'Input file.')
  parser:option('-o --output', 'Output file.', 'out.luac')

  parser:flag('-R --roblox', 'Enable ROBLOX bytecode specialization.')
  parser:flag('-D --debug', 'Run debug test suite.')
  parser:flag('-V --verbose', 'Enable verbose logging.')
  parser:flag('-S --skip-validation', 'Completely disable bytecode validation.')

  parser:option('-t --transformations', 'Source code transformations.'):args('*')
  parser:option('-m --mutations', 'Bytecode transformations.', {'forprep'}):args('*'):defmode('unused')

  parser:flag('--no-mutations', 'Completely disable bytecode mutations.')
  parser:flag('--no-transformations', 'Completely disable AST transformations.')
  parser:flag('--pretty-bytecode', 'Return loadstring(...)() call.')

  arguments = parser:parse()
  _G.regular_lua = not arguments.roblox -- globals :\\\\/\/\/\//\/
  --arguments.skip_validation = arguments.skip_validation or (not _G.regular_lua or not _VERSION:match 'Lua 5.1' or jit) 

  if arguments.verbose then 
    _G.VERBOSE_COMPILATION = true

    print('Arguments: ')

    for k, v in pairs(arguments) do 
      print(k, v, (type(v) == 'table' and ('Size: ' .. #v) or ''))
    end

    print('')
  end 
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
      assert(obfuscators.ast[v], 'No AST transformer: ' .. v)

      if arguments.verbose then 
        print('Running source transformation: ' .. v)
      end

      source = obfuscators.ast[v](source, verbose)
    end
  elseif arguments.verbose then 
    print 'Skipping AST transformations.'
  end 

  local succ, err = pcall(assert, source and loadstring(source), 'Invalid AST transformations')
  if not succ then 
    if verbose then 
      print('Error during AST transformation: ', err)
      print('Source code: \n', source)
    end

    error(err)
  end

  if 
    not arguments.no_mutations and
    arguments.mutations and 
    #arguments.mutations > 0 then 

    local compiler 
    compiler = require 'compiler'
    source = compile_source(source)--compiler.compile_to_proto(source, '=lumida')
    table.foreach(source, print)

    for _, v in ipairs(arguments.mutations) do 
      assert(obfuscators.bytecode[v], 'No bytecode mutator: ' .. v)

      if arguments.verbose then 
        print('Running bytecode mutation: ' .. v)
      end

      source = obfuscators.bytecode[v](source, verbose)
    end

    source = assert(compiler.compile_proto(source), 'Failed to compile proto.')

    if not arguments.skip_validation then
      assert(LumidaCompiler.ValidateBytecode(source, #source) == 1, 'Invalid bytecode transformations.')
    end

    if arguments.pretty_bytecode then 
      local dump = {
        --source:byte(1, 2 ^ 30) -- please do not write 9e9 + 1 instructions worth of code. 
      }
      for i=1,#source do
        dump[#dump + 1] = source:byte(i,i)
      end

      local s = 'loadstring(\'\\' .. table.concat(dump, '\\') .. '\')()'
      print(s)
    end    
  elseif arguments.verbose then  
    print 'Skipping bytecode mutations.'
  end
end

do 
  local f = io.open(arguments.output, 'wb')
  f:write(source)
  f:close()

  if arguments.verbose and source:byte(1) ~= 27 then 
    print(
      '\n------------------\nOutput: \n------------------\n\n' 
      .. tostring(source) .. 
      '\n------------------')
  end
end