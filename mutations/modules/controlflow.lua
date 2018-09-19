local opcodes = require('lib.opcodes')
local table_print = require('lib/table_print')
local shift_down_array
shift_down_array = function(array)
  local _tbl_0 = { }
  for k, v in ipairs(array) do
    _tbl_0[k - 1] = v
  end
  return _tbl_0
end
local repetitions
repetitions = function(x, scalar)
  return scalar * (math.exp(-x * .8) * math.exp(-50 * math.exp(-26 * (x - 0.85))))
end
local get_jumps
get_jumps = function(min, max, scalar, x)
  if min == nil then
    min = 2
  end
  if max == nil then
    max = 1
  end
  if scalar == nil then
    scalar = 50
  end
  if x == nil then
    x = math.random()
  end
  return math.min(math.max(min, repetitions(x, 50)), max)
end
local obfuscate_proto
obfuscate_proto = function(proto, verbose)
  math.randomseed(1337)
  if verbose then
    print('Beginning control flow obfuscation...')
  end
  local process_proto
  process_proto = function(proto, verbose)
    if verbose then
      print('In process_proto')
    end
    local jumps, closures, old_positions, new_positions = { }, { }, { }, { }
    local old_instructions
    do
      local _tbl_0 = { }
      for k, v in pairs(proto.code) do
        _tbl_0[k + 1] = v
      end
      old_instructions = _tbl_0
    end
    local new_instructions
    do
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #old_instructions do
        local v = old_instructions[_index_0]
        _accum_0[_len_0] = v
        _len_0 = _len_0 + 1
      end
      new_instructions = _accum_0
    end
    print(#old_instructions, #new_instructions)
    for i, instruction in ipairs(old_instructions) do
      old_positions[instruction] = i
      local _exp_0 = instruction.OP
      if opcodes.EQ == _exp_0 or opcodes.LT == _exp_0 or opcodes.LE == _exp_0 or opcodes.TEST == _exp_0 or opcodes.TESTSET == _exp_0 then
        jumps[instruction] = {
          old_instructions[i + old_instructions[i + 1].Bx],
          old_instructions[i + 2]
        }
      elseif opcodes.JMP == _exp_0 or opcodes.FORLOOP == _exp_0 or opcodes.FORPREP == _exp_0 then
        jumps[instruction] = {
          old_instructions[i - instruction.Bx]
        }
      elseif opcodes.CLOSURE == _exp_0 then
        closures[i] = true
        do
          local _accum_0 = { }
          local _len_0 = 1
          for i = i + 1, #old_instructions do
            local _exp_1 = old_instructions[i]
            if opcodes.GETUPVAL == _exp_1 or opcodes.MOVE == _exp_1 or opcodes.ADD == _exp_1 or opcodes.SUB == _exp_1 or opcodes.MUL == _exp_1 or opcodes.DIV == _exp_1 then
              closures[i] = true
              _accum_0[_len_0] = old_instructions[i]
            else
              break
            end
            _len_0 = _len_0 + 1
          end
          closures[instruction] = _accum_0
        end
      end
    end
    do
      local a = new_instructions
      for i = #a - 1, 1, -1 do
        local _continue_0 = false
        repeat
          if closures[i] then
            _continue_0 = true
            break
          end
          local j = math.random(i)
          a[i], a[j] = a[j], a[i]
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
    end
    for i = #new_instructions, 1, -1 do
      local _continue_0 = false
      repeat
        if closures[i] then
          _continue_0 = true
          break
        end
        for _ = 1, get_jumps() do
          proto.sizecode = proto.sizecode + 1
          table.insert(new_instructions, i, {
            OP = opcodes.JMP,
            A = 0,
            Bx = 131071
          })
        end
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    new_instructions = shift_down_array(new_instructions)
    for i, instruction in pairs(new_instructions) do
      new_positions[instruction], new_positions[i] = i, instruction
    end
    for i = 1, #old_instructions - 1 do
      do
        local instruction = old_instructions[i]
        local current_position = new_positions[instruction]
        local next_instruction_to_execute = old_instructions[i + 1]
        local jump_target = new_positions[next_instruction_to_execute]
        print('Current position: ' .. current_position)
        print('Jumping to position: ' .. jump_target)
        new_instructions[current_position + 1].Bx = jump_target + 131070 - (current_position + 1)
      end
    end
    print(new_instructions[0].Bx)
    if verbose then
      print('Old table: ')
      print('New table:')
    end
    do
      local p = proto
      for i = 0, p.sizep - 1 do
        process_proto(p.p[i])
      end
      p.sizelineinfo = 0
      p.code = new_instructions
      return p
    end
  end
  return process_proto(proto)
end
return function(proto, verbose)
  do
    local p = proto
    obfuscate_proto(p, verbose)
    return p
  end
end
