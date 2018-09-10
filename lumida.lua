local arguments 

do
  local argparse = require 'lib/argparse'
  local parser = argparse('lumida.lua')

  parser:argument('input', 'Input file.')

  parser:flag('-R --roblox', 'Enable ROBLOX bytecode specialization.')

  parser:option('-output', 'Output file.', 'out.luac')
  parser:option('-t --transformations', 'Source code transformations.'):args('?')

  arguments = parser:parse()
end

