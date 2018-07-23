------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                       Copyright (C) 2018, AdaCore                        --
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

with Ada.Strings.Unbounded;           use Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;

with GNATCOLL.SQL.Sessions;
with GNATCOLL.SQL.Sqlite;
with GNATCOLL.VFS;

with Basic_Types;

with GPS.Kernel.Messages;
with GPS.Kernel.Project;              use GPS.Kernel.Project;

with Database.Orm;
with Language.Abstract_Language_Tree;

package body GNAThub.Loader.Databases is

   procedure Load_Tools_Rules_And_Metrics
     (Self : in out Database_Loader_Type'Class);
   --  Loads list of tools and their associated rules/metrics.

   procedure Load_Resources (Self : in out Database_Loader_Type'Class);
   --  Loads list of resources.

   procedure Free_Resource is
        new Ada.Unchecked_Deallocation (Resource_Record, Resource_Access);

   ---------------------
   -- Prepare_Loading --
   ---------------------

   overriding procedure Prepare_Loading (Self : in out Database_Loader_Type)
   is
      Database : constant GNATCOLL.VFS.Virtual_File :=
                   Self.Module.Get_Kernel.Get_Project_Tree.
                     Root_Project.Object_Dir
                       .Create_From_Dir ("gnathub")
                       .Create_From_Dir ("gnathub.db");
   begin
      if Database.Is_Regular_File then
         GNATCOLL.SQL.Sessions.Setup
           (Descr        =>
              GNATCOLL.SQL.Sqlite.Setup (String (Database.Full_Name.all)),
            Max_Sessions => 2);
         Self.Load_Tools_Rules_And_Metrics;
         Self.Load_Resources;
      else
         Self.Cleanup;
      end if;
   end Prepare_Loading;

   ----------------------
   -- Has_Data_To_Load --
   ----------------------

   overriding function Has_Data_To_Load
     (Self : Database_Loader_Type) return Boolean is
   begin
      return not Self.Resources.Is_Empty;
   end Has_Data_To_Load;

   -------------
   -- Cleanup --
   -------------

   overriding procedure Cleanup (Self : in out Database_Loader_Type) is

      Resource : Resource_Access;
   begin
      Loader_Type (Self).Cleanup;

      while not Self.Resources.Is_Empty loop
         Resource := Self.Resources.First_Element;
         Self.Resources.Delete_First;
         Free_Resource (Resource);
      end loop;

      Self.Rules.Clear;
      Self.Metrics.Clear;

      GNATCOLL.SQL.Sessions.Free;
   end Cleanup;

   ---------------
   -- Load_Data --
   ---------------

   overriding procedure Load_Data
     (Self : in out Database_Loader_Type)
   is
      Resource        : Resource_Access := Self.Resources.First_Element;
      Resource_Id     : constant Natural := Self.Resources.First_Key;
      Resource_Name   : constant String := To_String (Resource.Name);
      Resource_File   : constant GNATCOLL.VFS.Virtual_File :=
                         GNATCOLL.VFS.Create_From_UTF8 (Resource_Name);
      Session         : constant GNATCOLL.SQL.Sessions.Session_Type :=
                         GNATCOLL.SQL.Sessions.Get_New_Session;
      List            : Database.Orm.Resource_Message_List :=
                         Database.Orm.Filter
                          (Database.Orm.All_Resources_Messages,
                           Resource_Id => Resource_Id).Get (Session);
      R               : Database.Orm.Resource_Message;
      M               : Database.Orm.Message;
      Ranking         : Integer;
      Message         : GNAThub_Message_Access;
      Metric          : Metric_Access;
      Rule            : GNAThub.Rule_Access;
      Severity        : GNAThub.Severity_Access;
      Position        : GNAThub.Severity_Natural_Maps.Cursor;

      function Get_Importance_From_Ranking return Message_Importance_Type;

      procedure Load_Entities;

      procedure Load_Message
        (Kind : Resource_Kind_Type; Line : Integer; Column : Integer);

      procedure Load_Metric (Kind : Resource_Kind_Type;  Line : Integer);

      ---------------------------------
      -- Get_Importance_From_Ranking --
      ---------------------------------

      function Get_Importance_From_Ranking return Message_Importance_Type is
      begin
         --  Needs to be synchronized with the Message_Importance_Type
         --  enumeration values' position.
         return Message_Importance_Type'Val (Ranking);
      end Get_Importance_From_Ranking;

      -------------------
      -- Load_Entities --
      -------------------

      procedure Load_Entities
      is
         Messages         : Database.Orm.Message_List;
         Entities         : Database.Orm.Entity_List :=
                             Database.Orm.Filter
                              (Database.Orm.All_Entities,
                               Resource_Id => Resource_Id).Get (Session);
         Entity           : Database.Orm.Entity;
         Sub_Message      : Database.Orm.Entity_Message;
         Sub_Message_List : Database.Orm.Entity_Message_List;
      begin
         --  The entities of the file
         while Entities.Has_Row loop
            Entity := Entities.Element;
            Sub_Message_List := Database.Orm.Filter
              (Database.Orm.All_Entities_Messages, Entity_Id => Entity.Id)
              .Get (Session);

            --  The messages/metrics of the current entity
            while Sub_Message_List.Has_Row loop
               Sub_Message := Sub_Message_List.Element;
               Messages := Database.Orm.Filter
                 (Database.Orm.All_Messages, Id => Sub_Message.Message_Id)
                 .Get (Session);

               while Messages.Has_Row loop
                  M := Messages.Element;
                  if Self.Rules.Contains (M.Rule_Id) then
                     Load_Message
                       (Resource.Kind, Entity.Line, Entity.Col_Begin);
                  elsif Self.Metrics.Contains (M.Rule_Id) then
                     Load_Metric (Resource.Kind, Entity.Line);
                  end if;
                  Messages.Next;
               end loop;
               Sub_Message_List.Next;
            end loop;

            Entities.Next;
         end loop;
      end Load_Entities;

      ------------------
      -- Load_Message --
      ------------------

      procedure Load_Message
        (Kind : Resource_Kind_Type; Line : Integer; Column : Integer)
      is
         Project : GNATCOLL.Projects.Project_Type;
         File    : GNATCOLL.VFS.Virtual_File;
      begin
         --  Depending on the resource kind, retrieve the project directly
         --  from the resource filename.
         case Kind is
            when From_Project =>
               Project :=
                 GPS.Kernel.Project.Get_Project_Tree
                   (Self.Module.Get_Kernel).Project_From_Name (Resource_Name);
               File := GNATCOLL.VFS.No_File;
            when others =>
               Project :=
                 GPS.Kernel.Project.Get_Project (Self.Module.Get_Kernel);
               File := Resource_File;
         end case;

         Ranking := M.Ranking;
         Severity := Self.Module.Get_Severity (Get_Importance_From_Ranking);
         Rule     := Self.Rules (M.Rule_Id);
         Position := Rule.Count.Find (Severity);

         if Severity_Natural_Maps.Has_Element (Position) then
            Rule.Count.Replace_Element
              (Position, Severity_Natural_Maps.Element (Position) + 1);
         else
            Rule.Count.Insert (Severity, 1);
         end if;

         Message := new GNAThub_Message;
         GNAThub.Messages.Initialize
           (Self      => Message,
            Container =>
              Self.Module.Get_Kernel.Get_Messages_Container,
            Severity  => Severity,
            Rule      => Rule,
            Text      => To_Unbounded_String (Database.Orm.Data (M)),
            File      => File,
            Line      => Line,
            Column    => Basic_Types.Visible_Column_Type (Column));

         --  Insert the message in the module's tree

         Insert_Message
           (Self    => Self,
            Project => Project,
            Message => Message);

         Messages_Vectors.Append
           (Self.Messages,
            GPS.Kernel.Messages.References.Create
              (GPS.Kernel.Messages.Message_Access (Message)));
      end Load_Message;

      -----------------
      -- Load_Metric --
      -----------------

      procedure Load_Metric (Kind : Resource_Kind_Type; Line : Integer)
      is
         Project : GNATCOLL.Projects.Project_Type;
         File    : GNATCOLL.VFS.Virtual_File;
      begin
         --  Depending on the resource kind, retrieve the project directly
         --  from the resource filename.
         case Kind is
            when From_Project =>
               Project :=
                 GPS.Kernel.Project.Get_Project_Tree
                   (Self.Module.Get_Kernel).Project_From_Name (Resource_Name);
               File := GNATCOLL.VFS.No_File;
            when others =>
               Project :=
                 GPS.Kernel.Project.Get_Project (Self.Module.Get_Kernel);
               File := Resource_File;
         end case;

         Rule := Self.Metrics (M.Rule_Id);
         Metric := new Metric_Record'(Severity => Severity,
                                      Rule     => Rule,
                                      Value    =>
                                        Float'Value
                                          (Database.Orm.Data (M)));
         Insert_Metric
           (Self    => Self,
            Project => Project,
            File    => File,
            Line    => Line,
            Metric  => Metric);
      end Load_Metric;

   begin
      while List.Has_Row loop
         R := List.Element;
         M := Database.Orm.Filter
           (Database.Orm.All_Messages, Id => R.Message_Id)
           .Get (Session).Element;

         if Self.Rules.Contains (M.Rule_Id) then
            Load_Message (Resource.Kind, R.Line, R.Col_Begin);
         elsif Self.Metrics.Contains (M.Rule_Id) then
            Load_Metric (Resource.Kind, R.Line);
         end if;

         List.Next;
      end loop;

      if Resource.Kind = From_File then
         Load_Entities;
      end if;
      Self.Resources.Delete_First;
      Free_Resource (Resource);
   end Load_Data;

   --------------------
   -- Load_Resources --
   --------------------

   procedure Load_Resources (Self : in out Database_Loader_Type'Class) is
      Session  : constant GNATCOLL.SQL.Sessions.Session_Type :=
                   GNATCOLL.SQL.Sessions.Get_New_Session;

      procedure Retrieve_Kind (Kind : Resource_Kind_Type);

      -------------------
      -- Retrieve_Kind --
      -------------------

      procedure Retrieve_Kind (Kind : Resource_Kind_Type)
      is
         List     : Database.Orm.Resource_List := Database.Orm.Filter
           (Database.Orm.All_Resources,
            Kind => Resource_Kind_Type'Pos (Kind)).Get (Session);
         R        : Database.Orm.Resource;
         Resource : Resource_Access;
      begin
         while List.Has_Row loop
            R := List.Element;
            Resource := new Resource_Record'
              (Name => To_Unbounded_String (R.Name),
               Kind => Kind);
            Self.Resources.Insert (R.Id, Resource);
            List.Next;
         end loop;
      end Retrieve_Kind;

   begin
      Retrieve_Kind (From_Project);
      Retrieve_Kind (From_Directory);
      Retrieve_Kind (From_File);
   end Load_Resources;

   ----------------------------------
   -- Load_Tools_Rules_And_Metrics --
   ----------------------------------

   procedure Load_Tools_Rules_And_Metrics
     (Self : in out Database_Loader_Type'Class)
   is
      Session : constant GNATCOLL.SQL.Sessions.Session_Type :=
                  GNATCOLL.SQL.Sessions.Get_New_Session;
      TL      : Database.Orm.Tool_List := Database.Orm.All_Tools.Get (Session);
      T       : Database.Orm.Tool;
      Tool    : Tool_Access;

      procedure Retrieve_Kind (M : in out Rule_Maps.Map; Kind : Integer);
      --  There are two types of rules:
      --    Rule_Kind = 0: its messages are stored as String in the database
      --    Metric_Kind = 1: its messages are stored as Float in the database

      ------------------
      -- Retieve_Kind --
      ------------------

      procedure Retrieve_Kind (M : in out Rule_Maps.Map; Kind : Integer)
      is
         RL   : Database.Orm.Rule_List;
         R    : Database.Orm.Rule;
         Rule : Rule_Access;
      begin
         RL := Database.Orm.Filter (T.Tool_Rules, Kind => Kind).Get (Session);

         while RL.Has_Row loop
            R := RL.Element;
            Rule :=
              Self.Module.Get_Or_Create_Rule
                (Tool       => Tool,
                 Name       => To_Unbounded_String (R.Name),
                 Identifier => To_Unbounded_String (R.Identifier));
            M.Insert (R.Id, Rule);
            RL.Next;
         end loop;
      end Retrieve_Kind;

   begin
      while TL.Has_Row loop
         T    := TL.Element;
         Tool := Self.Module.Get_Or_Create_Tool (To_Unbounded_String (T.Name));

         Retrieve_Kind (Self.Rules, Kind => 0);
         Retrieve_Kind (Self.Metrics, Kind => 1);

         TL.Next;
      end loop;
   end Load_Tools_Rules_And_Metrics;

end GNAThub.Loader.Databases;