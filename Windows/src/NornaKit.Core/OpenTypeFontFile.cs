using System.Buffers.Binary;

namespace NornaKit;

/// <summary>Extracts a standalone SFNT face from a system TrueType collection for PDF embedding.</summary>
public static class OpenTypeFontFile
{
    public static byte[] ExtractFace(ReadOnlySpan<byte> source, int faceIndex = 0)
    {
        if (source.Length < 12 || faceIndex < 0) throw new InvalidDataException("Invalid OpenType font header.");
        var collection = U32(source, 0) == 0x74746366;
        var faceOffset = 0;
        if (collection)
        {
            var count = U32(source, 8);
            if ((uint)faceIndex >= count || 12L + count * 4 > source.Length)
                throw new InvalidDataException("Invalid font collection face index.");
            faceOffset = checked((int)U32(source, 12 + faceIndex * 4));
        }
        else if (faceIndex != 0) throw new InvalidDataException("A standalone font has only one face.");
        if (faceOffset < 0 || faceOffset > source.Length - 12) throw new InvalidDataException("Invalid font face offset.");
        var tableCount = U16(source, faceOffset + 4);
        var directoryLength = checked(12 + tableCount * 16);
        if (directoryLength > source.Length - faceOffset) throw new InvalidDataException("Truncated font table directory.");
        var length = directoryLength;
        for (var index = 0; index < tableCount; index++)
        {
            var entry = faceOffset + 12 + index * 16;
            var offset = U32(source, entry + 8);
            var size = U32(source, entry + 12);
            if ((ulong)offset + size > (ulong)source.Length) throw new InvalidDataException("Truncated font table.");
            length = checked(length + Align(checked((int)size)));
        }
        var result = new byte[length];
        source.Slice(faceOffset, directoryLength).CopyTo(result);
        var destination = directoryLength;
        var headOffset = -1;
        for (var index = 0; index < tableCount; index++)
        {
            var entry = 12 + index * 16;
            var sourceEntry = faceOffset + entry;
            var size = checked((int)U32(source, sourceEntry + 12));
            source.Slice(checked((int)U32(source, sourceEntry + 8)), size).CopyTo(result.AsSpan(destination));
            BinaryPrimitives.WriteUInt32BigEndian(result.AsSpan(entry + 8), (uint)destination);
            if (U32(source, sourceEntry) == 0x68656164)
            {
                if (size < 12) throw new InvalidDataException("Truncated font head table.");
                headOffset = destination;
                result.AsSpan(headOffset + 8, 4).Clear();
            }
            destination += Align(size);
        }
        if (headOffset < 0) throw new InvalidDataException("The font has no head table.");
        uint checksum = 0;
        for (var offset = 0; offset < result.Length; offset += 4)
        {
            checksum = unchecked(checksum + BinaryPrimitives.ReadUInt32BigEndian(result.AsSpan(offset, 4)));
        }
        BinaryPrimitives.WriteUInt32BigEndian(result.AsSpan(headOffset + 8), unchecked(0xB1B0AFBA - checksum));
        return result;
    }

    private static int Align(int value) => checked((value + 3) & ~3);
    private static uint U32(ReadOnlySpan<byte> bytes, int offset) => BinaryPrimitives.ReadUInt32BigEndian(bytes.Slice(offset, 4));
    private static ushort U16(ReadOnlySpan<byte> bytes, int offset) => BinaryPrimitives.ReadUInt16BigEndian(bytes.Slice(offset, 2));
}
