(*************************************************************************)
(* Reads records from a dBASE .DBF file. Should support file versions    *)
(* 3, 4, 5, and maybe 7. Note that support for versions other than 3 has *)
(* never been tested so proceed with caution.                            *)
(*                                                                       *)
(* Copyright (C) 2018  Jean-Paul LaBarre                                 *)
(*                                                                       *)
(* This file is part of ManglDat.                                        *)
(*                                                                       *)
(* ManglDat is free software: you can redistribute it and/or modify      *)
(* it under the terms of the GNU General Public License as published by  *)
(* the Free Software Foundation, either version 3 of the License, or     *)
(* (at your option) any later version.                                   *)
(*                                                                       *)
(* ManglDat is distributed in the hope that it will be useful,           *)
(* but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(* GNU General Public License for more details.                          *)
(*                                                                       *)
(* You should have received a copy of the GNU General Public License     *)
(* along with ManglDat. If not, see <http://www.gnu.org/licenses/>.      *)
(*************************************************************************)

Unit ReadDBF;

Interface

Type

  HeaderPtr = ^HeaderNode;
  HeaderNode = record    (* Field Descriptor Array *)
                 FieldName : String;
                 FieldType : Char;
                 DataAddress : LongWord;
                 FieldLength : Byte;
                 FieldDecimal : Byte;
                 WorkAreaID : Byte;
                 SetFields : Byte;
                 ProdMDXFlag : Byte;
                 Autoincrement : LongWord;
                 NextHeader : HeaderPtr;
               end;

  StdPropPtr = ^StdPropNode; (* Standard Property and Constraint *)
  StdPropNode = record       (* Descriptor Array                 *)
                 GenNum : Word;
                 TableFieldOffset : Word;
                 PropType : Byte;
                 FieldType : Byte;
                 Constraint : Byte;
                 DataOffset : Word;
                 FieldWidth : Word;
                 NextStdProp : StdPropPtr;
               end;

  CustPropPtr = ^CustPropNode; (* Custom Property Descriptor Array *)
  CustPropNode = record
                 GenNum : Word;
                 TableFieldOffset : Word;
                 FieldType : Byte;
                 NameOffset : Word;
                 NameLength : Word;
                 DataOffset : Word;
                 DataLength : Word;
                 NextCustProp : CustPropPtr;
               end;

  RIPropPtr = ^ RIPropNode; (* Referential Integrity Property *)
  RIPropNode = record       (* Descriptor Array               *)
                 Relation : Byte;
                 Number : Word;
                 NameOffset : Word;
                 NameLength : Word;
                 ForeignTableNameOffset : Word;
                 ForeignTableNameLength : Word;
                 Action : Byte;
                 LinkingKeyFields : Word;
                 LocalTableTagNameOffset : Word;
                 LocalTableTagNameLength : Word;
                 ForeignTableTagNameOffset : Word;
                 ForeignTableTagNameLength : Word;
                 NextRIProp : RIPropPtr;
               end;

  FieldPropPtr = ^FieldPropNode; (* Field Poperties Structure     *)
  FieldPropNode = record         (* Only used for dBase Version 7 *)
                 NumStdProp : Word;
                 StartStd : Word;
                 NumCustProp : Word;
                 StartCust : Word;
                 NumRIProp : Word;
                 StartRI : Word;
                 StartOfData : Word;
                 StructureSize : Word;
                 StdProp : StdPropPtr;
                 CustProp : CustPropPtr;
                 RIProp : RIPropPtr;
               end;

  DataPtr = ^DataNode;
  DataNode = record
               Data : String;
               NextData : DataPtr;
             end;

  RecordType = record
                 Deleted : char;  (* ' ' space = ok, '*' asterisk = deleted *)
                 RecordData : DataPtr;
               end;

  dBaseType = record
                Signature : Byte;
                dBaseLevel : ShortInt;
                ContainsMemo : Boolean;
                dBASE4Memo : Boolean;
                ContainsSQLTable : Boolean;
                Year : Word;
                Month : Byte;
                Day : Byte;
                NumRecords : LongWord;
                BytesInHeader : Word;
                BytesInRecord : Word;
                IncompTrans : Boolean; (* Incomplete dBASE IV Transaction *)
                Encryption : Boolean;  (* dBASE IV Encryption *)
                ProdMDXFlag : Byte;    (* Production MDX Flag *)
                LangDriverID : Byte;   (* Language Driver ID *)
                LangDriverName : String; (* Language Driver Name *)
                Header  : HeaderPtr;
                FieldProp : FieldPropPtr; (* Field Properties, dBase 7 only. *)
              end;


Procedure ReadHeader(var infile : text; var dBase : dBaseType);

Procedure ReadRecord(var infile : text; dBase : dBaseType; var rec : RecordType);

Procedure FreedBase(var dBase : dBaseType);

Procedure FreeRecord(var rec : RecordType);

Function GetField(FieldName : String; dBase : dBaseType; Rec : RecordType) : String;


Implementation

Uses chopchop;


Function ReadByte(var infile : text) : Byte;
var c : char;
begin
  Read(infile, c);
  ReadByte := ord(c);
end;


Function ReadWord(var infile : text) : Word;
(* Reads a word from infile, least significant byte first. *)
var w : Word;
begin
  w := ReadByte(infile);
  w := ReadByte(infile) shl 8 or w;
  ReadWord := w;
end;


Function ReadLongWord(var infile : text) : LongWord;
(* Reads a LongWord from infile, least significant byte first. *)
var lw : LongWord;
begin
  lw := ReadWord(infile);
  lw := ReadWord(infile) shl 16 or lw;
  ReadLongWord := lw;
end;


Function ReadString(var infile : text; length : Byte) : String;
(* Reads length characters from infile. *)
var
  s : String;
  c : char;
  i : byte;
begin
  s := '';
  for i := 1 to length do
    begin
      Read(infile,c);
      s := s + c;
    end;
  ReadString := s;
end;


Procedure InitFieldProp(var FieldProp : FieldPropNode);
begin
  FieldProp.StdProp := nil;
  FieldProp.CustProp := nil;
  FieldProp.RIProp := nil;
end;


Procedure InitdBASE(var dBase : dBaseType);
begin
  dBase.Header := nil;
  dBase.FieldProp := nil;
end;


Procedure FreeFieldProp(var FieldProp : FieldPropNode);
var
  s, ts : StdPropPtr;
  c, tc : CustPropPtr;
  r, tr : RIPropPtr;
begin
  s := FieldProp.StdProp;
  while s <> nil do
     begin
       ts := s;
       s := s^.NextStdProp;
       dispose(ts);
     end;
  c := FieldProp.CustProp;
  While c <> nil do
     begin
       tc := c;
       c := c^.NextCustProp;
       dispose(tc);
     end;
  r := FieldProp.RIProp;
  While r <> nil do
     begin
       tr := r;
       r := r^.NextRIProp;
       dispose(tr);
     end;
end;


Procedure FreedBase(var dBase : dBaseType);
var
  head : HeaderPtr;
  thead : HeaderPtr;
begin
  head := dBase.Header;
  while head <> nil do
     begin
       thead := head;
       head := head^.NextHeader;
       dispose(thead);
    end;
  dBase.Header := nil;
  if dBase.FieldProp <> nil then
     begin
       FreeFieldProp(dBase.FieldProp^);
       dispose(dBase.FieldProp);
       dBase.FieldProp := nil;
     end;
end;


Procedure FreeRecord(var rec : RecordType);
var
  data : DataPtr;
  tdata : DataPtr;
begin
  data := rec.RecordData;
  While data <> nil do
      begin
        tdata := data;
        data := data^.NextData;
        dispose(tdata);
      end;
  rec.RecordData := nil;
end;


Procedure ReadRecord(var infile : text; dBase : dBaseType; var rec : RecordType);
var
  data : DataPtr;
  head : HeaderPtr;
  colcount : Word;
  headers : Word;
  tstring : String;

begin

 (* First byte signals if record is deleted. *)

  Read(infile, rec.Deleted);

  New(rec.RecordData);
  data := rec.RecordData;

  head := dBase.Header;

  colcount := 1;
  headers := (dBase.BytesInHeader - 33) div 32;

  While (colcount <= headers) do
     begin

       (* Next is data, use FieldLength and FiledType from header.         *)
       (* B - Binary, 10 digits representing a .DBT block number.          *)
       (* C - Character, All OEM code page characters.                     *)
       (* D - Date, stored internally as 8 digits in YYYYMMDD format.      *)
       (* F - dBASE IV Floating Point { - . 0 1 2 3 4 5 6 7 8 9 }          *)
       (* G - General, 10 digits or OLE, representing a .DBT block number. *)
       (* N - Numeric { - . 0 1 2 3 4 5 6 7 8 9 }                          *)
       (* L - Logical { ? Y y N n T t F f } '?' when not initilized.       *)
       (* M - Memo, 10 digits representing a .DBT block number.            *)

        case head^.FieldType of
          'B' : data^.Data := ReadString(infile, 10);
          'C' : data^.Data := ReadString(infile, head^.FieldLength);
          'D' : begin (* Converting to MM/DD/YYYY format for now. *)
                  tstring := ReadString(infile, 4);
                  data^.Data := ReadString(infile, 2) + '/';
                  data^.Data := data^.Data + ReadString(infile, 2) + '/' + tstring;
                end;
          'F' : data^.Data := ReadString(infile, head^.FieldLength);
          'G' : data^.Data := ReadString(infile, 10);
          'N' : data^.Data := ReadString(infile, head^.FieldLength);
          'L' : data^.Data := ReadString(infile, 1);
          'M' : data^.Data := ReadString(infile, 10);
        otherwise (* Unknown Field Type. Attempt to read data anyway, store as string. *)
                data^.Data := ReadString(infile, head^.FieldLength);
        end; (* case *)

        head := head^.NextHeader;

        if (colcount < headers) then
           New(data^.NextData)
        else
           data^.NextData := nil;
        data := data^.NextData;

        colcount := colcount + 1;

     end; (* loop *)

end;


Procedure Read3Header(var infile : text; var dBase : dBaseType);

(* Should be able to read dBASE III Plus, dBASE IV, and dBase 5     *)
(* file headers.  Reads entire header except for the first byte,    *)
(* which should have been read before calling this procedure, to    *)
(* determine which Read#Header to call.                             *)

var
  desc : Word;
  head : HeaderPtr;
  headers : Word;
  tbyte : byte;
  lcv : Word;

begin

  (* Bytes 1-3: The date of the last update, YYMMDD format. *)

  dBase.Year := ReadByte(infile) + 1900;
  dBase.Month := ReadByte(infile);
  dBase.Day := ReadByte(infile);

  (* Bytes 4-7: Number of records in the table. *)

  dBase.NumRecords := ReadLongWord(infile);

  (* Bytes 8-9: Number of bytes in the header. *)

  dBase.BytesInHeader := ReadWord(infile);

  (* Bytes 10-11: Number of bytes in the record. *)

  dBase.BytesInRecord := ReadWord(infile);

  (* Bytes 12-13: Reserved *);

  for lcv := 12 to 13 do tbyte := ReadByte(infile);

  (* Byte 14: dBASE IV incomplete transaction flag. *)

  dBase.IncompTrans := ReadByte(infile) <> 0;

  (* Byte 15: dBASE IV encryption flag. *)

  dBase.Encryption := ReadByte(infile) <> 0;

  (* Bytes 16-27: Reserved For dBASE III PLUS on LAN. *)

  for lcv := 16 to 27 do tbyte := ReadByte(infile);

  (* Byte 28: Production MDX Flag                                  *)
  (*          0x01 - A production .MDX file exists for this table. *)
  (*          0x00 - No .MDX file exists.                          *)

  dBase.ProdMDXFlag := ReadByte(infile);

  (* Byte 29: Language Driver ID *)

  dBase.LangDriverID := ReadByte(infile);

  (* Bytes 30-31: Reserved *)

  for lcv := 30 to 31 do tbyte := ReadByte(infile);

  (* 32 - n: Field Descriptor Array *)

  (* Should be 32 bytes per descriptor, can determine number of  *)
  (* descriptors based on number of bytes in header.             *)

  headers := (dBase.BytesInHeader - 33) div 32;

  if headers > 0 then
     New(dBase.Header)
  else
     dBase.Header := nil;

  head := dBase.header;

  for desc := 1 to headers do
    begin

     (* Bytes 0-10: Field name in ASCII (zero-filled). *)

      head^.FieldName := ReadString(infile,11);

     (* Byte 11: Field Type in ASCII *)
     (*    C, D,       L, M, N: dBase III   *)
     (*    C, D, F,    L, M, N: dBASE IV    *)
     (*    C, D, F,    L, M, N: dBase 5 Dos *)
     (* B, C, D,    G, L, M, N: dBase 5 Win *)

      Read(infile, head^.FieldType);

     (* Bytes 12-15: Field Data Address. *)
     (*              Address is set in memory, not usefull on disk. *)

      head^.DataAddress := ReadLongWord(infile);

     (* Byte 16: Field Length *)

      head^.FieldLength := ReadByte(infile);

     (* Byte 17: Field Decimal Count *)

      head^.FieldDecimal := ReadByte(infile);

     (* Bytes 18-19: Reserved For dBASE III Plus on LAN. *)

      for lcv := 18 to 19 do tbyte := ReadByte(infile);

     (* Byte 20: Work Area ID. *)

      head^.WorkAreaID := ReadByte(infile);

     (* Bytes 21-22: Reserved For dBASE III Plus on LAN. *)

      for lcv := 21 to 22 do tbyte := ReadByte(infile);

     (* Byte 23: SET FIELDS Flag. *)

      head^.SetFields := ReadByte(infile);

     (* Bytes 24-30: Reserved Bytes. *);

      for lcv := 24 to 30 do tbyte := ReadByte(infile);

     (* Byte 31: Production MDX Flag                                  *)
     (*          0x01 - A production .MDX file exists for this table. *)
     (*          0x00 - No .MDX file exists.                          *)

      head^.ProdMDXFlag := ReadByte(infile);

     (* dBase III, IV, and 5 do not have an autoincrement field. *)
     (* just set to zero. *)

      head^.Autoincrement := 0;

      if desc < headers then
         new(head^.NextHeader)
      else
         head^.NextHeader := nil;
      head := head^.NextHeader;

   end; (* descriptor array *)

   (* Byte n+1: Field Terminator *)

   tbyte := ReadByte(infile);

end;


Procedure Read4Header(var infile : text; var dBase : dBaseType);
(* Should be able to read a dBASE 7 file header.           *)
(* Doesn't read the first byte, that should have been read *)
(* before calling this procedure, to determine which       *)
(* Read#Header to call.                                    *)

var
  desc : Word;
  headers : Word;
  tbyte : Byte;
  lcv : Word;
  head : HeaderPtr;
  StdProp : StdPropPtr;
  CustProp : CustPropPtr;
  RIProp : RIPropPtr;

begin
  (* Bytes 1-3: The date of the last update, YYMMDD format. *)

  dBase.Year := ReadByte(infile) + 1900;
  dBase.Month := ReadByte(infile);
  dBase.Day := ReadByte(infile);

  (* Bytes 4-7: Number of records in the table. *)

  dBase.NumRecords := ReadLongWord(infile);

  (* Bytes 8-9: Number of bytes in the header. *)

  dBase.BytesInHeader := ReadWord(infile);

  (* Bytes 10-11: Number of bytes in the record. *)

  dBase.BytesInRecord := ReadWord(infile);

  (* Bytes 12-13: Reserved *);

  tbyte := ReadByte(infile);
  tbyte := ReadByte(infile);

  (* Byte 14: Flag indicating incomplete dBASE IV transaction. *)

  tbyte := ReadByte(infile);
  dBase.IncompTrans := tbyte <> 0;

  (* Byte 15: dBASE IV encryption flag. *)

  tbyte := ReadByte(infile);
  dBase.Encryption := tbyte <> 0;

  (* Bytes 16-27: Reserved For Multiuser Processing. *)

  for lcv := 16 to 27 do tbyte := ReadByte(infile);

  (* Byte 28: Production MDX Flag                                  *)
  (*          0x01 - A production .MDX file exists for this table. *)
  (*          0x00 - No .MDX file exists.                          *)

  dBase.ProdMDXFlag := ReadByte(infile);

  (* Byte 29: Language Driver ID *)

  dBase.LangDriverID := ReadByte(infile);

  (* Bytes 30-31: Reserved *)

  tbyte := ReadByte(infile);
  tbyte := ReadByte(infile);

  (* Bytes 32-63: Language Driver Name *)

  dBase.LangDriverName := ReadString(infile,32);

  (* Bytes 64-67: Reserved *)

  for lcv := 64 to 67 do tbyte := ReadByte(infile);

  (***** Bytes 68-n: Field Descriptor Array *****)

  (* Should be 48 bytes per descriptor, can determine number of  *)
  (* descriptors based on number of bytes in header.             *)

  headers := (dBase.BytesInHeader - 67) div 48;

  if headers > 0 then
     New(dBase.Header)
  else
     dBase.Header := nil;

  head := dBase.header;

  for desc := 1 to headers do
    begin

     (* Bytes 0-31: Field name in ASCII (zero-filled). *)

      head^.FieldName := ReadString(infile,32);

     (* Byte 32: Field Type in ASCII *)
     (* +, @, 0, B, C, D, F, G, I, L, M, N: dBase 7   *)

      Read(infile, head^.FieldType);

     (* Byte 33: Field Length *)

      head^.FieldLength := ReadByte(infile);

     (* Byte 34: Field Decimal Count *)

      head^.FieldDecimal := ReadByte(infile);

     (* Bytes 35-36: Reserved. *)

      for lcv := 35 to 36 do tbyte := ReadByte(infile);

     (* Byte 37: Production .MDX field flag.                          *)
     (*          0x01 - A production .MDX file exists for this table. *)
     (*          0x00 - No .MDX file exists.                          *)

      head^.ProdMDXFlag := ReadByte(infile);

     (* Bytes 38-39: Reserved. *)

      for lcv := 38 to 39 do tbyte := ReadByte(infile);

     (* Bytes 40-43: Next Autoincrement Value. *)
     (* If the field type is Autoincrement, 0x00 otherwise. *)

      head^.Autoincrement := ReadLongWord(infile);

     (* Bytes 44-47: Reserved *)

     for lcv := 44 to 47 do tbyte := ReadByte(infile);

      if desc < headers then
         new(head^.NextHeader)
      else
         head^.NextHeader := nil;
      head := head^.NextHeader;

   end; (* descriptor array *)

   (***** Byte n+1: Field Terminator *****)

   tbyte := ReadByte(infile);

   (***** Bytes n+2 - m: Field Properties Structure *****)

      New(dBase.FieldProp);
      InitFieldProp(dBase.FieldProp^);

     (* Bytes 0-1: Number of Standard Properties *)

      dBase.FieldProp^.NumStdProp := ReadWord(infile);

     (* Bytes 2-3: Start of Standard Property Descriptor Array *)

      dBase.FieldProp^.StartStd := ReadWord(infile);

     (* Bytes 4-5: Number of Custom Properties *)

      dBase.FieldProp^.NumCustProp := ReadWord(infile);

     (* Bytes 6-7: Start of Custom Property Descriptor Array *)

      dBase.FieldProp^.StartCust := ReadWord(infile);

     (* Bytes 8-9: Number of Referential Integrity (RI) Properties *)

      dBase.FieldProp^.NumRIProp := ReadWord(infile);

     (* Bytes 10-11: Start of RI Property Descriptor Array *)

      dBase.FieldProp^.StartRI := ReadWord(infile);

     (* Bytes 12-13: Start of Data *)

      dBase.FieldProp^.StartOfData := ReadWord(infile);

     (* Bytes 14-15: Actual Size of Structure *)

      dBase.FieldProp^.StructureSize := ReadWord(infile);

     (**** Bytes 16-n: Standard Property Descriptor Array ****)
     (* n = 15 * (number of standard properties) + 16        *)

      if dBase.FieldProp^.NumStdProp > 0 then new(dBase.FieldProp^.StdProp);

      StdProp := dBase.FieldProp^.StdProp;

      for desc := 1 to dBase.FieldProp^.NumStdProp do
          begin

            (* Bytes 0-1: Generational Number *)

             StdProp^.GenNum := ReadWord(infile);

            (* Bytes 2-3: Table Field Offset *)

             StdProp^.TableFieldOffset := ReadWord(infile);

            (* Byte 4: Property Type   *)
            (* 01: Required            *)
            (* 02: Minimum             *)
            (* 03: Maximum             *)
            (* 04: Default             *)
            (* 06: Database Constraint *)

             StdProp^.PropType := ReadByte(infile);

            (* Byte 5: Field Type       *)
            (* 00: No Type - Constraint *)
            (* 01: Character            *)
            (* 02: Numeric              *)
            (* 03: Memo                 *)
            (* 04: Logical              *)
            (* 05: Date                 *)
            (* 06: Float                *)
            (* 08: OLE                  *)
            (* 09: Binary               *)
            (* 11: Long                 *)
            (* 12: Timestamp            *)
            (* 13: Double               *)
            (* 14: AutoIncrement        *)

             StdProp^.FieldType := ReadByte(infile);

            (* Byte 6: Constraint *)
            (* 0x00 if the array element is a constraint *)
            (* 0x02 otherwise                            *)

             StdProp^.Constraint := ReadByte(infile);

            (* Bytes 7-10: Reserved *)

             for lcv := 7 to 10 do tbyte := ReadByte(infile);

            (* Bytes 11-12: Data Offset *)

             StdProp^.DataOffset := ReadWord(infile);

            (* Bytes 13-14: Database Field Width *)

             StdProp^.FieldWidth := ReadWord(infile);

             if desc < dBase.FieldProp^.NumStdProp then
                new(StdProp^.NextStdProp)
             else
                StdProp^.NextStdProp := nil;

             StdProp := StdProp^.NextStdProp;

          end; (* Standard Property Descriptors *)

     (**** Bytes n+1 - m: Custom Property Descriptor Array ****)
     (* m = n + 14 * (number of custom properties)            *)

      if dBase.FieldProp^.NumCustProp > 0 then new(dBase.FieldProp^.CustProp);

      CustProp := dBase.FieldProp^.CustProp;

      for desc := 1 to dBase.FieldProp^.NumCustProp do
          begin

           (* Bytes 0-1: Generational Number *)

            CustProp^.GenNum := ReadWord(infile);

           (* Bytes 2-3: Table Field Offset *)

            CustProp^.TableFieldOffset := ReadWord(infile);

           (* Byte 4: Field Type *)
           (* 01: Char           *)
           (* 02: Numeric        *)
           (* 03: Memo           *)
           (* 04: Logical        *)
           (* 05: Date           *)
           (* 06: Float          *)
           (* 08: OLE            *)
           (* 09: Binary         *)
           (* 11: Long           *)
           (* 12: Timestamp      *)
           (* 13: Double         *)
           (* 14: Autoincrement  *)

            CustProp^.FieldType := ReadByte(infile);

           (* Byte 5: Reserved *)

            tbyte := ReadByte(infile);

           (* Bytes 6-7: Custom Property Name Offset *)

            CustProp^.NameOffset := ReadWord(infile);

           (* Bytes 8-9: Custom Property Name Length *)

            CustProp^.NameLength := ReadWord(infile);

           (* Bytes 10-11: Custom Property Data Offset *)

            CustProp^.DataOffset := ReadWord(infile);

           (* Bytes 12-13: Custom Property Data Length *)

            CustProp^.DataLength := ReadWord(infile);

            if desc < dBase.FieldProp^.NumCustProp then
               new(CustProp^.NextCustProp)
            else
               CustProp^.NextCustProp := nil;

            CustProp := CustProp^.NextCustProp;

          end; (* Custom Property Descriptors *)

     (**** Bytes m+1 - o: Referential Integrity Property Descriptor Array ****)
     (* 0 = m + 22 * (Number of RI Properties)                               *)

      if dBase.FieldProp^.NumRIProp > 0 then new(dBase.FieldProp^.RIProp);

      RIProp := dBase.FieldProp^.RIProp;

      for desc := 1 to dBase.FieldProp^.NumRIProp do
          begin

           (* Byte 0: Relation        *)
           (* 0x07: Master (parent)   *)
           (* 0x08: Dependent (child) *)

            RIProp^.Relation := ReadByte(infile);

           (* Bytes 1-2: Sequential Number *)
           (* 1 based counting. If 0 this RI rule has been droped. *)

            RIProp^.Number := ReadWord(infile);

           (* Bytes 3-4: RI Rule Name Offset *)

            RIProp^.NameOffset := ReadWord(infile);

           (* Bytes 5-6: RI Rule Name Length *)

            RIProp^.NameLength := ReadWord(infile);

           (* Bytes 7-8: Foreign Table Name Offset *)

            RIProp^.ForeignTableNameOffset := ReadWord(infile);

           (* Bytes 9-10: Foreign Table Name Length *)

            RIProp^.ForeignTableNameLength := ReadWord(infile);

           (* Byte 11: Update & Delete Behaviour *)
           (* 0x10: Update Cascade               *)
           (* 0x01: Delete Cascade               *)

            RIProp^.Action := ReadByte(infile);

           (* Bytes 12-13: Number of Fields in Linking Key *)

            RIProp^.LinkingKeyFields := ReadWord(infile);

           (* Bytes 14-15: Local Table Tag Name Offset *)

            RIProp^.LocalTableTagNameOffset := ReadWord(infile);

           (* Bytes 16-17: Local Table Tag Name Length *)

            RIProp^.LocalTableTagNameLength := ReadWord(infile);

           (* Bytes 18-19: Foreign Table Tag Name Offset *)

            RIProp^.ForeignTableTagNameOffset := ReadWord(infile);

           (* Bytes 20-21: Foreign Table Tag Name Length *)

            RIProp^.ForeignTableTagNameLength := ReadWord(infile);

            if desc < dBase.FieldProp^.NumRIProp then
               new(RIProp^.NextRIProp)
            else
               RIProp^.NextRIProp := nil;

            RIProp := RIProp^.NextRIProp;

          end; (* RI Property Descriptors *)

end;


Procedure ReadHeader(var infile : text; var dBase : dBaseType);
begin
  initdBASE(dBase);

  (* First Read File type byte to determine what     *)
  (* dBASE version we are dealing with.              *)

  (* The first byte determines the dBase file "Level" and the *)
  (* presence of any memo file or SQL table. The following is *)
  (* not a complete list of file signatures and is probably   *)
  (* wrong. There is much conflicting documentation out there.*)

  (* 02h - dBASE II or FoxBase                                *)
  (* 03h - dBASE III without memo .DBT file.                  *)
  (* 04h - dBASE IV without memo .DBT file.                   *)
  (* 05h - dBASE V without memo .DBT file.                    *)
  (* 07h - VISUAL OBJECTS (ver 1.0) for dBase III w/o memo.   *)
  (* 30h - Visual FoxPro or Visual FoxPro with DBC.           *)
  (* 31h - Visual FoxPro with AutoIncrement field.            *)
  (* 43h - .dbv memo var size (Flagship).                     *)
  (* 7Bh - dBASE IV with memo.                                *)
  (* 83h - dBASE III Plus with a memo.                        *)
  (* 84h - dBASE 7 with a memo .DBT file.                     *)
  (* 8Bh - dBASE IV Plus with a dBASE IV memo .DBT file.      *)
  (* 8Ch - dBASE 7 with a dBASE IV memo .DBT file.            *)

  dBase.Signature := ReadByte(infile);
  dBase.dBaseLevel := dBase.Signature and 7;
  dBase.ContainsMemo := (dBase.Signature and 136) <> 0;
  dBase.dBASE4Memo := (dBase.Signature and 8) <> 0;
  dBase.ContainsSQLTable := (dBase.Signature and 112) <> 0;

  if dBase.dBaseLevel = 3 then Read3Header(infile,dBase)
  else if dBase.dBaseLevel = 4 then Read4Header(infile,dBase)
  else
     begin
       Writeln('Unknown Format');
       Halt(0);
     end;
end;


Function GetField(FieldName : String; dBase : dBaseType; Rec : RecordType) : String;
(* Returns the data field in Rec for the coresponding     *)
(* FieldName in dBase. Returns empty string if not found. *)
(* Removes leading and trailing Nulls (chr(0)) and spaces *)
(* before strings are compaired.                          *)
var
  head : HeaderPtr;
  data : DataPtr;
begin
  head := dBase.Header;
  data := Rec.RecordData;
  while (head <> nil) and (data <> nil)
      and (Chop(head^.FieldName) <> Chop(FieldName)) do
      begin
        head := head^.NextHeader;
        data := data^.NextData;
      end;
  if (head <> nil) and (data <> nil) then
      GetField := data^.Data
  else
      GetField := '';
end;


end. (* Implementation *)
