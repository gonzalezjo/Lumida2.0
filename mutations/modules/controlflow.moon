-- TODO: Sanity checks for setlist.
-- Known bugs: If you try running the forprepifier, it'll break. 

opcodes = require 'lib.opcodes'
table_print = require 'lib/table_print'

shift_down_array = (array) -> {k - 1, v for k, v in ipairs array}
repetitions = (x, scalar) -> scalar * (math.exp(-x * .8) * math.exp(-50 * math.exp(-26 * (x - 0.85))))
get_jumps = (min = 2, max = 6, scalar = 70, x = math.random! + 0.2) -> math.min(math.max(min, repetitions(x, 50)), max) -- EVD

obfuscate_proto = (proto, verbose) -> 
  ZERO = 131071

  print 'Beginning control flow obfuscation...' if verbose 

  process_proto = (proto, verbose) -> 
    print 'In process_proto' if verbose

    jumps, closures, old_positions, new_positions = {}, {}, {}, {} 
    old_instructions = {k + 1, v for k, v in pairs proto.code}
    new_instructions = [v for v in *old_instructions] 

    for i, instruction in ipairs old_instructions
      old_positions[instruction] = i

      switch instruction.OP
        when opcodes.EQ, opcodes.LT, opcodes.LE
          jumps[instruction] = 
            destination: old_instructions[i + old_instructions[i + 1].Bx - ZERO + 2], 
            fallthrough: old_instructions[i + 2]
        when opcodes.TEST, opcodes.TESTSET, opcodes.TFORLOOP
          jumps[instruction] = 
            destination: old_instructions[i + old_instructions[i + 1].Bx - ZERO + 2],
            fallthrough: old_instructions[i + 2]
        when opcodes.JMP, opcodes.FORPREP, opcodes.FORLOOP
          jumps[instruction] = old_instructions[i + instruction.Bx - ZERO + 1]
        when opcodes.CLOSURE
          instruction.preserve = true 
          for j = i + 1, #old_instructions
              switch old_instructions[i] -- technically 100% okay, vis a vis code generation of our targets
                when opcodes.GETUPVAL, opcodes.MOVE, opcodes.ADD, opcodes.SUB, opcodes.MUL, opcodes.DIV 
                  old_instructions[i].preserve = 1
                else 
                  old_instructions[i - 1].preserve = false
                  break
        when opcodes.CALL, opcodes.TAILCALL, opcodes.VARARG, opcodes.LOADBOOL
          if instruction.C == 0 
            with succ = old_instructions[i + 1]
              instruction.preserve = succ
              succ.preserve = true -- should make the meaning of true more explicit.

    with a = new_instructions -- every day im shuffling :doggodance: 
      for i = #a - 1, 1, -1   
        j = math.random i
        continue if a[i].preserve or a[j].preserve 
        a[i], a[j] = a[j], a[i]

    for i = #new_instructions, 1, -1
      continue if new_instructions[i].preserve_next
      for _ = 1, get_jumps!
        proto.sizecode += 1
        table.insert new_instructions, i, OP: opcodes.JMP, A: 0, Bx: ZERO + math.random -i + 1, #new_instructions - i

    new_instructions = shift_down_array new_instructions

    -- TODO: new_positions:get() can return *a* jump to an instruction. better if it can recursively follow jumps. full nesting, bb.
    for i, instruction in pairs new_instructions
      new_positions[instruction], new_positions[i] = i, instruction

    for i = #new_instructions - 1, 0, -1
      with instruction = new_instructions[i]
        continue if (instruction.OP == opcodes.JMP) and (not jumps[instruction]) -- skip jumps that weren't generated

        switch instruction.OP
          when opcodes.JMP, opcodes.FORLOOP, opcodes.FORPREP 
            instruction.Bx = ZERO -- presumably you can mess with this. i didn't. you can.

            switch instruction.OP 
              when opcodes.FORLOOP, opcodes.FORPREP
                target = new_positions[old_instructions[old_positions[instruction] + 1]] -- can simplify to jumps lookup
                instruction.Bx = ZERO + new_positions[jumps[instruction]] - (i + 1)
                new_instructions[i + 1].Bx = ZERO + (target - (i + 2))
              when opcodes.JMP 
                target = new_positions[jumps[instruction]]
                new_instructions[i + 1].Bx = ZERO + (target - (i + 2))
          when opcodes.TEST, opcodes.TESTSET, opcodes.TFORLOOP, opcodes.EQ, opcodes.LT, opcodes.LE
            {:fallthrough, :destination} = jumps[instruction]
            new_instructions[i + 1].Bx = ZERO + new_positions[destination] - (i + 2)
            new_instructions[i + 2].Bx = ZERO + new_positions[fallthrough] - (i + 3)
          else
            target = new_positions[old_instructions[old_positions[instruction] + 1]] -- can use jumps...

            if instruction.preserve and instruction.preserve ~= true 
              new_instructions[i + 1] = instruction.preserve
              new_instructions[i + 2].Bx = ZERO + (target - (i + 2))
            else
              new_instructions[i + 1].Bx = ZERO + (target - (i + 2))
              new_instructions[i + 2].Bx = ZERO 

    new_instructions[0].Bx = ZERO + new_positions[old_instructions[1]] - 1

    with p = proto 
      process_proto .p[i] for i = 0, .sizep - 1
      .sizelineinfo = 0
      .code = new_instructions

  process_proto proto 

(proto, verbose) ->
  with p = proto 
    obfuscate_proto p, verbose