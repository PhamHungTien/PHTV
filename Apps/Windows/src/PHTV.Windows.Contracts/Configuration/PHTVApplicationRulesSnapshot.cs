using System.Buffers.Binary;
using System.Text;

namespace PHTV.Windows.Contracts.Configuration;

public readonly record struct RuntimeApplicationRule(
    string ExecutableIdentity,
    string? PackageFamilyName,
    ApplicationLanguageRule Rule
);

public readonly record struct RuntimeApplicationRulesSnapshot(
    int SchemaVersion,
    ulong Revision,
    IReadOnlyList<RuntimeApplicationRule> Rules
);

/// <summary>
/// Bounded runtime snapshot for per-application language policy. JSON remains
/// the source of truth; the native TSF component consumes this validated,
/// deterministic representation only during activation.
/// </summary>
public static class PHTVApplicationRulesSnapshot
{
    public const ushort CurrentFormatVersion = 1;
    public const int HeaderByteLength = 32;
    public const int RecordHeaderByteLength = 8;
    public const int ChecksumByteLength = 4;
    public const int MaximumByteLength = 64 * 1024;

    private const int FormatVersionOffset = 8;
    private const int HeaderLengthOffset = 10;
    private const int SchemaVersionOffset = 12;
    private const int RevisionOffset = 16;
    private const int RecordCountOffset = 24;
    private const int PayloadLengthOffset = 28;
    private const byte HasPackageFamilyFlag = 1 << 0;
    private const byte KnownRecordFlags = HasPackageFamilyFlag;
    private const uint FnvOffsetBasis = 2166136261;
    private const uint FnvPrime = 16777619;

    private static readonly UTF8Encoding StrictUtf8 =
        new(encoderShouldEmitUTF8Identifier: false, throwOnInvalidBytes: true);

    private static ReadOnlySpan<byte> Magic =>
    [
        (byte)'P',
        (byte)'H',
        (byte)'T',
        (byte)'V',
        (byte)'R',
        (byte)'U',
        (byte)'L',
        0,
    ];

    public static byte[] Encode(PHTVSettings settings, ulong revision)
    {
        ApplicationRule[] rules = settings
            .Normalize()
            .ApplicationRules
            .Where(rule => rule.Rule != ApplicationLanguageRule.Inherit)
            .ToArray();
        if (rules.Length > PHTVSettings.MaximumApplicationRuleCount)
        {
            throw new InvalidDataException(
                "The application rule count exceeds the runtime limit."
            );
        }

        var encodedRules = new List<(ApplicationRule Rule, byte[] Executable, byte[] Package)>(
            rules.Length
        );
        int payloadLength = 0;
        foreach (ApplicationRule rule in rules)
        {
            byte[] executable = StrictUtf8.GetBytes(rule.ExecutableIdentity);
            byte[] package = rule.PackageFamilyName is null
                ? []
                : StrictUtf8.GetBytes(rule.PackageFamilyName);
            if (executable.Length is 0 or > ushort.MaxValue
                || package.Length > ushort.MaxValue)
            {
                throw new InvalidDataException(
                    "An application identity is too large for the runtime snapshot."
                );
            }

            payloadLength = checked(
                payloadLength
                + RecordHeaderByteLength
                + executable.Length
                + package.Length
            );
            encodedRules.Add((rule, executable, package));
        }

        int totalLength = checked(
            HeaderByteLength + payloadLength + ChecksumByteLength
        );
        if (totalLength > MaximumByteLength)
        {
            throw new InvalidDataException(
                "The application rules snapshot exceeds its size limit."
            );
        }

        var result = new byte[totalLength];
        Magic.CopyTo(result);
        BinaryPrimitives.WriteUInt16LittleEndian(
            result.AsSpan(FormatVersionOffset),
            CurrentFormatVersion
        );
        BinaryPrimitives.WriteUInt16LittleEndian(
            result.AsSpan(HeaderLengthOffset),
            HeaderByteLength
        );
        BinaryPrimitives.WriteUInt32LittleEndian(
            result.AsSpan(SchemaVersionOffset),
            PHTVSettings.CurrentSchemaVersion
        );
        BinaryPrimitives.WriteUInt64LittleEndian(
            result.AsSpan(RevisionOffset),
            revision
        );
        BinaryPrimitives.WriteUInt32LittleEndian(
            result.AsSpan(RecordCountOffset),
            checked((uint)encodedRules.Count)
        );
        BinaryPrimitives.WriteUInt32LittleEndian(
            result.AsSpan(PayloadLengthOffset),
            checked((uint)payloadLength)
        );

        int offset = HeaderByteLength;
        foreach ((ApplicationRule rule, byte[] executable, byte[] package) in encodedRules)
        {
            result[offset] = checked((byte)rule.Rule);
            result[offset + 1] = package.Length == 0
                ? (byte)0
                : HasPackageFamilyFlag;
            BinaryPrimitives.WriteUInt16LittleEndian(
                result.AsSpan(offset + 2),
                checked((ushort)executable.Length)
            );
            BinaryPrimitives.WriteUInt16LittleEndian(
                result.AsSpan(offset + 4),
                checked((ushort)package.Length)
            );
            BinaryPrimitives.WriteUInt16LittleEndian(
                result.AsSpan(offset + 6),
                0
            );
            offset += RecordHeaderByteLength;
            executable.CopyTo(result, offset);
            offset += executable.Length;
            package.CopyTo(result, offset);
            offset += package.Length;
        }

        BinaryPrimitives.WriteUInt32LittleEndian(
            result.AsSpan(offset),
            ComputeChecksum(result.AsSpan(0, offset))
        );
        return result;
    }

    public static bool TryDecode(
        ReadOnlySpan<byte> contents,
        out RuntimeApplicationRulesSnapshot snapshot
    )
    {
        snapshot = default;
        if (contents.Length < HeaderByteLength + ChecksumByteLength
            || contents.Length > MaximumByteLength
            || !contents[..Magic.Length].SequenceEqual(Magic)
            || BinaryPrimitives.ReadUInt16LittleEndian(
                contents[FormatVersionOffset..]
            ) != CurrentFormatVersion
            || BinaryPrimitives.ReadUInt16LittleEndian(
                contents[HeaderLengthOffset..]
            ) != HeaderByteLength)
        {
            return false;
        }

        uint schemaVersion = BinaryPrimitives.ReadUInt32LittleEndian(
            contents[SchemaVersionOffset..]
        );
        uint recordCount = BinaryPrimitives.ReadUInt32LittleEndian(
            contents[RecordCountOffset..]
        );
        uint payloadLength = BinaryPrimitives.ReadUInt32LittleEndian(
            contents[PayloadLengthOffset..]
        );
        if (schemaVersion != PHTVSettings.CurrentSchemaVersion
            || recordCount > PHTVSettings.MaximumApplicationRuleCount
            || payloadLength
                != (uint)(
                    contents.Length
                    - HeaderByteLength
                    - ChecksumByteLength
                ))
        {
            return false;
        }

        int checksumOffset = contents.Length - ChecksumByteLength;
        if (BinaryPrimitives.ReadUInt32LittleEndian(contents[checksumOffset..])
            != ComputeChecksum(contents[..checksumOffset]))
        {
            return false;
        }

        try
        {
            var rules = new List<RuntimeApplicationRule>(
                checked((int)recordCount)
            );
            int offset = HeaderByteLength;
            for (uint index = 0; index < recordCount; ++index)
            {
                if (offset > checksumOffset - RecordHeaderByteLength)
                {
                    return false;
                }

                byte rawRule = contents[offset];
                byte flags = contents[offset + 1];
                int executableLength = BinaryPrimitives.ReadUInt16LittleEndian(
                    contents[(offset + 2)..]
                );
                int packageLength = BinaryPrimitives.ReadUInt16LittleEndian(
                    contents[(offset + 4)..]
                );
                ushort reserved = BinaryPrimitives.ReadUInt16LittleEndian(
                    contents[(offset + 6)..]
                );
                offset += RecordHeaderByteLength;

                bool hasPackage = (flags & HasPackageFamilyFlag) != 0;
                int recordLength = checked(executableLength + packageLength);
                if ((rawRule
                        != (byte)ApplicationLanguageRule.PreferEnglish
                        && rawRule
                            != (byte)ApplicationLanguageRule.LockEnglish)
                    || (flags & ~KnownRecordFlags) != 0
                    || reserved != 0
                    || executableLength == 0
                    || hasPackage != (packageLength != 0)
                    || offset > checksumOffset - recordLength)
                {
                    return false;
                }

                string executable = StrictUtf8.GetString(
                    contents.Slice(offset, executableLength)
                );
                offset += executableLength;
                string? package = packageLength == 0
                    ? null
                    : StrictUtf8.GetString(
                        contents.Slice(offset, packageLength)
                    );
                offset += packageLength;

                var candidate = new ApplicationRule(
                    executable,
                    package,
                    (ApplicationLanguageRule)rawRule
                );
                PHTVSettings normalized = new PHTVSettings
                {
                    ApplicationRules = [candidate],
                }.Normalize();
                if (normalized.ApplicationRules.Count != 1
                    || normalized.ApplicationRules[0] != candidate
                    || rules.Any(existing =>
                        existing.ExecutableIdentity == executable
                        && existing.PackageFamilyName == package))
                {
                    return false;
                }

                rules.Add(
                    new RuntimeApplicationRule(
                        executable,
                        package,
                        candidate.Rule
                    )
                );
            }

            if (offset != checksumOffset
                || !RulesAreCanonicallyOrdered(rules))
            {
                return false;
            }

            snapshot = new RuntimeApplicationRulesSnapshot(
                checked((int)schemaVersion),
                BinaryPrimitives.ReadUInt64LittleEndian(
                    contents[RevisionOffset..]
                ),
                rules
            );
            return true;
        }
        catch (Exception exception) when (
            exception is ArgumentException
                or OverflowException
        )
        {
            return false;
        }
    }

    private static bool RulesAreCanonicallyOrdered(
        IReadOnlyList<RuntimeApplicationRule> rules
    )
    {
        for (int index = 1; index < rules.Count; ++index)
        {
            RuntimeApplicationRule previous = rules[index - 1];
            RuntimeApplicationRule current = rules[index];
            int executableOrder = string.CompareOrdinal(
                previous.ExecutableIdentity,
                current.ExecutableIdentity
            );
            if (executableOrder > 0
                || (executableOrder == 0
                    && string.CompareOrdinal(
                        previous.PackageFamilyName,
                        current.PackageFamilyName
                    ) >= 0))
            {
                return false;
            }
        }
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
