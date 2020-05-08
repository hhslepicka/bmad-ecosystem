!+
! function sinc(x, nd) result (y)
!
! Routine to calculate sin(x) / x and derivatives.
!
! Input:
!   x  -- real(rp): Number.
!   nd -- integer, optional: Derivative order. nd = 0 (default) -> compute sin(x) / x
!           NOTE: Currently only nd = 0 and nd = 1 are implemented.
!
! Output:
!   y  -- real(rp): nd^th derivative of sin(x) / x
!-

elemental function sinc(x, nd) result (y)

use utilities_mod
implicit none

real(rp), intent(in) :: x
real(rp) y, x2
real(rp), parameter :: c1 = -1.0_rp / 3.0_rp, c2 = 1.0_rp / 30.0_rp
real(rp), parameter :: c3 = -1.0_rp / 840.0_rp, c4 = 1.0_rp / 45360.0_rp

integer, optional, intent(in) :: nd

!

x2 = x*x

select case (integer_option(0, nd))
case (0)
  if (abs(x) < 1e-8_rp) then
    y = 1.0_rp
  else
    y = sin(x)/x
  end if

case (1)
  if (abs(x) < 0.1_rp) then
    y = x * (c1 + x2 * (c2 + x2 * (c3 + x2 * c4)))
  else
    y = (x*cos(x) - sin(x)) / x2
  endif

end select

end function
