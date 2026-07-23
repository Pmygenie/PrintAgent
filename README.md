# printer_agent

Cross-platform POS print agent for **Windows** and **Android**, built for the **MyGenie** restaurant platform. The app listens for real-time orders over Socket.IO, routes print jobs to the correct kitchen or billing station, and sends them to thermal printers via ESC/POS (or PDF on Windows USB).

---

## Table of Contents

- [Features](#features)
- [How It Works](#how-it-works)
- [Supported Printer Connections](#supported-printer-connections)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [Configuration](#configuration)
- [Socket Events](#socket-events)
- [Print Types](#print-types)
- [App Screens](#app-screens)
- [Project Structure](#project-structure)
- [Key Dependencies](#key-dependencies)
- [Platform Notes](#platform-notes)
- [Troubleshooting](#troubleshooting)

---

## Features

- **Real-time order printing** via Socket.IO (`new_order_{restaurantId}`, `manually_print_{restaurantId}`)
- **Multi-station routing** — KOTs are filtered and printed per station (e.g. KDS, BAR, PIZZA, BILL)
- **Device targeting** — only prints when `printer_agent_id` in the order payload matches this device's `empId`
- **Print types** — KOT, Bill, and Cancel KOT
- **Connection modes** — USB, LAN (network), and Bluetooth
- **Paper sizes** — 58mm and 80mm thermal rolls
- **Configurable copies** — separate KOT and bill copy counts
- **Print style editor** — customize fonts, divider styles, and per-field sizes for bills and KOTs
- **Restaurant profile sync** — pulls branding and config from the MyGenie API on startup
- **Print queue** — FIFO processing with automatic retry (up to 3 attempts)
- **Live diagnostics** — socket status, queue length, and scrolling event log on the home screen
- **Android background service** — foreground service keeps the socket alive when the app is backgrounded
- **Windows PDF printing** — optional direct PDF output to a named Windows USB printer

---

## How It Works

```
MyGenie Socket Server
        │
        ▼
WindowsSocketService  ──►  PrintQueue  ──►  PrinterManager
        │                         │                │
        │                         │                ├── LAN / WiFi driver
        │                         │                ├── USB driver (Windows / Android)
        │                         │                └── Bluetooth driver
        │                         │
        │                         └── EscPosFormatter / PdfFormatter
        │
        └── Fetches order details from REST API (manual bill/KOT prints)
```

1. On launch, the app loads saved settings from `SharedPreferences`, syncs the restaurant profile, and connects to the configured socket server.
2. When an order event arrives, the socket service validates the event, matches the device `empId` against the `printer_agent` array in the payload, filters items by station, and enqueues print jobs.
3. The print queue processes jobs one at a time, formats receipt bytes (ESC/POS or PDF), and sends them to the configured printer driver.
4. Status updates (queued, printing, done, error, retry) are streamed to the home screen live log.

---

## Supported Printer Connections

| Type | Windows | Android | Notes |
|------|---------|---------|-------|
| **USB** | Printer name (Windows spooler) | Vendor ID + Product ID | Scan available printers in Settings or Diagnostics |
| **LAN** | IP address + port (default 9100) | IP address + port | Raw socket to network thermal printer |
| **Bluetooth** | MAC address | MAC address | BLE thermal printers |

---

## Requirements

- **Flutter SDK** `>=3.3.0 <4.0.0`
- **Windows** 10 or later (for desktop builds)
- **Android** 11+ recommended (SDK-aware Bluetooth/location permissions)
- A MyGenie account with:
  - Restaurant ID
  - Employee / printer agent ID (`empId`)
  - Auth token
  - Socket server URL
  - API base URL

---

## Getting Started

### 1. Clone and install dependencies

```bash
git clone <repository-url>
cd Printer_agent
flutter pub get
```

### 2. Run on Windows

```bash
flutter run -d windows
```

### 3. Run on Android

```bash
flutter run -d <device-id>
```

On Android, the app will request Bluetooth, notification, and battery optimization permissions as needed based on the device SDK version.

### 4. Configure the agent

Open the app and go to **Settings** (gear icon). Enter your restaurant ID, employee ID, auth token, socket URL, API URL, and printer connection details. Save and the agent will reconnect automatically.

---

## Configuration

All settings are stored locally via `shared_preferences` and managed through the in-app **Settings** screen.

### Server & Identity

| Setting | Description |
|---------|-------------|
| Restaurant ID | Identifies which restaurant's socket events to listen for |
| Employee ID (`empId`) | Must match `printer_agent_id` in order payloads for this device |
| Auth Token | Bearer token for MyGenie API calls |
| Socket URL | Socket.IO server (e.g. `http://socket.mygenie.online`) |
| API URL | REST API base (e.g. `https://manage.mygenie.online`) |
| Restaurant Name | Display name on receipts |

### Print Behavior

| Setting | Description |
|---------|-------------|
| Auto Print KOT | Automatically print kitchen tickets on new orders |
| Auto Print Bill | Automatically print bills on manual bill events |
| KOT Copies | Number of KOT copies per job |
| Bill Copies | Number of bill copies per job |
| Paper Size | 58mm or 80mm |
| Stations | Kitchen stations this device handles (KDS, BAR, custom) |

### Printer Connection

| Setting | Description |
|---------|-------------|
| Connection Type | USB, LAN, or Bluetooth |
| USB Printer Name | Windows printer name (Windows only) |
| USB Vendor / Product ID | Android USB device identifiers |
| LAN IP / Port | Network printer address (default port 9100) |
| Bluetooth MAC Address | Paired BLE printer MAC |

### Windows PDF Options

| Setting | Description |
|---------|-------------|
| Use PDF Printing on Windows | Send receipts as PDF via the Windows print spooler |
| PDF for Bills Only | Restrict PDF output to bill jobs only |

---

## Socket Events

### `new_order_{restaurantId}`

Handles automatic printing for incoming and updated orders.

**Supported event types:**
- `new-order` — print all items for matched stations
- `scan-new-order` — same as new order
- `update-order` — print only `newly_added_items`
- `update-order-status` — print `cancelled_items` as Cancel KOT

**Processing gates:**
1. Event type is recognized
2. Restaurant ID matches
3. Auto print is enabled
4. `print_kot` is `"Yes"`
5. `printer_agent` array exists in the payload
6. An entry matches this device's `empId`
7. Items exist for the matched station

### `manually_print_{restaurantId}`

Triggered when staff manually requests a print from the POS.

**Payload:** `[printType, orderId, restaurantId, stations]`

- `printType` — `"kot"` or `"bill"`
- For both types, the app fetches full order data from:
  ```
  GET {apiUrl}/api/v2/vendoremployee/order-temp-details?order_id={orderId}
  ```
- KOT manual prints filter by stations in the event and match non-BILL `printer_agent` entries.
- Bill manual prints match the BILL station entry for this device's `empId`.

---

## Print Types

| Type | Description |
|------|-------------|
| **KOT** | Kitchen Order Ticket — items for a specific station |
| **Bill** | Customer receipt with totals, taxes, and payment info |
| **Cancel KOT** | Cancellation ticket for removed/cancelled items |

Receipt layout is built by `EscPosFormatter` (thermal) or `PdfFormatter` (Windows PDF mode). Font family, divider style, and per-field sizes are controlled in **Print Style Configuration**.

---

## App Screens

### Home

- Socket connection status (connected / disconnected)
- Queue length and last printed order
- Live scrolling event log with clear button
- Quick access to Settings, Print Styles, Diagnostics, and profile refresh

### Settings

- Full agent configuration (server, identity, printer, print behavior)
- USB and Bluetooth printer scanning
- LAN connection test
- Saves config and triggers reconnect

### Print Style Configuration

- Global font family (Roboto, Poppins, Montserrat) and divider style
- Per-field size and bold settings for bill and KOT sections
- Separate 58mm and 80mm size values
- Persisted locally and applied on next print

### Diagnostics

- USB / Bluetooth printer discovery
- Connection and test print
- Save discovered printer to settings
- Useful for verifying hardware before going live

---

## Project Structure

```
lib/
├── main.dart                          # App entry, permissions, socket + queue setup
├── app/
│   ├── app_settings.dart
│   ├── print_agent_controller.dart
│   └── settings_store.dart
├── core/
│   ├── background/
│   │   └── background_service.dart    # Android foreground service + socket
│   ├── config/
│   │   └── print_config.dart          # Central config (loaded from SharedPreferences)
│   ├── constants.dart/
│   │   └── print_style_constants.dart
│   ├── controller/
│   │   └── print_style_controller.dart
│   ├── models/
│   │   ├── order_item.dart
│   │   ├── print_job.dart
│   │   ├── print_models.dart
│   │   ├── print_style_config.dart
│   │   ├── printer_config.dart
│   │   └── restaurant_order.dart
│   ├── printer/
│   │   ├── escpos_formatter.dart      # ESC/POS receipt builder
│   │   ├── pdf_formatter.dart         # PDF receipt builder (Windows)
│   │   ├── printer_driver.dart
│   │   └── printer_manager.dart       # Driver selection + print dispatch
│   ├── profile/
│   │   ├── restaurant_profile_api.dart
│   │   ├── restaurant_profile_model.dart
│   │   ├── restaurant_profile_repository.dart
│   │   ├── restaurant_profile_service.dart
│   │   └── restaurant_profile_store.dart
│   ├── queue/
│   │   └── print_queue.dart           # FIFO queue with retry logic
│   ├── services/
│   │   └── print_style_service.dart
│   └── socket/
│       └── windows_socket_service.dart # Socket.IO listener (Windows + Android UI path)
├── drivers/
│   ├── android_bt_driver.dart
│   ├── bluetooth_driver.dart
│   ├── lan_driver.dart
│   ├── printer_driver.dart
│   ├── usb_driver.dart
│   ├── wifi_driver.dart
│   ├── windows_bt_driver.dart
│   └── windows_usb_driver.dart
└── ui/
    └── screens/
        ├── diagnostics_screen.dart
        ├── home_screen.dart
        ├── print_style_screen.dart
        └── settings_screen.dart
```

---

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `socket_io_client` | Real-time order events from MyGenie |
| `esc_pos_utils_plus` | ESC/POS command generation |
| `flutter_thermal_printer` | USB / BLE printer discovery and communication |
| `thermal_printer_plus` | Additional thermal printer support |
| `flutter_thermal_printer_windows` | Windows Bluetooth printing |
| `flutter_blue_plus` | Bluetooth LE |
| `flutter_background_service` | Android background socket service |
| `flutter_local_notifications` | Android foreground service notification |
| `permission_handler` | Android runtime permissions |
| `pdf` / `printing` | PDF generation and Windows direct print |
| `shared_preferences` | Local settings persistence |
| `get` | State management for print style screen |
| `http` | REST API calls (order details, restaurant profile) |
| `uuid` | Unique print job IDs |
| `system_tray` | Windows system tray (plugin registered) |

---

## Platform Notes

### Windows

- Socket and print queue run in the main isolate.
- USB printing uses the Windows printer name via `WindowsUsbDriver`.
- Optional PDF mode uses `Printing.directPrintPdf` for higher-fidelity output on USB printers.
- Built with `flutter run -d windows` or `flutter build windows`.

### Android

- A foreground background service (`flutter_background_service`) maintains the socket connection when the app is minimized.
- Permissions are requested based on Android SDK version:
  - **SDK ≤ 30** — location + bluetooth (legacy BLE scanning)
  - **SDK ≥ 31** — `bluetoothScan`, `bluetoothConnect`, notifications, battery optimization
- USB printing uses vendor ID and product ID from printer discovery.
- Bluetooth printing uses the configured MAC address.

---

## Troubleshooting

| Issue | What to check |
|-------|---------------|
| Socket shows disconnected | Verify Socket URL, network connectivity, and restaurant ID |
| Orders arrive but nothing prints | Confirm `empId` matches `printer_agent_id` in the payload; check Auto Print is on |
| Wrong station prints | Review `printer_agent` station entries and item `station` fields |
| USB printer not found (Windows) | Ensure printer name in Settings matches Windows Devices & Printers exactly |
| USB printer not found (Android) | Use Diagnostics to scan; save vendor/product ID to Settings |
| Bluetooth not discovering | Grant Bluetooth permissions; on older Android, enable location |
| Print fails with retries | Check Diagnostics screen; review live log for `ERROR` / `FAILED` messages |
| Bill missing data | Confirm auth token is valid; API URL must reach `order-temp-details` endpoint |
| Garbled receipt text | Verify paper size (58mm vs 80mm) matches the physical printer |

Use the **Diagnostics** screen to scan printers, run test prints, and save working hardware config. The **Home** screen live log shows every socket event, queue action, and error in real time.

---

## Version

Current version: **1.0.0+1** (see `pubspec.yaml`).
