-- just going to use mlnlover11's conventions to make my life easier here 

local parser = require "luaminify.lib.ParseLua"
local parselua = parser.ParseLua
local util = require "luaminify.lib.Util"
local lookupify = util.lookupify
local stringbuilder = require "lib.stringbuilder"
local format_beautify = require "transformations.modules.noop_optimized"
local bit = require 'bit'
local acceptable_letters = {}

for i = ('a'):byte(), ('z'):byte() do 
  acceptable_letters[#acceptable_letters + 1] = string.char(i)
end
for i = ('A'):byte(), ('Z'):byte() do 
  acceptable_letters[#acceptable_letters + 1] = string.char(i)
end

local acceptable_names = {}

local USE_ASSERTS, sanity_check = false 
if USE_ASSERTS then
  sanity_check = {} 
end

local LENGTH_OF_LETTERS = #acceptable_letters

do 
  for i = 1e6, 5e6, 16 do 
    local pos = math.floor((i-1e6)/16)+1 

    acceptable_names[pos] = {} 

    -- arcane magic, don't ask.
    for j = 0, 20, 2 do 
      acceptable_names[pos][j / 2] = acceptable_letters[(bit.rshift(i, j) % (LENGTH_OF_LETTERS - 1)) + 1]
    end

    acceptable_names[pos] = table.concat(acceptable_names[pos])

    if USE_ASSERTS then 
      assert(not sanity_check[acceptable_names[pos]], 'adjust modulo to - 1 iirc')
      sanity_check[acceptable_names[pos]] = true
    end
  end
end

local formatStatlist
return function(code, ast)  
  local function getRandomName()
    return table.remove(acceptable_names, math.random(#acceptable_names))
  end

  if type(code) == "string" then
    local success, result = parselua(code)
    assert(success, "Failed to parse code.")
    ast = result
  else
    error(code)
  end

  local CONSTANT_POOL_NAME = assert(getRandomName(), 'No name?')

  -- Rip constant strings out
  local function makeNode(index)
    return {
      AstType = "IndexExpr",
      ParentCount = 1,
      Base = {AstType = "VarExpr", Name = CONSTANT_POOL_NAME},
      Index = {AstType = "StringExpr", Value = {Data = string.format('%q', index)}}
    } -- Ast Node
  end

  table.insert(
    ast.Body,
    1,
    {
      AstType = "LocalStatement",
      Name = CONSTANT_POOL_NAME,
      Scope = ast.Scope,
      LocalList = {
        --ast.Scope:CreateLocal('CONSTANT_POOL'),
        {Scope = ast.Scope, Name = CONSTANT_POOL_NAME, CanRename = true}
      },
      InitList = {
        {EntryList = {}, AstType = "ConstructorExpr"}
      }
    }
  )
  local constantPoolAstNode = ast.Body[1].InitList[1]

  local CONSTANT_POOL = {}
  local nilIndex
  local index = getRandomName()
  local function insertConstant(v, index, type)
    table.insert(
      constantPoolAstNode.EntryList,
      #constantPoolAstNode.EntryList == 0 and 1 or math.random(#constantPoolAstNode.EntryList),
      {
        Type = "Key",
        Value = {AstType = type or "StringExpr", Value = v},
        Key = {AstType = "StringExpr", Value = {Data = string.format('%q', index)}}
      }
    )
  end

  local function addConstant(const)
    if math.random() < .08 then -- bor
      if math.random() < .25 then 
        addConstant(math.random())
      elseif math.random(.75) then
        addConstant(math.random(90000000))
      else
        addConstant(math.random(-100000000, 100000000))
      end
    elseif math.random() < .09 then 
      if math.random() < .5 then 
        addConstant({})
      else
        addConstant(table.concat {getRandomName()})
      end
    end


    if CONSTANT_POOL[const] then
      return CONSTANT_POOL[const]
    end
    if const == nil and nilIndex then
      return nilIndex
    end

    if type(const) == "string" then
      const = const
      insertConstant({Data = string.format('%q', const), Constant = const}, index, "StringExpr")
      CONSTANT_POOL[const] = index
      index = getRandomName()
      return CONSTANT_POOL[const]
    elseif type(const) == 'table' then -- hack
      insertConstant({Data = getRandomName(), Constant = getRandomName()}, index, "StringExpr")      
    elseif type(const) == "number" then
      insertConstant({Data = const}, index, "NumberExpr")
      CONSTANT_POOL[const] = index
      index = getRandomName()
      return CONSTANT_POOL[const]
    elseif type(const) == "nil" then
      insertConstant(const, index, "NilExpr")
      nilIndex = index
      index = getRandomName()
      return nilIndex
    elseif type(const) == "boolean" then
      insertConstant(const, index, "BooleanExpr")
      CONSTANT_POOL[const] = index
      index = getRandomName()
      return CONSTANT_POOL[const]
    elseif const.AstType == "VarExpr" then
      table.insert(
        constantPoolAstNode.EntryList,
        {
          Type = "Key",
          Value = const,
          Key = {AstType = "NumberExpr", Value = {Data = tostring(index)}}
        }
      )
      CONSTANT_POOL[const] = index
      index = getRandomName()
      return CONSTANT_POOL[const]
    else
      error("Unable to process constant of type '" .. const .. "'")
    end
  end

  local fixExpr, fixStatList

  fixExpr = function(expr)
    if expr.AstType == "VarExpr" then
      if expr.Local then
        return expr
      else
        --local i = addConstant(expr)
        --return makeNode(i)
      end
    elseif expr.AstType == "NumberExpr" then
      local i = addConstant(tonumber(expr.Value.Data))
      return makeNode(i)
    elseif expr.AstType == "StringExpr" then
      local i = addConstant(expr.Value.Constant)
      return makeNode(i)
    elseif expr.AstType == "BooleanExpr" then
      local i = addConstant(expr.Value)
      return makeNode(i)
    elseif expr.AstType == "NilExpr" then
      local i = addConstant(nil)
      return makeNode(i)
    elseif expr.AstType == "BinopExpr" then
      expr.Lhs = fixExpr(expr.Lhs)
      expr.Rhs = fixExpr(expr.Rhs)
    elseif expr.AstType == "UnopExpr" then
      expr.Rhs = fixExpr(expr.Rhs)
    elseif expr.AstType == "DotsExpr" then
    elseif expr.AstType == "CallExpr" then
      expr.Base = fixExpr(expr.Base)
      for i = 1, #expr.Arguments do
        expr.Arguments[i] = fixExpr(expr.Arguments[i])
      end
    elseif expr.AstType == "TableCallExpr" then
      expr.Base = fixExpr(expr.Base)
      expr.Arguments[1] = fixExpr(expr.Arguments[1])
    elseif expr.AstType == "StringCallExpr" then
      expr.Base = fixExpr(expr.Base)
      expr.Arguments[1] = fixExpr(expr.Arguments[1])
    elseif expr.AstType == "IndexExpr" then
      expr.Base = fixExpr(expr.Base)
      expr.Index = fixExpr(expr.Index)
    elseif expr.AstType == "MemberExpr" then
      expr.Base = fixExpr(expr.Base)
    elseif expr.AstType == "Function" then
      fixStatList(expr.Body)
    elseif expr.AstType == "ConstructorExpr" then
      for i = 1, #expr.EntryList do
        local entry = expr.EntryList[i]
        if entry.Type == "Key" then
          entry.Key = fixExpr(entry.Key)
          entry.Value = fixExpr(entry.Value)
        elseif entry.Type == "Value" then
          entry.Value = fixExpr(entry.Value)
        elseif entry.Type == "KeyString" then
          entry.Value = fixExpr(entry.Value)
        end
      end
    end
    return expr
  end

  local fixStmt = function(statement)
    if statement.AstType == "AssignmentStatement" then
      for i = 1, #statement.Lhs do
        statement.Lhs[i] = fixExpr(statement.Lhs[i])
      end
      for i = 1, #statement.Rhs do
        statement.Rhs[i] = fixExpr(statement.Rhs[i])
      end
    elseif statement.AstType == "CallStatement" then
      statement.Expression = fixExpr(statement.Expression)
    elseif statement.AstType == "LocalStatement" then
      for i = 1, #statement.InitList do
        statement.InitList[i] = fixExpr(statement.InitList[i])
      end
    elseif statement.AstType == "IfStatement" then
      statement.Clauses[1].Condition = fixExpr(statement.Clauses[1].Condition)
      fixStatList(statement.Clauses[1].Body)
      for i = 2, #statement.Clauses do
        local st = statement.Clauses[i]
        if st.Condition then
          st.Condition = fixExpr(st.Condition)
        end
        fixStatList(st.Body)
      end
    elseif statement.AstType == "WhileStatement" then
      statement.Condition = fixExpr(statement.Condition)
      fixStatList(statement.Body)
    elseif statement.AstType == "DoStatement" then
      fixStatList(statement.Body)
    elseif statement.AstType == "ReturnStatement" then
      for i = 1, #statement.Arguments do
        statement.Arguments[i] = fixExpr(statement.Arguments[i])
      end
    elseif statement.AstType == "BreakStatement" then
    elseif statement.AstType == "RepeatStatement" then
      fixStatList(statement.Body)
      statement.Condition = fixExpr(statement.Condition)
    elseif statement.AstType == "Function" then
      if statement.IsLocal then
      else
        statement.Name = fixExpr(statement.Name)
      end
      fixStatList(statement.Body)
    elseif statement.AstType == "GenericForStatement" then
      for i = 1, #statement.Generators do
        statement.Generators[i] = fixExpr(statement.Generators[i])
      end
      fixStatList(statement.Body)
    elseif statement.AstType == "NumericForStatement" then
      statement.Start = fixExpr(statement.Start)
      statement.End = fixExpr(statement.End)
      if statement.Step then
        statement.Step = fixExpr(statement.Step)
      end
      fixStatList(statement.Body)
    elseif statement.AstType == "LabelStatement" then
    elseif statement.AstType == "GotoStatement" then
    elseif statement.AstType == "Eof" then
    else
      print("Unknown AST Type: " .. statement.AstType)
    end
  end

  fixStatList = function(statList)
    for _, stat in pairs(statList.Body) do
      fixStmt(stat)
    end
  end

  fixStatList(ast)

  return format_beautify(ast)
end