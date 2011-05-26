module photon_reflection_mod

use precision_def
use physical_constants

! Structure for holding the reflection probability tables.
! For a custom reflection calc: 
!   See the photon_reflection_init routine for an example of how to set up the reflection tables.
! Note: It is assumed that for each table that the energy(:) values are equally spaced.
!       Also must have angle(1) = 0 and the last angle(n) = 90.

type interval1_coef_struct
  real(rp) c0, c1, n_exp
end type

type photon_reflect_table_struct
  real(rp), allocatable :: angle(:)          ! Vector of angle values for %p_reflect
  real(rp), allocatable :: energy(:)         ! Vector of energy values for %p_reflect
  type (interval1_coef_struct), allocatable :: int1(:)
  real(rp), allocatable :: p_reflect(:,:)    ! (ev, angle) Logarithm of reflection probability
  real(rp) max_energy                        ! maximum energy for this table
  real(rp), allocatable :: reflect_prob(:)   ! Scratch space
end type

type (photon_reflect_table_struct), allocatable, target, save :: photon_reflect_table(:)
logical, save :: photon_reflect_table_init_needed = .true.

private photon_reflection_init

contains

!---------------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------------
!+
! Subroutine photon_reflection_init ()
!
! Initialization routine for proton reflection probability calculation.
! This routine is private and not meant for general 
!-

Subroutine photon_reflection_init ()

use nr

implicit none

type (photon_reflect_table_struct), pointer :: prt

character(100) datafile
character(100) line

real(rp) f, deriv, dprob

integer :: n_energy, n_angles
integer i, j, k

! There are four tables.

allocate(photon_reflect_table(4))
photon_reflect_table_init_needed = .false.

! Table 1: 0 - 500 eV, 10eV steps.

prt => photon_reflect_table(1)

n_energy = 58;  n_angles = 16
allocate(prt%angle(n_angles), prt%energy(n_energy), prt%p_reflect(n_angles,n_energy), prt%reflect_prob(n_angles), prt%int1(n_energy))

prt%angle = [0, 1, 2, 3, 4, 5, 6, 7, 10, 15, 20, 30, 45, 60, 75, 90]

prt%energy = [(i, i = 30, 600, 10)]
prt%max_energy = prt%energy(n_energy)

! Angle:                  0         1         2         3         4         5         6         7        10        15        20        30        45        60        75        90
prt%p_reflect(:,  1) = [1.00, 0.923630, 0.852910, 0.787263, 0.726194, 0.669267, 0.616103, 0.566372, 0.435039, 0.263631, 0.137873, 0.003234, 0.001180, 0.000727, 0.001980, 0.002673]  !   30 eV
prt%p_reflect(:,  2) = [1.00, 0.914839, 0.836482, 0.764004, 0.696633, 0.633721, 0.574715, 0.519143, 0.369149, 0.156553, 0.008207, 0.004792, 0.000364, 0.000747, 0.002038, 0.002560]  !   40 eV
prt%p_reflect(:,  3) = [1.00, 0.907185, 0.822053, 0.743165, 0.669344, 0.599597, 0.533044, 0.468867, 0.281784, 0.040299, 0.020329, 0.005244, 0.000101, 0.000548, 0.001287, 0.001540]  !   50 eV
prt%p_reflect(:,  4) = [1.00, 0.876644, 0.765027, 0.660928, 0.560698, 0.460587, 0.356528, 0.250923, 0.107430, 0.045740, 0.021179, 0.003942, 0.000023, 0.000353, 0.000731, 0.000852]  !   60 eV
prt%p_reflect(:,  5) = [1.00, 0.797371, 0.636611, 0.509502, 0.409164, 0.329940, 0.267264, 0.217511, 0.120393, 0.047830, 0.019475, 0.002769, 0.000003, 0.000258, 0.000501, 0.000580]  !   70 eV
prt%p_reflect(:,  6) = [1.00, 0.841165, 0.706888, 0.592949, 0.496061, 0.413634, 0.343601, 0.284271, 0.157157, 0.055118, 0.018563, 0.001819, 0.000005, 0.000124, 0.000241, 0.000281]  !   80 eV
prt%p_reflect(:,  7) = [1.00, 0.845503, 0.713926, 0.601244, 0.504400, 0.421059, 0.349420, 0.288059, 0.154703, 0.048860, 0.014359, 0.001109, 0.000003, 0.000067, 0.000134, 0.000157]  !   90 eV
prt%p_reflect(:,  8) = [1.00, 0.844784, 0.712489, 0.598954, 0.501079, 0.416552, 0.343642, 0.281025, 0.145071, 0.040963, 0.010558, 0.000670, 0.000001, 0.000042, 0.000085, 0.000100]  !  100 eV
prt%p_reflect(:,  9) = [1.00, 0.843757, 0.710551, 0.596065, 0.497137, 0.411458, 0.337346, 0.273563, 0.135384, 0.033808, 0.007563, 0.000403, 0.000001, 0.000028, 0.000057, 0.000066]  !  110 eV
prt%p_reflect(:, 10) = [1.00, 0.842813, 0.708773, 0.593417, 0.493520, 0.406765, 0.331513, 0.266606, 0.126259, 0.027518, 0.005272, 0.000245, 0.000000, 0.000019, 0.000038, 0.000045]  !  120 eV
prt%p_reflect(:, 11) = [1.00, 0.846440, 0.714661, 0.600327, 0.500353, 0.412587, 0.335580, 0.268421, 0.121416, 0.022239, 0.003534, 0.000146, 0.000000, 0.000012, 0.000024, 0.000028]  !  130 eV
prt%p_reflect(:, 12) = [1.00, 0.847463, 0.716095, 0.601482, 0.500548, 0.411213, 0.332178, 0.262769, 0.110971, 0.016632, 0.002241, 0.000092, 0.000000, 0.000008, 0.000016, 0.000019]  !  140 eV
prt%p_reflect(:, 13) = [1.00, 0.847936, 0.716603, 0.601475, 0.499443, 0.408468, 0.327381, 0.255745, 0.099909, 0.012106, 0.001404, 0.000061, 0.000000, 0.000005, 0.000011, 0.000013]  !  150 eV
prt%p_reflect(:, 14) = [1.00, 0.849048, 0.718178, 0.602765, 0.499676, 0.406917, 0.323466, 0.249184, 0.088796, 0.008536, 0.000869, 0.000042, 0.000000, 0.000004, 0.000008, 0.000009]  !  160 eV
prt%p_reflect(:, 15) = [1.00, 0.849912, 0.719332, 0.603514, 0.499271, 0.404630, 0.318701, 0.241677, 0.077548, 0.005888, 0.000543, 0.000029, 0.000000, 0.000003, 0.000005, 0.000006]  !  170 eV
prt%p_reflect(:, 16) = [1.00, 0.852839, 0.724046, 0.608864, 0.504099, 0.407789, 0.319152, 0.238724, 0.068450, 0.004020, 0.000341, 0.000021, 0.000000, 0.000002, 0.000004, 0.000004]  !  180 eV
prt%p_reflect(:, 17) = [1.00, 0.858405, 0.733220, 0.619729, 0.514717, 0.416189, 0.323465, 0.237613, 0.058127, 0.002595, 0.000212, 0.000014, 0.000000, 0.000001, 0.000003, 0.000003]  !  190 eV
prt%p_reflect(:, 18) = [1.00, 0.862059, 0.739107, 0.626306, 0.520288, 0.418917, 0.321558, 0.229973, 0.046230, 0.001630, 0.000137, 0.000010, 0.000000, 0.000001, 0.000002, 0.000002]  !  200 eV
prt%p_reflect(:, 19) = [1.00, 0.864957, 0.743680, 0.631119, 0.523660, 0.418912, 0.316237, 0.218374, 0.035009, 0.001016, 0.000092, 0.000007, 0.000000, 0.000001, 0.000001, 0.000002]  !  210 eV
prt%p_reflect(:, 20) = [1.00, 0.867167, 0.747034, 0.634260, 0.524879, 0.416129, 0.307353, 0.202790, 0.025410, 0.000635, 0.000064, 0.000005, 0.000000, 0.000000, 0.000001, 0.000001]  !  220 eV
prt%p_reflect(:, 21) = [1.00, 0.868010, 0.747969, 0.634138, 0.522105, 0.408662, 0.293255, 0.182559, 0.017927, 0.000408, 0.000047, 0.000004, 0.000000, 0.000000, 0.000001, 0.000001]  !  230 eV
prt%p_reflect(:, 22) = [1.00, 0.868608, 0.748479, 0.633443, 0.518576, 0.400127, 0.277739, 0.161584, 0.012587, 0.000268, 0.000035, 0.000003, 0.000000, 0.000000, 0.000001, 0.000001]  !  240 eV
prt%p_reflect(:, 23) = [1.00, 0.869093, 0.748781, 0.632424, 0.514498, 0.390585, 0.260689, 0.140025, 0.008758, 0.000179, 0.000027, 0.000002, 0.000000, 0.000000, 0.000000, 0.000001]  !  250 eV
prt%p_reflect(:, 24) = [1.00, 0.869713, 0.749314, 0.631658, 0.510528, 0.380677, 0.242718, 0.118934, 0.006079, 0.000123, 0.000021, 0.000002, 0.000000, 0.000000, 0.000000, 0.000000]  !  260 eV
prt%p_reflect(:, 25) = [1.00, 0.871206, 0.751406, 0.632955, 0.508822, 0.372634, 0.225708, 0.099769, 0.004209, 0.000086, 0.000016, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000]  !  270 eV
prt%p_reflect(:, 26) = [1.00, 0.873681, 0.755198, 0.636343, 0.509008, 0.365152, 0.207182, 0.080861, 0.002850, 0.000061, 0.000012, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000]  !  280 eV
prt%p_reflect(:, 27) = [1.00, 0.875698, 0.758148, 0.638462, 0.507226, 0.354333, 0.184807, 0.062983, 0.001919, 0.000044, 0.000010, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000]  !  290 eV
prt%p_reflect(:, 28) = [1.00, 0.877463, 0.760624, 0.639822, 0.504066, 0.340722, 0.159984, 0.047634, 0.001289, 0.000033, 0.000007, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000]  !  300 eV
prt%p_reflect(:, 29) = [1.00, 0.879036, 0.762735, 0.640556, 0.499626, 0.324251, 0.133994, 0.035277, 0.000867, 0.000025, 0.000006, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000]  !  310 eV
prt%p_reflect(:, 30) = [1.00, 0.880457, 0.764547, 0.640741, 0.493918, 0.304769, 0.108476, 0.025783, 0.000585, 0.000020, 0.000005, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  320 eV
prt%p_reflect(:, 31) = [1.00, 0.881739, 0.766085, 0.640393, 0.486857, 0.282072, 0.085085, 0.018704, 0.000396, 0.000015, 0.000004, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  330 eV
prt%p_reflect(:, 32) = [1.00, 0.882900, 0.767371, 0.639523, 0.478339, 0.256087, 0.065058, 0.013521, 0.000269, 0.000012, 0.000003, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  340 eV
prt%p_reflect(:, 33) = [1.00, 0.883935, 0.768396, 0.638090, 0.468152, 0.226933, 0.048854, 0.009760, 0.000185, 0.000010, 0.000002, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  350 eV
prt%p_reflect(:, 34) = [1.00, 0.884720, 0.768917, 0.635705, 0.455606, 0.194939, 0.036249, 0.007042, 0.000128, 0.000008, 0.000002, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  360 eV
prt%p_reflect(:, 35) = [1.00, 0.884984, 0.768436, 0.631684, 0.439896, 0.161962, 0.026861, 0.005109, 0.000091, 0.000007, 0.000002, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  370 eV
prt%p_reflect(:, 36) = [1.00, 0.885225, 0.767888, 0.627357, 0.422529, 0.131073, 0.019979, 0.003722, 0.000066, 0.000006, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  380 eV
prt%p_reflect(:, 37) = [1.00, 0.885449, 0.767270, 0.622660, 0.403117, 0.103616, 0.014899, 0.002716, 0.000049, 0.000005, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  390 eV
prt%p_reflect(:, 38) = [1.00, 0.885644, 0.766557, 0.617524, 0.381343, 0.080539, 0.011141, 0.001985, 0.000037, 0.000004, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  400 eV
prt%p_reflect(:, 39) = [1.00, 0.885792, 0.765714, 0.611871, 0.356913, 0.061987, 0.008352, 0.001451, 0.000029, 0.000004, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  410 eV
prt%p_reflect(:, 40) = [1.00, 0.885893, 0.764740, 0.605665, 0.329641, 0.047513, 0.006275, 0.001062, 0.000024, 0.000003, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  420 eV
prt%p_reflect(:, 41) = [1.00, 0.885942, 0.763626, 0.598869, 0.299540, 0.036419, 0.004723, 0.000777, 0.000020, 0.000003, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  430 eV
prt%p_reflect(:, 42) = [1.00, 0.886133, 0.762744, 0.591999, 0.267325, 0.027974, 0.003558, 0.000568, 0.000018, 0.000003, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  440 eV
prt%p_reflect(:, 43) = [1.00, 0.886417, 0.761986, 0.584761, 0.232890, 0.021478, 0.002675, 0.000415, 0.000016, 0.000003, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  450 eV
prt%p_reflect(:, 44) = [1.00, 0.886550, 0.760878, 0.576391, 0.197077, 0.016503, 0.002009, 0.000305, 0.000015, 0.000002, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  460 eV
prt%p_reflect(:, 45) = [1.00, 0.886538, 0.759435, 0.566871, 0.162171, 0.012709, 0.001511, 0.000227, 0.000015, 0.000002, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  470 eV
prt%p_reflect(:, 46) = [1.00, 0.886313, 0.757523, 0.555930, 0.130275, 0.009806, 0.001140, 0.000173, 0.000016, 0.000002, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  480 eV
prt%p_reflect(:, 47) = [1.00, 0.885852, 0.755101, 0.543447, 0.102964, 0.007590, 0.000867, 0.000139, 0.000017, 0.000003, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  490 eV
prt%p_reflect(:, 48) = [1.00, 0.885095, 0.752058, 0.529213, 0.080682, 0.005902, 0.000673, 0.000121, 0.000019, 0.000003, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  500 eV
prt%p_reflect(:, 49) = [1.00, 0.883883, 0.748103, 0.512804, 0.063037, 0.004630, 0.000544, 0.000118, 0.000022, 0.000003, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  510 eV
prt%p_reflect(:, 50) = [1.00, 0.881610, 0.742113, 0.492838, 0.049295, 0.003711, 0.000484, 0.000137, 0.000028, 0.000004, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  520 eV
prt%p_reflect(:, 51) = [1.00, 0.876814, 0.731527, 0.467043, 0.038997, 0.003200, 0.000537, 0.000202, 0.000043, 0.000007, 0.000002, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  530 eV
prt%p_reflect(:, 52) = [1.00, 0.837560, 0.666826, 0.406574, 0.039489, 0.006459, 0.002196, 0.001048, 0.000210, 0.000033, 0.000008, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000]  !  540 eV
prt%p_reflect(:, 53) = [1.00, 0.666556, 0.404251, 0.162926, 0.006091, 0.001012, 0.000697, 0.000441, 0.000098, 0.000016, 0.000004, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  550 eV
prt%p_reflect(:, 54) = [1.00, 0.699636, 0.443395, 0.169003, 0.002921, 0.000161, 0.000294, 0.000216, 0.000048, 0.000008, 0.000002, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  560 eV
prt%p_reflect(:, 55) = [1.00, 0.710809, 0.456262, 0.163190, 0.002018, 0.000080, 0.000227, 0.000166, 0.000036, 0.000006, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  570 eV
prt%p_reflect(:, 56) = [1.00, 0.718205, 0.464220, 0.152854, 0.001488, 0.000082, 0.000200, 0.000139, 0.000029, 0.000005, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  580 eV
prt%p_reflect(:, 57) = [1.00, 0.723902, 0.469855, 0.139123, 0.001147, 0.000107, 0.000185, 0.000120, 0.000025, 0.000004, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  590 eV
prt%p_reflect(:, 58) = [1.00, 0.728577, 0.474020, 0.122734, 0.000924, 0.000137, 0.000175, 0.000107, 0.000021, 0.000003, 0.000001, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000]  !  600 eV

! Table 2: 500 - 1500 eV, 20 eV steps.

prt => photon_reflect_table(2)

n_energy = 41;  n_angles = 11
allocate(prt%angle(n_angles), prt%energy(n_energy), prt%p_reflect(n_angles,n_energy), prt%reflect_prob(n_angles), prt%int1(n_energy))

prt%angle = [0.0, 0.4, 0.8, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 90.0]

prt%energy = [(i, i = 600, 1400, 20)]
prt%max_energy = prt%energy(n_energy)

! Angle:                  0        0.4       0.8       1.0       1.5      2.0        2.5      3.0       3.5       4.0       90 
prt%p_reflect(:,  1) = [1.00,  0.88515,  0.779423, 0.728577, 0.603364, 0.47402,  0.326451, 0.122734, 1.12E-02, 9.24E-04,  0.00]  !  600 eV
prt%p_reflect(:,  2) = [1.00,  0.888952, 0.785964, 0.73605,  0.611581, 0.479459, 0.320319, 8.68E-02, 7.15E-03, 6.86E-04,  0.00]  !  620 eV
prt%p_reflect(:,  3) = [1.00,  0.89217,  0.791486, 0.742331, 0.61824,  0.4828,   0.309234, 5.64E-02, 4.79E-03, 5.96E-04,  0.00]  !  640 eV
prt%p_reflect(:,  4) = [1.00,  0.895213, 0.796715, 0.748275, 0.624436, 0.485172, 0.292844, 3.62E-02, 3.38E-03, 5.66E-04,  0.00]  !  660 eV
prt%p_reflect(:,  5) = [1.00,  0.897529, 0.800629, 0.752647, 0.628449, 0.484347, 0.26654,  2.36E-02, 2.47E-03, 5.46E-04,  0.00]  !  680 eV
prt%p_reflect(:,  6) = [1.00,  0.899056, 0.803106, 0.755293, 0.630033, 0.479889, 0.227572, 1.58E-02, 1.90E-03, 5.37E-04,  0.00]  !  700 eV
prt%p_reflect(:,  7) = [1.00,  0.900817, 0.806018, 0.758458, 0.632236, 0.475263, 0.177858, 1.11E-02, 1.55E-03, 5.32E-04,  0.00]  !  720 eV
prt%p_reflect(:,  8) = [1.00,  0.902563, 0.808905, 0.761591, 0.634282, 0.469249, 0.124178, 8.04E-03, 1.32E-03, 5.19E-04,  0.00]  !  740 eV
prt%p_reflect(:,  9) = [1.00,  0.904161, 0.811519, 0.764387, 0.635731, 0.460933, 8.20E-02, 6.01E-03, 1.15E-03, 4.98E-04,  0.00]  !  760 eV
prt%p_reflect(:, 10) = [1.00,  0.905706, 0.814038, 0.767063, 0.636862, 0.450115, 5.48E-02, 4.64E-03, 1.03E-03, 4.73E-04,  0.00]  !  780 eV
prt%p_reflect(:, 11) = [1.00,  0.907257, 0.816568, 0.769744, 0.637824, 0.436119, 3.79E-02, 3.68E-03, 9.32E-04, 4.43E-04,  0.00]  !  800 eV
prt%p_reflect(:, 12) = [1.00,  0.908708, 0.818911, 0.772189, 0.638252, 0.417188, 2.71E-02, 2.99E-03, 8.47E-04, 4.09E-04,  0.00]  !  820 eV
prt%p_reflect(:, 13) = [1.00,  0.91005,  0.821051, 0.774377, 0.638085, 0.391021, 1.99E-02, 2.48E-03, 7.71E-04, 3.75E-04,  0.00]  !  840 eV
prt%p_reflect(:, 14) = [1.00,  0.911205, 0.822835, 0.776121, 0.637024, 0.353493, 1.50E-02, 2.10E-03, 7.02E-04, 3.42E-04,  0.00]  !  860 eV
prt%p_reflect(:, 15) = [1.00,  0.912213, 0.824341, 0.777513, 0.635141, 0.298823, 1.15E-02, 1.80E-03, 6.40E-04, 3.10E-04,  0.00]  !  880 eV
prt%p_reflect(:, 16) = [1.00,  0.913159, 0.825722, 0.778735, 0.632627, 0.22567,  9.01E-03, 1.57E-03, 5.85E-04, 2.82E-04,  0.00]  !  900 eV
prt%p_reflect(:, 17) = [1.00,  0.914065, 0.827022, 0.77984,  0.629489, 0.154709, 7.21E-03, 1.39E-03, 5.35E-04, 2.55E-04,  0.00]  !  920 eV
prt%p_reflect(:, 18) = [1.00,  0.915072, 0.828504, 0.781148, 0.626074, 0.105486, 5.88E-03, 1.24E-03, 4.89E-04, 2.31E-04,  0.00]  !  940 eV
prt%p_reflect(:, 19) = [1.00,  0.916083, 0.829987, 0.782436, 0.621958, 7.44E-02, 4.87E-03, 1.11E-03, 4.46E-04, 2.08E-04,  0.00]  !  960 eV
prt%p_reflect(:, 20) = [1.00,  0.917057, 0.831391, 0.783604, 0.616819, 5.44E-02, 4.10E-03, 1.01E-03, 4.06E-04, 1.88E-04,  0.00]  !  980 eV
prt%p_reflect(:, 21) = [1.00,  0.917976, 0.832683, 0.784611, 0.610411, 4.09E-02, 3.49E-03, 9.10E-04, 3.68E-04, 1.70E-04,  0.00]  ! 1000 eV
prt%p_reflect(:, 22) = [1.00,  0.918821, 0.833822, 0.785398, 0.602283, 3.15E-02, 3.01E-03, 8.26E-04, 3.34E-04, 1.53E-04,  0.00]  ! 1020 eV
prt%p_reflect(:, 23) = [1.00,  0.919599, 0.834819, 0.785978, 0.592039, 2.47E-02, 2.62E-03, 7.51E-04, 3.03E-04, 1.39E-04,  0.00]  ! 1040 eV
prt%p_reflect(:, 24) = [1.00,  0.920392, 0.835836, 0.78655,  0.579332, 1.97E-02, 2.30E-03, 6.84E-04, 2.75E-04, 1.26E-04,  0.00]  ! 1060 eV
prt%p_reflect(:, 25) = [1.00,  0.921166, 0.836803, 0.787025, 0.562967, 1.60E-02, 2.04E-03, 6.23E-04, 2.50E-04, 1.14E-04,  0.00]  ! 1080 eV
prt%p_reflect(:, 26) = [1.00,  0.921901, 0.83768,  0.787345, 0.540993, 1.31E-02, 1.82E-03, 5.68E-04, 2.27E-04, 1.04E-04,  0.00]  ! 1100 eV
prt%p_reflect(:, 27) = [1.00,  0.922597, 0.838463, 0.787499, 0.509931, 1.09E-02, 1.63E-03, 5.19E-04, 2.07E-04, 9.54E-05,  0.00]  ! 1120 eV
prt%p_reflect(:, 28) = [1.00,  0.923256, 0.839157, 0.787488, 0.462995, 9.18E-03, 1.47E-03, 4.74E-04, 1.88E-04, 8.76E-05,  0.00]  ! 1140 eV
prt%p_reflect(:, 29) = [1.00,  0.923879, 0.839762, 0.787305, 0.387686, 7.79E-03, 1.34E-03, 4.34E-04, 1.72E-04, 8.07E-05,  0.00]  ! 1160 eV
prt%p_reflect(:, 30) = [1.00,  0.924467, 0.840273, 0.786931, 0.28342,  6.69E-03, 1.22E-03, 3.98E-04, 1.58E-04, 7.47E-05,  0.00]  ! 1180 eV
prt%p_reflect(:, 31) = [1.00,  0.925022, 0.840693, 0.786362, 0.195087, 5.79E-03, 1.11E-03, 3.65E-04, 1.45E-04, 6.94E-05,  0.00]  ! 1200 eV
prt%p_reflect(:, 32) = [1.00,  0.92554,  0.841011, 0.785569, 0.138541, 5.05E-03, 1.02E-03, 3.35E-04, 1.34E-04, 6.47E-05,  0.00]  ! 1220 eV
prt%p_reflect(:, 33) = [1.00,  0.926026, 0.841232, 0.784546, 0.102536, 4.45E-03, 9.36E-04, 3.08E-04, 1.24E-04, 6.05E-05,  0.00]  ! 1240 eV
prt%p_reflect(:, 34) = [1.00,  0.926477, 0.841345, 0.78325,  7.83E-02, 3.95E-03, 8.63E-04, 2.85E-04, 1.15E-04, 5.69E-05,  0.00]  ! 1260 eV
prt%p_reflect(:, 35) = [1.00,  0.926895, 0.841344, 0.781647, 6.13E-02, 3.53E-03, 7.97E-04, 2.63E-04, 1.07E-04, 5.36E-05,  0.00]  ! 1280 eV
prt%p_reflect(:, 36) = [1.00,  0.927276, 0.841221, 0.779704, 4.89E-02, 3.18E-03, 7.38E-04, 2.44E-04, 1.00E-04, 5.07E-05,  0.00]  ! 1300 eV
prt%p_reflect(:, 37) = [1.00,  0.927611, 0.840942, 0.777322, 3.97E-02, 2.88E-03, 6.85E-04, 2.27E-04, 9.42E-05, 4.82E-05,  0.00]  ! 1320 eV
prt%p_reflect(:, 38) = [1.00,  0.927894, 0.840486, 0.77442,  3.26E-02, 2.62E-03, 6.38E-04, 2.12E-04, 8.89E-05, 4.59E-05,  0.00]  ! 1340 eV
prt%p_reflect(:, 39) = [1.00,  0.928121, 0.839831, 0.770888, 2.71E-02, 2.40E-03, 5.96E-04, 1.99E-04, 8.43E-05, 4.40E-05,  0.00]  ! 1360 eV
prt%p_reflect(:, 40) = [1.00,  0.928279, 0.838923, 0.766521, 2.27E-02, 2.22E-03, 5.59E-04, 1.87E-04, 8.04E-05, 4.23E-05,  0.00]  ! 1380 eV
prt%p_reflect(:, 41) = [1.00,  0.928361, 0.837729, 0.76112,  1.92E-02, 2.06E-03, 5.25E-04, 1.77E-04, 7.71E-05, 4.09E-05,  0.00]  ! 1400 eV

! Table 3: 1500 - 1600 eV, 10 eV steps. There is a resonance here

prt => photon_reflect_table(3)

n_energy = 21;  n_angles = 10
allocate(prt%angle(n_angles), prt%energy(n_energy), prt%p_reflect(n_angles,n_energy), prt%reflect_prob(n_angles), prt%int1(n_energy))

prt%angle = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.5, 2.0, 2.5, 90.0]

prt%energy = [(i, i = 1400, 1600, 10)]
prt%max_energy = prt%energy(n_energy)

! Angle:                  0        0.2       0.4       0.6       0.8       1.0       1.5      2.0        2.5      90 
prt%p_reflect(:,  1) = [1.00,  0.964733, 0.928361, 0.887882, 0.837729, 0.76112,  1.92E-02, 2.06E-03, 5.25E-04, 0.00]  ! 1400 eV
prt%p_reflect(:,  2) = [1.00,  0.964753, 0.928349, 0.887692, 0.83694,  0.757774, 1.77E-02, 1.99E-03, 5.11E-04, 0.00]  ! 1410 eV
prt%p_reflect(:,  3) = [1.00,  0.964772, 0.928333, 0.887492, 0.836114, 0.754152, 1.64E-02, 1.92E-03, 4.96E-04, 0.00]  ! 1420 eV
prt%p_reflect(:,  4) = [1.00,  0.964765, 0.928262, 0.887192, 0.835088, 0.749821, 1.52E-02, 1.86E-03, 4.84E-04, 0.00]  ! 1430 eV
prt%p_reflect(:,  5) = [1.00,  0.964748, 0.928166, 0.886845, 0.833949, 0.744912, 1.42E-02, 1.81E-03, 4.72E-04, 0.00]  ! 1440 eV
prt%p_reflect(:,  6) = [1.00,  0.96471,  0.928028, 0.886419, 0.832637, 0.739184, 1.32E-02, 1.76E-03, 4.62E-04, 0.00]  ! 1450 eV
prt%p_reflect(:,  7) = [1.00,  0.964643, 0.927823, 0.885868, 0.831056, 0.732198, 1.23E-02, 1.71E-03, 4.53E-04, 0.00]  ! 1460 eV
prt%p_reflect(:,  8) = [1.00,  0.964566, 0.927598, 0.885272, 0.829343, 0.724123, 1.15E-02, 1.67E-03, 4.44E-04, 0.00]  ! 1470 eV
prt%p_reflect(:,  9) = [1.00,  0.964413, 0.927206, 0.884368, 0.826982, 0.712953, 1.08E-02, 1.64E-03, 4.39E-04, 0.00]  ! 1480 eV
prt%p_reflect(:, 10) = [1.00,  0.964255, 0.926799, 0.883424, 0.82446,  0.699552, 1.01E-02, 1.61E-03, 4.34E-04, 0.00]  ! 1490 eV
prt%p_reflect(:, 11) = [1.00,  0.963984, 0.926145, 0.882012, 0.820895, 0.679076, 9.56E-03, 1.59E-03, 4.33E-04, 0.00]  ! 1500 eV
prt%p_reflect(:, 12) = [1.00,  0.963656, 0.925362, 0.880338, 0.816624, 0.649261, 9.05E-03, 1.58E-03, 4.33E-04, 0.00]  ! 1510 eV
prt%p_reflect(:, 13) = [1.00,  0.963165, 0.924214, 0.877952, 0.810593, 0.593463, 8.60E-03, 1.58E-03, 4.39E-04, 0.00]  ! 1520 eV
prt%p_reflect(:, 14) = [1.00,  0.96225,  0.922125, 0.87373,  0.799945, 0.432662, 8.23E-03, 1.62E-03, 4.55E-04, 0.00]  ! 1530 eV
prt%p_reflect(:, 15) = [1.00,  0.961267, 0.919857, 0.869026, 0.787008, 0.253593, 7.95E-03, 1.65E-03, 4.71E-04, 0.00]  ! 1540 eV
prt%p_reflect(:, 16) = [1.00,  0.948514, 0.889857, 0.798969, 0.289009, 5.61E-02, 8.77E-03, 2.26E-03, 7.09E-04, 0.00]  ! 1550 eV
prt%p_reflect(:, 17) = [1.00,  0.74478,  0.514904, 0.30286,  0.150061, 7.05E-02, 1.24E-02, 2.83E-03, 8.95E-04, 0.00]  ! 1560 eV
prt%p_reflect(:, 18) = [1.00,  0.855225, 0.71287,  0.552627, 0.353525, 0.152114, 1.27E-02, 1.94E-03, 4.73E-04, 0.00]  ! 1570 eV
prt%p_reflect(:, 19) = [1.00,  0.864307, 0.730513, 0.579964, 0.389233, 0.174535, 1.26E-02, 1.75E-03, 4.07E-04, 0.00]  ! 1580 eV
prt%p_reflect(:, 20) = [1.00,  0.87228,  0.746094, 0.604425, 0.423324, 0.200739, 1.25E-02, 1.57E-03, 3.46E-04, 0.00]  ! 1590 eV
prt%p_reflect(:, 21) = [1.00,  0.876128, 0.753518, 0.615783, 0.438769, 0.212852, 1.22E-02, 1.45E-03, 3.10E-04, 0.00]  ! 1600 eV

! Table 4: 1600 - 5000 eV, 50 eV steps

prt => photon_reflect_table(4)

n_energy = 69;  n_angles = 11
allocate(prt%angle(n_angles), prt%energy(n_energy), prt%p_reflect(n_angles,n_energy), prt%reflect_prob(n_angles), prt%int1(n_energy))

prt%angle = [0.0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0, 1.5, 2.0, 2.5, 90.0]

prt%energy = [(i, i = 1600, 5000, 50)]
prt%max_energy = prt%energy(n_energy)

! Angle:                  0        0.2       0.4       0.5       0.6       0.8       1.0       1.5      2.0        2.5      90 
prt%p_reflect(:,  1) = [1.00,  0.876128, 0.753518, 0.687795, 0.615783, 0.438769, 0.212852, 1.22E-02, 1.45E-03, 3.10E-04, 0.00]  ! 1600 eV
prt%p_reflect(:,  2) = [1.00,  0.886289, 0.772755, 0.711509, 0.6440,   0.474435, 0.236703, 1.02E-02, 1.03E-03, 2.04E-04, 0.00]  ! 1650 eV
prt%p_reflect(:,  3) = [1.00,  0.891608, 0.782471, 0.723064, 0.656997, 0.487096, 0.235433, 8.18E-03, 7.48E-04, 1.47E-04, 0.00]  ! 1700 eV
prt%p_reflect(:,  4) = [1.00,  0.895414, 0.78921,  0.730808, 0.665181, 0.491873, 0.223279, 6.43E-03, 5.53E-04, 1.09E-04, 0.00]  ! 1750 eV
prt%p_reflect(:,  5) = [1.00,  0.898511, 0.794547, 0.736736, 0.671017, 0.492221, 0.204201, 5.00E-03, 4.13E-04, 8.34E-05, 0.00]  ! 1800 eV
prt%p_reflect(:,  6) = [1.00,  0.901094, 0.798869, 0.741348, 0.67513,  0.488954, 0.180385, 3.88E-03, 3.12E-04, 6.53E-05, 0.00]  ! 1850 eV
prt%p_reflect(:,  7) = [1.00,  0.903319, 0.802487, 0.745042, 0.678018, 0.482693, 0.15437,  3.00E-03, 2.38E-04, 5.20E-05, 0.00]  ! 1900 eV
prt%p_reflect(:,  8) = [1.00,  0.905259, 0.805536, 0.747979, 0.679851, 0.473347, 0.128209, 2.32E-03, 1.84E-04, 4.22E-05, 0.00]  ! 1950 eV
prt%p_reflect(:,  9) = [1.00,  0.906995, 0.80818,  0.750370, 0.680893, 0.461094, 0.104131, 1.80E-03, 1.44E-04, 3.46E-05, 0.00]  ! 2000 eV
prt%p_reflect(:, 10) = [1.00,  0.90861,  0.810576, 0.752411, 0.681366, 0.445881, 8.33E-02, 1.40E-03, 1.13E-04, 2.88E-05, 0.00]  ! 2050 eV
prt%p_reflect(:, 11) = [1.00,  0.910182, 0.812868, 0.754259, 0.68141,  0.42712,  6.59E-02, 1.09E-03, 9.07E-05, 2.42E-05, 0.00]  ! 2100 eV
prt%p_reflect(:, 12) = [1.00,  0.911658, 0.814957, 0.755804, 0.680894, 0.404306, 5.19E-02, 8.56E-04, 7.33E-05, 2.05E-05, 0.00]  ! 2150 eV
prt%p_reflect(:, 13) = [1.00,  0.913056, 0.816879, 0.757082, 0.679836, 0.37686,  4.08E-02, 6.73E-04, 5.99E-05, 1.75E-05, 0.00]  ! 2200 eV
prt%p_reflect(:, 14) = [1.00,  0.914373, 0.818621, 0.758063, 0.678145, 0.344026, 3.21E-02, 5.33E-04, 4.96E-05, 1.51E-05, 0.00]  ! 2250 eV
prt%p_reflect(:, 15) = [1.00,  0.915629, 0.820224, 0.758801, 0.675868, 0.306035, 2.53E-02, 4.24E-04, 4.15E-05, 1.31E-05, 0.00]  ! 2300 eV
prt%p_reflect(:, 16) = [1.00,  0.916822, 0.82168,  0.759269, 0.672904, 0.263671, 2.01E-02, 3.39E-04, 3.52E-05, 1.15E-05, 0.00]  ! 2350 eV
prt%p_reflect(:, 17) = [1.00,  0.917971, 0.82303,  0.759524, 0.6693,   0.219897, 1.59E-02, 2.73E-04, 3.00E-05, 1.00E-05, 0.00]  ! 2400 eV
prt%p_reflect(:, 18) = [1.00,  0.919062, 0.824231, 0.759480, 0.664821, 0.177833, 1.27E-02, 2.21E-04, 2.59E-05, 8.88E-06, 0.00]  ! 2450 eV
prt%p_reflect(:, 19) = [1.00,  0.920123, 0.825359, 0.759254, 0.659615, 0.141286, 1.02E-02, 1.80E-04, 2.25E-05, 7.85E-06, 0.00]  ! 2500 eV
prt%p_reflect(:, 20) = [1.00,  0.921138, 0.826363, 0.758743, 0.653379, 0.111138, 8.20E-03, 1.48E-04, 1.97E-05, 6.98E-06, 0.00]  ! 2550 eV
prt%p_reflect(:, 21) = [1.00,  0.922113, 0.827253, 0.757949, 0.645988, 8.73E-02, 6.62E-03, 1.23E-04, 1.74E-05, 6.24E-06, 0.00]  ! 2600 eV
prt%p_reflect(:, 22) = [1.00,  0.923055, 0.828043, 0.756879, 0.637296, 6.88E-02, 5.37E-03, 1.02E-04, 1.54E-05, 5.60E-06, 0.00]  ! 2650 eV
prt%p_reflect(:, 23) = [1.00,  0.923965, 0.82874,  0.755529, 0.627112, 5.45E-02, 4.37E-03, 8.57E-05, 1.37E-05, 5.03E-06, 0.00]  ! 2700 eV
prt%p_reflect(:, 24) = [1.00,  0.924844, 0.829329, 0.753838, 0.615004, 4.35E-02, 3.57E-03, 7.26E-05, 1.23E-05, 4.55E-06, 0.00]  ! 2750 eV
prt%p_reflect(:, 25) = [1.00,  0.9257,   0.829846, 0.751869, 0.600849, 3.49E-02, 2.92E-03, 6.16E-05, 1.10E-05, 4.11E-06, 0.00]  ! 2800 eV
prt%p_reflect(:, 26) = [1.00,  0.926519, 0.830225, 0.749442, 0.583666, 2.82E-02, 2.41E-03, 5.30E-05, 1.00E-05, 3.74E-06, 0.00]  ! 2850 eV
prt%p_reflect(:, 27) = [1.00,  0.927316, 0.830516, 0.746628, 0.563069, 2.29E-02, 1.99E-03, 4.59E-05, 9.08E-06, 3.41E-06, 0.00]  ! 2900 eV
prt%p_reflect(:, 28) = [1.00,  0.928093, 0.830727, 0.743417, 0.538271, 1.87E-02, 1.65E-03, 3.98E-05, 8.24E-06, 3.11E-06, 0.00]  ! 2950 eV
prt%p_reflect(:, 29) = [1.00,  0.928843, 0.830819, 0.739661, 0.507719, 1.53E-02, 1.37E-03, 3.49E-05, 7.51E-06, 2.84E-06, 0.00]  ! 3000 eV
prt%p_reflect(:, 30) = [1.00,  0.929568, 0.830796, 0.735313, 0.46996,  1.26E-02, 1.15E-03, 3.08E-05, 6.88E-06, 2.61E-06, 0.00]  ! 3050 eV
prt%p_reflect(:, 31) = [1.00,  0.930273, 0.830667, 0.730318, 0.423672, 1.05E-02, 9.62E-04, 2.74E-05, 6.32E-06, 2.41E-06, 0.00]  ! 3100 eV
prt%p_reflect(:, 32) = [1.00,  0.930959, 0.830435, 0.724608, 0.36882,  8.69E-03, 8.09E-04, 2.44E-05, 5.80E-06, 2.21E-06, 0.00]  ! 3150 eV
prt%p_reflect(:, 33) = [1.00,  0.93163,  0.830108, 0.718111, 0.308661, 7.25E-03, 6.83E-04, 2.18E-05, 5.32E-06, 2.04E-06, 0.00]  ! 3200 eV
prt%p_reflect(:, 34) = [1.00,  0.932275, 0.829627, 0.710495, 0.249071, 6.07E-03, 5.79E-04, 1.97E-05, 4.92E-06, 1.88E-06, 0.00]  ! 3250 eV
prt%p_reflect(:, 35) = [1.00,  0.932897, 0.828988, 0.701558, 0.196956, 5.10E-03, 4.94E-04, 1.79E-05, 4.57E-06, 1.76E-06, 0.00]  ! 3300 eV
prt%p_reflect(:, 36) = [1.00,  0.933513, 0.82827,  0.691376, 0.155752, 4.30E-03, 4.21E-04, 1.63E-05, 4.22E-06, 1.62E-06, 0.00]  ! 3350 eV
prt%p_reflect(:, 37) = [1.00,  0.934094, 0.827309, 0.678991, 0.123343, 3.64E-03, 3.62E-04, 1.50E-05, 3.96E-06, 1.53E-06, 0.00]  ! 3400 eV
prt%p_reflect(:, 38) = [1.00,  0.934673, 0.826276, 0.664725, 9.90E-02, 3.09E-03, 3.12E-04, 1.38E-05, 3.67E-06, 1.42E-06, 0.00]  ! 3450 eV
prt%p_reflect(:, 39) = [1.00,  0.935237, 0.82509,  0.647709, 8.02E-02, 2.63E-03, 2.69E-04, 1.26E-05, 3.41E-06, 1.32E-06, 0.00]  ! 3500 eV
prt%p_reflect(:, 40) = [1.00,  0.935775, 0.82364,  0.626535, 6.54E-02, 2.24E-03, 2.34E-04, 1.18E-05, 3.20E-06, 1.24E-06, 0.00]  ! 3550 eV
prt%p_reflect(:, 41) = [1.00,  0.936319, 0.822144, 0.601464, 5.40E-02, 1.92E-03, 2.02E-04, 1.08E-05, 2.96E-06, 1.15E-06, 0.00]  ! 3600 eV
prt%p_reflect(:, 42) = [1.00,  0.936821, 0.820233, 0.568456, 4.47E-02, 1.65E-03, 1.78E-04, 1.01E-05, 2.81E-06, 1.09E-06, 0.00]  ! 3650 eV
prt%p_reflect(:, 43) = [1.00,  0.937334, 0.818284, 0.528291, 3.74E-02, 1.42E-03, 1.55E-04, 9.34E-06, 2.60E-06, 1.01E-06, 0.00]  ! 3700 eV
prt%p_reflect(:, 44) = [1.00,  0.937825, 0.816019, 0.476576, 3.14E-02, 1.22E-03, 1.36E-04, 8.69E-06, 2.44E-06, 9.50E-07, 0.00]  ! 3750 eV
prt%p_reflect(:, 45) = [1.00,  0.938295, 0.813402, 0.412184, 2.65E-02, 1.06E-03, 1.20E-04, 8.15E-06, 2.30E-06, 8.97E-07, 0.00]  ! 3800 eV
prt%p_reflect(:, 46) = [1.00,  0.938746, 0.810396, 0.339803, 2.24E-02, 9.22E-04, 1.07E-04, 7.70E-06, 2.18E-06, 8.53E-07, 0.00]  ! 3850 eV
prt%p_reflect(:, 47) = [1.00,  0.939199, 0.80717,  0.272449, 1.91E-02, 8.02E-04, 9.48E-05, 7.20E-06, 2.05E-06, 8.01E-07, 0.00]  ! 3900 eV
prt%p_reflect(:, 48) = [1.00,  0.939635, 0.803496, 0.216106, 1.63E-02, 7.01E-04, 8.45E-05, 6.77E-06, 1.93E-06, 7.57E-07, 0.00]  ! 3950 eV
prt%p_reflect(:, 49) = [1.00,  0.940058, 0.79932,  0.172192, 1.40E-02, 6.14E-04, 7.57E-05, 6.38E-06, 1.83E-06, 7.17E-07, 0.00]  ! 4000 eV
prt%p_reflect(:, 50) = [1.00,  0.940487, 0.794873, 0.139512, 1.21E-02, 5.36E-04, 6.72E-05, 5.92E-06, 1.70E-06, 6.68E-07, 0.00]  ! 4050 eV
prt%p_reflect(:, 51) = [1.00,  0.940883, 0.789507, 0.113604, 1.04E-02, 4.73E-04, 6.07E-05, 5.62E-06, 1.62E-06, 6.36E-07, 0.00]  ! 4100 eV
prt%p_reflect(:, 52) = [1.00,  0.941267, 0.783392, 9.35E-02, 9.03E-03, 4.18E-04, 5.50E-05, 5.33E-06, 1.54E-06, 6.05E-07, 0.00]  ! 4150 eV
prt%p_reflect(:, 53) = [1.00,  0.94164,  0.776404, 7.77E-02, 7.84E-03, 3.70E-04, 5.00E-05, 5.06E-06, 1.46E-06, 5.76E-07, 0.00]  ! 4200 eV
prt%p_reflect(:, 54) = [1.00,  0.942004, 0.768389, 6.52E-02, 6.83E-03, 3.29E-04, 4.55E-05, 4.79E-06, 1.39E-06, 5.48E-07, 0.00]  ! 4250 eV
prt%p_reflect(:, 55) = [1.00,  0.942361, 0.759154, 5.51E-02, 5.96E-03, 2.92E-04, 4.15E-05, 4.54E-06, 1.32E-06, 5.20E-07, 0.00]  ! 4300 eV
prt%p_reflect(:, 56) = [1.00,  0.942712, 0.748454, 4.69E-02, 5.21E-03, 2.60E-04, 3.77E-05, 4.28E-06, 1.25E-06, 4.92E-07, 0.00]  ! 4350 eV
prt%p_reflect(:, 57) = [1.00,  0.943058, 0.73596,  4.02E-02, 4.57E-03, 2.31E-04, 3.43E-05, 4.02E-06, 1.17E-06, 4.63E-07, 0.00]  ! 4400 eV
prt%p_reflect(:, 58) = [1.00,  0.943374, 0.720237, 3.45E-02, 4.01E-03, 2.08E-04, 3.17E-05, 3.84E-06, 1.12E-06, 4.44E-07, 0.00]  ! 4450 eV
prt%p_reflect(:, 59) = [1.00,  0.943688, 0.70125,  2.98E-02, 3.53E-03, 1.86E-04, 2.93E-05, 3.65E-06, 1.07E-06, 4.23E-07, 0.00]  ! 4500 eV
prt%p_reflect(:, 60) = [1.00,  0.944001, 0.677956, 2.58E-02, 3.12E-03, 1.67E-04, 2.69E-05, 3.45E-06, 1.01E-06, 4.01E-07, 0.00]  ! 4550 eV
prt%p_reflect(:, 61) = [1.00,  0.944284, 0.646813, 2.24E-02, 2.76E-03, 1.51E-04, 2.51E-05, 3.31E-06, 9.74E-07, 3.86E-07, 0.00]  ! 4600 eV
prt%p_reflect(:, 62) = [1.00,  0.944569, 0.606443, 1.96E-02, 2.44E-03, 1.37E-04, 2.34E-05, 3.15E-06, 9.29E-07, 3.68E-07, 0.00]  ! 4650 eV
prt%p_reflect(:, 63) = [1.00,  0.944857, 0.553553, 1.71E-02, 2.16E-03, 1.23E-04, 2.15E-05, 2.97E-06, 8.77E-07, 3.48E-07, 0.00]  ! 4700 eV
prt%p_reflect(:, 64) = [1.00,  0.945117, 0.481571, 1.50E-02, 1.92E-03, 1.12E-04, 2.02E-05, 2.85E-06, 8.42E-07, 3.34E-07, 0.00]  ! 4750 eV
prt%p_reflect(:, 65) = [1.00,  0.94535,  0.394686, 1.32E-02, 1.72E-03, 1.03E-04, 1.93E-05, 2.77E-06, 8.21E-07, 3.26E-07, 0.00]  ! 4800 eV
prt%p_reflect(:, 66) = [1.00,  0.945622, 0.319118, 1.17E-02, 1.53E-03, 9.29E-05, 1.77E-05, 2.59E-06, 7.69E-07, 3.06E-07, 0.00]  ! 4850 eV
prt%p_reflect(:, 67) = [1.00,  0.945832, 0.252554, 1.03E-02, 1.37E-03, 8.62E-05, 1.70E-05, 2.53E-06, 7.52E-07, 2.99E-07, 0.00]  ! 4900 eV
prt%p_reflect(:, 68) = [1.00,  0.946088, 0.206173, 9.16E-03, 1.22E-03, 7.77E-05, 1.57E-05, 2.37E-06, 7.05E-07, 2.80E-07, 0.00]  ! 4950 eV
prt%p_reflect(:, 69) = [1.00,  0.946281, 0.167764, 8.12E-03, 1.10E-03, 7.24E-05, 1.51E-05, 2.32E-06, 6.90E-07, 2.75E-07, 0.00]  ! 5000 eV

! Take the logiarithm of p_reflect. Where zero, just use an extrapolation of the previous two points.

do i = 1, size(photon_reflect_table)
  prt => photon_reflect_table(i)
  do j = 1, size(prt%energy)

    do k = 1, size(prt%angle)
      if (prt%p_reflect(k, j) == 0) then
        f = (prt%angle(k) - prt%angle(k-2)) / (prt%angle(k-1) - prt%angle(k-2))
        prt%p_reflect(k, j) = (1 - f) * prt%p_reflect(k-2, j) + f * prt%p_reflect(k-1, j)  ! Linear extrapolation
        if (prt%p_reflect(k, j) > prt%p_reflect(k-1, j)) call err_exit  ! something wrong with table
      else
        prt%p_reflect(k, j) = log(prt%p_reflect(k, j))
      endif
    enddo

    ! First interval interpolation: p = c0 + c1 * angle^n

    deriv = (prt%p_reflect(3,j) - prt%p_reflect(1,j)) / prt%angle(3)
    dprob = prt%p_reflect(2,j) - prt%p_reflect(1,j)
    prt%int1(j)%c0     = prt%p_reflect(1,j)
    prt%int1(j)%n_exp  = deriv * prt%angle(2) / dprob
    prt%int1(j)%c1     = dprob / prt%angle(2)**prt%int1(j)%n_exp

  enddo
enddo

end subroutine

!---------------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------------
!---------------------------------------------------------------------------------------------
!+
! Subroutine photon_reflectivity (angle, energy, reflect_prob)
!
! Routine to evaluate the photon reflectivity using a spline interpolation.
!
! Modules needed:
!  use photon_reflection_mod
!
! Input:
!  angle  -- Real(rp): Incident grazing angle in radians
!  energy -- Real(rp): Photon energy in eV.
!
! Output:
!  reflect_prob -- Real(rp): reflection probability. 1.0 -> 100% reflection.
!-

subroutine photon_reflectivity (angle, energy, reflect_prob)

use spline_mod

implicit none

type (photon_reflect_table_struct), pointer :: prt
type (spline_struct) ang_spline(6)

real(rp) angle, angle_deg, energy, e_tot, reflect_prob, max_e, f
real(rp) c0, c1, n_exp

integer i, j, ie, ix, n_table, n_energy, ixa, ixa0, ixa1, n_ang, n_a

logical ok

! Init

if (photon_reflect_table_init_needed) call photon_reflection_init

! Singular cases

if (angle < 1d-10) then
  reflect_prob = 1
  return
endif

if (angle > 1.000001 * pi/2 .or. angle < 0) then
  print *, 'PHOTON_REFLECTIVITY: ANGLE OUT OF RANGE!', angle
  call err_exit
endif

angle_deg = angle * 180 / pi

! If the energy is less than the minimum of the table then just use the minimum.

e_tot = max(photon_reflect_table(1)%energy(1), energy)

! If the energy is greater than what the tables covers assume that things scale as energy*angle

n_table = size(photon_reflect_table)
max_e = photon_reflect_table(n_table)%max_energy
 
if (e_tot > max_e) then
  angle_deg = angle_deg * e_tot / max_e
  e_tot = max_e
  if (angle_deg > pi) then
    reflect_prob = 0
    return
  endif
endif

! Find which table to use

do i = 1, n_table 
  prt => photon_reflect_table(i)
  if (e_tot <= prt%max_energy) exit
enddo

! interpolation:
! First Simple linear interpolation in energy 

n_energy = size(prt%energy)
ie = 1 + int((n_energy - 1) * (e_tot - prt%energy(1)) / (prt%energy(n_energy) - prt%energy(1)))
if (ie == n_energy) ie = n_energy - 1

! Find which angle interval angle_deg is in.

n_ang = size(prt%angle)
call bracket_index (prt%angle, 1, n_ang, angle_deg, ixa)

f = (e_tot - prt%energy(ie)) / (prt%energy(ie+1) - prt%energy(ie))

! If in the first interval then spline interpolation is not good.
! In this case we use the fact that the probability is monotonic and fit and use the form:
!   prob = c0 + c1 * ang^n

if (ixa == 1) then
  c0    = (1 - f) * prt%int1(ie)%c0 + f * prt%int1(ie)%c0
  c1    = (1 - f) * prt%int1(ie)%c1 + f * prt%int1(ie)%c1
  n_exp = (1 - f) * prt%int1(ie)%n_exp + f * prt%int1(ie)%n_exp
  reflect_prob = c0 + c1 * angle_deg**n_exp
  reflect_prob = exp(reflect_prob)
  return
endif

! Now use Akima spline interpolation in angle.
! Only spline the part of reflect_prob that is needed

prt%reflect_prob = (1 - f) * prt%p_reflect(:, ie) + f * prt%p_reflect(:, ie+1)  ! Linear interpolation

ixa0 = max(1, ixa-2)
ixa1 = min(n_ang, ixa+3)

n_a = ixa1 - ixa0 + 1
ang_spline(1:n_a)%x = prt%angle(ixa0:ixa1)
ang_spline(1:n_a)%y = prt%reflect_prob(ixa0:ixa1)
call spline_akima(ang_spline(1:n_a), ok)
if (.not. ok) call err_exit

call spline_evaluate (ang_spline(1:n_a), angle_deg, ok, reflect_prob)
if (.not. ok) call err_exit

!if (reflect_prob > prt%reflect_prob(ixa) .or. reflect_prob < prt%reflect_prob(min(n_ang, ixa+1))) then
!  print *, 'PHOTON_REFECTIVITY: BAD SPLINE FIT!'
!  call err_exit
!endif

reflect_prob = exp(reflect_prob)

end subroutine

end module
