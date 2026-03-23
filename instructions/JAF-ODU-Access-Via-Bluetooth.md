# How to Access ODU WEB UI on Android

This guide explains how to find the IP address of the ODU (Outdoor Unit) and access its WEB UI. It provides two methods:

1. **Primary Method**: Using **Termux** and `nmap` for fast command-line scanning.
2. **Alternative Method**: Using the **PingTools Network Utilities** app if Termux fails.

---

## 📋 Prerequisites

Ensure you have the following apps installed on your Android device:

- **J**\*\* **Field Diagnostic App**
- **J**\*\* **Home App**
- **Termux**
- (Optional) **PingTools Network Utilities**: [Download from Play Store](https://play.google.com/store/apps/details?id=ua.com.streamsoft.pingtools&hl=en_IN)

---

## 🔧 Setup Instructions

### 1. Set Up J** Apps

1. **Install J**\*\* **Apps**
   - Install **J**\*\* **Field Diagnostic App** and **J**\*\* **Home App** from the Google Play Store.

2. **Login**
   - Open **J**\*\* **Home App**.
   - Log in using your J** account credentials.

3. **Scan QR Code**
   - Open the **J**\*\* **Field Diagnostic App**.
   - Scan the QR code on the ODU.

4. **Pair & Enable Bluetooth Tethering**
   - When prompted, open **J**\*\* **Home App**.
   - Follow instructions to **pair** and **enable Bluetooth tethering**.
   - Keep both apps running in the background.

---

## 🔍 Method 1: Using Termux (Preferred)

### Step A: Launch Termux

Open **Termux** and run:
```bash
ifconfig
```

Look for a `bt-pan` interface, e.g.:
```
bt-pan: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
      inet 192.168.44.1  netmask 255.255.255.0  broadcast 192.168.44.255
```

> If `bt-pan` is not visible, make sure both J** apps are open and tethering is active.

### Step B: Run Nmap to Discover ODU IP

Run:
```bash
nmap -p 443 192.168.44.0/24
```

Example output:
```
Nmap scan report for 192.168.44.1 (gateway)
443/tcp closed https

Nmap scan report for 192.168.44.150 (ODU)
443/tcp open https
```

> The IP with **port 443 open** (like `192.168.44.150`) is your ODU's address.

---

## 📱 Method 2: Using PingTools (If Termux Fails)

1. **Install the App**
   - Get **PingTools**: [Google Play Store](https://play.google.com/store/apps/details?id=ua.com.streamsoft.pingtools&hl=en_IN)

2. **Open Subnet Scanner**
   - Tap **menu icon (☰)** > **"Subnet Scanner"**

3. **Configure IP Range**
   - Tap **settings icon (⚙️)** > **Manual Configuration**
   - Set:
     - **Start IP**: `192.168.44.0`
     - **End IP**: `192.168.44.255`
   - Tap **Save**

4. **Start Scan**
   - Tap **Scan** to begin.
   - Look for a device with **port 443 open** or labeled **ODU**

---

## 🌐 Accessing the ODU WEB UI

1. Open a browser on your phone.
2. Go to:
   ```
   https://<ODU-IP>
   ```
   Example:
   ```
   https://192.168.44.150
   ```

3. Tap **"Advanced > Proceed"** if a security warning appears.

---

## 🛠️ Troubleshooting

- Ensure Bluetooth tethering is **enabled**.
- Keep **J**\*\* **apps** running in the background.
- If Termux shows no `bt-pan`, restart Bluetooth and reconnect.
- Retry scanning via Termux or use PingTools as a fallback.

---

> ✅ Use Termux for speed and precision. Use PingTools for a user-friendly visual method.
