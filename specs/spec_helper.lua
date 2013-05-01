function run_spec (yaml, cmd)
  yaml = yaml:gsub ("'", "'\\''")
  cmd  = cmd or ""
  -- if CMD begins with a '-' then only options follow, otherwise
  -- we assume the entire command was passed.
  if cmd == "" or cmd:sub (1, 1) == "-" then
    cmd = "env LUA_PATH='" .. package.path .. "' src/specl --color=no " .. cmd
  end
  return specl.cmdpipe ("printf '%s\\n' '" .. yaml .. "'|" .. cmd)
end
