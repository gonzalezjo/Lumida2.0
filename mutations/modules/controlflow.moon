ZERO, opcodes = 131071, require 'lib.opcodes'

shift_down_array = (array) -> array[i - 1] = array[i] for i = 1, #array + 1
repetitions = (x, scalar) -> scalar * (math.exp(-x * .8) * math.exp(-50 * math.exp(-26 * (x - 0.85))))
get_jumps = (min = 2, max = 6, scalar = 70, x = math.random! + 0.2) -> math.min(math.max(min, repetitions(x, 50)), max) -- EVD

populate_metadata = (old_instructions, old_positions, jumps) -> 
  for i, instruction in ipairs old_instructions
    old_positions[instruction] = i

    switch instruction.OP
      when opcodes.EQ, opcodes.LT, opcodes.LE
        jumps[instruction] = 
          destination: old_instructions[(i + 2) + (old_instructions[i + 1].Bx - ZERO)], 
          fallthrough: old_instructions[(i + 2)]
      when opcodes.TEST, opcodes.TESTSET, opcodes.TFORLOOP
        jumps[instruction] = 
          destination: old_instructions[(i + 2) + (old_instructions[i + 1].Bx - ZERO)],
          fallthrough: old_instructions[(i + 2)]
      when opcodes.JMP, opcodes.FORPREP, opcodes.FORLOOP
        jumps[instruction] = old_instructions[(i + 1) + (instruction.Bx - ZERO)]
      when opcodes.CLOSURE
        instruction.preserve = true 
        for j = i + 1, #old_instructions
            switch old_instructions[i] -- i convinced myself this was fine a while ago.
              when opcodes.GETUPVAL, opcodes.MOVE, opcodes.ADD, opcodes.SUB, opcodes.MUL, opcodes.DIV
                old_instructions[i].preserve = 1
              else 
                old_instructions[i - 1].preserve = false
                break
      when opcodes.CALL, opcodes.TAILCALL, opcodes.VARARG, opcodes.LOADBOOL, opcodes.SETLIST
        if instruction.C == 0 
          with succ = old_instructions[i + 1]
            instruction.preserve = succ
            succ.preserve = true

shuffle = (array) -> 
  with a = array
    for i = #a - 1, 1, -1   
      j = math.random i
      continue if a[i].preserve or a[j].preserve 
      a[i], a[j] = a[j], a[i]

add_jumps = (new_instructions, proto) ->
  replacement, len = {}, #new_instructions

  for i = 1, #new_instructions
    instruction = new_instructions[i]

    if not instruction.preserve_next
      for _ = 1, get_jumps!
        table.insert replacement, 
          OP: opcodes.JMP
          A: 0
          Bx: ZERO + math.random -i + 1, len - i - 1

    table.insert replacement, instruction

  for i, v in ipairs replacement
    new_instructions[i] = v 

populate_translation_tables = (new_instructions, new_positions) -> 
  for i, instruction in pairs new_instructions
    new_positions[instruction], new_positions[i] = i, instruction 

translate_instructions = (args) -> 
  {:new_instructions, :new_positions, 
   :old_positions, :old_instructions, :jumps} = args
  sizecode = #new_instructions

  for i = sizecode - 1, 0, -1 
    with instruction = new_instructions[i]
      unless (instruction.OP == opcodes.JMP) and (not jumps[instruction]) -- skip jumps that weren't generated
        switch instruction.OP
          when opcodes.JMP, opcodes.FORLOOP, opcodes.FORPREP 
            instruction.Bx = ZERO
            target = new_positions[jumps[instruction]]

            if instruction.OP ~= opcodes.JMP
              instruction.Bx = ZERO + new_positions[jumps[instruction]] - (i + 1)

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

obfuscate_proto = (proto, verbose) -> 
  print 'Beginning control flow obfuscation...' if verbose 

  process_proto = (proto, verbose) -> 
    print 'In process_proto' if verbose

    jumps, old_positions, new_positions = {}, {}, {} 
    old_instructions = {k + 1, v for k, v in pairs proto.code}
    new_instructions = [v for v in *old_instructions] 

    populate_metadata old_instructions, old_positions, jumps
    shuffle new_instructions
    add_jumps new_instructions, proto
    shift_down_array new_instructions
    populate_translation_tables new_instructions, new_positions
    translate_instructions
      :new_instructions, :new_positions 
      :old_positions, :old_instructions, 
      :jumps

    with p = proto 
      process_proto .p[i] for i = 0, .sizep - 1
      .sizelineinfo = 0
      .code = new_instructions
      .sizecode = #.code + 1

  process_proto proto 

(proto, verbose) -> 
  with p = proto 
    obfuscate_proto p, verbose