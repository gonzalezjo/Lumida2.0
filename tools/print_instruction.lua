assert(jit, 'LuaJIT required. Aborting')

local ffi = require 'ffi'
local instructions = require 'bytecode.decoder'
local number = io.read('n')

do 
  local instruction = ffi.cast('uint32_t', number)
  local decoded = instructions.decode(instruction, ffi.sizeof(instruction))
  print(string.format('Name: %s\nA: %s\nB: %s\nC: %s\nBx: %s', 
      decoded.opcode.name,
      tostring(decoded.operands.a),
      tostring(decoded.operands.b),
      tostring(decoded.operands.c or 'NaN'),
      tostring(decoded.operands.b)))
end