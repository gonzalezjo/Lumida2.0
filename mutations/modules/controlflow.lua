local function obfuscate_proto(proto)
  local function shuffle(t)
    local rand = math.random 
    assert(t, "table.shuffle() expected a table, got nil")
    local iterations = #t
    local j

    for i = iterations, 2, -1 do
      j = rand(i)
      t[i], t[j] = t[j], t[i]
    end
  end

  local function fix_table(t)
    local temp = {}
    for i=1, #t do
      temp[i - 1] = t[i]
    end
    return temp
  end

  local function process_proto(p)
    math.randomseed(os.time())

    local code_insts = {}

    local code_add = 0

    for i = 0, p.sizecode - 1 do
      local inst = p.code[i]
      table.insert(code_insts, { original_pc = i, inst = inst })
    end

    local real_pos = {}

    shuffle(code_insts)
    local new_code = {}
    for i= 1, #code_insts do
      table.insert(new_code, {
        OP = 22,
        A = 0,
        Bx = 131071
      })
    end

    local to_fix = {}

    local get_jmp_pos = function(real)
      for i, v in next, code_insts do
        if v.original_pc == real then
          return i - 1
        end
      end
      return 0
    end

    local get_remap_pos = function(real)
      for i, v in next, code_insts do
        if v.original_pc == real then
          return v.new_pc
        end
      end
      return 0
    end

    for i= 1, #code_insts do
      local inst_info = code_insts[i]
      table.insert(new_code, inst_info.inst)
      inst_info.new_pc = #new_code - 1

      if i ~= #code_insts then
        local realpos = #code_insts - (#code_insts - (i - 1))
        --to_fix[realpos] = 

        table.insert(new_code, {
          OP = 22,
          A = 0,
          Bx = 131071 - ((#new_code + 1) - get_jmp_pos(inst_info.original_pc + 1))
        })
      end
    end

    new_code[1].Bx = 131071 + (get_remap_pos(0) - 1)

    for i = 2, #code_insts do
      local inst = new_code[i]
      local inst_info = code_insts[i]
      inst.Bx = 131071 + (get_remap_pos(inst_info.original_pc) - i)
    end

    --[[table.insert(new_code, {
      OP = 30,
      A = 0,
      B = 1,
      C = 0
    })]]

    p.sizecode = #new_code
    p.code = fix_table(new_code)
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