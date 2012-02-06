!+
! Subroutine track1_symp_lie_ptc (start_orb, ele, param, end_orb)
!
! Particle tracking through a single element using a hamiltonian
! and a symplectic integrator. This uses Etienne's PTC code. For a 
! "native" BMAD version see track1_symnp_lie_bmad.
!
! Modules Needed:
!   use bmad
!
! Input:
!   start_orb  -- Coord_struct: Starting position
!   ele    -- Ele_struct: Element
!   param  -- lat_param_struct:
!
! Output:
!   end_orb   -- Coord_struct: End position
!-

subroutine track1_symp_lie_ptc (start_orb, ele, param, end_orb)

use ptc_interface_mod, except_dummy => track1_symp_lie_ptc
use s_tracking, only: DEFAULT, alloc_fibre
use mad_like, only: fibre, kill, ptc_track => track

implicit none

type (coord_struct) :: start_orb
type (coord_struct) :: end_orb
type (ele_struct) :: ele, drift_ele
type (lat_param_struct) :: param
type (fibre), pointer :: fibre_ele

real(dp) re(6), beta0

character(20) :: r_name = 'track1_symp_lie_ptc'

! Error test

if (ele%key == wiggler$ .and. ele%value(z_patch$) == 0) then
  call out_io (s_fatal$, r_name, 'WIGGLER Z_PATCH VALUE HAS NOT BEEN COMPUTED!')
  if (bmad_status%exit_on_error) call err_exit 
endif


! call the PTC routines to track through the fibre.

if (ele_has_constant_reference_energy(ele)) then
  beta0 = ele%value(p0c$) / ele%value(e_tot$)
else
  beta0 = ele%value(p0c_start$) / ele%value(e_tot_start$)
endif

call vec_bmad_to_ptc (start_orb%vec, beta0, re)

! Track a drift if using hard edge model

if (tracking_uses_hard_edge_model(ele, tracking_method$)) then
  call create_hard_edge_drift (ele, drift_ele)
  call ele_to_fibre (drift_ele, fibre_ele, param, .true.)
  call ptc_track (fibre_ele, re, DEFAULT)  ! "track" in PTC
endif  

! track element

call ele_to_fibre (ele, fibre_ele, param, .true.)
call ptc_track (fibre_ele, re, DEFAULT)  ! "track" in PTC

if (tracking_uses_hard_edge_model(ele, tracking_method$)) then
  call ele_to_fibre (drift_ele, fibre_ele, param, .true.)
  call ptc_track (fibre_ele, re, DEFAULT)  ! "track" in PTC
endif  

call vec_ptc_to_bmad (re, beta0, end_orb%vec)
if (.not. ele_has_constant_reference_energy(ele)) &
      call vec_bmad_ref_energy_correct(end_orb%vec, ele%value(p0c$) / ele%value(p0c_start$))

if (has_z_patch(ele)) then
  end_orb%vec(5) = end_orb%vec(5) - ele%value(z_patch$)
endif

end subroutine
