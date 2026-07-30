{
  TreatmentForm — portable core.

  A deliberately small assertion runner.

  Why not DUnitX: the core suite has to run under both Delphi and Free
  Pascal, because Free Pascal is what makes continuous integration possible
  without a licensed compiler on the build machine. DUnitX does not run on
  FPC, and maintaining two parallel suites is how test suites rot. Roughly a
  hundred lines of runner is the cheaper trade.

  Delphi users who want IDE integration can wrap these suites in DUnitX
  without touching them; the assertions carry no framework state.
}
unit TreatmentForm.Testing;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
{$ENDIF}

interface

type
  TTestRunner = class
  strict private
    FPassed: Integer;
    FFailed: Integer;
    FSuiteName: string;
    FSuiteHeaderWritten: Boolean;
    procedure EnsureSuiteHeader;
    procedure Pass(const ATestName: string);
    procedure Fail(const ATestName, AExpected, AActual: string);
  public
    constructor Create;

    { Starts a named group. Purely for output grouping. }
    procedure Suite(const AName: string);

    procedure IsTrue(const ATestName: string; ACondition: Boolean);
    procedure IsFalse(const ATestName: string; ACondition: Boolean);
    procedure AreEqual(const ATestName, AExpected, AActual: string); overload;
    procedure AreEqual(const ATestName: string; AExpected, AActual: Integer); overload;

    { Writes the totals and returns the process exit code: 0 when everything
      passed, 1 otherwise. CI reads this. }
    function Finish: Integer;

    property Passed: Integer read FPassed;
    property Failed: Integer read FFailed;
  end;

implementation

uses
  {$IFDEF FPC}SysUtils{$ELSE}System.SysUtils{$ENDIF};

constructor TTestRunner.Create;
begin
  inherited Create;
  FPassed := 0;
  FFailed := 0;
  FSuiteName := '';
  FSuiteHeaderWritten := True;
end;

procedure TTestRunner.Suite(const AName: string);
begin
  FSuiteName := AName;
  FSuiteHeaderWritten := False;
end;

procedure TTestRunner.EnsureSuiteHeader;
begin
  if FSuiteHeaderWritten then
    Exit;
  WriteLn;
  WriteLn(FSuiteName);
  FSuiteHeaderWritten := True;
end;

procedure TTestRunner.Pass(const ATestName: string);
begin
  EnsureSuiteHeader;
  Inc(FPassed);
  WriteLn('  ok      ', ATestName);
end;

procedure TTestRunner.Fail(const ATestName, AExpected, AActual: string);
begin
  EnsureSuiteHeader;
  Inc(FFailed);
  WriteLn('  FAILED  ', ATestName);
  WriteLn('            expected: ', AExpected);
  WriteLn('            actual:   ', AActual);
end;

procedure TTestRunner.IsTrue(const ATestName: string; ACondition: Boolean);
begin
  if ACondition then
    Pass(ATestName)
  else
    Fail(ATestName, 'True', 'False');
end;

procedure TTestRunner.IsFalse(const ATestName: string; ACondition: Boolean);
begin
  if not ACondition then
    Pass(ATestName)
  else
    Fail(ATestName, 'False', 'True');
end;

procedure TTestRunner.AreEqual(const ATestName, AExpected, AActual: string);
begin
  if AExpected = AActual then
    Pass(ATestName)
  else
    Fail(ATestName, '"' + AExpected + '"', '"' + AActual + '"');
end;

procedure TTestRunner.AreEqual(const ATestName: string; AExpected, AActual: Integer);
begin
  if AExpected = AActual then
    Pass(ATestName)
  else
    Fail(ATestName, IntToStr(AExpected), IntToStr(AActual));
end;

function TTestRunner.Finish: Integer;
begin
  WriteLn;
  WriteLn('----------------------------------------');
  WriteLn(Format('%d passed, %d failed, %d total',
    [FPassed, FFailed, FPassed + FFailed]));
  if FFailed = 0 then
    Result := 0
  else
    Result := 1;
end;

end.
