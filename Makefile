#=============================================================================
#
# File:     Makefile
#
# Purpose:  Library makefile for the bsim package
#
# Author:   M. Palmer   7/24/00
#
# Acknowledgements:  Simon Patton's CLEO Makefile infrastructure
#                    Dave Sagan's descrip.mms 
#                    Mike Marsh and his makefiles
#
#=============================================================================
#
# $Id$
#
# $Log$
# Revision 1.5  2007/02/07 22:09:42  dcs
# added bmad_to_mad_and_xsif
#
# Revision 1.4  2007/01/30 16:14:30  dcs
# merged with branch_bmad_1.
#
# Revision 1.3.2.2  2007/01/26 18:01:48  dcs
# added bmad_to_csrtrack.
#
# Revision 1.3.2.1  2007/01/26 17:19:47  dcs
# added tune_plane_res_plot.
#
# Revision 1.3  2005/12/22 21:46:16  mjf7
# Adding dlr program analyzer to cvs
#
# Revision 1.2  2005/06/14 15:46:13  cesrulib
# *** empty log message ***
#
# Revision 1.1.1.1  2005/06/14 14:59:02  cesrulib
# Beam Simulation Code
#
# Revision 1.1.1.1  2005/06/09 00:14:31  cesrulib
# First version of ilcv simulation in repository
#
#
#=============================================================================

#-----------------------------------------------------------------------------
# Specify default source directories for code to be compiled and put into
# libraries, for module files, for code to be compiled into explicit object
# files, and initialization files to be copied to the config directory tree.
# Also specify lists of LOCAL directories to search for include files and 
# compiled module files (NOTE:  the directories $(CESR_INC) and $(CESR_MOD)
# are automatically included in this list by M.tail).  
#
# Multiple directories should be separated by spaces.
#
#
# WARNING:  DO NOT put a trailing SLASH on directory names
#
# WARNING:  EMPTY lists should have NO EXTRA SPACES after the :=
#           It is better to simply delete them.  The ones shown here 
#           are intended to show the full range of options available.
#
#
# LIB_SRC_DIRS    - Put a list of code sub-directories here.  These directories 
#                   hold code that is intended to be installed in the library
# OBJ_SRC_DIRS    - Put a list of sub-directories with code that should be 
#                   compiled into explicit .o files but NOT stored in the 
#                   archive library here (for instance, object files for 
#                   for programs).
# CONFIG_DIRS     - Put a list of sub-directories with initialization files
#                   here.   NOTE:  It is assumed that ALL config files in the
#                   CONFIG_DIRS are of the form *.*  This is to avoid copying
#                   of contained sub-directories (eg, the CVS sub-directory).
# LOCAL_INCS      - Local directories to search for include files.  It is 
#                   recommended that "partial paths" be used.  For example, 
#                   to specify that an include file from the bmad library is 
#                   needed, simply add   bmad/include   to this line.  Further 
#                   path information will be supplied by the M.tail makefile. 
# SRC_EXCLUDE     - Source files to exclude from compilation (just the base 
#                   file names should be used here)
#-----------------------------------------------------------------------------
LIB_SRC_DIRS := code
OBJ_SRC_DIRS := test tune_scan dynamic_aperture freq_map closed_orbit analyzer tune_plane_res_plot bmad_to_csrtrack bmad_to_mad_and_xsif beambeam bmad_to_autocad 
CONFIG_DIRS  :=
LOCAL_INCS   :=
SRC_EXCLUDE  :=
M_FILE_LIST  := M.tune_scan M.dynamic_aperture M.freq_map M.closed_orbit M.analyzer M.tune_plane_res_plot M.bmad_to_mad_and_xsif M.synrad M.bmad_to_autocad M.bbu

# beambeam_luminosity cannot be linked on OSF1 due to (intentionally) missing lammpio
ifneq "$(CESR_PLATFORM)" "OSF1_alpha"
  M_FILE_LIST += M.beambeam
endif


#-----------------------------------------------------------------------------
# "EXTRA" variables can be specified at the command line or hardwired here.  
# These variables are automatically appended to the relevant search paths and
# lists in M.tail
#
# EXTRA_LIB_SRC  - extra library code source directories
# EXTRA_OBJ_SRC  - extra object source directories
# EXTRA_CONFIG   - extra configuration file directories
# EXTRA_INCS     - extra include file search directories
# EXTRA_MODS     - extra compiled module search directories
# EXTRA_LIBDIR   - extra directories to search for archive library
# EXTRA_LIBS     - extra archive libraries for symbol searching
# EXTRA_OBJS     - extra object files for linking
# EXTRA_FFLAGS   - extra Fortran flags for compilation
# EXTRA_CFLAGS   - extra C flags for compilation 
# EXTRA_CXXFLAGS - extra C++ flags for compilation
# EXTRA_LFLAGS   - extra linker flags
#-----------------------------------------------------------------------------
EXTRA_LIB_SRC  :=
EXTRA_OBJ_SRC  :=
EXTRA_CONFIG   :=
EXTRA_INCS     :=
EXTRA_MODS     :=
EXTRA_LIBDIR   :=
EXTRA_LIBS     :=
EXTRA_OBJS     :=
EXTRA_FFLAGS   :=
EXTRA_CFLAGS   :=
EXTRA_CXXFLAGS :=
EXTRA_LFLAGS   :=


#------------------------------------------------
# Name of local libraries (standard and debug) 
#------------------------------------------------
ifeq "$(LIBNAME)" ""
  WHERE   := $(shell pwd)
  LIBNAME := $(notdir $(WHERE))
endif

#------------------------------------------------
# Place object files in the locallib area
#------------------------------------------------
OBJ_OUT_DIR   = $(locallib)



#------------------------------------------------
# Include the standard CESR M.tail makefile
#------------------------------------------------
ifeq "$(BMAD_DIST)" "TRUE"
  include $(BMAD_GMAKE)/M.tail
else
  include $(CESR_GMAKE)/M.tail
endif



