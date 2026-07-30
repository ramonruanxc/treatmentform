{
  TreatmentForm — demo.

  Built entirely in code, with no .dfm. That is deliberate: the form is
  documentation, and a reader can follow what it does from this one file
  instead of cross-referencing a designer file they cannot see on GitHub.

  Replaces a 1,416 line demo whose length came from repeating the same wiring
  for every control.
}
unit DemoForm;

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.Graphics,
  TreatmentForm.Vcl.Controls,
  TreatmentForm.Vcl.FormTreatment;

type
  TfrmDemo = class(TFadeForm)
  strict private
    FName: TEdit;
    FCpf: TEdit;
    FEmail: TEdit;
    FCep: TEdit;
    FBirthDate: TEdit;
    FStatus: TLabel;
    FTreatment: TFormTreatment;
    function AddField(const ACaption: string; ATop: Integer): TEdit;
    procedure SubmitClick(Sender: TObject);
    procedure FormatCpf(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

uses
  System.SysUtils,
  TreatmentForm.Types,
  TreatmentForm.Validation,
  TreatmentForm.Formatting,
  TreatmentForm.Vcl.Treatments;

function TfrmDemo.AddField(const ACaption: string; ATop: Integer): TEdit;
var
  Lbl: TLabel;
begin
  Lbl := TLabel.Create(Self);
  Lbl.Parent := Self;
  Lbl.SetBounds(24, ATop, 100, 17);
  Lbl.Caption := ACaption;

  Result := TEdit.Create(Self);
  Result.Parent := Self;
  Result.SetBounds(140, ATop - 3, 260, 25);
  Result.Name := 'ed' + StringReplace(ACaption, ' ', '', [rfReplaceAll]);
end;

constructor TfrmDemo.Create(AOwner: TComponent);
var
  Submit: TButton;
begin
  inherited Create(AOwner);

  Caption := 'TreatmentForm demo';
  Position := poScreenCenter;
  ClientWidth := 440;
  ClientHeight := 300;
  BorderStyle := bsSingle;
  KeyPreview := True;

  FName := AddField('Name', 30);
  FCpf := AddField('CPF', 70);
  FEmail := AddField('E-mail', 110);
  FCep := AddField('CEP (CE)', 150);
  FBirthDate := AddField('Birth date', 190);

  { Formatting runs while the user types; it never rejects. }
  FCpf.OnChange := FormatCpf;

  Submit := TButton.Create(Self);
  Submit.Parent := Self;
  Submit.SetBounds(140, 230, 120, 30);
  Submit.Caption := 'Validate';
  Submit.Default := True;
  Submit.OnClick := SubmitClick;

  FStatus := TLabel.Create(Self);
  FStatus.Parent := Self;
  FStatus.SetBounds(24, 270, 400, 17);
  FStatus.Font.Style := [fsBold];

  { The whole configuration of the form, in one readable block.

    How failures are shown, and what the rules are, are separate decisions —
    which is the entire point of the rewrite. Swapping the balloon for an
    inline label means changing one line here and nothing else. }
  FTreatment := TFormTreatment.Create;
  FTreatment.StopOnFirstFailure := False;

  FTreatment
    .Treat(THighlightTreatment.Create)
    .Treat(TBalloonTipTreatment.Create('Check this field'))
    .Treat(TFocusTreatment.Create);

  FTreatment
    .Require(FName, 'Name')
    .Require(FCpf, 'CPF')
    .Rule(FCpf, TCpfValidator.Create, 'CPF')
    .Require(FEmail, 'E-mail')
    .Rule(FEmail, TEmailValidator.Create, 'E-mail')
    .Rule(FCep, TCepValidator.Create('CE'), 'CEP')
    .Rule(FBirthDate, TDateValidator.Create, 'Birth date');

  FTreatment.ArrangeTabOrder(Self);
end;

destructor TfrmDemo.Destroy;
begin
  FTreatment.Free;
  inherited Destroy;
end;

procedure TfrmDemo.FormatCpf(Sender: TObject);
var
  F: IFormatter;
  Formatted: string;
begin
  F := TCpfCnpjFormatter.Create;
  Formatted := F.Format(FCpf.Text);
  if Formatted = FCpf.Text then
    Exit;
  FCpf.OnChange := nil;
  try
    FCpf.Text := Formatted;
    FCpf.SelStart := Length(Formatted);
  finally
    FCpf.OnChange := FormatCpf;
  end;
end;

procedure TfrmDemo.SubmitClick(Sender: TObject);
begin
  if FTreatment.Validate then
  begin
    FStatus.Font.Color := clGreen;
    FStatus.Caption := 'All fields valid.';
  end
  else
  begin
    FStatus.Font.Color := clRed;
    { Failures carries every failure of the pass, in field order, each with the
      reason the validator gave. }
    FStatus.Caption := Format('%d field(s) rejected. First: %s',
      [FTreatment.Failures.Count, FTreatment.Failures[0].Message]);
  end;
end;

end.
