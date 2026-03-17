local TEST_RUNNERS = {
  "lib/log/tst/run.lua",
  "lib/rednet-contracts/tst/run.lua",
}

for _, path in ipairs(TEST_RUNNERS) do
  print("Running " .. path)
  if not shell.run(path) then
    error("test runner failed: " .. path, 0)
  end
end

print("All shared library tests passed.")
