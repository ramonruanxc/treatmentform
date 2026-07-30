program TreatmentFormDemo;

uses
  Vcl.Forms,
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
