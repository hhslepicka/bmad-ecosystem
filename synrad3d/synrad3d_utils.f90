module synrad3d_utils

use synrad3d_struct
use random_mod
use photon_init_mod
use capillary_mod

private sr3d_wall_pt_params

contains

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Subroutine sr3d_check_wall (wall)
!
! Routine to check the vacuum chamber wall for problematic values.
!
! Input:
!   wall -- wall3d_struct: wall structure.
!-

subroutine sr3d_check_wall (wall)

implicit none

type (wall3d_struct), target :: wall
type (wall3d_pt_struct), pointer :: pt

integer i

character(20) :: r_name = 'sr3d_check_wall'

!

do i = 0, wall%n_pt_max
  pt => wall%pt(i)

  if (i > 0) then
    if (pt%s <= wall%pt(i-1)%s) then
      call out_io (s_fatal$, r_name, &
                'WALL%PT(i)%S: \es12.2\ ', &
                '    IS LESS THAN PT(i-1)%S: \es12.2\ ', &
                '    FOR I = \i0\ ', &
                r_array = [pt%s, wall%pt(i-1)%s], i_array = [i])
      call err_exit
    endif
  endif

  if (.not. any(pt%basic_shape == ['elliptical ', 'rectangular', 'gen_shape  '])) then
    call out_io (s_fatal$, r_name, &
              'BAD WALL%PT(i)%BASIC_SHAPE: ' // pt%basic_shape, &
              '    FOR I = \i0\ ', i_array = [i])
    call err_exit
  endif

  if (pt%basic_shape == 'gen_shape') then
    if (pt%ix_gen_shape < 1) then
      call out_io (s_fatal$, r_name, &
              'BAD WALL%PT(I)%IX_GEN_SHAPE INDEX FOR I = \i0\ ', i_array = [i])
      call err_exit
    endif

    cycle
  endif


  if (pt%width2 <= 0) then
    call out_io (s_fatal$, r_name, &
              'BAD WALL%PT(i)%WIDTH2: \es12.2\ ', &
              '    FOR I = \i0\ ', r_array = [pt%width2], i_array = [i])
    call err_exit
  endif

  if (pt%width2 <= 0) then
    call out_io (s_fatal$, r_name, &
              'BAD WALL%PT(i)%HEIGHT2: \es12.2\ ', &
              '    FOR I = \i0\ ', r_array = [pt%height2], i_array = [i])
    call err_exit
  endif

  ! +x side check

  if (pt%ante_height2_plus < 0 .and.pt%width2_plus > 0) then
    if (pt%width2_plus > pt%width2) then
      call out_io (s_fatal$, r_name, &
              'WITHOUT AN ANTECHAMBER: WALL%PT(i)%WIDTH2_PLUS \es12.2\ ', &
              '    MUST BE LESS THEN WIDTH2 \es12.2\ ', &
              '    FOR I = \i0\ ', &
              r_array = [pt%width2_plus, pt%width2], i_array = [i])
      call err_exit
    endif
  endif

  ! -x side check

  if (pt%ante_height2_minus < 0 .and. pt%width2_minus > 0) then
    if (pt%width2_minus > pt%width2) then
      call out_io (s_fatal$, r_name, &
              'WITHOUT AN ANTECHAMBER: WALL%PT(i)%WIDTH2_MINUS \es12.2\ ', &
              '    MUST BE LESS THEN WIDTH2 \es12.2\ ', &
              '    FOR I = \i0\ ', &
              r_array = [pt%width2_minus, pt%width2], i_array = [i])
      call err_exit
    endif
  endif

enddo

! computations

do i = 0, wall%n_pt_max
  pt => wall%pt(i)

  ! +x side computation

  if (pt%ante_height2_plus > 0) then
    if (pt%basic_shape == 'elliptical') then
      pt%ante_x0_plus = pt%width2 * sqrt (1 - (pt%ante_height2_plus / pt%height2)**2)
    else
      pt%ante_x0_plus = pt%width2
    endif

    if (pt%width2_plus <= pt%ante_x0_plus) then
      call out_io (s_fatal$, r_name, &
              'WITH AN ANTECHAMBER: WALL%PT(i)%WIDTH2_PLUS \es12.2\ ', &
              '    MUST BE GREATER THEN: \es12.2\ ', &
              '    FOR I = \i0\ ', &
              r_array = [pt%width2_plus, pt%ante_x0_plus], i_array = [i])
      call err_exit
    endif

  elseif (pt%width2_plus > 0) then
    if (pt%basic_shape == 'elliptical') then
      pt%y0_plus = pt%height2 * sqrt (1 - (pt%width2_plus / pt%width2)**2)
    else
      pt%y0_plus = pt%height2
    endif
  endif

  ! -x side computation

  if (pt%ante_height2_minus > 0) then
    if (pt%basic_shape == 'elliptical') then
      pt%ante_x0_minus = pt%width2 * sqrt (1 - (pt%ante_height2_minus / pt%height2)**2)
    else
      pt%ante_x0_minus = pt%width2
    endif

    if (pt%width2_minus <= pt%ante_x0_minus) then
      call out_io (s_fatal$, r_name, &
              'WITH AN ANTECHAMBER: WALL%PT(i)%WIDTH2_MINUS \es12.2\ ', &
              '    MUST BE GREATER THEN: \es12.2\ ', &
              '    FOR I = \i0\ ', &
              r_array = [pt%width2_minus, pt%ante_x0_minus], i_array = [i])

      call err_exit
    endif

  elseif (pt%width2_minus > 0) then
    if (pt%basic_shape == 'elliptical') then
      pt%y0_minus = pt%height2 * sqrt (1 - (pt%width2_minus / pt%width2)**2)
    else
      pt%y0_minus = pt%height2
    endif
  endif

enddo

end subroutine

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Subroutine sr3d_get_emission_pt_params (lat, orb, ix_ele, s_offset, ele_here, orb_here, gx, gy)
!
! Routine to get the parameters at a photon emission point.
!
! Modules needed:
!   use synrad3d_utils
!
! Input:
!   lat       -- lat_struct with twiss propagated and mat6s made.
!   orb(0:*)  -- coord_struct: orbit of particles to use as source of ray.
!   ix_ele    -- integer: index of lat element to start ray from.
!   s_offset  -- real(rp): Distance from beginning of element to the point where the photon is emitted.
!
! Output:
!   ele_here  -- ele_struct: Twiss parameters at emission point.
!   orb_here  -- coord_struct: Beam center coords at emission point.
!   gx        -- Real(rp): Horizontal 1/bending_radius.
!   gy        -- Real(rp): Vertical 1/bending_radius.
!-

subroutine sr3d_get_emission_pt_params (lat, orb, ix_ele, s_offset, ele_here, orb_here, gx, gy)

use em_field_mod

implicit none

type (lat_struct), target :: lat
type (coord_struct) :: orb(0:), orb_here, orb1
type (ele_struct), pointer :: ele
type (ele_struct) ele_here
type (photon3d_coord_struct) :: photon
type (em_field_struct) :: field

real(rp) s_offset, k_wig, g_max, l_small, gx, gy
real(rp), save :: s_old_offset = 0

integer ix_ele

logical err
logical, save :: init_needed = .true.

! Init

if (init_needed) then
  call init_ele (ele_here)
  init_needed = .false.
endif

ele  => lat%ele(ix_ele)

! Calc the photon's initial twiss values.
! Tracking through a wiggler can take time so use twiss_and_track_intra_ele to
!   minimize the length over which we track.

if (ele_here%ix_ele /= ele%ix_ele .or. ele_here%ix_branch /= ele%ix_branch .or. s_old_offset > s_offset) then
  ele_here = lat%ele(ix_ele-1)
  ele_here%ix_ele = ele%ix_ele
  ele_here%ix_branch = ele%ix_branch
  orb_here = orb(ix_ele-1)
  s_old_offset = 0
endif

call twiss_and_track_intra_ele (ele, lat%param, s_old_offset, s_offset, .true., .true., &
                                            orb_here, orb_here, ele_here, ele_here, err)
if (err) call err_exit
s_old_offset = s_offset

! Calc the photon's g_bend value (inverse bending radius at src pt) 

select case (ele%key)
case (sbend$)  

  ! sbends are easy
  gx = 1 / ele%value(rho$)
  gy = 0
  if (ele%value(roll$) /= 0) then
    gy = gx * sin(ele%value(roll$))
    gx = gx * cos(ele%value(roll$))
  endif

case (quadrupole$, sol_quad$, elseparator$)

  ! for quads or sol_quads, get the bending radius
  ! from the change in x' and y' over a small 
  ! distance in the element

  l_small = 1e-2      ! something small
  ele_here%value(l$) = l_small
  call make_mat6 (ele_here, lat%param, orb_here, orb_here)
  call track1 (orb_here, ele_here, lat%param, orb1)
  orb1%vec = orb1%vec - orb_here%vec
  gx = orb1%vec(2) / l_small
  gy = orb1%vec(4) / l_small

case (wiggler$)

  if (ele%sub_key == periodic_type$) then

    ! for periodic wigglers, get the max g_bend from 
    ! the max B field of the wiggler, then scale it 
    ! by the cos of the position along the poles

    k_wig = twopi * ele%value(n_pole$) / (2 * ele%value(l$))
    g_max = c_light * ele%value(b_max$) / (ele%value(p0c$))
    gx = g_max * sin (k_wig * s_offset)
    gy = 0
    orb_here%vec(1) = (g_max / k_wig) * sin (k_wig * s_offset)
    orb_here%vec(2) = (g_max / k_wig) * cos (k_wig * s_offset)

  else

    ! for mapped wigglers, find the B field at the source point
    ! Note: assumes particles are relativistic!!

    call em_field_calc (ele_here, lat%param, ele_here%value(l$), orb_here, .false., field)
    gx = field%b(2) * c_light / ele%value(p0c$)
    gy = field%b(1) * c_light / ele%value(p0c$)

  endif

case default

  print *, 'ERROR: UNKNOWN ELEMENT HERE ', ele%name

end select

end subroutine


!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Subroutine sr3d_emit_photon (ele_here, orb_here, gx, gy, emit_a, emit_b, sig_e, photon_direction, photon)
!
! subroutine sr3d_to initialize a new photon
!
! Modules needed:
!   use synrad3d_utils
!
! Input:
!   ele_here  -- Ele_struct: Element emitting the photon. Emission is at the exit end of the element.
!   orb_here  -- coord_struct: orbit of particles emitting the photon.
!   gx, gy    -- Real(rp): Horizontal and vertical bending strengths.
!   emit_a    -- Real(rp): Emittance of the a-mode.
!   emit_b    -- Real(rp): Emittance of the b-mode.
!   photon_direction 
!             -- Integer: +1 In the direction of increasing s.
!                         -1 In the direction of decreasing s.
!
! Output:
!   photon    -- photon_coord_struct: Generated photon.
!-

subroutine sr3d_emit_photon (ele_here, orb_here, gx, gy, emit_a, emit_b, sig_e, photon_direction, p_orb)

implicit none

type (ele_struct), target :: ele_here
type (coord_struct) :: orb_here
type (photon3d_coord_struct) :: p_orb
type (twiss_struct), pointer :: t

real(rp) emit_a, emit_b, sig_e, gx, gy, g_tot, gamma
real(rp) orb(6), r(3), vec(4), v_mat(4,4)

integer photon_direction

! Get photon energy and "vertical angle".

g_tot = sqrt(gx**2 + gy**2)
call convert_total_energy_to (ele_here%value(E_tot$), electron$, gamma) 
call photon_init (g_tot, gamma, orb)
p_orb%energy = orb(6)
p_orb%vec = 0
p_orb%vec(4) = orb(4) / sqrt(orb(4)**2 + 1)

! rotate photon if gy is non-zero

if (gy /= 0) then
  p_orb%vec(2) = gy * p_orb%vec(4) / g_tot
  p_orb%vec(4) = gx * p_orb%vec(4) / g_tot
endif

! Offset due to finite beam size

call ran_gauss(r)
t => ele_here%a
vec(1:2) = (/ sqrt(t%beta*emit_a) * r(1)                    + t%eta  * sig_e * r(3), &
              sqrt(emit_a/t%beta) * (r(2) + t%alpha * r(1)) + t%etap * sig_e * r(3) /)

call ran_gauss(r)
t => ele_here%b
vec(3:4) = (/ sqrt(t%beta*emit_b) * r(1)                    + t%eta  * sig_e * r(3), &
              sqrt(emit_b/t%beta) * (r(2) + t%alpha * r(1)) + t%etap * sig_e * r(3) /)

call make_v_mats (ele_here, v_mat)

p_orb%vec(1:4) = p_orb%vec(1:4) + matmul(v_mat, vec)

! Offset due to non-zero orbit.

p_orb%vec(1:4) = p_orb%vec(1:4) + orb_here%vec(1:4)

! Longitudinal position

p_orb%vec(5) = ele_here%s

! Note: phase space coords here are different from the normal beam and photon coords.
! Here vec(2)^2 + vec(4)^2 + vec(6)^2 = 1

p_orb%vec(6) = photon_direction * sqrt(1 - orb(2)**2 - orb(4)**2)

end subroutine

!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!+
! Subroutine sr3d_photon_radius (p_orb, wall, radius, dw_perp, in_antechamber)
!
! Routine to calculate the normalized transverse position of the photon 
! relative to the wall: 
!     radius = 0 => Center of the beam pipe 
!     radius = 1 => at wall.
!     radius > 1 => Outside the beam pipe.
!
! Modules needed:
!   use photon_utils
!
! Input:
!   wall -- wall3d_struct: Wall
!   s    -- Real(rp): Longitudinal position.
!
! Output:
!   radius       -- real(rp): Radius of beam relative to the wall.
!   dw_perp(3)   -- real(rp), optional: Outward normal vector perpendicular to the wall.
!   in_antechamber -- Logical, optional: At antechamber wall?
!-

Subroutine sr3d_photon_radius (p_orb, wall, radius, dw_perp, in_antechamber)

implicit none

type (wall3d_struct), target :: wall
type (photon3d_coord_struct), target :: p_orb

real(rp), optional :: dw_perp(:)
real(rp) g0, g1, f, radius
real(rp) dw_x0, dw_y0, dw_x1, dw_y1
real(rp), pointer :: vec(:)

integer ix

logical, optional :: in_antechamber
logical in_ante0, in_ante1

! There is a sigularity in the calculation when the photon is at the origin.
! To avoid this, just return radius = 0 for small radii.

vec => p_orb%vec

if (abs(vec(1)) < 1e-6 .and. abs(vec(3)) < 1e-6) then
  radius = 0
  if (present (dw_perp)) dw_perp = 0
  if (present(in_antechamber)) in_antechamber = .false.
  return
endif

!

call bracket_index (wall%pt%s, 0, wall%n_pt_max, vec(5), ix)
p_orb%ix_wall = ix

if (ix == wall%n_pt_max) ix = wall%n_pt_max - 1

! The outward normal vector is discontinuous at the wall points.
! If at a wall point, use the correct part of the wall.

if (vec(5) == wall%pt(ix)%s .and. vec(6) > 0) then
  if (ix /= 0) then
    ix = ix - 1
  endif
endif

!

call sr3d_wall_pt_params (wall%pt(ix),   vec, g0, dw_x0, dw_y0, in_ante0, wall)
call sr3d_wall_pt_params (wall%pt(ix+1), vec, g1, dw_x1, dw_y1, in_ante1, wall)

f = (vec(5) - wall%pt(ix)%s) / (wall%pt(ix+1)%s - wall%pt(ix)%s)
radius = 1 / ((1 - f) * g0 + f * g1)

if (present (dw_perp)) then
  dw_perp(1) = (1 - f) * dw_x0 + f * dw_x1
  dw_perp(2) = (1 - f) * dw_y0 + f * dw_y1
  dw_perp(3) = (g0 - g1) / (wall%pt(ix+1)%s - wall%pt(ix)%s)
  dw_perp = dw_perp / sqrt(sum(dw_perp**2))  ! Normalize
endif

if (present(in_antechamber)) in_antechamber = (in_ante0 .or. in_ante1)

end subroutine sr3d_photon_radius

!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!-------------------------------------------------------------------------------------------
!+
! Subroutine sr3d_wall_pt_params (wall_pt, vec, g, dw_x, dw_y, in_antechamber, wall)
!
! Routine to compute parameters needed by sr3d_photon_radius routine.
!
! Input:
!   wall_pt -- wall3d_pt_struct: Wall outline at a particular longitudinal location.
!   vec(6)  -- Real(rp): Photon phase space coords. 
!
! Output:
!   g              -- Real(rp): Radius of the wall / radius of the photon.
!   [dw_x, dw_y]   -- Real(rp): Transverse directional derivatives of -g.
!   in_antechamber -- Logical: Set true of particle is in antechamber
!-

subroutine sr3d_wall_pt_params (wall_pt, vec, g, dw_x, dw_y, in_antechamber, wall)

implicit none

type (wall3d_pt_struct) wall_pt, pt
type (wall3d_struct), target :: wall
type (cross_section_vertex_struct), pointer :: v(:)

real(rp) g, dw_x, dw_y, vec(6), r_p, r_w, theta, numer, denom
real(rp) r_wall, r_photon, gradient(2)

integer ix

logical in_antechamber

! Init

in_antechamber = .false.

! general shape

if (wall_pt%basic_shape == 'gen_shape') then
  call calc_wall_radius (wall%gen_shape(wall_pt%ix_gen_shape)%v, atan2(vec(3), vec(1)), r_wall, gradient)
  r_photon = sqrt(vec(1)**2 + vec(3)**2)
  g = r_wall / r_photon
  dw_x = gradient(1) * g / r_photon
  dw_y = gradient(2) * g / r_photon
  return
endif

! Check for antechamber or beam stop...
! If the line extending from the origin through the photon intersects the
! antechamber or beam stop then pretend the chamber is rectangular with the 
! antechamber or beam stop dimensions.

! Positive x side check.

pt = wall_pt

if (vec(1) > 0) then

  ! If there is an antechamber...
  if (pt%ante_height2_plus > 0) then

    if (abs(vec(3)/vec(1)) < pt%ante_height2_plus/pt%ante_x0_plus) then  
      pt%basic_shape = 'rectangular'
      pt%width2 = pt%width2_plus
      pt%height2 = pt%ante_height2_plus
      if (vec(1) >= pt%ante_x0_plus) in_antechamber = .true.
    endif

  ! If there is a beam stop...
  elseif (pt%width2_plus > 0) then
    if (abs(vec(3)/vec(1)) < pt%y0_plus/pt%width2_plus) then 
      pt%basic_shape = 'rectangular'
      pt%width2 = pt%width2_plus
    endif

  endif

! Negative x side check

elseif (vec(1) < 0) then

  ! If there is an antechamber...
  if (pt%ante_height2_minus > 0) then

    if (abs(vec(3)/vec(1)) < pt%ante_height2_minus/pt%ante_x0_minus) then  
      pt%basic_shape = 'rectangular'
      pt%width2 = pt%width2_minus
      pt%height2 = pt%ante_height2_minus
      if (vec(1) >= pt%ante_x0_minus) in_antechamber = .true.
    endif

  ! If there is a beam stop...
  elseif (pt%width2_minus > 0) then
    if (abs(vec(3) / vec(1)) < pt%y0_minus/pt%width2_minus) then 
      pt%basic_shape = 'rectangular'
      pt%width2 = pt%width2_minus
    endif

  endif

endif

! Compute parameters

if (pt%basic_shape == 'rectangular') then
  if (abs(vec(1)/pt%width2) > abs(vec(3)/pt%height2)) then
    g = pt%width2 / abs(vec(1)) 
    dw_x = g / vec(1)
    dw_y = 0
  else
    g = pt%height2 / abs(vec(3))
    dw_x = 0
    dw_y = g / vec(3)
  endif

elseif (pt%basic_shape == 'elliptical') then
  g = 1 / sqrt((vec(1)/pt%width2)**2 + (vec(3)/pt%height2)**2)
  dw_x = vec(1) * g**3 / pt%width2**2
  dw_y = vec(3) * g**3 / pt%height2**2

endif

end subroutine

end module
