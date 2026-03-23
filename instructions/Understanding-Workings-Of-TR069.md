⚠️ Note: This is a general guide which explains how tr069 works, might contain wrong info and we are not liable for anything you do with it. 

---
### IT IS PURELY FOR EDUCATIONAL PURPOSES. YOU ARE REPONSIBLE FOR YOUR DOINGS. WE WONT BE HELD LIABLE FOR ANY DAMAGES DONE TO YOUR DEVICES.

---
## Note from Author: 
*This guide will along the way will contain mostly explanations and sometimes codes. Don't ask for help if you cant read. Be your own guide and Use the search engines bestowed upon you to learn more about these things. Don't expect to be spoon fed. 
If you manage to do something cool with this info don't feel shy to show us, would love to hear about your hacks🥂* :)

---

 
### A Brief Overview: IDU Firmware Updates & TR-069

Let’s keep it concise.

Yes, firmware behaviour varies slightly across models—each may use different binaries for updating.  
**Key point**: check your IDU and inspect the `/tmp` directory. If you find files named `jioCwmpLog` there, you're in luck.

These files log **unencrypted commands and URLs** sent over-the-air to the IDU during firmware updates.  
We leverage these logs to capture relevant data whenever the ACS pushes an update.

## ⚠️ Keep in Mind

- You **cannot force** the ACS to push firmware unless it has already been uploaded and made available for download by the CPE.
- You **can** periodically pull the log to a separate location.
- Optionally, implement a script to **drop the ACS connection** by modifying firewall rules as soon as a firmware URL prefix like: http://fota.slv.kai.jiophone.net/5G/ is detected in the log.

There are experimental approaches too—such as injecting a modified `libssl` to decrypt HTTPS traffic.  
While the modified `libssl` is ready, this method is overkill for now :)

---

## ODU Side (Outdoor Unit)

The ODU communicates with the ACS similarly and stores unencrypted TR-069/CWMP logs on its filesystem.  
However, **without shell access**—which is restricted on most ODUs—this data isn't easily accessible.

For those with **root shell access**, ACS links can be extracted.

#### 🔍 Log Files (Located in `/data`)

- `tr69_stack.log`  
- `tr69data.log`  

📁 These files contain **plaintext TR-069 communication data**.

#### 🔄 Manually Restart TR-069 on the ODU

1. Find the PID of the TR-069 process:

 ```sh
 ps aux | grep -e tr
```

2. Kill it 
```shell
 kill -9 <PID>
```

3. Restart Tr069 client
```shell
/usr/bin/tr69_ctrl /usr/bin/tr69c
```

### Understanding the URL Formats

- `/5G/` — constant segment; appears in all URLs.
- `/UDI/` — stands for **IDU** firmware (Indoor Unit).
- `/UDO/` — stands for **ODU** firmware (Outdoor Unit).
- `/DIN520/` — indicates the ODU variant; "520" typically matches the beginning of the ODU model number.
- `/A1402_32_S/` — firmware version:
  - `2_32_S` is the actual version.
  - `A140` encodes part of the model in reverse — e.g., `A140` → `041A`, which hints at model suffix like `52041`.
- `/Sxxxxxxx.img` — the actual firmware file:
  - File name usually starts with `S`, followed by a seemingly random string (likely hashed or auto-generated).




## TR-069 Communication – IDU

### 🛠️ Server Configuration

- **ACS Server**: `https://acs.oss.jio.com:8443/ftacs-digest/ACS`
  - To find your ACS server, check:
    - `/etc/cpestate-default.xml` – (in SSH-enabled IDU)
    - `/rom/etc/cpestate-default.xml` – (alternate path)
    - `/etc/keep/config.save` – (from firmware backup)
- **Communication Port**: `7547` (TCP)
- **Authentication**: HTTPS with Digest Authentication

---

### 🔁 Initial Connection

- Device sends **periodic inform messages** every 24 hours.
- Connection settings stored in:
  - `/etc/cpestate-default.xml`
- **TR-069 client binary**:
  - `/sbin/cwmpc`
- Includes key device info:
  - Model, serial number, firmware version
- Secured via **HTTPS Digest Authentication**

---

### 📦 Device Information Sent

> Collected from various system files:

- **Model name**: `/tmp/deviceModel`
- **Manufacturer**: `/tmp/mfgName`
- **Serial number**: `/tmp/deviceSerial`
- **Hardware version**: `/tmp/hwVersion`
- **Software version**: (current firmware version)
- **OUI**: First 6 characters of MAC address

---

## 📥 Firmware Download Process

### 1. 🔔 Update Notification

- ACS server detects available firmware and sends a `Download` RPC.
- RPC contains:
  - Firmware download URL
  - Signature file URL
  - Auth credentials (if required)
  - File size information
- All communication is encrypted via **HTTPS**

---

### 2. ⬇️ Download Phase

- TR-069 client (`/sbin/cwmpc`) receives the `Download` RPC.
- Downloads:
  - Firmware to `/tmp/firmware.img`
  - Signature to `/tmp/firmware.sig`
- **These filenames are mandatory** for the upgrade process.
- Files are verified for:
  - **Integrity**
  - **Completeness**

---

### 3. ✅ Validation Phase

```sh
/sbin/jioSysMethods.sh validate /tmp/firmware.img /tmp/firmware.sig <TRIGGER_SOURCE>
```

- Valid trigger sources:
    - `GUI`: For web interface-triggered upgrades
    - `ACS`: For TR-069 / Auto Configuration Server-triggered upgrades
    - `PLATFORM`: For system/platform-triggered upgrades
    - `PLUME`: For Plume mesh-triggered upgrades


- Performs:
	- File existence and name checks
    - Cryptographic signature validation
    - Device compatibility verification

### 4. 🔐Cryptographic Verification 

- Uses `/usr/bin/jcrypt upgrade` for verification 
- Takes 3 parameters: 
	- Device model (from `/tmp/deviceModel`) 
	- Signature file path 
	- Firmware image path 
- Verification is model-specific 
- Uses asymmetric cryptography: 
	- Private key held by FW-maker 
	- Public key embedded in device 
	- Signature is created with private key 
	- Verification is done with public key

### 5.🗃️ File needed to be present during a fw upgrade
- Firmware image: `/tmp/firmware.img` 
- Signature file: `/tmp/firmware.sig`
- Device model: `/tmp/deviceModel` 
- Hardware version: `/tmp/hwVersion` 
- Manufacturer: `/tmp/mfgName` 
- Serial number: `/tmp/deviceSerial`