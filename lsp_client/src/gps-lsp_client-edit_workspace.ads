------------------------------------------------------------------------------
--                               GNAT Studio                                --
--                                                                          --
--                       Copyright (C) 2019-2022, AdaCore                   --
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

with VSS.Strings;

with GPS.Kernel;    use GPS.Kernel;
with LSP.Messages;

package GPS.LSP_Client.Edit_Workspace is

   procedure Edit
     (Kernel                   : Kernel_Handle;
      Workspace_Edit           : LSP.Messages.WorkspaceEdit;
      Title                    : VSS.Strings.Virtual_String;
      Make_Writable            : Boolean;
      Auto_Save                : Boolean;
      Allow_File_Renaming      : Boolean;
      Locations_Message_Markup : String;
      Limit_Span               : LSP.Messages.Span := LSP.Messages.Empty_Span;
      Error                    : out Boolean);
     --  Apply edit changes.
     --  Title is used for information/error dialogs and for the messages
     --  category when Show_Messages is True.
     --  Make_Writable controls whether changing read-only files.
     --  Allow_File_Renaming controls whether filenames should potentially be
     --  renamed when appropriate (i.e: when renaming a package).
     --  Locations_Message_Markup indicates what to display in the Locations
     --  View: if it is the empty string, do not display messages in the
     --  Locations view; if it is not empty, it needs to be valid pango markup.
     --  Limit_Span is used to filter out Workspace_Edit and only allow Edits
     --  within it, do nothing when empty.

end GPS.LSP_Client.Edit_Workspace;
