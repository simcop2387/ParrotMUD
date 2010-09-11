.HLL 'Lua', 'lua_group'
.namespace [ 'Lua::tcpserver' ]

.sub '__onload' :anon :load
    .const .Sub entry = 'luaopen_tcpserver'
    set_hll_global 'luaopen_tcpserver', entry
.end

.sub luaopen_tcpserver
.end

.sub luaexportfunc
  .param string fname

  .local pmc _lua__GLOBAL
  .local pmc _func
  _func  = find_global "Lua::sockets", fname
  _lua__GLOBAL = get_hll_global '_G'

  new $P1, 'LuaString'

  _func.'setfenv'(_lua__GLOBAL)
  set $P1, fname

  _lua__GLOBAL[$P1] = _func
#  return (_func)
.end

# reguest handler sub - not a method
# this is called from the async select code, i.e from the event
# subsystem
#this needs to be replaced with a sub that calls a lua function, or does something that queues up a buffer to be parsed
.sub req_handler
    .param pmc work # a pio
    .param pmc conn     # Conn obj

    .local pmc srv, req

    srv = conn.'server'()
    $I0 = srv.'exists_conn'(conn)
    if $I0 goto do_read
    .return srv.'accept_conn'()

do_read:
    req = conn.'get_request'()
    unless req goto close_it
    $S0 = req.'method'()
    if $S0 == 'GET' goto serve_get
    printerr 'unknown method: '
    printerr $S0
    printerr "\n"
close_it:
    srv.'del_conn'(conn)
    .return()
serve_get:
    .local string file
    file = req.'uri'()
#    conn.'send_file_response'(file)
.end

