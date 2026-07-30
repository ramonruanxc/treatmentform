{
  TreatmentForm — VCL layer.

  Runs a set of rules over a form's controls and reports failures through
  whichever treatments were attached.

  Two things changed from the original, and both were defects rather than
  matters of taste.

  Rules are now bound explicitly. The original inferred them from the control's
  name:

      if UpperCase(Edit.Name).Contains('EMAIL') then
        if not Edit.IsEmail then ...

  Rename edEmail to edContact and the validation silently stops running. No
  compiler error, no test failure, no warning — the form just quietly accepts
  anything. Here a rule names the control it applies to, so the compiler is
  involved.

  The result is now accumulated correctly. The original assigned Result inside
  the loop, so in the "InAll" modes the last control examined decided the
  answer: an invalid field followed by a valid one returned True and the form
  submitted.
}
unit TreatmentForm.Vcl.FormTreatment;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Forms,
  TreatmentForm.Types,
  TreatmentForm.Vcl.Treatments;

type
  TFieldRule = record
    Control: TWinControl;
    Validator: IValidator;
    Label_: string;
  end;

  TFormTreatment = class
  strict private
    FRules: TList<TFieldRule>;
    FTreatments: TList<IControlTreatment>;
    FStopOnFirstFailure: Boolean;
    FFirstInvalidControl: TWinControl;
    FFailures: TList<TValidationResult>;
    function ControlValue(AControl: TWinControl): string;
    function ShouldSkip(AControl: TWinControl): Boolean;
    procedure ClearAll;
  public
    constructor Create;
    destructor Destroy; override;

    { How failures are signalled. Attach as many as make sense; they all run. }
    function Treat(const ATreatment: IControlTreatment): TFormTreatment;

    { The control must hold a non-empty value. }
    function Require(AControl: TWinControl; const ALabel: string = ''): TFormTreatment;

    { The control's value must satisfy AValidator. An empty control passes:
      combine with Require when the field is mandatory as well as formatted. }
    function Rule(AControl: TWinControl; const AValidator: IValidator;
      const ALabel: string = ''): TFormTreatment;

    { Runs every rule. Returns True only when all of them passed. }
    function Validate: Boolean;

    { Assigns tab order following the visual layout, top to bottom then left to
      right, skipping controls that cannot receive focus. }
    procedure ArrangeTabOrder(AParent: TWinControl);

    { Populated by the last Validate call. }
    property FirstInvalidControl: TWinControl read FFirstInvalidControl;
    property Failures: TList<TValidationResult> read FFailures;

    { When True (the default) Validate returns as soon as a rule fails, which
      is the original ttBalloonTipInOne / ttPaintControlInOne behaviour. When
      False every rule runs and every failure is signalled, which is the
      "InAll" behaviour — only now the return value is still correct. }
    property StopOnFirstFailure: Boolean read FStopOnFirstFailure
      write FStopOnFirstFailure;
  end;

  { Required-value rule, expressed as a validator so that "must be filled in"
    composes with every other rule instead of being a special case in the loop. }
  TRequiredValidator = class(TInterfacedObject, IValidator)
  strict private
    FLabel: string;
  public
    constructor Create(const ALabel: string = '');
    function Validate(const AValue: string): TValidationResult;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Defaults,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.Mask;

{ TRequiredValidator }

constructor TRequiredValidator.Create(const ALabel: string);
begin
  inherited Create;
  FLabel := ALabel;
end;

function TRequiredValidator.Validate(const AValue: string): TValidationResult;
begin
  if Trim(AValue) = '' then
  begin
    if FLabel <> '' then
      Result := TValidationResult.Invalid(vfEmpty,
        Format('%s is required.', [FLabel]))
    else
      Result := TValidationResult.Invalid(vfEmpty, 'This field is required.');
  end
  else
    Result := TValidationResult.Valid;
end;

{ TFormTreatment }

constructor TFormTreatment.Create;
begin
  inherited Create;
  FRules := TList<TFieldRule>.Create;
  FTreatments := TList<IControlTreatment>.Create;
  FFailures := TList<TValidationResult>.Create;
  FStopOnFirstFailure := True;
end;

destructor TFormTreatment.Destroy;
begin
  FFailures.Free;
  FTreatments.Free;
  FRules.Free;
  inherited Destroy;
end;

function TFormTreatment.Treat(const ATreatment: IControlTreatment): TFormTreatment;
begin
  if ATreatment = nil then
    raise Exception.Create('Treatment cannot be nil.');
  FTreatments.Add(ATreatment);
  Result := Self;
end;

function TFormTreatment.Require(AControl: TWinControl;
  const ALabel: string): TFormTreatment;
begin
  Result := Rule(AControl, TRequiredValidator.Create(ALabel), ALabel);
end;

function TFormTreatment.Rule(AControl: TWinControl;
  const AValidator: IValidator; const ALabel: string): TFormTreatment;
var
  NewRule: TFieldRule;
begin
  if AControl = nil then
    raise Exception.Create('Rule target control cannot be nil.');
  if AValidator = nil then
    raise Exception.CreateFmt('Validator for "%s" cannot be nil.',
      [AControl.Name]);

  NewRule.Control := AControl;
  NewRule.Validator := AValidator;
  NewRule.Label_ := ALabel;
  FRules.Add(NewRule);
  Result := Self;
end;

type
  { TControl.Text is protected, so a TWinControl reference cannot read it; a
    local descendant exposes the inherited member. Text lives on TControl, so
    this reaches every control uniformly — the standard VCL "cracker" idiom. }
  TControlTextAccess = class(TControl);

function TFormTreatment.ControlValue(AControl: TWinControl): string;
begin
  if AControl is TDateTimePicker then
    { Pinned format, not DateToStr. DateToStr uses the ambient
      ShortDateFormat, while TDateValidator is a fixed day/month/year parser —
      so on an m/d/yyyy machine a valid date came back as '7/25/2026' and was
      rejected with "Month 25 is out of range", and on d <= 12 the day and
      month silently swapped. The two halves of the library have to agree on
      one order, and this is where that is decided. }
    Result := FormatDateTime('dd/mm/yyyy', TDateTimePicker(AControl).Date)
  else
    Result := TControlTextAccess(AControl).Text;
end;

{ TControl.Visible reports the control's OWN flag, which stays True for an edit
  sitting on a hidden panel or an inactive tab sheet. Effective visibility needs
  the whole parent chain, otherwise a form refuses to submit and paints the
  reason on a page the user cannot see. }
function EffectivelyVisible(AControl: TControl): Boolean;
var
  Current: TControl;
begin
  Current := AControl;
  while (Current <> nil) and Current.Visible do
    Current := Current.Parent;
  Result := Current = nil;
end;

{ A disabled or unreachable control is not something the user can act on, so
  failing it would produce a form that cannot be submitted and gives no way to
  find out why. The original made the same choice, but tested only the control's
  own Visible flag. }
function TFormTreatment.ShouldSkip(AControl: TWinControl): Boolean;
begin
  Result := (not AControl.Enabled) or (not EffectivelyVisible(AControl));
end;

procedure TFormTreatment.ClearAll;
var
  I, J: Integer;
begin
  for I := 0 to FRules.Count - 1 do
    for J := 0 to FTreatments.Count - 1 do
      FTreatments[J].Clear(FRules[I].Control);
end;

function TFormTreatment.Validate: Boolean;
var
  I, J: Integer;
  Res: TValidationResult;
  Current: TFieldRule;
begin
  ClearAll;
  FFailures.Clear;
  FFirstInvalidControl := nil;
  Result := True;

  for I := 0 to FRules.Count - 1 do
  begin
    Current := FRules[I];

    if ShouldSkip(Current.Control) then
      Continue;

    Res := Current.Validator.Validate(ControlValue(Current.Control));
    if Res.IsValid then
      Continue;

    { Assigned with 'and', never with '=', so a later success cannot overwrite
      an earlier failure. This is the bug the original had. }
    Result := False;
    FFailures.Add(Res);

    if FFirstInvalidControl = nil then
      FFirstInvalidControl := Current.Control;

    for J := 0 to FTreatments.Count - 1 do
      FTreatments[J].Apply(Current.Control, Res);

    if FStopOnFirstFailure then
      Exit;
  end;
end;

procedure TFormTreatment.ArrangeTabOrder(AParent: TWinControl);
var
  Ordered: TList<TWinControl>;
  I: Integer;
  Child: TControl;
begin
  Ordered := TList<TWinControl>.Create;
  try
    { Every windowed child goes in, containers included, and TabStop is NOT a
      filter here. TabOrder is an index into the parent's list of ALL windowed
      children, and that list is flattened depth-first — so a container's slot
      decides when its children are reached. Renumbering from a TabStop-only
      subset pushed panels and group boxes to the end and made everything inside
      them come last, whatever their position on screen. Controls with
      TabStop=False are skipped at run time by the VCL's own navigation, so
      including them here costs nothing and keeps containers in visual order. }
    for I := 0 to AParent.ControlCount - 1 do
    begin
      Child := AParent.Controls[I];
      if Child is TWinControl then
        Ordered.Add(TWinControl(Child));
    end;

    Ordered.Sort(TComparer<TWinControl>.Construct(
      function(const A, B: TWinControl): Integer
      begin
        Result := A.Top - B.Top;
        if Result = 0 then
          Result := A.Left - B.Left;
      end));

    for I := 0 to Ordered.Count - 1 do
      Ordered[I].TabOrder := I;

    { Nested containers order their own children. }
    for I := 0 to AParent.ControlCount - 1 do
      if (AParent.Controls[I] is TWinControl) and
         (TWinControl(AParent.Controls[I]).ControlCount > 0) then
        ArrangeTabOrder(TWinControl(AParent.Controls[I]));
  finally
    Ordered.Free;
  end;
end;

end.
