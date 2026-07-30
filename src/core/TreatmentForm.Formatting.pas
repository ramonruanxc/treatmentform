{
  TreatmentForm — portable core.

  Presentation formatting, kept apart from validation.

  In the original library both lived on the same class helper, which forced
  every caller to accept the pair. They are different operations: an editor
  formats a value while the user is still typing it, long before the value
  could pass validation. Formatters here therefore never reject input — they
  format what they can and leave the rest alone.
}
unit TreatmentForm.Formatting;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}

interface

uses
  TreatmentForm.Types;

type
  { Formats as CPF (000.000.000-00) or CNPJ (00.000.000/0000-00) depending on
    how many digits are present. Anything other than 11 or 14 digits is
    returned as the bare digit string. }
  TCpfCnpjFormatter = class(TInterfacedObject, IFormatter)
  public
    function Format(const AValue: string): string;
  end;

  { Brazilian phone numbers. Handles 8 and 9 digit subscriber numbers, with
    and without area code, and an optional country code. }
  TPhoneFormatter = class(TInterfacedObject, IFormatter)
  public
    function Format(const AValue: string): string;
  end;

  TCepFormatter = class(TInterfacedObject, IFormatter)
  public
    function Format(const AValue: string): string;
  end;

  TDateStyle = (dsTwoDigitYear, dsFourDigitYear);

  TDateFormatter = class(TInterfacedObject, IFormatter)
  strict private
    FStyle: TDateStyle;
  public
    constructor Create(AStyle: TDateStyle = dsFourDigitYear);
    function Format(const AValue: string): string;
    property Style: TDateStyle read FStyle write FStyle;
  end;

implementation

uses
  {$IFDEF FPC}SysUtils{$ELSE}System.SysUtils{$ENDIF},
  TreatmentForm.Text;

{ Applies a mask where '0' marks a digit slot and every other character is a
  literal. Stops when the digits run out, so partial input formats cleanly. }
function ApplyDigitMask(const ADigits, AMask: string): string;
var
  I, DigitIndex: Integer;
begin
  Result := '';
  DigitIndex := 1;
  for I := 1 to Length(AMask) do
  begin
    if DigitIndex > Length(ADigits) then
      Break;
    if AMask[I] = '0' then
    begin
      Result := Result + ADigits[DigitIndex];
      Inc(DigitIndex);
    end
    else
      Result := Result + AMask[I];
  end;
end;

{ TCpfCnpjFormatter }

function TCpfCnpjFormatter.Format(const AValue: string): string;
var
  Digits: string;
begin
  Digits := DigitsOnly(AValue);
  case Length(Digits) of
    11: Result := ApplyDigitMask(Digits, '000.000.000-00');
    14: Result := ApplyDigitMask(Digits, '00.000.000/0000-00');
  else
    Result := Digits;
  end;
end;

{ TPhoneFormatter }

function TPhoneFormatter.Format(const AValue: string): string;
var
  Digits: string;
begin
  Digits := DigitsOnly(AValue);
  case Length(Digits) of
     8: Result := ApplyDigitMask(Digits, '0000-0000');
     9: Result := ApplyDigitMask(Digits, '00000-0000');
    10: Result := ApplyDigitMask(Digits, '(00) 0000-0000');
    11: Result := ApplyDigitMask(Digits, '(00) 00000-0000');
    12: Result := ApplyDigitMask(Digits, '+00 (00) 0000-0000');
    13: Result := ApplyDigitMask(Digits, '+00 (00) 00000-0000');
  else
    Result := Digits;
  end;
end;

{ TCepFormatter }

function TCepFormatter.Format(const AValue: string): string;
var
  Digits: string;
begin
  Digits := DigitsOnly(AValue);
  if Length(Digits) = 8 then
    Result := ApplyDigitMask(Digits, '00000-000')
  else
    Result := Digits;
end;

{ TDateFormatter }

constructor TDateFormatter.Create(AStyle: TDateStyle);
begin
  inherited Create;
  FStyle := AStyle;
end;

function TDateFormatter.Format(const AValue: string): string;
var
  Digits: string;
begin
  Digits := DigitsOnly(AValue);

  { 6 and 8 digit input is unambiguous; anything else is returned untouched
    rather than guessed at. }
  if (Length(Digits) = 6) and (FStyle = dsTwoDigitYear) then
    Result := ApplyDigitMask(Digits, '00/00/00')
  else if Length(Digits) = 8 then
    Result := ApplyDigitMask(Digits, '00/00/0000')
  else if Length(Digits) = 6 then
    Result := ApplyDigitMask(Digits, '00/00/00')
  else
    Result := Digits;
end;

end.
