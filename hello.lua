require "ten"
require "sockets"

function two()
  print "1 2"
end

--socket PF_INET, SOCK_STREAM, tcp
sock = socket(2,1,6)
address = sockaddr(4000, "localhost")

print(type(sock))
print(type(address))
ret = sock_bind(sock,address)

print(type(ret))
print(ret)

  sock_listen(sock)


n = 0
repeat
  n = n + 1
until (n > 100000)


sock_close(sock)
