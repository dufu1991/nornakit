using System.Runtime.InteropServices;
using Microsoft.Graphics.Canvas.Text;

namespace NornaKit.Windows;

/// <summary>Reads the actual local font file chosen by DirectWrite, including its collection face index.</summary>
internal static unsafe class NativeFontFiles
{
    private static readonly Guid ResourceWrapperId = new("5F10688D-EA55-4D55-A3B0-4DDB55C0C20A");
    // CanvasFontFace wraps IDWriteFontFaceReference, rather than IDWriteFontFace.
    private static readonly Guid FontReferenceId = new("5E7FA7CA-DDE3-424C-89F0-9FCD6FED58CD");
    private static readonly Guid LocalFontLoaderId = new("B2D9F3EC-C9FE-4A11-A2EC-D86208F7C0A2");

    public static FontFaceReference Resolve(CanvasFontFace face)
    {
        var unknown = ((WinRT.IWinRTObject)face).NativeObject.ThisPtr;
        var wrapperId = ResourceWrapperId;
        Marshal.ThrowExceptionForHR(Marshal.QueryInterface(unknown, in wrapperId, out var wrapper));
        nint nativeReference = 0, fontFile = 0, loader = 0, localLoader = 0;
        try
        {
            var referenceId = FontReferenceId;
            Check(((delegate* unmanaged[Stdcall]<nint, nint, float, Guid*, nint*, int>)Table(wrapper)[3])
                (wrapper, 0, 0, &referenceId, &nativeReference));
            Check(((delegate* unmanaged[Stdcall]<nint, nint*, int>)Table(nativeReference)[8])(nativeReference, &fontFile));
            nint key = 0;
            uint keySize = 0;
            Check(((delegate* unmanaged[Stdcall]<nint, nint*, uint*, int>)Table(fontFile)[3])(fontFile, &key, &keySize));
            Check(((delegate* unmanaged[Stdcall]<nint, nint*, int>)Table(fontFile)[4])(fontFile, &loader));
            var loaderId = LocalFontLoaderId;
            Marshal.ThrowExceptionForHR(Marshal.QueryInterface(loader, in loaderId, out localLoader));
            uint pathLength = 0;
            Check(((delegate* unmanaged[Stdcall]<nint, nint, uint, uint*, int>)Table(localLoader)[4])
                (localLoader, key, keySize, &pathLength));
            var path = new char[checked((int)pathLength + 1)];
            fixed (char* buffer = path)
                Check(((delegate* unmanaged[Stdcall]<nint, nint, uint, char*, uint, int>)Table(localLoader)[5])
                    (localLoader, key, keySize, buffer, pathLength + 1));
            var index = ((delegate* unmanaged[Stdcall]<nint, uint>)Table(nativeReference)[6])(nativeReference);
            var family = face.FamilyNames.TryGetValue("en-us", out var english) ? english : face.FamilyNames.Values.First();
            return new(family, new string(path, 0, (int)pathLength), checked((int)index),
                face.Weight.Weight >= 600, face.Style != global::Windows.UI.Text.FontStyle.Normal,
                face.Simulations.HasFlag(CanvasFontSimulations.Bold), face.Simulations.HasFlag(CanvasFontSimulations.Oblique));
        }
        finally
        {
            if (localLoader != 0) Marshal.Release(localLoader);
            if (loader != 0) Marshal.Release(loader);
            if (fontFile != 0) Marshal.Release(fontFile);
            if (nativeReference != 0) Marshal.Release(nativeReference);
            Marshal.Release(wrapper);
        }
    }

    private static nint* Table(nint pointer) => *(nint**)pointer;
    private static void Check(int result) => Marshal.ThrowExceptionForHR(result);
}
