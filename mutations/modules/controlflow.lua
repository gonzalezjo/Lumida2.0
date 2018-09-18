local function obfuscate_proto(proto)
  local function shuffle(t)
    assert(type(t) == 'table', 'table.shuffle() expected a table.')
    
    for i = #t, 2, -1 do
      local j = math.random(i)
      t[i], t[j] = t[j], t[i]
    end
  end

  local function zero_indexed(t)
    local temp = {}

    for i = 1, #t do
      temp[i - 1] = t[i]
    end

    return temp
  end

  local function process_proto(p)
    local instructions = {}
    local new_instructions = {}
    local real_pos = {}
    local to_fix = {}

    -- Initialize instructions
    do 
      for i = 0, p.sizecode - 1 do
        table.insert(instructions, { 
          original_pc = i, 
          inst = p.code[i] 
        })
      end

      shuffle(instructions)
    end

    -- Initialize new_instructions.
    do 
      for i = 1, #instructions do
        -- Jump
        table.insert(new_instructions, {
          OP = 22,
          A = 0,
          Bx = 131071
        })
      end
    end

    local get_jmp_pos = function(real)
      for i, v in pairs(instructions) do
        if v.original_pc == real then
          return i - 1
        end
      end
    end

    local get_remap_pos = function(real)
      for i, v in pairs(instructions) do
        if v.original_pc == real then
          return v.new_pc
        end
      end
    end

    for i= 1, #instructions do
      local inst_info = instructions[i]
      table.insert(new_instructions, inst_info.inst)
      inst_info.new_pc = #new_instructions - 1

      if i ~= #instructions then
        local realpos = #instructions - (#instructions - (i - 1))

        table.insert(new_instructions, {
          OP = 22,
          A = 0,
          Bx = 131071 - ((#new_instructions + 1) - get_jmp_pos(inst_info.original_pc + 1))
        })
      end
    end

    new_instructions[1].Bx = 131071 + (get_remap_pos(0) - 1)

    for i = 2, #instructions do
      local inst = new_instructions[i]
      local inst_info = instructions[i]
      inst.Bx = 131071 + (get_remap_pos(inst_info.original_pc) - i)
    end

    p.sizecode = #new_instructions
    p.code = zero_indexed(new_instructions)
    p.sizelineinfo = 0


    for i = 0, p.sizep - 1 do
      process_proto(p.p[i])
    end
  end

  process_proto(proto)

  return proto
end

return function(proto, verbose)
  local table_print = require 'lib/table_print'

  obfuscate_proto(proto)

  if verbose then 
    table_print(proto)
  end

  return proto
end