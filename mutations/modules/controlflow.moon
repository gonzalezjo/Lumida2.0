-- TODO: if two instructions do the same thing (i.e., two call 0 1 0s, then merge the instructions.)
-- TODO: Sanity checks for setlist.

-- Known bugs: Does not play well with FORPREPs 
-- If you run it twice on print(i) for i = 1, 10 you will get a forprep error.
-- If you try running the forprepifier, it'll break. 
-- ablobsigh

opcodes = require 'lib.opcodes'
table_print = require 'lib/table_print'

shift_down_array = (array) -> {k - 1, v for k, v in ipairs array}
repetitions = (x, scalar) -> scalar * (math.exp(-x * .8) * math.exp(-50 * math.exp(-26 * (x - 0.85))))
get_jumps = (min = 2, max = 2, scalar = 70, x = math.random()+0.2) -> math.min(math.max(min, repetitions(x, 50)), max)

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
        when opcodes.EQ, opcodes.LT, opcodes.LE, opcodes.TEST, opcodes.TESTSET
          jumps[instruction] = 
            fallthrough: old_instructions[i + old_instructions[i + 1].Bx - ZERO], 
            destination: old_instructions[i + 2]
        when opcodes.JMP
          jumps[instruction] = {old_instructions[i + instruction.Bx - ZERO]}
        when opcodes.FORPREP, opcodes.FORLOOP
          jumps[instruction] = {old_instructions[i + instruction.Bx - ZERO + 1]}
          print(old_instructions[i + instruction.Bx - ZERO + 1].OP, 'OP')
        when opcodes.CLOSURE
          instruction.preserve_next = true 
          closures[i] = true -- possible bug?
          closures[instruction] = for i = i + 1, #old_instructions
              switch old_instructions[i] -- technically 100% okay, vis a vis code generation of our targets
                when opcodes.GETUPVAL, opcodes.MOVE, opcodes.ADD, opcodes.SUB, opcodes.MUL, opcodes.DIV 
                  closures[i] = true
                  old_instructions[i]
                else 
                  break
        when opcodes.CALL, opcodes.TAILCALL
          if instruction.C == 0 
            with _ = old_instructions[i + 1]
              instruction.preserve = _
              .preserve = true

    with a = new_instructions           
      for i = #a - 1, 1, -1   
        j = math.random i
        continue if a[i].preserve or a[j].preserve 
        a[i], a[j] = a[j], a[i]

    for i = #new_instructions, 1, -1
      continue if new_instructions[i].preserve_next
      for _ = 1, get_jumps!
        proto.sizecode += 1
        table.insert new_instructions, i, OP: opcodes.JMP, A: 0, Bx: ZERO + math.random(-i + 1, #new_instructions - i)

    new_instructions = shift_down_array new_instructions

    for i, instruction in pairs new_instructions -- TODO: new_positions:get() can return *a* jump to an instruction: full nesting, bb.
      new_positions[instruction], new_positions[i] = i, instruction

    for i = #new_instructions - 1, 0, -1
      with instruction = new_instructions[i]
        continue if (instruction.OP == opcodes.JMP) and (not jumps[instruction])

        switch instruction.OP
          when opcodes.JMP, opcodes.FORLOOP, opcodes.FORPREP 
            unless instruction.tampered
              instruction.Bx = ZERO + new_positions[old_instructions[old_positions[instruction] + 1]] - (i + 1)
            if (instruction.OP == opcodes.FORLOOP) or (instruction.OP == opcodes.FORPREP) 
              instruction.Bx = ZERO + new_positions[jumps[instruction][1]] - (i + 1)

            target = new_positions[old_instructions[old_positions[instruction] + 1]]
            new_instructions[i + 1].Bx = ZERO + (target - (i + 2)) unless new_instructions[i + 1].preserve_next         
          when opcodes.EQ, opcodes.LT, opcodes.LE
            {:fallthrough, :destination} = jumps[instruction]
            new_instructions[i + 1].Bx = ZERO + new_positions[fallthrough] - (i + 2)
            new_instructions[i + 1].tampered = true
            new_instructions[i + 2].Bx = ZERO + new_positions[destination] - (i + 3)
          when opcodes.TEST, opcodes.TESTSET
            {:fallthrough, :destination} = jumps[instruction]
            new_instructions[i + 1].Bx = ZERO + new_positions[destination] - (i + 1)
            new_instructions[i + 1].tampered = true
            new_instructions[i + 2].Bx = ZERO + new_positions[fallthrough] - (i + 2)
            new_instructions[i + 2].tampered = true
          else
            target = new_positions[old_instructions[old_positions[instruction] + 1]]

            if instruction.preserve and instruction.preserve ~= true 
              new_instructions[i + 1] = instruction.preserve
              new_instructions[i + 2].Bx = ZERO + (target - (i + 3))
            else 
              new_instructions[i + 1].Bx = ZERO
              new_instructions[i + 2].Bx = ZERO + (target - (i + 3))


    new_instructions[0].Bx = ZERO + new_positions[old_instructions[1]] - 1

    with p = proto 
      process_proto .p[i] for i = 0, .sizep - 1
      .sizelineinfo = 0
      .code = new_instructions

  process_proto proto 

(proto, verbose) ->
  with p = proto 
    obfuscate_proto p, verbose
