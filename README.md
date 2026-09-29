# GOGAIT

Wearable gait-analysis system based on instrumented insoles with plastic optical fiber (POF) sensors, developed as a Bachelor's Thesis — *"Gait Analysis and Visualization Using a Smart Optical Fiber Insole for Injury Prevention"* (Telecommunications Engineering, Universidad Carlos III de Madrid).

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white)
![Bluetooth Low Energy](https://img.shields.io/badge/BLE-Bluetooth%20Low%20Energy-0082FC?style=flat&logo=bluetooth&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-Auth-FFCA28?style=flat&logo=firebase&logoColor=black)
![Seeed XIAO nRF52840](https://img.shields.io/badge/MCU-XIAO%20nRF52840-black?style=flat)

<p align="center">
  <img src="docs/screenshots_en/home_en.png" width="260" alt="Home screen">
  &nbsp;&nbsp;
  <img src="docs/screenshots_en/hero_analisis_vivo_en.png" width="260" alt="Live analysis with plantar pressure heatmap">
</p>

## Description

GOGAIT integrates two instrumented insoles (one per foot) with their acquisition and Bluetooth Low Energy transmission electronics, and this Flutter mobile app, which:

- Manages user profiles and the individual calibration of each insole.
- Receives plantar pressure readings over BLE in real time.
- Generates dynamic heatmaps of the pressure distribution.
- Computes biomechanical metrics: Balance, Impact, Fatigue Index, Performance Score, Stride Ratio, and Strike Index.
- Keeps a session history and lets you export the data as CSV.

<table align="center">
  <tr>
    <td align="center"><img src="docs/screenshots_en/guia_equilibrio_en.png" width="180" alt="Metrics guide: Balance explanation"></td>
    <td align="center"><img src="docs/screenshots_en/bluetooth_en.png" width="180" alt="Bluetooth connection with the insole"></td>
    <td align="center"><img src="docs/screenshots_en/calibracion_en.png" width="180" alt="Guided calibration of the insole"></td>
    <td align="center"><img src="docs/screenshots_en/historial_en.png" width="180" alt="Activity history"></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots_en/resumen_sesion_en.png" width="180" alt="Session summary"></td>
    <td align="center"><img src="docs/screenshots_en/detalles_actividad_en.png" width="180" alt="Activity details"></td>
    <td align="center"><img src="docs/screenshots_en/quick_metrics_en.png" width="180" alt="Quick metrics / trend across sessions"></td>
    <td align="center"><img src="docs/screenshots_en/perfil_en.png" width="180" alt="User profile"></td>
  </tr>
</table>

## Architecture

<p align="center">
  <img src="docs/arquitectura.png" width="800" alt="System architecture: hardware and user, mobile client, and backend">
</p>

The instrumented insoles transmit over BLE to the mobile client, which handles all the processing and keeps the history stored locally. The cloud is limited to user authentication and the map tiles used for the route; there is no dedicated backend server or remote database.

## Project structure

- `lib/main.dart` — Flutter app: UI, business logic, and local persistence.
- `firmware/` — firmware for the microcontrollers (Seeed Studio XIAO nRF52840) on each insole.

## Requirements

- Flutter SDK (stable channel).
- A physical Android device: BLE communication and GPS do not work on the emulator.
- Your own Firebase project (Authentication) — `firebase_options.dart` and credentials are not included in this repository.

## Authorship

Bárbara Cristina Hernández Bello — Telecommunications Engineering, Universidad Carlos III de Madrid (2026).

Supervisors: Alicia Fresno Hernández, Carmen Vázquez García.
