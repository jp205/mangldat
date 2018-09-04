(*************************************************************************)
(* Contains procedures and data types for working with a hash table used *) 
(* to store TagName data, stored by the TTagIndex value.                 *)
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

Unit TagNameHash;

Interface

Const

  HashTableSize = 200;

Type

  TagNameRecPtr = ^TagNameRecord;
  TagNameRecord = record
                 TagName : String;
                 TagType : ShortInt;
                 TagDataType : ShortInt;
              end;
  TagNamePtr = ^TagNameNode;
  TagNameNode = record
                  TagRec : TagNameRecPtr;
                  NextTag : TagNamePtr;
                end;
  TagNameTable = array [0..HashTableSize - 1] of TagNamePtr;


Procedure TagNameHashInit(var Hash : TagNameTable);

Procedure TagNameHashStore(RecPtr : TagNameRecPtr; Key : Word; var Hash : TagNameTable);

Function  TagNameHashGet(Key : Word; Hash : TagNameTable) : TagNameRecPtr;

Procedure TagNameHashFree(var Hash : TagNameTable);


Implementation


Procedure TagNameHashInit(var Hash : TagNameTable);
var 
  pos : Word;
begin
  For pos := 0 to HashTableSize - 1 do Hash[pos] := nil;
end;


Procedure Locate(key : Word; var pos : Word; var depth : Word);
begin
  depth := Key div HashTableSize;
  pos := Key - depth * HashTableSize;
end;


Procedure TagNameHashStore(RecPtr : TagNameRecPtr; Key : Word; var Hash : TagNameTable);
var
  pos : Word;
  depth : Word; 
  Ptr : TagNamePtr;
begin
  Locate(Key, pos, depth);
  if Hash[pos] = nil then 
     begin
       New(Hash[pos]);
       Hash[pos]^.TagRec := nil;
       Hash[pos]^.NextTag := nil;
     end;
  Ptr := Hash[pos];
  While depth > 0 do
     begin
       if Ptr^.NextTag = nil then
          begin
            New(Ptr^.NextTag);           
            Ptr^.NextTag^.TagRec := nil;
            Ptr^.NextTag^.NextTag := nil;
          end;
        Ptr := Ptr^.NextTag;
        depth := depth - 1;
     end;
  Ptr^.TagRec := RecPtr;
end;


Function TagNameHashGet(Key : Word; Hash : TagNameTable) : TagNameRecPtr;
(* Returns an nil if tag does not exist. *)
var
  pos : Word;
  depth : Word;
  Ptr : TagNamePtr;
begin
  Locate(Key, pos, depth);
  Ptr := Hash[pos];
  While (depth > 0) and (ptr <> nil) do
    begin    
      Ptr := Ptr^.NextTag;
      depth := depth - 1;
    end;
  if ptr <> nil then
     TagNameHashGet := ptr^.TagRec
  else
     TagNameHashGet := nil;
end;


Procedure TagNameHashFree(var Hash : TagNameTable);
var
  pos : Word;
  Ptr : TagNamePtr;
  Tmp : TagNamePtr;
begin
  for pos := 0 to HashTableSize - 1 do
     begin
       Ptr := Hash[pos];
       While Ptr <> nil do
         begin
           Tmp := Ptr;
           Ptr := Ptr^.NextTag;
           if Tmp^.TagRec <> nil then Dispose(Tmp^.TagRec);
           Dispose(Tmp);
         end;
       Hash[pos] := nil;
     end;
end;


end. (* Implementation *)
