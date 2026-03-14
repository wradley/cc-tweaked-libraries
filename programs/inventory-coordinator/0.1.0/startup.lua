local function programDir()
  if shell and shell.getRunningProgram then
    return fs.getDir(shell.getRunningProgram())
  end

  return ""
end

local entrypoint = fs.combine(programDir(), "src/coordinator.lua")

if shell and shell.run then
  shell.run(entrypoint)
else
  dofile(entrypoint)
end
