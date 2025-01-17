------------------------------------------------------------------------------
--                               GNAT Studio                                --
--                                                                          --
--                        Copyright (C) 2022, AdaCore                       --
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

--  Common types that are used for DAP integration

with Ada.Containers.Vectors;
with Ada.Containers.Doubly_Linked_Lists;

package DAP.Types is

   type Debugger_Status_Kind is
     (Initialization, Initialized, Ready, Stopped, Running, Terminating);

   type Breakpoint_Identifier is new Natural;
   No_Breakpoint : constant Breakpoint_Identifier := 0;
   --  How breakpoints are identified. Currently, the debuggers supported
   --  by gvd all associate numbers with breakpoints.

   package Breakpoint_Identifier_Lists is
     new Ada.Containers.Doubly_Linked_Lists (Breakpoint_Identifier);
   --  This type is used when doing the same debugger action on a list of
   --  breakpoints (delete/enable/disable).

   package Numbers is new Ada.Containers.Vectors (Positive, Positive);

end DAP.Types;
