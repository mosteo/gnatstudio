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

--  This package provides tooltips-like functionality.
--  It is not based on GtkTooltip, because the latter has several drawbacks
--  as of gtk 3.4:
--      * it doesn't seem possible to define an area in which the tooltip stays
--        constant, and the window should stay visible while the pointer is in
--        that area.  Set_Tip_Area doesn't seem to do that at least for
--        GtTextView.
--      * the contents of the tooltip is computed every time the mouse moves,
--        not at the end of the timeout. This results in a lot of extra
--        computation for the contents of the tooltip.

with Glib;           use Glib;
with Gdk.RGBA;       use Gdk.RGBA;
with Gtk.Widget;     use Gtk.Widget;
with Gdk.Rectangle;
with Gtk.Tree_Model;
with Gtk.Tree_View;
with Gtk.Label;      use Gtk.Label;

package Tooltips is

   procedure Initialize_Tooltips
     (Tree : access Gtk.Tree_View.Gtk_Tree_View_Record'Class;
      X, Y : Gint;
      Area : out Gdk.Rectangle.Gdk_Rectangle;
      Iter : out Gtk.Tree_Model.Gtk_Tree_Iter);
   --  Find out the position of the mouse over the tree, and compute the area
   --  that triggered the tooltip to appear (see Create_Contents below).
   --  Iter is the iterator for which we should generate a tooltip.
   --  Null_Iter is returned if no tooltip should be displayed.
   --
   --  See Gtk.Tree_View.Get_Tooltip_Context instead,
   --  and Gtk.Tree_View.Set_Tooltip_Cell

   function Tooltips_Foreground_Color return Gdk.RGBA.Gdk_RGBA;
   --  Return the default foreground color used for the text in the tooltip.

   --------------
   -- Tooltips --
   --------------

   type Tooltip_Handler is abstract tagged private;
   type Tooltip_Handler_Access is access all Tooltip_Handler'Class;
   --  This type represents a tooltip handler: it can be attached to one or
   --  more widgets, and will create a tooltip (ie a graphical window to
   --  display information) automatically for them when the mouse is left for
   --  a while over the window.
   --  This general form can embed any gtk widget in its window

   procedure Destroy (Tooltip : access Tooltip_Handler) is null;
   --  Destroy the memory occupied by the fields in Tooltip, not Tooltip
   --  itself.

   function Show_Tooltip_On_Create_Contents
     (Tooltip : not null access Tooltip_Handler) return Boolean
   is
     (True);
   --  Return True if the tooltip can immediately and automatically be shown
   --  after calling Create_Contents on a tooltip query.
   --  Override this function and return False if your tooltips contents can
   --  change after a tooltip query: then you'll need to show the tooltip
   --  manually by calling the Show_Finalized_Tooltip subprogramd when the
   --  tooltip contents are ready.

   function Align_Tooltip_With_Tip_Area
     (Tooltip : not null access Tooltip_Handler) return Boolean
   is
     (False);
   --  A small offset is added between the tooltip and the cursor positions
   --  by default: override this function and return True if the tooltips
   --  should be aligned with its tip area.
   --  When returning True, the tooltip will be placed justed under or just
   --  above the tip area.

   function Create_Contents
     (Tooltip : not null access Tooltip_Handler;
      Widget  : not null access Gtk.Widget.Gtk_Widget_Record'Class;
      X, Y    : Glib.Gint) return Gtk.Widget.Gtk_Widget is abstract;
   --  Return the widget to be displayed in the tooltip. This widget will be
   --  automatically destroyed when the tooltip is hidden.
   --  This function should return null if the tooltip shouldn't be
   --  displayed.
   --  This function should call Tooltip.Set_Tip_Area to indicate which area
   --  of widget the tooltip applies to (the tooltip will remain visible while
   --  the mouse is in this area).

   procedure Show_Finalized_Tooltip;
   --  Show the finalized tooltip.
   --  This is done automatically by default: only the tooltip handlers that
   --  work asynchronously should call this procedure once the tooltips
   --  contents are fixed and won't change anymore.

   procedure Hide_Tooltip;
   --  Hide the global tooltip.

   procedure Set_Tip_Area
     (Tooltip : not null access Tooltip_Handler;
      Area    : Gdk.Rectangle.Gdk_Rectangle);
   --  Set the active area for the tooltip. While the cursor remains in this
   --  area, the tooltip is kept on screen with the same contents.
   --  Coordinates are relative to the widget.

   procedure Associate_To_Widget
     (Tooltip         : access Tooltip_Handler'Class;
      Widget          : access Gtk.Widget.Gtk_Widget_Record'Class;
      Scroll_Event_Widget : access Gtk.Widget.Gtk_Widget_Record'Class := null);
   --  Bind Tooltip to the widget, so that when the mouse is left over Widget,
   --  the tooltip is displayed.
   --  You can attach a given tooltip to a single widget for the time being.
   --  A Program_Error will be raised if you do not respect that.
   --  Tooltip is automatically destroyed and freed when the widget is
   --  destroyed.
   --  If Scroll_Event_Widget is specified, tooltips will be automatically
   --  hidden when a scrolling event occurs on it, instead of trying to
   --  detect a scrolling event on Widget itself.

   ---------------
   -- Clipboard --
   ---------------

   procedure Set_Tooltip_Clipboard_Widget (Widget : not null Gtk_Widget);
   --  Set the tooltip widget to be used for clipboard-related actions.
   --  Setting this allows users to copy/paste text from the given tooltip
   --  widget.

   function Get_Tooltip_Clipboard_Widget return Gtk_Widget;
   --  Return the tooltip widget to use for clipboard-related actions.
   --  Return null if there is no tooltip displayed or if there is no widget
   --  available for clipboard actions.

   ---------------
   -- Shortcuts --
   ---------------

   procedure Set_Static_Tooltip
     (Widget     : not null access Gtk_Widget_Record'Class;
      Text       : String;
      Use_Markup : Boolean := True);
   --  Set static text for a tooltip.
   --  This is similar to Gtk.Widget.Set_Tooltip_Text, but the placement of
   --  tooltips is different.

   -----------
   -- Utils --
   -----------

   procedure Create_Tooltip_Label
     (Label      : out Gtk_Label;
      Text       : String;
      Use_Markup : Boolean := True);
   --  Create a label suitable to be displayed in tooltips.
   --  In particular, it ensures that the created label will wrap if it's
   --  needed width becomes too wide to be displayed in a tooltip.

   procedure Set_Tooltip_Highlighted (Highlighted : Boolean);
   --  Highlight/unhighlight the global tooltip widget.
   --  When highlighted, the tooltip will have a colored border.
   --  Do nothing if there is no tooltip displayed.

private
   type Tooltip_Handler is abstract tagged null record;

end Tooltips;
