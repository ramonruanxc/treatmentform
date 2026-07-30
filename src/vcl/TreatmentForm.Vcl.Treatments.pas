{
  TreatmentForm — VCL layer.

  How a validation failure is shown to the user.

  The original library encoded this as an enumeration:

    TTreatFormType = (ttDefault, ttPaintControlInOne, ttPaintControlInAll,
                      ttBalloonTipInOne, ttBalloonTipInAll);

  Five values covering two independent decisions — how to signal a failure,
  and whether to stop at the first one — multiplied together. Every new way of
  signalling meant another enumeration value and another branch in an already
  branching routine, and combinations like "highlight AND show a balloon" were
  simply unreachable.

  Here each way of signalling is an object. Combining them is putting two of
  them in a list, and "stop at the first failure" moves to where it belongs,
  on the object that runs the loop.
}
unit TreatmentForm.Vcl.Treatments;

interface

uses
  System.Classes,
  System.Generics.Collections,
  Vcl.Controls,
  Vcl.Graphics,
  Vcl.StdCtrls,
  TreatmentForm.Types;

type
  IControlTreatment = interface
    ['{A6D3E4B2-7C81-4F95-B0A7-3D82E15C9F44}']
    { Applied to a control that failed validation. }
    procedure Apply(AControl: TWinControl; const AResult: TValidationResult);
    { Returns the control to its untouched state. Called on every control
      before a validation pass, so a failure signalled on a previous pass does
      not linger after the user fixes the field. }
    procedure Clear(AControl: TWinControl);
  end;

  { Tints the background of the offending control.

    The original drew a red rectangle straight onto the window DC, which the
    next repaint erased — the highlight disappeared as soon as the user
    scrolled or another window overlapped. Setting the control's own colour
    survives repainting because the control draws it. }
  THighlightTreatment = class(TInterfacedObject, IControlTreatment)
  strict private
    FColor: TColor;
    FOriginalColors: TDictionary<TWinControl, TColor>;
    function TryGetColor(AControl: TWinControl; out AColor: TColor): Boolean;
    function TrySetColor(AControl: TWinControl; AColor: TColor): Boolean;
  public
    constructor Create(AColor: TColor = $00CFCFFF);
    destructor Destroy; override;
    procedure Apply(AControl: TWinControl; const AResult: TValidationResult);
    procedure Clear(AControl: TWinControl);
    property Color: TColor read FColor write FColor;
  end;

  { Shows the failure message in a balloon anchored to the control.

    Replaces a hand-rolled Win32 tooltip that leaked a window handle on every
    call, under-allocated its text buffer, and truncated pointers on 64-bit.
    TBalloonHint has shipped with the VCL since Delphi 2009 and does the same
    job without any of that. }
  TBalloonTipTreatment = class(TInterfacedObject, IControlTreatment)
  strict private
    FHint: TBalloonHint;
    FTitle: string;
  public
    constructor Create(const ATitle: string = 'Check this field');
    destructor Destroy; override;
    procedure Apply(AControl: TWinControl; const AResult: TValidationResult);
    procedure Clear(AControl: TWinControl);
    property Title: string read FTitle write FTitle;
  end;

  { Moves the caret to the offending control. Only the first failure of a pass
    takes focus; later ones would fight over it. }
  TFocusTreatment = class(TInterfacedObject, IControlTreatment)
  strict private
    FClaimed: Boolean;
  public
    procedure Apply(AControl: TWinControl; const AResult: TValidationResult);
    procedure Clear(AControl: TWinControl);
  end;

implementation

uses
  Vcl.Forms;

{ THighlightTreatment }

constructor THighlightTreatment.Create(AColor: TColor);
begin
  inherited Create;
  FColor := AColor;
  FOriginalColors := TDictionary<TWinControl, TColor>.Create;
end;

destructor THighlightTreatment.Destroy;
begin
  FOriginalColors.Free;
  inherited Destroy;
end;

{ Colour is not on TWinControl, so the supported control types are explicit.
  An unsupported control is skipped rather than raising: a form may legitimately
  contain controls this treatment cannot tint. }
function THighlightTreatment.TryGetColor(AControl: TWinControl;
  out AColor: TColor): Boolean;
begin
  Result := True;
  if AControl is TCustomEdit then
    AColor := TCustomEdit(AControl).Color
  else if AControl is TCustomComboBox then
    AColor := TCustomComboBox(AControl).Color
  else
  begin
    AColor := clWindow;
    Result := False;
  end;
end;

function THighlightTreatment.TrySetColor(AControl: TWinControl;
  AColor: TColor): Boolean;
begin
  Result := True;
  if AControl is TCustomEdit then
    TCustomEdit(AControl).Color := AColor
  else if AControl is TCustomComboBox then
    TCustomComboBox(AControl).Color := AColor
  else
    Result := False;
end;

procedure THighlightTreatment.Apply(AControl: TWinControl;
  const AResult: TValidationResult);
var
  Original: TColor;
begin
  if not FOriginalColors.ContainsKey(AControl) then
  begin
    if not TryGetColor(AControl, Original) then
      Exit;
    FOriginalColors.Add(AControl, Original);
  end;
  TrySetColor(AControl, FColor);
end;

procedure THighlightTreatment.Clear(AControl: TWinControl);
var
  Original: TColor;
begin
  if FOriginalColors.TryGetValue(AControl, Original) then
  begin
    TrySetColor(AControl, Original);
    FOriginalColors.Remove(AControl);
  end;
end;

{ TBalloonTipTreatment }

constructor TBalloonTipTreatment.Create(const ATitle: string);
begin
  inherited Create;
  FTitle := ATitle;
  FHint := TBalloonHint.Create(nil);
  FHint.ImageKind := bikWarning;
  FHint.HideAfter := 5000;
end;

destructor TBalloonTipTreatment.Destroy;
begin
  FHint.Free;
  inherited Destroy;
end;

procedure TBalloonTipTreatment.Apply(AControl: TWinControl;
  const AResult: TValidationResult);
begin
  FHint.Title := FTitle;
  { The message comes from the validator that rejected the value, so the text
    lives with the rule instead of being duplicated at every call site. }
  FHint.Description := AResult.Message;
  FHint.ShowHint(AControl);
end;

procedure TBalloonTipTreatment.Clear(AControl: TWinControl);
begin
  FHint.HideHint;
end;

{ TFocusTreatment }

procedure TFocusTreatment.Apply(AControl: TWinControl;
  const AResult: TValidationResult);
begin
  if FClaimed then
    Exit;
  if AControl.CanFocus then
  begin
    AControl.SetFocus;
    FClaimed := True;
  end;
end;

procedure TFocusTreatment.Clear(AControl: TWinControl);
begin
  { Clear runs over every control before a pass begins, which is exactly when
    the claim has to be released. }
  FClaimed := False;
end;

end.
