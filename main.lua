local code = [[
    local a; local function b() local c = 1 print(a) end;
]]

_G.regular_lua = true

local proto = compiler.compile_to_proto(code, "=lumida")

local function obfuscate_proto(pr)
    local function process_proto(p)
        
        -- fucking with op_jmp and op_forprep

        local has_jump = false
        for i = 0, p.sizecode - 1 do
            local inst = p.code[i]
            if i ~= 0 then
                local last_op = p.code[i - 1].OP
                if inst.OP == 22 and (last_op ~= 23 and last_op ~= 24 and last_op ~= 25 and last_op ~= 26 and last_op ~= 27) then
                    has_jump = true
                    break
                end
            end
        end

        if has_jump then
            if p.k[0] ~= nil then
                table.insert(p.k, { value = 0 })
            else
                table.insert(p.k, 0, { value = 0 })
            end

            

            p.sizek = p.sizek + 1
            p.maxstacksize = p.maxstacksize + 3
            
            table.insert(p.code, 0, {
                OP = 1,
                A = p.maxstacksize - 3,
                Bx = p.sizek - 1
            })

            table.insert(p.code, 1, {
                OP = 1,
                A = p.maxstacksize - 2,
                Bx = p.sizek - 1
            })

            table.insert(p.code, 2, {
                OP = 1,
                A = p.maxstacksize - 1,
                Bx = p.sizek - 1
            })

            p.sizecode = p.sizecode + 3

            for i = 0, p.sizecode - 1 do
                local inst = p.code[i]
                if i ~= 0 then
                    local last_op = p.code[i - 1].OP
                    if inst.OP == 22 and (last_op ~= 23 and last_op ~= 24 and last_op ~= 25 and last_op ~= 26 and last_op ~= 27) then
                        p.code[i] = {
                            OP = 32,
                            A = p.maxstacksize - 3,
                            Bx = inst.Bx
                        }
                        --inst.OP = 32
                        --inst.A = p.maxstacksize - 3
                        -- don't need to modify Bx (sBx is not a variable, it will be Bx + 131071) 
                    end
                end

            end

            p.maxstacksize = p.maxstacksize + 1
        end

        --p.sizelineinfo = 0
        --p.sizeupvalues = 0
        --p.sizelocvars = 0
        


        p.sizelineinfo = p.sizecode
        local new_lineinfo = {}
        for i = 1, p.sizelineinfo do
            new_lineinfo[i - 1] = math.random(1, 9999)
        end
        p.lineinfo = new_lineinfo


        for i = 0, p.sizep - 1 do
            process_proto(p.p[i])
        end
    end
    process_proto(pr)
end

obfuscate_proto(proto)

local function table_print(tt, indent, done)
    done = done or {}
    indent = indent or 0
    if type(tt) == "table" then
        for key, value in pairs (tt) do
            io.write(string.rep (" ", indent)) -- indent it
            if type (value) == "table" and not done [value] then
                done [value] = true
                io.write(string.format("[%s] => table\n", tostring (key)));
                io.write(string.rep (" ", indent+4)) -- indent it
                io.write("(\n");
                table_print (value, indent + 7, done)
                io.write(string.rep (" ", indent+4)) -- indent it
                io.write(")\n");
            else
                io.write(string.format("[%s] => %s\n",
                tostring (key), tostring(value)))
            end
        end
    else
        io.write(tt .. "\n")
    end
end

table_print(proto)

local bc = compiler.compile_proto(proto)
print(bc)

local f = io.open("output.luac", "wb")
f:write(bc)
f:close()

local built = ""
for i=1, #bc do
    built = built .. "\\" .. string.byte(bc, i)
end
print(built)
print(loadstring(bc))