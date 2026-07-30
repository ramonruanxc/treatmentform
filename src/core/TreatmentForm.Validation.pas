{
  TreatmentForm — portable core.

  Validators for the Brazilian document and contact formats the original
  library handled, rebuilt as objects instead of class helpers.

  Two rules hold across this unit:

    1. Invalid input is an expected outcome, never an exception. Exceptions
       are reserved for programmer error.
    2. Nothing here knows that a UI exists. That is what lets the suite run
       under Free Pascal in CI, and what lets the same rules be reused from a
       service or a console app.
}
unit TreatmentForm.Validation;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}

interface

uses
  TreatmentForm.Types;

type
  TValidatorBase = class(TInterfacedObject, IValidator)
  public
    function Validate(const AValue: string): TValidationResult; virtual; abstract;
  end;

  { CPF — Brazilian individual taxpayer registry.
    11 digits, two check digits (modulus 11). }
  TCpfValidator = class(TValidatorBase)
  public
    function Validate(const AValue: string): TValidationResult; override;
  end;

  { CNPJ — Brazilian company registry.
    14 digits, two check digits (modulus 11, different weights from CPF). }
  TCnpjValidator = class(TValidatorBase)
  public
    function Validate(const AValue: string): TValidationResult; override;
  end;

  { CEP — Brazilian postal code. 8 digits.

    Constructed without a state, it validates shape only. Constructed with a
    two-letter state code, it also checks that the code falls inside that
    state's allocated ranges. }
  TCepValidator = class(TValidatorBase)
  strict private
    FState: string;
  public
    constructor Create; overload;
    constructor Create(const AState: string); overload;
    function Validate(const AValue: string): TValidationResult; override;
  end;

  { Deliberately not an RFC 5322 implementation. Full RFC compliance accepts
    addresses no mail provider will take, and rejecting a real address is far
    worse than accepting an odd one. This checks the structure that actually
    predicts deliverability. }
  TEmailValidator = class(TValidatorBase)
  public
    function Validate(const AValue: string): TValidationResult; override;
  end;

  { Accepts dd/mm/yyyy and dd/mm/yy, with '/', '-' or '.' as separator.
    Two-digit years resolve through a sliding window: see TwoDigitYearPivot. }
  TDateValidator = class(TValidatorBase)
  strict private
    FTwoDigitYearPivot: Integer;
  public
    constructor Create;
    function Validate(const AValue: string): TValidationResult; override;
    { Years at or above the pivot map to 1900s, below it to 2000s.
      Defaults to 50, so '49' is 2049 and '50' is 1950. }
    property TwoDigitYearPivot: Integer read FTwoDigitYearPivot write FTwoDigitYearPivot;
  end;

  { Runs several validators over the same value.

    Stops at the first failure and returns it, because the first failure is
    the one the user has to fix. Aggregating every failure of a single field
    produces noise, not help. }
  TCompositeValidator = class(TValidatorBase)
  strict private
    FValidators: array of IValidator;
  public
    constructor Create(const AValidators: array of IValidator);
    function Validate(const AValue: string): TValidationResult; override;
    function Count: Integer;
  end;

implementation

uses
  {$IFDEF FPC}SysUtils{$ELSE}System.SysUtils{$ENDIF},
  TreatmentForm.Text;

{ Modulus-11 check digit shared by CPF and CNPJ.
  ADigits holds the digit string; AWeights the multipliers, applied left to
  right from the first digit. }
function Modulus11CheckDigit(const ADigits: string;
  const AWeights: array of Integer): Integer;
var
  I, Sum, Remainder: Integer;
begin
  Sum := 0;
  for I := 0 to High(AWeights) do
    Inc(Sum, DigitAt(ADigits, I + 1) * AWeights[I]);
  Remainder := Sum mod 11;
  if Remainder < 2 then
    Result := 0
  else
    Result := 11 - Remainder;
end;

{ TCpfValidator }

function TCpfValidator.Validate(const AValue: string): TValidationResult;
const
  FirstWeights: array[0..8] of Integer = (10, 9, 8, 7, 6, 5, 4, 3, 2);
  SecondWeights: array[0..9] of Integer = (11, 10, 9, 8, 7, 6, 5, 4, 3, 2);
var
  Digits: string;
begin
  if Trim(AValue) = '' then
    Exit(TValidationResult.Invalid(vfEmpty, 'CPF is empty.'));

  Digits := DigitsOnly(AValue);

  if Digits = '' then
    Exit(TValidationResult.Invalid(vfInvalidCharacters,
      'CPF contains no digits.'));

  if Length(Digits) <> 11 then
    Exit(TValidationResult.Invalid(vfInvalidLength,
      Format('CPF must have 11 digits, found %d.', [Length(Digits)])));

  { 000.000.000-00 through 999.999.999-99 satisfy the check digits but are
    never issued. Every real implementation has to special-case them. }
  if AllCharsEqual(Digits) then
    Exit(TValidationResult.Invalid(vfRepeatedSequence,
      'CPF is a repeated sequence of the same digit.'));

  if DigitAt(Digits, 10) <> Modulus11CheckDigit(Digits, FirstWeights) then
    Exit(TValidationResult.Invalid(vfCheckDigitMismatch,
      'CPF first check digit does not match.'));

  if DigitAt(Digits, 11) <> Modulus11CheckDigit(Digits, SecondWeights) then
    Exit(TValidationResult.Invalid(vfCheckDigitMismatch,
      'CPF second check digit does not match.'));

  Result := TValidationResult.Valid;
end;

{ TCnpjValidator }

function TCnpjValidator.Validate(const AValue: string): TValidationResult;
const
  FirstWeights: array[0..11] of Integer = (5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2);
  SecondWeights: array[0..12] of Integer = (6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2);
var
  Digits: string;
begin
  if Trim(AValue) = '' then
    Exit(TValidationResult.Invalid(vfEmpty, 'CNPJ is empty.'));

  Digits := DigitsOnly(AValue);

  if Digits = '' then
    Exit(TValidationResult.Invalid(vfInvalidCharacters,
      'CNPJ contains no digits.'));

  if Length(Digits) <> 14 then
    Exit(TValidationResult.Invalid(vfInvalidLength,
      Format('CNPJ must have 14 digits, found %d.', [Length(Digits)])));

  if AllCharsEqual(Digits) then
    Exit(TValidationResult.Invalid(vfRepeatedSequence,
      'CNPJ is a repeated sequence of the same digit.'));

  if DigitAt(Digits, 13) <> Modulus11CheckDigit(Digits, FirstWeights) then
    Exit(TValidationResult.Invalid(vfCheckDigitMismatch,
      'CNPJ first check digit does not match.'));

  if DigitAt(Digits, 14) <> Modulus11CheckDigit(Digits, SecondWeights) then
    Exit(TValidationResult.Invalid(vfCheckDigitMismatch,
      'CNPJ second check digit does not match.'));

  Result := TValidationResult.Valid;
end;

{ TCepValidator }

type
  TCepRange = record
    State: string;
    First: Integer;
    Last: Integer;
  end;

{ Ranges are on the first five digits of the code. A few states hold more
  than one block, so this is a list rather than a map. }
const
  CepRanges: array[0..29] of TCepRange = (
    (State: 'SP'; First: 1000;  Last: 19999),
    (State: 'RJ'; First: 20000; Last: 28999),
    (State: 'ES'; First: 29000; Last: 29999),
    (State: 'MG'; First: 30000; Last: 39999),
    (State: 'BA'; First: 40000; Last: 48999),
    (State: 'SE'; First: 49000; Last: 49999),
    (State: 'PE'; First: 50000; Last: 56999),
    (State: 'AL'; First: 57000; Last: 57999),
    (State: 'PB'; First: 58000; Last: 58999),
    (State: 'RN'; First: 59000; Last: 59999),
    (State: 'CE'; First: 60000; Last: 63999),
    (State: 'PI'; First: 64000; Last: 64999),
    (State: 'MA'; First: 65000; Last: 65999),
    (State: 'PA'; First: 66000; Last: 68899),
    (State: 'AP'; First: 68900; Last: 68999),
    (State: 'AM'; First: 69000; Last: 69299),
    (State: 'RR'; First: 69300; Last: 69399),
    (State: 'AM'; First: 69400; Last: 69899),
    (State: 'AC'; First: 69900; Last: 69999),
    (State: 'DF'; First: 70000; Last: 72799),
    (State: 'GO'; First: 72800; Last: 72999),
    (State: 'DF'; First: 73000; Last: 73699),
    (State: 'GO'; First: 73700; Last: 76799),
    (State: 'TO'; First: 77000; Last: 77999),
    (State: 'MT'; First: 78000; Last: 78899),
    (State: 'RO'; First: 78900; Last: 78999),
    (State: 'MS'; First: 79000; Last: 79999),
    (State: 'PR'; First: 80000; Last: 87999),
    (State: 'SC'; First: 88000; Last: 89999),
    (State: 'RS'; First: 90000; Last: 99999)
  );

constructor TCepValidator.Create;
begin
  inherited Create;
  FState := '';
end;

constructor TCepValidator.Create(const AState: string);
begin
  inherited Create;
  FState := UpperCase(Trim(AState));
end;

function TCepValidator.Validate(const AValue: string): TValidationResult;
var
  Digits: string;
  Prefix, I: Integer;
  StateKnown, InRange: Boolean;
begin
  if Trim(AValue) = '' then
    Exit(TValidationResult.Invalid(vfEmpty, 'CEP is empty.'));

  Digits := DigitsOnly(AValue);

  if Length(Digits) <> 8 then
    Exit(TValidationResult.Invalid(vfInvalidLength,
      Format('CEP must have 8 digits, found %d.', [Length(Digits)])));

  if FState = '' then
    Exit(TValidationResult.Valid);

  Prefix := StrToInt(Copy(Digits, 1, 5));

  StateKnown := False;
  InRange := False;
  for I := Low(CepRanges) to High(CepRanges) do
  begin
    if CepRanges[I].State = FState then
    begin
      StateKnown := True;
      if (Prefix >= CepRanges[I].First) and (Prefix <= CepRanges[I].Last) then
      begin
        InRange := True;
        Break;
      end;
    end;
  end;

  if not StateKnown then
    Exit(TValidationResult.Invalid(vfUnknownRegion,
      Format('"%s" is not a recognised state code.', [FState])));

  if not InRange then
    Exit(TValidationResult.Invalid(vfOutOfRange,
      Format('CEP %s is outside the range allocated to %s.', [Digits, FState])));

  Result := TValidationResult.Valid;
end;

{ TEmailValidator }

function TEmailValidator.Validate(const AValue: string): TValidationResult;
var
  Value, LocalPart, Domain: string;
  AtPos, I: Integer;
begin
  Value := Trim(AValue);

  if Value = '' then
    Exit(TValidationResult.Invalid(vfEmpty, 'E-mail is empty.'));

  if Pos(' ', Value) > 0 then
    Exit(TValidationResult.Invalid(vfInvalidCharacters,
      'E-mail cannot contain spaces.'));

  AtPos := Pos('@', Value);
  if AtPos = 0 then
    Exit(TValidationResult.Invalid(vfInvalidFormat, 'E-mail has no "@".'));

  { A second "@" is unambiguous corruption, not an exotic address. }
  for I := AtPos + 1 to Length(Value) do
    if Value[I] = '@' then
      Exit(TValidationResult.Invalid(vfInvalidFormat,
        'E-mail has more than one "@".'));

  LocalPart := Copy(Value, 1, AtPos - 1);
  Domain := Copy(Value, AtPos + 1, Length(Value) - AtPos);

  if LocalPart = '' then
    Exit(TValidationResult.Invalid(vfInvalidFormat,
      'E-mail has nothing before the "@".'));

  if Domain = '' then
    Exit(TValidationResult.Invalid(vfInvalidFormat,
      'E-mail has nothing after the "@".'));

  if Pos('.', Domain) = 0 then
    Exit(TValidationResult.Invalid(vfInvalidFormat,
      'E-mail domain has no dot.'));

  if (Domain[1] = '.') or (Domain[Length(Domain)] = '.') then
    Exit(TValidationResult.Invalid(vfInvalidFormat,
      'E-mail domain cannot start or end with a dot.'));

  if Pos('..', Value) > 0 then
    Exit(TValidationResult.Invalid(vfInvalidFormat,
      'E-mail cannot contain two consecutive dots.'));

  { A bare TLD of one character is never valid. }
  if Length(Domain) - LastDelimiter('.', Domain) < 2 then
    Exit(TValidationResult.Invalid(vfInvalidFormat,
      'E-mail top-level domain is too short.'));

  Result := TValidationResult.Valid;
end;

{ TDateValidator }

constructor TDateValidator.Create;
begin
  inherited Create;
  FTwoDigitYearPivot := 50;
end;

function TDateValidator.Validate(const AValue: string): TValidationResult;
const
  DaysPerMonth: array[1..12] of Integer =
    (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
var
  Value: string;
  Parts: array[0..2] of string;
  PartIndex, I, Day, Month, Year, MaxDay: Integer;
  Ch: Char;
  IsLeap: Boolean;
begin
  Value := Trim(AValue);

  if Value = '' then
    Exit(TValidationResult.Invalid(vfEmpty, 'Date is empty.'));

  for I := 0 to 2 do
    Parts[I] := '';
  PartIndex := 0;

  for I := 1 to Length(Value) do
  begin
    Ch := Value[I];
    if (Ch = '/') or (Ch = '-') or (Ch = '.') then
    begin
      Inc(PartIndex);
      if PartIndex > 2 then
        Exit(TValidationResult.Invalid(vfInvalidFormat,
          'Date has too many separators.'));
    end
    else if (Ch >= '0') and (Ch <= '9') then
      Parts[PartIndex] := Parts[PartIndex] + Ch
    else
      Exit(TValidationResult.Invalid(vfInvalidCharacters,
        Format('Date contains "%s".', [Ch])));
  end;

  if PartIndex <> 2 then
    Exit(TValidationResult.Invalid(vfInvalidFormat,
      'Date must be day, month and year.'));

  if (Parts[0] = '') or (Parts[1] = '') or (Parts[2] = '') then
    Exit(TValidationResult.Invalid(vfInvalidFormat,
      'Date has an empty part.'));

  if (Length(Parts[2]) <> 2) and (Length(Parts[2]) <> 4) then
    Exit(TValidationResult.Invalid(vfInvalidFormat,
      'Year must have 2 or 4 digits.'));

  Day := StrToInt(Parts[0]);
  Month := StrToInt(Parts[1]);
  Year := StrToInt(Parts[2]);

  if Length(Parts[2]) = 2 then
  begin
    if Year >= FTwoDigitYearPivot then
      Inc(Year, 1900)
    else
      Inc(Year, 2000);
  end;

  if (Month < 1) or (Month > 12) then
    Exit(TValidationResult.Invalid(vfOutOfRange,
      Format('Month %d is out of range.', [Month])));

  IsLeap := ((Year mod 4 = 0) and (Year mod 100 <> 0)) or (Year mod 400 = 0);

  MaxDay := DaysPerMonth[Month];
  if (Month = 2) and IsLeap then
    MaxDay := 29;

  if (Day < 1) or (Day > MaxDay) then
    Exit(TValidationResult.Invalid(vfOutOfRange,
      Format('Day %d is out of range for month %d of %d.', [Day, Month, Year])));

  Result := TValidationResult.Valid;
end;

{ TCompositeValidator }

constructor TCompositeValidator.Create(const AValidators: array of IValidator);
var
  I: Integer;
begin
  inherited Create;
  SetLength(FValidators, Length(AValidators));
  for I := Low(AValidators) to High(AValidators) do
  begin
    { A nil validator is a wiring mistake, not bad user input, so this is one
      of the few places in the core that raises. }
    if AValidators[I] = nil then
      raise Exception.CreateFmt('Validator at index %d is nil.', [I]);
    FValidators[I] := AValidators[I];
  end;
end;

function TCompositeValidator.Count: Integer;
begin
  Result := Length(FValidators);
end;

function TCompositeValidator.Validate(const AValue: string): TValidationResult;
var
  I: Integer;
begin
  for I := Low(FValidators) to High(FValidators) do
  begin
    Result := FValidators[I].Validate(AValue);
    if not Result.IsValid then
      Exit;
  end;
  Result := TValidationResult.Valid;
end;

end.
