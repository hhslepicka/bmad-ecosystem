!+
! Subroutine tao_open_file (file_name, iunit, full_file_name, error_severity)
!
! Subroutine to open a file for reading.
! This subroutine will first look for a file in the current directory before
! it looks in the logical_dir directory.
!
! Input:
!   file_name      -- Character(*): File name.
!   error_severity -- Integer: Severity of the error. Use s_fatal$, etc.
!                       Use -1 to not print a message if file cannot be opened.
!
! Output:
!   iunit          -- Integer: Logical unit number. Set to 0 if file not openable.
!   full_file_name -- Character(*): File name of found file.
!-

subroutine tao_open_file (file_name, iunit, full_file_name, error_severity)

  use tao_mod

  implicit none

  character(*) file_name, full_file_name
  character(20) :: r_name = 'tao_open_file'

  integer iunit, ios, error_severity
  logical valid

  ! A blank file name is always considered an error.

  if (file_name == "") then
    iunit = 0
    call out_io (s_error$, r_name, 'Blank file name')
    return
  endif

  ! open file

  iunit = lunget()
  full_file_name = file_name
  open (iunit, file = full_file_name, status = 'old', action = 'READ', iostat = ios)

  if (ios /= 0) then
    if (error_severity > 0) call out_io (error_severity, r_name, 'File not found: ' // file_name)
    iunit = 0
  endif

end subroutine
