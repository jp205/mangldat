(*************************************************************************)
(* Contains procedures and data types for working with a hash table used *)
(* to store data from a FactoryTalk View SE "float" .DAT file. Data is   *)
(* stored by the TagIndex value.                                         *)
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

Unit FloatDataHash;

Interface

Const

  FloatHashTableSize = 50;

Type

  FloatDataPtr = ^FloatDataNode;
  FloatDataNode = record
                  Data : String;
                  NextRec : FloatDataPtr;
                end;
  FloatDataTable = array [0..FloatHashTableSize - 1] of FloatDataPtr;


Procedure FloatDataHashInit(var Hash : FloatDataTable);

Procedure FloatDataHashStore(Data : String; Key : Word; var Hash : FloatDataTable);

Function  FloatDataHashGet(Key : Word; Hash : FloatDataTable) : String;

Procedure FloatDataHashFree(var Hash : FloatDataTable);


Implementation


Procedure FloatDataHashInit(var Hash : FloatDataTable);
var
  pos : Word;
begin
  For pos := 0 to FloatHashTableSize - 1 do Hash[pos] := nil;
end;


Procedure Locate(key : Word; var pos : Word; var depth : Word);
begin
  depth := Key div FloatHashTableSize;
  pos := Key - depth * FloatHashTableSize;
end;


Procedure FloatDataHashStore(Data : String; Key : Word; var Hash : FloatDataTable);
var
  pos : Word;
  depth : Word;
  Ptr : FloatDataPtr;
begin	
  Locate(Key, pos, depth);
  if Hash[pos] = nil then
     begin
       New(Hash[pos]);
       Hash[pos]^.Data := '';
       Hash[pos]^.NextRec := nil;
     end;
  Ptr := Hash[pos];
  While depth > 0 do
     begin
       if Ptr^.NextRec = nil then
          begin
            New(Ptr^.NextRec);
            Ptr^.NextRec^.Data := '';
            Ptr^.NextRec^.NextRec := nil;
          end;
        Ptr := Ptr^.NextRec;
        depth := depth - 1;
     end;
  Ptr^.Data := Data;
end;


Function FloatDataHashGet(Key : Word; Hash : FloatDataTable) : String;
(* Returns an empty string if tag does not exist. *)
var
  pos : Word;
  depth : Word;
  Ptr : FloatDataPtr;
begin
  Locate(Key, pos, depth);
  Ptr := Hash[pos];
  While (depth > 0) and (ptr <> nil) do
    begin
      Ptr := Ptr^.NextRec;
      depth := depth - 1;
    end;
  if ptr <> nil then
     FloatDataHashGet := ptr^.Data
  else
     FloatDataHashGet := '';
end;


Procedure FloatDataHashFree(var Hash : FloatDataTable);
var
  pos : Word;
  Ptr : FloatDataPtr;
  Tmp : FloatDataPtr;
begin
  for pos := 0 to FloatHashTableSize - 1 do
     begin
       Ptr := Hash[pos];
       While Ptr <> nil do
         begin
           Tmp := Ptr;
           Ptr := Ptr^.NextRec;
           Dispose(Tmp);
         end;
       Hash[pos] := nil;
     end;
end;


end. (* Implementation *)
