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
    math.randomseed ZERO

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
        when opcodes.TFORLOOP
          jumps[instruction] = 
            destination: old_instructions[i + old_instructions[i + 1].Bx - ZERO + 2], -- wut
            fallthrough: old_instructions[i + 2]
        when opcodes.JMP
          jumps[instruction] = old_instructions[i + instruction.Bx - ZERO + 1]
        when opcodes.FORPREP, opcodes.FORLOOP
          jumps[instruction] = old_instructions[i + instruction.Bx - ZERO + 1]
          print(old_instructions[i + instruction.Bx - ZERO + 1].OP, 'OP')
        when opcodes.CLOSURE
          instruction.preserve = true 
          for j = i + 1, #old_instructions
              switch old_instructions[i] -- technically 100% okay, vis a vis code generation of our targets
                when opcodes.GETUPVAL, opcodes.MOVE, opcodes.ADD, opcodes.SUB, opcodes.MUL, opcodes.DIV 
                  old_instructions[i].preserve = 1
                else 
                  old_instructions[i - 1].preserve = false
                  break
        when opcodes.CALL, opcodes.TAILCALL, opcodes.VARARG
          if instruction.C == 0 
            with succ = old_instructions[i + 1]
              instruction.preserve = succ
              -- succ.preserve = true

    with a = new_instructions -- every day im shuffling :doggodance: 
      for i = #a - 1, 1, -1   
        j = math.random i
        continue if a[i].preserve or a[j].preserve 
        a[i], a[j] = a[j], a[i]

    for i = #new_instructions, 1, -1
      continue if new_instructions[i].preserve_next
      for _ = 1, get_jumps!
        proto.sizecode += 1
        table.insert new_instructions, i, OP: opcodes.JMP, A: 0, Bx: ZERO --+ math.random(-i + 1, #new_instructions - i)

    new_instructions = shift_down_array new_instructions

    -- TODO: new_positions:get() can return *a* jump to an instruction. better if it can recursively follow jumps. full nesting, bb.
    -- TODO: Test test, testset, tforloop.
    for i, instruction in pairs new_instructions
      new_positions[instruction], new_positions[i] = i, instruction

    for i = #new_instructions - 1, 0, -1
      with instruction = new_instructions[i]
        continue if (instruction.OP == opcodes.JMP) and (not jumps[instruction]) -- skip jumps that weren't generated
        continue if instruction.skip -- removable..

        switch instruction.OP
          when opcodes.JMP, opcodes.FORLOOP, opcodes.FORPREP 
            unless instruction.tampered -- is this even needed? affects the buggy instruction. 
              -- old: 
              -- instruction.Bx = ZERO + new_positions[old_instructions[old_positions[instruction] + 1]] - (i + 1)
              -- new: 
              instruction.Bx = ZERO -- + new_positions[old_instructions[old_positions[instruction] + 1]] - (i + 1)
              -- instruction.Bx = ZERO + new_positions[old_instructions[old_positions[instruction] + 1]] - (i + 1)

            switch instruction.OP 
              when opcodes.FORLOOP, opcodes.FORPREP  
                instruction.Bx = ZERO + new_positions[jumps[instruction]] - (i + 1)
                -- possibly not necessary...
                target = new_positions[old_instructions[old_positions[instruction] + 2]]
                new_instructions[i + 1].Bx = ZERO + (target - (i + 2)) unless new_instructions[i + 1].preserve_next
              when opcodes.JMP 
                target = new_positions[jumps[instruction]]
                new_instructions[i + 1].Bx = ZERO + (target - (i + 2)) unless new_instructions[i + 1].preserve_next

          when opcodes.EQ, opcodes.LT, opcodes.LE
            {:fallthrough, :destination} = jumps[instruction]
            new_instructions[i + 1].Bx = ZERO + new_positions[fallthrough] - (i + 2)
            new_instructions[i + 1].tampered = true -- pretty sure tamper stuff is unnecessary.
            new_instructions[i + 2].Bx = ZERO + new_positions[destination] - (i + 3)
            new_instructions[i + 2].tampered = true
          when opcodes.TEST, opcodes.TESTSET -- deep thonk
            {:fallthrough, :destination} = jumps[instruction]
            new_instructions[i + 1].Bx = ZERO + new_positions[destination] - (i + 1) -- probably bad
            new_instructions[i + 1].tampered = true
            new_instructions[i + 2].Bx = ZERO + new_positions[fallthrough] - (i + 2)
            new_instructions[i + 2].tampered = true
          when opcodes.TFORLOOP
            {:fallthrough, :destination} = jumps[instruction]

            -- Destination; BAD
            new_instructions[i + 1].Bx = ZERO + new_positions[destination] - (i + 2)
            new_instructions[i + 1].tampered = true
            -- new_instructions[i + 1].Bx = ZERO + new_positions[jumps[instruction]] - (i + 2)
            -- new_instructions[i + 1].tampered = true

            -- Fallthrough; OK 
            new_instructions[i + 2].Bx = ZERO + new_positions[fallthrough] - (i + 3)
            new_instructions[i + 2].tampered = true            
          else
            target = new_positions[old_instructions[old_positions[instruction] + 1]]

            if instruction.preserve and instruction.preserve ~= true 
              new_instructions[i + 1] = instruction.preserve
              new_instructions[i + 2].Bx = ZERO + (target - (i + 2))
              -- old
              -- new_instructions[i + 2].Bx = ZERO + (target - (i + 3))
            else
              new_instructions[i + 1].Bx = ZERO + (target - (i + 2)) -- correct.
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

-- 1 [1] NEWTABLE  0 0 0
-- 2 [1] SETGLOBAL 0 -1  ; x
-- 3 [3] GETGLOBAL 0 -2  ; print
-- 4 [3] GETGLOBAL 1 -1  ; x
-- 5 [3] GETTABLE  1 1 -3  ; "k"
-- 6 [3] CALL      0 2 1
-- 7 [5] GETGLOBAL 0 -1  ; x
-- 8 [5] SETTABLE  0 -3 -4 ; "k" 5
-- 9 [7] GETGLOBAL 0 -2  ; print
-- 10  [7] GETGLOBAL 1 -1  ; x
-- 11  [7] GETTABLE  1 1 -3  ; "k"
-- 12  [7] CALL      0 2 1
-- 13  [9] GETGLOBAL 0 -5  ; pairs
-- 14  [9] GETGLOBAL 1 -1  ; x
-- 15  [9] CALL      0 2 4
-- 16  [9] JMP       4 ; to 21
-- 17  [10]  GETGLOBAL 5 -2  ; print
-- 18  [10]  MOVE      6 3
-- 19  [10]  MOVE      7 4
-- 20  [10]  CALL      5 3 1
-- 21  [9] TFORLOOP  0 2
-- 22  [10]  JMP       -6  ; to 17
-- 23  [11]  RETURN    0 1

-- getglobal that is important is #21 in compiled.