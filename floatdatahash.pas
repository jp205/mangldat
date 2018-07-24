(********************************************************)
(* Jean-Paul LaBarre 8/21/2015                          *)
(* Contains procedures and data types for working with  *)
(* a hash table used to store data from an Allen-Bradly *)
(* "float" .DAT file. Data is stored by the TagIndex    *)
(* value.                                               *)
(********************************************************)

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
