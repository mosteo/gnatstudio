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

--  This package handles the customizable information in the buffer,
--  such as information added to the sides of lines, or VCS information.

with Cairo;                use Cairo;
with Gdk.RGBA;
with Gtk.Drawing_Area;     use Gtk.Drawing_Area;
with Gtk.Text_View;        use Gtk.Text_View;
with Gtk.Widget;           use Gtk.Widget;
with Pango.Layout;         use Pango.Layout;

with GNATCOLL.Traces;      use GNATCOLL.Traces;

with GPS.Kernel.Messages;  use GPS.Kernel.Messages;

package Src_Editor_Buffer.Line_Information is

   procedure Create_Line_Information_Column
     (Buffer     : access Source_Buffer_Record'Class;
      Identifier : String;
      Every_Line : Boolean;
      Data       : Line_Information_Record);
   --  Add a column corresponding to Identifier in Buffer
   --  Data is used to determine the size of the column.

   function Has_Information_Column
     (Buffer     : access Source_Buffer_Record'Class;
      Identifier : String)
     return Boolean;
   --  Whether a column with this Identifier has been created.

   procedure Remove_Line_Information_Column
     (Buffer     : access Source_Buffer_Record'Class;
      Identifier : String);
   --  Remove a column from the side information in Buffer

   procedure Add_Extra_Information
     (Buffer     : access Source_Buffer_Record'Class;
      Identifier : String;
      Info       : access Line_Information_Array;
      Tooltip    : String := "";
      Icon       : String := "");
   --  Add extra information in the buffer. Extra information is for example
   --  the VCS status information displayed at the bottom of editors.
   --  Icon is a stock image to display

   procedure Add_File_Information
     (Buffer     : access Source_Buffer_Record'Class;
      Identifier : String;
      Messages   : Message_Array);
   --  Add the line information to the Buffer.
   --  User must not free Info.

   procedure Add_Side_Information
     (Buffer     : access Source_Buffer_Record'Class;
      Identifier : String;
      Data       : Line_Information_Array);
   --  Same as above.
   --  User must not free Info.

   procedure Remove_Message
     (Buffer    : access Source_Buffer_Record'Class;
      Reference : Message_Reference);
   --  Remove message from Buffer

   procedure Free_File_Information
     (Buffer : access Source_Buffer_Record'Class);
   --  Free all file information stored in the buffer

   function Get_Side_Information
     (Buffer : access Source_Buffer_Record'Class;
      Line   : Buffer_Line_Type) return Line_Info_Width_Array_Access;
   function Get_Side_Information
     (Buffer : access Source_Buffer_Record'Class;
      Line   : Editable_Line_Type) return Line_Info_Width_Array_Access;
   --  Return the side information for the given line

   function Get_Internal_Tooltip
     (Buffer : access Source_Buffer_Record'Class;
      Line   : Buffer_Line_Type) return String;
   --  Returns representation of internal data

   procedure Draw_Line_Info
     (Buffer       : access Source_Buffer_Record'Class;
      Top_Line     : Buffer_Line_Type;
      Bottom_Line  : Buffer_Line_Type;
      Current_Line : Buffer_Line_Type;
      As_Line      : Boolean;
      View         : Gtk_Text_View;
      Area         : Gtk_Drawing_Area;
      Color        : Gdk.RGBA.Gdk_RGBA;
      Line_Color   : Gdk.RGBA.Gdk_RGBA;
      Layout       : Pango_Layout;
      Cr           : Cairo.Cairo_Context);
   --  Draw side info from Top_Line to Bottom_Line on Drawable.
   --  Layout should be used to draw text.

   procedure On_Click
     (Buffer : access Source_Buffer_Record'Class;
      Line   : Buffer_Line_Type;
      Offset : Gint);
   --  Perform a click in the side column for line Line, offset Offset

   procedure On_Click_On_Side_Column
     (Buffer : not null access Source_Buffer_Record'Class;
      Line   : Buffer_Line_Type;
      Col    : Natural);
   --  Perform a click on the given side column for the given line (e.g: to
   --  fold a block).
   --  Execute the action associated with the given column, if any..

   procedure Execute_Line_Info
     (Buffer    : access Source_Buffer_Record'Class;
      Line_Info : Line_Information_Record;
      At_Line   : Buffer_Line_Type);
   --  Excute the given line information's associated command, if any.
   --  At_Line is used to set the command's line information when needed.

   function Add_Special_Lines
     (Buffer    : access Source_Buffer_Record'Class;
      Line      : Editable_Line_Type;
      Style     : Style_Access;
      Text      : String;
      Name      : String;
      Column_Id : String;
      Info      : Line_Information_Data)
      return Gtk.Text_Mark.Gtk_Text_Mark;
   --  Add Text at line Line, as a special line.
   --  The returned mark points to the beginning of the inserted special lines.
   --  Style is used to highlight the inserted special lines.
   --  Name is used to name the returned mark.
   --  Column_Id and Info, if not empty and null, indicate the side information
   --  to add to the buffer lines that we are inserting.
   --  Special lines cannot be edited and are not saved on disk.

   function Add_Special_Blank_Lines
     (Buffer             : access Source_Buffer_Record'Class;
      Line               : Editable_Line_Type;
      Style              : Style_Access;
      Number             : Natural;
      Name               : String;
      Column_Id          : String;
      Info               : Line_Information_Data)
      return Gtk.Text_Mark.Gtk_Text_Mark;
   --  Add Number blank special lines.

   function Create_Mark
     (Buffer : access Source_Buffer_Record'Class;
      Line   : Editable_Line_Type;
      Column : Visible_Column_Type) return Gtk.Text_Mark.Gtk_Text_Mark;
   --  Create mark at Line, Column.
   --  You need to explicitly Ref it if you want to keep it, since the current
   --  reference belongs to the buffer

   procedure Add_Lines
     (Buffer : access Source_Buffer_Record'Class;
      Start  : Buffer_Line_Type;
      Number : Buffer_Line_Type);
   --  Add Number blank lines to the column info and line highlights,
   --  after Start.

   procedure Remove_Lines
     (Buffer     : access Source_Buffer_Record'Class;
      Start_Line : Buffer_Line_Type;
      Count      : Buffer_Line_Type);
   --  Remove lines from the column info and line highlights

   procedure Remove_Blank_Lines
     (Buffer : access Source_Buffer_Record'Class;
      Mark   : Gtk.Text_Mark.Gtk_Text_Mark;
      Number : Natural);
   --  Remove Number blank lines associated with Mark

   procedure Hide_Lines
     (Buffer : access Source_Buffer_Record'Class;
      Line   : Buffer_Line_Type;
      Number : Editable_Line_Type);
   --  Hide Number editable lines from Mark

   procedure Unhide_Lines
     (Buffer     : access Source_Buffer_Record'Class;
      Start_Line : Editable_Line_Type;
      Number     : Editable_Line_Type);
   --  Write after Start_Line the lines stored in the corresponding editable
   --  line.

   procedure Add_Block_Command
     (Buffer        : access Source_Buffer_Record'Class;
      Editable_Line : Editable_Line_Type;
      Command       : Command_Access;
      Icon_Name     : String;
      Tooltip_Text  : String);
   --  Add a command in the block column information
   --  If Command is null, remove the previous messages rather than adding one.

   procedure Fold_All
     (Buffer  : access Source_Buffer_Record'Class;
      Similar : Boolean := False);
   --  Fold all top-level foldable blocks
   --  If Similar then fold only the blocks of the current block type.

   procedure Unfold_All
     (Buffer  : access Source_Buffer_Record'Class;
      Similar : Boolean := False);
   --  Unfold all top-level foldable blocks.
   --  Do nothing if there is no folded block.
   --  If Similar then unfold only the blocks of the current block type.

   procedure Unfold_Line
     (Buffer : access Source_Buffer_Record'Class;
      Line   : Editable_Line_Type);
   --  Unfold the block(s) containing Line

   procedure Fold_Block
     (Buffer : access Source_Buffer_Record'Class;
      Line   : Editable_Line_Type);
   --  Fold the block containing Line

   function Fold_Unfold_Line
     (Buffer : access Source_Buffer_Record'Class;
      Line   : Editable_Line_Type;
      Fold   : Boolean) return Boolean;
   --  Fold or unfold the block containing Line.
   --  Return True when an operation was executed, False otherwise.

   function Lines_Are_Real
     (Buffer : access Source_Buffer_Record'Class) return Boolean;
   pragma Inline (Lines_Are_Real);
   --  Return True if all editable lines are visible and all visible lines
   --  are editable lines.

   procedure Remove_Block_Folding_Commands
     (Buffer                 : access Source_Buffer_Record'Class;
      Remove_Unfold_Commands : Boolean := True);
   --  Remove the commands corresponding to block folding/unfolding from the
   --  side column.
   --  If Remove_Unfold_Commands is False, will only remove block folding
   --  command.

   procedure Highlight_Message
     (Buffer        : access Source_Buffer_Record'Class;
      Editable_Line : Editable_Line_Type;
      Buffer_Line   : Buffer_Line_Type;
      Message       : Message_Access);
   --  Highlight Message in the editor.
   --  Editable_Line and Buffer_Line can be left to 0, in which case the
   --  relevant data will be extracted from the message.

   procedure Remove_Message_Highlighting
     (Buffer  : access Source_Buffer_Record'Class;
      Message : Message_Access;
      Style   : Style_Access);
   --  Remove highlighting associated with Message

   function Get_Line
     (Buffer   : access Source_Buffer_Record'Class;
      Position : Gtk.Text_Mark.Gtk_Text_Mark) return Editable_Line_Type;
   --  Return the line of Position

   function Get_Column
     (Buffer   : access Source_Buffer_Record'Class;
      Position : Gtk.Text_Mark.Gtk_Text_Mark) return Positive;
   --  Return the column of Position

   function Flatten_Area
     (Buffer            : access Source_Buffer_Record'Class;
      Start_Line        : Editable_Line_Type;
      End_Line          : Editable_Line_Type;
      Start_Buffer_Line : Buffer_Line_Type;
      End_Buffer_Line   : Buffer_Line_Type) return Boolean;
   --  Remove all special lines between Start_Line and End_Line. Unfold all
   --  lines between those locations.
   --  If the area was already flat before calling this function, return
   --  False. Otherwise, return True.
   --  Remove all special lines between Start_Buffer_Line and End_Buffer_Line.

   procedure Recalculate_Side_Column_Width
     (Buffer : access Source_Buffer_Record'Class);
   --  Recalculate the total width of the left column side

   procedure Side_Column_Configuration_Changed
     (Buffer : access Source_Buffer_Record'Class);
   --  Emit the "side_column_configuration_changed" signal

   procedure Side_Column_Changed
     (Buffer : access Source_Buffer_Record'Class);
   --  Emit the "side_column_changed" signal

   procedure Free_Note (Message : Message_Access);
   --  Free note associated with Message

   function Get_Line_Infos
     (Data : Line_Info_Width) return Line_Information_Array;
   --  Convenience function to get all the line information, looking in the
   --  associated message too.

   procedure Popup_Contextual_Menu_For_Multiactions
     (Buffer : access Source_Buffer_Record'Class);
   --  Show the menu for multiactions for the current location, if any.

   function Has_Special_Lines
     (Buffer     : access Source_Buffer_Record'Class;
      Line_Start : Buffer_Line_Type;
      Line_End   : Buffer_Line_Type) return Boolean;
   --  Return True if there are special lines between line_start and line_end,
   --  included

   function Is_Line_Visible
     (Buffer : not null access Source_Buffer_Record'Class;
      Line   : Editable_Line_Type) return Boolean;
   --  Return True if the line is visible or False if the enclosing
   --  block is folded.

   Visualize_Internal_Buffers : constant Trace_Handle := Create
     ("GPS.INTERNAL.SOURCE_EDITOR_BUFFER_VISUALIZE_INTERNALS",
      Default => Off);
   --  Controls whether framework for displaying buffer internal data is active

end Src_Editor_Buffer.Line_Information;
