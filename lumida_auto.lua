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
  local retstruct = LumidaCompiler.CompileToBytecode(src, #src)
  local bc = ffi.string(ffi.cast("void*", retstruct.str), retstruct.len)
  local chunk = bytecode_parser.decode_chunk(bc)
  ffi.C.free(retstruct)
  return chunk
end

local transformations = {
	'improveparsability',
    --'numbers',
    'pooling',
	'strings',
	
}
local mutations = {
	--'forprep',
	
    --'controlflow',
    --'spoofdebug',
}

local do_obfuscate = function(source)
    local obfuscators = {}
    
    do 
        obfuscators.ast = require 'transformations/transformations'
        obfuscators.bytecode = require 'mutations/mutations'
    end

    for _, v in ipairs(transformations) do 
        source = obfuscators.ast[v](source, verbose)
    end

    local compiler 
    compiler = require 'compiler'

    --print("after transformations: ", source)

    local proto = compile_source(source) --compiler.compile_to_proto(source, '=lumida')

    for _, v in ipairs(mutations) do 
        proto = obfuscators.bytecode[v](proto, verbose)
    end

    source = assert(compiler.compile_proto(proto), 'Failed to compile proto.')

    --print(#source)

    local built = "loadstring('"
    for i = 1, #source do
        built = built .. '\\' .. string.byte(source, i)
    end
    built = built .. "')()"
    return built


    --local s = 'loadstring(\'\\' .. table.concat(dump, '\\') .. '\')()'
    --return s

end

local str = io.read()
local obf = do_obfuscate(str)
print(obf)

--return obf