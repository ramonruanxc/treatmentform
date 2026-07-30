{
  TreatmentForm — core test runner.

  Compiles and runs under both toolchains:

    Delphi        dcc32 -B CoreTests.dpr
    Free Pascal   fpc -Mdelphi CoreTests.dpr

  Exits non-zero when any assertion fails, which is what CI checks.
}
program CoreTests;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
{$ELSE}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  { Every project unit is listed with its path, including the ones only reached
    indirectly, so the project builds from a clone with nothing to configure.
    Forward slashes on purpose: Delphi accepts them on Windows and Free Pascal
    needs them on Linux. }
  TreatmentForm.Types in '../../src/core/TreatmentForm.Types.pas',
  TreatmentForm.Text in '../../src/core/TreatmentForm.Text.pas',
  TreatmentForm.Validation in '../../src/core/TreatmentForm.Validation.pas',
  TreatmentForm.Formatting in '../../src/core/TreatmentForm.Formatting.pas',
  TreatmentForm.Testing in '../../src/core/TreatmentForm.Testing.pas',
  TreatmentForm.Tests.Validation in 'TreatmentForm.Tests.Validation.pas',
  TreatmentForm.Tests.Formatting in 'TreatmentForm.Tests.Formatting.pas';

var
  Runner: TTestRunner;
begin
  WriteLn('TreatmentForm core test suite');
  {$IFDEF FPC}
  WriteLn('compiler: Free Pascal');
  {$ELSE}
  WriteLn('compiler: Delphi');
  {$ENDIF}

  Runner := TTestRunner.Create;
  try
    RunValidationTests(Runner);
    RunFormattingTests(Runner);
    ExitCode := Runner.Finish;
  finally
    Runner.Free;
  end;
end.
