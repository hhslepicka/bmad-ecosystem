!+
! Subroutine tao_get_user_input (cmd_line, prompt_str, wait_flag, will_need_cmd_line_input)
!
! Subroutine to get input from the terminal.
!
! Input:
!   prompt_str -- Character(*), optional: Primpt string to print at terminal. If not
!                   present then s%global%prompt_string will be used.
!   wait_flag  -- logical, optional: Used for single mode: Wait state for get_a_char call.
!   cmd_line   -- Character(*): Command from something like Python if s%com%shell_interactive = F.
!
! Output:
!   cmd_line -- Character(*): Command line from the user.
!   will_need_cmd_line_input
!              -- logical, optional :: If s%com%shell_interactive = F, This argument is set to True
!                   when more input is needed from the calling program.
!-

subroutine tao_get_user_input (cmd_line, prompt_str, wait_flag, will_need_cmd_line_input)

use tao_mod, dummy => tao_get_user_input
use input_mod

implicit none

type do_loop_struct
  character(20) :: name ! do loop index name
  integer index, start, end, step ! for do loops
  integer n_line_start, n_line_end ! lines in each nested loop
  integer value
end type

type (do_loop_struct), allocatable, save :: loop(:)

integer i, ix, ix1, ix2
integer, save :: in_loop = 0 ! in loop nest level
integer ios, n_level
character(*) :: cmd_line
character(*), optional :: prompt_str
character(80) prompt_string

character(5) :: sub_str(9) = (/ '[[1]]', '[[2]]', '[[3]]', '[[4]]', '[[5]]', &
                            '[[6]]', '[[7]]', '[[8]]', '[[9]]' /)
character(40) tag, name
character(200), save :: saved_line
character(40) :: r_name = 'tao_get_user_input'

logical, optional :: wait_flag, will_need_cmd_line_input
logical err, wait, flush
logical, save :: init_needed = .true.

! Init single char input

prompt_string = s%global%prompt_string
if (present(prompt_str)) prompt_string = prompt_str

if (init_needed) then
#ifdef CESR_WINCVF
#else
  call init_tty_char
#endif
  init_needed = .false.
endif

! If single character input wanted then...

if (s%com%single_mode) then
  if (s%global%wait_for_CR_in_single_mode) then
    if (s%com%single_mode_buffer == '') then
      do
        read '(a)', s%com%single_mode_buffer
        if (s%com%single_mode_buffer /= '') exit
      enddo
    endif
    cmd_line(1:1) = s%com%single_mode_buffer(1:1)
    s%com%single_mode_buffer = s%com%single_mode_buffer(2:)
  else
    wait = logic_option(.true., wait_flag)
    call get_a_char (cmd_line(1:1), wait, [' '])  ! ignore blanks
    s%com%cmd_from_cmd_file = .false.
  endif
  return
endif

s%com%single_mode_buffer = '' ! Reset buffer when not in single mode

! check if we still have something from a line with multiple commands

if (s%com%multi_commands_here) then
  call string_trim (saved_line, saved_line, ix)
  if (ix == 0) then
    s%com%multi_commands_here = .false.
  else
    cmd_line = saved_line
  endif
endif

! If recalling a command from the cmd history stack...

if (s%com%use_cmd_here) then
  cmd_line = s%com%cmd
  call alias_translate (cmd_line, err)
  s%com%use_cmd_here = .false.
  return
endif

! If a command file is open then read a line from the file.

n_level = s%com%cmd_file_level
if (n_level /= 0 .and. .not. s%com%cmd_file(n_level)%paused) then

  call output_direct (do_print = s%global%command_file_print_on)

  if (.not. s%com%multi_commands_here) then
    do
      read (s%com%cmd_file(n_level)%ix_unit, '(a)', end = 8000) cmd_line
      s%com%cmd_file(n_level)%n_line = s%com%cmd_file(n_level)%n_line + 1
      s%com%cmd_from_cmd_file = .true.
      call string_trim (cmd_line, cmd_line, ix)
      if (ix /= 0) exit
    enddo

    ! nothing more to do if an alias definition

    if (cmd_line(1:5) == 'alias') then
      call out_io (s_blank$, r_name, trim(prompt_string) // ': ' // trim(cmd_line))
      return
    endif

    ! replace argument variables

    do i = 1, 9
      ix = index (cmd_line, sub_str(i))
      if (ix /= 0) cmd_line = cmd_line(1:ix-1) // &
                          trim(s%com%cmd_file(n_level)%cmd_arg(i)) // cmd_line(ix+5:)
    enddo

    loop1: do
      ix1 = index(cmd_line, '[[')
      ix2 = index(cmd_line, ']]')
      if (ix1 == 0) exit
      if (.not. allocated(loop) .or. ix2 < ix1) then
        call out_io (s_error$, r_name, 'MALFORMED LINE IN COMMAND FILE: ' // cmd_line)
        call tao_abort_command_file()
        cmd_line = ''
        return
      endif
      name = cmd_line(ix1+2:ix2-1)

      do i = 1, size(loop)
        if (name == loop(i)%name) then
          write (cmd_line, '(a, i0, a)') cmd_line(1:ix1-1), loop(i)%value, cmd_line(ix2+2:) 
          cycle loop1
        endif
      enddo

      call out_io (s_error$, r_name, 'CANNOT MATCH NAME IN [[...]] CONSTRUCT: ' // cmd_line)
      call tao_abort_command_file()
      cmd_line = ''
      return
      
    enddo loop1

    call out_io (s_blank$, r_name, trim(prompt_string) // ': ' // trim(cmd_line))
    
    ! Check if in a do loop
    call do_loop(cmd_line)
    
  endif

  call alias_translate (cmd_line, err)
  call check_for_multi_commands

  return

  8000 continue
  close (s%com%cmd_file(n_level)%ix_unit)
  s%com%cmd_file(n_level)%ix_unit = 0 
  s%com%cmd_file_level = n_level - 1 ! signal that the file has been closed
  cmd_line = ''
  ! If still lower nested command file to complete then return
  if (s%com%cmd_file_level /= 0) then
    if (s%com%cmd_file(n_level-1)%paused) then
      call out_io (s_info$, r_name, &
                      'To continue the paused command file type "continue".')
    else
      return 
    endif
  endif
  call output_direct (do_print = s%com%print_to_terminal)
endif

! Here if no command file is being used.

if (s%com%shell_interactive) then
  if (.not. s%com%multi_commands_here) then
    cmd_line = ' '
    tag = trim(prompt_string) // '> '
    s%com%cmd_from_cmd_file = .false.
    call read_a_line (tag, cmd_line)
  endif
endif

if (present (will_need_cmd_line_input)) then
  will_need_cmd_line_input = .false.
  if (.not. s%com%multi_commands_here .and. (s%com%cmd_file_level == 0 .or. s%com%cmd_file(n_level)%paused)) then
     will_need_cmd_line_input = .true.
  endif
endif

call alias_translate (cmd_line, err)
call check_for_multi_commands

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
contains

subroutine alias_translate (cmd_line, err)

character(*) cmd_line
character(100) old_cmd_line

logical err, translated

!

old_cmd_line = cmd_line ! Save old command line for the command history.
translated = .false.    ! No translation done yet
call alias_translate2 (cmd_line, err, translated)

if (translated) then
  write (*, '(2a)') 'Alias: ', trim (cmd_line)
  cmd_line = trim(cmd_line) // "  ! " // trim(old_cmd_line)  
endif

end subroutine

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
! contains

recursive subroutine alias_translate2 (cmd_line, err, translated)

character(*) cmd_line
character(100) string

integer ic, i, j
logical err, translated

! Look for a translation for the first word

call string_trim (cmd_line, cmd_line, ic)

do i = 1, s%com%n_alias

  if (cmd_line(1:ic) /= s%com%alias(i)%name) cycle

  ! We have a match...
  ! Now get the actual arguments and replace dummy args with actual args.

  string = cmd_line
  cmd_line = s%com%alias(i)%string

  do j = 1, 9
    ix = index (cmd_line, sub_str(j))
    if (ix == 0) exit
    call string_trim (string(ic+1:), string, ic)
    cmd_line = cmd_line(1:ix-1) // &
                          trim(string(1:ic)) // cmd_line(ix+5:)
  enddo

  ! Append rest of string

  call string_trim (string(ic+1:), string, ic)
  cmd_line = trim(cmd_line) // ' ' // string
  call alias_translate2 (cmd_line, err, translated) ! Translation is an alias?
  translated = .true.

  return

enddo

translated = .false.

end subroutine

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
! contains

subroutine check_for_multi_commands

integer ix
character(1) quote

!

if (cmd_line(1:5) == 'alias') return

quote = ''   ! Not in quote string
do ix = 1, len(cmd_line)

  if (quote == '') then
    select case (cmd_line(ix:ix))
    case (';')
      s%com%multi_commands_here = .true.
      saved_line = cmd_line(ix+1:)
      cmd_line = cmd_line(:ix-1)
      return

    case ("'", '"')
     quote = cmd_line(ix:ix)
    end select

  else ! quote /= ''
    if (cmd_line(ix:ix) == quote .and. cmd_line(ix-1:ix-1) /= '\') quote = ''           ! '
  endif

enddo

saved_line = ' '

end subroutine

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
! contains

subroutine do_loop (cmd_line)

use tao_command_mod

integer ix

character(*) cmd_line
character(8) :: r_name = "do_loop"
character(20) cmd_word(9)

logical err

! Check if a "do" statement

call string_trim (cmd_line, cmd_word(1), ix)
if (cmd_word(1) /= 'do' .and. cmd_word(1) /= 'enddo') return

!

call tao_cmd_split (cmd_line, 9, cmd_word, .false., err, '=,')

if (cmd_word(1) == 'do') then

  if (cmd_word(3) /= '=' .or. .not. is_integer(cmd_word(4)) .or. &
      cmd_word(5) /= ',' .or. .not. is_integer(cmd_word(6)) .or. &
     (cmd_word(7) /= '' .and. ( &
      cmd_word(7) /= ',' .or. .not. is_integer(cmd_word(8)) .or. cmd_word(9) /= ''))) then
    call out_io (s_error$, r_name, 'MALFORMED DO STATEMENT.')
    call tao_abort_command_file()
    return
  endif

  call set_loop_level (in_loop + 1)
  loop(in_loop)%name = cmd_word(2)
  read (cmd_word(4), *) loop(in_loop)%start
  read (cmd_word(6), *) loop(in_loop)%end
  loop(in_loop)%step = 1
  if (cmd_word(7) /= '') read (cmd_word(8), *) loop(in_loop)%step

  loop(in_loop)%n_line_start = s%com%cmd_file(n_level)%n_line
  loop(in_loop)%value = loop(in_loop)%start
  call out_io (s_blank$, r_name, 'Loop: ' // trim(loop(in_loop)%name) // ' = \i0\ ', &
                                                  i_array = (/ loop(in_loop)%value /) )
  cmd_line = '' ! So tao_command will not try to parse this line.

! Check if hit 'enddo'.

elseif (cmd_word(1) == 'enddo') then
  cmd_line = ''  ! so tao_command will not try to process this.
  if (in_loop == 0) then
    call out_io (s_error$, r_name, 'ENDDO FOUND WITHOUT CORRESPODING DO STATEMENT')
    call tao_abort_command_file()
    return
  endif

  loop(in_loop)%value = loop(in_loop)%value + loop(in_loop)%step
  if ((loop(in_loop)%value <= loop(in_loop)%end .and. loop(in_loop)%step > 0) .or. &
      (loop(in_loop)%value >= loop(in_loop)%end .and. loop(in_loop)%step < 0)) then
    ! rewind
    do i = s%com%cmd_file(n_level)%n_line, loop(in_loop)%n_line_start+1, -1
      backspace (s%com%cmd_file(s%com%cmd_file_level)%ix_unit)
      s%com%cmd_file(n_level)%n_line = s%com%cmd_file(n_level)%n_line - 1
    enddo
    call out_io (s_blank$, r_name, 'Loop: ' // trim(loop(in_loop)%name) // ' = \i0\ ', &
                                                  i_array = (/ loop(in_loop)%value /) )
  else
    ! looped correct number of times, now exit loop
    call set_loop_level (in_loop-1)
  endif
  ! read next line
endif
    
end subroutine do_loop

!-------------------------------------------------------------------------
!-------------------------------------------------------------------------
! contains

subroutine set_loop_level (level)

implicit none

type (do_loop_struct), allocatable, save :: temp(:)
integer level

! If going down then only need to set in_loop

if (level < in_loop) then
  in_loop = level
  return
endif

!

in_loop = level

if (allocated(loop)) then
  allocate (temp(level-1))
  temp = loop(1:level-1)
  deallocate (loop)
endif

allocate (loop(level))
if (allocated(temp)) then
  loop(1:size(temp)) = temp
  deallocate(temp)
endif

end subroutine set_loop_level

end subroutine tao_get_user_input

