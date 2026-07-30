object frmDemo: TfrmDemo
  Left = 0
  Top = 0
  BorderStyle = bsSingle
  BorderIcons = [biSystemMenu]
  Caption = 'TreatmentForm demo'
  ClientHeight = 320
  ClientWidth = 440
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object lblName: TLabel
    Left = 24
    Top = 30
    Width = 32
    Height = 15
    Caption = 'Name'
  end
  object lblCpf: TLabel
    Left = 24
    Top = 70
    Width = 22
    Height = 15
    Caption = 'CPF'
  end
  object lblEmail: TLabel
    Left = 24
    Top = 110
    Width = 40
    Height = 15
    Caption = 'E-mail'
  end
  object lblCep: TLabel
    Left = 24
    Top = 150
    Width = 51
    Height = 15
    Caption = 'CEP (CE)'
  end
  object lblBirthDate: TLabel
    Left = 24
    Top = 190
    Width = 55
    Height = 15
    Caption = 'Birth date'
  end
  object lblStatus: TLabel
    Left = 24
    Top = 280
    Width = 3
    Height = 15
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object edName: TEdit
    Left = 140
    Top = 27
    Width = 260
    Height = 23
    TabOrder = 0
  end
  object edCpf: TEdit
    Left = 140
    Top = 67
    Width = 260
    Height = 23
    TabOrder = 1
    OnChange = edCpfChange
  end
  object edEmail: TEdit
    Left = 140
    Top = 107
    Width = 260
    Height = 23
    TabOrder = 2
  end
  object edCep: TEdit
    Left = 140
    Top = 147
    Width = 260
    Height = 23
    TabOrder = 3
  end
  object edBirthDate: TEdit
    Left = 140
    Top = 187
    Width = 260
    Height = 23
    TabOrder = 4
  end
  object btnValidate: TButton
    Left = 140
    Top = 230
    Width = 120
    Height = 30
    Caption = 'Validate'
    Default = True
    TabOrder = 5
    OnClick = btnValidateClick
  end
  object btnFadeForm: TButton
    Left = 272
    Top = 230
    Width = 128
    Height = 30
    Caption = 'Open a TFadeForm'
    TabOrder = 6
    OnClick = btnFadeFormClick
  end
end
