(*************************************************************************)
(* ManglDat reads Rockwell's FactoryTalk View SE datalog .DAT files and  *)
(* outputs a single .csv file with tag names in the header, empty        *)
(* columns removed, and data in a more human friendly format.            *)
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

Program ManglDat;

Uses
  readdbf,
  tagnamehash,
  floatdatahash, 
  chopchop,
  math;

Const
  vnum = '0.1';

var
  FloatFile : text;
  StringFile : text;

  FdBase : dBaseType;
  FRec   : RecordType;

  SdBase : dBaseType;
  SRec   : RecordType;

  THash : TagNameTable;
  TRecPtr : TagNameRecPtr;

  FHash : FloatDataTable;
 
  Index : Word;
  Count : Word;
  FCount : Word;
  SCount : Word;

  cDate, nDate, sDate : String;
  cTime, nTime, sTime : String;
  cMilt, nMilt, sMilt : String;

  Key  : Word;
  Code : Integer;

  TempData : String;
  TempType : ShortInt;

  HaveStrings : Boolean;

Function StrToFloat(S : String) : Double;
var
 d : ^Double; 
begin

  (* Quick Sanity Check *)
  if (ord(s[0]) <> 8 ) then
       StrToFloat := NaN
  else
     (* Read String as 64 bit Float *)
     begin
	d := @s[1];
	StrToFloat := d^;
     end;
end;


Procedure ReadTagNameFile(FileName : String; var THash : TagNameTable);
var
  TagFile : text;
  TdBase : dBaseType;

  Rec : RecordType;
  RecPtr : TagNameRecPtr;
  TagName : String;
  TempType : ShortInt;
  Key : Word;
  Code : Integer;
  RecCount : LongWord;

begin

  assign(TagFile,FileName);
  reset(TagFile);

  ReadHeader(TagFile,TdBase);

  TagNameHashInit(THash);

  RecCount := 1;

  while (RecCount <= TdBase.NumRecords) and not eof(TagFile) do
     begin
       ReadRecord(TagFile,TdBase,Rec);
       New(RecPtr);

       (* Read TagName, remove nulls and anything before *)
       (* the last backslash.                            *)
       TagName := Chop(GetField('Tagname', TdBase, Rec));
       TagName := ChopRight(TagName,'\');
       RecPtr^.TagName := TagName;

       (* Read TempType convert it to a ShortInt. *)
       Val(GetField('TagType', TdBase, Rec), TempType, Code);
       RecPtr^.TagType := TempType;

       (* Read TagDataTyp convert it to a ShortInt *)
       Val(GetField('TagDataTyp', TdBase, Rec), TempType, Code);
       RecPtr^.TagDataType := TempType;

       (* Read Key convert it to a numeric type.         *)
       Val(GetField('TTagIndex', TdBase, Rec), Key, Code);

       TagNameHashStore(RecPtr, Key, THash);

       FreeRecord(Rec);
       reccount := reccount + 1;

     end; (* Loop *)

  close(TagFile);

  FreedBASE(TdBase);

end;


Function EOFDate(date, time, milt : string) : boolean;
(* Returns True if an EOF character Chr(26) is found anywhere in the date/time stamp. *)
(* When logging at high rates (< 10 sec interval?) FactoryTalk SE does not correctly  *)
(* set the number of records in the dBase file header. *)
begin 
  if (Pos(chr(26),date) <> 0) or
     (Pos(chr(26),time) <> 0) or
     (Pos(chr(26),milt) <> 0) then
      EOFDate := True
  else
      EOFDate := False
end;


begin

  (* Check for required parameters. *)

  if (paramstr(1) = '') or (paramstr(2) = '') then
     begin
       Writeln;
       Writeln('ManglDat Ver ', vnum, ' Copyright (C) 2018 Jean-Paul LaBarre');
       Writeln;
       Writeln('This program is free software and comes with ABSOLUTLEY NO WARRANTY.');
       Writeln('You are welcome to redistribute it and/or modify it under the terms');
       Writeln('of the GNU General Public License as published by the Free Software');
       Writeln('Foundation, either version 3 of the License or (at your option) any');
       Writeln('later version.');
       Writeln;
       Writeln('You should have received a copy of the GNU General Public license');
       Writeln('along with this program. If not, see <http://www.gnu.org/licenses/>.');
       Writeln;
       Writeln('Usage: mangldat <tagname.DAT> <float.DAT> [string.DAT]');
       Writeln;
       Halt(0);
     end;

  (* Read TagName File *)
  ReadTagNameFile(paramstr(1), THash);

  (* Read Float File Header *)
  assign(FloatFile, paramstr(2));
  reset(FloatFile);
  ReadHeader(FloatFile, FdBase);

  (* Read String File Header, if provided. *)
  if paramstr(3) <> '' then
     begin
       assign(StringFile, paramstr(3));
       reset(StringFile);
       ReadHeader(StringFile, SdBase);       
       HaveStrings := True;
     end
  else
     HaveStrings := False;

  (* At this point can write the .csv file header. *)
  (* for now just write it to standard output.     *)

  (* First three columns will be Date, Time, and Millitm *)
  Write('Date,Time,Millitm');

  (* The remaining columns will be tagnames. *)
  Index := 0;
  TRecPtr := TagNameHashGet(Index, THash);
  While TRecPtr <> nil do
    begin
      Write(',', TRecPtr^.TagName);
      Index := Index + 1;
      TRecPtr := TagNameHashGet(Index, THash);
    end;
  Count := Index - 1;
  Writeln;

  (* Initilize Hash Table *)
  FloatDataHashInit(FHash);

  (* Initilize counts of records read. *)
  FCount := 0;
  SCount := 0;

  (* Read first record from float file. *)
  if FdBase.NumRecords > 0 then
     begin
       ReadRecord(FloatFile, FdBase, FRec);
       FCount := FCount + 1;
       nDate := GetField('Date', FdBase, FRec);
       nTime := GetField('Time', FdBase, FRec);
       nMilt := GetField('Millitm', FdBase, FRec);
     end;
  
  (* Read first record from string file. *)
  if HaveStrings and (SdBase.NumRecords > 0) then
     begin
       ReadRecord(StringFile, SdBase, SRec);
       SCount := SCount + 1;
       sDate := GetField('Date', SdBase, SRec);
       sTime := GetField('Time', SdBase, SRec);
       sMilt := GetField('Millitm', SdBase, SRec);
     end;

  (* Read the other records, write to csv, etc. *)
  While (FCount < FdBase.NumRecords) and Not EOFDate(nDate, nTime, nMilt) do
    begin

      (* Copy the Date, Time, and Millitm for future comparison. *)
      cDate := nDate;
      cTime := nTime;
      cMilt := nMilt;

      (* Write the Date, Time, and Millitm. *)
      Write(cDate, ',', cTime, ',', cMilt);

      (* Store float file data into the hash table until the time stamps change. *)
      While (cMilt = nMilt) and (cTime = nTime) and (cDate = nDate) do
        begin
          Val(GetField('TagIndex', FdBase, FRec), Key, Code);
          FloatDataHashStore(GetField('Value', FdBase, FRec), Key, FHash);          
          FreeRecord(FRec);
          if FCount < FdBase.NumRecords then
            begin
              ReadRecord(FloatFile, FdBase, FRec);
              nDate := GetField('Date', FdBase, FRec);
              nTime := GetField('Time', FdBase, FRec);
              nMilt := GetField('Millitm', FdBase, FRec);
              FCount := FCount + 1;
            end
          else
             nMilt := '';  (* End of File, Exit Loop *)
        end; (* 1st Inner While Loop *)

      (* Do the same for the String File if being used. *)
      If HaveStrings Then
         While (cMilt = sMilt) and (cTime = sTime) and (cDate = sDate) do
            begin
              Val(GetField('TagIndex', SdBase, SRec), Key, Code);
              FloatDataHashStore(GetField('Value', SdBase, SRec), Key, FHash);
              FreeRecord(SRec);
              if SCount < SdBase.NumRecords then
                begin          
                  ReadRecord(StringFile, SdBase, SRec);
                  sDate := GetField('Date', SdBase, SRec);
                  sTime := GetField('Time', SdBase, SRec);
                  sMilt := GetField('Millitm', SdBase, SRec);
                  SCount := SCount + 1;
                end
              else
                sMilt := ''; (* End of File, Exit Loop *)
            end; (* 2nd Inner While Loop *)                     

      (* Write data, check data type and convert as needed. *)
      For Index := 0 to Count do
        begin
          TempData := FloatDataHashGet(Index, FHash);
          TempType := TagNameHashGet(Index, THash)^.TagDataType;

          (* As far a I can tell data types *)
          (* should be encoded as follows   *)
          (* but are actualy all in 64 bit  *)
          (* floating point.                *)
          (* -1 : Boolean                   *)
          (*  0 : Integer?                  *)
          (*  1 : Double                    *)
          (*  2 : String                    *)
           
          if (TempData = '') or (TempType = 2) then (* Missing Data or String *)
            Write(',', TempData)
          else
            Write(',', StrToFloat(TempData));

        end;  (* For Loop *)

      Writeln; (* End of Row *)
      FloatDataHashFree(FHash) (* Clear Hash Table *)

    end; (* Outer While Loop *)

  close(FloatFile);
  TagNameHashFree(THash);
  FloatDataHashFree(FHash);
  FreedBase(FdBase);

end.
