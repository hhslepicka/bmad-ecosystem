module tao_plot_mod

use tao_mod
use quick_plot
use tao_plot_window_mod

contains

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine tao_draw_plots (do_clear)
!
! Subroutine to draw the plots on the plot window.
!
! Input:
!   do_clear -- Logical, optional: If present and False then call qp_clear_page.
!                 This argument is used when drawing PS or GIF.
!-

subroutine tao_draw_plots (do_clear)

implicit none

type (tao_plot_struct), pointer :: plot
type (tao_graph_struct), pointer :: graph
type (tao_curve_struct), pointer :: curve
type (qp_rect_struct) border1, border2
type (tao_data_array_struct), allocatable, save :: d_array(:)

real(rp) location(4), dx, dy, h

integer i, j, k, ic, id

character(80) text
character(16) :: r_name = 'tao_draw_plots'
character(3) view_str

logical, optional :: do_clear
logical found, err, beam_source

! inits

if (.not. s%global%plot_on) return
call tao_create_plot_window () ! This routine knows not to create multiple windows.
if (logic_option(.true., do_clear)) call qp_clear_page

h = s%plotting%text_height
call qp_set_text_attrib ('TEXT', height = h)
call qp_set_text_attrib ('MAIN_TITLE', height = h * s%plotting%main_title_text_scale)
call qp_set_text_attrib ('GRAPH_TITLE', height = h * s%plotting%graph_title_text_scale)
call qp_set_text_attrib ('LEGEND', height = h * s%plotting%legend_text_scale)
call qp_set_text_attrib ('AXIS_NUMBERS', height = h * s%plotting%axis_number_text_scale)
call qp_set_text_attrib ('AXIS_LABEL', height = h * s%plotting%axis_label_text_scale)

! print the title 

h = s%plotting%text_height * s%plotting%main_title_text_scale
do i = 1, size(s%plotting%title)
  if (s%plotting%title(i)%draw_it)                                         &
    call qp_draw_text (s%plotting%title(i)%string, s%plotting%title(i)%x, &
                     s%plotting%title(i)%y, s%plotting%title(i)%units,    &
                     s%plotting%title(i)%justify, height = h)
enddo

! Draw view universe

if (size(s%u) > 1) then
  write (view_str, '(i3)') s%global%u_view
  call qp_draw_text ('View Universe:' // view_str, -2.0_rp, -2.0_rp, 'POINTS/PAGE/RT', 'RT')
endif

! loop over all plots

do i = 1, size(s%plotting%region)

  if (.not. s%plotting%region(i)%visible) cycle
  plot => s%plotting%region(i)%plot

  ! set the s%plot_page border for this particular region

  location = s%plotting%region(i)%location
  border1%units = '%PAGE'
  call qp_convert_rectangle_rel (s%plotting%border, border1)
  dx = 1 - (border1%x2 - border1%x1)
  dy = 1 - (border1%y2 - border1%y1)
  border2%x1 = border1%x1 + dx * location(1)
  border2%x2 = border1%x2 + dx * (1 - location(2))
  border2%y1 = border1%y1 + dy * location(3)
  border2%y2 = border1%y2 + dy * (1 - location(4))
  border2%units = '%PAGE'
  call qp_set_layout (page_border = border2)

  ! loop over all the graphs of the plot and draw them.

  g_loop: do j = 1, size(plot%graph)

    graph => plot%graph(j)
    if (.not. graph%visible) cycle

    ! For a non-valid graph just print a message

    if (.not. graph%valid) then
      call qp_set_layout (box = graph%box)
      text = 'Error In The Plot Calculation'
      if (graph%why_invalid /= '') text = graph%why_invalid
      call qp_draw_text (text, 0.5_rp, 0.5_rp, '%BOX', color = red$, justify = 'CC')
    endif

    ! Now we can draw the graph

    call tao_hook_draw_graph (plot, graph, found)
    if (found) cycle

    select case (graph%type)
    case ('data', 'phase_space')
      call tao_plot_data (plot, graph)
    case ('wave.0', 'wave.a', 'wave.b')
      call tao_plot_wave (plot, graph)
     case ('lat_layout')
      call tao_draw_lat_layout (plot, graph)
    case ('key_table')
      call tao_plot_key_table (plot, graph)
    case ('floor_plan')
      call tao_draw_floor_plan (plot, graph)
    case ('histogram')
      call tao_plot_histogram (plot, graph)
    case default
      call out_io (s_fatal$, r_name, 'UNKNOWN GRAPH TYPE: ' // graph%type)
    end select

    ! Draw a rectangle so the box and graph boundries can be seen.

    if (s%global%box_plots) then
      call qp_draw_rectangle (0.0_rp, 1.0_rp, 0.0_rp, 1.0_rp, '%GRAPH/LB')
      call qp_draw_rectangle (0.0_rp, 1.0_rp, 0.0_rp, 1.0_rp, '%BOX/LB')
    endif

  enddo g_loop

enddo

end subroutine

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine tao_plot_histogram (plot, graph)
!
! Routine to draw one graph for the histogram analysis plot.
!
! Input:
!   plot  -- Tao_plot_struct: Plot containing the graph.
!   graph -- Tao_graph_struct: Graph to plot.
!-

subroutine tao_plot_histogram (plot, graph)

type (tao_plot_struct) :: plot
type (tao_graph_struct), target :: graph

integer k
logical have_data

! Draw the graph outline.

call tao_draw_data_graph (plot, graph)
if (.not. graph%valid) return

! loop over all the curves of the graph and draw them

have_data = .false.

do k = 1, size(graph%curve)
  call tao_draw_histogram_data (plot, graph, graph%curve(k), have_data)
enddo

if (.not. have_data) call qp_draw_text ('**No Plottable Data**', &
                            0.18_rp, -0.15_rp, '%/GRAPH/LT', color = red$) 

end subroutine tao_plot_histogram

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine tao_plot_wave (plot, graph)
!
! Routine to draw one graph for the wave analysis plot.
!
! Input:
!   plot  -- Tao_plot_struct: Plot containing the graph.
!   graph -- Tao_graph_struct: Graph to plot.
!-

subroutine tao_plot_wave (plot, graph)

type (tao_plot_struct) :: plot
type (tao_graph_struct), target :: graph
type (qp_axis_struct), pointer :: y

real(rp) y0, y1

! Draw the data

call tao_plot_data (plot, graph)

! Now draw the rectangles of the fit regions.

y => graph%y
y0 = y%min + 0.1 * (y%max - y%min)
y1 = y%max - 0.1 * (y%max - y%min)

if (graph%type == 'wave.0' .or. graph%type == 'wave.a') then
  call qp_draw_rectangle (1.0_rp * s%wave%ix_a1, 1.0_rp * s%wave%ix_a2, y0, y1, color = blue$, width = 2)
endif

if (graph%type == 'wave.0' .or. graph%type == 'wave.b') then
  call qp_draw_rectangle (1.0_rp * s%wave%ix_b1, 1.0_rp * s%wave%ix_b2, y0, y1, color = blue$, width = 2)
endif

end subroutine

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine tao_plot_key_table (plot, graph)
!
! Routine to draw a key table graph.
!
! Input:
!   plot  -- Tao_plot_struct: Plot containing the graph.
!   graph -- Tao_graph_struct: Graph to plot.
!-


subroutine tao_plot_key_table (plot, graph)

implicit none

type (tao_plot_struct) :: plot
type (tao_graph_struct) :: graph
type (tao_var_struct), pointer :: var

integer i, j, k, ix_var, i_off
real(rp) :: y_here, x1, x2, y1, y2
real(rp) :: height

character(120) str, header
character(7) prefix
character(24) :: r_name = 'tao_plot_key_table'

!

call qp_set_layout (box = graph%box, margin = graph%margin)

call qp_get_layout_attrib ('GRAPH', x1, x2, y1, y2, 'POINTS/GRAPH')
y_here = y2  ! start from the top of the graph
height = s%plotting%text_height * s%plotting%key_table_text_scale


i_off = tao_com%ix_key_bank
call tao_key_info_to_str (1, i_off+1, i_off+10, str, header)
call qp_draw_text ('   Ix  ' // header, 0.0_rp, y_here, 'POINTS/GRAPH', &
                             height = height, uniform_spacing = .true.)
  

do i = 1, 10

  k = i + i_off
  if (k > ubound(s%key, 1)) return

  prefix = ''
  j = mod(i, 10)
  if (i == 1) then
    write (prefix, '(i2, a, i2)') tao_com%ix_key_bank, ':', j
  else
    write (prefix(4:), '(i2)') j
  endif

  ix_var = s%key(k)

  call tao_key_info_to_str (i+i_off, i_off+1, i_off+10, str, header)

  y_here = y_here - 1.1 * height
  call qp_draw_text (prefix // str, 0.0_rp, y_here, 'POINTS/GRAPH', &
                          height = height, uniform_spacing = .true.)

enddo

end subroutine tao_plot_key_table

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine tao_draw_floor_plan (plot, graph)
!
! Routine to draw a floor plan graph.
!
! Input:
!   plot  -- Tao_plot_struct: Plot containing the graph.
!   graph -- Tao_graph_struct: Graph to plot.
!-

subroutine tao_draw_floor_plan (plot, graph)

implicit none

type (tao_plot_struct) :: plot
type (tao_graph_struct) :: graph
type (lat_struct), pointer :: lat
type (tao_ele_shape_struct), pointer :: ele_shape
type (tao_lattice_branch_struct), pointer :: lat_branch
type (floor_position_struct) end1, end2, floor
type (tao_building_wall_point_struct), pointer :: pt(:)
type (ele_struct), pointer :: ele
type (branch_struct), pointer :: branch
type (tao_data_struct), pointer :: datum
type (tao_data_array_struct), allocatable, target :: d_array(:)
type (tao_var_array_struct), allocatable, target :: v_array(:)
type (tao_logical_array_struct), allocatable :: logic_array(:)
type (tao_var_struct), pointer :: var

real(rp) theta, v_vec(3), theta1, dtheta
real(rp) x_bend(0:1000), y_bend(0:1000)

integer i, j, k, n, n_bend, isu, ic, ib, icol

character(20) :: r_name = 'tao_draw_floor_plan'

logical err

! Each graph is a separate floor plan plot (presumably for different universes). 
! setup the placement of the graph on the plot page.

call qp_set_layout (x_axis = graph%x, y_axis = graph%y, y2_axis = graph%y2, &
                                        box = graph%box, margin = graph%margin)


if (graph%correct_xy_distortion) call qp_eliminate_xy_distortion

!

if (graph%draw_axes) then
  if (graph%title == '') then
    call qp_set_graph (title = '')
  else
    call qp_set_graph (title = trim(graph%title) // ' ' // graph%title_suffix)
  endif
  call qp_draw_axes
endif

isu = tao_universe_number(graph%ix_universe)
lat => s%u(isu)%model%lat

if (.not. graph%valid) return

! loop over all elements in the lattice. 

do n = 0, ubound(lat%branch, 1)
  branch => lat%branch(n)
  branch%ele%logic = .false.  ! Used to mark as drawn.
  do i = 1, branch%n_ele_max
    ele => branch%ele(i)
    ele_shape => tao_pointer_to_ele_shape (ele, s%plotting%floor_plan%ele_shape)
    if (ele%ix_ele > lat%n_ele_track .and. .not. associated(ele_shape)) cycle   ! Nothing to draw
    if (ele%lord_status == multipass_lord$) then
      do j = ele%ix1_slave, ele%ix2_slave
        ic = lat%control(j)%ix_slave
        call tao_draw_ele_for_floor_plan (plot, graph, lat, branch%ele(ic), '', ele_shape, .false.)
      enddo
    else
      call tao_draw_ele_for_floor_plan (plot, graph, lat, ele, '', ele_shape, .false.)
    endif
  enddo
enddo

! Draw data

do i = 1, size(s%plotting%floor_plan%ele_shape)
  ele_shape => s%plotting%floor_plan%ele_shape(i)
  if (ele_shape%ele_name(1:5) /= 'dat::') cycle
  if (.not. ele_shape%draw) cycle
  call tao_find_data (err, ele_shape%ele_name, d_array = d_array, log_array = logic_array)
  if (err) cycle
  do j = 1, size(d_array)
    datum => d_array(j)%d
    if (datum%d1%d2%ix_uni /= graph%ix_universe) cycle
    if (size(logic_array) /= 0) then
      if (.not. logic_array(j)%l) cycle
    endif
    ele => pointer_to_ele (lat, datum%ix_branch, datum%ix_ele)
    call tao_draw_ele_for_floor_plan (plot, graph, lat, ele, tao_datum_name(datum), ele_shape, .true.)
  enddo
enddo

! Draw variables

do i = 1, size(s%plotting%floor_plan%ele_shape)
  ele_shape => s%plotting%floor_plan%ele_shape(i)
  if (ele_shape%ele_name(1:5) /= 'var::') cycle
  if (.not. ele_shape%draw) cycle
  call tao_find_var (err, ele_shape%ele_name, v_array = v_array, log_array = logic_array)
  if (err) cycle
  do j = 1, size(v_array)
    var => v_array(j)%v
    if (size(logic_array) /= 0) then
      if (.not. logic_array(j)%l) cycle
    endif
    do k = 1, size(var%this)
      if (var%this(k)%ix_uni /= graph%ix_universe) cycle
      ele => pointer_to_ele(lat, var%this(k)%ix_ele, var%this(k)%ix_branch)
      call tao_draw_ele_for_floor_plan (plot, graph, lat, ele, tao_var1_name(var), ele_shape, .true.)
    enddo
  enddo
enddo

! Draw the building wall

if (allocated(s%building_wall%section)) then
  do i = 1, size(s%plotting%floor_plan%ele_shape)
    ele_shape => s%plotting%floor_plan%ele_shape(i)
    if (ele_shape%ele_name /= 'wall::building') cycle
    if (.not. ele_shape%draw) cycle
    call qp_translate_to_color_index (ele_shape%color, icol)

    do ib = 1, size(s%building_wall%section)
      pt => s%building_wall%section(ib)%point

      do j = 2, size(pt)
        if (pt(j)%radius == 0) then   ! line
          call floor_to_screen (pt(j-1)%x, 0.0_rp, pt(j-1)%z, end1%x, end1%y)
          call floor_to_screen (pt(j)%x, 0.0_rp, pt(j)%z, end2%x, end2%y)
          call qp_draw_line(end1%x, end2%x, end1%y, end2%y, color = icol)

        else                    ! arc
          theta1 = atan2(pt(j-1)%x - pt(j)%x_center, pt(j-1)%z - pt(j)%z_center)
          dtheta = atan2(pt(j)%x - pt(j)%x_center, pt(j)%z - pt(j)%z_center) - theta1
          if (abs(dtheta) > pi) dtheta = modulo2(dtheta, pi)
          n_bend = abs(50 * dtheta) + 1
          do k = 0, n_bend
            theta = theta1 + k * dtheta / n_bend
            v_vec(1) = pt(j)%x_center + abs(pt(j)%radius) * sin(theta)
            v_vec(2) = 0
            v_vec(3) = pt(j)%z_center + abs(pt(j)%radius) * cos(theta)
            call floor_to_screen (v_vec(1), v_vec(2), v_vec(3), x_bend(k), y_bend(k))
          enddo
          call qp_draw_polyline(x_bend(:n_bend), y_bend(:n_bend), color = icol)
        endif
      enddo

    enddo
    exit
  enddo
end if

! Draw any data curves and beam chamber wall curve

do i = 1, size(graph%curve)
  ! ... needs to be filled in ..
enddo

end subroutine tao_draw_floor_plan 

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine tao_draw_ele_for_floor_plan (plot, graph, lat, ele, name_in, ele_shape, is_data)
!
! Routine to draw one lattice element or one datum location for the floor plan graph. 
!
! Input:
!   plot         -- Tao_plot_struct: Plot containing the graph.
!   graph        -- Tao_graph_struct: Graph to plot.
!   lat          -- lat_struct: Lattice containing the element.
!   ele          -- ele_struct: Element to draw.
!   name_in      -- Character(*): If not blank then name to print beside the element.
!   ele_shape    -- tao_ele_shape_struct: Shape to draw from s%plotting%floor_plan%ele_shape(:) array.
!                    Will be NULL if no associated shape for this element.
!   is_data      -- Logical: Are we drawing an actual lattice elment or marking where a Tao datum is being evaluated?
!-

recursive subroutine tao_draw_ele_for_floor_plan (plot, graph, lat, ele, name_in, ele_shape, is_data)

implicit none

type (tao_plot_struct) :: plot
type (tao_graph_struct) :: graph
type (lat_struct) :: lat
type (ele_struct) :: ele
type (ele_struct) :: drift
type (ele_struct), pointer :: ele1, ele2, lord
type (floor_position_struct) end1, end2, floor, x_ray
type (tao_building_wall_point_struct), pointer :: pt(:)
type (tao_ele_shape_struct), pointer :: ele_shape, branch_shape

integer i, j, k, icol, isu, n_bend, n, ix, ic, n_mid

real(rp) off, off1, off2, angle, rho, dx1, dy1, dx2, dy2
real(rp) dt_x, dt_y, x_center, y_center, dx, dy, theta
real(rp) x_bend(0:1000), y_bend(0:1000), dx_bend(0:1000), dy_bend(0:1000)
real(rp) v_old(3), w_old(3,3), r_vec(3), dr_vec(3), v_vec(3), dv_vec(3)
real(rp) cos_t, sin_t, cos_p, sin_p, cos_a, sin_a, height
real(rp) x_inch, y_inch, x0, y0, x1, x2, y1, y2, e1_factor, e2_factor
real(rp) r0_plus(2), r0_minus(2), dr2_p(2), dr2_m(2), dr_p(2), dr_m(2)

character(*) name_in
character(80) str
character(40) name
character(40) :: r_name = 'tao_draw_ele_for_floor_plan'
character(2) justify

logical is_data
logical shape_has_box, is_bend

!

call find_element_ends (lat, ele, ele1, ele2)
if (.not. associated(ele1)) return

if (is_data) then  ! pretend this is zero length element
  ele1 => ele2
  is_bend = .false.
else
  is_bend = (ele%key == sbend$)
endif

call floor_to_screen_coords (ele1%floor, end1)
call floor_to_screen_coords (ele2%floor, end2)

! Only draw those element that have at least one point in bounds.
  
if ((end1%x < graph%x%min .or. graph%x%max < end1%x .or. &
    end1%y < graph%y%min .or. graph%y%max < end1%y) .and. &
    (end2%x < graph%x%min .or. graph%x%max < end2%x .or. &
    end2%y < graph%y%min .or. graph%y%max < end2%y)) return

! Bends can be tricky if they are not in the X-Z plane. 
! Bends are parameterized by a set of points (x_bend, y_bend) along their  
! centerline and a set of vectors (dx_bend, dy_bend) tangent to the centerline.

if (is_bend) then

  floor = ele1%floor
  v_old = [floor%x, floor%y, floor%z]
  call floor_angles_to_w_mat (floor%theta, floor%phi, 0.0_rp, w_old)

  n_bend = min(abs(int(100 * ele%value(angle$))) + 1, ubound(x_bend, 1))
  do j = 0, n_bend
    angle = j * ele%value(angle$) / n_bend
    cos_t = cos(ele%value(tilt$))
    sin_t = sin(ele%value(tilt$))
    cos_a = cos(angle)
    sin_a = sin(angle)
    if (ele%value(g$) == 0) then
      r_vec = ele%value(l$) * j * [0, 0, 1]
    else
      r_vec = ele%value(rho$) * [cos_t * (cos_a - 1), sin_t * (cos_a - 1), sin_a]
    endif
    dr_vec = [-cos_t * sin_a, -sin_t * sin_a, cos_a]
    ! This keeps dr_vec pointing to the inside (important for the labels).
    if (cos_t < 0) dr_vec = -dr_vec
    v_vec = matmul (w_old, r_vec) + v_old
    dv_vec = matmul (w_old, dr_vec) 
    call floor_to_screen (v_vec(1), v_vec(2), v_vec(3), x_bend(j), y_bend(j))
    call floor_to_screen (dv_vec(1), dv_vec(2), dv_vec(3), dx_bend(j), dy_bend(j))

    ! Correct for e1 and e2 face angles which are a rotation of the faces about
    ! the local y-axis.

    if (j == 0) then
      dr_vec = tan(ele%value(e1$)) * [cos_t * cos_a, sin_t * cos_a, sin_a]
      dv_vec = matmul (w_old, dr_vec) 
      call floor_to_screen (dv_vec(1), dv_vec(2), dv_vec(3), dx1, dy1)
      dx_bend(j) = dx_bend(j) - dx1
      dy_bend(j) = dy_bend(j) - dy1
      e1_factor = sqrt(dx_bend(j)**2 + dy_bend(j)**2)
    endif

    if (j == n_bend) then
      dr_vec = tan(ele%value(e2$)) * [cos_t * cos_a, sin_t * cos_a, sin_a]
      dv_vec = matmul (w_old, dr_vec) 
      call floor_to_screen (dv_vec(1), dv_vec(2), dv_vec(3), dx1, dy1)
      dx_bend(j) = dx_bend(j) + dx1
      dy_bend(j) = dy_bend(j) + dy1
      e2_factor = sqrt(dx_bend(j)**2 + dy_bend(j)**2)
    endif
  enddo

endif

! Only those elements with an associated ele_shape are to be drawn in full.
! All others are drawn with a simple line or arc

if (.not. associated(ele_shape)) then
  if (is_bend) then
    call qp_draw_polyline(x_bend(:n_bend), y_bend(:n_bend))
  else
    call qp_draw_line(end1%x, end2%x, end1%y, end2%y)
  endif
  return
endif

! Here if element is to be drawn...

if (.not. ele_shape%draw) return
call qp_translate_to_color_index (ele_shape%color, icol)

off = ele_shape%size
off1 = off
off2 = off
if (ele_shape%shape == 'VAR_BOX' .or. ele_shape%shape == 'ASYM_VAR_BOX') then
  select case (ele%key)
  case (quadrupole$)
    off1 = off * ele%value(k1$)
  case (sextupole$)
    off1 = off * ele%value(k2$)
  case (octupole$)
    off1 = off * ele%value(k3$)
  case (solenoid$)
    off1 = off * ele%value(ks$)
  end select
  off2 = off1
  if (ele_shape%shape == 'ASYM_VAR_BOX') off1 = 0
endif

! x-ray line parameters if present

if (attribute_index(ele, 'X_RAY_LINE_LEN') > 0 .and. ele%value(x_ray_line_len$) > 0) then
  call init_ele(drift)
  drift%key = drift$
  drift%value(l$) = ele%value(x_ray_line_len$)
  call ele_geometry (ele2%floor, drift, drift%floor) 
  call floor_to_screen_coords (drift%floor, x_ray)
  call qp_convert_point_abs (x_ray%x, x_ray%y, 'DATA', x_ray%x, x_ray%y, 'POINTS')
endif

! Draw the shape. Since the conversion from floor coords to screen coords can
! be different along x and y, we convert to screen coords to make sure that rectangles
! remain rectangular.

call qp_convert_point_abs (end1%x, end1%y, 'DATA', end1%x, end1%y, 'POINTS')
call qp_convert_point_abs (end2%x, end2%y, 'DATA', end2%x, end2%y, 'POINTS')

! dx1, etc. are offsets perpendicular to the refernece orbit

call qp_convert_point_rel (cos(end1%theta), sin(end1%theta), 'DATA', dt_x, dt_y, 'POINTS')
dx1 =  off1 * dt_y / sqrt(dt_x**2 + dt_y**2)
dy1 = -off1 * dt_x / sqrt(dt_x**2 + dt_y**2)

call qp_convert_point_rel (cos(end2%theta), sin(end2%theta), 'DATA', dt_x, dt_y, 'POINTS')
dx2 =  off2 * dt_y / sqrt(dt_x**2 + dt_y**2)
dy2 = -off2 * dt_x / sqrt(dt_x**2 + dt_y**2)

if (is_bend) then
  do j = 0, n_bend
    call qp_convert_point_abs (x_bend(j), y_bend(j), 'DATA', x_bend(j), y_bend(j), 'POINTS')
    call qp_convert_point_rel (dx_bend(j), dy_bend(j), 'DATA', dt_x, dt_y, 'POINTS')
    dx_bend(j) =  off * dt_y / sqrt(dt_x**2 + dt_y**2)
    dy_bend(j) = -off * dt_x / sqrt(dt_x**2 + dt_y**2)
  enddo
  dx_bend(0) = dx_bend(0) * e1_factor
  dy_bend(0) = dy_bend(0) * e1_factor
  dx_bend(n_bend) = dx_bend(n_bend) * e2_factor
  dy_bend(n_bend) = dy_bend(n_bend) * e2_factor

  ! Finite e1 or e2 may mean some points extend beyound the outline of the bend.
  ! Throw out these points.

  ! First look at the first half of the bend for points that are beyound due to e1.

  r0_plus  = [x_bend(0) + dx_bend(0), y_bend(0) + dy_bend(0)]
  r0_minus = [x_bend(0) - dx_bend(0), y_bend(0) - dy_bend(0)]
  n_mid = n_bend/2
  dr2_p = [x_bend(n_mid) + dx_bend(n_mid), y_bend(n_mid) + dy_bend(n_mid)] - r0_plus
  dr2_m = [x_bend(n_mid) - dx_bend(n_mid), y_bend(n_mid) - dy_bend(n_mid)] - r0_minus

  j = n_bend/2 
  do 
    if (j == 0) exit
    dr_p  = [x_bend(j) + dx_bend(j), y_bend(j) + dy_bend(j)] - r0_plus
    dr_m  = [x_bend(j) - dx_bend(j), y_bend(j) - dy_bend(j)] - r0_minus
    ! If one of the points is outside then exit
    if (dot_product(dr_p, dr2_p) < 0 .or.dot_product(dr_m, dr2_m) < 0) exit
    j = j - 1
  enddo

  ! If there are points outside, delete them

  if (j > 0) then
    x_bend(1:n_bend-j)  = x_bend(j+1:n_bend)
    y_bend(1:n_bend-j)  = y_bend(j+1:n_bend)
    dx_bend(1:n_bend-j) = dx_bend(j+1:n_bend)
    dy_bend(1:n_bend-j) = dy_bend(j+1:n_bend)
    n_bend = n_bend - j
  endif

  ! Now look at the last half of the bend for points that are beyound due to e2.

  r0_plus  = [x_bend(n_bend) + dx_bend(n_bend), y_bend(n_bend) + dy_bend(n_bend)]
  r0_minus = [x_bend(n_bend) - dx_bend(n_bend), y_bend(n_bend) - dy_bend(n_bend)]
  n_mid = n_bend/2
  dr2_p = [x_bend(n_mid) + dx_bend(n_mid), y_bend(n_mid) + dy_bend(n_mid)] - r0_plus
  dr2_m = [x_bend(n_mid) - dx_bend(n_mid), y_bend(n_mid) - dy_bend(n_mid)] - r0_minus

  j = n_bend/2 
  do 
    if (j == n_bend) exit
    dr_p  = [x_bend(j) + dx_bend(j), y_bend(j) + dy_bend(j)] - r0_plus
    dr_m  = [x_bend(j) - dx_bend(j), y_bend(j) - dy_bend(j)] - r0_minus
    ! If one of the points is outside then exit
    if (dot_product(dr_p, dr2_p) < 0 .or.dot_product(dr_m, dr2_m) < 0) exit
    j = j + 1
  enddo

  ! If there are points outside, delete them

  if (j < n_bend) then
    x_bend(j)  = x_bend(n_bend)
    y_bend(j)  = y_bend(n_bend)
    dx_bend(j) = dx_bend(n_bend)
    dy_bend(j) = dy_bend(n_bend)
    n_bend = j
  endif

endif

! Draw the element...

! Draw x-ray line

if (attribute_index(ele, 'X_RAY_LINE_LEN') > 0 .and. ele%value(x_ray_line_len$) > 0) then
  drift%key = photon_branch$
  drift%name = ele%name
  branch_shape => tao_pointer_to_ele_shape (drift, s%plotting%floor_plan%ele_shape)
  if (associated(branch_shape)) then
    if (branch_shape%draw) then
      call qp_translate_to_color_index (branch_shape%color, ic)
      call qp_draw_line (x_ray%x, end2%x, x_ray%y, end2%y, units = 'POINTS', color = ic)
    endif
  endif
endif

shape_has_box = (index(ele_shape%shape, 'BOX') /= 0)

! Draw diamond

if (ele_shape%shape == 'DIAMOND') then
  if (is_bend) then
    n = n_bend / 2
    x1 = (x_bend(n) + dx_bend(n)) / 2
    x2 = (x_bend(n) - dx_bend(n)) / 2
    y1 = (y_bend(n) + dy_bend(n)) / 2
    y2 = (y_bend(n) - dy_bend(n)) / 2
  else
    x1 = ((end1%x + end2%x) + (dx1 + dx2)) / 2
    x2 = ((end1%x + end2%x) - (dx1 + dx2)) / 2
    y1 = ((end1%y + end2%y) + (dy1 + dy2)) / 2
    y2 = ((end1%y + end2%y) - (dy1 + dy2)) / 2
  endif
  call qp_draw_line (end1%x, x1, end1%y, y1, units = 'POINTS', color = icol)
  call qp_draw_line (end1%x, x2, end1%y, y2, units = 'POINTS', color = icol)
  call qp_draw_line (end2%x, x1, end2%y, y1, units = 'POINTS', color = icol)
  call qp_draw_line (end2%x, x2, end2%y, y2, units = 'POINTS', color = icol)
endif

! Draw a circle.

if (ele_shape%shape == 'CIRCLE') then
  call qp_draw_circle ((end1%x+end2%x)/2, (end1%y+end2%y)/2, off, &
                                                  units = 'POINTS', color = icol)
endif

! Draw an X.

if (ele_shape%shape == 'X') then
  if (is_bend) then
    n = n_bend / 2
    x0  = x_bend(n)
    y0  = y_bend(n)
    dx1 = dx_bend(n)
    dy1 = dy_bend(n)
  else
    x0 = (end1%x + end2%x) / 2
    y0 = (end1%y + end2%y) / 2
  endif
  call qp_draw_line (x0 - dx1, x0 + dx1, y0 - dy1, y0 + dy1, units = 'POINTS', color = icol) 
  call qp_draw_line (x0 - dx1, x0 + dx1, y0 + dy1, y0 - dy1, units = 'POINTS', color = icol) 
endif

! Draw top and bottom of boxes and bow_tiw

if (ele_shape%shape == 'BOW_TIE' .or. shape_has_box) then
  if (is_bend) then
    call qp_draw_polyline(x_bend(:n_bend) + dx_bend(:n_bend), &
                          y_bend(:n_bend) + dy_bend(:n_bend), units = 'POINTS', color = icol)
    call qp_draw_polyline(x_bend(:n_bend) - dx_bend(:n_bend), &
                          y_bend(:n_bend) - dy_bend(:n_bend), units = 'POINTS', color = icol)

  else
    call qp_draw_line (end1%x+dx1, end2%x+dx1, end1%y+dy1, end2%y+dy1, &
                                                    units = 'POINTS', color = icol)
    call qp_draw_line (end1%x-dx2, end2%x-dx2, end1%y-dy2, end2%y-dy2, &
                                                    units = 'POINTS', color = icol)
  endif
endif

! Draw sides of boxes

if (shape_has_box) then
  if (is_bend) then
    call qp_draw_line (x_bend(0)-dx_bend(0), x_bend(0)+dx_bend(0), &
                       y_bend(0)-dy_bend(0), y_bend(0)+dy_bend(0), units = 'POINTS', color = icol)
    n = n_bend
    call qp_draw_line (x_bend(n)-dx_bend(n), x_bend(n)+dx_bend(n), &
                       y_bend(n)-dy_bend(n), y_bend(n)+dy_bend(n), units = 'POINTS', color = icol)
  else
    call qp_draw_line (end1%x+dx1, end1%x-dx2, end1%y+dy1, end1%y-dy2, &
                                                  units = 'POINTS', color = icol)
    call qp_draw_line (end2%x+dx1, end2%x-dx2, end2%y+dy1, end2%y-dy2, &
                                                  units = 'POINTS', color = icol)
  endif
endif

! Draw X for xbox or bow_tie

if (ele_shape%shape == 'XBOX' .or. ele_shape%shape == 'BOW_TIE') then
  call qp_draw_line (end1%x+dx1, end2%x-dx2, end1%y+dy1, end2%y-dy2, &
                                                  units = 'POINTS', color = icol)
  call qp_draw_line (end1%x-dx2, end2%x+dx1, end1%y-dy1, end2%y+dy2, &
                                                  units = 'POINTS', color = icol)
endif

! Draw the label.
! Since multipass slaves are on top of one another, just draw the multipass lord's name.
! Also place a bend's label to the outside of the bend.

if (ele_shape%label == 'name') then
  if (name_in /= '') then
    name = name_in
  elseif (ele%slave_status == multipass_slave$) then
    lord => pointer_to_lord(ele, 1)
    name = lord%name
  else
    name = ele%name
  endif
elseif (ele_shape%label == 's') then
  write (name, '(f16.2)') ele%s - ele%value(l$) / 2
  call string_trim (name, name, ix)
elseif (ele_shape%label /= 'none') then
  call out_io (s_error$, r_name, 'BAD ELEMENT LABEL: ' // ele_shape%label)
  call err_exit
endif 

if (ele_shape%label /= 'none') then
  if (ele%key /= sbend$ .or. ele%value(g$) == 0) then
    x_center = (end1%x + end2%x) / 2 
    y_center = (end1%y + end2%y) / 2 
    dx = -2 * dt_y / sqrt(dt_x**2 + dt_y**2)
    dy =  2 * dt_x / sqrt(dt_x**2 + dt_y**2)
  else
    n = n_bend / 2
    x_center = x_bend(n) 
    y_center = y_bend(n) 
    dx = -2 * dx_bend(n) / sqrt(dx_bend(n)**2 + dy_bend(n)**2)
    dy = -2 * dy_bend(n) / sqrt(dx_bend(n)**2 + dy_bend(n)**2)
  endif
  theta = modulo2 (atan2(dy, dx) * 180 / pi, 90.0_rp)
  if (dx > 0) then
    justify = 'LC'
  else
    justify = 'RC'
  endif
  height = s%plotting%text_height * s%plotting%legend_text_scale
  call qp_draw_text (name, x_center+dx*off2, y_center+dy*off2, units = 'POINTS', &
                               height = height, justify = justify, ANGLE = theta)    
endif

end subroutine tao_draw_ele_for_floor_plan

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine tao_draw_lat_layout (plot, graph)
!
! Routine to draw a lattice layout graph.
!
! Input:
!   plot  -- Tao_plot_struct: Plot containing the graph.
!   graph -- Tao_graph_struct: Graph to plot.
!-

subroutine tao_draw_lat_layout (plot, graph)

implicit none

type (tao_plot_struct) :: plot
type (tao_graph_struct) :: graph
type (tao_lattice_branch_struct), pointer :: lat_branch
type (tao_ele_shape_struct), pointer :: ele_shape
type (lat_struct), pointer :: lat
type (ele_struct), pointer :: ele, ele1, ele2
type (branch_struct), pointer :: branch, branch2
type (tao_data_array_struct), allocatable, target :: d_array(:)
type (tao_var_array_struct), allocatable, target :: v_array(:)
type (tao_logical_array_struct), allocatable :: logic_array(:)
type (tao_data_struct), pointer :: datum
type (tao_var_struct), pointer :: var

real(rp) x1, x2, y1, y2, y, s_pos, x0, y0
real(rp) lat_len, height, dx, dy, key_number_height, dummy, l2

integer i, j, k, n, kk, ix, ix1, isu
integer ix_var, ixv

logical shape_has_box, err, have_data

character(80) str
character(40) name
character(20) :: r_name = 'tao_draw_lat_layout'
character(20) shape_name

! Init

if (.not. graph%valid) return

select case (plot%x_axis_type)
case ('index')
  call out_io (s_error$, r_name, '"index" x-axis type not valid with lat_layout')
  graph%valid = .false.
  return

case ('ele_index')
  call out_io (s_error$, r_name, '"ele_index" x-axis type not valid with lat_layout')
  graph%valid = .false.
  return

case ('s')

case default
  call out_io (s_warn$, r_name, "Unknown x_axis_type")
  graph%valid = .false.
  return
end select

isu = tao_universe_number(graph%ix_universe)
lat => s%u(isu)%model%lat
branch => lat%branch(graph%ix_branch)
lat_branch => s%u(isu)%model%lat_branch(graph%ix_branch)

lat_len = branch%param%total_length
  
! Setup the placement of the graph on the plot page.

call qp_set_layout (x_axis = graph%x, y_axis = graph%y, box = graph%box, margin = graph%margin)

call qp_draw_line (graph%x%min, graph%x%max, 0.0_rp, 0.0_rp)

! loop over all elements in the branch. Only draw those element that
! are within bounds.

do i = 1, branch%n_ele_track
  ele => branch%ele(i)
  if (ele%slave_status == super_slave$) cycle
  call draw_ele_for_lat_layout (ele, ele%name)
enddo

! Loop over all control elements.

do i = lat%n_ele_track+1, lat%n_ele_max
  ele => branch%ele(i)
  if (ele%lord_status == multipass_lord$) cycle
  branch2 => pointer_to_branch(ele)
  if (branch2%ix_branch /= branch%ix_branch) cycle
  call draw_ele_for_lat_layout (ele, ele%name)
enddo

! Draw data

do i = 1, size(s%plotting%lat_layout%ele_shape)
  ele_shape => s%plotting%lat_layout%ele_shape(i)
  if (ele_shape%ele_name(1:5) /= 'dat::') cycle
  if (.not. ele_shape%draw) cycle
  call tao_find_data (err, ele_shape%ele_name, d_array = d_array, log_array = logic_array)
  if (err) cycle
  do j = 1, size(d_array)
    datum => d_array(j)%d
    if (datum%ix_branch /= graph%ix_branch) cycle
    if (datum%d1%d2%ix_uni /= graph%ix_universe) cycle
    if (size(logic_array) /= 0) then
      if (.not. logic_array(j)%l) cycle
    endif
    x0 = datum%s 
    if (x0 > graph%x%max) cycle
    if (x0 < graph%x%min) cycle
    y1 = ele_shape%size
    y1 = max(graph%y%min, min(y1, graph%y%max))
    y2 = -y1
    call qp_convert_point_rel (dummy, y1, 'DATA', dummy, y, 'INCH') 
    call qp_convert_point_rel (y, dummy, 'INCH', dx, dummy, 'DATA')
    x1 = x0 - dx
    x2 = x0 + dx
    ele => pointer_to_ele (lat, datum%ix_branch, datum%ix_ele)
    call draw_shape_for_lat_layout (tao_datum_name(datum), datum%s, ele_shape)
  enddo
enddo

! Draw variables

do i = 1, size(s%plotting%lat_layout%ele_shape)
  ele_shape => s%plotting%lat_layout%ele_shape(i)
  if (.not. ele_shape%draw) cycle
  if (ele_shape%ele_name(1:5) /= 'var::') cycle
  call tao_find_var (err, ele_shape%ele_name, v_array = v_array, log_array = logic_array)
  if (err) cycle
  do j = 1, size(v_array)
    var => v_array(j)%v
    if (size(logic_array) /= 0) then
      if (.not. logic_array(j)%l) cycle
    endif
    do k = 1, size(var%this)
      if (var%this(k)%ix_uni /= graph%ix_universe) cycle
      if (var%this(k)%ix_branch /= graph%ix_branch) cycle
      ele => pointer_to_ele(lat, var%this(k)%ix_ele, var%this(k)%ix_branch)
      call draw_shape_for_lat_layout(tao_var1_name(var), ele%s, ele_shape)
    enddo
  enddo
enddo

! Draw x-axis min max

if (graph%x%draw_numbers) then
  call qp_to_axis_number_text (graph%x, 0, str)
  call qp_convert_point_abs (graph%x%min, -10.0_rp, 'DATA', x1, y1, 'POINTS')
  call qp_draw_text (trim(str) // '-|', x1, y1, 'POINTS', justify = 'RT')
  call qp_to_axis_number_text (graph%x, graph%x%major_div, str)
  call qp_convert_point_abs (graph%x%max, -10.0_rp, 'DATA', x1, y1, 'POINTS')
  call qp_draw_text ('|-' // trim(str), x1, y1, 'POINTS', justify = 'LT')
endif

! This is for drawing the key numbers under the appropriate elements

key_number_height = 10

if (s%global%label_keys) then
  do kk = 1, 10
    k = kk + 10*tao_com%ix_key_bank
    if (k > ubound(s%key, 1)) cycle
    ix_var = s%key(k)
    if (ix_var < 1) cycle
    write (str, '(i1)') mod(kk, 10)
    var => s%var(ix_var)
    do ixv = 1, size(var%this)
      if (var%this(ixv)%ix_uni /= isu) cycle
      ele => pointer_to_ele(lat, var%this(ixv)%ix_ele, var%this(ixv)%ix_branch)
      if (ele%n_slave /= 0 .and. ele%lord_status /= super_lord$) then
        do j = 1, ele%n_slave
          ele1 => pointer_to_slave(ele, j)
          l2 = ele1%value(l$) / 2
          s_pos = ele1%s - l2
          if (s_pos > graph%x%max .and. s_pos-lat_len > graph%x%min) s_pos = s_pos - lat_len
          if (s_pos + l2 < graph%x%min .or. s_pos - l2 > graph%x%max) cycle
          call qp_draw_text (trim(str), s_pos, graph%y%max, justify = 'CT', height = key_number_height)  
        enddo
      else
        l2 = ele%value(l$) / 2
        s_pos = ele%s - l2
        if (s_pos > graph%x%max .and. s_pos-lat_len > graph%x%min) s_pos = s_pos - lat_len
        if (s_pos + l2 < graph%x%min .or. s_pos - l2 > graph%x%max) cycle
        call qp_draw_text (trim(str), s_pos, graph%y%max, justify = 'CT', height = key_number_height)  
      endif
    enddo
  enddo
endif

! Draw data and beam_chamber curves

if (allocated(graph%curve)) then
  do i = 1, size(graph%curve)
    call tao_draw_curve_data (plot, graph, graph%curve(i), have_data)
  enddo
endif

!--------------------------------------------------------------------------------------------------
contains 

subroutine draw_ele_for_lat_layout (ele, name_in)

type (ele_struct) ele
type (ele_struct), pointer :: ele1, ele2
type (tao_ele_shape_struct), pointer :: ele_shape

integer section_id, icol

character(*) name_in

! Draw element shape...

ele_shape => tao_pointer_to_ele_shape (ele, s%plotting%lat_layout%ele_shape)
if (.not. associated(ele_shape)) return
if (.not. ele_shape%draw) return

shape_name = ele_shape%shape

call find_element_ends (lat, ele, ele1, ele2)
if (.not. associated(ele1)) return
if (ele1%ix_branch /= graph%ix_branch) return
x1 = ele1%s
x2 = ele2%s
! If out of range then try a negative position
if (branch%param%lattice_type == circular_lattice$ .and. x1 > graph%x%max) then
  x1 = x1 - lat_len
  x2 = x2 - lat_len
endif
  
if (x1 > graph%x%max) return
if (x2 < graph%x%min) return

! Here if element is to be drawn...
! r1 and r2 are the scale factors for the lines below and above the center line.

y = ele_shape%size
y1 = -y
y2 =  y
if (shape_name == 'VAR_BOX' .or. shape_name == 'ASYM_VAR_BOX') then
  select case (ele%key)
  case (quadrupole$)
    y2 = y * ele%value(k1$)
  case (sextupole$)
    y2 = y * ele%value(k2$)
  case (octupole$)
    y2 = y * ele%value(k3$)
  case (solenoid$)
    y2 = y * ele%value(ks$)
  end select
  y1 = -y2
  if (shape_name == 'ASYM_VAR_BOX') y1 = 0
end if

y1 = max(graph%y%min, min(y1, graph%y%max))
y2 = max(graph%y%min, min(y2, graph%y%max))

call draw_shape_for_lat_layout (name_in, ele%s - ele%value(l$) / 2, ele_shape)

end subroutine draw_ele_for_lat_layout

!--------------------------------------------------------------------------------------------------
!--------------------------------------------------------------------------------------------------
! contains

subroutine draw_shape_for_lat_layout (name_in, s_pos, ele_shape)

type (tao_ele_shape_struct) ele_shape
real(rp) s_pos, r_dum, y_off
integer icol
character(*) name_in
character(20) shape_name

!

shape_name = ele_shape%shape
shape_has_box = (index(shape_name, 'BOX') /= 0)
call qp_translate_to_color_index (ele_shape%color, icol)

! Draw the shape

if (shape_name == 'DIAMOND') then
  call qp_draw_line (x1, (x1+x2)/2, 0.0_rp, y1, color = icol)
  call qp_draw_line (x1, (x1+x2)/2, 0.0_rp, y2, color = icol)
  call qp_draw_line (x2, (x1+x2)/2, 0.0_rp, y1, color = icol)
  call qp_draw_line (x2, (x1+x2)/2, 0.0_rp, y2, color = icol)
endif

if (shape_name == 'CIRCLE') then
  call qp_convert_point_abs ((x1+x2)/2, (y1+y2)/2, 'DATA', x0, y0, 'POINTS')
  call qp_draw_circle (x0, y0, abs(y1), units = 'POINTS', color = icol)
endif

if (shape_name == 'X') then
  call qp_convert_point_abs ((x1+x2)/2, (y1+y2)/2, 'DATA', x0, y0, 'POINTS')
  call qp_convert_point_rel (x1, y1, 'DATA', x1, y1, 'POINTS')
  call qp_convert_point_rel (x2, y2, 'DATA', x2, y2, 'POINTS')
  call qp_draw_line (x0-y1, x0+y1, y0-y1, y0+y1, units = 'POINTS', color = icol)
  call qp_draw_line (x0-y1, x0+y1, y0+y1, y0-y1, units = 'POINTS', color = icol)
endif

if (shape_name == 'BOW_TIE') then
  call qp_draw_line (x1, x2, y1, y1, color = icol)
  call qp_draw_line (x1, x2, y2, y2, color = icol)
endif

if (shape_has_box) then
  call qp_draw_rectangle (x1, x2, y1, y2, color = icol)
endif

! Draw X for XBOX or BOW_TIE

if (shape_name == 'XBOX' .or. shape_name == 'BOW_TIE') then
  call qp_draw_line (x1, x2, y2, y1, color = icol)
  call qp_draw_line (x1, x2, y1, y2, color = icol)
endif

! Put on a label

if (s%global%label_lattice_elements .and. ele_shape%label /= 'none') then

  call qp_from_inch_rel (0.0_rp, graph%y%label_offset, r_dum, y_off, 'DATA')

  if (ele_shape%label == 'name') then
    name = name_in
  elseif (ele_shape%label == 's') then
    write (name, '(f16.2)') s_pos
    call string_trim (name, name, ix)
  else
    call out_io (s_error$, r_name, 'BAD ELEMENT LABEL: ' // ele_shape%label)
    call err_exit
  endif 

  if (s_pos > graph%x%max .and. s_pos-lat_len > graph%x%min) s_pos = s_pos - lat_len
  height = s%plotting%text_height * s%plotting%legend_text_scale
  call qp_draw_text (name, s_pos, graph%y%min-y_off, height = height, justify = 'LC', ANGLE = 90.0_rp)

endif

end subroutine draw_shape_for_lat_layout

end subroutine tao_draw_lat_layout

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine tao_draw_beam_chamber_wall (plot, graph)
!
! Routine to draw the beam chamber wall.
!
! Input:
!   plot  -- Tao_plot_struct: Plot containing the graph.
!   graph -- Tao_graph_struct: Graph to plot.
!-

subroutine tao_draw_beam_chamber_wall (plot, graph)

implicit none

type (tao_plot_struct) plot
type (ele_struct), pointer :: ele
type (tao_graph_struct), target :: graph
type (lat_struct), pointer :: lat
type (tao_lattice_branch_struct), pointer :: lat_branch
type (branch_struct), pointer :: branch, branch2

real(rp) lat_len, dummy

integer i, isu

!

isu = tao_universe_number(graph%ix_universe)
lat => s%u(isu)%model%lat
branch => lat%branch(graph%ix_branch)
lat_branch => s%u(isu)%model%lat_branch(graph%ix_branch)

lat_len = branch%param%total_length
  
! Setup the placement of the graph on the plot page.

call qp_set_layout (x_axis = graph%x, y_axis = graph%y, box = graph%box, margin = graph%margin)
call qp_draw_line (graph%x%min, graph%x%max, 0.0_rp, 0.0_rp)

! Loop over all elements

do i = 1, branch%n_ele_track
  ele => branch%ele(i)
  if (ele%slave_status == super_slave$) cycle
  call draw_ele_beam_chamber (ele)
enddo

! Loop over all control elements.

do i = lat%n_ele_track+1, lat%n_ele_max
  ele => branch%ele(i)
  if (ele%lord_status == multipass_lord$) cycle
  branch2 => pointer_to_branch(ele)
  if (branch2%ix_branch /= branch%ix_branch) cycle
  call draw_ele_beam_chamber (ele)
enddo

!------------------------------------------------------------------------
contains

subroutine draw_ele_beam_chamber (ele)

type (ele_struct) ele

real(rp) y1_plus, y1_minus, y2_plus, y2_minus, x1, x2, y1, y2
integer section_id, icol

! Draw beam chamber wall. 

icol = black$
if (allocated (graph%curve)) icol = graph%curve(1)%line%color

if (associated(ele%wall3d)) then
  call calc_wall_radius (ele%wall3d%section(1)%v,  1.0_rp, 0.0_rp,  y1_plus, dummy)
  call calc_wall_radius (ele%wall3d%section(1)%v, -1.0_rp, 0.0_rp,  y1_minus, dummy)
  x1 = ele%s - ele%value(l$) + ele%wall3d%section(1)%s

  ! Skip points so close to the last point that the points have negligible spacing

  do section_id = 2, size(ele%wall3d%section)
    x2 = ele%s - ele%value(l$) + ele%wall3d%section(section_id)%s
    if (section_id /= size(ele%wall3d%section) .and. &
            (x2 - x1) < (graph%x%max - graph%x%min) / s%plotting%n_curve_pts) cycle
    call calc_wall_radius (ele%wall3d%section(section_id)%v,  1.0_rp, 0.0_rp,  y2_plus, dummy)
    call calc_wall_radius (ele%wall3d%section(section_id)%v, -1.0_rp, 0.0_rp,  y2_minus, dummy)
    !scale wall
    call qp_draw_line (x1, x2, y1_plus, y2_plus, color = icol)
    call qp_draw_line (x1, x2, -y1_minus, -y2_minus, color = icol)
    x1       = x2
    y1_plus  = y2_plus
    y1_minus = y2_minus 
  end do
endif

end subroutine draw_ele_beam_chamber

end subroutine tao_draw_beam_chamber_wall

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine tao_plot_data (plot, graph)
!
! Routine to draw a graph with data and/or variable curves. 
!
! Input:
!   plot  -- Tao_plot_struct: Plot containing the graph.
!   graph -- Tao_graph_struct: Graph to plot.
!-

subroutine tao_plot_data (plot, graph)

implicit none

type (tao_plot_struct) plot
type (tao_graph_struct), target :: graph

integer k
logical have_data

! Draw the graph outline.

call tao_draw_data_graph (plot, graph)
if (.not. graph%valid) return

! loop over all the curves of the graph and draw them

have_data = .false.

do k = 1, size(graph%curve)
  call tao_draw_curve_data (plot, graph, graph%curve(k), have_data)
enddo

if (.not. have_data) call qp_draw_text ('**No Plottable Data**', &
                            0.18_rp, -0.15_rp, '%/GRAPH/LT', color = red$) 

end subroutine tao_plot_data

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine tao_draw_curve_data (plot, graph, curve, have_data)
!
! Routine to draw a graph with data and/or variable curves. 
!
! Input:
!   plot      -- Tao_plot_struct: Plot containing the graph.
!   graph     -- Tao_graph_struct: Graph containing the curve.
!   curve     -- Tao_curve_struct: Curve to draw.
!   have_data -- Logical: Intitial state.
! Output:
!    have_data -- Logical: Is there any data to plot? Set True if so.
!                   But never reset to False. 
!-

subroutine tao_draw_curve_data (plot, graph, curve, have_data)

implicit none

type (tao_plot_struct) plot
type (tao_graph_struct), target :: graph
type (tao_curve_struct) :: curve

integer i
logical have_data
character(16) num_str

!

if (curve%use_y2) call qp_use_axis (y = 'Y2')
call qp_set_symbol (curve%symbol)

if (curve%draw_symbols .and. allocated(curve%x_symb)) then
  if (size(curve%x_symb) > 0) have_data = .true.
  if (graph%symbol_size_scale > 0) then
    do i = 1, size(curve%x_symb), max(1, curve%symbol_every)
      call qp_draw_symbol (curve%x_symb(i), curve%y_symb(i), height = curve%symb_size(i), clip = graph%clip)
    enddo
  else
    call qp_draw_symbols (curve%x_symb, curve%y_symb, symbol_every = curve%symbol_every, clip = graph%clip)
  endif
endif

if (curve%draw_symbol_index .and. allocated(curve%ix_symb)) then
  if (size(curve%ix_symb) > 0) have_data = .true.
  do i = 1, size(curve%ix_symb)
    if (graph%clip) then
      if (curve%x_symb(i) < graph%x%min .or. curve%x_symb(i) > graph%x%max)  cycle
      if (curve%y_symb(i) < graph%y%min .or. curve%y_symb(i) > graph%y%max) cycle
    endif
    write (num_str, '(i0)') curve%ix_symb(i)
    call qp_draw_text (num_str, curve%x_symb(i), curve%y_symb(i))
  enddo
endif

if (curve%draw_line .and. allocated(curve%x_line)) then
  if (size(curve%x_line) > 0) have_data = .true.
  call qp_set_line ('PLOT', curve%line) 
  call qp_draw_polyline (curve%x_line, curve%y_line, clip = graph%clip, style = 'PLOT')
endif

call qp_use_axis (y = 'Y')  ! reset

end subroutine tao_draw_curve_data

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine tao_draw_histogram_data (plot, graph, curve, have_data)
!
! Routine to draw a graph with data and/or variable histograms. 
!
! Input:
!   plot      -- Tao_plot_struct: Plot containing the graph.
!   graph     -- Tao_graph_struct: Graph containing the histogram.
!   curve     -- Tao_curve_struct: Histogram to draw.
!   have_data -- Logical: Intitial state.
! Output:
!    have_data -- Logical: Is there any data to plot? Set True if so.
!                   But never reset to False. 
!-

subroutine tao_draw_histogram_data (plot, graph, curve, have_data)

implicit none

type (tao_plot_struct) plot
type (tao_graph_struct), target :: graph
type (tao_curve_struct) :: curve

integer i
logical have_data
character(16) num_str

end subroutine tao_draw_histogram_data

!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
!+
! Subroutine tao_draw_data_graph (plot, graph)
!
! Routine to draw a just the graph part of a data graph.
! The calling routine takes care of drawing any curves.
!
! Input:
!   plot  -- Tao_plot_struct: Plot containing the graph.
!   graph -- Tao_graph_struct: Graph to plot.
!-

subroutine tao_draw_data_graph (plot, graph)

implicit none

type (tao_plot_struct) plot
type (tao_graph_struct), target :: graph
type (tao_curve_struct), pointer :: curve
type (qp_line_struct), allocatable :: line(:)
type (qp_symbol_struct), allocatable :: symbol(:)

integer i, j, k, n
real(rp) x, y, x1
character(100), allocatable :: text(:)

! Set scales, margens, etc

call qp_set_layout (box = graph%box, margin = graph%margin)
call qp_set_layout (x_axis = graph%x, x2_mirrors_x = .true.)
call qp_set_layout (y_axis = graph%y, y2_axis = graph%y2, y2_mirrors_y = graph%y2_mirrors_y)
if (graph%title == '') then
  call qp_set_graph (title = '')
else
  call qp_set_graph (title = trim(graph%title) // ' ' // graph%title_suffix)
endif
call qp_draw_axes

! Draw the default x-axis label if there is none. 

if (graph%x%draw_label .and. graph%x%label == '') then
  select case (plot%x_axis_type) 
  case ('index', 'ele_index', 's')
    call qp_to_inch_rel (1.0_rp, 0.0_rp, x1, y, '%GRAPH')
    x = x1 * (graph%x%major_div - 0.5) / graph%x%major_div
    y = -graph%x%number_offset
    call qp_draw_text (plot%x_axis_type, x, y, 'INCH', justify = 'CT')
  end select
endif

!

if (.not. graph%valid) return

if (graph%limited .and. graph%clip .and. s%global%draw_curve_off_scale_warn) &
  call qp_draw_text ('**Curve Off Scale**', -0.30_rp, -0.15_rp, '%/GRAPH/RT', color = red$) 


! Draw the text legend if there is one

if (any(graph%text_legend /= ' ')) call qp_draw_text_legend (graph%text_legend, &
       graph%text_legend_origin%x, graph%text_legend_origin%y, graph%text_legend_origin%units)

! Draw the curve legend if needed

n = size(graph%curve)
allocate (text(n), symbol(n), line(n))

do i = 1, n
  curve => graph%curve(i)
  text(i) = curve%legend_text
  if (text(i) == '') text(i) = curve%data_type
  symbol(i) = curve%symbol
  if (size(curve%x_symb) == 0) symbol(i)%type = -1 ! Do not draw
  if (.not. curve%draw_symbols) symbol(i)%type = -1
  line(i) = curve%line
  if (size(curve%x_line) == 0) line(i)%width = -1 ! Do not draw
  if (.not. curve%draw_line) line(i)%width = -1
enddo

if (graph%draw_curve_legend .and. n > 1) then
  call qp_draw_curve_legend (graph%curve_legend_origin%x, graph%curve_legend_origin%y, &
            graph%curve_legend_origin%units, line, s%plotting%curve_legend_line_len, &
            symbol, text, s%plotting%curve_legend_text_offset)
endif

! Draw any curve info messages

j = 0
do i = 1, n
  curve => graph%curve(i)
  if (curve%message_text == '') cycle
  j = j + 1
  text(j) = curve%message_text
enddo

if (j > 1) then
  call qp_draw_text_legend (text(1:j), 0.50_rp, 0.95_rp, '%GRAPH/LB')
endif

!

deallocate (text, symbol, line)

end subroutine tao_draw_data_graph

end module
