$ErrorActionPreference = 'Stop'

BeforeAll {
    $moduleManifestPath = Join-Path -Path $PSScriptRoot -ChildPath '../Module/FasterWhisperStandaloneGui.psd1'
    Import-Module -Name $moduleManifestPath -Force -ErrorAction Stop
}

Describe 'FasterWhisperStandaloneGui config' {
    It 'returns stable default config shape' {
        $config = Get-FasterWhisperGuiDefaultConfig

        $config | Should -Not -BeNullOrEmpty
        $config.PSObject.Properties.Name | Should -Contain 'ExecutablePath'
        $config.PSObject.Properties.Name | Should -Contain 'Device'
        $config.PSObject.Properties.Name | Should -Contain 'Language'
        $config.PSObject.Properties.Name | Should -Contain 'Model'
        $config.PSObject.Properties.Name | Should -Contain 'OutputFormat'
        $config.PSObject.Properties.Name | Should -Contain 'Task'
        $config.PSObject.Properties.Name | Should -Contain 'BestOf'
        $config.PSObject.Properties.Name | Should -Contain 'BeamSize'
        $config.PSObject.Properties.Name | Should -Contain 'Patience'
        $config.PSObject.Properties.Name | Should -Contain 'Temperature'
        $config.PSObject.Properties.Name | Should -Contain 'PlayConfirmationSound'
        $config.PSObject.Properties.Name | Should -Contain 'ShowCliProgress'
        $config.PSObject.Properties.Name | Should -Contain 'UseInputDirectoryAsOutput'
    }

    It 'falls back to defaults when config is missing' {
        $defaults = Get-FasterWhisperGuiDefaultConfig
        $config = Get-FasterWhisperGuiConfig -ConfigPath (Join-Path $TestDrive 'missing.json') -DefaultConfig $defaults

        $config.ExecutablePath | Should -Be $defaults.ExecutablePath
        $config.Device | Should -Be $defaults.Device
        $config.Language | Should -Be $defaults.Language
        $config.Model | Should -Be $defaults.Model
        $config.OutputFormat | Should -Be $defaults.OutputFormat
        $config.Task | Should -Be $defaults.Task
        $config.BestOf | Should -Be $defaults.BestOf
        $config.BeamSize | Should -Be $defaults.BeamSize
        $config.Patience | Should -Be $defaults.Patience
        $config.Temperature | Should -Be $defaults.Temperature
        $config.PlayConfirmationSound | Should -Be $defaults.PlayConfirmationSound
        $config.ShowCliProgress | Should -Be $defaults.ShowCliProgress
        $config.UseInputDirectoryAsOutput | Should -Be $defaults.UseInputDirectoryAsOutput
    }

    It 'merges JSON values and preserves types' {
        $defaults = Get-FasterWhisperGuiDefaultConfig
        $configPath = Join-Path $TestDrive 'config.json'

        @'
{
  "ExecutablePath": "my-whisper.exe",
  "Device": "cuda",
  "Language": "en",
  "Model": "xxl",
  "OutputFormat": "srt",
  "Task": "translate",
  "BestOf": 7,
  "BeamSize": 9,
  "Patience": 1.25,
  "Temperature": 0.4,
  "PlayConfirmationSound": true,
  "ShowCliProgress": true,
  "UseInputDirectoryAsOutput": false
}
'@ | Set-Content -LiteralPath $configPath -Encoding utf8

        $config = Get-FasterWhisperGuiConfig -ConfigPath $configPath -DefaultConfig $defaults

        $config.ExecutablePath | Should -Be 'my-whisper.exe'
        $config.Device | Should -Be 'cuda'
        $config.Language | Should -Be 'en'
        $config.Model | Should -Be 'xxl'
        $config.OutputFormat | Should -Be 'srt'
        $config.Task | Should -Be 'translate'
        $config.BestOf | Should -BeOfType 'System.Int32'
        $config.BestOf | Should -Be 7
        $config.BeamSize | Should -BeOfType 'System.Int32'
        $config.BeamSize | Should -Be 9
        $config.Patience | Should -BeOfType 'System.Double'
        $config.Patience | Should -Be 1.25
        $config.Temperature | Should -BeOfType 'System.Double'
        $config.Temperature | Should -Be 0.4
        $config.PlayConfirmationSound | Should -BeTrue
        $config.ShowCliProgress | Should -BeTrue
        $config.UseInputDirectoryAsOutput | Should -BeFalse
    }

    It 'falls back to defaults on invalid JSON' {
        $defaults = Get-FasterWhisperGuiDefaultConfig
        $configPath = Join-Path $TestDrive 'invalid.json'

        '{' | Set-Content -LiteralPath $configPath -Encoding utf8

        $config = Get-FasterWhisperGuiConfig -ConfigPath $configPath -DefaultConfig $defaults

        $config.ExecutablePath | Should -Be $defaults.ExecutablePath
        $config.Device | Should -Be $defaults.Device
    }

    It 'normalizes case-insensitive enum values' {
        $defaults = Get-FasterWhisperGuiDefaultConfig
        $configPath = Join-Path $TestDrive 'case.json'

        @'
{
  "Device": "CUDA",
  "Model": "Large-V2",
  "OutputFormat": "VTT",
  "Task": "Translate"
}
'@ | Set-Content -LiteralPath $configPath -Encoding utf8

        $config = Get-FasterWhisperGuiConfig -ConfigPath $configPath -DefaultConfig $defaults

        $config.Device | Should -Be 'cuda'
        $config.Model | Should -Be 'large-v2'
        $config.OutputFormat | Should -Be 'vtt'
        $config.Task | Should -Be 'translate'
    }

    It 'falls back to defaults on invalid enum values' {
        $defaults = Get-FasterWhisperGuiDefaultConfig
        $configPath = Join-Path $TestDrive 'invalid-enum.json'

        @'
{
  "Device": "gpu",
  "Model": "tiny",
  "OutputFormat": "doc",
  "Task": "listen"
}
'@ | Set-Content -LiteralPath $configPath -Encoding utf8

        $config = Get-FasterWhisperGuiConfig -ConfigPath $configPath -DefaultConfig $defaults

        $config.Device | Should -Be $defaults.Device
        $config.Model | Should -Be $defaults.Model
        $config.OutputFormat | Should -Be $defaults.OutputFormat
        $config.Task | Should -Be $defaults.Task
    }
}

Describe 'FasterWhisperStandaloneGui argument list' {
    It 'returns a string array' {
        $argList = Get-FasterWhisperArgumentList `
            -InputFile 'input.mp3' `
            -Device 'cpu' `
            -Language 'en' `
            -Model 'base' `
            -OutputDirectory 'C:\out' `
            -OutputFormat 'txt' `
            -Task 'transcribe' `
            -BestOf 3 `
            -BeamSize 5 `
            -Patience '1.0' `
            -Temperature '0.0' `
            -PlayConfirmationSound $false `
            -ShowCliProgress $false

        $argList | Should -Not -BeNullOrEmpty
        @($argList | Where-Object { $_ -isnot [string] }).Count | Should -Be 0
    }

    It 'omits language argument when language is empty' {
        $argList = Get-FasterWhisperArgumentList `
            -InputFile 'input.mp3' `
            -Device 'cpu' `
            -Language '' `
            -Model 'base' `
            -OutputDirectory 'C:\out' `
            -OutputFormat 'txt' `
            -Task 'transcribe' `
            -BestOf 3 `
            -BeamSize 5 `
            -Patience '1.0' `
            -Temperature '0.0' `
            -PlayConfirmationSound $false `
            -ShowCliProgress $false

        ($argList -contains '--language') | Should -BeFalse
    }
    It 'includes language argument when language is set' {
        $argList = Get-FasterWhisperArgumentList `
            -InputFile 'input.mp3' `
            -Device 'cpu' `
            -Language 'en' `
            -Model 'base' `
            -OutputDirectory 'C:\out' `
            -OutputFormat 'txt' `
            -Task 'transcribe' `
            -BestOf 3 `
            -BeamSize 5 `
            -Patience '1.0' `
            -Temperature '0.0' `
            -PlayConfirmationSound $true `
            -ShowCliProgress $true

        $languageIndex = [Array]::IndexOf($argList, '--language')
        $languageIndex | Should -BeGreaterThan -1
        $argList[$languageIndex + 1] | Should -Be 'en'
        ($argList -contains '--beep_off') | Should -BeFalse
        ($argList -contains '--print_progress') | Should -BeTrue
    }
}

Describe 'FasterWhisperStandaloneGui output directory' {
    It 'uses input directory when configured and input exists' {
        $inputPath = Join-Path $TestDrive 'input.wav'
        Set-Content -LiteralPath $inputPath -Value 'data' -Encoding utf8

        $outputDir = Get-FasterWhisperOutputDirectory `
            -InputFile $inputPath `
            -OutputDirectory '' `
            -UseInputDirectoryAsOutput $true

        $outputDir | Should -Be (Split-Path -Path $inputPath -Parent)
    }

    It 'uses explicit output directory when provided' {
        $inputPath = Join-Path $TestDrive 'input.wav'
        Set-Content -LiteralPath $inputPath -Value 'data' -Encoding utf8

        $outputDir = Get-FasterWhisperOutputDirectory `
            -InputFile $inputPath `
            -OutputDirectory 'C:\\out' `
            -UseInputDirectoryAsOutput $false

        $outputDir | Should -Be 'C:\\out'
    }

    It 'falls back to input directory when output is blank' {
        $inputPath = Join-Path $TestDrive 'input.wav'
        Set-Content -LiteralPath $inputPath -Value 'data' -Encoding utf8

        $outputDir = Get-FasterWhisperOutputDirectory `
            -InputFile $inputPath `
            -OutputDirectory '' `
            -UseInputDirectoryAsOutput $false

        $outputDir | Should -Be (Split-Path -Path $inputPath -Parent)
    }
}

Describe 'Test-PathTraversalSafe' {
    It 'returns true for normal paths' {
        Test-PathTraversalSafe -Path 'C:\Users\me\file.mp3' | Should -BeTrue
        Test-PathTraversalSafe -Path 'D:\out' | Should -BeTrue
        Test-PathTraversalSafe -Path '/home/user/audio.wav' | Should -BeTrue
    }

    It 'returns false for path traversal' {
        Test-PathTraversalSafe -Path 'C:\Users\..\etc\file' | Should -BeFalse
        Test-PathTraversalSafe -Path 'C:\a\..\b' | Should -BeFalse
        Test-PathTraversalSafe -Path '../other/file.txt' | Should -BeFalse
    }

    It 'returns false for null or whitespace' {
        Test-PathTraversalSafe -Path '' | Should -BeFalse
        Test-PathTraversalSafe -Path '   ' | Should -BeFalse
    }
}

Describe 'Get-ConfigBoolOrDefault string booleans' {
    It 'parses string "true" and "false" correctly' {
        $defaults = Get-FasterWhisperGuiDefaultConfig
        $configPath = Join-Path $TestDrive 'bool-strings.json'
        @'
{ "PlayConfirmationSound": "true", "ShowCliProgress": "false", "UseInputDirectoryAsOutput": "false" }
'@ | Set-Content -LiteralPath $configPath -Encoding utf8

        $config = Get-FasterWhisperGuiConfig -ConfigPath $configPath -DefaultConfig $defaults

        $config.PlayConfirmationSound | Should -BeTrue
        $config.ShowCliProgress | Should -BeFalse
        $config.UseInputDirectoryAsOutput | Should -BeFalse
    }
}
