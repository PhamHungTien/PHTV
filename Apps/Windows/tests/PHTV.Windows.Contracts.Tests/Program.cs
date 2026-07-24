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
