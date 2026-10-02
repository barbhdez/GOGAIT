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

### Hardware

<p align="center">
  <img src="docs/foto-plantilla-sensorizada.png" width="420" alt="Instrumented shoe with the full sensing and acquisition system mounted">
</p>
<p align="center"><i>The complete system mounted on the shoe: the POF sensor fiber routed through the insole, and the acquisition PCB (XIAO nRF52840, signal conditioning, BLE connector) and LiPo battery on the tongue.</i></p>

<p align="center">
  <img src="docs/diagrama-circuito-pof.png" width="800" alt="POF sensor circuit: optical emission, photodiode reception, signal conditioning, acquisition and BLE, autonomous power">
</p>
<p align="center"><i>The 5 stages of the sensing circuit: a 650 nm LED (IF-E97) emits light through the fiber, a photodiode (IF-D91B) receives it, an op-amp (LM2904P) conditions the signal, the XIAO nRF52840 digitizes it with its 12-bit ADC and sends it over BLE, powered by a 3.7 V / 290 mAh LiPo battery.</i></p>

<p align="center">
  <img src="docs/diagrama-conexion-electronica.png" width="800" alt="Wiring diagram of the electronic components">
</p>
<p align="center"><i>Real wiring between the LED, photodiode, resistors, op-amp and the XIAO board.</i></p>

<p align="center">
  <img src="docs/diagrama-firmware_v4.png" width="700" alt="Firmware flow diagram: setup and loop">
</p>
<p align="center"><i>Firmware structure: <code>setup()</code> initializes BLE and the sensor pins once; <code>loop()</code> samples the ADC every 10 ms and pushes the reading over BLE.</i></p>

<p align="center">
  <img src="docs/diagrama-protocolo-ble.png" width="800" alt="BLE communication protocol sequence diagram">
</p>
<p align="center"><i>Each insole exposes its own BLE service and characteristic (GATT). After scanning, connecting and enabling notifications, each board pushes a sample every 10 ms; a 3-second RSSI read acts as a connection watchdog.</i></p>

### Software

<p align="center">
  <img src="docs/diagrama-curva-m.png" width="700" alt="M-shaped ground reaction force curve during stance phase">
</p>
<p align="center"><i>The ground reaction force during stance draws an "M" shaped curve, with peaks at heel strike and propulsion — the reason GOGAIT places its two sensing zones at the heel and the metatarsal area.</i></p>

<p align="center">
  <img src="docs/diagrama-maquina-estados-fase.png" width="700" alt="State machine for gait phase detection">
</p>
<p align="center"><i>The app detects Heel Strike, Midstance, Propulsion and Swing purely in software, by comparing the pressure signal against a contact threshold and its trend, with no extra sensors.</i></p>

<p align="center">
  <img src="docs/diagrama-navegacion-pantallas_v2.png" width="650" alt="Screen navigation flow of the mobile app">
</p>
<p align="center"><i>How a user moves through the app: connect the insoles over BLE, calibrate both feet, run the activity with the live heatmap, and review it afterward from the session summary or the history.</i></p>

<p align="center">
  <img src="docs/diagrama-maquina-estados-calibracion_v2.png" width="500" alt="Calibration state machine for walking and running/trekking">
</p>
<p align="center"><i>Guided calibration sequence, with a shorter 4-step path for walking and a longer 7-step path for running/trekking, repeated for each foot.</i></p>

<p align="center">
  <img src="docs/diagrama-pipeline-datos.png" width="800" alt="Data processing pipeline: real-time stage and end-of-session postprocessing">
</p>
<p align="center"><i>Each sample goes through the real-time stage (pressure, phase, heatmap) as it arrives; the 7 metrics are only computed once, in a postprocessing stage, when the session ends.</i></p>

<p align="center">
  <img src="docs/diagrama-modelo-datos.png" width="800" alt="Data model: Usuario, SesionActividad, Calibracion_Pie, Estado_Conexion_BLE entities and their relationships">
</p>
<p align="center"><i>Local data model: a user owns a calibration per foot and a history of activity sessions; the BLE connection state is kept separately and never persisted. Everything is namespaced by email in <code>SharedPreferences</code>, so several accounts can share the same device.</i></p>

<p align="center">
  <img src="docs/diagrama-casos-de-uso_v2.png" width="700" alt="Use case diagram of the system">
</p>
<p align="center"><i>What a user can do with GOGAIT: register, pair the insoles, calibrate, run an activity, review the session history, and manage their profile.</i></p>

### Results

<p align="center">
  <img src="docs/resultado-traza-fase-s7.png" width="800" alt="Gait phase detection over a real pressure trace, session S7">
</p>
<p align="center"><i>Phase detection running on a real recorded trace (session S7, first 12 s): Swing lines up with the pressure valleys, and Heel Strike marks the sharp rise at the start of each peak.</i></p>

<p align="center">
  <img src="docs/resultado-mapa-calor-promedio_v3.png" width="600" alt="Averaged plantar pressure heatmap across 5 validated sessions">
</p>
<p align="center"><i>Heatmap averaged over the 5 validated sessions (same color scale as the app), showing a consistent forefoot-dominant loading pattern in both feet.</i></p>

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
