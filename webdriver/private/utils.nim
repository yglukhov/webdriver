import net, random

proc noimpl* =
  assert(false, "abstract method called")

proc allocateRandomPort*(): Port =
  randomize()
  Port(rand(30000..39999))
