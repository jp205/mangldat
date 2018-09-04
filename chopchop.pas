(*************************************************************************)
(* Contains string manipulation functions.                               *)
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

Unit ChopChop;

Interface

Function Chop(S : String) : String;

Function ChopRight(S : String; C : char) : String;


Implementation

Function Chop(S : String) : String;
(* Returns a string with the leading and trailing  *)
(* nulls (00h) and spaces removed.                 *)
var
  pos : Byte;
  length : Byte;
begin
  length := ord(S[0]);
  pos := 1;
  While (pos <= length) and (S[pos] in [chr(0), ' ']) do pos := pos + 1;
  S := Copy(S,pos,length - pos + 1);
  pos := ord(S[0]);
  While (pos >= 1) and (S[pos] in [chr(0), ' ']) do pos := pos - 1;
  Chop := Copy(S,1,pos);
end;

Function ChopRight(S : String; C : char) : String;
(* Returns the rightmost portion of string S after *)
(* the rightmost occurance of character C.         *)
var
  pos : Byte;
begin
  pos := ord(S[0]);
  While (pos >= 1) and (S[pos] <> C) do pos := pos - 1;
  ChopRight := Copy(S, pos + 1, ord(S[0]) - pos);
end;

end.
