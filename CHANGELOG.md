# Changelog

This project follows [Semantic Versioning](https://semver.org/).

## [2.0.0] — unreleased

Breaking rewrite. See [MIGRATION.md](MIGRATION.md) for the full API mapping.
Version 1.0 remains available at the `v1.0` tag.

### Fixed

- **`StartTreatment` returned the wrong result in the "InAll" modes.** `Result`
  was assigned inside the loop, so the last control examined decided the answer.
  A form with an invalid field followed by a valid one returned `True` and
  submitted.
- **`TDBGrid` shadowed `Vcl.DBGrids.TDBGrid`.** Any unit that included
  `RRClass` silently resolved `TDBGrid` to the library's class instead of the
  VCL's, including forms whose `.dfm` had been streamed against the real class.
  Renamed to `TZebraDBGrid`.
- **`TDBGrid.DrawDataCell` raised on an unassigned data source.** It
  dereferenced `DataSource.DataSet` without checking `DataSource`, which fails
  on a grid placed on a form at design time. Now guarded.
- **`TTip.ShowBalloonTip` leaked a window handle on every call.** The tooltip
  window created by `CreateWindow` was never destroyed.
- **`TTip.ShowBalloonTip` could overflow its text buffer.** It allocated
  `2 * 256` bytes and passed `2 * 356` as the buffer size to
  `StringToWideChar`.
- **`TTip.ShowBalloonTip` truncated pointers on 64-bit.** `@ToolInfo` was cast
  through `Integer` when passed as an `LPARAM`.
- **`TTip.ShowBalloonTip` read uninitialised memory.** `TToolInfo` was used
  without being zeroed, leaving stack garbage in the fields it did not set.
- **`TTip.SetBorder` did not survive a repaint.** It drew onto the window DC, so
  the highlight disappeared as soon as anything invalidated the control.
- **`TComboBoxHelper.GetIndex` returned 0 for "not found".** Indistinguishable
  from a match on the first item. Its replacement returns -1.
- **`TFormHelper.TreatTabOrder` ignored nested containers.** Controls inside a
  panel or group box kept whatever tab order they had.

### Changed

- Validation rules moved off `TCustomEdit` class helpers into objects in a
  UI-free core (`TreatmentForm.Validation`), so they can be unit tested, run in
  CI, and reused outside the VCL.
- Validators return `TValidationResult` — carrying a failure reason and a
  message — instead of `Boolean`.
- Form rules are bound to controls explicitly. 1.0 inferred them from the
  control's name (`if Name.Contains('EMAIL')`), so renaming a control silently
  disabled its validation.
- `TTreatFormType`, five enum values encoding two independent decisions, is
  replaced by composable `IControlTreatment` objects plus a
  `StopOnFirstFailure` property. Combinations the enum could not express, such
  as highlighting *and* showing a balloon, now work.
- The Win32 tooltip is replaced by `TBalloonHint`, a VCL component available
  since Delphi 2009.
- Highlighting sets the control's own colour rather than painting on its DC.
- `TfObject` is now `TFadeForm`, with the fade, its duration and the
  close-on-Escape behaviour all switchable. 1.0 closed on Escape
  unconditionally and always allocated two timers.
- All identifiers, comments and documentation are in English.

### Added

- `TCompositeValidator`, to run several rules over one value.
- `TCepValidator` state-range checking covering all 27 federative units,
  including the split blocks for AM, DF and GO.
- `TCepFormatter`.
- `TDateValidator.TwoDigitYearPivot`, making the two-digit year window explicit
  and configurable rather than implicit.
- `TFormTreatment.Failures`, exposing every failure of a pass, and
  `FirstInvalidControl`.
- `TFocusTreatment`, to move the caret to the first offending field.
- A portable test suite: 122 assertions over the core, run on every push by
  GitHub Actions using Free Pascal.
- `boss.json`, for installation through Boss.

### Removed

- `RRClass.pas`, split into the units above.
- `UTips.pas`. See Fixed.
- `TFunctions` and the global `fFunctions` instance. `ProximoDiaUtil` and
  `VersaoExe` were unrelated to form treatment and are out of scope.
- The `IgnoreList` parameter. Only registered controls are validated, so there
  is nothing to exclude.

## [1.0.0] — 2017-02-13

Initial published version. Delphi 10.1 Berlin.

- `TFormHelper.StartTreatment`, validating a form's controls and signalling
  failures by balloon tip or by painting the control.
- `TFormHelper.TreatTabOrder`.
- CPF, CNPJ, CEP, e-mail and date validation on a `TCustomEdit` class helper.
- CPF/CNPJ, phone and date masks.
- `TDBGrid` with alternating row colours.
- `TfObject`, a form with fade in and fade out.
- `TComboBoxHelper.GetIndex`.
