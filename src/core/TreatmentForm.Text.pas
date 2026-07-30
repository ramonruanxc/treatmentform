{
  TreatmentForm — portable core.

  Small string helpers shared by validators and formatters. Kept internal to
  the library on purpose: this is not a general-purpose string unit, and
  growing it into one is how utility libraries stop being maintainable.
}
unit TreatmentForm.Text;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}

interface

{ Keeps only 0..9, discarding every other character. }
function DigitsOnly(const AValue: string): string;

{ True when the value is non-empty and every character is the same. }
function AllCharsEqual(const AValue: string): Boolean;

{ True when every character is in 0..9. Empty strings return False. }
function IsAllDigits(const AValue: string): Boolean;

{ Digit at a 1-based position, as an integer. No range checking: callers in
  this library validate length first. }
function DigitAt(const AValue: string; APosition: Integer): Integer;

implementation

function DigitsOnly(const AValue: string): string;
var
  I, Len: Integer;
begin
  SetLength(Result, Length(AValue));
  Len := 0;
  for I := 1 to Length(AValue) do
    if (AValue[I] >= '0') and (AValue[I] <= '9') then
    begin
      Inc(Len);
      Result[Len] := AValue[I];
    end;
  SetLength(Result, Len);
end;

function AllCharsEqual(const AValue: string): Boolean;
var
  I: Integer;
begin
  if AValue = '' then
    Exit(False);
  for I := 2 to Length(AValue) do
    if AValue[I] <> AValue[1] then
      Exit(False);
  Result := True;
end;

function IsAllDigits(const AValue: string): Boolean;
var
  I: Integer;
begin
  if AValue = '' then
    Exit(False);
  for I := 1 to Length(AValue) do
    if (AValue[I] < '0') or (AValue[I] > '9') then
      Exit(False);
  Result := True;
end;

function DigitAt(const AValue: string; APosition: Integer): Integer;
begin
  Result := Ord(AValue[APosition]) - Ord('0');
end;

end.
