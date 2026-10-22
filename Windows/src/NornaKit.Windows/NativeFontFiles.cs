using System.Runtime.InteropServices;
using Microsoft.Graphics.Canvas.Text;

namespace NornaKit.Windows;

/// <summary>Reads the actual local font file chosen by DirectWrite, including its collection face index.</summary>
internal static unsafe class NativeFontFiles
{
    private static readonly Guid ResourceWrapperId = new("5F10688D-EA55-4D55-A3B0-4DDB55C0C20A");
    private static readonly Guid FontFaceId = new("5F49804D-7024-4D43-BFA9-D25984F53849");
    private static readonly Guid LocalFontLoaderId = new("B2D9F3EC-C9FE-4A11-A2EC-D86208F7C0A2");

    public static FontFaceReference Resolve(CanvasFontFace face)
    {
        var unknown = ((WinRT.IWinRTObject)face).NativeObject.ThisPtr;
        var wrapperId = ResourceWrapperId;
        Marshal.ThrowExceptionForHR(Marshal.QueryInterface(unknown, in wrapperId, out var wrapper));
        nint nativeFace = 0, fontFile = 0, loader = 0, localLoader = 0;
        try
        {
            var faceId = FontFaceId;
            Check(((delegate* unmanaged[Stdcall]<nint, nint, float, Guid*, nint*, int>)Table(wrapper)[3])
                (wrapper, 0, 0, &faceId, &nativeFace));
            uint count = 0;
            var getFiles = (delegate* unmanaged[Stdcall]<nint, uint*, nint*, int>)Table(nativeFace)[4];
            Check(getFiles(nativeFace, &count, null));
            if (count != 1) throw new DiagramRenderException("The selected font must have one local font file.", "export-font");
            Check(getFiles(nativeFace, &count, &fontFile));
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
            var index = ((delegate* unmanaged[Stdcall]<nint, uint>)Table(nativeFace)[5])(nativeFace);
            var family = face.FamilyNames.TryGetValue("en-us", out var english) ? english : face.FamilyNames.Values.First();
            return new(family, new string(path, 0, (int)pathLength), checked((int)index),
                face.Weight.Weight >= 600, face.Style != global::Windows.UI.Text.FontStyle.Normal);
        }
        finally
        {
            if (localLoader != 0) Marshal.Release(localLoader);
            if (loader != 0) Marshal.Release(loader);
            if (fontFile != 0) Marshal.Release(fontFile);
            if (nativeFace != 0) Marshal.Release(nativeFace);
            Marshal.Release(wrapper);
        }
    }

    private static nint* Table(nint pointer) => *(nint**)pointer;
    private static void Check(int result) => Marshal.ThrowExceptionForHR(result);
}
