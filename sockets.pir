.HLL 'Lua', 'lua_group'
.namespace [ 'Lua::sockets' ]

.sub '__onload' :anon :load
    .const .Sub entry = 'luaopen_sockets'
    set_hll_global 'luaopen_sockets', entry
.end

.sub luaopen_sockets
  luaexportfunc("socket")
  luaexportfunc("sockaddr")
  luaexportfunc("sock_connect")
  luaexportfunc("sock_bind")
  luaexportfunc("sock_close")
  luaexportfunc("sock_listen")
.end

.sub "socket"
  .param int a
  .param int b
  .param int c
  .local pmc sock
  socket sock, a, b, c
  unless sock goto SOCKERR
  .return (sock)
SOCKERR: 
   $P1 = new 'LuaNil'
   .return ($P1)
.end

.sub "sockaddr"
  .param pmc _port
  .param pmc _dest
  .local string address
  .local pmc luaaddress

  .local int port
  .local string dest
  port = _port
  dest = _dest

  address = sockaddr port, dest

  luaaddress = new 'LuaString'
  luaaddress=address

  .return (address)
.end

.sub "sock_connect"
  .param pmc sock
  .param pmc _address
  .local string address
  .local int ret
  .local pmc luaret
	address = _address
  
  ret = connect sock, address
  luaret = new 'LuaNumber'
  luaret = ret

  .return (luaret)
.end

.sub "recv"
  
.end

.sub "send"

.end

.sub "sock_close"
  .param pmc sock
  close sock
.end

.sub "sock_bind"
  .param pmc sock
  .param pmc _address
  .local string address
  .local int ret
  .local pmc luaret
	address = _address
  
  ret = bind sock, address
  luaret = new 'LuaNumber'
  luaret = ret

  .return (luaret)
.end

.sub "sock_listen"
  .param pmc sock
  .local int ret
  .local pmc luaret
  
  ret = listen sock, 1
  luaret = new 'LuaNumber'
  luaret = ret

  .return (luaret)
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
