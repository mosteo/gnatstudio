------------------------------------------------------------------------------
--                               GNAT Studio                                --
--                                                                          --
--                     Copyright (C) 2000-2022, AdaCore                     --
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

with Language; use Language;
with GNATCOLL.VFS;

package Language_Utils is

   procedure Parse_File_Constructs
     (Lang      : access Language_Root'Class;
      File_Name : GNATCOLL.VFS.Virtual_File;
      Result    : out Construct_List);
   --  Same as Language.Parse_Constructs, but works on a given file.
   --  Since Parse_File_Constructs calls Parse_Constructs, this function does
   --  not need to be dispatching.

end Language_Utils;
