# Dossard (STM32H745 Dual-Core with Embedded AI)

## Overview
- CM4: Sensor acquisition (LM35 via ADC, MAX30100 via I2C), feature extraction.
- CM7: AI inference using ST X-CUBE-AI, inter-core communications via shared memory (D2 SRAM3) and HSEM notification.

## Project Structure
- `CM4/` Cortex-M4 application
- `CM7/` Cortex-M7 application
  - `X-CUBE-AI/App/` generated AI integration (`athlet*.c/h`)
- `Drivers/` HAL and CMSIS
- `Middlewares/ST/AI/` X-CUBE-AI runtime
- `Common/` shared boot/system code
- `docs/report/` LaTeX report (modular chapters)

## Build
- Use STM32CubeIDE 1.16+.
- Build targets:
  - `Dossard/CM4 (Debug)`
  - `Dossard/CM7 (Debug)`

Notes:
- Ensure `CM7/X-CUBE-AI/App/` is included in CM7 sources.
- AI runtime library path: `Middlewares/ST/AI/Lib`.

## Inter-Core Communication
- Shared mailbox at `0x30040000` (D2 SRAM3).
- HSEM ID 5 used for CM4→CM7 notification.
- CM4 publishes features and releases HSEM 5. CM7 reads, runs AI, and handles prediction.

## AI I/O
- Input (5 floats): `[temperature_C, SpO2_pct, heart_rate_bpm, fatigue_score, 1.0]`
- Output (1 float): prediction.

