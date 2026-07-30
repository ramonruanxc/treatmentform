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
  TreatmentForm.Testing,
  TreatmentForm.Tests.Validation,
  TreatmentForm.Tests.Formatting;

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
