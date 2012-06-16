!+
! Subroutine type2_ele (ele, lines, n_lines, type_zero_attrib, type_mat6, type_taylor, 
!        twiss_out, type_control, lattice, type_wake, type_floor_coords, 
!        type_field, type_wall)
!
! Subroutine to put information on an element in a string array. 
! See also the subroutine: type_ele.
!
! Modules needed:
!   use bmad
!
! Input:
!   ele               -- Ele_struct: Element
!   type_zero_attrib  -- Logical, optional: If False then surpress printing of
!                           attributes whose value is 0. Default is False.
!   type_mat6         -- Integer, optional:
!                            = 0   => Do not type ele%mat6
!                            = 4   => Type 4X4 xy submatrix
!                            = 6   => Type full 6x6 matrix (Default)
!   type_taylor       -- Logical, optional: Print out taylor map terms?
!                          If ele%taylor is not allocated then this is ignored.
!                          Default is False.
!   twiss_out         -- Integer, optional: Print the Twiss parameters at the element end?
!                          = 0         => Do not print the Twiss parameters
!                          = radians$  => Print Twiss, phi in radians (Default).
!                          = degrees$  => Print Twiss, phi in degrees.
!                          = cycles$   => Print Twiss, phi in radians/2pi.
!   type_control      -- Logical, optional: If True then print control status.
!                          Default: False if lattice is not present. Otherwise True.
!   lattice           -- lat_struct, optional: Needed for control typeout.
!   type_wake         -- Logical, optional: If True then print the long-range and 
!                          short-range wakes information. If False then just print
!                          how many terms the wake has. Default is True.
!                          If ele%rf_wake is not allocated then this is ignored.
!   type_floor_coords -- Logical, optional: If True then print the global ("floor")
!                          coordinates at the exit end of the element.
!                          Default is False.
!   type_field        -- Logical, optional: If True then print:
!                          Wiggler terms for a a map_type wiggler or
!                          RF field info for a lcavity or rfcavity, etc.
!                          Default is False.
!   type_wall         -- Logical, optional: If True then print wall info. Default is False.
!
! Output       
!   lines(:)     -- Character(100), pointer: Character array to hold the 
!                     output. The array size of lines(:) will be set by
!                     this subroutine. Note: You need to deallocate lines
!                     between each call to type2_ele.
!   n_lines      -- Number of lines in lines(:).
!-

subroutine type2_ele (ele, lines, n_lines, type_zero_attrib, type_mat6, &
                type_taylor, twiss_out, type_control, lattice, type_wake, &
                type_floor_coords, type_field, type_wall)

use bmad_struct
use bmad_interface, except_dummy => type2_ele
use multipole_mod
use lat_ele_loc_mod

implicit none

type (ele_struct), target :: ele
type (ele_struct), pointer :: lord, slave
type (lat_struct), optional, target :: lattice
type (wig_term_struct), pointer :: term
type (rf_wake_lr_struct), pointer :: lr
type (rf_wake_sr_table_struct), pointer :: sr_table
type (rf_wake_sr_mode_struct), pointer :: sr_m
type (em_field_mode_struct), pointer :: rfm
type (wall3d_section_struct), pointer :: section
type (wall3d_vertex_struct), pointer :: v
type (ele_attribute_struct) attrib

integer, optional, intent(in) :: type_mat6, twiss_out
integer, intent(out) :: n_lines
integer i, i1, j, n, ix, ix_tot, iv, ic, nl2, l_status, a_type, default_val
integer nl, nt, n_max, particle, n_term, n_att, attrib_type, n_char

real(rp) coef
real(rp) a(0:n_pole_maxx), b(0:n_pole_maxx)
real(rp) a2(0:n_pole_maxx), b2(0:n_pole_maxx)
real(rp), pointer :: r_ptr

character(*), pointer :: lines(:)
character(len(lines)), pointer :: li(:)
character(len(lines)), allocatable :: li2(:)
character(40) a_name, name, fmt_a, fmt_i, fmt_l, coef_str
character(12) val_str
character(8) angle
character(2) str_i
character(12), parameter :: r_name = 'type2_ele'

logical, optional, intent(in) :: type_taylor, type_wake
logical, optional, intent(in) :: type_control, type_zero_attrib
logical, optional :: type_floor_coords, type_field, type_wall
logical type_zero, err_flag, print_it, is_default, has_nonzero_pole

! init

allocate (li(300))

type_zero = logic_option(.false., type_zero_attrib)

if (associated(ele%lat)) call check_lat_controls(ele%lat, err_flag)

! Encode element name and type

nl = 0  

if (ele%ix_branch /= 0) then
  if (present(lattice)) then
    nl=nl+1; write (li(nl), *) 'Branch #', ele%ix_branch, ': ', lattice%branch(ele%ix_branch)%name
  else
    nl=nl+1; write (li(nl), *) 'Branch #', ele%ix_branch
  endif
endif
nl=nl+1; write (li(nl), *) 'Element #', ele%ix_ele
nl=nl+1; write (li(nl), *) 'Element Name: ', ele%name

if (ele%type /= blank_name$) then
  nl=nl+1; write (li(nl), *) 'Element Type: "', trim(ele%type), '"'
endif

if (ele%alias /= blank_name$) then
  nl=nl+1; write (li(nl), *) 'Element Alias: "', trim(ele%alias), '"'
endif

if (associated(ele%descrip)) then
  nl=nl+1; write (li(nl), *) 'Descrip: "', trim(ele%descrip), '"'
endif

! Encode element key and attributes

if (ele%key <= 0) then
  nl=nl+1; write (li(nl), *) 'Key: BAD VALUE!', ele%key
else
  nl=nl+1; write (li(nl), *) 'Key: ', key_name(ele%key)
endif

if (ele%sub_key /= 0) then
  nl=nl+1; write (li(nl), *) 'Sub Key: ', sub_key_name(ele%sub_key)
endif

nl=nl+1; write (li(nl), '(1x, a, f14.5)')  'S:       ', ele%s
nl=nl+1; write (li(nl), '(1x, a, es14.6)') 'Ref_time:', ele%ref_time

nl=nl+1; li(nl) = ''
if (type_zero) then
  nl=nl+1; write (li(nl), *) 'Attribute values:'
else
  nl=nl+1; write (li(nl), *) 'Attribute values [Only non-zero values shown]:'
endif

n_att = n_attrib_string_max_len() + 2

if (ele%lord_status == overlay_lord$) then
  i = ele%ix_value
  call pointer_to_indexed_attribute (ele, i, .false., r_ptr, err_flag)
  if (err_flag) call err_exit
  name = ele%component_name
  nl=nl+1; write (li(nl), '(i6, 3x, 2a, es15.7)') i, name(1:n_att), '=', r_ptr

else
  do i = 1, num_ele_attrib$
    attrib = attribute_record(ele, i)
    a_name = attrib%name
    if (a_name == null_name$) cycle
    if (attrib%private) cycle
    ix_tot = corresponding_tot_attribute_index (ele, i)
    if (ix_tot > 0) then
      if (ele%value(i) == 0 .and. ele%value(ix_tot) == 0 .and. .not. type_zero) cycle
      nl=nl+1; write (li(nl), '(i6, 3x, 2a, es15.7, a, i7, 3x, a16, a, es15.7)') &
                        i, a_name(1:n_att), '=', ele%value(i), ',', &
                        ix_tot, attribute_name(ele, ix_tot), '=', ele%value(ix_tot)

    elseif (a_name == 'P0C_START') then
      nl=nl+1; write (li(nl), '(i6, 3x, 2a, es15.7, a, 10x, a, f11.7)') &
                        i, a_name(1:n_att), '=', ele%value(i), ',', &
                        'BETA_START      =', ele%value(p0c_start$) / ele%value(e_tot_start$)

    elseif (a_name == 'E_TOT_START') then
      nl=nl+1; write (li(nl), '(i6, 3x, 2a, es15.7)')  i, a_name(1:n_att), '=', ele%value(i)

    elseif (a_name == 'P0C') then
      nl=nl+1; write (li(nl), '(i6, 3x, 2a, es15.7, a, 10x, a, f11.7)') &
                        i, a_name(1:n_att), '=', ele%value(i), ',', &
                        'BETA            =', ele%value(p0c$) / ele%value(e_tot$)

    elseif (a_name == 'E_TOT' .and. attribute_name(ele, e_tot_start$) == 'E_TOT_START') then
      nl=nl+1; write (li(nl), '(i6, 3x, 2a, es15.7, a, 10x, a, es15.7)') &
                        i, a_name(1:n_att), '=', ele%value(i), ',', &
                        'DELTA_E         =', ele%value(e_tot$) - ele%value(e_tot_start$)

    elseif (index(a_name, 'ANGLE') /= 0 .and. a_name /= 'CRITICAL_ANGLE_FACTOR') then
      if (ele%value(i) == 0) cycle
      nl=nl+1; write (li(nl), '(i6, 3x, 2a, es15.7, 6x, a, f10.4, a)') &
                   i, a_name(1:n_att), '=', ele%value(i), '[', ele%value(i) * 180 / pi, ' deg]'
    else
      attrib_type = attribute_type(a_name)
      if (is_a_tot_attribute(ele, i)) cycle
      if (ele%value(i) == 0 .and. .not. type_zero .and. attrib_type /= is_logical$) cycle
      select case (attrib_type)
      case (is_logical$)
        if (ele%value(i) /= 0) ele%value(i) = 1
        nl=nl+1; write (li(nl), '(i6, 3x, 2a, l1, a, i0, a)')  i, a_name(1:n_att), '=  ', &
                                    (ele%value(i) /= 0), ' (', nint(ele%value(i)), ')'
      case (is_integer$)
        nl=nl+1; write (li(nl), '(i6, 3x, 2a, i0)')  i, a_name(1:n_att), '= ', nint(ele%value(i))
      case (is_real$)
        nl=nl+1; write (li(nl), '(i6, 3x, 2a, es15.7)')  i, a_name(1:n_att), '=', ele%value(i)
      case (is_name$)
        name = attribute_value_name (a_name, ele%value(i), ele, is_default)
        if (.not. is_default .or. type_zero) then
          nl=nl+1; write (li(nl), '(i6, 3x, 4a, i0, a)')  i, a_name(1:n_att), '=  ', &
                                                        trim(name), ' (', nint(ele%value(i)), ')'
        endif
      end select
    endif
  enddo

  if (associated(ele%a_pole)) then
    particle = +1
    if (present(lattice)) particle = lattice%param%particle

    if (ele%key == multipole$) then
      call multipole_ele_to_kt (ele, particle, .false., has_nonzero_pole, a,  b)
      call multipole_ele_to_kt (ele, particle, .true.,  has_nonzero_pole, a2, b2)
    else
      call multipole_ele_to_ab (ele, particle, .false., has_nonzero_pole, a,  b)
      call multipole_ele_to_ab (ele, particle, .true.,  has_nonzero_pole, a2, b2)
    endif

    if (attribute_index(ele, 'SCALE_MULTIPOLES') == scale_multipoles$) then
      nl=nl+1; write (li(nl), '(a, l1)') 'Scale_Multipoles: ', ele%scale_multipoles
    endif

    do i = 0, n_pole_maxx
      if (a2(i) == 0 .and. b2(i) == 0) cycle
      write (str_i, '(i2)') i
      call string_trim (str_i, str_i, ix)
      if (ele%key == ab_multipole$) then
        write (li(nl+1), '(5x, 2a, 2(a, es11.3))') &
               'A', str_i, ' =', ele%a_pole(i), '   W/Tilt:', a2(i)
        write (li(nl+2), '(5x, 2a, 2(a, es11.3))') &
               'B', str_i, ' =', ele%b_pole(i), '   W/Tilt:', b2(i)
      elseif (ele%key == multipole$) then
        write (li(nl+1), '(5x, 2a, 2(a, es11.3))') &
               'K', trim(str_i), 'L =', ele%a_pole(i), '   W/Tilt:', a2(i)
        write (li(nl+2), '(5x, 2a, 2(a, es11.3))') &
               'T', trim(str_i), '  =', ele%b_pole(i), '   W/Tilt:', b2(i)
      else
        write (li(nl+1), '(5x, 2a, 3(a, es11.3))') 'A', str_i, ' =', &
               ele%a_pole(i), '   Scaled:', a(i), '   W/Tilt:', a2(i)
        write (li(nl+2), '(5x, 2a, 3(a, es11.3))') 'B', str_i, ' =', &
               ele%b_pole(i), '   Scaled:', b(i), '   W/Tilt:', b2(i)
      endif

      nl = nl + 2
    enddo

  endif

endif

! RF field coefs

if (associated(ele%em_field)) then
  if (logic_option(.false., type_field)) then
    do i = 1, size(ele%em_field%mode)
      rfm => ele%em_field%mode(i)
      if (rfm%master_scale == 0) then
        name = '---'
      else
        name = attribute_name(ele, rfm%master_scale)
      endif
      nl=nl+1; li(nl) = ''
      nl=nl+1; write (li(nl), '(a, i0)')        'Mode #:', i
      nl=nl+1; write (li(nl), '(a, i0)')        '    m:             ', rfm%m
      nl=nl+1; write (li(nl), '(a, i0)')        '    harmonic:      ', rfm%harmonic
      nl=nl+1; write (li(nl), '(2a)')           '    master_scale:  ', trim(name)
      nl=nl+1; write (li(nl), '(a, es16.8)')    '    f_damp:        ', rfm%f_damp
      nl=nl+1; write (li(nl), '(a, es16.8)')    '    dphi0_ref:     ', rfm%dphi0_ref
      nl=nl+1; write (li(nl), '(a, es16.8)')    '    phi0_azimuth:  ', rfm%phi0_azimuth
      nl=nl+1; write (li(nl), '(a, es16.8)')    '    field_scale:   ', rfm%field_scale

      if (associated(rfm%map)) then
        nl=nl+1; write (li(nl), '(2a)')         '    File:          ', trim(rfm%map%file)
        nl=nl+1; write (li(nl), '(2a)')         '    ele_anchor_pt: ', anchor_pt_name(rfm%map%ele_anchor_pt)
        nl=nl+1; write (li(nl), '(a, i0)')      '    n_link:        ', rfm%map%n_link
        nl=nl+1; write (li(nl), '(a, es16.8)')  '    dz:            ', rfm%map%dz
        nl=nl+1; write (li(nl), '(a)')          '  Term                e                           b'
        do j = 1, min(10, size(rfm%map%term))
          if (nl+1 > size(li)) call re_associate(li, 2 * nl)
          nl=nl+1; write (li(nl), '(i5, 3x, 2(a, 2es12.4), a)') j, &
                                             '(', rfm%map%term(j)%e_coef, ')  (', rfm%map%term(j)%b_coef, ')'
        enddo
        if (size(rfm%map%term) > 10) then
          nl=nl+1; li(nl) = '     .... etc ...'
        endif
      endif

      if (associated(rfm%grid)) then
        nl=nl+1; write (li(nl), '(2a)')         '    File:          ', trim(rfm%grid%file)
        nl=nl+1; write (li(nl), '(2a)')         '    Type:          ', em_grid_type_name(rfm%grid%type)
        nl=nl+1; write (li(nl), '(2a)')         '    ele_anchor_pt: ', anchor_pt_name(rfm%grid%ele_anchor_pt)
        nl=nl+1; write (li(nl), '(a, i0)')      '    n_link:        ', rfm%grid%n_link
        nl=nl+1; write (li(nl), '(a, 3f14.6)')  '    dr:            ', rfm%grid%dr
        nl=nl+1; write (li(nl), '(a, 3f14.6)')  '    r0:            ', rfm%grid%r0
        nl=nl+1; write (li(nl), '(a, 3f14.6)')  '    r_max - r0:    ', ubound(rfm%grid%pt)*rfm%grid%dr - rfm%grid%r0
      endif

    enddo
  else
    nl=nl+1; write (li(nl), '(a, i5)') 'Number of Field modes:', size(ele%em_field%mode)
  endif
endif

! Encode on/off status and s_position

if (.not. ele%is_on) then
  nl=nl+1; write (li(nl), *) '*** Note: Element is turned OFF ***'
endif

if (.not. ele%multipoles_on) then
  nl=nl+1; write (li(nl), *) '*** Note: Element Multipoles are turned OFF ***'
endif

! wiggler terms

if (associated(ele%wig)) then
  if (logic_option(.false., type_field)) then
    nl=nl+1; write (li(nl), '(a, 6x, a, 3(9x, a), 9x, a)') ' Term#', &
                                'Coef', 'K_x', 'K_y', 'K_z', 'phi_z   Type'
    do i = 1, size(ele%wig%term)
      term => ele%wig%term(i)
      write (li(nl+i), '(i4, 4f12.6, f14.6, 3x, a)') i, term%coef, &
            term%kx, term%ky, term%kz, term%phi_z, wig_term_type_name(term%type)
    enddo
    nl = nl + size(ele%wig%term)
  else
    nl=nl+1; write (li(nl), '(a, i5)') 'Number of wiggler terms:', size(ele%wig%term)
  endif
endif

! wall3d cross-sections.
! Do not print more than 100 sections.

if (associated(ele%wall3d%section)) then
  nl=nl+1; write (li(nl), '(a, i5)') 'Number of Wall Sections:', size(ele%wall3d%section)
  if (logic_option(.false., type_wall)) then
    n = min(size(ele%wall3d%section), 100)
    do i = 1, n
      n_max = nl + 100 
      if (n_max > size(li)) call re_associate (li, n_max) 
      section => ele%wall3d%section(i)
      if (i == size(ele%wall3d%section)) then
        nl=nl+1; write (li(nl), '(a, i0, a, f10.6)') 'Wall%Section(', i, '):  S =', section%s
      elseif (section%dr_ds == real_garbage$) then
        nl=nl+1; write (li(nl), '(a, i0, a, f10.6, a)') &
              'Wall%Section(', i, '):  S =', section%s, ',  dr_ds = Not-set'
      else
        nl=nl+1; write (li(nl), '(a, i0, a, f10.6, a, es12.4)') &
              'Wall%Section(', i, '):  S =', section%s, ',  dr_ds =', section%dr_ds
      endif
      do j = 1, size(section%v)
        v => section%v(j)
        nl=nl+1; write (li(nl), '(4x, a, i0, a, 5f11.6)') &
                              'v(', j, ') =', v%x, v%y, v%radius_x, v%radius_y, v%tilt
      enddo
    enddo
  endif
endif

! Encode methods, etc.

write (fmt_a, '(a, i0, a)') '(9x, a, t', n_att+10, ', a, 2x, a)'
write (fmt_i, '(a, i0, a)') '(9x, a, t', n_att+10, ', a, i6)'
write (fmt_l, '(a, i0, a)') '(9x, a, t', n_att+10, ', a, 2x, l1)'

nl=nl+1; write (li(nl), *) ' '

if (attribute_name(ele, crystal_type$) == 'CRYSTAL_TYPE') then
  nl=nl+1; write (li(nl), fmt_a) 'CRYSTAL_TYPE', '=', ele%component_name
endif

if (attribute_name(ele, tracking_method$) == 'TRACKING_METHOD') then
  nl=nl+1; write (li(nl), fmt_a) &
                  'TRACKING_METHOD', '=', calc_method_name(ele%tracking_method)
endif

if (attribute_name(ele, mat6_calc_method$) == 'MAT6_CALC_METHOD') then
  nl=nl+1; write (li(nl), fmt_a) &
                  'MAT6_CALC_METHOD', '=', calc_method_name(ele%mat6_calc_method)
endif

if (attribute_name(ele, field_calc$) == 'FIELD_CALC') then
  nl=nl+1; write (li(nl), fmt_a) 'FIELD_CALC', '=', field_calc_name(ele%field_calc)
endif

! Write aparture stuff if appropriate

if (attribute_name(ele, aperture_at$) == 'APERTURE_AT' .and. ele%aperture_at /= 0) then
  nl=nl+1; write (li(nl), fmt_a) 'APERTURE_AT', '=', aperture_at_name(ele%aperture_at)
  default_val = rectangular$
  if (ele%key == ecollimator$) default_val = elliptical$
  if (ele%aperture_type /= default_val .or. type_zero) then
    nl=nl+1; write (li(nl), fmt_a) 'APERTURE_TYPE', '=', aperture_type_name(ele%aperture_type)
  endif
  nl=nl+1; write (li(nl), fmt_l) 'OFFSET_MOVES_APERTURE', '=', ele%offset_moves_aperture
endif

if (ele%ref_orbit /= 0) then
  nl=nl+1; write (li(nl), fmt_a) 'REF_ORBIT', '=', ref_orbit_name(ele%ref_orbit) 
endif

if (attribute_index(ele, 'SYMPLECTIFY') /= 0) then
  nl=nl+1; write (li(nl), fmt_l) 'SYMPLECTIFY', '=', ele%symplectify
endif
  
if (ele%lord_status /= overlay_lord$ .and. ele%lord_status /= group_lord$ .and. &
    ele%lord_status /= girder_lord$ .and. attribute_index(ele, 'FIELD_MASTER') /= 0) then
  nl=nl+1; write (li(nl), fmt_l) 'FIELD_MASTER', '=', ele%field_master
endif

if (attribute_index(ele, 'CSR_CALC_ON') /= 0) then
  nl=nl+1; write (li(nl), fmt_l) 'CSR_CALC_ON', '=', ele%csr_calc_on
endif
  
! Encode branch info

if (ele%key == branch$ .or. ele%key == photon_branch$) then
  
  if (li(nl) /= '') then
    nl=nl+1; li(nl) = ' '
  endif

  n = nint(ele%value(ix_branch_to$))
  if (present(lattice)) then
    nl=nl+1; write (li(nl), '(3a, i0, a)') 'Branch to:', trim(lattice%branch(n)%name), '  [', n, ']'
  else
    nl=nl+1; write (li(nl), *) 'Branch to:', n
  endif

endif

! Encode slave info.
! For super_lords there is no attribute_name associated with a slave.
! For slaves who are overlay_lords then the attribute_name is obtained by
!   looking at the overlay_lord's 1st slave (slave of slave of the input ele).

if (logic_option(present(lattice), type_control)) then

  if (.not. present (lattice)) then
    call out_io (s_fatal$, r_name, 'TYPE_CONTROL IS TRUE BUT NO LATTICE PRESENT.')
    if (bmad_status%exit_on_error) call err_exit
  endif

  if (li(nl) /= '') then
    nl=nl+1; li(nl) = ' '
  endif

  ! Print info on element's lords

  if (ele%slave_status <= 0) then
    nl=nl+1; write (li(nl), '(a)') 'Slave_status: BAD!', ele%slave_status
  else
    nl=nl+1; write (li(nl), '(2a)') 'Slave_status: ', control_name(ele%slave_status)
  endif

  if (ele%n_lord /= 0) then

    nl=nl+1; write (li(nl), *) &
      '    Name                       Lat_index  Attribute         Coefficient       Value  Lord_Type'

    do i = 1, ele%n_lord
      lord => pointer_to_lord (ele, i, ic)
      select case (lord%lord_status)
      case (super_lord$, multipass_lord$, patch_in_slave$, girder_lord$)
        coef_str = ''
        a_name = ''
        val_str = ''
      case default
        write (coef_str, '(es11.3)') lattice%control(ic)%coef
        iv = lattice%control(ic)%ix_attrib
        a_name = attribute_name(ele, iv)
        ix = lord%ix_value
        if (ix == 0) then
          val_str = '     GARBAGE!'
        else
          call pointer_to_indexed_attribute (lord, ix, .false., r_ptr, err_flag)
          write (val_str, '(1p, e12.3)') r_ptr
        endif
      end select

      nl=nl+1; write (li(nl), '(5x, a30, i6, 2x, a18, a11, a12, 2x, a)') &
            lord%name, lord%ix_ele, a_name, coef_str, val_str, trim(trim(key_name(lord%key)))
    enddo
    nl=nl+1; li(nl) = ''

  endif

  ! Print info on elements slaves.

  if (ele%lord_status <= 0) then
    nl=nl+1; write (li(nl), '(a)') 'Lord_status: BAD!', ele%lord_status
  else
    nl=nl+1; write (li(nl), '(2a)') 'Lord_status:  ', control_name(ele%lord_status)
  endif

  if (ele%n_slave /= 0) then
    nl=nl+1; write (li(nl), '(a, i4)') 'Slaves:'

    n_char = 20
    do i = 1, ele%n_slave
      slave => pointer_to_slave (ele, i)
      n_char = max(n_char, len_trim(slave%name))
    enddo

    select case (ele%lord_status)

    case (multipass_lord$, super_lord$, girder_lord$)
      name = 'Name'
      nl=nl+1; write (li(nl), '(3x, a, 3x, a)') name(1:n_char), 'Type                 Lat_index'
      do i = 1, ele%n_slave
        slave => pointer_to_slave (ele, i)
        nl=nl+1; write (li(nl), '(3x, a, 3x, a20, a10)') &
                    slave%name(1:n_char), key_name(slave%key), trim(ele_loc_to_string(slave))
      enddo

    case default
      name = 'Name'
      nl=nl+1; write (li(nl), '(3x, a, 3x, a)') name(1:n_char), ' Lat_index  Attribute         Coefficient'
      do ix = 1, ele%n_slave
        slave => pointer_to_slave (ele, ix, i)
        iv = lattice%control(i)%ix_attrib
        coef = lattice%control(i)%coef
        a_name = attribute_name(slave, iv)
        nl=nl+1; write (li(nl), '(3x, a, 3x, a10, 2x, a18, es11.3, es12.3)') &
                           slave%name(1:n_char), trim(ele_loc_to_string(slave)), a_name, coef
      enddo
    end select

  endif

endif

! Encode Twiss info

if (integer_option(radians$, twiss_out) /= 0 .and. ele%a%beta /= 0) then
  nl=nl+1; li(nl) = ' '
  nl=nl+1; li(nl) = 'Twiss at end of element:'
  call type2_twiss (ele, li(nl+1:), nl2, twiss_out)
  nl = nl + nl2
endif

l_status = ele%lord_status
if (l_status /= overlay_lord$ .and. l_status /= multipass_lord$ .and. &
    l_status /= group_lord$ .and. l_status /= girder_lord$) then

  ! Encode mat6 info

  n = integer_option (6, type_mat6)

  if (n /= 0) then
    nl=nl+1; li(nl) = ' '
    nl=nl+1; write (li(nl), '(a, f12.6, a)') 'Transfer Matrix : Kick  [Matrix symplectic error:', &
                  mat_symp_error(ele%mat6), ']'
  endif

  if (any(abs(ele%mat6(1:n,1:n)) >= 1000)) then
    do i = 1, n
      nl=nl+1; write (li(nl), '(6es11.3, a, es11.3)') &
                          (ele%mat6(i, j), j = 1, n), '   : ', ele%vec0(i)
    enddo
  else
    do i = 1, n
      nl=nl+1; write (li(nl), '(6f10.5, a, es11.3)') &
                          (ele%mat6(i, j), j = 1, n), '   : ', ele%vec0(i)
    enddo
  endif

  ! Encode taylor series

  if (associated(ele%taylor(1)%term)) then
    nl=nl+1; li(nl) = ' '
    nl=nl+1; write (li(nl), '(a, l1)') 'map_with_offsets: ', ele%map_with_offsets
    if (logic_option(.false., type_taylor)) then
      call type2_taylors (ele%taylor, li2, nt)
      call re_associate (li, nl+nt+100)
      li(1+nl:nt+nl) = li2(1:nt)
      deallocate (li2)
      nl = nl + nt
    else
      n_term = 0
      do i = 1, 6
        n_term = n_term + size(ele%taylor(i)%term)
      enddo
      nl=nl+1; write (li(nl), *) 'Taylor map total number of terms:', n_term
    endif
  endif

endif

! Encode HOM info

if (associated(ele%rf_wake)) then

  if (size(ele%rf_wake%sr_table) /= 0) then
    nl=nl+1; write (li(nl), *)
    if (logic_option (.true., type_wake)) then
      call re_associate (li, nl+size(ele%rf_wake%sr_table)+100)
      nl=nl+1; li(nl) = 'Short-range wake table:'
      nl=nl+1; li(nl) = &
            '   #           Z   Longitudinal     Transverse'
      do i = 0, ubound(ele%rf_wake%sr_table,1)
        sr_table => ele%rf_wake%sr_table(i)
        nl=nl+1; write (li(nl), '(i4, es12.4, 2es15.4)') i, sr_table%z, sr_table%long, sr_table%trans
      enddo
    else
      nl=nl+1; write (li(nl), *) 'Number of short-range wake table rows:', size(ele%rf_wake%sr_table)
    endif
  endif

  if (size(ele%rf_wake%sr_mode_long) /= 0) then
    nl=nl+1; write (li(nl), *)
    if (logic_option (.true., type_wake)) then
      nl=nl+1; li(nl) = 'Short-range pseudo modes:'
      nl=nl+1; li(nl) = &
            '   #        Amp        Damp           K         Phi'
      do i = 1, size(ele%rf_wake%sr_mode_long)
        sr_m => ele%rf_wake%sr_mode_long(i)
        nl=nl+1; write (li(nl), '(i4, 4es12.4)') i, sr_m%amp, sr_m%damp, sr_m%k, sr_m%phi
      enddo
    else
      nl=nl+1; li(nl) = 'No short-range longitudinal pseudo modes.'
    endif
  endif

  if (size(ele%rf_wake%sr_mode_trans) /= 0) then
    nl=nl+1; write (li(nl), *)
    if (logic_option (.true., type_wake)) then
      nl=nl+1; li(nl) = 'Short-range pseudo modes:'
      nl=nl+1; li(nl) = &
            '   #        Amp        Damp           K         Phi'
      do i = 1, size(ele%rf_wake%sr_mode_trans)
        sr_m => ele%rf_wake%sr_mode_trans(i)
        nl=nl+1; write (li(nl), '(i4, 4es12.4)') i, sr_m%amp, sr_m%damp, sr_m%k, sr_m%phi
      enddo
    else
     nl=nl+1; li(nl) = 'No short-range transverse pseudo modes.'
    endif
  endif

  if (size(ele%rf_wake%lr) /= 0) then
    nl=nl+1; write (li(nl), *)
    if (logic_option (.true., type_wake)) then
      nl=nl+1; li(nl) = 'Long-range HOM modes:'
      nl=nl+1; li(nl) = &
            '  #       Freq         R/Q           Q   m   Angle' // &
            '    b_sin     b_cos     a_sin     a_cos     t_ref'
      do i = 1, size(ele%rf_wake%lr)
        lr => ele%rf_wake%lr(i)
        angle = ' unpolar'
        if (lr%polarized) write (angle, '(f8.3)') lr%angle
        nl=nl+1; write (li(nl), '(i3, 3es12.4, i3, a, 5es10.2)') i, &
                lr%freq, lr%R_over_Q, lr%Q, lr%m, angle, &
                lr%b_sin, lr%b_cos, lr%a_sin, lr%a_cos, lr%t_ref
      enddo
    else
      nl=nl+1; li(nl) = 'No long-range HOM modes.'
    endif
  endif

endif

! Encode Floor coords

if (logic_option(.false., type_floor_coords)) then
  nl=nl+1; li(nl) = ''
  nl=nl+1; li(nl) = 'Global Floor Coords:'
  nl=nl+1; write (li(nl), '(3(a, f12.5, 5x))') 'X =    ', ele%floor%x,     'Y =  ', ele%floor%y,   'Z =  ', ele%floor%z 
  nl=nl+1; write (li(nl), '(3(a, f12.5, 5x))') 'Theta =', ele%floor%theta, 'Phi =', ele%floor%phi, 'Psi =', ele%floor%psi   
endif

! finish

allocate(lines(nl))
n_lines = nl
lines(1:nl) = li(1:nl)
deallocate (li)
  
end subroutine
