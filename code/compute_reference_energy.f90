!+
! Subroutine compute_reference_energy (lat)
!
! Subroutine to compute the energy, momentum and time of the reference particle for 
! each element in a lat structure.
!
! Modules needed:
!   use bmad
!
! Input:
!   lat     -- lat_struct: Input lattice.
!     %ele(0)%value(E_tot$) -- Energy at the start of the lattice.
!
! Output:
!   lat -- lat_struct
!     %ele(:)%value(E_tot$) -- Reference energy at the exit end.
!     %ele(:)%value(p0c$)   -- Reference momentum at the exit end.
!     %ele(:)%ref_time      -- Reference time from the beginning at the exit end.
!-

subroutine compute_reference_energy (lat)

use lat_ele_loc_mod

implicit none

type (lat_struct), target :: lat
type (ele_struct), pointer :: ele, lord, slave, branch_ele, ele0
type (branch_struct), pointer :: branch

integer i, k, ib, ix, ixs, ibb

logical did_set, stale

character(24), parameter :: r_name = 'compute_reference_energy'

! propagate the energy through the tracking part of the lattice

do ib = 0, ubound(lat%branch, 1)
  branch => lat%branch(ib)

  if (bmad_com%auto_bookkeeper) then
    stale = .true.
  else
    if (branch%param%status%ref_energy /= stale$) cycle
    stale = .false.
  endif

  branch%param%status%ref_energy = ok$

  ! Init energy at beginning of branch if needed.

  ele0 => branch%ele(0)

  if (branch%ix_from_branch >= 0 .and. (stale .or. ele0%status%ref_energy == stale$)) then

    branch_ele => pointer_to_ele (lat, branch%ix_from_ele, branch%ix_from_branch)
    branch%param%particle = nint(branch_ele%value(particle$))
    branch%param%lattice_type = nint(branch_ele%value(lattice_type$))

    did_set = .false.

    if (branch_ele%value(E_tot_start$) == 0) then
      ele0%value(E_tot$) = branch_ele%value(E_tot$)
      call convert_total_energy_to (ele0%value(E_tot$), branch%param%particle, pc = ele0%value(p0c$))
    else
      ele0%value(E_tot$) = branch_ele%value(E_tot_start$)
      did_set = .true.
    endif

    if (branch_ele%value(p0c_start$) == 0) then
      ele0%value(p0c$) = branch_ele%value(p0c$)
     call convert_pc_to (ele0%value(p0c$), branch%param%particle, e_tot = ele0%value(e_tot$))
    else
      ele0%value(p0c$) = branch_ele%value(p0c_start$)
      did_set = .true.
    endif

    if (.not. did_set .and. mass_of(branch%param%particle) /= &
                            mass_of(lat%branch(branch_ele%ix_branch)%param%particle)) then
      call out_io (s_fatal$, r_name, &
        'E_TOT_START OR P0C_START MUST BE SET IN A BRANCHING ELEMENT IF THE PARTICLE IN ', &
        'THE "FROM" BRANCH IS DIFFERENT FROM THE PARTICLE IN THE "TO" BRANCH.', &
        'PROBLEM OCCURS WITH BRANCH ELEMENT: ' // branch_ele%name) 
      call err_exit
    endif

    stale = .true.

  endif

  if (ele0%status%ref_energy == stale$) ele0%status%ref_energy = ok$

  ! This is for attribute_bookkeeper to prevent it from flagging the ref energy in ele(0) as stale

  ele0%old_value(e_tot$) = ele0%value(e_tot$)
  ele0%old_value(p0c$)   = ele0%value(p0c$)

  ! Loop over all elements in the branch

  do i = 1, branch%n_ele_track
    ele => branch%ele(i)

    if (.not. stale .and. ele%status%ref_energy /= stale$) cycle

    stale = .true.
    ele%status%ref_energy = ok$

    if (ele%key == branch$ .or. ele%key == photon_branch$) then
      ibb = nint(ele%value(ix_branch_to$))
      lat%branch(ibb)%ele(0)%status%ref_energy = stale$
    endif

    ! Calculate the energy

    ele0 => branch%ele(i-1)
    call compute_ele_reference_energy (ele, branch%param, ele0%value(e_tot$), ele0%value(p0c$), ele0%ref_time)
    call set_lords_status_stale (ele, lat, ref_energy_status$)

  enddo

enddo

! Put the appropriate energy values in the lord elements...

if (bmad_com%auto_bookkeeper .or. lat%param%status%ref_energy == stale$) then

  lat%param%status%ref_energy = ok$

  do i = lat%n_ele_track+1, lat%n_ele_max

    lord => lat%ele(i)

    if (.not. bmad_com%auto_bookkeeper .and. lord%status%ref_energy /= stale$) cycle

    ! Multipass lords have their own reference energy if n_ref_pass /= 0.

    if (lord%lord_status == multipass_lord$) then
      ix = nint(lord%value(n_ref_pass$))
      if (ix /= 0) then  
        slave => pointer_to_slave(lat, lord, ix)
        lord%value(e_tot$) = slave%value(e_tot$)
        lord%value(p0c$)   = slave%value(p0c$)
      elseif (lord%value(e_tot$) == 0 .and. lord%value(p0c$) /= 0) then
        call convert_pc_to (lord%value(p0c$), lat%param%particle, e_tot = lord%value(e_tot$))
      elseif (lord%value(p0c$) == 0 .and. lord%value(e_tot$) /= 0) then
        call convert_total_energy_to (lord%value(e_tot$), lat%param%particle, pc = lord%value(p0c$))
      endif
      cycle
    endif

    ! Now for everything but multipass_lord elements...
    ! The lord inherits the energy from the last slave.
    ! First find this slave.

    slave => lord
    do
      if (slave%n_slave == 0) exit
      slave => pointer_to_slave (lat, slave, slave%n_slave)
    enddo

    ! Now transfer the information to the lord.

    lord%value(p0c$) = slave%value(p0c$)
    lord%value(E_tot$) = slave%value(E_tot$)

    ! Transfer the starting energy if needed.

    if (lord%key == lcavity$ .or. lord%key == custom$) then
      slave => pointer_to_slave (lat, lord, 1)
      lord%value(E_tot_start$) = slave%value(E_tot_start$)
      lord%value(p0c_start$)   = slave%value(p0c_start$)
    endif

  enddo

endif

end subroutine compute_reference_energy

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
!+
! Subroutine compute_ele_reference_energy (ele, param, e_tot_start, p0c_start, ref_time_start)
!
! Routine to compute the reference energy and reference time at the end of an element 
! given the reference enegy and reference time at the start of the element.
!
! Input:
!   ele            -- Ele_struct: Lattice element
!   param          -- lat_Param_struct: Lattice parameters.
!   e_tot_start    -- Real(rp): Entrance end energy.
!   p0c_start      -- Real(rp): Entrance end momentum
!   ref_time_start -- Real(rp): Entrance end reference time
!
! Output:
!   ele         -- Ele_struct: Lattice element with reference energy and time.
!-

subroutine compute_ele_reference_energy (ele, param, e_tot_start, p0c_start, ref_time_start)

use lat_ele_loc_mod
use rf_mod

implicit none

type (ele_struct) ele
type (lat_param_struct) :: param
type (coord_struct) start_orb, end_orb

real(rp) E_tot_start, p0c_start, ref_time_start, e_tot, p0c, phase

!

select case (ele%key)
case (lcavity$) 
  ele%value(E_tot_start$) = E_tot_start
  ele%value(p0c_start$) = p0c_start

  phase = twopi * (ele%value(phi0$) + ele%value(dphi0$)) 
  E_tot = E_tot_start + ele%value(gradient$) * ele%value(l$) * cos(phase)
  call convert_total_energy_to (E_tot, param%particle, pc = p0c)

  ! A zero e_tot can mess up tracking so put in a temp value if needed.
  if (ele%value(e_tot$) == 0) then ! Can happen on first pass through this routine
    ele%value(E_tot$) = E_tot      ! Temp value. Does not affect phase & amp adjustment.
    ele%value(p0c$) = p0c
    ele%ref_time = ref_time_start
  endif
  if (associated(ele%rf%field)) call rf_accel_mode_adjust_phase_and_amp (ele, param)

  ele%value(E_tot$) = E_tot
  ele%value(p0c$) = p0c

  if (E_tot_start == E_tot) then
    ele%ref_time = ref_time_start + ele%value(l$) * E_tot / (p0c * c_light)
  elseif (ele%tracking_method == bmad_standard$) then
    ele%ref_time = ref_time_start + ele%value(l$) * &        ! lcavity with non-zero acceleration formula
              (p0c - p0c_start) / ((E_tot - E_tot_start) * c_light)
  else
    call track1 (start_orb, ele, param, end_orb)
    ele%ref_time = ele%ref_time - end_orb%vec(5) * E_tot / (p0c * c_light)
  endif

case (custom$, hybrid$)
  ele%value(E_tot_start$) = E_tot_start
  ele%value(p0c_start$) = p0c_start
  E_tot = E_tot_start + ele%value(delta_e$)
  call convert_total_energy_to (E_tot, param%particle, pc = p0c)

  ele%value(E_tot$) = E_tot
  ele%value(p0c$) = p0c
  ele%ref_time = ref_time_start + ele%value(delta_ref_time$)

case (crystal$, mirror$, multilayer_mirror$)
  ele%value(ref_wavelength$) = c_light * h_planck / E_tot_start
  ele%value(E_tot$) = E_tot_start
  ele%value(p0c$) = p0c_start
  ele%ref_time = ref_time_start

case (patch$) 
  ele%value(E_tot_start$) = E_tot_start
  ele%value(p0c_start$) = p0c_start

  if (ele%is_on .and. ele%value(e_tot_offset$) /= 0) then
    e_tot = e_tot_start + ele%value(e_tot_offset$)
    call convert_total_energy_to (e_tot, param%particle, pc = p0c)
  endif

  ele%value(E_tot$) = E_tot
  ele%value(p0c$) = p0c
  ele%ref_time = ref_time_start

case default
  ele%value(E_tot$) = E_tot_start
  ele%value(p0c$) = p0c_start
  ele%ref_time = ref_time_start + ele%value(l$) * E_tot_start / (p0c_start * c_light)

end select


! %old_value is changed in tandem so changes in delta_ref_time do not trigger unnecessary bookkeeping.

ele%value(delta_ref_time$) = ele%ref_time - ref_time_start
ele%old_value(delta_ref_time$) = ele%value(delta_ref_time$) 

end subroutine compute_ele_reference_energy
