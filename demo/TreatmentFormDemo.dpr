program TreatmentFormDemo;

uses
  Vcl.Forms,
  { Every project unit is listed with its path so the demo builds from a clone
    without setting a search path. Forward slashes on purpose: Delphi accepts
    them on Windows. }
  TreatmentForm.Types in '../src/core/TreatmentForm.Types.pas',
  TreatmentForm.Text in '../src/core/TreatmentForm.Text.pas',
  TreatmentForm.Validation in '../src/core/TreatmentForm.Validation.pas',
  TreatmentForm.Formatting in '../src/core/TreatmentForm.Formatting.pas',
  TreatmentForm.Vcl.Treatments in '../src/vcl/TreatmentForm.Vcl.Treatments.pas',
  TreatmentForm.Vcl.FormTreatment in '../src/vcl/TreatmentForm.Vcl.FormTreatment.pas',
  TreatmentForm.Vcl.Controls in '../src/vcl/TreatmentForm.Vcl.Controls.pas',
  DemoForm in 'DemoForm.pas' {frmDemo};

{ The project .res carries the application MANIFEST, not just version info and
  an icon: without it the executable gets no comctl32 v6 reference (controls
  render in the legacy unthemed style) and no DPI declaration (Windows treats
  the process as DPI-unaware and bitmap-stretches it above 100% scaling). It is
  build-generated, so it is not checked in — the IDE and MSBuild recreate it. }
{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'TreatmentForm demo';
  Application.CreateForm(TfrmDemo, frmDemo);
  Application.Run;
end.
