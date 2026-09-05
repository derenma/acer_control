# Project and Third-Party Licenses

This document records the license for original project work and the open-source components directly used to build, test, run, or interoperate with this project. Third-party copyrights remain with their respective owners.

## Project License

Except for the exclusions below, original source code, PowerShell scripts, tests, and documentation authored for this project are licensed under the MIT License.

Copyright (c) 2026 Matt Deren

This grant does not cover:

- Acer or Microsoft software, firmware, drivers, services, documentation, names, or brand assets.
- NuGet packages, .NET framework/runtime files, Python, setuptools, PowerShell, OpenRGB, or other third-party components.
- Generated files under `bin/`, `obj/`, or `artifacts/`.

See [MANUFACTURER.md](MANUFACTURER.md) for manufacturer and product-name attribution.

## Open-Source Component Inventory

Versions are taken from the current project manifests. Build-tool versions may vary where the project specifies a range.

| Component | Version or scope | Role | License | Copyright or project owner |
|---|---|---|---|---|
| .NET Runtime and base class libraries | .NET 10 | Runtime bundled by self-contained publish | MIT plus licenses in the .NET third-party notices | .NET Foundation and Contributors; additional upstream owners |
| ASP.NET Core / `Microsoft.AspNetCore.App` | .NET 10 | HTTP API and hosting framework | MIT plus upstream third-party notices | .NET Foundation and Contributors |
| `Microsoft.Extensions.Hosting.WindowsServices` | 10.0.4 | Windows Service hosting | MIT | .NET Foundation and Contributors |
| `System.Management` | 10.0.4 | WMI access | MIT | .NET Foundation and Contributors |
| `Microsoft.AspNetCore.Mvc.Testing` | 10.0.4 | Integration testing only | MIT | .NET Foundation and Contributors |
| `Microsoft.NET.Test.Sdk` | 17.14.1 | Test platform only | MIT | Microsoft Corporation and contributors |
| `coverlet.collector` | 6.0.4 | Test coverage only | MIT | Copyright (c) 2018 Toni Solarin-Sodara and contributors |
| `xunit` | 2.9.3 | Unit testing only | Apache-2.0 | xUnit.net project authors and contributors |
| `xunit.runner.visualstudio` | 3.1.4 | Test runner only | Apache-2.0 | xUnit.net project authors and contributors |
| Python | 3.10 or newer | Optional external client runtime | PSF-2.0 and bundled third-party licenses | Python Software Foundation and other listed contributors |
| setuptools | 68 or newer | Python package build backend only | MIT | Python Packaging Authority/setuptools contributors |
| PowerShell 7 | Optional | Script host and build shell | MIT | Microsoft Corporation and PowerShell contributors |
| OpenRGB | Acer-bundled 0.7 observed | External RGB server used by `acer-keyboard-led.ps1`; not redistributed by this project | GPL-2.0 | OpenRGB contributors; Adam Honse is identified in the upstream license notice |

The Python client declares no third-party runtime package dependencies.

## Distribution Notes

The service is published as a self-contained .NET application, so a published artifact includes .NET runtime and framework files. Preserve the notices applicable to the exact SDK and runtime used for each publish. The installed .NET SDK provides `ThirdPartyNotices.txt` at the root of its installation; the corresponding upstream notices are also available from:

- [.NET Runtime license](https://github.com/dotnet/runtime/blob/main/LICENSE.TXT)
- [.NET Runtime third-party notices](https://github.com/dotnet/runtime/blob/main/THIRD-PARTY-NOTICES.TXT)
- [ASP.NET Core license](https://github.com/dotnet/aspnetcore/blob/main/LICENSE.txt)
- [ASP.NET Core third-party notices](https://github.com/dotnet/aspnetcore/blob/main/THIRD-PARTY-NOTICES.txt)

OpenRGB is installed and launched by Acer software. This repository does not contain or distribute OpenRGB binaries or source code; the PowerShell keyboard client communicates with its documented network protocol. Its complete license is the [GNU General Public License version 2](https://github.com/CalcProgrammer1/OpenRGB/blob/release_0.7/LICENSE).

Python, setuptools, and PowerShell are external tools and are not redistributed by this repository. Their complete upstream terms are available at:

- [Python 3 license](https://docs.python.org/3/license.html)
- [setuptools license](https://github.com/pypa/setuptools/blob/main/LICENSE)
- [PowerShell license](https://github.com/PowerShell/PowerShell/blob/master/LICENSE.txt)

Windows PowerShell 5.1, Windows, Acer drivers, Acer services, and Acer applications are proprietary components and are therefore not open-source entries in this document.

## MIT License

The following text applies to the project-authored work and to third-party components identified as MIT-licensed under their respective copyright notices.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Apache License 2.0

The following text applies to `xunit` and `xunit.runner.visualstudio` under their respective copyright notices.

```text
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship, whether in Source or
      Object form, made available under the License, as indicated by a
      copyright notice that is included in or attached to the work
      (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean any work of authorship, including
      the original version of the Work and any modifications or additions
      to that Work or Derivative Works thereof, that is intentionally
      submitted to Licensor for inclusion in the Work by the copyright owner
      or by an individual or Legal Entity authorized to submit on behalf of
      the copyright owner. For the purposes of this definition, "submitted"
      means any form of electronic, verbal, or written communication sent
      to the Licensor or its representatives, including but not limited to
      communication on electronic mailing lists, source code control systems,
      and issue tracking systems that are managed by, or on behalf of, the
      Licensor for the purpose of discussing and improving the Work, but
      excluding communication that is conspicuously marked or otherwise
      designated in writing by the copyright owner as "Not a Contribution."

      "Contributor" shall mean Licensor and any individual or Legal Entity
      on behalf of whom a Contribution has been received by Licensor and
      subsequently incorporated within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by combination of their Contribution(s)
      with the Work to which such Contribution(s) was submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or
          Derivative Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, then any Derivative Works that You distribute must
          include a readable copy of the attribution notices contained
          within such NOTICE file, excluding those notices that do not
          pertain to any part of the Derivative Works, in at least one
          of the following places: within a NOTICE text file distributed
          as part of the Derivative Works; within the Source form or
          documentation, if provided along with the Derivative Works; or,
          within a display generated by the Derivative Works, if and
          wherever such third-party notices normally appear. The contents
          of the NOTICE file are for informational purposes only and
          do not modify the License. You may add Your own attribution
          notices within Derivative Works that You distribute, alongside
          or as an addendum to the NOTICE text from the Work, provided
          that such additional attribution notices cannot be construed
          as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional or different license terms and conditions
      for use, reproduction, or distribution of Your modifications, or
      for any such Derivative Works as a whole, provided Your use,
      reproduction, and distribution of the Work otherwise complies with
      the conditions stated in this License.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any warranties or conditions
      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A
      PARTICULAR PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or consequential damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (including but not limited to damages for loss of goodwill,
      work stoppage, computer failure or malfunction, or any and all
      other commercial damages or losses), even if such Contributor
      has been advised of the possibility of such damages.

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may act only
      on Your own behalf and on Your sole responsibility, not on behalf
      of any other Contributor, and only if You agree to indemnify,
      defend, and hold each Contributor harmless for any liability
      incurred by, or claims asserted against, such Contributor by reason
      of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work.

      To apply the Apache License to your work, attach the following
      boilerplate notice, with the fields enclosed by brackets "[]"
      replaced with your own identifying information. (Don't include
      the brackets!) The text should be enclosed in the appropriate
      comment syntax for the file format. We also recommend that a
      file or class name and description of purpose be included on the
      same "printed page" as the copyright notice for easier
      identification within third-party archives.

   Copyright [yyyy] [name of copyright owner]

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
```
