# Copyright (C) 2006-2007, The Perl Foundation.
# $Id: Daemon.pir 22180 2007-10-17 19:33:17Z allison $

.sub '_onload' :load
    .local pmc cl
    # server clsass
    print "ONLOAD Lua::Server\n"
    cl = newclass ['Lua::Server']
    addattribute cl, 'socket'	# pio where httpd is listening
#    addattribute cl, 'opts'     # options TBdoced
    addattribute cl, 'active'   # list of active ClientConns
    addattribute cl, 'to_log'   # list of strings to be logged
    addattribute cl, 'doc_root' # where to serve files from
    
        # client connection
    # XXX this should subclass ParrotIO but opcode or PIO code 
    # just doesn't work with classes
    print "ONLOAD Lua::Server::ClientConn\n"
    cl = newclass ['Lua::Server::ClientConn']
    addattribute cl, 'socket'	# the connected pio
    addattribute cl, 'server'	# whom are we working for
    addattribute cl, 'close'	# needs closing after req is handled
    addattribute cl, 'time_stamp'  # timestamp for timeout
.end

.namespace ['Lua::Server']




.sub req_handler
    .param pmc work # a pio
    .param pmc conn     # Conn obj

    .local pmc srv, req

    srv = conn.'server'()
    $I0 = srv.'exists_conn'(conn)
    if $I0 goto do_read
    .return srv.'accept_conn'()

do_read:
		 say "----REQH----do_read"
#    req = conn.'get_request'()
#    unless req goto close_it
#    $S0 = req.'method'()
#    if $S0 == 'GET' goto serve_get
#    printerr 'unknown method: '
#    printerr $S0
#    printerr "\n"
close_it:
#    srv.'del_conn'(conn)
    .return()
serve_get:
    .local string file
    file = req.'uri'()
#    conn.'send_file_response'(file)
.end












.const string CRLF     = "\r\n"
.const string LFCR     = "\n\r"
.const string LF       = "\n"
.const string CR       = "\r"

.include "stat.pasm"
.include 'io_thr_msg.pasm'

.sub init_pmc :vtable :method
#    .param pmc args

    .local pmc active

#    setattribute self, 'opts', args
    active = new 'ResizablePMCArray'
    setattribute self, 'active', active
    $P0 = new 'ResizableStringArray'
    setattribute self, 'to_log', $P0

    # create socket
    .local pmc sock
    say "Getting Socket"
    sock = socket 2, 1, 6 	# PF_INET, SOCK_STREAM, tcp
    unless sock goto err_sock
    setattribute self, 'socket', sock

    say "Got Socket"

    .local int port
    .local string adr
    #XXX need to find the correct way to do this part...
    port = 4000
    adr = 'localhost'

    # bind
    say "Sockaddr parsing"
    .local string i_addr
    .local int res
    i_addr = sockaddr port, adr
    say "binding"
		res = bind sock, i_addr
    if res == -1 goto err_bind

    # listen
    say "the world is listening"
    res = listen sock, 1
    if res == -1 goto err_listen

    # add connection
    self.'new_conn'(sock)
    .return()

err_listen:
err_bind:
    err $I0
    err $S0, $I0
    printerr $S0
    printerr "\n"
    close sock
err_sock:
    $P0 = new 'Undef'
    setattribute self, 'socket', $P0
.end

.sub 'socket' :method
    $P0 = getattribute self, 'socket'
    .return ($P0)
.end

.sub 'opts' :method
    $P0 = getattribute self, 'opts'
    .return ($P0)
.end

.sub 'get_bool' :vtable :method
    $P0 = getattribute self, 'socket'
    $I0 = istrue $P0
    .return ($I0)
.end


.sub 'run' :method

loop:
    ## self.'_del_stale_conns'()
    say "---SELECT ACTIVE"
		self.'_select_active'()
    # while idle dump the logfile
    say "---_WRITE_LOGS"
		self.'_write_logs'()
    say "---SLEEP"
    sleep 0.5
#this should either call a lua func, or a lua func call this, not sure yet
    goto loop
.end

# === server utils

.sub '_write_logs' :method
    .local pmc to_log
    to_log = getattribute self, 'to_log'
    say "DEBUG: writelogs"
loop:
    # log can fill, while we are running here
    unless to_log goto ex
    $S0 = shift to_log
    print $S0
    goto loop
ex:
.end

.sub 'debug' :method
    .param pmc args :slurpy

    .local pmc opts
#    opts = getattribute self, 'opts'
#    $I0 =  opts['debug']
    $I0 = 0
    if $I0 goto do_debug
    .return()
do_debug:
    .local int n
    .local string fmt, res
    n = elements args
    fmt = repeat "%Ss", n
    res = sprintf fmt, args
    printerr res	
.end

.sub 'log' :method
    .param pmc args :slurpy

    .local int n, now
    .local string fmt, res, t
    n = elements args
    n += 3
    now = time
    $S0 = gmtime now
    chopn $S0, 2	# XXX why 2?
    unshift args, ", "
    unshift args, $S0
    push args, "\n"
    fmt = repeat "%Ss", n
    res = sprintf fmt, args
    .local pmc to_log
    to_log = getattribute self, 'to_log'
    # Yay! The fun of any async server
    # write to log when we idling
    push to_log, res
.end

# === connection handling

.sub '_select_active' :method
    .local pmc active, conn, sock
    .local int i, n
    .const .Sub req_handler = "req_handler"
    active = getattribute self, 'active'
    n = elements active
    i = 0
add_lp:
    say "-----ACTIVE_LOOP"
    conn = active[i]
    say "----- CONN.socket()"
    sock = conn.'socket'()
    say "----- ADD IO EVENT"
    add_io_event sock, req_handler, conn, .IO_THR_MSG_ADD_SELECT_RD
    ## self.'debug'('**select ', i, "\n")
    say "INC I AND CHECK"
    inc i
    if i < n goto add_lp
.end

#this should be checked over and enabled, so that we don't exhaust connections
#but that must wait until parrot stops segfaulting on closing a socket
.sub '_del_stale_conns' :method
    .local int n, now, last
    .local pmc active, conn, sock

    now = time 
    active = getattribute self, 'active'
    n = elements active
    dec n
loop:
    unless n goto done
    conn = active[n]
    last = conn.'time_stamp'()
    $I0 = now - last
    if $I0 < 10 goto keep_it	# TODO ops var
    sock = conn.'socket'()
    close sock
    delete active[n]
    self.'debug'('del stale conn ', n, "\n")
keep_it:
    dec n
    goto loop
done:
.end

# add coket to active connections
.sub 'new_conn' :method
    .param pmc sock
    .local pmc active, conn
    $S0 = typeof sock
    say $S0
    active = getattribute self, 'active'
    new conn, 'Lua::Server::ClientConn'
    conn.'init_pmc'(sock)
    conn.'server'(self)
    push active, conn
    self.'debug'("new conn\n")
.end

# accept new connection and add to active
.sub 'accept_conn' :method
    .local pmc orig, work
    orig   = getattribute self, 'socket'
    accept work, orig
    self.'new_conn'(work)
.end

# remove work from active connections and close it
.sub 'del_conn' :method
    .param pmc work

    .local pmc active, orig, sock
    .local int i, n
    sock = getattribute work, 'socket'
    close sock
    active = getattribute self, 'active'
loop:
    n = elements active
    i = 0
rem_lp:
    $P0 = active[i]
    eq_addr $P0, work, del_it
    inc i
    if i < n goto rem_lp
del_it:
    delete active[i]
    .return()
not_found:
    self.'debug'("connection not found to delete\n")
.end

# close all sockets
# this needs enabling of SIGHUP in src/events.c but still doesn't
# help against FIN_WAIT2 / TIME_WAIT state of connections
.sub 'shutdown' :method
    .local pmc active, sock
    active = getattribute self, 'active'
rem_lp:
    $P0 = pop active
    sock = $P0.'socket'()
    close sock
    if active goto rem_lp
.end

# if work is the original httpd conn, it's a new connection
.sub 'exists_conn' :method
    .param pmc work

    .local pmc active, orig
    active = getattribute self, 'active'
    orig = active[0]
    ne_addr work, orig, yes
    .return (0)
yes:
    .return (1)
.end

.namespace ['Lua::Server::ClientConn']

.sub init_pmc :vtable :method
    .param pmc sock
    setattribute self, 'socket', sock
    $P0 = new 'Boolean'
    setattribute self, 'close', $P0
    $P0 = new 'Integer'
    time $I0
    $P0 = $I0
    setattribute self, 'time_stamp', $P0
.end

# get socket
.sub 'socket' :method
    $P0 = getattribute self, 'socket'
    .return ($P0)
.end

.sub 'server' :method
    .param pmc sv      :optional
    .param int has_sv  :opt_flag
    if has_sv goto set_it
    sv = getattribute self, 'server'
    .return (sv)
set_it:
    setattribute self, 'server', sv
.end

# get/set timestamp
.sub 'time_stamp' :method
    .param int ts      :optional
    .param int has_ts  :opt_flag
    $P0 = getattribute self, 'time_stamp'
    if has_ts goto set_it
    .return ($P0)
set_it:
    $P0 = ts
.end

.sub '_read' :method
    .local int res, do_close, pos
    .local string buf, req, firstline
    .local pmc sock, srv
    .local pmc lines

    srv = self.'server'()
    req = ''
    do_close = 0
    sock = self.'socket'()
    # TODO keep a buffer and a state in Conn
    # check method, read Content-Length if needed and read
    # until message is complete
MORE:
    res = recv sock, buf
    srv.'debug'("**read ", res, " bytes\n")
    if res > 0 goto not_empty
    do_close = 1
    if res <= 0 goto done
not_empty:
#i think i need to change this to be something else
    concat req, buf
    index pos, req, LF
    if pos >= 0 goto have_line
#    index pos, req, LFLF
#    if pos >= 0 goto have_line
#    index pos, req, CRCR
#    if pos >= 0 goto have_line
    goto MORE
have_line:
    # TODO rip off from the line
    split lines, LF, req
    firstline = shift lines
    req = join "\n", lines
    print "-----INPUT-----\n"
    print req
   
done:
#ignore do_close, i don't do that here i think
#    $P0 = getattribute self, 'close'
#    $P0 = do_close
    .return (req)
.end

.sub 'send_response' :method
    .param string resp
    .local pmc sock
    sock = self.'socket'()
    $I0 = send sock, resp	# XXX don't ignore
    .return ($I0) #return the error code, don't know what to do with it yet
.end
