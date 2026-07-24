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
