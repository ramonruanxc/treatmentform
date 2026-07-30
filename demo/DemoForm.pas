{
  TreatmentForm — demo.

  An ordinary VCL form with an ordinary .dfm, so it opens in the form designer
  like any other Delphi project. The controls live in the designer; this unit
  holds only the wiring, which is the part worth reading:

    - which validator applies to which control (FormCreate)
    - how failures are signalled (the Treat calls)
    - formatting while the user types (edCpfChange)

  Note that the form descends from TForm, not from the library's TFadeForm. A
  form whose ancestor is a custom form class cannot be opened in the designer
  unless that ancestor is installed in a design-time package, which is friction
  a demo should not impose. TFadeForm gets its own runtime demonstration
  instead — see btnFadeFormClick.
}
unit DemoForm;

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.Graphics,
  TreatmentForm.Vcl.FormTreatment;

type
  TfrmDemo = class(TForm)
    lblName: TLabel;
    lblCpf: TLabel;
    lblEmail: TLabel;
    lblCep: TLabel;
    lblBirthDate: TLabel;
    lblStatus: TLabel;
    edName: TEdit;
    edCpf: TEdit;
    edEmail: TEdit;
    edCep: TEdit;
    edBirthDate: TEdit;
    btnValidate: TButton;
    btnFadeForm: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnValidateClick(Sender: TObject);
    procedure edCpfChange(Sender: TObject);
    procedure btnFadeFormClick(Sender: TObject);
  strict private
    FTreatment: TFormTreatment;
  public
    destructor Destroy; override;
  end;

var
  frmDemo: TfrmDemo;

implementation

uses
  System.SysUtils,
  TreatmentForm.Types,
  TreatmentForm.Validation,
  TreatmentForm.Formatting,
  TreatmentForm.Vcl.Controls,
  TreatmentForm.Vcl.Treatments;

{$R *.dfm}

procedure TfrmDemo.FormCreate(Sender: TObject);
begin
  { The whole configuration of the form, in one readable block.

    How failures are shown, and what is checked, are separate decisions — which
    is the point of the rewrite. Swapping the balloon for an inline label means
    changing one line here and nothing else. }
  FTreatment := TFormTreatment.Create;
  FTreatment.StopOnFirstFailure := False;

  FTreatment
    .Treat(THighlightTreatment.Create)
    .Treat(TBalloonTipTreatment.Create('Check this field'))
    .Treat(TFocusTreatment.Create);

  { Rules name the control they apply to. The 2017 version guessed from the
    control's name, so renaming a field silently disabled its validation. }
  FTreatment
    .Require(edName, 'Name')
    .Require(edCpf, 'CPF')
    .Rule(edCpf, TCpfValidator.Create, 'CPF')
    .Require(edEmail, 'E-mail')
    .Rule(edEmail, TEmailValidator.Create, 'E-mail')
    .Rule(edCep, TCepValidator.Create('CE'), 'CEP')
    .Rule(edBirthDate, TDateValidator.Create, 'Birth date');
end;

destructor TfrmDemo.Destroy;
begin
  FTreatment.Free;
  inherited Destroy;
end;

procedure TfrmDemo.edCpfChange(Sender: TObject);
var
  Formatter: IFormatter;
  Formatted: string;
begin
  { Formatters never reject, so this is safe to run on every keystroke. The
    handler is detached while rewriting Text to avoid re-entering itself. }
  Formatter := TCpfCnpjFormatter.Create;
  Formatted := Formatter.Format(edCpf.Text);
  if Formatted = edCpf.Text then
    Exit;

  edCpf.OnChange := nil;
  try
    edCpf.Text := Formatted;
    edCpf.SelStart := Length(Formatted);
  finally
    edCpf.OnChange := edCpfChange;
  end;
end;

procedure TfrmDemo.btnValidateClick(Sender: TObject);
begin
  if FTreatment.Validate then
  begin
    lblStatus.Font.Color := clGreen;
    lblStatus.Caption := 'All fields valid.';
  end
  else
  begin
    lblStatus.Font.Color := clRed;
    { Failures holds every failure of the pass, in field order, each carrying
      the reason its validator gave. }
    lblStatus.Caption := Format('%d field(s) rejected. First: %s',
      [FTreatment.Failures.Count, FTreatment.Failures[0].Message]);
  end;
end;

procedure TfrmDemo.btnFadeFormClick(Sender: TObject);
var
  Fade: TFadeForm;
  Info: TLabel;
begin
  { TFadeForm has no .dfm of its own, so it is built with CreateNew — Create
    would raise EResNotFound. Its defaults come from InitializeNewForm, which
    both constructors call, so FadeEnabled and CloseOnEscape are already set
    here. }
  Fade := TFadeForm.CreateNew(Self);
  try
    Fade.Caption := 'TFadeForm';
    Fade.Position := poMainFormCenter;
    Fade.BorderStyle := bsDialog;
    Fade.ClientWidth := 320;
    Fade.ClientHeight := 120;
    Fade.FadeDuration := 400;

    Info := TLabel.Create(Fade);
    Info.Parent := Fade;
    Info.SetBounds(24, 40, 280, 40);
    Info.WordWrap := True;
    Info.Caption := 'This window faded in over 400 ms. Press Escape to close ' +
      'it — the fade is on open only.';

    Fade.ShowModal;
  finally
    Fade.Free;
  end;
end;

end.
