!+
! Subroutine create_overlay (ring, ix_overlay, ix_value, n_slave, con_)
!
! Subroutine to add the controller information to slave elements of
! an overlay_lord.
!
! Modules needed:
!   use bmad
!
! Input:
!   ring       -- Ring_struct: Ring to modify.
!   ix_overlay -- Integer: Index of overlay element.
!   ix_value   -- Integer: Index of variable in RING%ELE_(IX_OVERLAY)%VALUE()
!                       that will be varied.
!   n_slave    -- Integer: Number of slaves
!   con_(:)    -- Control_struct: control info. 1 element for each slave.
!     %ix_slave  -- Index of element to control
!     %ix_attrib -- Index of attribute controlled
!     %coef      -- Coefficient
!
! Output:
!   ring    -- Ring_struct: Modified ring.
!
! Note: Use NEW_CONTROL to get an index for the overlay element
!
! Example:
!   call new_control (ring, ix_ele)        ! get IX_ELE index
!   ring%ele_(ix_ele)%name = 'OVERLAY1'    ! overlay name
!   ring%ele_(ix_ele)%value(command$) = 0  ! start at zero
!   n_control = 2                          ! control 2 elements
!
!   con_(1)%ix_slave = 10   ! RING%ELE_(10) is Q01W say.
!   con_(1)%ix_attrib = k1$ ! The overlay controls the quadrupole strength.
!   con_(1)%coef = 0.1      ! A change in the overlay value of 1 produces
!                           !    a change of 0.1 in k1 of element 10.
!
!   con_(2)%ix_slave = 790  ! RING%ELE_(790) is Q01E say.
!   con_(2)%ix_attrib = k1$ ! The overlay controls the quadrupole strength.
!   con_(2)%coef = 0.1      ! make changes antisymmetric.
!
!   call create_overlay (ring, ix_ele, k1$, 2, con_)  ! create the overlay
!-

#include "CESR_platform.inc"

subroutine create_overlay (ring, ix_overlay, ix_value, n_slave, con_)

  use bmad_struct
  use bmad_interface

  implicit none

  type (ring_struct)  ring
  type (ele_struct)  slave_ele, over_ele
  type (control_struct)  con_(:)

  integer i, j, ix, ix2, ixc, ix_overlay, n_con2
  integer ix_slave, n_slave, ix_value, slave_type, idel

! Mark element as an overlay lord

  ix = ring%n_control_max
  n_con2 = ix + n_slave
  if (n_con2 > size(ring%control_)) &
                      ring%control_ => reallocate (ring%control_, n_con2+500)

  do j = 1, n_slave
    ring%control_(ix+j) = con_(j)
    ring%control_(ix+j)%ix_lord = ix_overlay
  enddo

  ring%ele_(ix_overlay)%ix_value = ix_value
  ring%ele_(ix_overlay)%n_slave = n_slave
  ring%ele_(ix_overlay)%ix1_slave = ix + 1
  ring%ele_(ix_overlay)%ix2_slave = ix + n_slave
  ring%n_control_max = n_con2
  ring%ele_(ix_overlay)%control_type = overlay_lord$
  ring%ele_(ix_overlay)%key = overlay$

! Loop over all slaves
! Free elements convert to overlay slaves.

  over_ele = ring%ele_(ix_overlay)

  do i = over_ele%ix1_slave, over_ele%ix2_slave

    ix_slave = ring%control_(i)%ix_slave

    if (ix_slave <= 0) then
      print *, 'ERROR IN CREATE_OVERLAY: INDEX OUT OF BOUNDS.', ix_slave
      call err_exit
    endif

    slave_ele = ring%ele_(ix_slave)
    slave_type = slave_ele%control_type

    if (slave_type == free$) ring%ele_(ix_slave)%control_type =  &
                                                            overlay_slave$

! You cannot overlay super_slaves or overlay_lords

    if (slave_type == super_slave$) then
      print *, 'ERROR IN CREATE_OVERLAY: ILLEGAL OVERLAY ON ',  &
                                             ring%ele_(ix_slave)%name
      print *, '      BY: ', over_ele%name
      call err_exit
    endif

! update controller info for the slave ele

    ring%ele_(ix_slave)%n_lord = slave_ele%n_lord + 1
    call adjust_control_struct (ring, ix_slave)
    ixc = ring%ele_(ix_slave)%ic2_lord
    ring%ic_(ixc) = i

  enddo

end subroutine
