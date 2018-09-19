opcodes = require 'lib.opcodes'
table_print = require 'lib/table_print'

shift_down_array = (array) -> {k - 1, v for k, v in ipairs array}
repetitions = (x, scalar) -> scalar * (math.exp(-x * .8) * math.exp(-50 * math.exp(-26 * (x - 0.85))))
get_jumps = (min = 2, max = 1, scalar = 50, x = math.random()) -> math.min(math.max(min, repetitions x, 50), max)

obfuscate_proto = (proto, verbose) -> 
  math.randomseed 1337

  print 'Beginning control flow obfuscation...' if verbose 

  process_proto = (proto, verbose) -> 
    print 'In process_proto' if verbose

    jumps, closures, old_positions, new_positions = {}, {}, {}, {} 
    old_instructions = {k + 1, v for k, v in pairs proto.code}
    new_instructions = [v for v in *old_instructions] 

    print(#old_instructions, #new_instructions)
    for i, instruction in ipairs old_instructions
      old_positions[instruction] = i

      switch instruction.OP
        when opcodes.EQ, opcodes.LT, opcodes.LE, opcodes.TEST, opcodes.TESTSET
          jumps[instruction] = {old_instructions[i + old_instructions[i + 1].Bx], old_instructions[i + 2]}
        when opcodes.JMP, opcodes.FORLOOP, opcodes.FORPREP
          jumps[instruction] = {old_instructions[i - instruction.Bx]}
        when opcodes.CLOSURE
          closures[i] = true
          closures[instruction] = for i = i + 1, #old_instructions
              switch old_instructions[i] -- technically 100% okay, vis a vis code generation of our targets
                when opcodes.GETUPVAL, opcodes.MOVE, opcodes.ADD, opcodes.SUB, opcodes.MUL, opcodes.DIV 
                  closures[i] = true
                  old_instructions[i]
                else 
                  break

    -- Why #a - 1? It's simple. The last instruction is a return. We are *not* moving that.
    -- Or is it? Might be a subtle off by one, since apparently without the - 1, it worked for you?
    with a = new_instructions           
      -- for i = #a - 1, 1, -1   
      for i = #a - 1, 1, -1   
        continue if closures[i] 
        j = math.random i
        a[i], a[j] = a[j], a[i]

    for i = #new_instructions, 1, -1
      continue if closures[i]
      for _ = 1, get_jumps!
        proto.sizecode += 1
        table.insert new_instructions, i, OP: opcodes.JMP, A: 0, Bx: 131071 -- + math.random(-i + 1, #new_instructions - 1)

    new_instructions = shift_down_array new_instructions

    for i, instruction in pairs new_instructions
      new_positions[instruction], new_positions[i] = i, instruction

    -- 131071 = 0 

    -- for i = 1, #old_instructions - 1
    --   with instruction = old_instructions[i]
    --     -- switch instruction.OP 
    --     --   when false 
    --     --     print 'false.'
    --     --   else 
    --     current_position = new_positions[instruction]
    --     next_instruction_to_execute = old_instructions[i + 1]
    --     jump_target = new_positions[next_instruction_to_execute]
    --     print 'Current position: ' .. current_position
    --     print 'Jumping to position: ' .. jump_target

    --     new_instructions[current_position + 1].Bx = jump_target + 131071 - (current_position + 1)


    for i = #new_instructions - 1, 0, -1
      with instruction = new_instructions[i]
        continue if (instruction.OP == opcodes.JMP) and (not jumps[instruction])

        switch instruction.OP
          when opcodes.JMP, opcodes.FORLOOP, opcodes.FORPREP 
            assert(false, 'Should not run.')
            instruction.Bx = 131071 + new_positions[old_instructions[old_positions[instruction] + 1]] - (i + 1)
          when opcodes.EQ, opcodes.LT, opcodes.LE, opcodes.TEST, opcodes.TESTSET
            assert(false, 'Should not run.')
            {fallthrough, destination} = jumps[instruction]
            new_instructions[i + 1].Bx = 131071 + new_positions[fallthrough] - (i + 1)
            new_instructions[i + 2].Bx = 131071 + new_positions[destination] - (i + 2)
          else
            target = new_positions[old_instructions[old_positions[instruction] + 1]]
            print instruction.OP, 'awaaa'
            print old_positions[instruction] + 1
            print(target, 'New location.')
            new_instructions[i + 1].Bx = 131071 + (target - (i + 2))

    new_instructions[0].Bx = 131071 = new_positions[old_positions[0]] + 131071

    if verbose
      print 'Old table: '
      -- table_print old_instructions
      print 'New table:'
      -- table_print new_instructions

    with p = proto 
      process_proto .p[i] for i = 0, .sizep - 1
      .sizelineinfo = 0
      .code = new_instructions

  process_proto proto 

(proto, verbose) ->
  with p = proto 
    obfuscate_proto p, verbose
    -- table_print p if verbose