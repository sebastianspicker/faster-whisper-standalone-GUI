# faster-whisper-standalone-GUI
A simple, user-friendly graphical interface for performing transcription and translation using the Faster Whisper model. This tool allows you to easily transcribe or translate audio and video files, with customizable options like beam size, patience, temperature, and more.

## Features

- **Graphical User Interface (GUI)**: Easy-to-use PowerShell-based GUI for performing transcription and translation tasks.
- **Multiple Model Support**: Choose from various models (`base`, `medium`, `large-v2`, and `xxl`) for your transcription tasks.
- **Customizable Parameters**:
  - **Device**: Select whether to run the process on `cpu` or `cuda` (GPU).
  - **Language**: Specify the transcription language using ISO-639-1 codes.
  - **Beam Size**: Adjust beam search width to optimize transcription accuracy.
  - **Best Of**: Configure the number of candidates when sampling.
  - **Patience**: Control the patience of beam search.
  - **Temperature**: Adjust sampling temperature for more deterministic or creative results.
  - **Task**: Choose between `transcribe` and `translate`.
- **Progress Bar**: Optional progress bar feature to show task progress.
- **Sound Notification**: Configurable beep sound to notify when a task is completed.
- **Save Settings**: Option to use the source directory for output.
- **Detailed Logging**: Output logs for review and debugging.
- **Cross-Platform**: Compatible with Windows (via `.exe` created from the PowerShell script).

## Description

This project is a PowerShell-based graphical tool that wraps the functionality of Faster Whisper, allowing you to transcribe or translate audio and video files with a few clicks. Faster Whisper is a faster and more efficient implementation of the Whisper transcription model.

The tool provides advanced options such as beam search width, patience, temperature, and the ability to choose specific models and devices (`cpu` or `cuda`). These options allow users to optimize performance based on their system and desired output quality.

The PowerShell script or executable must be placed in the same folder as the `faster-whisper-xxl.exe` file from the following repository:  
[Whisper Standalone Win Repository](https://github.com/Purfview/whisper-standalone-win).

## Getting Started

### Prerequisites

- **Whisper Standalone Win**: Download and set up the Whisper Standalone application from [this repository](https://github.com/Purfview/whisper-standalone-win).
- **PowerShell**: Ensure that PowerShell is available on your system (pre-installed on most Windows versions).
- **Icon File**: (Optional) If you want to use custom icons for your executable, make sure you have an `.ico` file ready.

### Installation

1. **Clone the Repository**:  
   Clone the project to your local machine:
   ```markdown
   git clone https://github.com/sebastianspicker/Faster-Whisper-Transcription-Tool.git
2. **Place Executables**:
   ```markdown
   Ensure that both run_faster_whisper_xxl.ps1 or the .exe file and faster-whisper-xxl.exe are located in the same folder for the program to run successfully.
3. **Run the Script**:
   Navigate to the project directory and run the PowerShell script directly:
   ```markdown
   cd Faster-Whisper-Transcription-Tool
   ./run_faster_whisper_xxl.ps1

## Usage

1. Launch the tool.
2. Select the audio or video file for transcription.
3. Configure the options (device, language, model, task, output directory, etc.).
4. Click Start to begin the transcription or translation process.
5. If enabled, you will hear a beep notification when the task is completed.
6. You can view progress in the PowerShell window or review output logs for any issues.

### Example
Here is an example command for running Faster Whisper manually:
Ensure that both run_faster_whisper_xxl.ps1 or the .exe file and faster-whisper-xxl.exe are located in the same folder for the program to run successfully:

```markdown faster-whisper-xxl.exe "path_to_audio.mp3" --device cuda --language en --model medium --output_dir "C:\Output" --output_format txt --task transcribe --best_of 3 --beam_size 5 --patience 1.5 --temperature 1.0 ```

## Dependencies
- PowerShell: Pre-installed on most Windows versions.
- Whisper Standalone Win: Must be installed from Whisper Standalone Win Repository: [Whisper Standalone Win Repository](https://github.com/Purfview/whisper-standalone-win)

## Known Issues
- Translate Option: In some cases, the translate option may not function as expected due to language model limitations or missing dependencies.
- GUI Freezes: While the Faster Whisper model is running, the GUI may become unresponsive until the task is completed.
- CUDA Errors: Ensure that the correct CUDA version is installed for GPU acceleration. Users may encounter errors if the CUDA setup is incomplete or misconfigured.

## Troubleshooting
- No Output: Ensure that you have specified a valid input file and output directory.
- CUDA Issues: Make sure the CUDA drivers are correctly installed and compatible with the version of Faster Whisper being used.
- Progress Bar Not Displayed: Ensure the "Print Progress" checkbox is checked to display progress in the command line.

## License
MIT License. See the `LICENSE` file for more information.
