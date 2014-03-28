module track1_photon_mod

use track1_mod
use wall3d_mod
use photon_utils_mod
use xraylib_interface

! This is for passing info into the field_calc_routine

type, private :: crystal_param_struct
  real(rp) cap_gamma, dtheta_sin_2theta, b_eff, wavelength
  real(rp) old_vvec(3), new_vvec(3)
end type

private e_field_calc

contains

!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!+
! Subroutine track1_diffraction_plate (ele, param, orbit)
!
! Routine to track through a diffraction plate element.
!
! Input:
!   ele      -- ele_struct: Diffraction plate element.
!   param    -- lat_param_struct: lattice parameters.
!   orbit    -- Coord_struct: phase-space coords to be transformed
!
! Output:
!   orbit    -- Coord_struct: final phase-space coords
!-

subroutine track1_diffraction_plate (ele, param, orbit)

implicit none

type (ele_struct), target:: ele
type (coord_struct), target:: orbit
type (lat_param_struct) :: param
type (wall3d_section_struct), pointer :: sec

real(rp) w_to_surface(3,3), vz0
real(rp) wavelength, thickness, absorption, phase_shift

integer ix_sec

logical err_flag

character(60) material

! Photon is lost if in an opaque section

ix_sec = diffraction_plate_hit_spot (ele, orbit)

if (ix_sec == 0) then
  if (ele%wall3d%opaque_material == '') then
    orbit%state = lost$
    return
  endif
  material = ele%wall3d%opaque_material
  thickness = ele%wall3d%thickness

else
  material = ele%wall3d%clear_material
  thickness = ele%wall3d%thickness
  sec => ele%wall3d%section(ix_sec)
  if (sec%material /= '') material = sec%material
  if (sec%thickness >= 0) thickness = sec%thickness
endif

! Transmit through material

if (material /= '') then
  call photon_absorption_and_phase_shift (material, orbit%p0c, absorption, phase_shift, err_flag)
  if (err_flag) then
    orbit%state = lost$
    return
  endif

  orbit%field = orbit%field * exp(-absorption * thickness)
  orbit%phase = orbit%phase - phase_shift * thickness
endif

! Choose outgoing direction

vz0 = orbit%vec(6)
call isotropic_photon_emission (ele, param, orbit, +1, twopi)

! Rescale field

wavelength = c_light * h_planck / orbit%p0c
orbit%field = orbit%field * (vz0 + orbit%vec(6)) / (2 * wavelength)
orbit%phase = orbit%phase - pi / 2

end subroutine track1_diffraction_plate

!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!+
! Function diffraction_plate_hit_spot (ele, orbit) result (ix_section)
!
! Routine to determine where a photon hits on a diffraction_plate element.
!
! Note: It is assumed that orbit is in the frame of reference of the element.
! That is, offset_photon needs to be called before this routine.
!
! Input:
!   ele     -- ele_struct: diffraction_plate element.
!   orbit   -- coord_struct: photon position.
!
! Output:
!   ix_section -- integer, Set to index of clear section hit. Set to zero if
!                   photon is outside all clear areas.
!-

function diffraction_plate_hit_spot (ele, orbit) result (ix_section)

implicit none

type (ele_struct), target :: ele
type (coord_struct) orbit
type (wall3d_struct), pointer :: wall3d

integer :: ix_section
integer i, ix_sec

! Logic: A particle is in a clear section if it is inside the section and outside
! all subsiquent mask sections up to the next clear section.

wall3d => ele%wall3d
ix_section = 0
ix_sec = 0

section_loop: do 

  ! Skip any mask sections

  do
    ix_sec = ix_sec + 1
    if (ix_sec > size(wall3d%section)) exit section_loop
    if (wall3d%section(ix_sec)%type == clear$) exit
  enddo

  ! Section must be clear. Check if photon is within the section

  if (.not. in_section(wall3d%section(ix_sec))) cycle
  ix_section = ix_sec

  ! Now check if photon is within a mask section

  do
    ix_sec = ix_sec + 1
    if (ix_sec > size(wall3d%section)) return           ! In this clear area
    if (wall3d%section(ix_sec)%type == clear$) return   ! In this clear area
    if (in_section(wall3d%section(ix_sec))) cycle section_loop  ! Is masked
  enddo

enddo section_loop

! Not in a clear area...

ix_section = 0

!------------------------------------------------------------
contains

function in_section(sec) result (is_in)

type (wall3d_section_struct) sec
logical is_in

real(rp) x, y, norm, r_wall, dr_dtheta

!

x = orbit%vec(1) - sec%x0;  y = orbit%vec(3) - sec%y0

if (x == 0 .and. y == 0) then
  is_in = .true.
  return
endif

norm = norm2([x, y])
call calc_wall_radius (sec%v, x/norm, y/norm, r_wall, dr_dtheta)
is_in = (norm <= r_wall)

end function in_section

end function diffraction_plate_hit_spot

!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!+
! Subroutine track1_sample (ele, param, orbit)
!
! Routine to track reflection from a sample element.
!
! Input:
!   ele      -- ele_struct: Element tracking through.
!   param    -- lat_param_struct: lattice parameters.
!   orbit    -- Coord_struct: phase-space coords to be transformed
!
! Output:
!   orbit    -- Coord_struct: final phase-space coords
!-

subroutine track1_sample (ele, param, orbit)

implicit none

type (ele_struct), target:: ele
type (coord_struct), target:: orbit
type (lat_param_struct) :: param

real(rp) w_to_surface(3,3), absorption, phase_shift

logical err_flag

character(*), parameter :: r_name = 'track1_sample'

!

call track_to_surface (ele, orbit, curved_surface_rot = .false.)
if (orbit%state /= alive$) return

if (ele%photon%surface%has_curvature) then
  call rotate_for_curved_surface (ele, orbit, set$, w_to_surface)
endif

! Check aperture

if (ele%aperture_at == surface$) then
  call check_aperture_limit (orbit, ele, surface$, param)
  if (orbit%state /= alive$) return
endif

! Reflect 

select case (nint(ele%value(mode$)))
case (reflection$)

  call isotropic_photon_emission (ele, param, orbit, -1, fourpi, w_to_surface)

case (transmission$)
  call photon_absorption_and_phase_shift (ele%component_name, orbit%p0c, absorption, phase_shift, err_flag)
  if (err_flag) then
    orbit%state = lost$
    return
  endif

  orbit%field = orbit%field * exp(-absorption * ele%value(l$))
  orbit%phase = orbit%phase - phase_shift * ele%value(l$)

case default
  call out_io (s_error$, r_name, 'MODE NOT SET.')
  orbit%state = lost$
end select

! Rotate back to uncurved element coords

if (ele%photon%surface%has_curvature) then
  call rotate_for_curved_surface (ele, orbit, unset$)
endif

end subroutine track1_sample

!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!+
! Subroutine isotropic_photon_emission (ele, param, orbit, direction, solid_angle, w_to_surface)
!
! Routine to emit a photon from a surface in a random direction.
!
! Input:
!   ele                -- ele_struct: Emitting element.
!   param              -- lat_param_struct: lattice parameters.
!   orbit              -- Coord_struct: phase-space coords of photon.
!   direction          -- Integer: +1 -> Emit in forward +z direction, -1 -> emit backwards.
!   solid_angle        -- real(rp): Solid angle photons may be emitted over.
!   w_to_surface(3,3)  -- real(rp), optional: Rotation matrix for curved surface.
!
! Output:
!   orbit    -- Coord_struct: Final phase-space coords
!-

subroutine isotropic_photon_emission (ele, param, orbit, direction, solid_angle, w_to_surface)

implicit none

type (ele_struct), target:: ele
type (coord_struct), target:: orbit
type (lat_param_struct) :: param
type (photon_target_struct), pointer :: target
type (target_point_struct) corner(8)

real(rp), optional :: w_to_surface(3,3)
real(rp) ran(2), r_particle(3), w_to_target(3,3), w_to_ele(3,3)
real(rp) phi_min, phi_max, y_min, y_max, y, phi, rho, r(3), solid_angle

integer direction
integer n, i, ix

!

call ran_uniform(ran)

target => ele%photon%target
if (target%enabled) then
  r_particle = orbit%vec(1:5:2)
  r = target%center%r - r_particle
  if (ele%photon%surface%has_curvature) r = matmul(w_to_surface, r)
  call target_rot_mats (r, w_to_target, w_to_ele)

  do i = 1, target%n_corner
    r = target%corner(i)%r - r_particle
    if (direction == 1) then
      if (r(3) < 0) r(3) = 0   ! photon cannot be emitted backward
    elseif (direction == -1) then
      if (r(3) > 0) r(3) = 0   ! photon cannot be emitted forward
    else
      call err_exit
    endif
    r = matmul(w_to_target, r)
    if (ele%photon%surface%has_curvature) r = matmul(w_to_surface, r)
    corner(i)%r = r / norm2(r)
  enddo

  call target_min_max_calc (corner(4)%r, corner(1)%r, y_min, y_max, phi_min, phi_max, .true.)
  call target_min_max_calc (corner(1)%r, corner(2)%r, y_min, y_max, phi_min, phi_max)
  call target_min_max_calc (corner(2)%r, corner(3)%r, y_min, y_max, phi_min, phi_max)
  call target_min_max_calc (corner(3)%r, corner(4)%r, y_min, y_max, phi_min, phi_max)

  if (target%n_corner == 8) then
    call target_min_max_calc (corner(8)%r, corner(5)%r, y_min, y_max, phi_min, phi_max)
    call target_min_max_calc (corner(5)%r, corner(6)%r, y_min, y_max, phi_min, phi_max)
    call target_min_max_calc (corner(6)%r, corner(7)%r, y_min, y_max, phi_min, phi_max)
    call target_min_max_calc (corner(7)%r, corner(8)%r, y_min, y_max, phi_min, phi_max)
  endif

  if (y_min >= y_max .or. phi_min >= phi_max) then
    orbit%state = lost$
    return
  endif

  y = y_min + (y_max-y_min) * ran(1)
  phi = phi_min + (phi_max-phi_min) * ran(2)
  rho = sqrt(1 - y*y)
  orbit%vec(2:6:2) = [rho * sin(phi), y, rho * cos(phi)]
  orbit%vec(2:6:2) = matmul(w_to_ele, orbit%vec(2:6:2))

  if (param%tracking_mode == coherent$) then
    orbit%field = orbit%field * (y_max - y_min) * (phi_max - phi_min) / solid_angle
    ! If path_len = 0 then assume that photon is being initialized so only normalize field if path_len /= 0
    if (orbit%path_len /= 0) then
      orbit%field = orbit%field * orbit%path_len
      orbit%path_len = 0
    endif
  else
    orbit%field = orbit%field * sqrt ((y_max - y_min) * (phi_max - phi_min) / solid_angle)
  endif

else
  y = 2 * ran(1) - 1
  phi = pi * (ran(2) - 0.5_rp)
  rho = sqrt(1 - y**2)
  orbit%vec(2:6:2) = [rho * sin(phi), y, direction * rho * cos(phi)]
  ! Without targeting photons are emitted into twopi solid angle.
  if (param%tracking_mode == coherent$) then
    orbit%field = orbit%field * twopi / solid_angle
    ! If path_len = 0 then assume that photon is being initialized so only normalize field if path_len /= 0
    if (orbit%path_len /= 0) then
      orbit%field = orbit%field * orbit%path_len
      orbit%path_len = 0
    endif
  else
    orbit%field = orbit%field * sqrt(twopi / solid_angle)
  endif
endif

end subroutine isotropic_photon_emission 

!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!+
! Subroutine track1_mirror (ele, param, orbit)
!
! Routine to track reflection from a mirror.
!
! Input:
!   ele      -- ele_struct: Element tracking through.
!   param    -- lat_param_struct: lattice parameters.
!   orbit    -- Coord_struct: phase-space coords to be transformed
!
! Output:
!   orbit    -- Coord_struct: final phase-space coords
!-

subroutine track1_mirror (ele, param, orbit)

implicit none

type (ele_struct), target:: ele
type (coord_struct), target:: orbit
type (lat_param_struct) :: param

real(rp) wavelength
real(rp), pointer :: val(:)

character(*), parameter :: r_name = 'track1_mirror'

!

val => ele%value
wavelength = c_light * h_planck / orbit%p0c

call track_to_surface (ele, orbit)
if (orbit%state /= alive$) return

! Check aperture

if (ele%aperture_at == surface$) then
  call check_aperture_limit (orbit, ele, surface$, param)
  if (orbit%state /= alive$) return
endif

! Reflect momentum vector

orbit%vec(6) = -orbit%vec(6)

! Rotate back to uncurved element coords

if (ele%photon%surface%has_curvature) then
  call rotate_for_curved_surface (ele, orbit, unset$)
endif

end subroutine track1_mirror

!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!+
! Subroutine track1_multilayer_mirror (ele, param, orbit)
!
! Routine to track reflection from a multilayer_mirror.
! Basic equations are from Kohn, "On the Theory of Reflectivity of an X-Ray Multilayer Mirror".
!
! Input:
!   ele    -- ele_struct: Element tracking through.
!   param  -- lat_param_struct: lattice parameters.
!   orbit    -- Coord_struct: phase-space coords to be transformed
!
! Output:
!   orbit    -- Coord_struct: final phase-space coords
!-

subroutine track1_multilayer_mirror (ele, param, orbit)

implicit none

type (ele_struct), target:: ele
type (coord_struct), target:: orbit
type (lat_param_struct) :: param

real(rp) wavelength, kz_air
real(rp), pointer :: val(:)

complex(rp) zero, xi_1, xi_2, kz1, kz2, c1, c2

character(*), parameter :: r_name = 'track1_multilayer_mirror'

!

val => ele%value
wavelength = c_light * h_planck / orbit%p0c

call track_to_surface (ele, orbit)
if (orbit%state /= alive$) return

! Check aperture

if (ele%aperture_at == surface$) then
  call check_aperture_limit (orbit, ele, surface$, param)
  if (orbit%state /= alive$) return
endif

! Note: Koln z-axis = Bmad x-axis.
! Note: f0_re and f0_im are both positive.

xi_1 = -conjg(ele%photon%material%f0_m1) * r_e * wavelength**2 / (pi * val(v1_unitcell$)) 
xi_2 = -conjg(ele%photon%material%f0_m2) * r_e * wavelength**2 / (pi * val(v2_unitcell$)) 

kz1 = twopi * sqrt(orbit%vec(6)**2 + xi_1) / wavelength
kz2 = twopi * sqrt(orbit%vec(6)**2 + xi_2) / wavelength
kz_air = twopi * orbit%vec(6) / wavelength

c1 = exp(I_imaginary * kz1 * val(d1_thickness$) / 2)
c2 = exp(I_imaginary * kz2 * val(d2_thickness$) / 2)

zero = cmplx(0.0_rp, 0.0_rp)

call multilayer_track (xi_1, xi_2, orbit%field(1), orbit%phase(1))     ! pi polarization
call multilayer_track (zero, zero, orbit%field(2), orbit%phase(2))     ! sigma polarization

! Reflect momentum vector

orbit%vec(6) = -orbit%vec(6)

! Rotate back to uncurved element coords

if (ele%photon%surface%has_curvature) then
  call rotate_for_curved_surface (ele, orbit, unset$)
endif

!-----------------------------------------------------------------------------------------------
contains

subroutine multilayer_track (xi1_coef, xi2_coef, e_field, e_phase)

real(rp) e_field, e_phase

complex(rp) xi1_coef, xi2_coef, r_11, r_22, tt, denom, k1, k2
complex(rp) a, v, f_minus, f_plus, r_ratio, f, r, ttbar, nu, exp_half, exp_n
complex(rp) Rc_n_top, R_tot, k_a, r_aa, Rc_1_bot, Rc_1_top

integer i, n1

! Rc_n_top is the field ratio for the top layer of cell n.
! Rc_n_bot is the field ratio for the bottom layer of cell n.
! Rc_1_bot for the bottom layer just above the substrate is assumed to be zero.
! Upgrade: If we knew the substrate material we would not have to make this assumption.

Rc_1_bot = 0

! Compute Rc_1_top.
! The top layer of a cell is labeled "2" and the bottom "1". See Kohn Eq 6.

k1 = (1 + xi2_coef) * kz1
k2 = (1 + xi1_coef) * kz2
denom = k1 + k2

r_11 = c1**2 * (k1 - k2) / denom
r_22 = c2**2 * (k2 - k1) / denom

tt = 4 * k1 * k2 * (c1 * c2 / denom)**2    ! = t_12 * t_21

Rc_1_top = r_22 + tt * Rc_1_bot / (1 - r_11 * Rc_1_bot)

! Now compute the single cell factors. See Kohn Eq. 12.
! Note: If you go through the math you will find r = r_bar.

f = tt / (1 - r_11**2)
r = r_22 + r_11 * f
ttbar = f**2

! Calc Rc_n_top. See Kohn Eq. 21. Note that there are n-1 cells in between. 

a = (1 - ttbar + r**2) / 2
nu = (1 + ttbar - r**2) / (2 * sqrt(ttbar))
n1 = nint(val(n_cell$)) - 1

exp_half = nu + I_imaginary * sqrt(1 - nu**2)
exp_n = exp_half ** (2 * n1)
f_plus  = a - I_imaginary * sqrt(ttbar) * sqrt(1 - nu**2)
f_minus = a + I_imaginary * sqrt(ttbar) * sqrt(1 - nu**2)
Rc_n_top = r * (r - Rc_1_top * f_minus - (r - Rc_1_top * f_plus) * exp_n) / &
               (f_plus * (r - Rc_1_top * f_minus) - f_minus * (r - Rc_1_top * f_plus) * exp_n)

! Now factor in the air interface

k_a = kz_air
denom = k_a + k2

tt = 4 * k_a * k2 * (c2 / denom)**2
r_aa = (k_a - k2) / denom
r_22 = c2**2 * (k2 - k_a) / denom

R_tot = r_aa + tt * Rc_n_top / (1 - r_22 * Rc_n_top)

e_field = e_field * abs(R_tot)
e_phase = e_phase + atan2(aimag(R_tot), real(R_tot))

end subroutine multilayer_track 

end subroutine track1_multilayer_mirror

!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!+
! Subroutine track1_crystal (ele, param, orbit)
!
! Routine to track reflection from a crystal.
!
! Input:
!   ele      -- ele_struct: Element tracking through.
!   param    -- lat_param_struct: lattice parameters.
!   orbit    -- Coord_struct: phase-space coords to be transformed
!
! Output:
!   orbit    -- Coord_struct: final phase-space coords
!-

subroutine track1_crystal (ele, param, orbit)

implicit none

type (ele_struct), target:: ele
type (coord_struct), target:: orbit
type (lat_param_struct) :: param
type (crystal_param_struct) cp

real(rp) h_bar(3), e_tot, pc, p_factor
real(rp) gamma_0, gamma_h, dr1(3), dr2(3)

character(*), parameter :: r_name = 'track1_cyrstal'

! A graze angle of zero means the wavelength of the reference photon was too large
! for the bragg condition. 

if (ele%value(bragg_angle_in$) == 0) then
  call out_io (s_fatal$, r_name, 'REFERENCE ENERGY TOO SMALL TO SATISFY BRAGG CONDITION!')
  orbit%state = lost_z_aperture$
  if (global_com%exit_on_error) call err_exit
  return
endif

!

cp%wavelength = c_light * h_planck / orbit%p0c
cp%cap_gamma = r_e * cp%wavelength**2 / (pi * ele%value(v_unitcell$)) 

! (px, py, pz) coords are with respect to laboratory reference trajectory.
! Convert this vector to k0_outside_norm which are coords with respect to crystal surface.
! k0_outside_norm is normalized to 1.

call track_to_surface (ele, orbit)
if (orbit%state /= alive$) return

cp%old_vvec = orbit%vec(2:6:2)

! Check aperture

if (ele%aperture_at == surface$) then
  call check_aperture_limit (orbit, ele, surface$, param)
  if (orbit%state /= alive$) return
endif

! Construct h_bar = H * wavelength.

h_bar = ele%photon%material%h_norm
if (ele%photon%surface%grid%type == h_misalign$) call crystal_h_misalign (ele, orbit, h_bar) 
h_bar = h_bar * cp%wavelength / ele%value(d_spacing$)

! cp%new_vvec is the normalized outgoing wavevector outside the crystal

cp%new_vvec = orbit%vec(2:6:2) + h_bar

if (ele%value(b_param$) < 0) then ! Bragg
  cp%new_vvec(3) = -sqrt(1 - cp%new_vvec(1)**2 - cp%new_vvec(2)**2)
else
  cp%new_vvec(3) = sqrt(1 - cp%new_vvec(1)**2 - cp%new_vvec(2)**2)
endif

! Calculate some parameters

gamma_0 = cp%old_vvec(3)
gamma_h = cp%new_vvec(3)

cp%b_eff = gamma_0 / gamma_h
cp%dtheta_sin_2theta = -dot_product(h_bar + 2 * cp%old_vvec, h_bar) / 2

! E field calc

p_factor = cos(ele%value(bragg_angle_in$) + ele%value(bragg_angle_out$))
call e_field_calc (cp, orbit, ele, param, p_factor, .true.,  orbit%field(1), orbit%phase(1), dr1)
call e_field_calc (cp, orbit, ele, param, 1.0_rp,   .false., orbit%field(2), orbit%phase(2), dr2)   ! Sigma pol

! Average trajectories for the two polarizations weighted by the fields.
! This approximation is valid as long as the two trajectories are "close" enough.

orbit%vec(1:5:2) = orbit%vec(1:5:2) + &
                      (dr1 * orbit%field(1) + dr2 * orbit%field(2)) / (orbit%field(1) + orbit%field(2))

! Rotate back from curved body coords to element coords

if (ele%value(b_param$) < 0) then ! Bragg
  orbit%vec(2:6:2) = cp%new_vvec
else
  ! forward_diffracted and undiffracted beams do not have an orientation change.
  if (nint(ele%value(ref_orbit_follows$)) == bragg_diffracted$) orbit%vec(2:6:2) = cp%new_vvec
endif

if (ele%photon%surface%has_curvature) then
  call rotate_for_curved_surface (ele, orbit, unset$)
endif

end subroutine track1_crystal

!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!+
! Subroutine e_field_calc (cp, orbit, ele, param, p_factor, do_branch_calc, e_field, e_phase, dr)
!
! Routine to compute position where crystal reflects in crystal coordinates.
!
! Input:
!   cp             -- crystal_param_struct: Crystal parameters.
!   orbit          -- coord_struct: Initial orbit.
!   ele            -- ele_struct: Crystal element.
!   param          -- lat_param_struct: 
!   p_factor       -- Real(rp): Polarization factor.
!   do_branch_calc -- Logical: Calculate probability of branching to alpha or beta branches?
!   e_field        -- Real(rp): Input field amplitude.
!   e_phase        -- Real(rp): Input field phase.
!
! Output:
!   orbit          -- coord_struct: Position is shifted for Laue diffraction.
!   e_field        -- Real(rp): Output field amplitude.
!   e_phase        -- Real(rp): Output field phase.
!   dr(3)          -- Real(rp): (x,y,z) orbit change.
!-

subroutine e_field_calc (cp, orbit, ele, param, p_factor, do_branch_calc, e_field, e_phase, dr)

type (crystal_param_struct) cp
type (coord_struct) orbit
type (ele_struct), target :: ele
type (lat_param_struct) param
type (photon_material_struct), pointer :: pms

real(rp) p_factor, e_field, e_phase, sqrt_b, delta1
real(rp) s_alpha(3), s_beta(3), dr_alpha(3), dr_beta(3), k_0(3), k_h(3), dr(3)
real(rp) kr, k0_im, k_mag, denom, thickness
real(rp), save :: r_ran

complex(rp) e_rel, e_rel_a, e_rel_b, eta, eta1, f_cmp, xi_0k_a, xi_hk_a, xi_0k_b, xi_hk_b
complex(rp) E_hat_alpha, E_hat_beta
complex(rp), save :: E_hat_alpha_saved, E_hat_beta_saved

logical to_alpha_branch, do_branch_calc

! Construct xi_0k = xi_0 / k and xi_hk = xi_h / k

pms => ele%photon%material
sqrt_b = sqrt(abs(cp%b_eff))

eta = (cp%b_eff * cp%dtheta_sin_2theta + pms%f_0 * cp%cap_gamma * (1.0_rp - cp%b_eff)/2) / &
                                              (cp%cap_gamma * abs(p_factor) * sqrt_b * pms%f_hkl) 
eta1 = sqrt(eta**2 + sign(1.0_rp, cp%b_eff))
f_cmp = abs(p_factor) * sqrt_b * cp%cap_gamma * pms%f_hkl / 2

xi_0k_b = f_cmp * (eta - eta1)                         ! beta branch xi
xi_hk_b = f_cmp / (abs(cp%b_eff) * (eta - eta1))

xi_0k_a = f_cmp * (eta + eta1)                         ! alpha branch xi
xi_hk_a = f_cmp / (abs(cp%b_eff) * (eta + eta1))

!---------------
! Bragg

if (ele%value(b_param$) < 0) then 
  if (abs(eta+eta1) > abs(eta-eta1)) then  ! beta branch excited
    e_rel = -2.0_rp * xi_0k_b / (p_factor * cp%cap_gamma * pms%f_hbar)
  else                                     ! alpha branch excited
    e_rel = -2.0_rp * xi_0k_a / (p_factor * cp%cap_gamma * pms%f_hbar)
  endif

  ! Factor of sqrt_b comes from geometrical change in the transverse width of the photon beam

  e_field = e_field * abs(e_rel) / sqrt_b
  e_phase = atan2(aimag(e_rel), real(e_rel)) + e_phase

!---------------
! Laue calc

else 

  thickness = ele%value(thickness$)
  e_rel_a = -2.0_rp * xi_0k_a / (p_factor * cp%cap_gamma * pms%f_hbar)
  e_rel_b = -2.0_rp * xi_0k_b / (p_factor * cp%cap_gamma * pms%f_hbar)

  delta1 = 1 - cp%cap_gamma * real(pms%f_0) / 2
  k_mag = delta1 / cp%wavelength

  k_0 = [cp%old_vvec(1), cp%old_vvec(2), sqrt(delta1**2 - cp%old_vvec(1)**2 - cp%old_vvec(2)**2)] / cp%wavelength
  k_H = [cp%new_vvec(1), cp%new_vvec(2), sqrt(delta1**2 - cp%new_vvec(1)**2 - cp%new_vvec(2)**2)] / cp%wavelength

  s_alpha = k_0 + abs(e_rel_a)**2 * k_H
  dr_alpha = thickness * s_alpha / s_alpha(3)

  s_beta = k_0 + abs(e_rel_b)**2 * k_H
  dr_beta = thickness * s_beta / s_beta(3)

  ! Calc fields

  if (nint(ele%value(ref_orbit_follows$)) == bragg_diffracted$) then
    kr = -twopi * dot_product(k_h, dr_alpha)
    k0_im = k_mag**2 * (cp%cap_gamma * imag(pms%f_0) / 2 - aimag(xi_0k_a)) / k_0(3)
    E_hat_alpha = cmplx(cos(kr), sin(kr)) * exp(-twopi * k0_im * thickness) * e_rel_a * e_rel_b / (e_rel_b - e_rel_a)

    kr = -twopi * dot_product(k_h, dr_beta)
    k0_im = k_mag**2 * (cp%cap_gamma * imag(pms%f_0) / 2 - imag(xi_0k_b)) / k_0(3)
    E_hat_beta  = -cmplx(cos(kr), sin(kr)) * exp(-twopi * k0_im * thickness) * E_hat_alpha

  else
    kr = -twopi * dot_product(k_0, dr_alpha)
    k0_im = k_mag**2 * (cp%cap_gamma * imag(pms%f_0) / 2 - imag(xi_0k_a)) / k_0(3)
    E_hat_alpha = cmplx(cos(kr), sin(kr)) * exp(-twopi * k0_im * thickness) * e_rel_b / (e_rel_b - e_rel_a)

    kr = -twopi * dot_product(k_0, dr_beta)
    k0_im = k_mag**2 * (cp%cap_gamma * imag(pms%f_0) / 2 - imag(xi_0k_b)) / k_0(3)
    E_hat_beta  = cmplx(cos(kr), sin(kr)) * exp(-twopi * k0_im * thickness) * e_rel_a / (e_rel_b - e_rel_a)
  endif

  ! Calculate branching numbers?

  if (do_branch_calc) then
    call ran_uniform(r_ran)
    E_hat_alpha_saved = E_hat_alpha
    E_hat_beta_saved = E_hat_beta
  endif

  ! If crystal is too thick then mark particle as lost

  if (E_hat_alpha_saved == 0 .and. E_hat_beta_saved == 0) then
    orbit%state = lost$
    e_field = 0
    return
  endif

  ! Calculate branch and field

  if (param%tracking_mode == coherent$) then
    denom = abs(E_hat_beta_saved) + abs(E_hat_alpha_saved)
    if (r_ran < abs(E_hat_alpha_saved) / denom) then ! alpha branch
      to_alpha_branch = .true.
      e_field = e_field * denom * abs(E_hat_alpha) / abs(E_hat_alpha_saved)
    else
      to_alpha_branch = .false.
      e_field = e_field * denom * abs(E_hat_beta) / abs(E_hat_beta_saved)
    endif
  else
    denom = abs(E_hat_beta)**2 + abs(E_hat_alpha_saved)**2
    if (r_ran < abs(E_hat_alpha_saved)**2 / denom) then ! alpha branch
      to_alpha_branch = .true.
      e_field = e_field * sqrt(denom * abs(E_hat_alpha)**2 / abs(E_hat_alpha_saved)**2)
    else
      to_alpha_branch = .false.
      e_field = e_field * sqrt(denom * abs(E_hat_beta)**2 / abs(E_hat_beta_saved)**2)
    endif
  endif

  ! Calculate phase and orbit change. Orbit change only is done once.

  if (to_alpha_branch) then
    e_phase = e_phase + atan2(aimag(E_hat_alpha), real(E_hat_alpha))
    dr = dr_alpha
  else
    e_phase = e_phase + atan2(aimag(E_hat_beta), real(E_hat_beta))
    dr = dr_beta
  endif

endif

end subroutine e_field_calc

!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!+
! Subroutine track_to_surface (ele, orbit, curved_surface_rot)
!
! Routine to track a photon to the surface of the element.
!
! If the surface is curved, the photon's velocity coordinates are rotated so that 
! orbit%vec(6) is maintained to be normal to the local surface and pointed inward.
!
! Notice that, to save time, the photon's position is not rotated when there is a curved surface.
!
! Input:
!   ele                 -- ele_struct: Element
!   orbit               -- coord_struct: Coordinates in the element coordinate frame
!   curved_surface_rot  -- Logical, optional, If present and False then do not rotate velocity coords.
!
! Output:
!   orbit      -- coord_struct: At surface in local surface coordinate frame
!   err        -- logical: Set true if surface intersection cannot be found. 
!-

subroutine track_to_surface (ele, orbit, curved_surface_rot)

use nr, only: zbrent

implicit none

type (ele_struct) ele
type (coord_struct) orbit
type (segmented_surface_struct), pointer :: segment

real(rp) :: s_len, s1, s2, s_center, x0, y0
character(*), parameter :: r_name = 'track_to_surface'
logical, optional :: curved_surface_rot

! If there is curvature, compute the reflection point which is where 
! the photon intersects the surface.

if (ele%photon%surface%has_curvature) then

  ele%photon%surface%segment%ix = int_garbage$; ele%photon%surface%segment%iy = int_garbage$

  ! Assume flat crystal, compute s required to hit the intersection

  s_center = orbit%vec(5) / orbit%vec(6)

  s1 = s_center
  s2 = s_center
  if (photon_depth_in_element(s_center) > 0) then
    do
      s1 = s1 - 0.1
      if (photon_depth_in_element(s1) < 0) exit
      if (s1 < -10) then
        !! call out_io (s_warn$, r_name, &
        !!      'PHOTON INTERSECTION WITH SURFACE NOT FOUND FOR ELEMENT: ' // ele%name)
        orbit%state = lost$
        return
      endif
    enddo
  else
    do
      s2 = s2 + 0.1
      if (photon_depth_in_element(s2) > 0) exit
      if (s1 > 10) then
        !! call out_io (s_warn$, r_name, &
        !!      'PHOTON INTERSECTION WITH SURFACE NOT FOUND FOR ELEMENT: ' // ele%name)
        orbit%state = lost$
        return
      endif
    enddo
  endif

  s_len = zbrent (photon_depth_in_element, s1, s2, 1d-10)

  ! Compute the intersection point

  orbit%vec(1:5:2) = s_len * orbit%vec(2:6:2) + orbit%vec(1:5:2)
  orbit%t = orbit%t + s_len / c_light

  if (logic_option(.true., curved_surface_rot)) call rotate_for_curved_surface (ele, orbit, set$)

else
  s_len = -orbit%vec(5) / orbit%vec(6)
  orbit%vec(1:5:2) = orbit%vec(1:5:2) + s_len * orbit%vec(2:6:2) ! Surface is at z = 0
  orbit%t = orbit%t + s_len / c_light
endif

contains

!-----------------------------------------------------------------------------------------------
!+
! Function photon_depth_in_element (s_len) result (delta_h)
! 
! Private routine to be used as an argument in zbrent. Propagates
! photon forward by a distance s_len. Returns delta_h = z-z0
! where z0 is the height of the element surface. 
! Since positive z points inward, positive delta_h => inside element.
!
! Input:
!   s_len   -- Real(rp): Place to position the photon.
!
! Output:
!   delta_h -- Real(rp): Depth of photon below surface in crystal coordinates.
!-

function photon_depth_in_element (s_len) result (delta_h)

implicit none

real(rp), intent(in) :: s_len
real(rp) :: delta_h
real(rp) :: point(3)

!

point = s_len * orbit%vec(2:6:2) + orbit%vec(1:5:2)
delta_h = point(3) - z_at_surface(ele, point(1), point(2))

end function photon_depth_in_element

end subroutine track_to_surface

!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!+
! Subroutine rotate_for_curved_surface (ele, orbit, set, rot_mat)
!
! Routine to rotate just the velocity coords between element body coords and effective 
! body coords ("curved body coords") with respect to the surface at the point of photon impact.
!
! Input:
!   ele      -- ele_struct: reflecting element
!   orbit    -- coord_struct: Photon position.
!   set      -- Logical: True -> Transform body to curved body. 
!                        False -> Transform curved body to body.
!
! Output:
!   orbit        -- coord_struct: Photon position.
!   rot_mat(3,3) -- real(rp), optional: rotation matrix applied to 
!-

subroutine rotate_for_curved_surface (ele, orbit, set, rot_mat)

implicit none

type (ele_struct), target :: ele
type (coord_struct) orbit
type (photon_surface_struct), pointer :: s

real(rp), optional :: rot_mat(3,3)
real(rp) curve_rot(3,3), angle
real(rp) slope_y, slope_x, x, y
integer ix, iy

logical set

! Compute the slope of the crystal at that the point of impact.
! curve_rot transforms from standard body element coords to body element coords at point of impact.

s => ele%photon%surface
x = orbit%vec(1)
y = orbit%vec(3)

if (s%grid%type == segmented$) then
  call init_surface_segment (x, y, ele)
  slope_x = s%segment%slope_x; slope_y = s%segment%slope_y

else

  slope_x = 0
  slope_y = 0

  do ix = 0, ubound(s%curvature_xy, 1)
  do iy = 0, ubound(s%curvature_xy, 2) - ix
    if (s%curvature_xy(ix, iy) == 0) cycle
    if (ix > 0) slope_x = slope_x - ix * s%curvature_xy(ix, iy) * x**(ix-1) * y**iy
    if (iy > 0) slope_y = slope_y - iy * s%curvature_xy(ix, iy) * x**ix * y**(iy-1)
  enddo
  enddo

endif

if (slope_x == 0 .and. slope_y == 0) return

! Compute rotation matrix and goto body element coords at point of photon impact

angle = atan2(sqrt(slope_x**2 + slope_y**2), 1.0_rp)
if (set) angle = -angle
call axis_angle_to_w_mat ([slope_y, -slope_x, 0.0_rp], angle, curve_rot)

orbit%vec(2:6:2) = matmul(curve_rot, orbit%vec(2:6:2))
if (present(rot_mat)) rot_mat = curve_rot

end subroutine rotate_for_curved_surface

!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!+
! Subroutine crystal_h_misalign (ele, orbit, h_vec)
!
! Routine reorient the crystal H vector due to local imperfections in the crystal lattice.
!
! Input:
!   ele      -- ele_struct: Crystal element
!   orbit    -- coord_struct: Photon position at crystal surface.
!   h_vec(3) -- real(rp): H vector before misalignment.
!
! Output:
!   h_vec(3) -- real(rp): H vector after misalignment.
!-

subroutine crystal_h_misalign (ele, orbit, h_vec)

implicit none

type (ele_struct), target :: ele
type (coord_struct) orbit
type (photon_surface_struct), pointer :: s
type (surface_grid_pt_struct), pointer :: pt

real(rp) h_vec(3), r(2)
integer ij(2)
character(*), parameter :: r_name = 'crystal_h_misalign'

!

s => ele%photon%surface

ij = nint((orbit%vec(1:3:2) + s%grid%r0) / s%grid%dr)

if (any(ij < lbound(s%grid%pt)) .or. any(ij > ubound(s%grid%pt))) then
  call out_io (s_error$, r_name, &
              'Photon position on crystal surface outside of grid bounds for element: ' // ele%name)
  return
endif

! Make small angle approximation

pt => s%grid%pt(ij(1), ij(2))
if (pt%x_pitch == 0 .and. pt%y_pitch == 0 .and. pt%x_pitch_rms == 0 .and. pt%y_pitch_rms == 0) return

h_vec(1:2) = h_vec(1:2) + [pt%x_pitch, pt%y_pitch]
if (pt%x_pitch_rms /= 0 .or. pt%y_pitch /= 0) then
  call ran_gauss (r)
  h_vec(1:2) = h_vec(1:2) + [pt%x_pitch_rms, pt%y_pitch_rms] * r
endif

h_vec(3) = sqrt(1 - h_vec(1)**2 - h_vec(2)**2)

end subroutine crystal_h_misalign

!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!+
! Subroutine target_rot_mats (r_center, w_to_target, w_to_ele)
!
! Routine to calculate the rotation matrices between ele coords and "target" coords.
! By definition, in target coords r_center = [0, 0, 1].
!
! Input:
!   r_center(3)   -- real(rp): In lab coords: Center of target relative to phton emission point.
!
! Output:
!   w_to_target(3,3) -- real(rp): Rotation matrix from lab to target coords.
!   w_to_ele(3,3)    -- real(rp): Rotation matrix from target to ele coords.
!-

subroutine target_rot_mats (r_center, w_to_target, w_to_ele)

implicit none

real(rp) r_center(3), w_to_target(3,3), w_to_ele(3,3)
real(rp) r(3), cos_theta, sin_theta, cos_phi, sin_phi

!

r = r_center / norm2(r_center)
sin_phi = r(2)
cos_phi = sqrt(r(1)**2 + r(3)**2)
if (cos_phi == 0) then
  sin_theta = 0  ! Arbitrary
  cos_theta = 1
else
  sin_theta = r(1) / cos_phi
  cos_theta = r(3) / cos_phi
endif

w_to_ele(1,:) = [ cos_theta, -sin_theta * sin_phi, sin_theta * cos_phi]
w_to_ele(2,:) = [ 0.0_rp,     cos_phi,             sin_phi]
w_to_ele(3,:) = [-sin_theta, -cos_theta * sin_phi, cos_theta * cos_phi]

w_to_target(1,:) = [ cos_theta,       0.0_rp,      -sin_theta]
w_to_target(2,:) = [-sin_theta * sin_phi, cos_phi, -cos_theta * sin_phi]
w_to_target(3,:) = [ sin_theta * cos_phi, sin_phi,  cos_theta * cos_phi]

end subroutine target_rot_mats

!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------------
!+
! Subroutine target_min_max_calc (r_corner1, r_corner2, y_min, y_max, phi_min, phi_max, initial)
!
! Routine to calculate the min/max values for (y, phi).
! min/max values are cumulative.
!
! Input:
!   r_corner1(3)     -- real(rp): In target coords: A corner of the target. Must be normalized to 1.
!   r_corner2(3)     -- real(rp): In target coords: Adjacent corner of the target. Must be normalized to 1.
!   y_min, y_max     -- real(rp): min/max values. Only needed if initial = False.
!   phi_min, phi_max -- real(rp): min/max values. Only needed if initial = False.
!   initial          -- logical, optional: If present and True then this is the first edge for computation.
!
! Output:
!   y_min, y_max     -- real(rp): min/max values. 
!   phi_min, phi_max -- real(rp): min/max values. 
!-

subroutine target_min_max_calc (r_corner1, r_corner2, y_min, y_max, phi_min, phi_max, initial)

implicit none

real(rp)  r_corner1(3), r_corner2(3), y_min, y_max, phi_min, phi_max
real(rp) phi1, phi2, k, t, alpha, beta, y

logical, optional :: initial

!

phi1 = atan2(r_corner1(1), r_corner1(3))
phi2 = atan2(r_corner2(1), r_corner2(3))

if (logic_option(.false., initial)) then
  y_max = max(r_corner1(2), r_corner2(2))
  y_min = min(r_corner1(2), r_corner2(2))
  phi_max = max(phi1, phi2)
  phi_min = min(phi1, phi2)
else
  y_max = max(y_max, r_corner1(2), r_corner2(2))
  y_min = min(y_min, r_corner1(2), r_corner2(2))
  phi_max = max(phi_max, phi1, phi2)
  phi_min = min(phi_min, phi1, phi2)
endif

k = dot_product(r_corner1, r_corner2)
t = abs(k * r_corner1(2) - r_corner2(2)) 
alpha = t / sqrt((1-k**2)*(1-k**2 + t**2))

if (alpha < 1) then
  beta = sqrt((alpha * k)**2 + 1 - alpha**2) - alpha * k
  y = r_corner1(2) * alpha + r_corner2(2) * beta
  y_max = max(y_max, y)
  y_min = min(y_min, y)
endif

end subroutine target_min_max_calc

end module
