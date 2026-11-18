local rentals = {}

-- Rental screen: rent the first three Pokemon (A, Down to RENT, A, Right), then confirm.
function rentals.rentThree(F)
  F.idle(120); F.shot("rental_screen")
  for _ = 1, 3 do
    F.press("A", 2); F.idle(60)
    F.press("Down", 2); F.idle(30); F.press("A", 2); F.idle(60)
    F.press("Right", 2); F.idle(30)
  end
  F.idle(60); F.shot("rental_confirm")
  F.press("A", 2); F.idle(120)
end

-- Swap screen: trade the first rental for the opponent's first Pokemon. Choosing an opponent's
-- Pokemon opens its picture before the Yes/No, which ignores input until the picture is up.
function rentals.swapFirst(F)
  F.idle(120); F.shot("swap_screen")
  F.press("A", 2); F.idle(60)
  F.press("Down", 2); F.idle(30); F.press("A", 2); F.idle(150)
  F.press("A", 2); F.idle(150)
  F.shot("swap_accept")
  F.press("A", 2); F.idle(150)
end

return rentals
