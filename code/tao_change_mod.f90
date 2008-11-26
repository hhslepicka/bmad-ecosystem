module tao_change_mod

use tao_mod
use tao_evaluate_mod
use quick_plot

contains

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine tao_change_var (name, num_str, silent)
!
! Routine to change a variable in the model lattice.
!
! Input:
!   name     -- Character(*): Name of variable or element.
!   num_str  -- Character(*): Change in value. 
!                                A '@' signifies a absolute set.
!                                A 'd' signifies a set relative design.        
!   silent   -- Logical: If True then do not print any info.
!
! Output:
!    %u(s%global%u_view)%model -- model lattice where the variable lives.
!-

subroutine tao_change_var (name, num_str, silent)

implicit none

type (tao_universe_struct), pointer :: u
type (tao_var_array_struct), allocatable, save :: v_array(:)
type (tao_var_struct), pointer :: var

real(rp), allocatable :: change_number(:)
real(rp) model_value, old_merit, new_merit, max_val
real(rp) old_value, new_value, design_value, delta

integer nl, i, ixa, ix, err_num, n

character(*) name, num_str
character(20) :: r_name = 'tao_change_var'
character(20) abs_or_rel, component
character(100) l1, num, fmt
character(200), allocatable, save :: lines(:)

logical err, exists, silent

!-------------------------------------------------

call tao_find_var (err, name, v_array = v_array, component = component)
if (err) return
if (.not. allocated(v_array)) then
  call out_io (s_error$, r_name, 'BAD VARIABLE NAME: ' // name)
  return
endif
if (component /= "" .and. component /= "model") then
  call out_io (s_error$, r_name, &
            '"change var" ONLY MODIFIES THE "model" COMPONENT.', &
            'USE "set var" INSTEAD.')
  return
endif

! find change value(s)

call to_number (num_str, size(v_array), change_number, abs_or_rel, err);  if (err) return
old_merit = tao_merit()

! We need at least one variable to exist.

exists = .false.
do i = 1, size(v_array)
  if (v_array(i)%v%exists) exists = .true.
enddo

if (.not. exists) then
  call out_io (s_error$, r_name, 'VARIABLE DOES NOT EXIST')
  return
endif

! now change all desired variables

max_val = 0
do i = 1, size(v_array)
  var => v_array(i)%v
  if (.not. var%exists) cycle
  var%old_value = var%model_value
  if (abs_or_rel == '@') then
    call tao_set_var_model_value (var, change_number(i))
  elseif (abs_or_rel == 'd') then
    call tao_set_var_model_value (var, var%design_value + change_number(i))
  elseif (abs_or_rel == '%') then
    call tao_set_var_model_value (var, var%model_value * (1 + 0.01 * change_number(i)))
  else
    call tao_set_var_model_value (var, var%model_value + change_number(i))
  endif
  max_val = max(max_val, abs(var%old_value))
  max_val = max(max_val, abs(var%design_value)) 
  max_val = max(max_val, abs(var%model_value)) 
enddo

! print results

new_merit = tao_merit()

if (max_val > 100) then
  fmt = '(5x, I5, 2x, f12.0, a, 4f12.0)'
else
  fmt = '(5x, I5, 2x, f12.6, a, 4f12.6)'
endif

call re_allocate (lines, 200, 200)
nl = 0
l1 = '     Index     Old_Model       New_Model       Delta  Old-Design  New-Design'
nl=nl+1; lines(nl) = l1

n = size(v_array)
call re_allocate (lines, len(lines(1)), n+100)

do i = 1, size(v_array)
  var => v_array(i)%v
  if (.not. var%exists) cycle
  delta = var%model_value - var%old_value
  nl=nl+1; write (lines(nl), fmt) i, var%old_value, '  ->', &
       var%model_value, delta, var%old_value - var%design_value, &
	     var%model_value - var%design_value
enddo
nl=nl+1; lines(nl) = l1

if (max(abs(old_merit), abs(new_merit)) > 100) then
  fmt = '(5x, 2(a, es15.6), es15.6)'
else
  fmt = '(5x, 2(a, f13.6), f13.6)'
endif

nl=nl+1; lines(nl) = ' '
nl=nl+1; write (lines(nl), fmt) 'Merit:      ', old_merit, '  ->', new_merit
nl=nl+1; write (lines(nl), fmt) 'dMerit:     ', new_merit-old_merit
if (delta /= 0) then
  nl=nl+1; write (lines(nl), '(5x, a, es11.3)') 'dMerit/dVar:', &
                                     (new_merit-old_merit) / delta
endif

if (.not. silent) call out_io (s_blank$, r_name, lines(1:nl))

end subroutine

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
!+
! Subroutine tao_change_ele (ele_name, attrib_name, num_str)
!
! Routine to change a variable in the model lattice.
!
! Input:
!   ele_name    -- Character(*): Name of variable or element.
!   attrib_name -- Character(*): Attribute name of element.
!   num_str     -- Character(*): Change in value. 
!                                A '@' signifies a absolute set.
!                                A 'd' signifies a set relative design.        
!
! Output:
!    %u(s%global%u_view)%model -- model lattice where the variable lives.
!-

subroutine tao_change_ele (ele_name, attrib_name, num_str)

use tao_mod
use quick_plot

implicit none

type (tao_universe_struct), pointer :: u
type (real_array_struct), allocatable, save :: d_ptr(:), m_ptr(:)

real(rp), allocatable, save :: change_number(:), old_value(:)

real(rp) new_merit, old_merit, new_value, delta

integer i, ix, ix_a, nl, len_name
integer, allocatable, save :: ix_ele(:)
integer, parameter :: len_lines = 200

character(*) ele_name
character(*) attrib_name
character(*) num_str
character(40) e_name, a_name, fmt, name
character(20) :: r_name = 'tao_change_ele'
character(len_lines), allocatable, save :: lines(:)
character(20) abs_or_rel

logical err
logical, allocatable, save :: good(:)

!-------------------------------------------------

if (tao_com%common_lattice) then
  u => s%u(ix_common_uni$)
else
  u => tao_pointer_to_universe(-1)
endif

! 

call string_trim (ele_name, e_name, ix)
call string_trim (attrib_name, a_name, ix)
call str_upcase (e_name, e_name)
call str_upcase (a_name, a_name)

call pointers_to_attribute (u%design%lat, e_name, a_name, .true., &
                                                d_ptr, err, .true., ix_ele, ix_a)
if (err) return

call pointers_to_attribute (u%model%lat, e_name, a_name, .true., &
                                                m_ptr, err, .true., ix_ele, ix_a)
if (err) return

! Count to see if any of the attributes are free

call re_allocate (old_value, size(d_ptr))
call re_allocate (good, size(d_ptr))

good = .false.
do i = 1, size(d_ptr)
  if (ix_ele(i) > -1) then  ! bunch_start variables are always free
    if (.not. attribute_free (ix_ele(i), ix_a, u%model%lat, .false.)) cycle
  endif
  good(i) = .true.
end do

if (all (.not. good)) then
  call out_io (s_error$, r_name, 'ATTRIBUTE NOT FREE TO VARY. NOTHING DONE')
  return
endif

! Find change value(s)

call to_number (num_str, size(d_ptr), change_number, abs_or_rel, err);  if (err) return
old_merit = tao_merit()
call re_allocate (old_value, size(d_ptr))

! put in change

fmt = '(5f14.6, 4x, a)'

do i = 1, size(d_ptr)

  if (.not. good(i)) cycle

  old_value(i) = m_ptr(i)%r

  if (abs_or_rel == '@') then
    m_ptr(i)%r = change_number(i)
  elseif (abs_or_rel == 'd') then
    m_ptr(i)%r = d_ptr(i)%r + change_number(i)
  elseif (abs_or_rel == '%') then
    m_ptr(i)%r = m_ptr(i)%r * (1 + 0.01 * change_number(i))
  else
    m_ptr(i)%r = m_ptr(i)%r + change_number(i)
  endif
     
  call changed_attribute_bookkeeper (u%model%lat, ix_ele(i), m_ptr(i)%r)

  if (max(abs(old_value(i)), abs(m_ptr(i)%r), abs(d_ptr(1)%r)) > 100) &
                                                          fmt = '(5f14.0, 4x, a)'

enddo

tao_com%lattice_recalc = .true.

!----------------------------------
! print results

new_merit = tao_merit()

call re_allocate (lines, len_lines, size(d_ptr)+10)
nl = 0
nl=nl+1;write (lines(nl), '(11x, a)') &
                  'Old           New    Old-Design    New-Design         Delta'
do i = 1, size(d_ptr)
  if (.not. good(i)) cycle
  if (nl > 10 .and. i /= size(d_ptr)) exit  
  name = 'BEAM_START'
  if (ix_ele(i) > -1) name = u%design%lat%ele(ix_ele(i))%name
  nl=nl+1; write (lines(nl), fmt) old_value(i), m_ptr(i)%r, &
                            old_value(i)-d_ptr(i)%r, m_ptr(i)%r-d_ptr(i)%r, &
                            m_ptr(i)%r-old_value(i), trim(name)
enddo

if (i <= size(d_ptr)) then
  nl=nl+1; lines(nl) = '   ... etc ...'
endif

if (max(abs(old_merit), abs(new_merit)) > 100) then
  fmt = '(2(a, f13.2), a, f13.2)'
else
  fmt = '(2(a, f13.6), a, f13.6)'
endif

nl=nl+1;write (lines(nl), fmt) 'Merit:      ', &
                        old_merit, '  ->', new_merit, '  Delta: ', new_merit-old_merit
if (delta /= 0) then
  nl=nl+1
  write (lines(nl), '(a, es12.3)') 'dMerit/dValue:  ', (new_merit-old_merit) / delta
endif

call out_io (s_blank$, r_name, lines(1:nl))

end subroutine tao_change_ele

!----------------------------------------------------------------------------
!----------------------------------------------------------------------------
!----------------------------------------------------------------------------

subroutine to_number (num_str, n_size, change_number, abs_or_rel, err)

implicit none

real(rp), allocatable :: change_number(:)
logical, allocatable, save :: good(:)
integer ix, ios, n_size

character(*) num_str
character(*) abs_or_rel
character(len(num_str)) number_str
character(20) :: r_name = 'to_number'

logical err

!

call string_trim(num_str, number_str, ix)
abs_or_rel = ' ' 

select case (number_str(1:1))
case ('@', 'd', '%')
  abs_or_rel = number_str(1:1)
  number_str(1:1) = ' '
end select

call tao_to_real_vector (number_str, 'BOTH', n_size, .false., change_number, good, err)

end subroutine

end module
