(*******************************************************)
(* Jean-Paul LaBarre  11/30/2012                       *)
(* Contains string manipulation functions.             *)
(*******************************************************)

(* 12/22/2015 - JPL - Renamed TrimRight ChopRight to avoid conflict with sysutils unit. *)

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
