# Stock Acer Service Privacy

This document summarizes confirmed outbound communications by stock Acer software found on the inspected laptop. It describes what the installed clients are capable of sending; it does not establish how Acer or its infrastructure providers retain, combine, or use the data after receipt.

## Confirmed External Communications

| Stock component | Communication |
|:---|:---|
| Acer Device Enabling Service V2 (`AcerDeviceEnablingServiceV2` / `DataUpdate.exe`) | **Destination:** `https://hola.acer.com/?1_<TYPE>-ADESV2_V1`<br>**Trigger:** After recorded consent, when the saved update time is at least 30 days old.<br>**Sends:** Persistent ADES FUB enrollment token, complete BIOS serial number, coarse machine type derived from the serial prefix, generated HOLA user-agent, and normal HTTPS metadata. |
| Acer Device Enabling Service V2, development mode | **Destination:** `https://holadev.acer.com/?1_<TYPE>-ADESV2_V1`<br>**Trigger:** Same operation as above when `C:\ProgramData\OEM\Acer Device Enabling Service V2\HOLA_UAT.ini` exists.<br>**Sends:** The same fields as the production HOLA request. |
| AcerService / XSense (`AcerServiceSvc` launching `AcerService.exe`) | **Destination:** `https://backend-prd-imub2p4wyq-uc.a.run.app/xsense/api/getCountry2`<br>**Trigger:** Country or regional lookup requested by Acer software.<br>**Sends:** Generated authorization JWT and normal request metadata. The server can observe the public source IP; no explicit request body was identified. |
| AcerService / XSense | **Destination:** `https://backend-prd-imub2p4wyq-uc.a.run.app/xsense/api/getWarranty/<BIOS_SERIAL>`<br>**Trigger:** Warranty lookup requested by Acer software.<br>**Sends:** Complete BIOS serial in the URL path, authorization JWT, and normal HTTPS request metadata. |
| AcerService / XSense | **Destination:** `https://backend-prd-imub2p4wyq-uc.a.run.app/xsense/api/getDriverList3/<MODEL>/<BIOS_SERIAL>`<br>**Trigger:** Driver or update lookup requested by Acer software.<br>**Sends:** Computer model and complete BIOS serial in the URL path, authorization JWT, and normal HTTPS request metadata. |
| Acer Device Info Agent (`AcerDIAgentSvis` / `AcerDIAgent.exe`) | **Destination:** `https://device-info-prd-imub2p4wyq-uc.a.run.app/device-info`<br>**Trigger:** Periodic inventory, privacy-policy changes, and display-language changes.<br>**Sends:** The JSON inventory described below. |

The XSense and Device Info production endpoints are hosted on Google Cloud Run. On the inspected machine, both production hostnames were mapped to `127.0.0.1`, so current requests failed locally. Historical logs confirmed successful requests before the block.

## Acer Device Info Payload

The documented `AcerDIAgent.exe` JSON payload can include these categories:

| Category | Examples of transmitted fields |
|---|---|
| Consent and recommendations | `isConsent`, `promotionAccepted`, `recommendation` |
| Product identity | Product, manufacturer, enclosure type, SKU, SNID, SMBIOS, baseboard, and BIOS information |
| Devices and drivers | PnP class, device name/display name, hardware IDs, driver version, and manufacturer |
| Storage | Logical-disk free space; storage vendor, model, type, total/used size; NVMe spare, pending/reallocated sectors, and media/data-integrity errors |
| Network | Adapter name, MAC address, IPv4 address, and IPv6 address |
| Battery | Designed capacity, full-charge capacity, and cycle count |
| Processor and memory | CPU name/model/core count; memory module name/model/type/size |
| Graphics and audio | Graphics-device and audio-device names |
| Windows | OS name, version, build, architecture, language, region, and CHID hardware identifier |
| Acer application | AcerSense/NitroSense/PredatorSense identity, protocol version, and creation time |

The exact object/array placement and conditions for every optional value were not fully established. Historical logs showed upload attempts while the agent logged `User agreed: NO`; the available evidence could not determine whether those attempts carried the full inventory or a reduced consent-change payload.

`AcerDIAgent.exe` also references the UAT endpoint `https://device-info-uat-ycrmvsk7ia-uc.a.run.app`. Its presence is confirmed, but active use was not observed. Production/UAT selection is associated with `HKLM\SOFTWARE\Acer\XSense\sku`.

## HOLA Request Details

The HOLA body is a two-field UTF-8 string despite being labeled `text/xml`:

```text
"<FUB>","<BIOS_SERIAL_NUMBER>"
```

This executable does **not** send general hardware inventory, installed applications, usernames, MAC addresses, fan settings, keyboard settings, or performance profiles. Those categories belong to other components, principally AcerDIAgent.

`DataUpdate.exe` disables HTTPS certificate validation and permits TLS 1.0, 1.1, and 1.2. Consequently, its FUB/BIOS-serial request is vulnerable to interception by an active DNS, proxy, or network attacker even though the URL uses HTTPS. It treats any HTTP 200 response as success and does not inspect a response body.

## Local-Only Communication

These observed endpoints are local IPC and do not, by themselves, send data to Acer over the internet:

| Component | Local endpoint | Purpose |
|---|---|---|
| AcerService / XSense | `https://127.0.0.1:15152` | Local API used by NitroSense; AcerService may then make the external XSense requests listed above |
| Acer Device Enabling Service V2 | `127.0.0.1:51779-51782` | NitroSense consent and ADES lifecycle communication |
| NitroSense | `wss://localhost:15150/mqtt` and related local service ports | Communication between the NitroSense UI and local Acer components |
| Acer Experience Zone | `https://127.0.0.1:19443` | Local Acer Experience Zone backend |

The custom `AcerControlService` in this repository is also local-only. It listens on `127.0.0.1:46934` and contains no cloud endpoint or outbound telemetry implementation.

## Windows Hosts File

To block the identified external endpoints on Windows, add these entries to `C:\Windows\System32\drivers\etc\hosts` from an administrator account:

```text
127.0.0.1 backend-prd-imub2p4wyq-uc.a.run.app
127.0.0.1 device-info-prd-imub2p4wyq-uc.a.run.app
127.0.0.1 hola.acer.com
127.0.0.1 holadev.acer.com
127.0.0.1 firestore.googleapis.com
127.0.0.1 www.planet9.gg
```

**Caution:**

- `firestore.googleapis.com` is a shared Google service. Blocking it system-wide may prevent other applications and websites that use Google Cloud Firestore from working correctly.
- `www.planet9.gg` may support products and services that call `planet9.gg`

## Scope and Evidence

- Confirmed routes are a verified minimum for the installed versions. Conditional application paths mean this is not proof that no other stock Acer version or feature can contact additional endpoints.
- URLs are not presented as active communications unless historical execution evidence or repeatable request behavior supported them.
- No real device identifiers were submitted during this analysis.
- Acer's backend retention periods, sharing practices, account correlation, and deletion behavior were not established.

Primary evidence and its limitations are documented in `acer_analysis.md`.