using System.Buffers.Binary;

namespace PHTV.Windows.Contracts.Configuration;

public readonly record struct RuntimeSettingsSnapshot(
    int SchemaVersion,
    ulong Revision,
    bool VietnameseEnabled,
    InputMethod InputMethod
);

/// <summary>
/// Stable, fixed-size control-plane snapshot consumed by the native TSF DLL.
/// The JSON document remains the user-facing source of truth; this format keeps
/// parsing, allocation, and forward-compatibility decisions out of the hot IME.
/// </summary>
public static class PHTVRuntimeSettingsSnapshot
{
    public const ushort CurrentFormatVersion = 1;
    public const int ByteLength = 36;

    private const int FormatVersionOffset = 8;
    private const int ByteLengthOffset = 10;
    private const int SchemaVersionOffset = 12;
    private const int RevisionOffset = 16;
    private const int FlagsOffset = 24;
    private const int InputMethodOffset = 28;
    private const int ChecksumOffset = 32;

    private const uint VietnameseEnabledFlag = 1U << 0;
    private const uint KnownFlags = VietnameseEnabledFlag;
    private const uint FnvOffsetBasis = 2166136261;
    private const uint FnvPrime = 16777619;

    private static ReadOnlySpan<byte> Magic =>
    [
        (byte)'P',
        (byte)'H',
        (byte)'T',
        (byte)'V',
        (byte)'C',
        (byte)'F',
        (byte)'G',
        0,
    ];

    public static byte[] Encode(PHTVSettings settings, ulong revision)
    {
        PHTVSettings normalized = settings.Normalize();
        var result = new byte[ByteLength];

        Magic.CopyTo(result);
        BinaryPrimitives.WriteUInt16LittleEndian(
            result.AsSpan(FormatVersionOffset),
            CurrentFormatVersion
        );
        BinaryPrimitives.WriteUInt16LittleEndian(
            result.AsSpan(ByteLengthOffset),
            checked((ushort)ByteLength)
        );
        BinaryPrimitives.WriteUInt32LittleEndian(
            result.AsSpan(SchemaVersionOffset),
            checked((uint)normalized.SchemaVersion)
        );
        BinaryPrimitives.WriteUInt64LittleEndian(
            result.AsSpan(RevisionOffset),
            revision
        );

        uint flags = normalized.VietnameseEnabled
            ? VietnameseEnabledFlag
            : 0;
        BinaryPrimitives.WriteUInt32LittleEndian(
            result.AsSpan(FlagsOffset),
            flags
        );
        BinaryPrimitives.WriteUInt32LittleEndian(
            result.AsSpan(InputMethodOffset),
            (uint)normalized.InputMethod
        );
        BinaryPrimitives.WriteUInt32LittleEndian(
            result.AsSpan(ChecksumOffset),
            ComputeChecksum(result.AsSpan(0, ChecksumOffset))
        );

        return result;
    }

    public static bool TryDecode(
        ReadOnlySpan<byte> contents,
        out RuntimeSettingsSnapshot snapshot
    )
    {
        snapshot = default;
        if (contents.Length != ByteLength
            || !contents[..Magic.Length].SequenceEqual(Magic)
            || BinaryPrimitives.ReadUInt16LittleEndian(
                contents[FormatVersionOffset..]
            ) != CurrentFormatVersion
            || BinaryPrimitives.ReadUInt16LittleEndian(
                contents[ByteLengthOffset..]
            ) != ByteLength)
        {
            return false;
        }

        uint expectedChecksum = BinaryPrimitives.ReadUInt32LittleEndian(
            contents[ChecksumOffset..]
        );
        if (expectedChecksum != ComputeChecksum(contents[..ChecksumOffset]))
        {
            return false;
        }

        uint schemaVersion = BinaryPrimitives.ReadUInt32LittleEndian(
            contents[SchemaVersionOffset..]
        );
        uint flags = BinaryPrimitives.ReadUInt32LittleEndian(
            contents[FlagsOffset..]
        );
        uint inputMethod = BinaryPrimitives.ReadUInt32LittleEndian(
            contents[InputMethodOffset..]
        );
        if (schemaVersion != PHTVSettings.CurrentSchemaVersion
            || (flags & ~KnownFlags) != 0
            || inputMethod > (uint)InputMethod.Vni)
        {
            return false;
        }

        snapshot = new RuntimeSettingsSnapshot(
            checked((int)schemaVersion),
            BinaryPrimitives.ReadUInt64LittleEndian(contents[RevisionOffset..]),
            (flags & VietnameseEnabledFlag) != 0,
            (InputMethod)inputMethod
        );
        return true;
    }

    private static uint ComputeChecksum(ReadOnlySpan<byte> contents)
    {
        uint checksum = FnvOffsetBasis;
        foreach (byte value in contents)
        {
            checksum ^= value;
            checksum = unchecked(checksum * FnvPrime);
        }
        return checksum;
    }
}
