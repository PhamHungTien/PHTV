using System.Buffers.Binary;
using System.Text;
using System.Text.Json;
using PHTV.Windows.Contracts.Configuration;

namespace PHTV.Windows.Contracts.Tests;

internal static class Program
{
    public static int Main()
    {
        try
        {
            RoundTripKeepsSupportedSettings();
            NormalizationIsStableAndDeterministic();
            FutureSchemaIsRejected();
            RuntimeSnapshotMatchesNativeGoldenVector();
            RuntimeSnapshotRejectsCorruptionAndFutureFormats();
            ApplicationRulesSnapshotMatchesNativeGoldenVector();
            ApplicationRulesSnapshotRoundTrips();
            ApplicationRulesSnapshotRejectsMalformedInput();
            Console.WriteLine("PHTV Windows configuration contract tests passed");
            return 0;
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine($"FAILED: {exception.Message}");
            return 1;
        }
    }

    private static void RoundTripKeepsSupportedSettings()
    {
        var original = new PHTVSettings
        {
            VietnameseEnabled = false,
            InputMethod = InputMethod.Vni,
            ApplicationRules =
            [
                new(
                    "devenv.exe",
                    null,
                    ApplicationLanguageRule.PreferEnglish
                ),
            ],
        };

        byte[] encoded = PHTVSettingsSerializer.Serialize(original);
        PHTVSettings decoded = PHTVSettingsSerializer.Deserialize(encoded);

        Assert(decoded.SchemaVersion == PHTVSettings.CurrentSchemaVersion);
        Assert(!decoded.VietnameseEnabled);
        Assert(decoded.InputMethod == InputMethod.Vni);
        Assert(decoded.ApplicationRules.Count == 1);
        Assert(
            decoded.ApplicationRules[0].Rule
                == ApplicationLanguageRule.PreferEnglish
        );
    }

    private static void NormalizationIsStableAndDeterministic()
    {
        var settings = new PHTVSettings
        {
            ApplicationRules =
            [
                new(" ZALO.EXE ", null, ApplicationLanguageRule.LockEnglish),
                new("zalo.exe", null, ApplicationLanguageRule.PreferEnglish),
                new("Code.EXE", " Example.Package ", ApplicationLanguageRule.Inherit),
                new(" ", null, ApplicationLanguageRule.LockEnglish),
                new(@"C:\unsafe.exe", null, ApplicationLanguageRule.LockEnglish),
                new("readme.txt", null, ApplicationLanguageRule.LockEnglish),
            ],
        };

        PHTVSettings normalized = settings.Normalize();
        Assert(normalized.ApplicationRules.Count == 2);
        Assert(normalized.ApplicationRules[0].ExecutableIdentity == "code.exe");
        Assert(normalized.ApplicationRules[0].PackageFamilyName == "example.package");
        Assert(normalized.ApplicationRules[1].ExecutableIdentity == "zalo.exe");
        Assert(
            normalized.ApplicationRules[1].Rule
                == ApplicationLanguageRule.LockEnglish
        );
    }

    private static void ApplicationRulesSnapshotRoundTrips()
    {
        const ulong revision = 0x1122334455667788;
        var settings = new PHTVSettings
        {
            ApplicationRules =
            [
                new(
                    "NOTEPAD.EXE",
                    null,
                    ApplicationLanguageRule.LockEnglish
                ),
                new(
                    "code.exe",
                    " Microsoft.Code_8WEKYB3D8BBWE ",
                    ApplicationLanguageRule.LockEnglish
                ),
                new(
                    "code.exe",
                    null,
                    ApplicationLanguageRule.PreferEnglish
                ),
                new(
                    "ignored.exe",
                    null,
                    ApplicationLanguageRule.Inherit
                ),
            ],
        };

        byte[] encoded = PHTVApplicationRulesSnapshot.Encode(
            settings,
            revision
        );
        Assert(
            PHTVApplicationRulesSnapshot.TryDecode(
                encoded,
                out RuntimeApplicationRulesSnapshot snapshot
            )
        );
        Assert(snapshot.SchemaVersion == PHTVSettings.CurrentSchemaVersion);
        Assert(snapshot.Revision == revision);
        Assert(snapshot.Rules.Count == 3);
        Assert(snapshot.Rules[0].ExecutableIdentity == "code.exe");
        Assert(snapshot.Rules[0].PackageFamilyName is null);
        Assert(
            snapshot.Rules[0].Rule
                == ApplicationLanguageRule.PreferEnglish
        );
        Assert(
            snapshot.Rules[1].PackageFamilyName
                == "microsoft.code_8wekyb3d8bbwe"
        );
        Assert(snapshot.Rules[2].ExecutableIdentity == "notepad.exe");
    }

    private static void ApplicationRulesSnapshotMatchesNativeGoldenVector()
    {
        byte[] expected = Convert.FromHexString(
            "5048545652554C000100200001000000"
                + "08070605040302010100000010000000"
                + "0100080000000000636F64652E657865"
                + "1159A51E"
        );
        byte[] encoded = PHTVApplicationRulesSnapshot.Encode(
            new PHTVSettings
            {
                ApplicationRules =
                [
                    new(
                        "code.exe",
                        null,
                        ApplicationLanguageRule.PreferEnglish
                    ),
                ],
            },
            revision: 0x0102030405060708
        );
        Assert(encoded.SequenceEqual(expected));
    }

    private static void ApplicationRulesSnapshotRejectsMalformedInput()
    {
        byte[] snapshot = PHTVApplicationRulesSnapshot.Encode(
            new PHTVSettings
            {
                ApplicationRules =
                [
                    new(
                        "code.exe",
                        null,
                        ApplicationLanguageRule.PreferEnglish
                    ),
                ],
            },
            revision: 99
        );

        byte[] corrupted = (byte[])snapshot.Clone();
        corrupted[32] ^= 1;
        Assert(
            !PHTVApplicationRulesSnapshot.TryDecode(corrupted, out _)
        );

        byte[] unknownRule = (byte[])snapshot.Clone();
        unknownRule[32] = 3;
        RefreshTrailingChecksum(unknownRule);
        Assert(
            !PHTVApplicationRulesSnapshot.TryDecode(unknownRule, out _)
        );

        byte[] invalidFlags = (byte[])snapshot.Clone();
        invalidFlags[33] = 2;
        RefreshTrailingChecksum(invalidFlags);
        Assert(
            !PHTVApplicationRulesSnapshot.TryDecode(invalidFlags, out _)
        );

        Assert(
            !PHTVApplicationRulesSnapshot.TryDecode(
                snapshot.AsSpan(0, snapshot.Length - 1),
                out _
            )
        );
    }

    private static void FutureSchemaIsRejected()
    {
        byte[] futureDocument = Encoding.UTF8.GetBytes(
            """
            {
              "schemaVersion": 999,
              "vietnameseEnabled": true,
              "inputMethod": 0,
              "applicationRules": []
            }
            """
        );

        try
        {
            _ = PHTVSettingsSerializer.Deserialize(futureDocument);
            throw new InvalidOperationException(
                "A future schema was accepted unexpectedly."
            );
        }
        catch (JsonException)
        {
            // Expected: readers fail closed instead of guessing a future schema.
        }
    }

    private static void RuntimeSnapshotMatchesNativeGoldenVector()
    {
        const ulong revision = 0x0102030405060708;
        var settings = new PHTVSettings
        {
            VietnameseEnabled = false,
            InputMethod = InputMethod.Vni,
        };
        byte[] expected = Convert.FromHexString(
            "50485456434647000100240001000000"
                + "08070605040302010000000001000000"
                + "6C05A6E9"
        );

        byte[] encoded = PHTVRuntimeSettingsSnapshot.Encode(
            settings,
            revision
        );
        Assert(encoded.SequenceEqual(expected));
        Assert(
            PHTVRuntimeSettingsSnapshot.TryDecode(
                expected,
                out RuntimeSettingsSnapshot decoded
            )
        );
        Assert(decoded.SchemaVersion == PHTVSettings.CurrentSchemaVersion);
        Assert(decoded.Revision == revision);
        Assert(!decoded.VietnameseEnabled);
        Assert(decoded.InputMethod == InputMethod.Vni);
    }

    private static void RuntimeSnapshotRejectsCorruptionAndFutureFormats()
    {
        byte[] snapshot = PHTVRuntimeSettingsSnapshot.Encode(
            new PHTVSettings(),
            revision: 42
        );

        byte[] corrupted = (byte[])snapshot.Clone();
        corrupted[24] ^= 1;
        Assert(
            !PHTVRuntimeSettingsSnapshot.TryDecode(corrupted, out _)
        );
        Assert(
            !PHTVRuntimeSettingsSnapshot.TryDecode(snapshot.AsSpan(1), out _)
        );

        byte[] futureFormat = (byte[])snapshot.Clone();
        futureFormat[8] = 2;
        Assert(
            !PHTVRuntimeSettingsSnapshot.TryDecode(futureFormat, out _)
        );

        byte[] unknownFlags = (byte[])snapshot.Clone();
        unknownFlags[24] = 2;
        RefreshRuntimeSnapshotChecksum(unknownFlags);
        Assert(
            !PHTVRuntimeSettingsSnapshot.TryDecode(unknownFlags, out _)
        );

        byte[] unknownMethod = (byte[])snapshot.Clone();
        unknownMethod[28] = 2;
        RefreshRuntimeSnapshotChecksum(unknownMethod);
        Assert(
            !PHTVRuntimeSettingsSnapshot.TryDecode(unknownMethod, out _)
        );

        byte[] futureSchema = (byte[])snapshot.Clone();
        futureSchema[12] = 2;
        RefreshRuntimeSnapshotChecksum(futureSchema);
        Assert(
            !PHTVRuntimeSettingsSnapshot.TryDecode(futureSchema, out _)
        );
    }

    private static void RefreshRuntimeSnapshotChecksum(Span<byte> contents)
    {
        const uint fnvOffsetBasis = 2166136261;
        const uint fnvPrime = 16777619;
        const int checksumOffset = 32;
        uint checksum = fnvOffsetBasis;
        foreach (byte value in contents[..checksumOffset])
        {
            checksum ^= value;
            checksum = unchecked(checksum * fnvPrime);
        }
        BinaryPrimitives.WriteUInt32LittleEndian(
            contents[checksumOffset..],
            checksum
        );
    }

    private static void RefreshTrailingChecksum(Span<byte> contents)
    {
        const uint fnvOffsetBasis = 2166136261;
        const uint fnvPrime = 16777619;
        int checksumOffset = contents.Length - sizeof(uint);
        uint checksum = fnvOffsetBasis;
        foreach (byte value in contents[..checksumOffset])
        {
            checksum ^= value;
            checksum = unchecked(checksum * fnvPrime);
        }
        BinaryPrimitives.WriteUInt32LittleEndian(
            contents[checksumOffset..],
            checksum
        );
    }

    private static void Assert(
        bool condition,
        [System.Runtime.CompilerServices.CallerArgumentExpression(
            nameof(condition)
        )]
        string? expression = null
    )
    {
        if (!condition)
        {
            throw new InvalidOperationException(expression ?? "Assertion failed.");
        }
    }
}
