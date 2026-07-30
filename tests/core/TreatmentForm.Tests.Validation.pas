{
  TreatmentForm — core test suite.

  The CPF and CNPJ numbers used here are check-digit-valid but are test
  fixtures, not real registrations.
}
unit TreatmentForm.Tests.Validation;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}

interface

uses
  TreatmentForm.Testing;

procedure RunValidationTests(ARunner: TTestRunner);

implementation

uses
  {$IFDEF FPC}SysUtils{$ELSE}System.SysUtils{$ENDIF},
  TreatmentForm.Types,
  TreatmentForm.Validation;

{ Local assertion helpers. They live here rather than in the runner so the
  runner stays free of any dependency on what is being tested. }

procedure Accepts(ARunner: TTestRunner; AValidator: IValidator;
  const AValue, ADescription: string);
var
  Res: TValidationResult;
begin
  Res := AValidator.Validate(AValue);
  if Res.IsValid then
    ARunner.IsTrue(ADescription, True)
  else
    ARunner.AreEqual(ADescription, 'valid',
      FailureToString(Res.Reason) + ' (' + Res.Message + ')');
end;

procedure Rejects(ARunner: TTestRunner; AValidator: IValidator;
  const AValue: string; AExpected: TValidationFailure;
  const ADescription: string);
var
  Res: TValidationResult;
begin
  Res := AValidator.Validate(AValue);
  if Res.IsValid then
    ARunner.AreEqual(ADescription, FailureToString(AExpected), 'valid')
  else
    ARunner.AreEqual(ADescription, FailureToString(AExpected),
      FailureToString(Res.Reason));
end;

procedure TestCpf(ARunner: TTestRunner);
var
  V: IValidator;
  I: Integer;
  Repeated: string;
begin
  ARunner.Suite('CPF');
  V := TCpfValidator.Create;

  Accepts(ARunner, V, '52998224725', 'accepts a valid unformatted CPF');
  Accepts(ARunner, V, '529.982.247-25', 'accepts the same CPF formatted');
  Accepts(ARunner, V, '  529.982.247-25  ', 'ignores surrounding whitespace');
  Accepts(ARunner, V, '11144477735', 'accepts a CPF whose first check digit is 3');

  Rejects(ARunner, V, '', vfEmpty, 'rejects an empty string');
  Rejects(ARunner, V, '   ', vfEmpty, 'rejects whitespace only');
  Rejects(ARunner, V, 'abc.def.ghi-jk', vfInvalidCharacters,
    'rejects a value with no digits at all');
  Rejects(ARunner, V, '5299822472', vfInvalidLength, 'rejects 10 digits');
  Rejects(ARunner, V, '529982247251', vfInvalidLength, 'rejects 12 digits');
  Rejects(ARunner, V, '52998224726', vfCheckDigitMismatch,
    'rejects a wrong second check digit');
  Rejects(ARunner, V, '52998224735', vfCheckDigitMismatch,
    'rejects a wrong first check digit');

  { Every repeated-digit CPF satisfies the modulus-11 arithmetic, so a
    validator that only checks the digits accepts all eleven of them. This is
    the single most common bug in CPF implementations. }
  for I := 0 to 9 do
  begin
    Repeated := StringOfChar(Chr(Ord('0') + I), 11);
    Rejects(ARunner, V, Repeated, vfRepeatedSequence,
      Format('rejects the repeated sequence %s', [Repeated]));
  end;
end;

procedure TestCnpj(ARunner: TTestRunner);
var
  V: IValidator;
  I: Integer;
  Repeated: string;
begin
  ARunner.Suite('CNPJ');
  V := TCnpjValidator.Create;

  Accepts(ARunner, V, '11222333000181', 'accepts a valid unformatted CNPJ');
  Accepts(ARunner, V, '11.222.333/0001-81', 'accepts the same CNPJ formatted');
  Accepts(ARunner, V, '04252011000110', 'accepts a CNPJ with leading zero');

  Rejects(ARunner, V, '', vfEmpty, 'rejects an empty string');
  Rejects(ARunner, V, '1122233300018', vfInvalidLength, 'rejects 13 digits');
  Rejects(ARunner, V, '112223330001811', vfInvalidLength, 'rejects 15 digits');
  Rejects(ARunner, V, '11222333000182', vfCheckDigitMismatch,
    'rejects a wrong second check digit');
  Rejects(ARunner, V, '11222333000191', vfCheckDigitMismatch,
    'rejects a wrong first check digit');

  for I := 0 to 9 do
  begin
    Repeated := StringOfChar(Chr(Ord('0') + I), 14);
    Rejects(ARunner, V, Repeated, vfRepeatedSequence,
      Format('rejects the repeated sequence %s', [Repeated]));
  end;
end;

procedure TestCep(ARunner: TTestRunner);
var
  Shape: IValidator;
  Ceara: IValidator;
  SaoPaulo: IValidator;
  Amazonas: IValidator;
  Brasilia: IValidator;
  Nowhere: IValidator;
begin
  ARunner.Suite('CEP');

  Shape := TCepValidator.Create;
  Accepts(ARunner, Shape, '60000000', 'accepts 8 digits when no state is given');
  Accepts(ARunner, Shape, '60000-000', 'accepts the formatted form');
  Rejects(ARunner, Shape, '', vfEmpty, 'rejects an empty string');
  Rejects(ARunner, Shape, '6000000', vfInvalidLength, 'rejects 7 digits');
  Rejects(ARunner, Shape, '600000000', vfInvalidLength, 'rejects 9 digits');

  Ceara := TCepValidator.Create('CE');
  Accepts(ARunner, Ceara, '60175295', 'accepts a Fortaleza CEP for CE');
  Accepts(ARunner, Ceara, '63900000', 'accepts the last CE block');
  Rejects(ARunner, Ceara, '01310930', vfOutOfRange,
    'rejects a Sao Paulo CEP for CE');

  SaoPaulo := TCepValidator.Create('sp');
  Accepts(ARunner, SaoPaulo, '01310930',
    'accepts a Sao Paulo CEP with a lowercase state code');
  Accepts(ARunner, SaoPaulo, '01000000',
    'accepts the first SP code, whose prefix has a leading zero');

  { Amazonas holds two separate blocks with Roraima wedged between them.
    A single-range lookup gets this wrong. }
  Amazonas := TCepValidator.Create('AM');
  Accepts(ARunner, Amazonas, '69000000', 'accepts the first AM block');
  Accepts(ARunner, Amazonas, '69500000', 'accepts the second AM block');
  Rejects(ARunner, Amazonas, '69350000', vfOutOfRange,
    'rejects the Roraima block that sits between the two AM blocks');

  { Brasilia is likewise split, by a Goias block. }
  Brasilia := TCepValidator.Create('DF');
  Accepts(ARunner, Brasilia, '70000000', 'accepts the first DF block');
  Accepts(ARunner, Brasilia, '73100000', 'accepts the second DF block');
  Rejects(ARunner, Brasilia, '72900000', vfOutOfRange,
    'rejects the Goias block that sits between the two DF blocks');

  Nowhere := TCepValidator.Create('XX');
  Rejects(ARunner, Nowhere, '60175295', vfUnknownRegion,
    'reports an unrecognised state code rather than a range failure');
end;

procedure TestEmail(ARunner: TTestRunner);
var
  V: IValidator;
begin
  ARunner.Suite('E-mail');
  V := TEmailValidator.Create;

  Accepts(ARunner, V, 'ramon@example.com', 'accepts a plain address');
  Accepts(ARunner, V, 'ramon.ruan+jobs@sub.example.co.uk',
    'accepts dots, a plus tag and a multi-label domain');
  Accepts(ARunner, V, '  ramon@example.com  ', 'ignores surrounding whitespace');

  Rejects(ARunner, V, '', vfEmpty, 'rejects an empty string');
  Rejects(ARunner, V, 'ramon at example.com', vfInvalidCharacters,
    'rejects a value containing a space');
  Rejects(ARunner, V, 'ramon.example.com', vfInvalidFormat, 'rejects a missing @');
  Rejects(ARunner, V, 'ramon@@example.com', vfInvalidFormat,
    'rejects a doubled @');
  Rejects(ARunner, V, 'ramon@ex@ample.com', vfInvalidFormat,
    'rejects two separated @ signs');
  Rejects(ARunner, V, '@example.com', vfInvalidFormat,
    'rejects an empty local part');
  Rejects(ARunner, V, 'ramon@', vfInvalidFormat, 'rejects an empty domain');
  Rejects(ARunner, V, 'ramon@example', vfInvalidFormat,
    'rejects a domain with no dot');
  Rejects(ARunner, V, 'ramon@.example.com', vfInvalidFormat,
    'rejects a domain starting with a dot');
  Rejects(ARunner, V, 'ramon@example.com.', vfInvalidFormat,
    'rejects a domain ending with a dot');
  Rejects(ARunner, V, 'ramon@example..com', vfInvalidFormat,
    'rejects consecutive dots');
  Rejects(ARunner, V, 'ramon@example.c', vfInvalidFormat,
    'rejects a single-character top-level domain');
end;

procedure TestDate(ARunner: TTestRunner);
var
  V: IValidator;
  { Two variables for one object, deliberately.

    The validators descend from TInterfacedObject, so the moment one is passed
    to an IValidator parameter it acquires a reference count. Holding only the
    concrete reference means the count drops to zero when that call returns and
    the object is freed underneath you — the next use reads freed memory.

    Keeping the interface reference alive for the whole scope is the contract
    for every validator in this library. }
  PivotedRef: IValidator;
  Pivoted: TDateValidator;
begin
  ARunner.Suite('Date');
  V := TDateValidator.Create;

  Accepts(ARunner, V, '29/07/2026', 'accepts dd/mm/yyyy');
  Accepts(ARunner, V, '29-07-2026', 'accepts a dash separator');
  Accepts(ARunner, V, '29.07.2026', 'accepts a dot separator');
  Accepts(ARunner, V, '1/1/2026', 'accepts single-digit day and month');
  Accepts(ARunner, V, '29/02/2024', 'accepts 29 February in a leap year');
  Accepts(ARunner, V, '29/02/2000',
    'accepts 29 February in a century divisible by 400');

  Rejects(ARunner, V, '', vfEmpty, 'rejects an empty string');
  Rejects(ARunner, V, '29/07', vfInvalidFormat, 'rejects a missing year');
  Rejects(ARunner, V, '29/07/2026/01', vfInvalidFormat,
    'rejects a fourth component');
  Rejects(ARunner, V, '29//2026', vfInvalidFormat, 'rejects an empty component');
  Rejects(ARunner, V, '29/07/202', vfInvalidFormat,
    'rejects a three-digit year');
  Rejects(ARunner, V, '29/ju/2026', vfInvalidCharacters,
    'rejects letters in a component');
  Rejects(ARunner, V, '29/13/2026', vfOutOfRange, 'rejects month 13');
  Rejects(ARunner, V, '29/00/2026', vfOutOfRange, 'rejects month 0');
  Rejects(ARunner, V, '32/07/2026', vfOutOfRange, 'rejects day 32');
  Rejects(ARunner, V, '00/07/2026', vfOutOfRange, 'rejects day 0');
  Rejects(ARunner, V, '31/04/2026', vfOutOfRange,
    'rejects 31 April, a month with 30 days');
  Rejects(ARunner, V, '29/02/2026', vfOutOfRange,
    'rejects 29 February outside a leap year');
  Rejects(ARunner, V, '29/02/1900', vfOutOfRange,
    'rejects 29 February in a century not divisible by 400');

  { The two-digit year window is a policy, not a fact, so it is configurable
    and its behaviour is pinned by tests. }
  Pivoted := TDateValidator.Create;
  PivotedRef := Pivoted;
  Pivoted.TwoDigitYearPivot := 50;
  ARunner.Suite('Date, two-digit years');
  Accepts(ARunner, PivotedRef, '29/02/24',
    'reads 24 as 2024, a leap year, with the default pivot');
  Rejects(ARunner, PivotedRef, '29/02/99', vfOutOfRange,
    'reads 99 as 1999, not a leap year, with the default pivot');

  Pivoted.TwoDigitYearPivot := 30;
  Accepts(ARunner, PivotedRef, '29/02/24',
    'reads 24 as 2024 with a pivot of 30 as well');
  Accepts(ARunner, PivotedRef, '29/02/96',
    'reads 96 as 1996, a leap year, with a pivot of 30');
end;

procedure TestComposite(ARunner: TTestRunner);
var
  Composite: TCompositeValidator;
  AsValidator: IValidator;
  Empty: IValidator;
  Raised: Boolean;
begin
  ARunner.Suite('Composite');

  Composite := TCompositeValidator.Create([TCpfValidator.Create,
    TCpfValidator.Create]);
  AsValidator := Composite;
  ARunner.AreEqual('holds every validator it was given', 2, Composite.Count);
  Accepts(ARunner, AsValidator, '52998224725',
    'passes when every validator passes');
  Rejects(ARunner, AsValidator, '52998224726', vfCheckDigitMismatch,
    'returns the first failure');

  Empty := TCompositeValidator.Create([]);
  Accepts(ARunner, Empty, 'anything at all',
    'an empty composite accepts everything, having nothing to object to');

  { Pins the lifetime contract itself: the inner validators are kept alive by
    the composite's own interface references, so callers do not free them and
    must not hold concrete references to them. }
  Accepts(ARunner, AsValidator, '529.982.247-25',
    'inner validators outlive the expression that created them');

  { A nil validator is a wiring mistake and is the one case the core raises
    for, so the behaviour is pinned. }
  Raised := False;
  try
    TCompositeValidator.Create([TCpfValidator.Create, nil]);
  except
    Raised := True;
  end;
  ARunner.IsTrue('raises when handed a nil validator', Raised);
end;

procedure RunValidationTests(ARunner: TTestRunner);
begin
  TestCpf(ARunner);
  TestCnpj(ARunner);
  TestCep(ARunner);
  TestEmail(ARunner);
  TestDate(ARunner);
  TestComposite(ARunner);
end;

end.
