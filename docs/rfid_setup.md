# ECCD GrowthTrack RFID setup

## Hardware and wiring

Use the supplied `GrowthTrack_RFID_USB_Startup_2Beep.zip` firmware unchanged:
`GrowthTrack_RFID_USB_Startup_2Beep/GrowthTrack_RFID_USB_Startup_2Beep.ino`.

| Part | ESP32 connection |
| --- | --- |
| RC522 SS/SDA, SCK, MOSI, MISO, RST | GPIO 5, 18, 23, 19, 27 |
| RC522 power | 3V3 and GND only |
| OLED SDA, SCL | GPIO 21, 22 |
| Green LED / resistor | GPIO 25 |
| Red LED / resistor | GPIO 26 |
| Active buzzer signal / negative | GPIO 4 / GND |

The supplied sketch assumes an active-HIGH, low-current, 3.3V buzzer. For an
active-LOW module set only `BUZZER_ACTIVE_HIGH` to `false`; do not change the
GPIO mapping. Never wire the buzzer signal directly to 3V3/5V: that causes a
continuous tone regardless of software. Higher-current buzzers need a suitable
transistor driver and common ground.

## Uploading firmware

1. Extract the supplied ZIP and open `GrowthTrack_RFID_USB_Startup_2Beep.ino` in Arduino IDE.
2. Install **ESP32 by Espressif Systems**, `MFRC522`, `Adafruit SSD1306`,
   `Adafruit GFX`, and ArduinoJson **v7**.
3. Select the correct ESP32 board and COM port, then upload. Close Serial
   Monitor before Flutter opens the port.
4. On USB power/reset, verify both LEDs flash twice and the buzzer produces two
   85ms beeps separated by 110ms. OLED then shows `CONNECT`. It must be quiet
   when idle. The firmware was not compiled or hardware-tested in this project.

For isolated wiring checks, upload the ZIP's `Boot_Buzzer_LED_Test.ino` alone.
If it still buzzes continuously, power off and check polarity, module type,
ground, and that the buzzer is not powered directly from 3V3/5V.

## Flutter USB serial connection

Use either Android with an OTG data adapter **or the Web app in desktop Chrome
or Edge**. On a laptop, start the application with `flutter run -d chrome`
(or Edge), open **Attendance**, and click **Connect RFID Reader**. Chrome/Edge
will show the browser serial-port picker: select the ESP32/USB-UART COM device
and approve it. Web Serial requires `localhost` during development or HTTPS in
deployment; it does not work in Firefox, Safari, or a native Windows Flutter
window. Close Arduino Serial Monitor and any other application using the COM
port first. The app opens one shared port at **115200 baud**, sends one
`CONNECTED` and `MODE attendance` handshake, and listens for newline-delimited
JSON.

Do not run the native Flutter **Windows desktop** target for RFID: the USB
serial plugin supports Android and Chrome/Edge Web Serial, not Windows desktop.
If the panel says the port is busy, close Arduino Serial Monitor, PlatformIO,
other browser tabs for the app, and any serial-terminal application; then use
**Disconnect** followed by **Reconnect Reader**. The app waits for the ESP32
startup sequence before it sends its handshake.

Protocol examples, each terminated by `\n`:

```json
{"type":"SCAN","uid":"04A1B2C3","scanId":"esp32-1","purpose":"attendance"}
{"type":"RESULT","scanId":"esp32-1","ok":true,"code":"PRESENT","childName":"Juan","localDate":"2026-11-09","localTime":"08:30:45"}
{"type":"MANUAL_ATTENDANCE","eventId":"attendance-1","childId":"CHILD-001","childName":"Juan","status":"PRESENT","source":"manual","localDate":"2026-11-09","localTime":"08:30:45"}
```

`ACK` is correlated with `eventId`; manual-notification retries are deduplicated.
Reader failures never block a manual local attendance save.

## Daily use

### Register and verify a child card

1. Register Child normally. The profile is provisional while **Pending RFID
   Verification** is shown.
2. In the verification dialog connect the reader and scan one card.
3. Flutter normalizes the UID, reserves it in Firestore's `rfid_cards`
   registry transaction, then updates the child profile. Offline verification
   is rejected rather than falsely marked globally verified.
4. If the teacher chooses **Verify Later**, cancels, the UID is duplicated, or
   verification returns an error, the provisional child profile is discarded;
   it is not listed as a registered child. Start registration again and scan a
   valid card. For a new parent email, the parent account is also created only
   after a successful card verification. Existing profiles expose
   link/replace/unlink controls to authorized teacher/admin users.

### RFID attendance

On the Attendance page use this order: **Connect RFID Reader** → press **Open
Monday/Tuesday/etc. Attendance** for the current weekday → choose **RFID
Attendance Section** (ITED, Pre-Kinder 1, or Pre-Kinder 2) → wait two seconds
after a new connection, then scan. The same panel has **Disconnect** to close
the USB/Web Serial port cleanly. Daily attendance opens only for the real
Manila school day, so a past or future weekday cannot be selected. Only
verified cards for the selected section are accepted; another section receives
a rejection and no attendance is saved. Manual Present/Absent is also enabled
only after today's Daily Attendance is open, but remains independent of the
selected RFID section. Flutter records an accepted RFID Present locally first,
using Manila (`UTC+08:00`) school date and a `HH:mm:ss` time. It also stores
the original UTC event instant and source `rfid`; a later Firebase sync does
not replace it. Repeated UIDs are debounced for five seconds and a second
Present for the same child/date preserves the original Time In. Unknown cards
create a rejected audit event but no attendance record.

### Manual attendance and offline sync

Select a child, then use **Mark Present** or **Mark Absent**. The existing
local-first repository saves immediately with source `manual`, then syncs when
online. If connected, ESP32 receives OLED/LED feedback but no manual-attendance
buzzer tone. Offline attendance and existing children remain usable; Firebase
sync is retried by the existing app mechanisms.

## End-to-end hardware checklist

1. Power ESP32: two LED flashes + double beep, then buzzer OFF.
2. Connect Flutter once: one more double beep and OLED `CONNECTED`; PING,
   rebuilds, sync, MODE, RESULT, and manual attendance remain silent.
3. Scan a new physical card: exactly one double beep, then OLED/LED result
   after Flutter responds.
4. Verify green feedback for registered/Present, red feedback for unknown or
   duplicate card, and that transient LEDs turn off.
5. Disconnect ESP32 and verify manual Present/Absent still saves locally.
