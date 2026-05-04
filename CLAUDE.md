# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Delphi 10.1 Berlin VCL library (Win32) that automates required-field validation, tab-order, and visual feedback on standard VCL forms. Source code, comments, and validation messages are in Brazilian Portuguese; validators target Brazilian formats (CPF, CNPJ, CEP, DD/MM/YYYY).

The repo is both the library and a demo app:
- `TreatmentForm.dpr` / `.dproj` / `.res` — Delphi project (program target).
- `UUseMode.pas` / `.dfm` — demo form `TfUseMode` exercising every validation/feedback mode.
- `RRClass.pas` — the library: base form, validators, helpers, custom DBGrid.
- `UTips.pas` — `TTip` helper for `TWinControl` (balloon tooltips and red border painting).

## Build and run

There is no test suite, lint config, or CI. Build with the Delphi toolchain on Windows:

- Open `TreatmentForm.dproj` in RAD Studio (Delphi 10.1 Berlin or newer) and Run, OR
- Command line: `msbuild TreatmentForm.dproj /t:Build /p:Config=Debug /p:Platform=Win32`
  Output: `Win32\Debug\TreatmentForm.exe`. Configurations: `Debug`, `Release`, `Base`. Only `Win32` is configured.

Personality is `Delphi.Personality.12`; `dproj.local` references a Windows path from the original author and is not portable — leave it alone.

## Architecture

### Validation entry point: `TFormHelper.StartTreatment` (RRClass.pas)

`StartTreatment(IgnoreList: TStringList = nil; TreatFormType: TTreatFormType = ttDefault): boolean` is the whole library's public API. It walks the form's `GetTabOrderList`, skips components named in `IgnoreList`, and dispatches by **runtime type**:

- `TEdit` — empty check; if name contains `EMAIL`, runs `IsEmail`.
- `TLabeledEdit` — empty check.
- `TMaskEdit` — branch by `EditMask` substring: `99/99/99` → date (2-digit year), `99/99/9999` → date, `99.999.999/9999-99` → CNPJ (`IsCNPJ`), `999.999.999-99` → CPF (`IsCPF`), `99.999-999` → CEP (`IsCep`), else generic empty check. **The mask string is the only signal** — adding new validations means adding a new mask branch here.
- `TComboBox` — `ItemIndex < 0`.

`TTreatFormType` controls feedback:
- `ttDefault` / `ttBalloonTipInOne` / `ttPaintControlInOne` — stop at the first invalid control (`Exit`).
- `ttBalloonTipInAll` / `ttPaintControlInAll` — keep walking and flag every invalid control.
- Balloon variants call `ShowBalloonTip`; paint variants call `SetBorder(clRed)`.

Be careful editing this method: each component-type branch repeats the same five-way `case`-on-`TreatFormType` block by hand, and the early `Exit` paths must stay aligned with the "InOne" modes or validation silently changes behavior.

### `TfObject` base form (RRClass.pas)

Forms in client apps inherit from `TfObject`, not `TForm`. The constructor sets `KeyPreview`, `AlphaBlend`, `Position := poScreenCenter`, and wires two `TTimer` instances for fade-in/fade-out animation. `DoShow` calls `TreatTabOrder` (auto-reorders TabOrder by visual top/left), then enables the fade-in timer. `KeyDown` maps **ESC → Close** and **Enter → next control** form-wide. `DoClose` busy-waits on the fade-out timer with `Application.ProcessMessages` before allowing the close. The demo `TfUseMode` inherits from `TfObject` (`UUseMode.pas:26`) so it picks up all of this; new forms should do the same.

### `TDBGrid` shadow class (RRClass.pas)

`RRClass.TDBGrid = class(Vcl.DBGrids.TDBGrid)` deliberately reuses the same identifier to override `DrawDataCell` with zebra striping (`FColorDataCell` published property) and force `ReadOnly := True` with no editing/indicator/row lines. Because it shadows the VCL class, **the unit that uses it must list `RRClass` AFTER `Vcl.DBGrids` in the `uses` clause** (see `UUseMode.pas`). The constructor is `strict private`, so it is instantiated only by the streaming system, not by user code.

### Helpers

- `TCustomEditHelper` (RRClass.pas) — adds `IsCPF`, `IsCNPJ`, `IsCEP` (with optional state code for region check), `IsEmail`, `IsDate`, plus `SetMaskCpfCnpj` / `SetMaskDate2D` / `SetMaskDate4D` / `SetMaskPhone` formatters and an internal `OnlyNumber` / `CharsInSet` helper. These extend `TCustomEdit`, so they apply to `TEdit`, `TMaskEdit`, `TLabeledEdit` alike.
- `TComboBoxHelper.GetIndex(str)` — case-insensitive item lookup; **side effect**: it walks by setting `ItemIndex` on each iteration, so the combo's selection changes during the search.
- `TTip` (UTips.pas) — class helper on `TWinControl`. `ShowBalloonTip` calls Win32 `CreateWindow(TOOLTIPS_CLASS, ...)` directly. `SetBorder` paints via `GetWindowDC` and is **not invalidation-safe** — the next repaint erases the border, which is intentional for transient feedback.
- `TFunctions` (RRClass.pas) — `VersaoExe` reads `VS_FIXEDFILEINFO` from the running EXE; `ProximoDiaUtil` returns the next Brazilian business day, computing Easter-derived holidays (Carnaval, Semana Santa, Corpus Christi) plus fixed national holidays. Global `fFunctions: TFunctions` is declared but never instantiated in this repo — callers must `Create` it.

## Conventions

- **Language**: keep new identifiers, comments, and user-facing strings in Portuguese to match the existing code. Validation messages already in `StartTreatment` follow the pattern `'Por favor, ...!'` / `'Campo obrigatório'`.
- **Scoped enums**: `{$SCOPEDENUMS ON}` is set in `UTips.pas`; reference `TIconKind.Warning` etc. with the type prefix.
- **Identifying mask types**: validation code matches `EditMask` by `Contains` on a literal pattern. New mask formats need a matching branch in `StartTreatment` AND, if applicable, a new `IsXxx` validator on `TCustomEditHelper`.
- **`uses` ordering matters** when shadowing VCL types (see `TDBGrid` note above).
- **No third-party dependencies**: an earlier `fBaseForm` external dependency was removed (commit `67fc78b`) so the demo is self-contained — don't reintroduce package references in `TreatmentForm.dproj` without reason.
