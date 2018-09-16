-- For constructing large strings fast.
-- J Gonzalez, 2018

class StringBuilder 
  new: (...) => @contents, @size = {...}, select '#', ...
  __concat: (operand) => with @ do .size, .contents[.size + 1] = .size + 1, operand
  __tostring: => table.concat(@contents)

StringBuilder