.sub main :main
    .param pmc args

    .local pmc d, opts
    .local int clid

    load_bytecode 'server.pbc'

    opts = new 'ResizablePMCArray'
    $P0 = new 'Integer'
    $P0 = 4000
    push opts, $P0

    $P1 = new 'String'
    $P1 = 'localhost'
    push opts, $P1

    say "Calling"
    d = new 'Lua::Server'
    d.'init_pmc'()
    unless d goto err

    say "running"
    d.'run'()
err:
.end

