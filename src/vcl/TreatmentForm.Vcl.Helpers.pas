{
  TreatmentForm — VCL layer, optional.

  Class helpers, for callers who want the terse form.

  ---------------------------------------------------------------------------
  Read this before using the unit.

  Delphi resolves at most ONE class helper per type at any point in the source.
  If your project already has a helper for TCustomEdit, adding this unit to a
  uses clause makes one of the two invisible — whichever is declared further
  away. There is no error, no warning, and no compiler diagnostic. The methods
  simply stop existing.

  That is why the original library's architecture was a problem: it put
  validation *only* on class helpers, so any project with its own TCustomEdit
  helper lost the entire feature set and had no way to tell.

  Everything here is a one-line forward to TreatmentForm.Validation, which is
  where the behaviour actually lives and which has no such constraint. Use the
  validators directly whenever a project is large enough that a helper
  collision is plausible.
  ---------------------------------------------------------------------------
}
unit TreatmentForm.Vcl.Helpers;

interface

uses
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  TreatmentForm.Types;

type
  TTreatmentEditHelper = class helper for TCustomEdit
  public
    function ValidateAsCpf: TValidationResult;
    function ValidateAsCnpj: TValidationResult;
    function ValidateAsCep: TValidationResult; overload;
    function ValidateAsCep(const AState: string): TValidationResult; overload;
    function ValidateAsEmail: TValidationResult;
    function ValidateAsDate: TValidationResult;

    { Rewrites Text with the formatted value and restores the caret to the end.
      Formatting never rejects input, so this is safe to call while typing. }
    procedure FormatAsCpfCnpj;
    procedure FormatAsCep;
    procedure FormatAsPhone;
  end;

  TTreatmentComboHelper = class helper for TCustomComboBox
  public
    { Index of the first item equal to AText, or -1. Case-insensitive.
      The original returned 0 when nothing matched, which is indistinguishable
      from a match on the first item. }
    function IndexOfText(const AText: string): Integer;
  end;

implementation

uses
  System.SysUtils,
  TreatmentForm.Validation,
  TreatmentForm.Formatting;

{ TTreatmentEditHelper }

function TTreatmentEditHelper.ValidateAsCpf: TValidationResult;
var
  V: IValidator;
begin
  V := TCpfValidator.Create;
  Result := V.Validate(Text);
end;

function TTreatmentEditHelper.ValidateAsCnpj: TValidationResult;
var
  V: IValidator;
begin
  V := TCnpjValidator.Create;
  Result := V.Validate(Text);
end;

function TTreatmentEditHelper.ValidateAsCep: TValidationResult;
var
  V: IValidator;
begin
  V := TCepValidator.Create;
  Result := V.Validate(Text);
end;

function TTreatmentEditHelper.ValidateAsCep(const AState: string): TValidationResult;
var
  V: IValidator;
begin
  V := TCepValidator.Create(AState);
  Result := V.Validate(Text);
end;

function TTreatmentEditHelper.ValidateAsEmail: TValidationResult;
var
  V: IValidator;
begin
  V := TEmailValidator.Create;
  Result := V.Validate(Text);
end;

function TTreatmentEditHelper.ValidateAsDate: TValidationResult;
var
  V: IValidator;
begin
  V := TDateValidator.Create;
  Result := V.Validate(Text);
end;

procedure TTreatmentEditHelper.FormatAsCpfCnpj;
var
  F: IFormatter;
begin
  F := TCpfCnpjFormatter.Create;
  Text := F.Format(Text);
  SelStart := Length(Text);
end;

procedure TTreatmentEditHelper.FormatAsCep;
var
  F: IFormatter;
begin
  F := TCepFormatter.Create;
  Text := F.Format(Text);
  SelStart := Length(Text);
end;

procedure TTreatmentEditHelper.FormatAsPhone;
var
  F: IFormatter;
begin
  F := TPhoneFormatter.Create;
  Text := F.Format(Text);
  SelStart := Length(Text);
end;

{ TTreatmentComboHelper }

function TTreatmentComboHelper.IndexOfText(const AText: string): Integer;
var
  I: Integer;
begin
  for I := 0 to Items.Count - 1 do
    if SameText(Items[I], AText) then
      Exit(I);
  Result := -1;
end;

end.
