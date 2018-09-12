local parser = require 'luaminify.lib.ParseLua'
local ParseLua = parser.ParseLua
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

local function stringoflength(number)
  local out = ""
  repeat out = out..string.char(math.random(200,240)) until #out == number
  return out
end

local function getAddition(number, target)
  local offset = number - target
  return "tonumber(\""..offset.."\")+"
end

local function mutateNumber(number) -- should encode 3 as like #"255" to really heck with people
    if #number == 0 then return number end

    local option = math.random()
    number = tonumber(number)
    if number < 255 and number == math.floor(number) and number > 0 then
      if option < 0.5 then
        if number > 127 then
          return ("byte('" .. string.char(number) .. "')")
        else
          local comp1 = math.abs(255 - math.floor(number * math.random() * 2) * 0.5 + 60)
          comp1 = comp1 ^ math.random() * 2
          comp1 = comp1 + math.random(10000)
          comp1 = math.floor(math.abs(comp1))
          comp1 = math.random(comp1) / comp1
          comp1 = 255 * comp1

          local comparator = 248 - (comp1/255 * 150)
          comparator = math.floor(comparator)

          local comp2 = number * math.random() * 255
          comp2 = comp2 + math.random(10000)
          comp2 = math.floor(math.abs(comp2))
          comp2 = math.random(comp2) / comp2
          comp2 = 255 * comp2
          local secret = 248 - (comp2 / 255 * 150)
          secret = math.floor(secret)

          return ("(\"" .. string.char(secret) .. "\" < " .. "\"" .. string.char(comparator) .. "\"" .. (" and %s or %s"):format(secret < comparator and ("tonumber(\"" .. number .. "\")") or "tonumber(\"" .. math.random(0, 128) .. "\")", secret < comparator and ("tonumber(\"" .. math.random(0, 128) .. "\")") or ("tonumber(\"" .. number .. "\")"))) .. ")"
        end
      elseif option < 0.85 then
        local offset = math.random(1,10)
        if number % offset == 0 then
          return "(#{" .. ("{},"):rep(number / offset) .. "nil} * " ..offset .. ")"
        else
          return "(#{" .. ("{},"):rep(number) .. "nil})"
        end
      else
        return "(#'"..stringoflength(number).."')"
      end
    else
      if false and option < 0.4 and tostring(number):match"." then
        -- if tostring(number):match(".") then
          local random = math.random()
          local result = number^random * 1/random
          return "("..getAddition(result,number).."tonumber(\"" .. number^random .. "\") ^ ".."tonumber(\"" .. 1/random .. "\"))"
        -- else -- just turn this into an if match(".") else thing
        --   local newmessage = tostring(number)
        --   newmessage = ("0"):rep(#newmessage%3)..newmessage
        --   return "tonumber(" .. newmessage:gsub("...", function(c) return mutatenumber(c).. "\"..\"" end) .. ")"
        -- end
      elseif option < 0.6 then
        local random = math.random(1337)
        return "(" .. number - random .. "+" .. random ..")"
      elseif option < 0.8 then
        return "(" .. "tonumber(" .. "\"" .. number .. "\"))"
      else
        local offset = math.random(-10000000, 9e9)
        local modulonum = math.random(number+offset+1, number+offset+9e9)
        return "(" .. number + offset .. "%" .. modulonum .. "-" .. offset .. ")"
      end
    end

  return number
end

local function Format_Beautify(code, verbose)
  if type(code) == 'string' then 
    local success, result = ParseLua(code)
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
      out = out..mutateNumber(expr.Value.Data)

    elseif expr.AstType == 'StringExpr' then
      out = out..expr.Value.Data

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
      out = out..formatExpr(expr.Base) .. " "
      out = out..expr.Arguments[1].Data

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
    for _, stat in pairs(statList.Body) do
      out = joinStatementsSafe(out, formatStatement(stat) .. EOL)
    end
    return out
  end

  return formatStatlist(code)
end

return Format_Beautify
