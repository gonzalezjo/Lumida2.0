local parser = require 'luaminify.lib.ParseLua'
local parselua = parser.ParseLua
local util = require 'luaminify.lib.Util'
local lookupify = util.lookupify

local LowerChars = lookupify{'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i',
               'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r',
               's', 't', 'u', 'v', 'w', 'x', 'y', 'z'}
local UpperChars = lookupify{'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I',
               'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R',
               'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'}
local Digits = lookupify{'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'}

local formatStatlist
local function Format_Beautify(code, verbose)
  local alphabet = {}
  local character_lookup = {}

  do
    for i = 0, 255 do 
      character_lookup[string.char(i)] = {}
    end 
  end

  local function add_to_alphabet() 
    local numbers = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255} -- hey you made it to the end of the line. :athWAVE:

    local len = #alphabet + 1
    while #numbers ~= 0 do 
      local number = table.remove(numbers, math.random(#numbers))
      local char = string.char(number)
      local chars = character_lookup[char]
      alphabet[len] = string.format('%q', char)
      chars[#chars + 1] = len  
      len = len + 1
    end

  end

  for i = 1, 90 do 
    add_to_alphabet()
  end

  local function generate_alphabet_access(letter)
    local subtree = character_lookup[letter] 
    return string.format('alphabet[%d]', subtree[math.random(#subtree)])
  end

  local function obfuscated_string(str) -- takes a .Data
    local decoded = loadstring('return ' .. str)()
    encoded = {}

    for i = 1, #decoded do 
      encoded[i] = generate_alphabet_access(decoded:sub(i, i))
    end 

    return string.format('(%s)', table.concat(encoded, ' .. '))
  end

  if type(code) == 'string' then 
    local success, result = parselua(code)
    assert(success, 'Failed to parse code.')
    code = result
  else 
    error(code)
  end

  local formatStatlist, formatExpr
  local indent = 0
  local EOL = "\n"

  local function getIndentation()
    return string.rep("    ", indent)
  end

  local function joinStatementsSafe(a, b, sep)
    sep = sep or ''
    local aa, bb = a:sub(-1,-1), b:sub(1,1)
    if UpperChars[aa] or LowerChars[aa] or aa == '_' then
      if not (UpperChars[bb] or LowerChars[bb] or bb == '_' or Digits[bb]) then
        --bb is a symbol, can join without sep
        return a .. b
      elseif bb == '(' then
        --prevent ambiguous syntax
        return a..sep..b
      else
        return a..sep..b
      end
    elseif Digits[aa] then
      if bb == '(' then
        --can join statements directly
        return a..b
      else
        return a..sep..b
      end
    elseif aa == '' then
      return a..b
    else
      if bb == '(' then
        --don't want to accidentally call last statement, can't join directly
        return a..sep..b
      else
        return a..b
      end
    end
  end

  formatExpr = function(expr)
    local out = string.rep('(', expr.ParenCount or 0)
    if expr.AstType == 'VarExpr' then
      if expr.Variable then
        out = out .. expr.Variable.Name
      else
        out = out .. expr.Name
      end

    elseif expr.AstType == 'NumberExpr' then
      out = out..expr.Value.Data

    elseif expr.AstType == 'StringExpr' then
      out = out .. obfuscated_string(expr.Value.Data) 

    elseif expr.AstType == 'BooleanExpr' then
      out = out..tostring(expr.Value)

    elseif expr.AstType == 'NilExpr' then
      out = joinStatementsSafe(out, "nil")

    elseif expr.AstType == 'BinopExpr' then
      out = joinStatementsSafe(out, formatExpr(expr.Lhs)) .. " "
      out = joinStatementsSafe(out, expr.Op) .. " "
      out = joinStatementsSafe(out, formatExpr(expr.Rhs))

    elseif expr.AstType == 'UnopExpr' then
      out = joinStatementsSafe(out, expr.Op) .. (#expr.Op ~= 1 and " " or "")
      out = joinStatementsSafe(out, formatExpr(expr.Rhs))

    elseif expr.AstType == 'DotsExpr' then
      out = out.."..."

    elseif expr.AstType == 'CallExpr' then
      out = out..formatExpr(expr.Base)
      out = out.."("
      for i = 1, #expr.Arguments do
        out = out..formatExpr(expr.Arguments[i])
        if i ~= #expr.Arguments then
          out = out..", "
        end
      end
      out = out..")"

    elseif expr.AstType == 'TableCallExpr' then
      out = out..formatExpr(expr.Base) .. " "
      out = out..formatExpr(expr.Arguments[1])

    elseif expr.AstType == 'StringCallExpr' then
      out = out .. formatExpr(expr.Base) .. obfuscated_string(expr.Arguments[1].Data)

    elseif expr.AstType == 'IndexExpr' then
      out = out..formatExpr(expr.Base).."["..formatExpr(expr.Index).."]"

    elseif expr.AstType == 'MemberExpr' then
      out = out..formatExpr(expr.Base)..expr.Indexer..expr.Ident.Data

    elseif expr.AstType == 'Function' then
      -- anonymous function
      out = out.."function("
      if #expr.Arguments > 0 then
        for i = 1, #expr.Arguments do
          out = out..expr.Arguments[i].Name
          if i ~= #expr.Arguments then
            out = out..", "
          elseif expr.VarArg then
            out = out..", ..."
          end
        end
      elseif expr.VarArg then
        out = out.."..."
      end
      out = out..")" .. EOL
      indent = indent + 1
      out = joinStatementsSafe(out, formatStatlist(expr.Body))
      indent = indent - 1
      out = joinStatementsSafe(out, getIndentation() .. "end")
    elseif expr.AstType == 'ConstructorExpr' then
      out = out.."{ "
      for i = 1, #expr.EntryList do
        local entry = expr.EntryList[i]
        if entry.Type == 'Key' then
          out = out.."["..formatExpr(entry.Key).."] = "..formatExpr(entry.Value)
        elseif entry.Type == 'Value' then
          out = out..formatExpr(entry.Value)
        elseif entry.Type == 'KeyString' then
          out = out..entry.Key.." = "..formatExpr(entry.Value)
        end
        if i ~= #expr.EntryList then
          out = out..", "
        end
      end
      out = out.." }"

    elseif expr.AstType == 'Parentheses' then
      out = out.."("..formatExpr(expr.Inner)..")"

    end
    out = out..string.rep(')', expr.ParenCount or 0)
    return out
  end

  local formatStatement = function(statement)
    local out = ""
    if statement.AstType == 'AssignmentStatement' then
      out = getIndentation()
      for i = 1, #statement.Lhs do
        out = out..formatExpr(statement.Lhs[i])
        if i ~= #statement.Lhs then
          out = out..", "
        end
      end
      if #statement.Rhs > 0 then
        out = out.." = "
        for i = 1, #statement.Rhs do
          out = out..formatExpr(statement.Rhs[i])
          if i ~= #statement.Rhs then
            out = out..", "
          end
        end
      end
    elseif statement.AstType == 'CallStatement' then
      out = getIndentation() .. formatExpr(statement.Expression)
    elseif statement.AstType == 'LocalStatement' then
      out = getIndentation() .. out.."local "
      for i = 1, #statement.LocalList do
        out = out..statement.LocalList[i].Name
        if i ~= #statement.LocalList then
          out = out..", "
        end
      end
      if #statement.InitList > 0 then
        out = out.." = "
        for i = 1, #statement.InitList do
          out = out..formatExpr(statement.InitList[i])
          if i ~= #statement.InitList then
            out = out..", "
          end
        end
      end
    elseif statement.AstType == 'IfStatement' then
      out = getIndentation() .. joinStatementsSafe("if ", formatExpr(statement.Clauses[1].Condition))
      out = joinStatementsSafe(out, " then") .. EOL
      indent = indent + 1
      out = joinStatementsSafe(out, formatStatlist(statement.Clauses[1].Body))
      indent = indent - 1
      for i = 2, #statement.Clauses do
        local st = statement.Clauses[i]
        if st.Condition then
          out = getIndentation() .. joinStatementsSafe(out, getIndentation() .. "elseif ")
          out = joinStatementsSafe(out, formatExpr(st.Condition))
          out = joinStatementsSafe(out, " then") .. EOL
        else
          out = joinStatementsSafe(out, getIndentation() .. "else") .. EOL
        end
        indent = indent + 1
        out = joinStatementsSafe(out, formatStatlist(st.Body))
        indent = indent - 1
      end
      out = joinStatementsSafe(out, getIndentation() .. "end") .. EOL
    elseif statement.AstType == 'WhileStatement' then
      out = getIndentation() .. joinStatementsSafe("while ", formatExpr(statement.Condition))
      out = joinStatementsSafe(out, " do") .. EOL
      indent = indent + 1
      out = joinStatementsSafe(out, formatStatlist(statement.Body))
      indent = indent - 1
      out = joinStatementsSafe(out, getIndentation() .. "end") .. EOL
    elseif statement.AstType == 'DoStatement' then
      out = getIndentation() .. joinStatementsSafe(out, "do") .. EOL
      indent = indent + 1
      out = joinStatementsSafe(out, formatStatlist(statement.Body))
      indent = indent - 1
      out = joinStatementsSafe(out, getIndentation() .. "end") .. EOL
    elseif statement.AstType == 'ReturnStatement' then
      out = getIndentation() .. "return "
      for i = 1, #statement.Arguments do
        out = joinStatementsSafe(out, formatExpr(statement.Arguments[i]))
        if i ~= #statement.Arguments then
          out = out..", "
        end
      end
    elseif statement.AstType == 'BreakStatement' then
      out = getIndentation() .. "break"
    elseif statement.AstType == 'RepeatStatement' then
      out = getIndentation() .. "repeat" .. EOL
      indent = indent + 1
      out = joinStatementsSafe(out, formatStatlist(statement.Body))
      indent = indent - 1
      out = joinStatementsSafe(out, getIndentation() .. "until ")
      out = joinStatementsSafe(out, formatExpr(statement.Condition)) .. EOL
    elseif statement.AstType == 'Function' then
      if statement.IsLocal then
        out = "local "
      end
      out = joinStatementsSafe(out, "function ")
      out = getIndentation() .. out
      if statement.IsLocal then
        out = out..statement.Name.Name
      else
        out = out..formatExpr(statement.Name)
      end
      out = out.."("
      if #statement.Arguments > 0 then
        for i = 1, #statement.Arguments do
          out = out..statement.Arguments[i].Name
          if i ~= #statement.Arguments then
            out = out..", "
          elseif statement.VarArg then
            out = out..",..."
          end
        end
      elseif statement.VarArg then
        out = out.."..."
      end
      out = out..")" .. EOL
      indent = indent + 1
      out = joinStatementsSafe(out, formatStatlist(statement.Body))
      indent = indent - 1
      out = joinStatementsSafe(out, getIndentation() .. "end") .. EOL
    elseif statement.AstType == 'GenericForStatement' then
      out = getIndentation() .. "for "
      for i = 1, #statement.VariableList do
        out = out..statement.VariableList[i].Name
        if i ~= #statement.VariableList then
          out = out..", "
        end
      end
      out = out.." in "
      for i = 1, #statement.Generators do
        out = joinStatementsSafe(out, formatExpr(statement.Generators[i]))
        if i ~= #statement.Generators then
          out = joinStatementsSafe(out, ', ')
        end
      end
      out = joinStatementsSafe(out, " do") .. EOL
      indent = indent + 1
      out = joinStatementsSafe(out, formatStatlist(statement.Body))
      indent = indent - 1
      out = joinStatementsSafe(out, getIndentation() .. "end") .. EOL
    elseif statement.AstType == 'NumericForStatement' then
      out = getIndentation() .. "for "
      out = out..statement.Variable.Name.." = "
      out = out..formatExpr(statement.Start)..", "..formatExpr(statement.End)
      if statement.Step then
        out = out..", "..formatExpr(statement.Step)
      end
      out = joinStatementsSafe(out, " do") .. EOL
      indent = indent + 1
      out = joinStatementsSafe(out, formatStatlist(statement.Body))
      indent = indent - 1
      out = joinStatementsSafe(out, getIndentation() .. "end") .. EOL
    elseif statement.AstType == 'LabelStatement' then
      out = getIndentation() .. "::" .. statement.Label .. "::" .. EOL
    elseif statement.AstType == 'GotoStatement' then
      out = getIndentation() .. "goto " .. statement.Label .. EOL
    elseif statement.AstType == 'Comment' then
      if statement.CommentType == 'Shebang' then
        out = getIndentation() .. statement.Data
        --out = out .. EOL
      elseif statement.CommentType == 'Comment' then
        out = getIndentation() .. statement.Data
        --out = out .. EOL
      elseif statement.CommentType == 'LongComment' then
        out = getIndentation() .. statement.Data
        --out = out .. EOL
      end
    elseif statement.AstType == 'Eof' then
      -- Ignore
    else
      print("Unknown AST Type: ", statement.AstType)
    end
    return out
  end

  formatStatlist = function(statList)
    local out = ''
    out = out .. 'local alphabet = {' .. table.concat(alphabet, ', ') .. '}\n'
    for _, stat in pairs(statList.Body) do
      out = joinStatementsSafe(out, formatStatement(stat) .. EOL)
    end
    return out
  end

  return formatStatlist(code)
end

return Format_Beautify