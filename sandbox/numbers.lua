local x = 5 

while true do 
  if x == 5 then 
    print 'hi' 
    x = 3 
  elseif x == 1 then
    return
  elseif x == 3 then 
    print 'world'
    x = 1
  end
end