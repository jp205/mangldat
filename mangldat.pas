(************************************************************)
(* Jean-Paul LaBarre 8/21/2013                              *)
(* This  program  attempts   to   manipulate  Allen-Bradley *)
(* Factory  Talk  View  datalog .DAT  files  and  eventualy *)
(* output a single .csv file  with  Allen-Bradley tag names *)
(* in the header,  empty  columns  removed,  and  data in a *)
(* more  human  friendly  format.                           *)
(************************************************************)
(* 3/30/2016 - JPL - Added check for EOF characters in date stamp. Should fix problems *)
(*    with large invalid record counts in the dBase Header. Which seems to happen when *)
(*    trying to log data very quickly in Factory Talk View SE. *) 

Program MangleDAT;

Uses
  readdbf,
  tagnamehash,
  floatdatahash,
  chopchop,
  math;

var
  FloatFile : text;

  FdBase : dBaseType;
  FRec   : RecordType;

  THash : TagNameTable;
  TRecPtr : TagNameRecPtr;

  FHash : FloatDataTable;
  Index : Word;
  Count : Word;
  RCount : Word;

  cDate, nDate : String;
  cTime, nTime : String;
  cMilt, nMilt : String;

  Key  : Word;
  Code : Integer;

  TempData : String;
  TempType : ShortInt;


Function StrToFloat(S : String) : Double;
var
  i : Byte;
  RawBytes : QWord;
  RawSignificand : QWord;
  Divisor : QWord;
  Exponent : Integer;
  Significand : Double;
  FinalResult : Double;
  Sign : Boolean;

begin

  (* Quick Sanity Check *)
  if (ord(s[0]) <> 8 ) then
     StrToFloat := NaN
  else
     begin

       (* Copy bytes into QWord. *)
       RawBytes := 0;
       for i := 8 downto 1 do
         begin
           RawBytes := RawBytes shl 8;
           RawBytes := RawBytes or ord(s[i]);
         end;

       (* Sign Bit *)
       Sign := (RawBytes and $8000000000000000) <> 0;

      (* Significand *)
      RawSignificand := RawBytes and $FFFFFFFFFFFFF;
      Significand := 1;
      for i := 51 downto 0 do
          begin
            (* Some trickery is needed to keep the compiler in line. *)
            (* i.e. make sure that shl & shr are preformed on QWords. *)
            Divisor := 2;
            Divisor := Divisor shl (51 - i);
            Significand := Significand + ((RawSignificand shr i) and 1) / Divisor;
          end;

      (* Exponent *)
      Exponent := (RawBytes and $7FF0000000000000) shr 52 - 1023;

      (* Compute Final Number *)
      FinalResult := Significand * power(2, Exponent);
      if Sign then FinalResult := FinalResult * -1;
      StrToFloat := FinalResult;

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
(* When logging at high rates (< 10 sec interval?) Factory Talk SE does not correctly *)
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
       Writeln('Usage: mangldat <tagname.DAT> <float.DAT>');
       Halt(0);
     end;

  (* Read TagName File *)
  ReadTagNameFile(paramstr(1), THash);

  (* Read Float File Header *)
  assign(FloatFile, paramstr(2));
  reset(FloatFile);

  ReadHeader(FloatFile, FdBase);

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

  (* Initilize count of records read. *)
  RCount := 0;

  (* Read first record from float file. *)
  if FdBase.NumRecords > 0 then
     begin
       ReadRecord(FloatFile, FdBase, FRec);
       RCount := RCount + 1;
       nDate := GetField('Date', FdBase, FRec);
       nTime := GetField('Time', FdBase, FRec);
       nMilt := GetField('Millitm', FdBase, FRec);
     end;

  (* Read the other records, write to csv, etc. *)
  While (RCount < FdBase.NumRecords) and Not EOFDate(nDate, nTime, nMilt) do
    begin

      (* Copy the Date, Time, and Militum for future comparison. *)
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
         if RCount < FdBase.NumRecords then
           begin
             ReadRecord(FloatFile, FdBase, FRec);
             nDate := GetField('Date', FdBase, FRec);
             nTime := GetField('Time', FdBase, FRec);
             nMilt := GetField('Millitm', FdBase, FRec);
             RCount := RCount + 1;
           end
         else
            nMilt := '';  (* End of File, Exit Loop *)
        end; (* Inner Wile Loop *)

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

          if TempType = 2 then (* Is String? *)
            Write(',', TempData)
          else
            Write(',', StrToFloat(TempData));

        end;  (* For Loop *)

      Writeln; (* End of Row *)

    end; (* Outer While Loop *)

  close(FloatFile);
  TagNameHashFree(THash);
  FloatDataHashFree(FHash);
  FreedBase(FdBase);

end.
