unit TreatmentForm.Tests.Formatting;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}

interface

uses
  TreatmentForm.Testing;

procedure RunFormattingTests(ARunner: TTestRunner);

implementation

uses
  TreatmentForm.Types,
  TreatmentForm.Formatting;

procedure Formats(ARunner: TTestRunner; AFormatter: IFormatter;
  const AInput, AExpected, ADescription: string);
begin
  ARunner.AreEqual(ADescription, AExpected, AFormatter.Format(AInput));
end;

procedure TestCpfCnpj(ARunner: TTestRunner);
var
  F: IFormatter;
begin
  ARunner.Suite('CPF / CNPJ formatting');
  F := TCpfCnpjFormatter.Create;

  Formats(ARunner, F, '52998224725', '529.982.247-25',
    'formats 11 digits as a CPF');
  Formats(ARunner, F, '11222333000181', '11.222.333/0001-81',
    'formats 14 digits as a CNPJ');
  Formats(ARunner, F, '529.982.247-25', '529.982.247-25',
    'is idempotent on an already formatted CPF');
  Formats(ARunner, F, '04252011000110', '04.252.011/0001-10',
    'keeps a leading zero');

  { Neither 11 nor 14 digits: the formatter has no basis for a choice, so it
    returns the digits rather than guessing at a layout. }
  Formats(ARunner, F, '5299822472', '5299822472',
    'returns bare digits for an ambiguous length');
  Formats(ARunner, F, '', '', 'returns an empty string unchanged');
  Formats(ARunner, F, 'no digits here', '',
    'strips everything that is not a digit');
end;

procedure TestPhone(ARunner: TTestRunner);
var
  F: IFormatter;
begin
  ARunner.Suite('Phone formatting');
  F := TPhoneFormatter.Create;

  Formats(ARunner, F, '32345678', '3234-5678', 'formats an 8 digit number');
  Formats(ARunner, F, '997838819', '99783-8819', 'formats a 9 digit number');
  Formats(ARunner, F, '8532345678', '(85) 3234-5678',
    'formats an area code with 8 digits');
  Formats(ARunner, F, '85997838819', '(85) 99783-8819',
    'formats an area code with 9 digits');
  Formats(ARunner, F, '5585997838819', '+55 (85) 99783-8819',
    'formats a country code');
  Formats(ARunner, F, '+55 (85) 99783-8819', '+55 (85) 99783-8819',
    'is idempotent on an already formatted number');
  Formats(ARunner, F, '123', '123', 'returns an unrecognised length unchanged');
end;

procedure TestCep(ARunner: TTestRunner);
var
  F: IFormatter;
begin
  ARunner.Suite('CEP formatting');
  F := TCepFormatter.Create;

  Formats(ARunner, F, '60175295', '60175-295', 'formats 8 digits');
  Formats(ARunner, F, '60175-295', '60175-295', 'is idempotent');
  Formats(ARunner, F, '6017529', '6017529',
    'returns an incomplete code unchanged');
end;

procedure TestDate(ARunner: TTestRunner);
var
  FourDigit: IFormatter;
  TwoDigit: IFormatter;
begin
  ARunner.Suite('Date formatting');

  FourDigit := TDateFormatter.Create(dsFourDigitYear);
  Formats(ARunner, FourDigit, '29072026', '29/07/2026', 'formats 8 digits');
  Formats(ARunner, FourDigit, '29/07/2026', '29/07/2026', 'is idempotent');

  TwoDigit := TDateFormatter.Create(dsTwoDigitYear);
  Formats(ARunner, TwoDigit, '290726', '29/07/26', 'formats 6 digits');

  { A four-digit year still formats correctly under the two-digit style: the
    digit count is unambiguous, and refusing it would only surprise callers. }
  Formats(ARunner, TwoDigit, '29072026', '29/07/2026',
    'formats 8 digits even under the two-digit style');

  Formats(ARunner, FourDigit, '2907', '2907',
    'returns an incomplete date unchanged');
end;

procedure RunFormattingTests(ARunner: TTestRunner);
begin
  TestCpfCnpj(ARunner);
  TestPhone(ARunner);
  TestCep(ARunner);
  TestDate(ARunner);
end;

end.
