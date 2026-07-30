{
  TreatmentForm — portable core.

  Shared types for validation and formatting. This unit has no UI dependency
  and compiles under both Delphi and Free Pascal, which is what allows the
  core test suite to run in CI.
}
unit TreatmentForm.Types;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}

interface

type
  { Why the validators return a reason instead of a boolean:

    "Invalid CPF" is not actionable. "Check digit does not match" and
    "only 10 digits, expected 11" are. Callers decide how much of that to
    surface; the core just refuses to throw the information away. }
  TValidationFailure = (
    vfNone,
    vfEmpty,
    vfInvalidLength,
    vfInvalidCharacters,
    vfRepeatedSequence,
    vfCheckDigitMismatch,
    vfInvalidFormat,
    vfOutOfRange,
    vfUnknownRegion
  );

  TValidationResult = record
  strict private
    FIsValid: Boolean;
    FReason: TValidationFailure;
    FMessage: string;
  public
    class function Valid: TValidationResult; static;
    class function Invalid(AReason: TValidationFailure;
      const AMessage: string): TValidationResult; static;

    property IsValid: Boolean read FIsValid;
    property Reason: TValidationFailure read FReason;
    property Message: string read FMessage;
  end;

  IValidator = interface
    ['{0B7E1F9C-3A44-4D21-9E52-6C1A8D4F7B10}']
    function Validate(const AValue: string): TValidationResult;
  end;

  IFormatter = interface
    ['{4F2C6D18-91B7-4E33-8A6D-2E5B0C93A741}']
    { Applies presentation formatting. Formatting never validates: a caller
      may legitimately want to format a partial value while the user types. }
    function Format(const AValue: string): string;
  end;

function FailureToString(AReason: TValidationFailure): string;

implementation

function FailureToString(AReason: TValidationFailure): string;
begin
  case AReason of
    vfNone:               Result := 'none';
    vfEmpty:              Result := 'empty';
    vfInvalidLength:      Result := 'invalid length';
    vfInvalidCharacters:  Result := 'invalid characters';
    vfRepeatedSequence:   Result := 'repeated sequence';
    vfCheckDigitMismatch: Result := 'check digit mismatch';
    vfInvalidFormat:      Result := 'invalid format';
    vfOutOfRange:         Result := 'out of range';
    vfUnknownRegion:      Result := 'unknown region';
  else
    Result := 'unspecified';
  end;
end;

{ TValidationResult }

class function TValidationResult.Valid: TValidationResult;
begin
  Result.FIsValid := True;
  Result.FReason := vfNone;
  Result.FMessage := '';
end;

class function TValidationResult.Invalid(AReason: TValidationFailure;
  const AMessage: string): TValidationResult;
begin
  Result.FIsValid := False;
  Result.FReason := AReason;
  Result.FMessage := AMessage;
end;

end.
