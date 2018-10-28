local ZERO, opcodes = 131071, require('lib.opcodes')
local shift_down_array
shift_down_array = function(array)
  for i = 1, #array + 1 do
    array[i - 1] = array[i]
  end
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
    max = 6
  end
  if scalar == nil then
    scalar = 70
  end
  if x == nil then
    x = math.random() + 0.2
  end
  return math.min(math.max(min, repetitions(x, 50)), max)
end
local populate_metadata
populate_metadata = function(old_instructions, old_positions, jumps)
  for i, instruction in ipairs(old_instructions) do
    old_positions[instruction] = i
    local _exp_0 = instruction.OP
    if opcodes.EQ == _exp_0 or opcodes.LT == _exp_0 or opcodes.LE == _exp_0 then
      jumps[instruction] = {
        destination = old_instructions[(i + 2) + (old_instructions[i + 1].Bx - ZERO)],
        fallthrough = old_instructions[(i + 2)]
      }
    elseif opcodes.TEST == _exp_0 or opcodes.TESTSET == _exp_0 or opcodes.TFORLOOP == _exp_0 then
      jumps[instruction] = {
        destination = old_instructions[(i + 2) + (old_instructions[i + 1].Bx - ZERO)],
        fallthrough = old_instructions[(i + 2)]
      }
    elseif opcodes.JMP == _exp_0 or opcodes.FORPREP == _exp_0 or opcodes.FORLOOP == _exp_0 then
      jumps[instruction] = old_instructions[(i + 1) + (instruction.Bx - ZERO)]
    elseif opcodes.CLOSURE == _exp_0 then
      instruction.preserve = true
      for j = i + 1, #old_instructions do
        local _exp_1 = old_instructions[i]
        if opcodes.GETUPVAL == _exp_1 or opcodes.MOVE == _exp_1 or opcodes.ADD == _exp_1 or opcodes.SUB == _exp_1 or opcodes.MUL == _exp_1 or opcodes.DIV == _exp_1 then
          old_instructions[i].preserve = 1
        else
          old_instructions[i - 1].preserve = false
          break
        end
      end
    elseif opcodes.CALL == _exp_0 or opcodes.TAILCALL == _exp_0 or opcodes.VARARG == _exp_0 or opcodes.LOADBOOL == _exp_0 or opcodes.SETLIST == _exp_0 then
      if instruction.C == 0 then
        do
          local succ = old_instructions[i + 1]
          succ.setlist_casted, succ.preserve = (instruction.OP == opcodes.SETLIST), true
          instruction.preserve, instruction.setlist_next = succ, true
        end
      end
    end
  end
end
local shuffle
shuffle = function(array)
  do
    local a = array
    for i = #a - 1, 1, -1 do
      local _continue_0 = false
      repeat
        local j = math.random(i)
        if a[i].preserve or a[j].preserve then
          _continue_0 = true
          break
        end
        a[i], a[j] = a[j], a[i]
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    return a
  end
end
local add_jumps
add_jumps = function(new_instructions, proto)
  local replacement, len = { }, #new_instructions
  for i = 1, #new_instructions do
    local instruction = new_instructions[i]
    if not instruction.preserve_next then
      for _ = 1, get_jumps() do
        table.insert(replacement, {
          OP = opcodes.JMP,
          A = 0,
          Bx = ZERO + math.random(-i + 1, len - i - 1)
        })
      end
    end
    table.insert(replacement, instruction)
  end
  for i, v in ipairs(replacement) do
    new_instructions[i] = v
  end
end
local populate_translation_tables
populate_translation_tables = function(new_instructions, new_positions)
  for i, instruction in pairs(new_instructions) do
    new_positions[instruction], new_positions[i] = i, instruction
  end
end
local translate_instructions
translate_instructions = function(args)
  local new_instructions, new_positions, old_positions, old_instructions, jumps
  new_instructions, new_positions, old_positions, old_instructions, jumps = args.new_instructions, args.new_positions, args.old_positions, args.old_instructions, args.jumps
  local sizecode = #new_instructions
  for i = sizecode - 1, 0, -1 do
    do
      local instruction = new_instructions[i]
      if not (instruction.setlist_casted or ((instruction.OP == opcodes.JMP) and (not jumps[instruction]))) then
        local _exp_0 = instruction.OP
        if opcodes.JMP == _exp_0 or opcodes.FORLOOP == _exp_0 or opcodes.FORPREP == _exp_0 then
          instruction.Bx = ZERO
          local target = new_positions[jumps[instruction]]
          if instruction.OP ~= opcodes.JMP then
            instruction.Bx = ZERO + new_positions[jumps[instruction]] - (i + 1)
          end
          new_instructions[i + 1].Bx = ZERO + (target - (i + 2))
        elseif opcodes.TEST == _exp_0 or opcodes.TESTSET == _exp_0 or opcodes.TFORLOOP == _exp_0 or opcodes.EQ == _exp_0 or opcodes.LT == _exp_0 or opcodes.LE == _exp_0 then
          local fallthrough, destination
          do
            local _obj_0 = jumps[instruction]
            fallthrough, destination = _obj_0.fallthrough, _obj_0.destination
          end
          new_instructions[i + 1].Bx = ZERO + new_positions[destination] - (i + 2)
          new_instructions[i + 2].Bx = ZERO + new_positions[fallthrough] - (i + 3)
        else
          local target = new_positions[old_instructions[old_positions[instruction] + 1]]
          if instruction.preserve and instruction.preserve ~= true then
            new_instructions[i + 1] = instruction.preserve
            new_instructions[i + 2].Bx = ZERO + (target - (i + 2))
          else
            new_instructions[i + 1].Bx = ZERO + (target - (i + 2))
            new_instructions[i + 2].Bx = ZERO
          end
        end
      end
      if instruction.preserve and instruction.setlist_next then
        new_instructions[i + 1] = instruction.preserve
      end
    end
    new_instructions[0].Bx = ZERO + new_positions[old_instructions[1]] - 1
  end
end
local obfuscate_proto
obfuscate_proto = function(proto, verbose)
  if verbose then
    print('Beginning control flow obfuscation...')
  end
  local process_proto
  process_proto = function(proto, verbose)
    if verbose then
      print('In process_proto')
    end
    local jumps, old_positions, new_positions = { }, { }, { }
    local old_instructions
    do
      local _tbl_0 = { }
      for k, v in pairs(proto.code) do
        _tbl_0[k + 1] = v
      end
      old_instructions = _tbl_0
    end
    proto.code = nil
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
    populate_metadata(old_instructions, old_positions, jumps)
    shuffle(new_instructions)
    add_jumps(new_instructions, proto)
    shift_down_array(new_instructions)
    populate_translation_tables(new_instructions, new_positions)
    translate_instructions({
      new_instructions = new_instructions,
      new_positions = new_positions,
      old_positions = old_positions,
      old_instructions = old_instructions,
      jumps = jumps
    })
    do
      local p = proto
      for i = 0, p.sizep - 1 do
        process_proto(p.p[i])
      end
      p.sizelineinfo = 0
      p.code = new_instructions
      p.sizecode = #p.code + 1
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
