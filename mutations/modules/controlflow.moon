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
        when opcodes.EQ, opcodes.LT, opcodes.LE
          jumps[instruction] = 
            fallthrough: old_instructions[i + old_instructions[i + 1].Bx - ZERO + 1], 
            destination: old_instructions[i + 2]
        when opcodes.TEST, opcodes.TESTSET
          jumps[instruction] = 
            destination: old_instructions[i + old_instructions[i + 1].Bx - ZERO + 1], 
            fallthrough: old_instructions[i + 2]
        when opcodes.JMP
          jumps[instruction] = {old_instructions[i + instruction.Bx - ZERO]}
        when opcodes.FORPREP, opcodes.FORLOOP
          jumps[instruction] = {old_instructions[i + instruction.Bx - ZERO + 1]}
          print(old_instructions[i + instruction.Bx - ZERO + 1].OP, 'OP')
        when opcodes.CLOSURE
          instruction.preserve = 0
          for j = i + 1, #old_instructions
              switch old_instructions[i] -- technically 100% okay, vis a vis code generation of our targets
                when opcodes.GETUPVAL, opcodes.MOVE, opcodes.ADD, opcodes.SUB, opcodes.MUL, opcodes.DIV 
                  old_instructions[i].preserve = 1
                else 
                  old_instructions[i - 1].preserve = nil unless old_instructions[i - 1].preserve == 0
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
        -- proto.sizelineinfo += 1
        table.insert new_instructions, i, OP: opcodes.JMP, A: 0, Bx: ZERO + math.random(-i + 1, #new_instructions - i)

    new_instructions = shift_down_array new_instructions

    -- TODO: new_positions:get() can return *a* jump to an instruction. better if it can recursively follow jumps. full nesting, bb.
    for i, instruction in pairs new_instructions
      new_positions[instruction], new_positions[i] = i, instruction

    for i = #new_instructions - 1, 0, -1
      with instruction = new_instructions[i]
        continue if (instruction.OP == opcodes.JMP) and (not jumps[instruction])

        switch instruction.OP
          when opcodes.JMP, opcodes.FORLOOP, opcodes.FORPREP 
            unless instruction.tampered -- is this even needed?
              instruction.Bx = ZERO + new_positions[old_instructions[old_positions[instruction] + 1]] - (i + 1)
            if (instruction.OP == opcodes.FORLOOP) or (instruction.OP == opcodes.FORPREP) 
              instruction.Bx = ZERO + new_positions[jumps[instruction][1]] - (i + 1)

            target = new_positions[old_instructions[old_positions[instruction] + 1]]
            new_instructions[i + 1].Bx = ZERO + (target - (i + 2)) unless new_instructions[i + 1].preserve_next         
          when opcodes.EQ, opcodes.LT, opcodes.LE
            {:fallthrough, :destination} = jumps[instruction]
            new_instructions[i + 1].Bx = ZERO + new_positions[fallthrough] - (i + 2)
            new_instructions[i + 1].tampered = true -- pretty sure tamper stuff is unnecessary.
            new_instructions[i + 2].Bx = ZERO + new_positions[destination] - (i + 3)
            new_instructions[i + 2].tampered = true
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
      .sizelineinfo = .sizecode
      .code = new_instructions

  process_proto proto 

(proto, verbose) ->
  with p = proto 
    obfuscate_proto p, verbose

  -- 1 [1] LOADK     0 -2  ; 7
  -- 2 [1] SETGLOBAL 0 -1  ; x
  -- 3 [2] GETGLOBAL 0 -3  ; print
  -- 4 [2] GETGLOBAL 1 -1  ; x
  -- 5 [2] LT        0 1 -4  ; - 6
  -- 6 [2] JMP       3 ; to 10
  -- 7 [2] LOADK     1 -5  ; 1
  -- 8 [2] TEST      1 0 1
  -- 9 [2] JMP       1 ; to 11
  -- 10  [2] LOADK     1 -6  ; 2
  -- 11  [2] CALL      0 2 1
  -- 12  [2] RETURN    0 1
