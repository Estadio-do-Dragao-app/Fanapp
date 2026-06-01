# Fan App Interface

A premium Flutter mobile application designed for stadium fans, featuring real-time map navigation, POI discovery, and dynamic emergency evacuation routing.

---

## Getting Started

To run the application, follow the guidelines below depending on whether you are running on a **physical device** (via USB) or on a **virtual emulator**.

### 1. Prerequisites
- **Flutter SDK**: Ensure you have Flutter installed (v3.10.1+ recommended).
- **USB Debugging**: Enabled on your physical Android device.
- **Docker Compose**: Backend services running on your host machine.

### 2. Dependency Installation
Before launching, download the required packages:
```bash
flutter pub get
```

---

## Running the App

### Option A: Physical Android Device (Recommended via USB) 🔌
Due to Android security restrictions, non-rooted physical devices cannot listen directly on system ports below 1024 (like `443` for HTTPS). We bypass this with high-port reverse mapping:

1. **Set up ADB Port Forwarding**:
   Tell Android to route loopback traffic from the phone to your PC's docker services over the USB cable:
   ```bash
   adb reverse tcp:8443 tcp:443
   adb reverse tcp:8883 tcp:8883
   ```
2. **Execute the Application**:
   Launch the app pointing to the local configuration file:
   ```bash
   flutter run --dart-define-from-file=config_local.env
   ```

> [!NOTE]
> The `config_local.env` is configured to use `https://127.0.0.1:8443`. ADB routes this port to port `443` on your computer, meaning you don't have to keep looking up or updating your computer's local IP address!

---

### Option B: Android Emulator
The Android emulator runs on a virtual router. It sees `127.0.0.1` as the virtual phone itself. To connect to your PC's local server:

1. Open your `config_local.env` and change `API_BASE_URL` to point to `10.0.2.2` (without a port, since Nginx runs on default 443):
   ```env
   API_BASE_URL=https://10.0.2.2
   ```
2. Launch the application:
   ```bash
   flutter run --dart-define-from-file=config_local.env
   ```

---

### Option C: Running on Virtual Machine (VM) / Remote Host 🌐
If you want to connect the app to a remote backend environment (e.g. running on IP `10.255.32.58`):

Run the app pointing to the VM configuration file:
```bash
flutter run --dart-define-from-file=config_vm.env
```

---

## Configuration Files Reference

The app uses two target configuration files within the root of the `fan_app_interface` directory:

### `config_local.env`
Used for running against your local PC's docker-compose stack.


### `config_vm.env`
Used for connecting to the remote virtual machine environment.

---

## Running via VS Code (F5)

If you prefer using VS Code GUI, simply open your **Run and Debug** panel (`Ctrl + Shift + D` on Windows) and select either configuration from the dropdown menu:
- `Fan App (Localhost)`
- `Fan App (VM - 10.255.32.58)`
