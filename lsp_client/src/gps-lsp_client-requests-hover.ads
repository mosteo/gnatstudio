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

package GPS.LSP_Client.Requests.Hover is

   type Abstract_Hover_Request is
     abstract new LSP_Request with record
      File     : Virtual_File;
      Position : LSP.Messages.Position;
   end record;

   function Params
     (Self : Abstract_Hover_Request)
      return LSP.Messages.TextDocumentPositionParams;
   --  Return parameters of the request to be sent to the server.

   procedure On_Result_Message
     (Self   : in out Abstract_Hover_Request;
      Result : LSP.Messages.Optional_Hover) is abstract;
   --  Called when a result response is received from the server.

   overriding function Method
     (Self : Abstract_Hover_Request) return VSS.Strings.Virtual_String;

   overriding procedure Params
     (Self   : Abstract_Hover_Request;
      Stream : not null access LSP.JSON_Streams.JSON_Stream'Class);

   overriding function Is_Request_Supported
     (Self    : Abstract_Hover_Request;
      Options : LSP.Messages.ServerCapabilities)
      return Boolean;

   overriding procedure On_Result_Message
     (Self   : in out Abstract_Hover_Request;
      Stream : not null access LSP.JSON_Streams.JSON_Stream'Class);

end GPS.LSP_Client.Requests.Hover;
