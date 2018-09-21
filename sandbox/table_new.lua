t = {c = 4}
function t:a()
  print(self.c)
end
t[1] = 2
print(t[1] + 3)
t:a()