# Acer Services Analysis

**System:** Acer Nitro AN17-42  
**Operating system:** Windows 11 Pro 23H2, build 22631  
**BIOS:** V1.29, dated 2025-07-02  
**Analysis date:** 2026-08-29  
**Scope:** Acer-branded Windows services, their child processes, related kernel/PnP drivers, scheduled tasks, installed Acer/Nitro applications, file trust, permissions, resource use, network listeners, firewall state, and recent Service Control Manager events.

## Executive summary

The laptop has **12 Acer Windows services**. Ten are configured for automatic start and are running as `LocalSystem`; Acer Care Center and Acer Quick Access are disabled and stopped. Three related Acer kernel drivers are also running.

All 12 service executables and the active child executables inspected have valid Microsoft Windows Hardware Compatibility Publisher signatures. Their files are stored in protected `System32` or Driver Store locations, none is writable by standard users, and the services use standard Windows service permissions. No suspicious service path, unsigned active service binary, user-writable service executable, or Acer-related Service Control Manager failure was found.

The main concern is **network exposure**. Windows Firewall is disabled for Domain, Private, and Public profiles, and no third-party firewall product is registered. Three Acer-related processes accept connections on all interfaces:

- `AcerDIAgent.exe` on TCP `4449`
- `AcerPixyService.exe` on TCP `58995`
- Acer Lighting's bundled `OpenRGB.exe --server` on TCP `6742`

Local connection tests through every assigned IPv4 address, including the Wi-Fi address, succeeded for all three ports. OpenRGB also has three enabled inbound allow rules for the current executable and seven additional allow rules for older Driver Store versions. Those rules permit any protocol, port, remote address, and firewall profile.

**Overall assessment: moderate-to-high risk until host firewall protection is restored and the wildcard listeners are restricted.** There is no direct evidence in this review that the Acer software is malicious or currently compromised.

## Priority findings

| Severity | Finding | Evidence | Recommended action |
|---|---|---|---|
| **High** | No active host firewall protects Acer listeners | All Windows Firewall profiles report `Enabled=False`; Security Center reports no third-party firewall; TCP 4449, 58995, and 6742 listen on wildcard addresses and accepted tests through all local IPv4 interfaces | Enable Windows Firewall on all profiles, or install and verify an equivalent managed firewall |
| **Medium** | OpenRGB server is intentionally exposed broadly | `OpenRGB.exe --server` listens on `0.0.0.0:6742`; three current and seven stale enabled allow rules accept inbound traffic from any address on any profile and any port/protocol | Remove stale rules and restrict the current rule to TCP 6742 and trusted local addresses, or bind the server to loopback if remote RGB control is unnecessary |
| **Medium** | Two additional Acer services expose undocumented interfaces | `AcerDIAgent.exe` listens on `[::]:4449`; `AcerPixyService.exe` listens on `[::]:58995`; both were reachable using the laptop's IPv4 addresses | After enabling the firewall, block inbound access unless Acer documentation or a required feature demonstrates a need for remote access |
| **Medium** | ADES disables HTTPS certificate validation while transmitting stable device identifiers | `DataUpdate.exe` accepts every server certificate and periodically posts the ADES FUB token and full BIOS serial number to Acer HOLA | Disable ADES if this enrollment telemetry is unwanted; otherwise restrict DNS/proxy trust and do not assume HTTPS protects this request against an active local/network interceptor |
| **Low** | NitroSense adds local Electron attack surface | The running NitroSense app uses `--no-sandbox` and exposes a Chromium debugging endpoint on `127.0.0.1:9993` | Keep NitroSense current and avoid running untrusted local software; the endpoint is loopback-only |
| **Low** | Acer cloud inventory requests are locally blocked | AcerService logs show HTTPS requests for country, driver list, and warranty data failing because the Acer backend hostname is mapped to `127.0.0.1` in the hosts file | Keep the block if intentional; remove it only if Acer update/warranty features are desired and the privacy tradeoff is acceptable |
| **Informational** | Disabled services still have launch tasks | Care Center and Quick Access are disabled, while their delayed-start tasks remain enabled and return Windows error 1058 (`service disabled`) | Disable the matching tasks if those applications are intentionally retired |

## Windows service inventory

All service dependencies were empty. All services use the normal Windows service DACL: administrators can configure them, while interactive and service users receive query/start/stop-style access but not configuration ownership. No service has a user-writable binary.

| Service | State / startup | Version | Function and observations |
|---|---|---:|---|
| `AASSvc` | Running / Automatic | 1.2.2108.0 | Acer Agent Service Central. Spawns `AcerAgentService.exe` and `AcerHardwareService.exe`; supports NitroSense hardware control. |
| `AcerARTAIMMXDriverService` | Running / Automatic | 2.0.0.3034 | Helper in Acer's ART-AIMMX multimedia/camera component package. |
| `AcerARTAIMMXService` | Running / Automatic | 2.0.0.3034 | Acer ART-AIMMX service. Package contents include camera detection, media, and OpenCV components. |
| `AcerCCAgentSvis` | Stopped / Disabled | 1.5.21 | Acer Care Center driver/service component. Its scheduled launcher returns error 1058 because the service is disabled. |
| `AcerDeviceEnablingServiceV2` | Running / Automatic | 1.0.0.3016 | NitroSense privacy-consent and Acer enrollment/telemetry broker. Spawns `ADESv2BW.exe`, monitors power/display transitions, maintains a firmware-backed consent flag, and exposes loopback IPC on TCP 51779-51782. |
| `AcerDeviceInfoAgentService` | Running / Automatic | 1.1.0.5 | Device inventory agent. It is the only Acer service configured to restart after failure: two retries at 60-second intervals. |
| `AcerDIAgentSvis` | Running / Automatic | 1.5.10 | Acer Device Info service. Listens on wildcard TCP 4449. |
| `AcerEZSvc` | Running / Automatic | not embedded | Acer Experience Zone local web service. Listens only on `127.0.0.1:19443` and includes a local TLS certificate valid from 2024 to 2044. |
| `AcerLightingService` | Running / Automatic | 1.0.1050.7 | Lighting controller. Starts bundled OpenRGB 0.7.0 in server mode; OpenRGB listens on wildcard TCP 6742. |
| `AcerPixyService` | Running / Automatic | 2.0.0.3034 | Acer Pixy multimedia/camera component. Listens on wildcard TCP 58995. |
| `AcerQAAgentSvis` | Stopped / Disabled | 1.5.24 | Acer Quick Access agent. Its scheduled launcher returns error 1058 because the service is disabled. |
| `AcerServiceSvc` | Running / Automatic | wrapper 2.12.0.0 | CloudBees WinSW wrapper launching Microsoft-signed `AcerService.exe` 1.0.266.0, a Node.js-based Acer inventory/driver-support backend. |

## Hardware controlled by Acer components

The installed drivers, live processes, PnP devices, and model-specific configuration indicate that Acer's software stack can manage or monitor the following hardware on this Nitro AN17-42:

| Hardware area | Acer component | Capabilities found |
|---|---|---|
| **CPU/GPU thermal system** | `AASSvc` | Reads CPU/GPU temperatures, utilization, clock speeds, and fan RPM; selects operating profiles such as Quiet, Balanced, Performance, and Turbo |
| **NVIDIA GPU** | `AASSvc` | Discrete-GPU mode, GPU operating mode, NVIDIA Battery Boost integration, and supported GPU core/memory overclock levels |
| **Keyboard controls** | `AASSvc` | Backlight timeout, brightness keys, Windows/Menu-key lock, NitroSense key, and keyboard type/language detection |
| **Keyboard RGB** | `AcerLightingService` | Controls four lighting zones, brightness, static colors, and breathing, neon, wave, shifting, zoom, meteor, and twinkling effects |
| **Audio hardware** | `AASSvc` | Selects DTS speaker sound modes through the installed DTS audio-processing component |
| **Webcam** | `AcerARTAIMMXService`, `AcerARTAIMMXDriverService`, `AcerPixyService` | Provides Acer HD webcam processing, including background blur and eye-contact effects, through a camera Media Foundation transform |
| **Wireless radios** | `AcerAirplaneModeController` kernel driver | Handles the airplane-mode key and wireless-radio state events |
| **Battery charging** | `AcerCCAgentSvis` | Supports optimized/full charging, charging boundaries, adaptive charging, battery calibration, and battery-health functions; the service is currently disabled |
| **Powered USB ports** | `AcerQAAgentSvis` | Enables or disables USB charging while the laptop is powered off and can apply battery-level restrictions; the service is currently disabled |
| **Display** | `AcerQAAgentSvis` | Provides Acer BlueLight Shield configuration; the service is currently disabled |
| **Storage** | Care Center and the `StorPSCTL` task | Performs SSD/storage health checks and Acer storage-control functions |
| **USB-C display output** | `AASSvc` | Monitors USB-C/DisplayPort capability and connection events |

Not every installed Acer service directly controls hardware:

- `AcerDeviceInfoAgentService` and `AcerDIAgentSvis` primarily collect device and system information.
- `AcerServiceSvc` inventories drivers and applications and performs Acer driver/warranty backend queries.
- `AcerEZSvc` supplies a local backend for Acer Experience Zone.
- `AcerDeviceEnablingServiceV2` is primarily a privacy-consent, firmware-flag, and periodic Acer telemetry/update broker on this model; no evidence links it to fan, performance-profile, keyboard, or GPU-mode control.

## Acer Device Enabling Service V2 functionality assessment

`AcerDeviceEnablingServiceV2` (`ADESv2Svc.exe` 1.0.0.3016) is installed as an automatic `LocalSystem` service. It starts `ADESv2BW.exe` and is accompanied by the demand-start kernel driver `AcerDeviceEnablingServiceComponent.sys`. The package is attached as a software component to the same Acer ACPI application-base device used by several Acer packages:

```text
ACPI\VEN_1025&DEV_165F&SUBSYS_10021025
```

The subsystem ID is explicitly classified as an Acer **Nitro notebook** by the ADES extension INF. This describes package association, not proof that ADES owns every interface exposed by the ACPI device.

### Confirmed responsibilities

| Function | Evidence and behavior |
|---|---|
| **NitroSense privacy-consent synchronization** | NitroSense calls `ddsc.util.callADES(...)` when the user accepts or changes its privacy policy. The only application command identifiable in `ADESv2Svc.exe` is `X-Sense_PrivacyPolicyConsensus_ADESV2`, with JSON fields named `Function`, `Parameter`, and `status`. |
| **Persistent consent/enrollment state** | `HKLM\SOFTWARE\OEM\ADESV2` contains `Consensus=1`, an opaque `FUB=KDY40` value, and a last-update timestamp. `FUB.exe` reads and writes a UEFI variable named `AcerDeviceEnablingServiceFlag` using `GetFirmwareEnvironmentVariableW` and `SetFirmwareEnvironmentVariableW`. |
| **Periodic Acer data update** | After consent and when the saved update time is at least 30 days old, the service can launch `DataUpdate.exe`. The helper sends the ADES FUB token and full BIOS serial number to Acer HOLA and records the current time after any HTTP 200 response. |
| **Local NitroSense IPC** | `ADESv2Svc.exe` listens only on `127.0.0.1:51779-51782`. A live NitroSense process maintained an established connection to port 51779. The observed protocol uses `ADESSocket`, JSON responses, and the `ACER` framing marker. |
| **Power-state handling** | The service registers for Windows power notifications, including `GUID_MONITOR_POWER_ON`, logs `PBT_POWERSETTINGCHANGE`, detects AOAC-capable devices, and runs a separate `ADESv2BW.exe` background worker. This appears to preserve or synchronize ADES state through display-off, sleep, and modern-standby transitions. |
| **Privileged firmware/device access** | The user-mode service and `FUB.exe` use `DeviceIoControl`, and the package installs a running KMDF kernel companion. The exact IOCTL contract was not established, but the observable firmware operation is the ADES UEFI flag described above. |

### Acer HOLA request and transmitted fields

`DataUpdate.exe` is a small .NET Framework 4.5 x64 program. Its complete request format is documented below; no packet capture or real-identifier submission was required.

The destination is selected only by the existence of this marker file:

```text
C:\ProgramData\OEM\Acer Device Enabling Service V2\HOLA_UAT.ini
```

| Marker state | Destination |
|---|---|
| Absent, as on this machine | `https://hola.acer.com/?1_<TYPE>-ADESV2_V1` |
| Present | `https://holadev.acer.com/?1_<TYPE>-ADESV2_V1` |

`<TYPE>` is derived from the first two characters of the BIOS serial number. Recognized values are `DG`, `DQ`, `DT`, `NH`, `NR`, `NT`, and `NX`; every other prefix becomes `UNKNOWN`. The query string therefore exposes a broad Acer machine category and the client/protocol label `ADESV2_V1`.

The HTTP request is:

```http
POST /?1_<TYPE>-ADESV2_V1 HTTP/1.1
Host: hola.acer.com
User-Agent: holav1_1<RANDOM8><HASH10>
Content-Type: text/xml
Content-Length: <UTF-8 byte count>

"<FUB>","<BIOS_SERIAL_NUMBER>"
```

Despite the declared `text/xml` content type, the body is neither XML nor JSON. It is a two-value, CSV-like UTF-8 string with no field names or escaping.

| Wire location | Data | Source | Privacy relevance |
|---|---|---|---|
| Query `<TYPE>` | First two BIOS-serial characters if they match Acer's whitelist, otherwise `UNKNOWN` | `Win32_BIOS.SerialNumber` | Coarse device-family classification |
| Query suffix | Literal `ADESV2_V1` | Protocol label | Identifies ADES V2 protocol/client version 1 |
| Body field 1 | FUB token | `HKLM\SOFTWARE\OEM\ADESV2\FUB` | Persistent Acer device-enablement/enrollment identifier; `FUB.exe` mirrors it with UEFI state and uses disk/firmware information when creating or recovering it |
| Body field 2 | Complete BIOS serial number | WMI `Win32_BIOS.SerialNumber` | Stable, device-unique hardware identifier |
| `User-Agent` | `holav1_1`, eight random hexadecimal characters, and a ten-character checksum | Locally generated per execution | Request-family marker, random nonce, and weak integrity token |
| Transport metadata | Source IP address, request time, TLS/HTTP metadata | Inherent in HTTPS | May allow network and approximate-location correlation even though no explicit IP or location field is in the body |

The user-agent checksum is the uppercase hexadecimal encoding of the first five SHA-1 bytes of:

```text
holav1_1<RANDOM8>*holav1
```

It is not meaningful authentication: its construction and fixed suffix are client-defined, it uses non-cryptographic `System.Random`, and anyone can reproduce it. Identifier-free tests also received HTTP 200 without this user agent.

Fields **not** sent by this executable include the ADES `Consensus`, `Country`, and `Time` registry values; Windows username; MAC address; Windows product key; CPU/GPU data; fan settings; performance profile; keyboard configuration; installed applications; and general hardware inventory. `Consensus` controls whether the service launches the update, while `Time` controls its approximately 30-day schedule and is updated after success.

### HOLA endpoint behavior

Both `hola.acer.com` and `holadev.acer.com` are currently served through Google infrastructure. During inspection:

- `holadev.acer.com` resolved to `34.120.251.6`.
- `hola.acer.com` resolved to `8.233.46.223` and `2600:1901:0:fded::`.
- Neither subdomain published a CNAME, TXT, or MX record. Acer's parent DNS zone is administered through Amazon Route 53, while the endpoint addresses reverse-resolve into Google's infrastructure.
- Both presented valid, hostname-specific Google Trust Services certificates and negotiated TLS 1.3 with AES-256.
- Responses identified the server as `Google Frontend`, included Google trace headers, and advertised HTTP/3.
- Sampled GET, HEAD, OPTIONS, and zero-length POST requests to both environments returned HTTP 200 with an empty body when the POST included a content length. A POST without `Content-Length` received Google's generic HTTP 411 response.
- `/robots.txt` returned HTTP 404.
- Plain HTTP on port 80 did not currently redirect to HTTPS: the development host returned an empty connection and production reset it. Historical urlscan.io browser results indicate an HTTP-to-HTTPS redirect existed previously.
- No cookie, authentication challenge, `Allow` header, HSTS header, redirect, API documentation, CORS grant, or descriptive application error was returned over HTTPS.

The permissive empty HTTP 200 response means a client cannot tell whether its payload was validated, stored, ignored, or rejected internally. `DataUpdate.exe` makes the same mistake: it treats **any** status 200 as successful, does not read a response body, and immediately records a new last-update time. The tests did not submit a real or fabricated serial/FUB pair, so backend storage behavior remains unverified.

Public references are sparse. GitHub code search found no implementation or protocol documentation and no references to the development host. The production hostname appears in the community-maintained `ShadowWhisperer/BlockLists` “Junk” list alongside other Acer cloud hosts, but that categorization is a maintainer opinion rather than evidence of malicious behavior. Public urlscan.io records show the production host returning the same empty Google Frontend response since at least December 2024 with regularly rotated Google-managed certificates. No Acer privacy notice or technical document found during this review explains the FUB/serial submission, retention period, or backend use.

### HOLA client security and implementation observations

- **Certificate validation is disabled.** `ServicePointManager.ServerCertificateValidationCallback` unconditionally returns `true`. An active DNS, proxy, or network interceptor can present any certificate, decrypt the request, collect the BIOS serial/FUB pair, and return HTTP 200. The endpoints' legitimate certificates were valid during inspection, but the client does not enforce them.
- **Legacy TLS is explicitly enabled.** The effective protocol mask permits TLS 1.0, 1.1, and 1.2. Modern servers currently negotiate a stronger protocol with other clients, but this program is willing to downgrade when a server or interceptor offers an older enabled protocol.
- **There is no meaningful request authentication.** The user-agent checksum uses public constants and only 40 bits of SHA-1 output. It does not cover the URL or body and cannot prove that Acer software originated a submission.
- **The development switch is standard-user writable.** `C:\ProgramData\OEM\Acer Device Enabling Service V2` grants `BUILTIN\Users` write access. A non-administrator can create `HOLA_UAT.ini` and redirect subsequent ADES submissions from Acer's production HOLA host to Acer's development HOLA host. The hostname cannot be changed to an arbitrary server through this file.
- **Optional logging can expose both identifiers locally.** If either expected logging registry key is present, the program logs the full URL and body as `param:"<FUB>","<serial>"` under the same broadly accessible ProgramData directory. Logging is currently disabled and no DataUpdate log exists.
- **Retries are limited but asynchronous.** The program tries up to three times with roughly one second between attempts and a 30-second request timeout. Its mixed synchronous/asynchronous request-stream handling and shared `_send_OK` flag can create overlapping or unreliable retry behavior.
- **Success uses a failure exit code.** Even after HTTP 200, the program calls `Environment.Exit(1)`. Parent code must rely on registry time or process behavior rather than the conventional zero exit code.
- **The response is unauthenticated and semantically empty.** Because certificate checks are disabled and only status 200 matters, an interceptor can both capture the identifiers and suppress retries by returning an empty 200 response.

**HOLA assessment:** this is a narrow Acer enrollment/telemetry heartbeat rather than a broad inventory upload. Its explicit payload is limited to two stable identifiers, but one is the complete BIOS serial number and the other is a persistent firmware-associated Acer token. The privacy impact is therefore significant despite the small payload. The most important implementation defect is not the amount of data but the unconditional TLS certificate bypass.

### Features not attributable to ADES on this AN17-42

No observed ADES behavior, live connection, or package configuration found in this assessment ties ADES to:

- CPU/GPU fan mode, fan targets, or thermal telemetry
- NitroSense Quiet/Balanced/Performance/Turbo profiles
- NVIDIA GPU mode, overclocking, or Battery Boost
- keyboard RGB, keyboard timeout, or NitroSense hotkeys
- DTS audio mode
- webcam effects
- battery charge limits or calibration
- powered-off USB charging or BlueLight Shield

Those functions are implemented through `AASSvc`, `AcerGamingFunction`, Acer Lighting/OpenRGB, Care Center, Quick Access, or the separate camera/audio components documented elsewhere in this report. In particular, the working direct `AcerGamingFunction` fan/profile/keyboard controls do not use the ADES loopback service.

### Operational and privacy assessment

- **Hardware-function impact:** disabling ADES is unlikely to remove fan, performance-profile, keyboard, or GPU controls. It may stop NitroSense from propagating privacy-consent changes, maintaining the ADES UEFI flag, performing the monthly HOLA update, and handling related state across power transitions.
- **NitroSense behavior:** NitroSense actively connects to ADES, so disabling it may produce retries, missing-service logs, or degraded privacy/onboarding behavior even if core hardware controls continue working.
- **Network exposure:** all four ADES listeners are loopback-only. They are not directly reachable from other machines, unlike the wildcard Acer listeners documented in the priority findings.
- **Outbound behavior:** no active external connection from `ADESv2Svc.exe` or `ADESv2BW.exe` was present during inspection. `DataUpdate.exe` performs the HOLA submission as a short-lived child process approximately every 30 days after consent.
- **Resource use:** at inspection time, `ADESv2Svc.exe` used approximately 6.7 MB working set and 2.1 MB private memory; `ADESv2BW.exe` used approximately 8.1 MB working set and 1.5 MB private memory. Both had accumulated effectively zero CPU time.
- **Reliability:** no substantive ADES error event was found. The Application log contains provider events with empty messages when the service starts, but no corresponding crash or Service Control Manager failure.

**Assessment:** ADES V2 is optional for the currently identified hardware-control paths but is not functionless. It is best treated as an Acer consent/enrollment and lifecycle-support component. Keep it enabled if preserving complete NitroSense onboarding and vendor-support behavior is more important than eliminating periodic Acer telemetry. If it is disabled, retain `AASSvc` and the Acer Application Base driver, and specifically verify NitroSense startup, privacy settings, sleep/wake, and display-off/resume behavior.

## Additional Acer cloud endpoints

Two other Acer hostnames on this installation are mapped to loopback addresses. They belong to separate components and carry substantially different data:

| Endpoint | Local component | Request type | Main data disclosed |
|---|---|---|---|
| `backend-prd-imub2p4wyq-uc.a.run.app` | `AcerService.exe` 1.0.266.0 (`XSense-Service`) | Authenticated HTTPS GET requests | Full BIOS serial and model in URL paths; the country request also reveals the public source IP to the server |
| `device-info-prd-imub2p4wyq-uc.a.run.app` | `AcerDIAgent.exe` 1.5.10 | HTTPS POST to `/device-info` | Broad JSON hardware, driver, storage-health, network, battery, OS, locale, Acer-application, and consent inventory |

The hosts-file mappings cause both clients to connect to `127.0.0.1:443` and fail. The findings below are supported by installed-component metadata and historical logs from before or during the block; no real device identifiers were submitted during this analysis.

### AcerService / XSense backend

`AcerService.exe` is a Node.js 16.16 application packaged with `pkg`. Package metadata names the application `XSense-Service`, and the compiled application path is `C:\snapshot\XSense-Service\dist\production\index.js`. NitroSense accesses its local API at `https://localhost:15152`; AcerService then makes the external requests.

Three external routes are confirmed:

| Request | Data sent to Acer | Response purpose |
|---|---|---|
| `GET /xsense/api/getCountry2` | An `Authorization` header containing a generated JWT, normal HTTPS request metadata, and the connection's public source IP. No explicit request body was found. | Returns country and detailed public-IP geolocation/network classification used for regional behavior. |
| `GET /xsense/api/getWarranty/<BIOS_SERIAL>` | The complete BIOS serial number appears directly in the URL path, plus the authorization token and normal request headers. | Returns warranty country, expiry information, reveal/ESP flags, and a support or purchase link. |
| `GET /xsense/api/getDriverList3/<MODEL>/<BIOS_SERIAL>` | The computer model and complete BIOS serial number both appear directly in the URL path, plus the authorization token and normal request headers. | Returns model-specific driver and update information. |

These are GET requests with no identified body. Because model and serial are path components, they can be recorded not only by Acer's application but also by reverse proxies, Cloud Run request logs, monitoring systems, and any other infrastructure that logs request URLs. The JWT appears to authenticate the AcerService client; it does not conceal the path parameters.

Historical logs show successful country, warranty, and driver-list calls before blocking. Subsequent calls fail with `ECONNREFUSED 127.0.0.1:443`, confirming the loopback mapping is effective. The country response included server-derived information about the laptop's public IP; this is data Acer can infer from any direct connection even though the IP is not an explicit query field.

No additional external route was confirmed. This is a verified minimum rather than proof that no other route can exist in a different execution path or application version.

### Acer Device Info endpoint

`AcerDIAgent.exe` is a native signed application installed as `AcerDIAgentSvis`. Its upload operation sends this request:

```text
POST https://device-info-prd-imub2p4wyq-uc.a.run.app/device-info
Content-Type: application/json
User-Agent: <runtime-generated AcerDIAgent value>

<serialized DeviceInfoJSON>
```

The application also references the UAT sibling `https://device-info-uat-ycrmvsk7ia-uc.a.run.app`. Production/UAT selection is associated with `HKLM\SOFTWARE\Acer\XSense\sku`. Requests use `cpp-httplib` 0.11.2, include a `User-Agent` header, serialize the object to JSON, post it as `application/json`, and return the HTTP status code. The exact runtime user-agent text was not established, so it should not be represented as a confirmed literal.

The observed upload envelope uses the property names `isConsent`, `promotionAccepted`, `data`, and `recommendation`. The exact placement of every repeated `data` object was not established. The inventory contains the following field families:

| Category | Fields found in the outbound JSON construction |
|---|---|
| Consent and Acer recommendations | `isConsent`, `promotionAccepted`, `recommendation` |
| Product and chassis | `product`, `manufacturer`, `enclosureType`, `skuNumber`, `SNID` |
| SMBIOS and baseboard | `SMBIOS`, `baseboard`, `version`, `minorRelease`, `majorRelease`, `vendor`, `productName`, `productFamily`, `manufacturer` |
| BIOS | BIOS information collected from firmware/WMI |
| Plug-and-play devices and drivers | `className`, `devices`, `name`, `displayName`, `hardwareIDs`, `driverVersion`, `manufacturer` |
| Logical disks | `logicalDisk`, `freeSize` |
| Storage devices | `storage`, `vendorName`, `modelName`, `type`, `totalSize`, `usedSize` |
| NVMe/storage health | `availableSpare`, `availableSpareThreshold`, `currentPendingSectorCount`, `reallocatedSectorsCount`, `mediaAndDataIntegrityErrors` |
| Network | `network`, adapter `name`, `MACAddress`, `IPv4/IPv6Address` |
| Battery | `battery`, `designedCapacity`, `fullChargedCapacity`, `cycleCount` |
| Graphics and audio | `graphicsDeviceName`, `audioDeviceName` |
| Processor | CPU `name`, `modelName`, `numberOfCores` |
| Memory | `memory`, module `name`/`modelName`, `RAMSize`, `RAMType` |
| Operating system and locale | OS `name`, `version`, `buildNumber`, `bits`, `lang`, `regionISO2`, `CHID` |
| Acer application identity | `senseName`, protocol `version`, and `createTime`; recognized products include `AcerSense`, `PredatorSense`, and `NitroSense`, with protocol version `v2.0.0` used by this build |

Repeated names such as `name`, `version`, `manufacturer`, and `modelName` occur in different nested category objects. The available evidence establishes the fields and broad category structure, but not every array/object boundary or every condition that suppresses an unavailable value. The list therefore describes the information collected and serialized without claiming an unverified byte-for-byte sample body.

The application includes separate upload triggers for the periodic inventory, privacy-policy changes, and display-language changes:

- `StartDataUploadTimer`
- `OnDataUploadTimerArrived`
- `SendDIDataToServer(bool)`
- `SendPrivacyPolicyChangedPayload4ToServer(bool)`
- `OnUserDisplayLanguageChangedToServer`

Available configuration values include `UserAgree`, `DisplayLanguage`, `Users`, `12Hour`, `2Weeks`, and `1Month`. They indicate multiple scheduling/configuration modes, but the exact active interval could not be established from the current registry state. Historical logs contain 2,509 upload attempts: 50 early requests received HTTP 200 and 2,459 later requests received HTTP 503 while the hostname was blocked. Importantly, the same history repeatedly logs `User agreed: NO` immediately around upload activity. This demonstrates that the agent still attempted contact when its recorded agreement state was false; the available evidence did not establish whether every no-consent attempt contained the complete inventory or a reduced privacy-change payload.

Successful Acer responses were small JSON messages, normally `{"result":"OK"}`. Some HTTP 200 responses instead contained a backend error reporting a Google Cloud SQL Admin rate limit. That response disclosed the internal Google Cloud project `ai-xsense-prd` and Cloud SQL instance `xsense-device-info-mysql-prd`. The application log's generic `Request body` label refers to the received server body in those entries, not to a retained copy of the outbound inventory JSON.

**Privacy assessment:** the XSense backend sends a small number of highly identifying URL parameters for support features, while Device Info sends a much broader machine fingerprint and health inventory. Blocking only HOLA does not block either of these flows. Keeping the two Cloud Run host mappings prevents the observed requests, at the cost of Acer country detection, warranty lookup, driver recommendations, and Device Info/AcerSense telemetry functions.

## Trust and hardening observations

- Every inspected service and child executable reports a **valid Authenticode signature**.
- Service files are owned by `SYSTEM` or `TrustedInstaller`.
- Standard users have no write, modify, or full-control permission on any service executable.
- Service image paths are not vulnerable to unquoted-path substitution.
- All 12 services run as `LocalSystem`. This is expected for hardware-control software but increases impact if an exposed service contains a vulnerability.
- No service declares a reduced `RequiredPrivileges` list.
- Eleven of the 12 services have no explicit restart-on-failure policy.
- No matching Service Control Manager errors or crashes were found in the previous 30 days.

## Network analysis

| Process / service | Bind | Exposure | Notes |
|---|---|---|---|
| `AcerDIAgent.exe` / `AcerDIAgentSvis` | `[::]:4449` | All interfaces | Active local client connection was also present |
| `AcerPixyService.exe` / `AcerPixyService` | `[::]:58995` | All interfaces | Undocumented Acer media/camera service interface |
| `OpenRGB.exe --server` / child of `AcerLightingService` | `0.0.0.0:6742` | All interfaces | OpenRGB SDK server; broad enabled inbound firewall rules exist |
| `AcerEZService.exe` / `AcerEZSvc` | `127.0.0.1:19443` | Loopback only | Local HTTPS-style service |
| `ADESv2Svc.exe` / `AcerDeviceEnablingServiceV2` | `127.0.0.1:51779-51782` | Loopback only | NitroSense privacy/ADES IPC; NitroSense was actively connected to port 51779 |
| `NitroSense.exe` | `127.0.0.1:9993` | Loopback only | Chromium remote-debugging endpoint |

The Windows Base Filtering Engine and Firewall service are running, but policy disables the firewall for every profile. Therefore, the configured OpenRGB block/allow rules currently provide no protection. The Wi-Fi network is categorized as **Public**, which would normally receive the strongest Windows Firewall restrictions.

## Resource footprint

The ten service processes plus their Acer child processes use approximately:

- **110.2 MB working set**
- **166.7 MB private memory**

CPU consumption since the last boot was low. The larger user-session footprint comes from NitroSense's Electron/Chromium processes and is separate from the Windows service total.

The most significant service-side processes were:

| Process | Working set | Private memory |
|---|---:|---:|
| `AcerService.exe` | 24.3 MB | 34.8 MB |
| `AcerHardwareService.exe` | 11.6 MB | 26.7 MB |
| `AcerEZService.exe` | 7.3 MB | 18.9 MB |
| `AcerServiceWrapper.exe` | 2.6 MB | 18.6 MB |
| `AcerDIAgent.exe` | 16.6 MB | 9.7 MB |

## Related drivers

Three Acer kernel drivers are running and use demand/manual start:

| Driver service | Purpose |
|---|---|
| `AcerAirplaneModeController` | Airplane-mode hardware/controller integration |
| `AcerApplicationBaseDriver_Device` | Base interface used by Acer applications |
| `AcerDeviceEnablingServiceComponentService` | KMDF companion for ADES privileged device/firmware access; the confirmed persistent operation is its UEFI-backed ADES flag |

Nine Acer PnP software components are installed: Agent Service, Airplane Mode Controller, Application Base, Care Center, two Device Info components, Pixy Service, Quick Access, and ADES v2. All report signed drivers.

## Related applications and scheduled tasks

Installed NitroSense Win32 support packages are version **5.0.1452**. AppX packages include NitroSense 5.0.1452.0, Acer QuickPanel 2.0.201.0, Acer Registration 2.0.3044.0, and Acer Purified Voice Console registrations.

| Scheduled task | State | Last result | Assessment |
|---|---|---:|---|
| `AcerDeviceInfoAgentServiceDelayStart` | Ready | 1058 | Old result indicating the service was disabled at that run; service is now automatic and running |
| `DelayStartCareCenter2` | Ready | 1058 | Expected failure while Care Center service remains disabled |
| `DelayStartDeviceInfo2` | Ready | 0 | Successful |
| `DelayStartQuickAccess2` | Ready | 1058 | Expected failure while Quick Access service remains disabled |
| `NitroSenseLauncher` | Disabled | 0 | No current concern |
| `StorPSCTL` | Running | 0x41301 | Acer SSD/storage utility; task status means it is currently running |

Task executables are signed and not writable by standard users. `StorPSCTL` runs at highest privilege for the `Everyone` group, but its executable is in protected `Program Files` storage and grants users read/execute access only.

## Privacy and operational behavior

`AcerService.exe` maintains local hardware, driver, provisioned-app, and current-user app inventories under `C:\ProgramData\OEM\AcerService`. It sends authenticated country, warranty, and driver-list GET requests to an Acer Google Cloud Run backend. Warranty and driver requests place the complete BIOS serial directly in the URL path; the driver request also includes the computer model.

Separately, ADES stores consent and update state under `HKLM\SOFTWARE\OEM\ADESV2`. Its periodic `DataUpdate.exe` helper sends the complete BIOS serial number and persistent FUB token to Acer HOLA. The current registry state records `Consensus=1` and a last update on 2026-08-04. No ADES outbound connection was active during inspection.

`AcerDIAgent.exe` separately posts a broad JSON hardware and software inventory to Acer's Device Info Cloud Run endpoint. Historical activity shows connection attempts even when its own log reported that the user had not agreed, although the exact payload variant used for each no-consent attempt was not established.

Both Cloud Run hostnames are explicitly mapped to `127.0.0.1` in the Windows hosts file, so current requests fail locally. This appears to be intentional blocking rather than an Acer service defect. It prevents or degrades Acer driver discovery, warranty lookup, regional recommendations, and Device Info telemetry.

The directory contains 250 log/inventory files totaling about 1.65 MB. This is not a meaningful disk-space issue, although the service retains a long history of small logs.

## Recommended remediation

1. **Enable Windows Firewall for Domain, Private, and Public profiles.** This is the highest-priority action. Verify that another security product is not expected to manage the firewall first; none was registered during this analysis.
2. **Restrict OpenRGB.** If remote lighting control is not required, remove its inbound allow rules or restrict them to loopback. Otherwise, allow only TCP 6742 from explicitly trusted local addresses. Remove the seven stale allow rules for superseded Driver Store paths.
3. **Block Acer Device Info and Pixy inbound traffic by default.** Add explicit inbound block rules for TCP 4449 and 58995 unless a documented required feature stops working.
4. **Update through the model-specific Acer support channel and Microsoft Update.** Pay particular attention to the NitroSense/Predator service package that bundles OpenRGB 0.7.0 and to the ART-AIMMX/Pixy package.
5. **Keep unused features disabled.** Care Center and Quick Access are already disabled. Disable their corresponding delayed-start tasks as well if that state is intentional.
6. **Review each hosts-file block independently.** Leave the XSense backend blocked if Acer country, driver, and warranty features are not wanted. Leave Device Info blocked if the broad hardware/health inventory is not wanted. Remove only the specific entry required for a feature after accepting its distinct data exchange.

## File hashes

SHA-256 values provide a baseline for later integrity comparisons.

| Service | Executable SHA-256 |
|---|---|
| `AASSvc` | `5BB16FA594878F7014BC61E2A7B2A6C6B640F0CE0E6A1BF1E18E440C3DD4C9F3` |
| `AcerARTAIMMXDriverService` | `780DCC680D0B6651D7528DCA3D038364AEB43872B7A61A0C83637D59700C2667` |
| `AcerARTAIMMXService` | `C5F19ECA5152AA98E158DB67FE7C2658767A494E35029BAA608602359F891A4D` |
| `AcerCCAgentSvis` | `33DC36902E885D249F6BF69FC25BB98ADE3678E701D1AF46990C1C6B723ECBED` |
| `AcerDeviceEnablingServiceV2` | `0DEF1053DE2502FCC7C7221635EECBFDD968C18F4EFAF32AEBD1CAE51262B2DA` |
| `AcerDeviceInfoAgentService` | `B80AD0FE9EB3560C126FC33D70D36F6BC83DEE232971FD3129910981334FB230` |
| `AcerDIAgentSvis` | `BA173BF81B5D149E5EFEF371D6AC71BA087B89B7658D966E73D8B85585AA25F0` |
| `AcerEZSvc` | `C792E844D1FB4A845A5BB44491F522D2AF58BB23E57F8C21AE3CA589FE773727` |
| `AcerLightingService` | `4F07DA2FD8AE5A9562254FB33F7434C83DD2A724AC2880EBFC82ED43EC18B66D` |
| `AcerPixyService` | `08C8D1C4500A0A15A08A39CA7212C968554E11DB0A500716C37FE2E8C204203C` |
| `AcerQAAgentSvis` | `E7BC1695ABF4700712B40D23F7642FBEF4AC9C8EA3BF13AEF65D9062AC0CAC4B` |
| `AcerServiceSvc` | `FEDC7B37AD5E91AFC2E2F96F4E338F7F2DA3A696949F4480F78BBB94E647146C` |

## Evidence and limitations

This review used Windows service, process, driver, task, signature, ACL, event-log, socket, firewall, package and file metadata; historical Acer application logs; passive DNS/TLS/HTTP inspection; and application-to-service connection ownership. It did not fuzz service protocols, submit device identifiers to Acer, verify backend storage, capture a byte-for-byte Device Info request body, capture local ADES IPC payloads, or compare hashes against an external malware database. Valid signatures and protected paths establish software provenance and reduce common persistence risks, but they do not prove that a component is free of vulnerabilities.
