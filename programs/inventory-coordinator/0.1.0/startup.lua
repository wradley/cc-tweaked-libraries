if shell and shell.run then
  shell.run("src/coordinator.lua")
else
  dofile("src/coordinator.lua")
end
