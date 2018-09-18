opcodes = require 'lib.opcodes'

shuffled_array = (array) -> 
  with a = {v for v in *array} 
    for i = #a, 2, -1
      j = math.random i
      a[i], a[j] = a[j], a[i]

repetitions = (scalar, seed = math.random()) -> scalar * (math.exp(e, -seed * .8) * exp(-50 * exp(-26 * (seed - 0.85)))) -- PDF of gumbel EVD w/transformations

shift_down_array = (array) -> {k - 1, v for k, v in ipairs array}

obfuscate_proto = (proto) -> 
  print 'Beginning control flow obfuscation...' if verbose 

  process_proto = (proto) -> 
    local old_instructions, new_instructions, shuffled_instructions
    local real_jump_targets, targets_to_fix

    old_instructions = {k + 1, v for k, v in pairs proto.code}
    shuffled_instructions = shuffled_array old_instructions

    new_instructions = [{OP: opcodes.JMP, A: 0, Bx: 131071} for _ in *new_instructions]
    real_jump_targets = {v, k + 1 for k, v in pairs proto.code}

    for i = 1, 2 * 
      

(proto, verbose) ->
  table_print = require 'lib/table_print'

  with p = proto 
    obfuscate_proto p
    table_print p if verbose