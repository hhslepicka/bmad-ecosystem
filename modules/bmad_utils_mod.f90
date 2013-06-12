!+
! Module bmad_utils_mod
!
! Module for some core utility routines.
!-

module bmad_utils_mod

use basic_attribute_mod

private pointer_to_ele1, pointer_to_ele2
private pointer_to_branch_given_name, pointer_to_branch_given_ele

!+
! Function pointer_to_branch
!
! Routine to return a pointer to the lattice branch associated with a given name
! or a given element.
!
! This routine is an overloaded name for:
!   pointer_to_branch_given_ele (ele) result (branch_ptr)
!   pointer_to_branch_given_name (branch_name, lat) result (branch_ptr)
!
! The lattice branch *associated* with a given element is not necessarily the
! branch where the element is *located*. For example, all lords live in branch #0.
! But the branch associated with a super_lord element is the branch of its slaves.
!
! To get the branch where the element is located, simply use ele%ix_branch.
! 
! Note: Result is ambiguous if ele argument is associated with multiple branches 
! which can happen, for example, with overlay_lord elements.
!
! Modules Needed:
!   use bmad_utils_mod
!
! Input:
!   ele         -- Ele_struct: Element contained in the branch.
!   branch_name -- Character(*): May be a branch name or a branch index.
!   lat         -- Lat_struct: Lattice to search.
!
! Output:
!   branch_ptr  -- branch_struct, pointer: Pointer to the branch.
!                   Nullified if there is no associated branch.
!-

interface pointer_to_branch
  module procedure pointer_to_branch_given_ele
  module procedure pointer_to_branch_given_name
end interface

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_ele (...)
!
! Routine to return a pointer to an element.
! pointer_to_ele is an overloaded name for:
!     Function pointer_to_ele1 (lat, ix_ele, ix_branch) result (ele_ptr)
!     Function pointer_to_ele2 (lat, ele_loc_id) result (ele_ptr)
!
! Also see:
!   pointer_to_slave
!   pointer_to_lord
!   pointer_to_field_ele
!
! Module needed:
!   use bmad_utils_mod
!
! Input:
!   lat       -- lat_struct: Lattice.
!   ix_ele    -- Integer: Index of element in lat%branch(ix_branch)
!   ix_branch -- Integer: Index of the lat%branch(:) containing the element.
!   ele_loc   -- Lat_ele_loc_struct: Location identification.
!
! Output:
!   ele_ptr  -- Ele_struct, pointer: Pointer to the element. 
!-

interface pointer_to_ele
  module procedure pointer_to_ele1
  module procedure pointer_to_ele2
end interface

contains

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function lord_edge_aligned (slave, slave_edge, lord) result (is_aligned)
!
! Routine to determine if the edge of a super_lord is aligned with a given edge 
! of a super_slave or slice_slave.
!
! Input:
!   slave       -- ele_struct: Slave element.
!   slave_edge  -- integer: End under consideration: upstream_end$, or downstream_end$.
!   lord        -- ele_struct: Lord element.
!
! Output:
!   is_aligned  -- integer: True if a lord edge is aligned with the slave edge.
!- 

function lord_edge_aligned (slave, slave_edge, lord) result (is_aligned)

implicit none

type (ele_struct), target :: slave, lord
type (branch_struct), pointer :: branch
integer slave_edge, ix_slave
real(rp) s_lord
logical is_aligned
character(*), parameter :: r_name = 'lord_edge_aligned'

! 

select case (slave_edge)
case (upstream_end$)
  s_lord = lord%s - lord%value(l$)
  branch => slave%branch
  if (associated(branch)) then
    if (s_lord < branch%ele(0)%s) s_lord = s_lord + branch%param%total_length
  endif
  is_aligned = (abs(slave%s - slave%value(l$) - s_lord) < bmad_com%significant_length)

case (downstream_end$)
  is_aligned = (abs(slave%s - lord%s) < bmad_com%significant_length)

case default
  call out_io (s_fatal$, r_name, 'BAD SLAVE_EDGE VALUE!')
  if (global_com%exit_on_error) call err_exit
end select

end function lord_edge_aligned

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function at_this_ele_end (now_at, where_at, orientation) result (is_at_this_end)
!
! Routine to determine if an aperture or fringe field is present.
!
! Input:
!   now_at      -- Integer: Which end is under consideration: upstream_end$, downstream_end$, or surface$.
!   where_at    -- Integer: Which ends have the aperture or fringe field: entrance_end$
!                     exit_end$, continuous$, both_ends$, no_ends$, surface$.
!   orientation -- Integer: element orientation: +/- 1.
!
! Output:
!   is_at_this_end   -- Logical: True if at this end. False otherwise.
!- 

function at_this_ele_end (now_at, where_at, orientation) result (is_at_this_end)

implicit none

integer now_at, where_at, orientation, physical_end
logical is_at_this_end

!

if (now_at == surface$ .or. where_at == surface$) then
  is_at_this_end = (now_at == where_at)
  return
endif

!

physical_end = physical_ele_end (now_at, orientation)
select case (physical_end)
case (entrance_end$)
  select case (where_at)
  case (entrance_end$, both_ends$, continuous$); is_at_this_end = .true.
  case default;                                  is_at_this_end = .false.
  end select

case (exit_end$)
  select case (where_at)
  case (exit_end$, both_ends$, continuous$); is_at_this_end = .true.
  case default;                              is_at_this_end = .false.
  end select
end select

end function at_this_ele_end

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function physical_ele_end (stream_end, ele_orientation) result (physical_end)
!
! Rotine to determine which physical end of an element a particle is at given 
! the position in terms of upstream/downstream and the element's orientation
!
! Input:
!   stream_end       -- Integer: upstream_end$, downstream_end$, surface$
!   ele_orientation  -- Integer: Either 1 = Normal or -1 = element reversed.
!
! Output:
!   physical_end     -- Integer: entrance_end$, exit_end$, or surface$
!-

function physical_ele_end (stream_end, ele_orientation) result (physical_end)

implicit none

integer stream_end, ele_orientation, physical_end
character(*), parameter :: r_name  = 'physical_ele_end'

!

if (stream_end == surface$) then
  physical_end = surface$
  return
endif

!

select case (ele_orientation)

case (1) 
  select case (stream_end)
  case (upstream_end$);   physical_end = entrance_end$
  case (downstream_end$); physical_end = exit_end$
  case default;
    call out_io (s_fatal$, r_name, 'BAD STREAM_END: \i0\ ', i_array = [stream_end])
    if (global_com%exit_on_error) call err_exit
  end select

case (-1) 
  select case (stream_end)
  case (upstream_end$);   physical_end = exit_end$
  case (downstream_end$); physical_end = entrance_end$
  case default;
    call out_io (s_fatal$, r_name, 'BAD STREAM_END: \i0\ ', i_array = [stream_end])
    if (global_com%exit_on_error) call err_exit
  end select

case default
  call out_io (s_fatal$, r_name, 'BAD ELEMENT ORIENTATION: \i0\ ', i_array = [ele_orientation])
  if (global_com%exit_on_error) call err_exit

end select

end function physical_ele_end 

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function stream_ele_end (physical_end, ele_orientation) result (stream_end)
!
! Rotine to determine which stream end of an element a particle is at given 
! the position in terms of the physical end and the element's orientation
!
! Input:
!   physical_end     -- Integer: entrance_end$, exit_end$, surface$, etc.
!   ele_orientation  -- Integer: Either 1 = Normal or -1 = element reversed.
!
! Output:
!   stream_end       -- Integer: upstream_end$, downstream_end$, or set equal
!                         to physical_end if physical_end is neither entrance_end$
!                         nor exit_end$
!-

function stream_ele_end (physical_end, ele_orientation) result (stream_end)

implicit none

integer stream_end, ele_orientation, physical_end
character(*), parameter :: r_name  = 'stream_ele_end'

!

if (physical_end /= entrance_end$ .and. physical_end /= exit_end$) then
  stream_end = physical_end
  return
endif

!

select case (ele_orientation)

case (1) 
  select case (physical_end)
  case (entrance_end$);   stream_end = upstream_end$
  case (exit_end$);       stream_end = downstream_end$
  case default;
    call out_io (s_fatal$, r_name, 'BAD PHYSICAL_END: \i0\ ', i_array = [physical_end])
    if (global_com%exit_on_error) call err_exit
  end select

case (-1) 
  select case (physical_end)
  case (entrance_end$);   stream_end = downstream_end$
  case (exit_end$);       stream_end = upstream_end$
  case default;
    call out_io (s_fatal$, r_name, 'BAD PHYSICAL_END: \i0\ ', i_array = [physical_end])
    if (global_com%exit_on_error) call err_exit
  end select

case default
  call out_io (s_fatal$, r_name, 'BAD ELEMENT ORIENTATION: \i0\ ', i_array = [ele_orientation])
  if (global_com%exit_on_error) call err_exit

end select

end function stream_ele_end 

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine check_if_s_in_bounds (branch, s, err_flag, translated_s)
!
! Routine to check if a given longitudinal position s is within the bounds of a given branch of a lattice.
! For linear branches the bounds are normally [0, branch_length].
! For circular branches negative s values do make sense so the bounds 
!   are normally [-branch_length, branch_length].
!
! "Normally" means that starting s-position in the branch is zero. This routine does
! adjust for non-zero starting s-positions.
!
! This routine will bomb the program if global_com%exit_on_error is True.
!
! Optionally: translated_s is a translated longitudinal position which is normally
! in the range [0, branch_length].
!
! Moduels needed:
!   use bmad
!
! Input:
!   branch        -- branch_struct: Branch
!   s             -- Real(rp): longitudinal position in the given branch.
!   
! Output:
!   err_flag      -- Logical: Set True if s position is out-of-bounds. False otherwise.
!   translated_s  -- Real(rp), optional: position translated to the range [0, branch_length]
!-

subroutine check_if_s_in_bounds (branch, s, err_flag, translated_s)

implicit none

type (branch_struct) branch

real(rp) s, ss, s_min, s_max, ds_fudge, s_bound
real(rp), optional :: translated_s

logical err_flag

character(24), parameter :: r_name = 'check_if_s_in_bounds'

! Setup

s_min = branch%ele(0)%s
s_max = branch%ele(branch%n_ele_track)%s 
ds_fudge = bmad_com%significant_length
err_flag = .false.
ss = s

! Check

if (s > s_max + ds_fudge) then
  err_flag = .true.
  s_bound = s_max
elseif (branch%param%geometry == closed$) then
  if (s < s_min - (s_max - s_min) - ds_fudge) then
    err_flag = .true.
    s_bound = s_min - (s_max - s_min)
  endif
  if (s < s_min) ss = s + (s_max - s_min)
elseif (s < s_min - ds_fudge) then
  err_flag = .true.
  s_bound = s_min
endif

! Finish

if (err_flag) then
  if (global_com%type_out) call out_io (s_fatal$, r_name, &
        'S-POSITION \es20.12\ PAST EDGE OF LATTICE. ' , &
        'PAST LATTICE EDGE AT: \es20.12\ ', r_array = [s, s_bound])
  if (global_com%exit_on_error) call err_exit
endif

if (present(translated_s)) translated_s = ss

end subroutine check_if_s_in_bounds 

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function ele_loc_to_string (ele, show_branch0) result (str)
!
! Routine to encode an element's location into a string.
! Example output:
!   "34"     ! Input: lat%ele(34) which is equivalent to lat%branch(0)%ele(34)
!   "0>>34"  ! Same as above if show_branch0 is set to True.
!   "1>>56"  ! Input: lat%branch(1)%ele(56).
!
! Modules needed:
!   use bmad
!
! Input:
!   ele          -- Ele_struct: Element in a lattice
!   show_branch0 -- Logical, optional: Explicitly show branch for main 
!                     lattice elements? Default is False.
!
! Output:
!   str(10)     -- Character: Output string. Left justified.
!-

function ele_loc_to_string (ele, show_branch0) result (str)

implicit none

type (ele_struct) ele
logical, optional :: show_branch0

character(10) str

!

if (ele%ix_branch == 0 .and. .not. logic_option(.false., show_branch0)) then
  write (str, '(i0)') ele%ix_ele
else
  write (str, '(i0, a, i0)') ele%ix_branch, '>>', ele%ix_ele
endif

end function ele_loc_to_string 

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function on_a_girder(ele) result (is_on_girder)
!
! Routine to determine if an element is being supported by a girder element.
!
! Input:
!   ele     -- ele_struct: Element to check.
!
! Output:
!   is_on_girder -- Logical: True if supported. False otherwise.
!- 

function on_a_girder(ele) result (is_on_girder)

implicit none

type (ele_struct), target :: ele
type (ele_struct), pointer :: lord
logical is_on_girder
integer i

!

is_on_girder = .false.

do i = 1, ele%n_lord
  lord => pointer_to_lord(ele, i)
  if (lord%key /= girder$) cycle
  is_on_girder = .true.
  return
enddo

end function on_a_girder

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine check_controller_controls (contrl, name, err)
!
! Routine to check for problems when setting up group or overlay controllers.
!
! Modules needed:
!   use bmad
!
! Input:
!   contrl(:)   -- Control_struct: control info. 1 element for each slave.
!   name        -- Character(*): Lord name. Used for error reporting.
!
! Output:
!   err         -- Logical: Set true if there is a problem. False otherwise.
!-

subroutine check_controller_controls (contrl, name, err)

implicit none

type (control_struct), target :: contrl(:)
type (control_struct), pointer :: c1, c2
integer i, j
logical err
character(*) name
character(40) :: r_name = 'check_controller_controls'

!

err = .true.

do i = 1, size(contrl)
  c1 => contrl(i)
  do j = i+1, size(contrl)
    c2 => contrl(j)
    if (c1%ix_slave == c2%ix_slave .and. c1%ix_branch == c2%ix_branch .and. &
                                         c1%ix_attrib == c2%ix_attrib) then
      call out_io (s_error$, r_name, 'DUPLICATE SLAVE CONTROL FOR LORD: ' // name)
      return
    endif
  enddo
enddo

err = .false.

end subroutine check_controller_controls

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function particle_is_moving_forward (orbit) result (is_moving_forward)
!
! Routine to determine if a particle is moving in the forward +s direction.
! If not moving forward it is dead or is moving backward.
!
! Remember: +s and +z directions are counteraligned if element being tracked 
! through is reversed.
!
! Input:
!   orbit     -- coord_struct: Particle coordinates
!
! Output:
!   is_moving_forward -- Logical: True if moving forward. False otherwise.
!-

function particle_is_moving_forward (orbit) result (is_moving_forward)

implicit none

type (coord_struct) orbit
integer particle
logical is_moving_forward

!

is_moving_forward = (orbit%state == alive$) .and. (orbit%p0c > 0)

end function particle_is_moving_forward

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function particle_is_moving_backward (orbit) result (is_moving_backward)
!
! Routine to determine if a particle is moving in the backward -s direction.
! If not moving backward it is dead or is moving backward.
!
! Remember: +s and +z directions are counteraligned if element being tracked 
! through is reversed.
!
! Input:
!   orbit  -- coord_struct: Particle coordinates
!
! Output:
!   is_moving_backward -- Logical: True if moving backward. False otherwise.
!-

function particle_is_moving_backward (orbit) result (is_moving_backward)

implicit none

type (coord_struct) orbit
logical is_moving_backward

!

is_moving_backward = (orbit%state == alive$) .and. (orbit%p0c < 0)

end function particle_is_moving_backward

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function key_name_to_key_index (key_str, abbrev_allowed) result (key_index)
!
! Function to convert a character string  (eg: "drift") to an index (eg: drift$).
!
! Modules needed:
!   use bmad
!
! Input:
!   key_str        -- Character(*): Name of the key. Result is case insensitive.
!   abbrev_allowed -- Logical, optional: Abbreviations (eg: "quad") allowed?
!                       Default is False. At least 3 characters are needed 
!                       (except for rfcavity elements) if True.
!
! Output:
!   key_index -- Integer: Index of the key. Set to -1 if key_name not recognized.
!-

function key_name_to_key_index (key_str, abbrev_allowed) result (key_index)

implicit none

character(*) key_str
character(16) name

logical, optional :: abbrev_allowed
logical abbrev

integer key_index
integer i, n_name, n_match

!

n_match = 0
key_index = -1
if (key_str == '') return

call str_upcase (name, key_str)
call string_trim (name, name, n_name)

abbrev = logic_option(.false., abbrev_allowed)

do i = 1, n_key$
  if (abbrev .and. (n_name > 2 .or. name(1:2) == "RF")) then
    if (name(:n_name) == key_name(i)(1:n_name)) then
      key_index = i
      n_match = n_match + 1
    endif
  else
    if (name == key_name(i)) then
      key_index = i
      return
    endif
  endif
enddo

if (abbrev .and. n_match > 1) key_index = -1  ! Multiple matches are not valid

end function key_name_to_key_index 

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function ele_has_nonzero_kick (ele) result (has_kick)
!
! Function to determine if an element has nonzero kick values.
! Kicks are something hkick$, bl_vkick$, etc.
! See also: zero_ele_kicks, ele_has_offset, zero_ele_offsets.
!
! Modules needed:
!   use bmad
!
! Input
!   ele -- Ele_struct: Element with possible nonzero kicks.
!
! Output:
!   ele -- Ele_struct: Element with no kicks.
!-

function ele_has_nonzero_kick (ele) result (has_kick)

implicit none

type (ele_struct) ele
logical has_kick

!

has_kick = .false.

if (has_hkick_attributes(ele%key)) then
  if (ele%value(bl_hkick$) /= 0) has_kick = .true.
  if (ele%value(bl_vkick$) /= 0) has_kick = .true.

elseif (has_kick_attributes(ele%key)) then
  if (ele%value(bl_kick$) /= 0) has_kick = .true.
endif

if (ele%key == lcavity$ .or. ele%key == rfcavity$) then
  if (ele%value(coupler_strength$) /= 0) has_kick = .true.
endif

end function ele_has_nonzero_kick

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine zero_ele_kicks (ele)
!
! Subroutine to zero any kick attributes like hkick$, bl_vkick$, etc.
! See also: ele_has_nonzero_kick, ele_has_offset, zero_ele_offsets.
!
! Modules needed:
!   use bmad
!
! Input
!   ele -- Ele_struct: Element with possible nonzero kicks.
!
! Output:
!   ele -- Ele_struct: Element with no kicks.
!-

subroutine zero_ele_kicks (ele)

implicit none

type (ele_struct) ele

!

if (has_hkick_attributes(ele%key)) then
  ele%value(hkick$) = 0
  ele%value(vkick$) = 0
  ele%value(bl_hkick$) = 0
  ele%value(bl_vkick$) = 0

elseif (has_kick_attributes(ele%key)) then
  ele%value(kick$) = 0
  ele%value(bl_kick$) = 0
endif

if (ele%key == lcavity$ .or. ele%key == rfcavity$) then
  ele%value(coupler_strength$) = 0
endif

end subroutine zero_ele_kicks

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function ele_has_offset (ele) result (has_offset)
!
! Function to tell if an element has a non-zero offset, pitch or tilt.
! Also see: zero_ele_offsets, zero_ele_kicks, ele_has_nonzero_kick
!
! Modules needed:
!   use bmad
!
! Input
!   ele -- Ele_struct: Element with possible nonzero offsets.
!
! Output:
!   has_offset -- Logical: Set true is element has a non-zero offset.
!-

function ele_has_offset (ele) result (has_offset)

implicit none

type (ele_struct) ele
logical has_offset

!

has_offset = .false.
if (.not. has_orientation_attributes(ele)) return

select case (ele%key)
case (sbend$)
  if (ele%value(roll_tot$) /= 0) has_offset = .true.
  if (ele%value(ref_tilt_tot$) /= 0) has_offset = .true.
case (mirror$, multilayer_mirror$, crystal$)
  if (ele%value(tilt_tot$) /= 0) has_offset = .true.
  if (ele%value(ref_tilt_tot$) /= 0) has_offset = .true.
case default
  if (ele%value(tilt_tot$) /= 0) has_offset = .true.
end select

if (ele%value(x_pitch_tot$) /= 0) has_offset = .true.
if (ele%value(y_pitch_tot$) /= 0) has_offset = .true.
if (ele%value(x_offset_tot$) /= 0) has_offset = .true.
if (ele%value(y_offset_tot$) /= 0) has_offset = .true.
if (ele%value(z_offset_tot$) /= 0) has_offset = .true.

end function ele_has_offset

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine zero_ele_offsets (ele)
!
! Subroutine to zero the offsets, pitches, tilt and ref_tilt of an element.
! Also see: ele_has_offset, zero_ele_kicks, ele_has_nonzero_kick
!
! Modules needed:
!   use bmad
!
! Input
!   ele -- Ele_struct: Element with possible nonzero offsets, etc.
!
! Output:
!   ele -- Ele_struct: Element with no (mis)orientation.
!-

subroutine zero_ele_offsets (ele)

implicit none

type (ele_struct) ele

!

if (.not. has_orientation_attributes(ele)) return

select case (ele%key)
case (sbend$)
  ele%value(roll$) = 0
  ele%value(roll_tot$) = 0
  ele%value(ref_tilt$) = 0
  ele%value(ref_tilt_tot$) = 0
case (mirror$, multilayer_mirror$, crystal$)
  ele%value(tilt$) = 0
  ele%value(tilt_tot$) = 0
  ele%value(ref_tilt$) = 0
  ele%value(ref_tilt_tot$) = 0
case default
  ele%value(tilt$) = 0
  ele%value(tilt_tot$) = 0
end select

ele%value(x_pitch$) = 0
ele%value(y_pitch$) = 0
ele%value(x_offset$) = 0
ele%value(y_offset$) = 0
ele%value(z_offset$) = 0

ele%value(x_pitch_tot$) = 0
ele%value(y_pitch_tot$) = 0
ele%value(x_offset_tot$) = 0
ele%value(y_offset_tot$) = 0
ele%value(z_offset_tot$) = 0

end subroutine zero_ele_offsets

!------------------------------------------------------------------------
!------------------------------------------------------------------------
!------------------------------------------------------------------------
!+
! Subroutine apply_energy_kick (dE, particle, orbit)
! 
! Routine to change the energy of a particle by an amount dE
! Appropriate changes to z and beta will be made
!
! Module needed:
!   use bmad
!
! Input:
!   dE        -- real(rp): Energy change
!   particle  -- integer: Particle type. positron$, etc.
!   orbit     -- coord_struct: Beginning coordinates
!
! Output:
!   orbit     -- coord_struct: coordinates with added dE energy kick.
!     %vec(6)   -- Set to -1 if particle energy becomes negative.
!-

subroutine apply_energy_kick (dE, particle, orbit)

implicit none

type (coord_struct) orbit
real(rp) dE, mc2, new_pc, new_beta, p0c, new_E, pc, beta, t3
integer particle

!

mc2 = mass_of(particle)
p0c = orbit%p0c
pc = (1 + orbit%vec(6)) * p0c
beta = orbit%beta

new_E = pc / orbit%beta + dE

if (new_E < 0) then
  orbit%vec(6) = -1
  orbit%beta = 0
  return
endif

t3 = mc2**2 * dE**3 / (2 * p0c * beta * pc**4) 
if (t3 < 1e-12) then
  orbit%vec(6) = orbit%vec(6) + dE / (beta * p0c) - (mc2 * dE / pc)**2 / (2 * p0c * pc) + t3
  new_pc = p0c * (1 + orbit%vec(6))
else
  new_pc = sqrt(new_E**2 - mc2**2)
  orbit%vec(6) = (new_pc - p0c) / p0c
endif

new_beta = new_pc / new_E
orbit%vec(5) = orbit%vec(5) * new_beta / beta
orbit%beta = new_beta

end subroutine apply_energy_kick

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+ 
! Function equivalent_taylor_attributes (ele_taylor, ele2) result (equiv)
!
! Subroutine to see if two elements are equivalent in terms of attributes so
! that their Taylor Maps would be the same. 
!
! This routine is used to see if a taylor map from one element may be 
! used for another and thus save some computation time. elements of type taylor
! are considered *never* to be equivalent since their maps are never computed.
!
! Modules needed:
!   use bmad
!
! Input: 
!   ele_taylor -- Ele_struct: Element with a Taylor map
!   ele2       -- Ele_struct: Element that might receive the Taylor map from ele_taylor.
!
! Output:
!   equiv -- logical: True if elements are equivalent.
!-

function equivalent_taylor_attributes (ele_taylor, ele2) result (equiv)

implicit none

type (ele_struct) :: ele_taylor, ele2

integer it

logical equiv
logical vmask(num_ele_attrib$), vnot(num_ele_attrib$)

!

equiv = .false.

if (ele_taylor%key == taylor$) return  
if (ele_taylor%key /= ele2%key) return
if (ele_taylor%sub_key /= ele2%sub_key) return
if (ele_taylor%map_with_offsets .neqv. ele2%map_with_offsets) return
if (ele_taylor%value(integrator_order$) /= ele2%value(integrator_order$)) return

vmask = .true.
vmask(delta_ref_time$) = .false.
vmask(ref_time_start$) = .false.
if (ele_taylor%key == wiggler$ .and. ele_taylor%sub_key == map_type$) then
  vmask( [k1$, rho$, b_max$] ) = .false.  ! These are dependent attributes.
endif
if (.not. ele_taylor%map_with_offsets) then
  vmask( [x_offset$, y_offset$, z_offset$, tilt$, x_pitch$, &
            y_pitch$, x_offset_tot$, y_offset_tot$, z_offset_tot$, &
            tilt_tot$, x_pitch_tot$, y_pitch_tot$] ) = .false.
endif

vnot = (ele_taylor%value /= ele2%value)
vnot = vnot .and. vmask
if (any(vnot)) return

if (associated(ele_taylor%wig) .neqv. associated(ele2%wig)) return
if (associated(ele_taylor%wig)) then
  if (size(ele_taylor%wig%term) /= size(ele2%wig%term)) return
  do it = 1, size(ele_taylor%wig%term)
    if (ele_taylor%wig%term(it)%coef  /= ele2%wig%term(it)%coef)  cycle
    if (ele_taylor%wig%term(it)%kx    /= ele2%wig%term(it)%kx)    cycle
    if (ele_taylor%wig%term(it)%ky    /= ele2%wig%term(it)%ky)    cycle
    if (ele_taylor%wig%term(it)%kz    /= ele2%wig%term(it)%kz)    cycle
    if (ele_taylor%wig%term(it)%phi_z /= ele2%wig%term(it)%phi_z) cycle
  enddo
endif

equiv = .true.

end function equivalent_taylor_attributes 

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!+
! Subroutine clear_lat_1turn_mats (lat)
!
! Subroutine to clear the 1-turn matrices in the lat structure:
!   lat%param%t1_no_RF
!   lat%param%t1_with_RF
! This will force any routine dependent upon these to do a remake.
!
! Modules needed:
!   use bmad
!
! Output:
!   lat -- lat_struct: Lat with 1-turn matrices cleared.
!-

subroutine clear_lat_1turn_mats (lat)

implicit none

type (lat_struct) lat

lat%param%t1_no_RF = 0
lat%param%t1_with_RF = 0

end subroutine clear_lat_1turn_mats


!--------------------------------------------------------------------
!--------------------------------------------------------------------
!--------------------------------------------------------------------
!+
! Subroutine transfer_mat_from_twiss (ele1, ele2, m)
!
! Subroutine to make a 6 x 6 transfer matrix from the twiss parameters
! at two points.
!
! Modules Needed:
!   use bmad
!
! Input:
!   ele1 -- Ele_struct: Element with twiss parameters for the starting point.
!     %a, %b -- a-mode and b-mode Twiss paramters
!       %beta   -- Beta parameter.
!       %alpha  -- Alpha parameter.
!       %phi    -- Phase at initial point.
!     %x  %y -- dispersion values
!       %eta    -- Dispersion at initial point.
!       %etap   -- Dispersion derivative at initial point.
!     %c_mat(2,2) -- Coupling matrix
!   ele2 -- Ele_struct: Element with twiss parameters for the ending point.
!
! Output:
!   m(6,6) -- Real(rp): Transfer matrix between the two points.
!-

subroutine transfer_mat_from_twiss (ele1, ele2, m)

implicit none

type (ele_struct) ele1, ele2

real(rp) m(6,6), v_mat(4,4), v_inv_mat(4,4), det
character(20) :: r_name = 'transfer_mat_from_twiss'

! Error check

if (ele1%a%beta == 0 .or. ele1%b%beta == 0) then
  call out_io (s_abort$, r_name, 'ZERO BETA IN ELEMENT: ' // ele1%name)
  if (global_com%exit_on_error) call err_exit
endif

if (ele2%a%beta == 0 .or. ele2%b%beta == 0) then
  call out_io (s_abort$, r_name, 'ZERO BETA IN ELEMENT: ' // ele2%name)
  if (global_com%exit_on_error) call err_exit
endif

! Transfer matrices without coupling or dispersion

call mat_make_unit (m)
call transfer_mat2_from_twiss (ele1%a, ele2%a, m(1:2,1:2))
call transfer_mat2_from_twiss (ele1%b, ele2%b, m(3:4,3:4))

! Add in coupling

if (any(ele1%c_mat /= 0)) then
  det = determinant (ele1%c_mat)
  ele1%gamma_c = sqrt(1-det)
  call make_v_mats (ele1, v_mat, v_inv_mat)
  m(1:4,1:4) = matmul (m(1:4,1:4), v_inv_mat)
endif

if (any(ele2%c_mat /= 0)) then
  det = determinant (ele2%c_mat)
  ele2%gamma_c = sqrt(1-det)
  call make_v_mats (ele2, v_mat, v_inv_mat)
  m(1:4,1:4) = matmul (v_mat, m(1:4,1:4))
endif

! Add in dispersion.

m(1:4,6) = [ele2%x%eta, ele2%x%etap, ele2%y%eta, ele2%y%etap] - &
        matmul (m(1:4,1:4), [ele1%x%eta, ele1%x%etap, ele1%y%eta, ele1%y%etap]) 

! The m(5,x) terms follow from the symplectic condition.

m(5,1) = -m(2,6)*m(1,1) + m(1,6)*m(2,1) - m(4,6)*m(3,1) + m(3,6)*m(4,1)
m(5,2) = -m(2,6)*m(1,2) + m(1,6)*m(2,2) - m(4,6)*m(3,2) + m(3,6)*m(4,2)
m(5,3) = -m(2,6)*m(1,3) + m(1,6)*m(2,3) - m(4,6)*m(3,3) + m(3,6)*m(4,3)
m(5,4) = -m(2,6)*m(1,4) + m(1,6)*m(2,4) - m(4,6)*m(3,4) + m(3,6)*m(4,4)


end subroutine transfer_mat_from_twiss

!--------------------------------------------------------------------
!--------------------------------------------------------------------
!--------------------------------------------------------------------
!+
! Subroutine match_ele_to_mat6 (ele, vec0, mat6, err_flag)
!
! Subroutine to make the 6 x 6 transfer matrix from the twiss parameters
! at the entrance and exit ends of the element.
!
! Modules Needed:
!   use bmad
!
! Input:
!   ele -- Ele_struct: Match element.
!     %value(beta_a0$) -- Beta_a at the start
!
! Output:
!   vec0(6)   -- Real(rp): Currently just set to zero.
!   mat6(6,6) -- Real(rp): Transfer matrix.
!   err_flag  -- Logical: Set true if there is an error. False otherwise.
!-

subroutine match_ele_to_mat6 (ele, vec0, mat6, err_flag)

implicit none

type (ele_struct), target :: ele, ele0, ele1

real(rp) mat6(6,6), vec0(6)
real(rp), pointer :: v(:)

logical err_flag

! Special case where match_end is set but there is no beginning beta value yet.
! In this case, just return the unit matrix and set the err_flag.

if (ele%value(match_end$) /= 0 .and. (ele%value(beta_a0$) == 0 .or. ele%value(beta_b0$) == 0)) then
  call mat_make_unit (mat6)
  vec0 = 0
  err_flag = .true.
  return
endif

!

err_flag = .false.

v => ele%value

ele0%a%beta   = v(beta_a0$)
ele0%a%alpha  = v(alpha_a0$)
ele0%a%phi    = 0
ele0%x%eta    = v(eta_x0$)
ele0%x%etap   = v(etap_x0$)

ele0%b%beta   = v(beta_b0$)
ele0%b%alpha  = v(alpha_b0$)
ele0%b%phi    = 0
ele0%y%eta    = v(eta_y0$)
ele0%y%etap   = v(etap_y0$)

ele1%a%beta   = v(beta_a1$)
ele1%a%alpha  = v(alpha_a1$)
ele1%a%phi    = v(dphi_a$)
ele1%x%eta    = v(eta_x1$)
ele1%x%etap   = v(etap_x1$)

ele1%b%beta   = v(beta_b1$)
ele1%b%alpha  = v(alpha_b1$)
ele1%b%phi    = v(dphi_b$)
ele1%y%eta    = v(eta_y1$)
ele1%y%etap   = v(etap_y1$)

ele0%c_mat(1,:) = [v(c_11$), v(c_12$)]
ele0%c_mat(2,:) = [v(c_21$), v(c_22$)]
ele0%gamma_c    = v(gamma_c$)

ele1%c_mat = 0 
ele1%gamma_c = 1

ele0%name = ele%name
ele1%name = ele%name

call transfer_mat_from_twiss (ele0, ele1, mat6)

! Kick part

vec0 = [v(x1$), v(px1$), v(y1$), v(py1$), v(z1$), v(pz1$)] - &
       matmul (mat6, [v(x0$), v(px0$), v(y0$), v(py0$), v(z0$), v(pz0$)])

end subroutine match_ele_to_mat6

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
!+
! Subroutine calc_superimpose_key (ele1, ele2, ele3, create_jumbo_slave)
!
! Function to decide what ele3%key and ele3%sub_key should be
! when two elements, ele1, and ele2, are superimposed.
!
! Modules needed:
!   use bmad
!
! Input:
!   ele1     -- Ele_struct:
!     %key
!     %sub_key
!   ele2     -- Ele_struct:
!     %key
!     %sub_key
!   create_jumbo_slave
!            -- Logical, optional: Default is False. If True then ele3%key
!                     will be set to em_field.
!
! Output:
!   ele3 -- Ele_struct:
!     %key        -- Set to -1 if there is an error
!     %sub_key
!-

subroutine calc_superimpose_key (ele1, ele2, ele3, create_jumbo_slave)

implicit none

type (ele_struct), target :: ele1, ele2, ele3
integer key1, key2
integer, pointer :: key3
logical, optional :: create_jumbo_slave

!

key1 = ele1%key
key2 = ele2%key
key3 => ele3%key

key3 = -1  ! Default if no superimpse possible
ele3%sub_key = 0

! control elements, etc. cannot be superimposed.

select case (key1)
case (overlay$, group$, girder$, taylor$, match$, patch$, fiducial$, floor_shift$, multipole$, ab_multipole$)
  return
end select

select case (key2)
case (overlay$, group$, girder$, taylor$, match$, patch$, fiducial$, floor_shift$, multipole$, ab_multipole$)
  return
end select

! Superimposing two of like kind...

if (key1 == key2) then
  select case (key1)
  case (sbend$)
    ! Bad
  case (wiggler$, rfcavity$)
    key3 = em_field$
    ele3%sub_key = const_ref_energy$
  case (lcavity$)
    key3 = em_field$
    ele3%sub_key = nonconst_ref_energy$
  case (em_field$)
    key3 = em_field$
    if (ele1%sub_key == nonconst_ref_energy$ .or. ele2%sub_key == nonconst_ref_energy$) then
      ele3%sub_key = nonconst_ref_energy$
    else
      ele3%sub_key = const_ref_energy$
    endif
  case default
    key3 = key1
  end select
  return
endif

! If one element is a drift then key3 = key of other element.

if (key1 == drift$) then
  key3 = key2
  ele3%sub_key = ele2%sub_key
  return
endif

if (key2 == drift$) then
  key3 = key1
  ele3%sub_key = ele1%sub_key
  return
endif

! If one element is a pipe then key3 = key of other element.

if (any(key1 == [pipe$])) then
  key3 = key2
  return
endif

if (any(key2 == [pipe$])) then
  key3 = key1
  return
endif

! If one element is a rcollimator, monitor, or instrument then key3 = key of other element.

if (ele1%aperture_type == elliptical$ .or. ele2%aperture_type == elliptical$ ) ele3%aperture_type = elliptical$

if (any(key1 == [ecollimator$, rcollimator$, monitor$, instrument$])) then
  key3 = key2
  return
endif

if (any(key2 == [ecollimator$, rcollimator$, monitor$, instrument$])) then
  key3 = key1
  return
endif

! If one element is a kicker then key3 = key of other element.

if (any(key1 == [kicker$, hkicker$, vkicker$])) then
  if (any(key2 == [kicker$, hkicker$, vkicker$])) then
    key3 = kicker$
  else
    key3 = key2
  endif
  return
endif

if (any(key2 == [kicker$, hkicker$, vkicker$])) then
  key3 = key1
  return
endif

! General case...

! sbend elements are problematical due to the different reference orbit so cannot superimpose them.

if (key1 == sbend$ .or. key2 == sbend$) return

! em_field wanted

if (logic_option(.false., create_jumbo_slave)) then
  key3 = em_field$
  if (key1 == lcavity$ .or. key2 == lcavity$) then
    ele3%sub_key = nonconst_ref_energy$
  elseif (key1 == em_field$) then
    ele3%sub_key = ele1%sub_key
  elseif (key2 == em_field$) then
    ele3%sub_key = ele2%sub_key
  else
    ele3%sub_key = const_ref_energy$
  endif
  return
endif

!

select case (key1)

case (quadrupole$,  solenoid$, sol_quad$) 
  select case (key2)
  case (quadrupole$);    key3 = sol_quad$
  case (solenoid$);      key3 = sol_quad$
  case (sol_quad$);      key3 = sol_quad$
  case (bend_sol_quad$); key3 = bend_sol_quad$
  case (sbend$);         key3 = bend_sol_quad$
  end select

case (bend_sol_quad$)
  select case (key2)
  case (quadrupole$);    key3 = bend_sol_quad$
  case (solenoid$);      key3 = bend_sol_quad$
  case (sol_quad$);      key3 = bend_sol_quad$
  case (sbend$);         key3 = bend_sol_quad$
  end select
end select

if (key3 /= -1) return  ! Have found something

! Only thing left is to use em_field type element.

key3 = em_field$
if (key1 == lcavity$ .or. key2 == lcavity$) then
  ele3%sub_key = nonconst_ref_energy$
elseif (key1 == em_field$) then
  ele3%sub_key = ele1%sub_key
elseif (key2 == em_field$) then
  ele3%sub_key = ele2%sub_key
else
  ele3%sub_key = const_ref_energy$
endif

end subroutine calc_superimpose_key

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Function gradient_shift_sr_wake (ele, param) result (grad_shift)
! 
! Function to return the shift in the accelerating gradient due to:
!   1) Short range longitudinal wake forces.
!   2) Adjustment in the external applied RF power attempting to compensate for the SR wake loss.
!
! Note: This routine will only return a non-zero value when bmad_com%sr_wakes_on = True
!
! Module needed:
!   use bmad
!
! Input:
!   ele           -- ele_struct: Lcavity element.
!   param         -- lat_param_struct: Lattice parameters
!     %n_part        -- Number of particles in a bunch
!     %particle      -- Type of particle
!
! Output:
!   grad_shift -- Real(rp): Shift in gradient
!-

function gradient_shift_sr_wake (ele, param) result (grad_shift)

implicit none

type (ele_struct) ele
type (lat_param_struct) param
real(rp) grad_shift

! ele%value(grad_loss_sr_wake$) is an internal variable used with macroparticles.
! It accounts for the longitudinal short-range wakefields between macroparticles.
! It is continually being modified for each macroparticle

if (bmad_com%sr_wakes_on .and. ele%value(l$) /= 0) then
  grad_shift = ele%value(e_loss$) * param%n_part * abs(charge_of(param%particle)) * &
                                      e_charge / ele%value(l$) - ele%value(grad_loss_sr_wake$) 
else
  grad_shift = 0
endif

end function gradient_shift_sr_wake

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine set_ele_status_stale (ele, status_group, set_slaves)
!
! Routine to set a status flags to stale in an element and the corresponding 
! ones for any slaves the element has.
!
! Also the branch%param structure of the branch the element is in is set.
!
! For example: status_group = ref_energy_group$ sets stale:
!   ele%bookkeeping_state%ref_energy 
!   ele%bookkeeping_state%floor_position
!   ele%bookkeeping_state%mat6
! See the code for more details.
! 
! Output:
!   ele           -- ele_struct: Element.
!     %bookkeeping_state   -- Status block to set.
!   status_group  -- Integer: Which flag groups to set. Possibilities are:
!                      attribute_group$, control_group$, floor_position_group$,
!                      s_position_group$, ref_energy_group$, or mat6_group$, all_groups$
!   set_slaves    -- Logical, optional: If present and False then do not set
!                      the status for any slaves. Default is True.
!-

recursive subroutine set_ele_status_stale (ele, status_group, set_slaves)

implicit none

type (bookkeeping_state_struct), pointer :: state
type (ele_struct), target :: ele
type (ele_struct), pointer :: slave
integer status_group, i
logical, optional :: set_slaves

! Only set overall lattice status flags if the element is part of a lattice.


if (ele%ix_ele > -1 .and. associated(ele%branch)) then
  ! If a lord
  if (ele%ix_branch == 0 .and. ele%ix_ele > ele%branch%n_ele_track) then
    state => ele%branch%lat%lord_state
  else
    state => ele%branch%param%bookkeeping_state
  endif
else
  nullify(state)
endif

!

select case (status_group)

case (attribute_group$)
  call set_attributes
  call set_mat6

case (control_group$)
  call set_control

case (floor_position_group$)
  call set_floor_position
  call set_mat6

case (s_position_group$)
  call set_s_position
  call set_floor_position
  call set_mat6

case (ref_energy_group$)
  call set_ref_energy
  call set_mat6
  call set_attributes ! EG: k1 <--> b1_gradient calc needed 

case (mat6_group$)
  call set_mat6

case (rad_int_group$)
  call set_rad_int

case (all_groups$)
  call set_attributes
  call set_control
  call set_ref_energy
  call set_floor_position
  call set_s_position
  call set_mat6
  call set_rad_int

case default
   if (global_com%exit_on_error) call err_exit   ! Should not be here

end select

! Set slave

if (logic_option(.true., set_slaves)) then
  do i = 1, ele%n_slave
    slave => pointer_to_slave (ele, i)
    call set_ele_status_stale (slave, status_group)
  enddo
endif

!----------------------------------------------------------------------------
contains

subroutine set_attributes
  if (ele%lord_status == overlay_lord$) return
  if (ele%lord_status == group_lord$) return
  ele%bookkeeping_state%attributes = stale$
  if (associated(state)) state%attributes = stale$
end subroutine set_attributes

!----------------------------------------------------------------------------
! contains

subroutine set_control
  if (ele%lord_status == not_a_lord$ .and. ele%slave_status == free$) return
  ele%bookkeeping_state%control = stale$
  if (associated(state)) state%control = stale$
end subroutine set_control

!----------------------------------------------------------------------------
! contains

subroutine set_floor_position
  if (ele%key == overlay$ .or. ele%key == group$) return
  ele%bookkeeping_state%floor_position = stale$
  if (associated(state)) state%floor_position = stale$
end subroutine set_floor_position

!----------------------------------------------------------------------------
! contains

subroutine set_s_position
  if (ele%key == overlay$ .or. ele%key == group$) return
  ele%bookkeeping_state%s_position = stale$
  if (associated(state)) state%s_position = stale$
end subroutine set_s_position

!----------------------------------------------------------------------------
! contains

subroutine set_ref_energy
  if (ele%key == overlay$ .or. ele%key == group$) return
  ele%bookkeeping_state%ref_energy = stale$
  if (associated(state)) state%ref_energy = stale$
end subroutine set_ref_energy

!----------------------------------------------------------------------------
! contains

subroutine set_rad_int
  if (ele%key == overlay$ .or. ele%key == group$) return
  ele%bookkeeping_state%rad_int = stale$
  if (associated(state)) state%rad_int = stale$
end subroutine set_rad_int

!----------------------------------------------------------------------------
! contains

! Ignore if the element does not have an associated linear transfer map
! Also the branch status does not get set since the transfer map calc
! must always check a branch due to possible reference orbit shifts.

subroutine set_mat6
  if (ele%lord_status == overlay_lord$) return
  if (ele%lord_status == group_lord$) return
  if (ele%lord_status == multipass_lord$) return
  ele%bookkeeping_state%mat6 = stale$
end subroutine set_mat6

end subroutine set_ele_status_stale 

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine set_lords_status_stale (ele, stat_group, flag)
!
! Routine to recursively set the status flag of all slaves of an element.
!
! Input:
!   ele        -- ele_struct: Element
!   stat_group -- Integer: which status group to set. floor_position_group$, etc.
!                   See set_ele_status_stale for more details.
!   flag       -- Logical, optional: Do not use. For determining recursion depth.
!
! Output:
!   ele%lat    -- Lat_struct: Lattice with status flags of lords of ele set.
!-

recursive subroutine set_lords_status_stale (ele, stat_group, flag)

implicit none

type (ele_struct) ele
type (ele_struct), pointer :: lord
integer stat_group, i
logical, optional :: flag

! First time through the flag argument will not be present.
! Do not set status first time through since this is the original element.
! That is, only want to set the flags of the lords.

if (present(flag)) call set_ele_status_stale (ele, stat_group, .false.)

do i = 1, ele%n_lord
  lord => pointer_to_lord (ele, i)
  call set_lords_status_stale (lord, stat_group, .true.)
enddo

end subroutine set_lords_status_stale

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_branch_given_name (branch_name, lat) result (branch_ptr)
!
! Function to point to the named lattice branch.
! This routine is overloaded by the routine: pointer_to_branch.
! See pointer_to_branch for more details.
! 
! Modules Needed:
!   use bmad_utils_mod
!
! Input:
!   branch_name -- Character(*): May be a branch name or a branch index.
!   lat         -- Lat_struct: Lattice to search.
!
! Output:
!   branch_ptr  -- branch_struct, pointer: Pointer to the nameed branch.
!                   Nullified if there is no such branch.
!-

function pointer_to_branch_given_name (branch_name, lat) result (branch_ptr)

implicit none

type (branch_struct), pointer :: branch_ptr
type (lat_struct), target :: lat

integer i, ib, ios
character(*) branch_name
character(32), parameter :: r_name = 'pointer_to_branch_given_name'

! Init in case of error

nullify(branch_ptr)

! Is index.

if (is_integer(trim(branch_name))) then
  read (branch_name, *, iostat = ios) ib
  if (ib < 0 .or. ib > ubound(lat%branch, 1)) then
    call out_io (s_error$, r_name, 'BRANCH INDEX OUT OF RANGE: ' // branch_name)
    return
  endif
  branch_ptr => lat%branch(ib)

! Is name.

else
  do i = lbound(lat%branch, 1), ubound(lat%branch, 1)
    if (lat%branch(i)%name == branch_name) then
      branch_ptr => lat%branch(ib)
      return
    endif
  enddo
  call out_io (s_error$, r_name, 'BRANCH NAME NOT FOUND: ' // branch_name)
  return
endif

end function pointer_to_branch_given_name

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_branch_given_ele (ele) result (branch_ptr)
!
! Function to point to the lattice branch associated with an element.
! This routine is overloaded by the routine: pointer_to_branch.
! See pointer_to_branch for more details.
!
! Note: Result is ambiguous if the element is associated with multiple branches which
! can happen, for example, with overlay lord elements.
!
! Modules Needed:
!   use bmad_utils_mod
!
! Input:
!   ele      -- Ele_struct: Element.
!
! Output:
!   branch_ptr  -- branch_struct, pointer: Pointer to the branch associated with the element.
!                   Nullified if the element is not associated with a lattice.
!-

recursive function pointer_to_branch_given_ele (ele) result (branch_ptr)

implicit none

type (ele_struct), target :: ele
type (branch_struct), pointer :: branch_ptr

! Now associated with a lattice case

if (.not. associated(ele%branch)) then
  nullify(branch_ptr)
  return
endif

! Not a lord case

if (ele%n_slave == 0) then
  branch_ptr => ele%branch
  return
endif

! If a lord then look to the first slave for the associated branch

branch_ptr => pointer_to_branch_given_ele(pointer_to_slave(ele, 1))

end function pointer_to_branch_given_ele

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine remove_lord_slave_link (lord, slave)
!
! Routine to remove the pointers between a lord and a slave.
! Note: This routine will not modify lord%lord_status and slave%slave_status.
!
! Input:
!   lord  -- ele_struct: Lord element
!   slave -- ele_struct: Slave element
!
! Output:
!   lord  -- ele_struct: Lord element with link info removed
!   slave -- ele_struct: Slave element with link info removed
!   lat   -- Lattice_struct: Lattice obtaind from lord%lat and slave%lat pointers.
!     %control(:)  -- Array modified to remove lord/slave link.
!     %ic(:)       -- Array modified to remove lord/slave link.
!-

subroutine remove_lord_slave_link (lord, slave)

implicit none

type (ele_struct), target :: lord, slave
type (ele_struct), pointer :: ele
type (lat_struct), pointer :: lat
type (branch_struct), pointer :: branch

integer ic_out, icon_out, ib, i, n

!

if (.not. associated(lord%branch, slave%branch)) call err_exit  ! Should not be

lat => lord%branch%lat

! Find lat%control(:) and lat%ic(:) elements associated with this link

do ic_out = slave%ic1_lord, slave%ic2_lord
  icon_out = lat%ic(ic_out)
  if (lat%control(icon_out)%ix_lord == lord%ix_ele) exit
enddo

if (icon_out == slave%ic2_lord + 1) call err_exit ! Should not be

! Compress lat%control and lat%ic arrays.

n = lat%n_control_max
lat%control(icon_out:n-1) = lat%control(icon_out+1:n)
lat%n_control_max = n - 1

n = lat%n_ic_max
lat%ic(ic_out:n-1) = lat%ic(ic_out+1:n)
lat%n_ic_max = n - 1

do i = 1, n - 1
  if (lat%ic(i) > icon_out) lat%ic(i) = lat%ic(i) - 1
enddo

! Correct info in all elements

do ib = 0, ubound(lat%branch, 1)
  branch => lat%branch(ib)

  do i = 1, branch%n_ele_max
    ele => branch%ele(i)

    if (ele%ix1_slave >  icon_out) ele%ix1_slave = ele%ix1_slave - 1
    if (ele%ix2_slave >= icon_out) ele%ix2_slave = ele%ix2_slave - 1

    if (ele%ic1_lord >  ic_out) ele%ic1_lord = ele%ic1_lord - 1
    if (ele%ic2_lord >= ic_out) ele%ic2_lord = ele%ic2_lord - 1
  enddo
enddo

slave%n_lord = slave%n_lord - 1
if (slave%n_lord == 0) then
  slave%ic1_lord = 0
  slave%ic2_lord = -1
  slave%slave_status = free$
endif

lord%n_slave = lord%n_slave - 1
if (lord%n_slave == 0) then
  lord%ix1_slave = 0
  lord%ix2_slave = -1
  lord%lord_status = not_a_lord$
endif

end subroutine remove_lord_slave_link 

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_slave (lord, ix_slave, ix_contrl) result (slave_ptr)
!
! Function to point to a slave of a lord.
! Also see:
!   pointer_to_lord
!   pointer_to_ele
!   pointer_to_field_ele
!
! Modules Needed:
!   use bmad_utils_mod
!
! Input:
!   lord     -- Ele_struct: Lord element
!   ix_slave -- Integer: Index of the slave. ix_slave goes from 1 to lord%n_slave
!
! Output:
!   slave_ptr  -- Ele_struct, pointer: Pointer to the slave.
!                   Nullified if there is an error.
!   ix_control -- Integer, optional :: index of appropriate lat%control(:) element.
!                   Set to -1 is there is an error.
!-

function pointer_to_slave (lord, ix_slave, ix_control) result (slave_ptr)

implicit none

type (ele_struct), target :: lord
type (ele_struct), pointer :: slave_ptr
type (control_struct), pointer :: con
type (lat_struct), pointer :: lat

integer, optional :: ix_control
integer ix_slave, icon

!

if (ix_slave > lord%n_slave .or. ix_slave < 1) then
  nullify(slave_ptr)
  if (present(ix_control)) ix_control = -1
  return
endif

lat => lord%branch%lat
icon = lord%ix1_slave + ix_slave - 1
con => lat%control(icon)
slave_ptr => lat%branch(con%ix_branch)%ele(con%ix_slave)
if (present(ix_control)) ix_control = icon

end function pointer_to_slave

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_lord (slave, ix_lord, ix_control, ix_slave) result (lord_ptr)
!
! Function to point to a lord of a slave.
! Also see:
!   pointer_to_slave
!   pointer_to_ele
!   pointer_to_field_ele
!
! Modules Needed:
!   use bmad_utils_mod
!
! Input:
!   slave      -- Ele_struct: Slave element.
!   ix_lord    -- Integer: Index of the lord. ix_lord goes from 1 to slave%n_lord
!
! Output:
!   lord_ptr   -- Ele_struct, pointer: Pointer to the lord.
!                   Nullified if there is an error.
!   ix_control -- Integer, optional: Index of appropriate lat%control(:) element.
!                   Set to -1 is there is an error or the slave is a slice_slave.
!   ix_slave   -- Integer, optional: Index of back to the slave. That is, 
!                   pointer_to_slave(lord_ptr, ix_slave) will point back to slave. 
!                   Set to -1 is there is an error or the slave is a slice_slave.
!-

function pointer_to_lord (slave, ix_lord, ix_control, ix_slave) result (lord_ptr)

implicit none

type (ele_struct), target :: slave
type (ele_struct), pointer :: lord_ptr
type (lat_struct), pointer :: lat

integer, optional :: ix_control, ix_slave
integer i, ix_lord, icon

character(*), parameter :: r_name = 'pointer_to_lord'

! Case where there is no lord

if (ix_lord > slave%n_lord .or. ix_lord < 1) then
  nullify(lord_ptr)
  if (present(ix_control)) ix_control = -1
  if (present(ix_slave)) ix_slave = -1
  return
endif

! slice_ele stores info differently

lat => slave%branch%lat

if (slave%slave_status == slice_slave$) then
  lord_ptr => slave%lord
  if (present(ix_control)) ix_control = -1
  if (present(ix_slave)) ix_slave = -1
  return
endif

! Point to the lord

icon = lat%ic(slave%ic1_lord + ix_lord - 1)
lord_ptr => lat%ele(lat%control(icon)%ix_lord)

if (present(ix_control)) ix_control = icon

! There must be a corresponding ix_slave value such that
!   pointer_to_slave(lord_ptr, ix_slave) => slave 

if (present(ix_slave)) then

  do i = 1, lord_ptr%n_slave
    if (associated (pointer_to_slave(lord_ptr, i), slave)) then
      ix_slave = i
      return
    endif
  enddo

  ! If ix_slave not found then this is an error

  call out_io (s_fatal$, r_name, 'CANNOT FIND SLAVE INDEX FOR LORD!')
  if (global_com%exit_on_error) call err_exit   

endif

end function pointer_to_lord

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function num_field_eles (ele_in) result (n_field_eles)
!
! Function to return the number of elements that have field information for
! the ele_in lattice_element.
!
! This routine is to be used in conjunction with pointer_to_field_ele.
!
! Modules Needed:
!   use bmad_utils_mod
!
! Input:
!   ele_in     -- Ele_struct: Lattice element.
!
! Output:
!   n_field_eles -- Integer: Number of elements that have field information.
!-

function num_field_eles (ele_in) result (n_field_eles)

implicit none

type (ele_struct) ele_in
integer n_field_eles

!

select case (ele_in%slave_status)

case (super_slave$, multipass_slave$)
  n_field_eles = ele_in%n_lord

case default
  n_field_eles = 1

end select


end function num_field_eles

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_field_ele (ele_in, ix_field) result (field_ele_ptr)
!
! Routine to return a pointer to an element that contains field information
! for the ele_in lattice element.
!
! An element, if it is a super_slave or multipass_slave, will have field information 
! stored in the lord elements.
! In this case, pointer_to_field_ele is identical to pointer_to_lord.
!
! If the element is not a super_slave or a multipass_slave, the element will 
! itself contain the field information.
! In this case pointer_to_field_ele (ele_in, 1) will return a pointer to itself.
!
! Note: Use the function num_field_eles(ele) to obtain the number of elements where
! field information is stored.
!
! Also see:
!   pointer_to_slave
!   pointer_to_ele
!   pointer_to_lord
!
! Modules Needed:
!   use bmad_utils_mod
!
! Input:
!   ele_in     -- Ele_struct: Lattice element.
!   ix_field   -- Integer: Index to select which of the field info elements to point to.
!                   ix_field should go from 1 to num_field_eles(ele).
!
! Output:
!   field_ele_ptr -- Ele_struct, pointer: Pointer to an element containing field information.
!                      Nullified if there is an error.
!-

function pointer_to_field_ele (ele_in, ix_field) result (field_ele_ptr)

implicit none

type (ele_struct), target :: ele_in
type (ele_struct), pointer :: field_ele_ptr
integer ix_field

!

select case (ele_in%slave_status)

case (super_slave$, multipass_slave$)
  field_ele_ptr => pointer_to_lord(ele_in, ix_field)

case default
  if (ix_field == 1) then
    field_ele_ptr => ele_in
  else
    nullify (field_ele_ptr)
  endif

end select

end function pointer_to_field_ele

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_next_ele (this_ele, offset, skip_beginning) result (next_ele)
!
! Function to return a pointer to the N^th element relative to this_ele
! in the array of elements in a lattice branch.
! Will wrap around. 
!
! Notice that the first eleemnt in a lattice is the beginning element.
!
! Input:
!   this_ele       -- ele_struct: Starting element.
!   offset         -- integer, optional: +1 -> return next element, +2 -> element 
!                       after that, etc. Can be negative. Default = +1.
!   skip_beginning -- logical, optional: If True then skip beginning element #0
!                       when wrapping around. Default is False.
!
!   next_ele -- ele_struct, pointer: Element after this_ele (if offset = 1).
!                Nullified if there is an error. EG bad this_ele.
!-

function pointer_to_next_ele (this_ele, offset, skip_beginning) result (next_ele)

implicit none

type (ele_struct), target :: this_ele
type (ele_struct), pointer :: next_ele
type (ele_struct), pointer :: an_ele
type (branch_struct), pointer :: branch

integer, optional :: offset
integer ix_ele, n_off
logical, optional :: skip_beginning
!

next_ele => null()

if (.not. associated(this_ele%branch)) return

branch => this_ele%branch
if (this_ele%ix_ele < 0 .or. this_ele%ix_ele > branch%n_ele_max) return

n_off = integer_option(+1, offset) 
if (n_off == 0) then
  next_ele => this_ele
  return
endif

if (this_ele%ix_ele > branch%n_ele_track) then
  if (this_ele%lord_status /= super_lord$) return
  if (n_off > 0) then
    an_ele => pointer_to_slave(this_ele, this_ele%n_slave)
  else
    an_ele => pointer_to_slave(this_ele, 1)
  endif
else
  an_ele => this_ele
endif

ix_ele = n_off + an_ele%ix_ele
if (ix_ele > branch%n_ele_track) then
  if (logic_option(.false., skip_beginning)) then
    next_ele => branch%ele(ix_ele - branch%n_ele_track)
  else
    next_ele => branch%ele(ix_ele - branch%n_ele_track - 1)
  endif
elseif (ix_ele == 0 .and. logic_option(.false., skip_beginning)) then
  next_ele => branch%ele(branch%n_ele_track)
elseif (ix_ele < 0) then
  next_ele => branch%ele(ix_ele + branch%n_ele_track + 1)
else
  next_ele => branch%ele(ix_ele)
endif

end function pointer_to_next_ele

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_ele1 (lat, ix_ele, ix_branch) result (ele_ptr)
!
! Function to return a pointer to an element in a lattice.
! This routine is overloaded by pointer_to_ele.
! See pointer_to_ele for more details.
!-

function pointer_to_ele1 (lat, ix_ele, ix_branch) result (ele_ptr)

implicit none

type (lat_struct), target :: lat
type (ele_struct), pointer :: ele_ptr

integer ix_branch, ix_ele

!

ele_ptr => null()

if (ix_branch < 0 .or. ix_branch > ubound(lat%branch, 1)) return
if (ix_ele < 0 .or. ix_ele > lat%branch(ix_branch)%n_ele_max) return

ele_ptr => lat%branch(ix_branch)%ele(ix_ele)

end function pointer_to_ele1

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function pointer_to_ele2 (lat, ele_loc) result (ele_ptr)
!
! Function to return a pointer to an element in a lattice.
! This routine is overloaded by pointer_to_ele.
! See pointer_to_ele for more details.
!-

function pointer_to_ele2 (lat, ele_loc) result (ele_ptr)

implicit none

type (lat_struct), target :: lat
type (ele_struct), pointer :: ele_ptr
type (lat_ele_loc_struct) ele_loc

!

ele_ptr => null()

if (ele_loc%ix_branch < 0 .or. ele_loc%ix_branch > ubound(lat%branch, 1)) return
if (ele_loc%ix_ele < 0 .or. ele_loc%ix_ele > lat%branch(ele_loc%ix_branch)%n_ele_max) return

ele_ptr => lat%branch(ele_loc%ix_branch)%ele(ele_loc%ix_ele)

end function pointer_to_ele2

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function ele_has_constant_ds_dt_ref (ele) result (is_const)
!
! Function to determine if an element has a constant longitudinal reference velocity.
! When in doubt, the assumption is that the longitudinal velocity is not constant.
!
! Module needed:
!   use bmad
!
! Input:
!   ele -- ele_struct: Element.
!
! Output:
!   is_const -- Logical: True if reference velocity must be a constant.
!-

function ele_has_constant_ds_dt_ref (ele) result (is_const)

implicit none

type (ele_struct) ele
logical is_const

! Anything with longitudinal electric fields or anything
! where the "zero-orbit" is not a straight line down the middle
! has a varying ds/dt(ref).

select case (ele%key)
case (lcavity$, custom$, hybrid$, wiggler$, rfcavity$, em_field$)
  is_const = .false.
case default
  is_const = .true.
end select

end function ele_has_constant_ds_dt_ref

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function tracking_uses_end_drifts (ele) result (has_drifts)
!
! Function to determine if the tracking for an element uses a "hard edge model"
! where the tracking looks like (drift, model, drift). For example,
! RF cavity fields with ele%field_calc = bmad_standard$ use a hard edge model where
! the length of the cavity is c_light / (2 * freq).
!
! Module needed:
!   use bmad
!
! Input:
!   ele    -- ele_struct: Element.
!
! Output:
!   has_drifts -- Logical: True if tracking uses end drifts.
!-

function tracking_uses_end_drifts (ele) result (has_drifts)

implicit none

type (ele_struct) ele
logical has_drifts

!

has_drifts = .false.
if (.not. bmad_com%use_hard_edge_drifts) return

select case (ele%key)
case (lcavity$, rfcavity$, solenoid$)
    if (ele%field_calc == bmad_standard$) has_drifts = .true.
end select

end function tracking_uses_end_drifts

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function element_has_fringe_fields (ele) result (has_fringe)
!
! Function to determine if the element has fringe fields that must be accounted
! for when tracking through the element. For example, a solenoid has edge fields.
! Note: If an element has end drifts (see tracking_uses_end_drifts function), 
! Then the fringe_fields will not be internal to the element and not at the ends.
!
! Module needed:
!   use bmad
!
! Input:
!   ele    -- ele_struct: Element.
!
! Output:
!   has_fringe -- Logical: True if the element has fringe fields.
!-

function element_has_fringe_fields (ele) result (has_fringe)

implicit none

type (ele_struct) ele
logical has_fringe
integer ix_fringe

!

has_fringe = .false.

select case (ele%key)
case (lcavity$, rfcavity$, solenoid$, sbend$, sol_quad$, bend_sol_quad$, e_gun$)
  if (ele%field_calc == bmad_standard$) has_fringe = .true.
case (quadrupole$)
  ix_fringe = nint(ele%value(fringe_type$))
  if (ele%field_calc == bmad_standard$ .and. &
     (ix_fringe == full_straight$ .or. ix_fringe == full_bend$)) has_fringe = .true.
end select

end function element_has_fringe_fields

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine calc_next_fringe_edge (track_ele, s_edge_track, hard_ele, s_edge_hard, hard_end)
!
! Routine to locate the next "hard edge" in an element when a hard edge model is being used. 
! This routine is used by integration tracking routines like Runge-Kutta.
! This routine is called repeatedly as the integration routine tracks through the element.
! If the element is a super_slave, there are potentially many hard edges.
!
! Rule: When track_ele is a super_slave, the edges of track_ele may be inside the field region.
! In this case, the hard edge is applied at the edges to make the particle look like it is
! outside the field. This is done to make the tracking symplectic from entrance edge to exit
! edge. [Remember that Bmad's coordinates are not canonical inside a field region.]
!
! Input:
!   track_ele     -- ele_struct: Element being tracked through.
!   hard_ele      -- ele_struct, pointer: Needs to be nullified at the start of tracking.
!
! Output:
!   s_edge_track -- Real(rp): S position of next hard edge in track_ele frame.
!                     If there are no more hard edges then s_pos will be set to ele%value(l$).
!   hard_ele     -- ele_struct, pointer: Points to element with the hard edge.
!                     Will be nullified if there is no hard edge.
!                     This will be track_ele unless track_ele is a super_slave.
!   s_edge_hard  -- Real(rp): S-position of next hard egde in hard_ele frame.
!   hard_end     -- Integer: Describes hard edge. Set to upstream_end$ or downstream_end$.
!-

subroutine calc_next_fringe_edge (track_ele, s_edge_track, hard_ele, s_edge_hard, hard_end)

implicit none

type (ele_struct), target :: track_ele
type (ele_struct), pointer :: hard_ele, lord

real(rp) s_edge_track, s_edge_hard
integer hard_end
integer i

! Init if needed.
! Keep track of things by setting: 
!   ele%ixx = 0  ! Init setting
!   ele%ixx = 1  ! About to track through entrance hard edge
!   ele%ixx = 2  ! About to track through exit hard edge

if (.not. associated(hard_ele)) then
  if (track_ele%slave_status == super_slave$ .or. track_ele%slave_status == slice_slave$) then
    do i = 1, track_ele%n_lord
      lord => pointer_to_lord(track_ele, i)
      lord%ixx = 0
    enddo
  else
    track_ele%ixx = 0
  endif
endif

! Find next hard edge

s_edge_track = track_ele%value(l$)
nullify (hard_ele)

if (track_ele%slave_status == super_slave$ .or. track_ele%slave_status == slice_slave$) then
  do i = 1, track_ele%n_lord
    if (lord%key == overlay$ .or. lord%key == group$) cycle
    lord => pointer_to_lord(track_ele, i)
    call does_this_ele_contain_the_next_edge (lord)
  enddo
else
  call does_this_ele_contain_the_next_edge (track_ele)
endif

if (associated (hard_ele)) hard_ele%ixx = hard_ele%ixx + 1

!-------------------------------------------------------------------------
contains 

subroutine does_this_ele_contain_the_next_edge (this_ele)

type (ele_struct), target :: this_ele
real(rp) s_this_edge, s_hard_entrance, s_hard_exit, s_off
integer this_end, dir

!

if (.not. element_has_fringe_fields (this_ele)) return
if (this_ele%ixx == 2) return

dir = 1
if (track_ele%value(l$) < 0) dir = -1

s_off = (this_ele%s - this_ele%value(l$)) - (track_ele%s - track_ele%value(l$))
s_hard_entrance = s_off + (this_ele%value(l$) - hard_edge_model_length(this_ele)) / 2 
s_hard_exit     = s_off + (this_ele%value(l$) + hard_edge_model_length(this_ele)) / 2 

if (dir * s_hard_entrance < -dir * bmad_com%significant_length .and. &
    dir * s_hard_exit     < -dir * bmad_com%significant_length) return

if (dir * s_hard_entrance > dir * (track_ele%value(l$) + bmad_com%significant_length) .and. &
    dir * s_hard_exit     > dir * (track_ele%value(l$) + bmad_com%significant_length)) return

if (this_ele%ixx == 0) then
  this_end = upstream_end$
  s_this_edge = max(0.0_rp, s_hard_entrance)

else   ! this_ele%ixx = 1
  this_end = downstream_end$
  s_this_edge = min(track_ele%value(l$), s_hard_exit)
endif

if (dir * s_this_edge > dir * s_edge_track) return

! This looks like the next hard edge

hard_ele => this_ele
hard_end = this_end
s_edge_track = s_this_edge
s_edge_hard = s_edge_track - s_off

end subroutine does_this_ele_contain_the_next_edge

end subroutine calc_next_fringe_edge

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Subroutine create_hard_edge_drift (ele_in, which_end, drift_ele)
!
! Routine to create the drift element for the end drifts of an element.
! The end drifts are present, for example, when doing runge_kutta tracking
! through an rf_cavity with field_calc = bmad_standard. In this case, the
! field model is a pi-wave hard-edge resonator whose length may not match
! the length of the element and so particles must be drifted from the edge
! of the element to the edge of the field model.
!
! Input:
!   ele_in     -- ele_struct: Input element.
!   which_end  -- Integer: Which end is being created. upstream_end$ or downstream_end$.
!                   For an Lcavity one can have differences in reference energy.
!
! Output:
!   drift_ele  -- ele_struct: drift elment.
!-

subroutine create_hard_edge_drift (ele_in, which_end, drift_ele)

implicit none

type (ele_struct) ele_in, drift_ele
real(rp) E_tot, p0c
integer which_end

!

select case (which_end)
case (upstream_end$)
  e_tot = ele_in%value(e_tot_start$)
  p0c   = ele_in%value(p0c_start$)
  drift_ele%name                   = 'drift1_' // ele_in%name(1:33)
case (downstream_end$)
  e_tot = ele_in%value(e_tot$)
  p0c   = ele_in%value(p0c$)
  drift_ele%name                   = 'drift2_' // ele_in%name(1:33)
case default
  if (global_com%exit_on_error) call err_exit
end select

drift_ele%key                    = drift$

drift_ele%value                  = 0
drift_ele%value(p0c$)            = p0c
drift_ele%value(e_tot$)          = e_tot
drift_ele%value(p0c_start$)      = p0c
drift_ele%value(e_tot_start$)    = e_tot
drift_ele%value(l$)              = (ele_in%value(l$) - hard_edge_model_length(ele_in)) / 2 
drift_ele%value(ds_step$)        = drift_ele%value(l$)
drift_ele%value(num_steps$)      = 1
drift_ele%value(delta_ref_time$) = drift_ele%value(l$) * e_tot / (c_light * p0c)
drift_ele%orientation            = ele_in%orientation

end subroutine create_hard_edge_drift 

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function hard_edge_model_length (ele) result (l_hard)
!
! Input:
!   ele -- ele_struct: Element
!
! Output:
!   l_hard -- real(rp): Length of the hard edge model.
!-

function hard_edge_model_length (ele) result (l_hard)

implicit none

type (ele_struct) ele
real(rp) l_hard

!

if (bmad_com%use_hard_edge_drifts) then
  l_hard = ele%value(l_hard_edge$)
else
  l_hard = ele%value(l$)
endif

end function hard_edge_model_length

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function absolute_time_tracking (ele) result (is_abs_time)
!
! Routine to return a logical indicating whether the tracking through an
! element should use absolute time or time relative to the reference particle.
!
! Note: e_gun elements always use aboslute time tracking to get around
! the problem when the particle velocity is zero.
!
! Input:
!   ele  -- ele_struct: Element being tracked through.
!
! Output:
!   is_abs_time -- Logical: True if absolute time tracking is needed.
!-

function absolute_time_tracking (ele) result (is_abs_time)

type (ele_struct), target :: ele
type (ele_struct), pointer :: lord
logical is_abs_time
integer i

!

is_abs_time = bmad_com%absolute_time_tracking_default
if (associated(ele%branch)) is_abs_time = ele%branch%lat%absolute_time_tracking
if (ele%key == e_gun$) is_abs_time = .true.

if (ele%key == em_field$ .and. ele%slave_status == super_slave$) then
  do i = 1, ele%n_lord
    lord => pointer_to_lord(ele, i)
    if (lord%key == e_gun$) is_abs_time = .true.
  enddo
endif

end function absolute_time_tracking

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function particle_time (orbit, ele) result (time)
!
! Routine to return the current time for use, for example, 
! in calculations of time-dependent EM fields.
!
! The oscillations of such fields are synched relative to the absolute clock if 
! absolute time tracking is used or are synched relative to the reference particle
! if relative time tracking is used.
!
! Input:
!   orbit -- Coord_struct: Particle coordinates
!   ele   -- ele_struct: Element being tracked through.
!
! Ouput:
!   time  -- Real(rp): Current time.
!-

function particle_time (orbit, ele) result (time)

implicit none

type (coord_struct) orbit
type (ele_struct) ele

real(rp) time
logical abs_time
character(16), parameter :: r_name = 'particle_time'

! Note: e_gun uses absolute time tracking to get around the problem when orbit%beta = 0.

if (absolute_time_tracking(ele)) then
  time = orbit%t 

else
  if (orbit%beta == 0) then
    call out_io (s_fatal$, r_name, 'PARTICLE IN NON E-GUN ELEMENT HAS VELOCITY = 0!')
    if (global_com%exit_on_error) call err_exit
    time = orbit%t  ! Just to keep on going
    return
  endif
  time = -orbit%vec(5) / (orbit%beta * c_light)
endif

end function particle_time

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function rf_ref_time_offset (ele) result (time)
!
! Routine to return an offset time due to the offset distance for super_slave and 
! slice_slave elemenets. This is used for calculating the RF phase
! in RF cavities. 
!
! This is only non-zer with absolute time tracking since relative time, which 
! references the time to the reference particle,  already takes this into account.
! 
! Input:
!   ele      -- ele_struct: RF Element being tracked through.
!
! Ouput:
!   time  -- Real(rp): Offset time.
!-

function rf_ref_time_offset (ele) result (time)

implicit none

type (coord_struct) orbit
type (ele_struct) ele
type (ele_struct), pointer :: lord
real(rp) time
character(*), parameter :: r_name = 'rf_ref_time_offset'

! 

time = 0
if (.not. absolute_time_tracking(ele)) return

if (ele%slave_status == super_slave$ .or. ele%slave_status == slice_slave$) then
  lord => pointer_to_lord (ele, 1)
  time = ele%value(ref_time_start$) - lord%value(ref_time_start$)
endif

end function rf_ref_time_offset

!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!---------------------------------------------------------------------------
!+
! Function rf_is_on (branch) result (is_on)
!
! Routine to check if any rfcavity is powered in a branch.
!
! Input:
!   branch -- branch_struct: Lattice branch to check.
!
! Output:
!   is_on  -- Logical: True if any rfcavity is powered. False otherwise.
!-

function rf_is_on (branch) result (is_on)

type (branch_struct), target :: branch
type (ele_struct), pointer :: ele

integer i
logical is_on

!

is_on = .false.

do i = 1, branch%n_ele_track
  ele => branch%ele(i)
  if (ele%key == rfcavity$ .and. ele%is_on .and. ele%value(voltage$) /= 0) then
    is_on = .true.
    return
  endif
enddo

end function rf_is_on

end module
