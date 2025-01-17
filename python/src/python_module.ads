------------------------------------------------------------------------------
--                               GNAT Studio                                --
--                                                                          --
--                     Copyright (C) 2003-2022, AdaCore                     --
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

with GPS.Kernel;

package Python_Module is

   procedure Register_Module
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class);
   --  Register the module into the list

   procedure Load_System_Python_Startup_Files
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class);
   --  Load all the GNAT Studio's systems Python plugins.
   --  This procedure should be called only after all standard modules
   --  have been registered, so that if the user's startup files depend
   --  on standard GNAT Studio functions these are already loaded.
   --  This procedure does nothing if the python module hasn't been
   --  registered.
   --
   --  ??? Ideally, we should have a hook run after all modules have been
   --  registered

   procedure Load_User_Python_Startup_Files
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class);
   --  As above but load the user's Python plugins

   procedure Load_No_Autoload_Python_Plugins
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class);
   --  Load the python plugins that have not been autoloaded by GNAT Studio,
   --  using startup.xml to identify the ones that need to be loaded.

end Python_Module;
