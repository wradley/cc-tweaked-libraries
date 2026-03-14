local function programDir()
  if shell and shell.getRunningProgram then
    return fs.getDir(shell.getRunningProgram())
  end

  return ""
end

local controller = dofile(fs.combine(programDir(), "src/app/controller.lua"))
controller.run()
