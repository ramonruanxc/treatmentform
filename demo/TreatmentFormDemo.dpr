program TreatmentFormDemo;

uses
  Vcl.Forms,
  DemoForm in 'DemoForm.pas';

var
  frmDemo: TfrmDemo;

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'TreatmentForm demo';
  Application.CreateForm(TfrmDemo, frmDemo);
  Application.Run;
end.
