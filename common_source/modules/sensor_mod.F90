!Copyright>        OpenRadioss
!Copyright>        Copyright (C) 1986-2025 Altair Engineering Inc.
!Copyright>
!Copyright>        This program is free software: you can redistribute it and/or modify
!Copyright>        it under the terms of the GNU Affero General Public License as published by
!Copyright>        the Free Software Foundation, either version 3 of the License, or
!Copyright>        (at your option) any later version.
!Copyright>
!Copyright>        This program is distributed in the hope that it will be useful,
!Copyright>        but WITHOUT ANY WARRANTY; without even the implied warranty of
!Copyright>        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!Copyright>        GNU Affero General Public License for more details.
!Copyright>
!Copyright>        You should have received a copy of the GNU Affero General Public License
!Copyright>        along with this program.  If not, see <https://www.gnu.org/licenses/>.
!Copyright>
!Copyright>
!Copyright>        Commercial Alternative: Altair Radioss Software
!Copyright>
!Copyright>        As an alternative to this open-source version, Altair also offers Altair Radioss
!Copyright>        software under a commercial license.  Contact Altair to discuss further if the
!Copyright>        commercial version may interest you: https://www.altair.com/radioss/.
      !||====================================================================
      !||    sensor_common_mod      ../common_source/modules/sensor_common_mod.F90
      !||--- called by ------------------------------------------------------
      !||    sensor_mod             ../engine/share/modules/sensor_mod.F
      !||--- uses       -----------------------------------------------------
      !||    names_and_titles_mod   ../common_source/modules/names_and_titles_mod.F
      !||    python_funct_mod       ../common_source/modules/python_mod.F90
      !||====================================================================
      module sensor_mod
! ----------------------------------------------------------------------------------------------------------------------
!                                                   Modules
! ----------------------------------------------------------------------------------------------------------------------
      USE PYTHON_FUNCT_MOD
      USE NAMES_AND_TITLES_MOD, ONLY:NCHARTITLE
! ----------------------------------------------------------------------------------------------------------------------
!                                                   Include
! ----------------------------------------------------------------------------------------------------------------------
#include "my_real.inc"
! ----------------------------------------------------------------------------------------------------------------------
!                                                   Parameters
! ----------------------------------------------------------------------------------------------------------------------
      integer ,parameter :: isenbuf  = 20
      integer ,parameter :: lsenbuf  = 101
      integer ,parameter :: nsenpari = 12
      integer ,parameter :: nsenparr = 20
      integer ,parameter :: isenpari = 3
      integer ,parameter :: isenparr = 203
      integer ,parameter :: sensor_type_python = 40
      integer, parameter :: sensor_result_size = 2
      integer ,parameter :: mx_sens  = 50000        !used only in sensor list in engine options /STOP, /OUTP...
! ----------------------------------------------------------------------------------------------------------------------
!                                                   Types
! ----------------------------------------------------------------------------------------------------------------------
      type sensor_str_
        integer :: type        !<   sensor type 
        integer :: sens_id     !<   sensor user id
        integer :: status      !<   sensor status
                               !          = 0   : deactivated
                               !          = 1   : activated at tstart
        character(len = nchartitle) :: title
        my_real :: tcrit       !<   time when activation criterion is met
        my_real :: tmin        !<   time duration of crit value before activation
        my_real :: tdelay      !<   time delay before activation (after tmin)
        my_real :: tstart      !<   time when sensor is finally activated (for output)
        my_real :: value       !<   actual sensor value
        integer :: npari       !<   number of constant integer parameters
        integer :: nparr       !<   number of constant real value parameters
        integer :: nvar        !<   number of internal variables
        integer ,dimension(:) ,allocatable :: iparam  !<  integer parameter array
        my_real ,dimension(:) ,allocatable :: rparam  !<  real parameter array
        my_real ,dimension(:) ,allocatable :: var     !<  internal variables array
        ! user sensor buffers
        integer ,dimension(:) ,allocatable :: integer_userbuf    !<  buffer to store integer variables
        my_real ,dimension(:) ,allocatable :: float_userbuf      !<  buffer to store user variables.
        integer ,dimension(:) ,allocatable :: integer_userparam  !<  buffer to store integer variables
        my_real ,dimension(:) ,allocatable :: float_userparam    !<  buffer to store user variables.
        my_real, dimension(sensor_result_size) :: results
        integer :: python_function_id !< the python functions, if type = sensor_type_python (40)
        type(python_function)  :: python_function !< the python functions, if type = sensor_type_python (40)
      end type sensor_str_

      ! -----------------------------------
      type sub_sensor_type
        integer :: part                                                 !   id of the part
        integer :: num_group_part                                       !   number of element group per part
        real(kind=8), dimension(:,:,:), allocatable :: fbsav6_sens      !   fbsav6 double precision array (parith/on array)           
      end type sub_sensor_type
      ! -----------------------------------
      type sensor_type
        integer :: typ                                                  !   type of energy sensor : 1 --> only 1 part ; 2 --> several subparts
        integer :: part                                                 !   id of the part
        integer :: nb_sub                                               !   number of subpart only useful for typ=2
        integer :: num_group_part                                       !   number of element group per part
        type(sub_sensor_type), dimension(:), allocatable :: sub
        real(kind=8), dimension(:,:,:), allocatable :: fbsav6_sens      !   fbsav6 double precision array (parith/on array)           
      end type sensor_type
      ! -----------------------------------
      type sensor_group
        integer :: num_part                            !   number of part per element group
        integer, dimension(:,:), allocatable :: part   !   size = (num_part,3)
!       structure of sens_group%part :
!       (1:num_part,1): id of the part
!       (1:num_part,2): type of energy sensor (1=part / 2=subset)
!       (1:num_part,3): sensor linked to the current part
      end type sensor_group
      ! -----------------------------------
      type sensor_comm
        logical :: bool                                 !   boolean : true if there is one or more energy sensors
        integer :: num_sens                             !   number of sensor
        integer :: buffer_size_mean                     !   buffer size for mpi_sum reduction
        integer :: buffer_size_min_max                  !   buffer size for min/max reduction
        integer, dimension(:), allocatable :: id_sens   !   id of the sensor
      end type sensor_comm

      type sensor_user_struct_
         logical :: is_used          ! boolean, true if a user sensor is activated
         integer :: pointer_node,number_node ! nbr of node of user sensor + index 
         integer :: pointer_part,number_part ! nbr of part of user sensor + index 
         integer :: pointer_node_per_part,number_node_per_part ! nbr of node defined in a part of user sensor + index 
         integer, dimension(:), allocatable :: node_list ! list of node
         integer, dimension(:), allocatable :: part_list ! list of part
         integer, dimension(:), allocatable :: node_per_part_list ! list of node defined in a part
      end type sensor_user_struct_


      !                                  IPARAM                     RPARAM               VAR
! if type == 0 : sensor time        {}                          {}                 {} 
! if type == 1 : sensor ACCEL
! if type == 2 : sensor DISP
! if type == 3 : sensor SENS
! if type == 4 : sensor AND
! if type == 5 : sensor OR
! if type == 6 : sensor CONTACT result(1) = contact force 
! if type == 7 : sensor RWALL
! if type == 8 : sensor NOT
! if type == 9 : sensor VEL
! if type == 10 : sensor GAUGE
! if type == 11 : sensor RBODY
! if type == 12 : sensor SECT
! if type == 13 : sensor WORK
! if type == 14 : sensor ENERGY  results(1) = kinetic energy, results(2) = internal energy
! if type == 15 : sensor DIST_SURF
! if type == 16 : sensor HIC
! if type == 17 : sensor TEMP
      ! main sensor structure
      type sensors_
        integer :: nsensor 
        integer :: stabsen
        integer :: sfsav
        integer :: nstop
        integer :: nstat
        integer :: noutp
        integer :: nanim
        integer :: nreset
        integer :: anim_id
        integer :: stop_nsth      !< /stop/lsensor - write time history file
        integer :: stop_nsanim    !< /stop/lsensor - write animation file
        integer :: stop_nsstat    !< /stop/lsensor - write state file
        integer :: stop_nsoutp    !< /stop/lsensor - write state file   
        integer :: stop_nsh3d     !< /stop/lsensor - write h3d state
        integer :: stop_nsabf     !< /stop/lsensor - write abf file
        my_real :: anim_dt

        type (sensor_str_) ,dimension(:) ,allocatable :: sensor_tab

        integer            ,dimension(:) ,allocatable :: stop
        integer            ,dimension(:) ,allocatable :: stat
        integer            ,dimension(:) ,allocatable :: outp
        integer            ,dimension(:) ,allocatable :: anim
        integer            ,dimension(:) ,allocatable :: reset
        integer            ,dimension(:) ,allocatable :: stop_tmp
        integer            ,dimension(:) ,allocatable :: outp_tmp
        integer            ,dimension(:) ,allocatable :: stat_tmp
        integer            ,dimension(:) ,allocatable :: anim_tmp

        integer, dimension(:) ,allocatable :: tabsensor  

        integer,dimension(:),allocatable :: ngr_sensor
        ! logical sensors
        integer logical_sensor_count
        integer, dimension(:),allocatable :: logical_sensors_list
  
        ! Engine MPI communication buffers
        double precision ,dimension(:,:,:) ,allocatable :: fsav  ! smpd communication array for "force" sensors           
        type(sensor_comm) :: COMM_SENS14 ! structure for mpi communication : sensor typ14
        type(sensor_comm) :: COMM_SENS16 ! structure for mpi communication : sensor typ16
        type(sensor_comm) :: COMM_SENS17 ! structure for mpi communication : sensor typ17 --> sensor temperature
        type(sensor_type), DIMENSION(:), ALLOCATABLE :: SENSOR_STRUCT     !   structure of energy sensor
        type(sensor_group), DIMENSION(:), ALLOCATABLE :: SENS_GROUP       !   structure of energy sensor              
      END TYPE SENSORS_


      end module sensor_mod 
