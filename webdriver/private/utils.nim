import net, random

proc noimpl* =
  assert(false, "abstract method called")

proc allocateRandomPort*(): Port =
  # TODO: ...
  Port(rand(49152..65535))
