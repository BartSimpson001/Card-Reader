I don't have a direct file-download button available in this environment, so I can't generate an attachment link for you.

However, you can save the Markdown document directly to your project in one step using the **Copy** icon in the top-right corner of the code block from my previous message, or by running this single terminal command inside your project's root folder:

### Linux / macOS / Git Bash

```bash
cat << 'EOF' > ARCHITECTURE.md
# Contactless EMV / RuPay Card Reader — System Architecture

A security-first, 3-layer Clean Architecture combining **Flutter** (for UI and Android `IsoDep` NFC hardware transport) with **Rust** (for memory-safe EMV APDU state machine execution, BER-TLV binary parsing, and automatic RAM zeroization).

---

## 1. High-Level System Architecture

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                        FLUTTER / DART LAYER (UI)                        │
│  ┌─────────────────────┐   ┌─────────────────────────────────────────┐  │
│  │   CardScanScreen    │◄──│  SafeCardModel (Masked PAN, Name, Exp)  │  │
│  │  (FLAG_SECURE UI)   │   └────────────────────▲────────────────────┘  │
│  └──────────┬──────────┘                        │                       │
│             │ 1. Start Scan                     │ 5. Return Safe DTO    │
│             ▼                                   │                       │
│  ┌──────────────────────────────────────────────┴────────────────────┐  │
│  │                  NfcBridgeService (Dumb Pipe)                     │  │
│  │  • Polls ISO-DEP tag via flutter_nfc_kit                          │  │
│  │  • Implements Dart Callback: Future<Uint8List> transceive(apdu)   │  │
│  └──────────────────────────┬────────────────────────────────────────┘  │
└─────────────────────────────┼───────────────────────────────────────────┘
                              │ FFI Boundary (flutter_rust_bridge v2)
┌─────────────────────────────▼───────────────────────────────────────────┐
│                      RUST CORE LAYER (Security & EMV)                   │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    EmvSessionController (Async)                   │  │
│  │  Step 1: Send SELECT PPSE (2PAY.SYS.DDF01) ──► Parse AID          │  │
│  │  Step 2: Send SELECT AID (RuPay A000000524...) ──► Parse PDOL     │  │
│  │  Step 3: Build & Send GPO (80 A8) ──► Extract AFL Sectors         │  │
│  │  Step 4: Loop READ RECORD (00 B2) ──► Collect TLV Bytes           │  │
│  └──────────────────────────┬────────────────────────────────────────┘  │
│                             ▼                                           │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                  BerTlvParser & BinResolver                       │  │
│  │  • Walks 1-byte & 2-byte tags (57, 5A, 5F20, 5F24, 5F25, 5F28)    │  │
│  │  • Resolves BIN (e.g., 6074 -> Bank of India)                     │  │
│  │  • Populates RawEmvCard ──► Masks PAN ──► Zeroizes RAM on Drop    │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                              ▲
                              │ Android IsoDep (ISO 14443-4)
                    ┌─────────┴─────────┐
                    │  Physical RuPay / │
                    │   EMV NFC Card    │
                    └───────────────────┘

```

---

## 2. Core Architectural Principles

1. **Inversion of Control via FFI Callback:**
Instead of Dart orchestrating individual APDU steps, Rust drives the entire EMV state machine using an async Dart callback (`transceive_fn`). Flutter calls `scan_emv_card(transceive: FlutterNfcKit.transceive)` once and awaits a sanitized `SafeCardModel`.
2. **Zero Sensitive Data in Dart Heap:**
Raw APDU responses containing the unmasked PAN (`Tag 5A` or `Tag 57`) remain exclusively inside Rust's native memory. Dart's garbage collector never holds a copy of the full 16-digit card number.
3. **Deterministic Memory Zeroization:**
Sensitive structs (`RawEmvCard`) and intermediate APDU buffers derive `Zeroize` and `ZeroizeOnDrop` (from the `zeroize` crate), overwriting memory pages with `0x00` immediately upon conversion to `SafeCardModel`.
4. **Screen Capture Protection:**
Android `MainActivity` enforces `WindowManager.LayoutParams.FLAG_SECURE` to prevent screenshots and recents-menu thumbnails while card metadata is displayed.

---

## 3. Project Directory Structure

```text
card_reader/
├── android/
│   └── app/src/main/
│       ├── AndroidManifest.xml              # NFC permissions & hardware features
│       └── kotlin/.../MainActivity.kt       # FLAG_SECURE + foreground NFC dispatch
├── lib/
│   ├── main.dart                            # App entry & RustLib.init()
│   ├── features/
│   │   └── scanner/
│   │       ├── data/
│   │       │   └── nfc_bridge_service.dart  # Wraps flutter_nfc_kit + FFI call
│   │       └── presentation/
│   │           ├── scan_screen.dart         # NFC tap UI & state management
│   │           └── widgets/
│   │               └── virtual_card_widget.dart # Renders masked RuPay card
│   └── src/rust/                            # Auto-generated by flutter_rust_bridge
└── rust/
    ├── Cargo.toml                           # zeroize, flutter_rust_bridge, getrandom
    └── src/
        ├── lib.rs
        └── api/
            ├── mod.rs
            ├── scanner.rs                   # Public FFI entry point (scan_emv_card)
            ├── emv_engine.rs                # PPSE -> AID -> PDOL -> GPO -> AFL loop
            ├── tlv_parser.rs                # BER-TLV binary decoder (1 & 2-byte tags)
            ├── models.rs                    # RawEmvCard (Zeroize) & SafeCardModel
            └── bin_db.rs                    # Indian Bank BIN prefix lookup (BOI, etc.)

```

---

## 4. End-to-End Execution Lifecycle

| Phase | Owner | Technical Operation | Security Boundary |
| --- | --- | --- | --- |
| **1. Discovery** | Flutter (`flutter_nfc_kit`) | Polls for `NFCTagType.iso7816` (`IsoDep`). | Rejects non-payment tags (NDEF/Mifare) immediately. |
| **2. PPSE Handshake** | Rust (`emv_engine.rs`) | Sends `SELECT PPSE` (`2PAY.SYS.DDF01`) via Dart callback. | Identifies supported AIDs (e.g., RuPay `A0000005241010` / `A0000005241011`). |
| **3. PDOL & GPO** | Rust (`emv_engine.rs`) | Builds dynamic PDOL (Country `0356`, Currency `0356`, 4-byte random `9F37`) and sends `GPO` (`80 A8`). | Card validates terminal parameters and returns Application File Locator (AFL) sectors. |
| **4. Record Read** | Rust (`emv_engine.rs`) | Iterates through AFL SFI/record ranges sending `READ RECORD` (`00 B2`). | Raw TLV responses stay inside a `Zeroizing<Vec<u8>>` native buffer. |
| **5. TLV Extraction** | Rust (`tlv_parser.rs`) | Parses `57` (Track 2), `5A` (PAN), `5F20` (Name), `5F24` (Expiry), `5F25` (Valid From), `5F28` (Country). | Resolves BIN (`6074xx` -> Bank of India), masks PAN, and drops `RawEmvCard`. |
| **6. UI Render** | Flutter (`scan_screen.dart`) | Closes NFC session (`FlutterNfcKit.finish()`) and renders `SafeCardModel`. | `FLAG_SECURE` prevents OS-level screenshots of the rendered card. |

---

## 5. EMV & RuPay Data Mapping

| Card Field | EMV Tag (Hex) | Encoding / Format | RuPay / qSPARC Specifics |
| --- | --- | --- | --- |
| **Application ID (AID)** | `4F` / `84` | Binary Hex | `A0000005241010` (RuPay Debit) / `A0000005241011` (qSPARC) |
| **Card Number (PAN)** | `5A` (or inside `57`) | Compressed Numeric (BCD) | RuPay BINs begin with `60`, `65`, `81`, or `82` |
| **Valid From** | `5F25` | `YYMMDD` (BCD) | Formatted to `MM/YY` |
| **Valid Thru (Expiry)** | `5F24` | `YYMMDD` (BCD) | Formatted to `MM/YY` |
| **Cardholder Name** | `5F20` | ASCII String | Defaults to `"CARDHOLDER"` if omitted or `"/"` |
| **Application Label** | `50` | ASCII String | e.g., `"RuPay Classic"` or `"RuPay Debit"` |
| **Issuer Country Code** | `5F28` | Numeric (`0356` = India) | Flags domestic-only restriction (`"For Use Only In India"`) |
| **Service Code** | `5F30` (or inside `57`) | 3-digit Numeric | e.g., `201` / `221` (IC chip card, PIN required) |
| **Track 2 Equivalent** | `57` | `PAN` + `'D'` + `YYMM` + `ServiceCode` | Primary fallback source for PAN and Expiry |

---

## 6. Rust Data Models (`rust/src/api/models.rs`)

```rust
use zeroize::{Zeroize, ZeroizeOnDrop};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CardNetwork {
    RuPay,
    Visa,
    Mastercard,
    Unknown(String),
}

/// Internal sensitive model: Automatically wipes PAN from RAM when dropped
#[derive(Zeroize, ZeroizeOnDrop)]
pub struct RawEmvCard {
    #[zeroize(skip)]
    pub network: CardNetwork,
    #[zeroize(skip)]
    pub aid: String,
    #[zeroize(skip)]
    pub app_label: String,
    pub pan: String,
    pub cardholder_name: Option<String>,
    pub valid_from: Option<String>,
    pub expiry_date: String,
    pub service_code: Option<String>,
    pub is_domestic_only: bool,
}

/// Safe UI Data Model passed across FFI to Flutter
#[derive(Debug, Clone)]
pub struct SafeCardModel {
    pub network: CardNetwork,
    pub issuer_bank: String,
    pub app_label: String,
    pub masked_pan: String,
    pub last_four: String,
    pub cardholder_name: String,
    pub valid_from: Option<String>,
    pub expiry_date: String,
    pub is_domestic_only: bool,
    pub supports_qsparc: bool,
}

```

---

## 7. Dependencies

### Rust (`rust/Cargo.toml`)

```toml
[package]
name = "rust_lib_card_reader"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "staticlib"]

[dependencies]
flutter_rust_bridge = "=2.11.1"
zeroize = { version = "1.8", features = ["derive"] }
thiserror = "2.0"
getrandom = "0.2"

```

### Flutter (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_nfc_kit: ^3.7.0
  flutter_rust_bridge: ^2.11.1

```

### Android Permissions (`AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.NFC" />
<uses-feature android:name="android.hardware.nfc" android:required="true" />

```

EOF

```

### Windows PowerShell (Alternative)
If you are on Windows PowerShell, copy the previous code block to your clipboard and run:
```powershell
Get-Clipboard | Out-File -FilePath ARCHITECTURE.md -Encoding utf8

```