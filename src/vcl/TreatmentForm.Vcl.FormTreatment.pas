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

function TFormTreatment.ControlValue(AControl: TWinControl): string;
begin
  if AControl is TCustomEdit then
    Result := TCustomEdit(AControl).Text
  else if AControl is TCustomComboBox then
    Result := TCustomComboBox(AControl).Text
  else if AControl is TDateTimePicker then
    Result := DateToStr(TDateTimePicker(AControl).Date)
  else
    Result := '';
end;

{ A disabled or hidden control is not something the user can act on, so
  failing it would produce a form that cannot be submitted and gives no way to
  find out why. The original made the same choice. }
function TFormTreatment.ShouldSkip(AControl: TWinControl): Boolean;
begin
  Result := (not AControl.Enabled) or (not AControl.Visible);
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
    for I := 0 to AParent.ControlCount - 1 do
    begin
      Child := AParent.Controls[I];
      if not (Child is TWinControl) then
        Continue;
      if Child is TLabel then
        Continue;
      if not TWinControl(Child).TabStop then
        Continue;
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
