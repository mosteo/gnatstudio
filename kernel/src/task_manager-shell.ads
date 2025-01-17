------------------------------------------------------------------------------
--                               GNAT Studio                                --
--                                                                          --
--                     Copyright (C) 2009-2022, AdaCore                     --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

with GNATCOLL.Scripts;
with GPS.Kernel;

package Task_Manager.Shell is

   procedure Register_Commands
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class);
   --  Register the task manager commands

   function Get_Or_Create_Instance
     (Data  : GNATCOLL.Scripts.Callback_Data'Class;
      Id    : String) return GNATCOLL.Scripts.Class_Instance;
   --  Return the script instance wrapping this Queue. Create it if it does
   --  not exist.

end Task_Manager.Shell;
