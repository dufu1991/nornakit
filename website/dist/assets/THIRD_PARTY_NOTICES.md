# Third-party notices

## Pele

The native shape measurement formulas, series palette, visual constants, and
diagram rendering conventions are adapted from Pele. Diagram family names and
core syntax were checked against its public registry and tests on 2026-10-20.
The public example sources and server-rendered SVG reference snapshots in
Baselines/ and Sources/NornaExamples/Resources/official-examples.json were retrieved from pele.run
on 2026-10-20. They include examples derived from Mermaid documentation.
The Swift and C# parsers, native scene representations, and layouts run independently;
no upstream JavaScript or TypeScript is executed or bundled.
Reference: https://github.com/obsidianmd/pele

MIT License

Copyright (c) 2026 kepano

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

## Windows dependencies

The Windows implementation references Windows App SDK 2.5.1, Win2D 1.4.0,
PDFsharp 6.2.3 and System.Security.Cryptography.Pkcs 10.0.13. Their original
license documents and package metadata are copied into the `licenses`
directory of Windows Studio distributions. The self contained .NET runtime
license and notices are included there as well. These components retain
their respective upstream copyrights and licenses.

Segoe UI and Segoe Fluent Icons are supplied by Windows. NornaKit does not
redistribute Apple fonts or SF Symbols artwork. PDF export checks the
embedding permissions recorded by the selected font.
