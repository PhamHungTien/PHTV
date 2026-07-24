namespace PHTV.Windows.Contracts.Configuration;

public enum InputMethod
{
    Telex = 0,
    Vni = 1,
}

public enum ApplicationLanguageRule
{
    Inherit = 0,
    PreferEnglish = 1,
    LockEnglish = 2,
}

public sealed record ApplicationRule(
    string ExecutableIdentity,
    string? PackageFamilyName,
    ApplicationLanguageRule Rule
);

public sealed record PHTVSettings
{
    public const int CurrentSchemaVersion = 1;
    public const int MaximumApplicationRuleCount = 256;
    public const int MaximumExecutableIdentityLength = 260;
    public const int MaximumPackageFamilyNameLength = 255;

    public int SchemaVersion { get; init; } = CurrentSchemaVersion;

    public bool VietnameseEnabled { get; init; } = true;

    public InputMethod InputMethod { get; init; } = InputMethod.Telex;

    public IReadOnlyList<ApplicationRule> ApplicationRules { get; init; } = [];

    public PHTVSettings Normalize()
    {
        InputMethod normalizedMethod =
            Enum.IsDefined(InputMethod) ? InputMethod : InputMethod.Telex;

        ApplicationRule[] normalizedRules = (ApplicationRules ?? [])
            .Where(rule => IsValidExecutableIdentity(rule.ExecutableIdentity))
            .Select(rule => rule with
            {
                ExecutableIdentity = rule.ExecutableIdentity.Trim().ToLowerInvariant(),
                PackageFamilyName = NormalizePackageFamilyName(
                    rule.PackageFamilyName
                ),
                Rule = Enum.IsDefined(rule.Rule)
                    ? rule.Rule
                    : ApplicationLanguageRule.Inherit,
            })
            .DistinctBy(rule => (rule.ExecutableIdentity, rule.PackageFamilyName))
            .OrderBy(rule => rule.ExecutableIdentity, StringComparer.Ordinal)
            .ThenBy(
                rule => rule.PackageFamilyName,
                StringComparer.Ordinal
            )
            .Take(MaximumApplicationRuleCount)
            .ToArray();

        return this with
        {
            SchemaVersion = CurrentSchemaVersion,
            InputMethod = normalizedMethod,
            ApplicationRules = normalizedRules,
        };
    }

    private static bool IsValidExecutableIdentity(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return false;
        }

        string trimmed = value.Trim();
        return trimmed.Length <= MaximumExecutableIdentityLength
            && trimmed.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)
            && trimmed.IndexOfAny(['\0', '/', '\\', ':']) < 0;
    }

    private static string? NormalizePackageFamilyName(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        string normalized = value.Trim().ToLowerInvariant();
        if (normalized.Length > MaximumPackageFamilyNameLength
            || normalized.Any(character =>
                !(character is >= 'a' and <= 'z'
                    or >= '0' and <= '9'
                    or '.'
                    or '_'
                    or '-')))
        {
            return null;
        }
        return normalized;
    }
}
