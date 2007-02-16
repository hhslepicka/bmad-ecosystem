!+
! Subroutine tao_x_axis_cmd (where, what)
!
! Routine to axis a plot. If x_min = x_max
! Then the axiss will be chosen to show all the data.
! 
! Input:
!   where -- Character(*): Region to axis. Eg: "top"
!   what  -- Character(*): "s" or "index"
!-

subroutine tao_x_axis_cmd (where, what)

use tao_mod
use quick_plot

implicit none

type (tao_plot_array_struct), allocatable, save :: plot(:)

integer i, j

character(*) where, what
character(16) :: r_name = 'tao_x_axis_cmd'

logical err

! check what

if (what /= "s" .and. what /= "index" .and. what /= "ele_index") then
  call out_io (s_error$, r_name, 'I DO NOT UNDERSTAND THIS: ' // what)
  return
endif

! If the where argument is blank then axis all graphs

if (len_trim(where) == 0 .or. where == 'all') then
  do j = 1, size(s%plot_page%region)
    if (.not. s%plot_page%region(j)%visible) cycle
    call set_axis (s%plot_page%region(j)%plot)
  enddo
  return
endif

! locate the plot by the region name given by the where argument.

call tao_find_plots (err, where, 'REGION', plot)
if (err) return
do i = 1, size(plot)
  call set_axis (plot(i)%p)
enddo

!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
contains

subroutine set_axis (plot)

type (tao_plot_struct) plot
type (tao_d1_data_struct), pointer :: d1_ptr
integer iu, n, p1, p2, ig, ic
real(rp) minn, maxx

!

plot%x_axis_type = what
iu = s%global%u_view

if (what == 's') then
  minn = s%u(iu)%model%lat%ele(0)%s
  n = s%u(iu)%model%lat%n_ele_track
  maxx = s%u(iu)%model%lat%param%total_length

elseif (what == 'ele_index') then
  minn = 0
  maxx = s%u(s%global%u_view)%model%lat%n_ele_track 

elseif (what == 'index') then
  plot%x%min = -1e30; plot%x%max = 1e30
  do ig = 1, size(plot%graph)
    call tao_graph_data_setup(plot, plot%graph(ig))
  enddo
  minn = 1e30; maxx = -1e30
  do ig = 1, size(plot%graph)
    plot%graph(ig)%valid = .false.
    if (allocated(plot%graph(ig)%curve)) then
      plot%graph(ig)%valid = .true.
      do ic = 1, size(plot%graph(ig)%curve)
        minn = min(minn, plot%graph(ig)%curve(ic)%x_symb(1))
        n = size(plot%graph(ig)%curve(ic)%x_symb)
        maxx = max(maxx, plot%graph(ig)%curve(ic)%x_symb(n))
      enddo
    endif
  enddo
  if (all(.not. plot%graph%valid)) return
endif

!

p1 = nint(0.7 * plot%x_divisions)  ! Used to be 8
p2 = nint(1.3 * plot%x_divisions)  ! Used to be 15
call qp_calc_axis_params (minn, maxx, p1, p2, plot%x)

end subroutine

end subroutine 






