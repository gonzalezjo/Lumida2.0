-- Convert OP_JMPs to OP_FORPREPs using black magic.

local function obfuscate_proto(pr)
  local function process_proto(p)
    local has_jump = false

    for i = 0, p.sizecode - 1 do
      local inst = p.code[i]

      if i ~= 0 then
        local last_op = p.code[i - 1].OP

        -- Explanation: TEST related instructions expect a JMP to follow them. We must skip protos with these instructions. 
        if inst.OP == 22 and (last_op ~= 23 and last_op ~= 24 and last_op ~= 25 and last_op ~= 26 and last_op ~= 27) then
          has_jump = true
          break
        end
      end
    end

    if has_jump then
      if p.k[0] ~= nil then
        table.insert(p.k, { value = 0 })
      else
        table.insert(p.k, 0, { value = 0 })
      end

      p.sizek = p.sizek + 1
      p.maxstacksize = p.maxstacksize + 3

      table.insert(p.code, 0, {
        OP = 1,
        A = p.maxstacksize - 3,
        Bx = p.sizek - 1
        })

      table.insert(p.code, 1, {
        OP = 1,
        A = p.maxstacksize - 2,
        Bx = p.sizek - 1
        })

      table.insert(p.code, 2, {
        OP = 1,
        A = p.maxstacksize - 1,
        Bx = p.sizek - 1
        })

      p.sizecode = p.sizecode + 3

      for i = 0, p.sizecode - 1 do
        local inst = p.code[i]

        if i ~= 0 then
          local last_op = p.code[i - 1].OP

          -- Once again, we skip the TEST related instructions. 
          if inst.OP == 22 and (last_op ~= 23 and last_op ~= 24 and last_op ~= 25 and last_op ~= 26 and last_op ~= 27) then
            p.code[i] = {
              OP = 32,
              A = p.maxstacksize - 3,
              Bx = inst.Bx
            }
          end
        end
      end

      p.maxstacksize = p.maxstacksize + 1
    end

    p.sizelineinfo = p.sizecode

    local new_lineinfo = {}
    for i = 1, p.sizelineinfo do
      new_lineinfo[i - 1] = math.random(9999)
    end

    p.lineinfo = new_lineinfo

    for i = 0, p.sizep - 1 do
      process_proto(p.p[i])
    end
  end

  process_proto(pr)
end

obfuscate_proto(proto)

return function(proto, verbose)
  local table_print = require 'lib/table_print.lua' -- for ~~smashing~~ printing the protos

  obfuscate_proto(proto)

  if verbose then 
    table_print(proto)
  end

  return proto
end

local bc = compiler.compile_proto(proto)
print(bc)

local built = ""
for i=1, #bc do
  built = built .. "\\" .. string.byte(bc, i)
end
print(built)
print(loadstring(bc))