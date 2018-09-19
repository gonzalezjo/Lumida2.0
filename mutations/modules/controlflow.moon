opcodes = require 'lib.opcodes'
table_print = require 'lib/table_print'

shift_down_array = (array) -> {k - 1, v for k, v in ipairs array}
repetitions = (x, scalar) -> scalar * (math.exp(-x * .8) * math.exp(-50 * math.exp(-26 * (x - 0.85))))
get_jumps = (min = 2, max = 2, scalar = 50, x = math.random()) -> math.min(math.max(min, repetitions(x, 50)), max)

-- TODO: if two instructions do the same thing (i.e., two call 0 1 0s, then merge the instructions.)
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
          jumps[instruction] = 
            fallthrough: old_instructions[i + old_instructions[i + 1].Bx - 131071], 
            destination: old_instructions[i + 2]
        when opcodes.JMP, opcodes.FORLOOP, opcodes.FORPREP
          jumps[instruction] = {old_instructions[i + instruction.Bx - 131071]}
        when opcodes.CLOSURE
          closures[i] = true
          closures[instruction] = for i = i + 1, #old_instructions
              switch old_instructions[i] -- technically 100% okay, vis a vis code generation of our targets
                when opcodes.GETUPVAL, opcodes.MOVE, opcodes.ADD, opcodes.SUB, opcodes.MUL, opcodes.DIV 
                  closures[i] = true
                  old_instructions[i]
                else 
                  break

    with a = new_instructions           
      for i = #a - 1, 1, -1   
        continue if closures[i] 
        j = math.random i
        a[i], a[j] = a[j], a[i]

    for i = #new_instructions, 1, -1
      continue if closures[i]
      for _ = 1, get_jumps!
        proto.sizecode += 1
        table.insert new_instructions, i, OP: opcodes.JMP, A: 0, Bx: 131071 + math.random(-i + 1, #new_instructions - i)

    new_instructions = shift_down_array new_instructions

    for i, instruction in pairs new_instructions
      new_positions[instruction], new_positions[i] = i, instruction

    for i = #new_instructions - 1, 0, -1
      with instruction = new_instructions[i]
        continue if (instruction.OP == opcodes.JMP) and (not jumps[instruction])

        switch instruction.OP
          when opcodes.JMP, opcodes.FORLOOP, opcodes.FORPREP 
            -- assert(false, 'Should not run.')
            -- unless instruction.tampered
            -- instruction.Bx = 131071 + new_positions[old_instructions[old_positions[instruction] + 1]] - (i + 1)
            -- target = new_positions[old_instructions[old_positions[instruction] + 1]]
            -- new_instructions[i + 1].Bx = 131071 + (target - (i + 2))              
            print 'noop'
          when opcodes.EQ, opcodes.LT, opcodes.LE
            {:fallthrough, :destination} = jumps[instruction]
            new_instructions[i + 1].Bx = 131071 + new_positions[fallthrough] - (i + 2)
            new_instructions[i + 1].tampered = true
            new_instructions[i + 2].Bx = 131071 + new_positions[destination] - (i + 3)
            new_instructions[i + 2].tampered = true
          when opcodes.TEST, opcodes.TESTSET
            {:fallthrough, :destination} = jumps[instruction]
            new_instructions[i + 1].Bx = 131071 + new_positions[destination] - (i + 1)
            new_instructions[i + 1].tampered = true
            new_instructions[i + 2].Bx = 131071 + new_positions[fallthrough] - (i + 2)
            new_instructions[i + 2].tampered = true
          else
            target = new_positions[old_instructions[old_positions[instruction] + 1]]
            new_instructions[i + 1].Bx = 131071 + (target - (i + 2))

    new_instructions[0].Bx = 131071 + new_positions[old_instructions[1]] - 1

    with p = proto 
      process_proto .p[i] for i = 0, .sizep - 1
      .sizelineinfo = 0
      .code = new_instructions

  process_proto proto 

(proto, verbose) ->
  with p = proto 
    obfuscate_proto p, verbose
    -- table_print p if verbose

-- 1 [1] LOADK     0 -2  ; 5
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
