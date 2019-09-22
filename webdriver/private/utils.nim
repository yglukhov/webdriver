import net

proc noimpl* =
  assert(false, "abstract method called")

proc allocateRandomPort*(): Port =
  # TODO: ...
  Port(37275)
