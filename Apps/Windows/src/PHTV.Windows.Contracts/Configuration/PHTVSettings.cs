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

    public int SchemaVersion { get; init; } = CurrentSchemaVersion;

    public bool VietnameseEnabled { get; init; } = true;

    public InputMethod InputMethod { get; init; } = InputMethod.Telex;

    public IReadOnlyList<ApplicationRule> ApplicationRules { get; init; } = [];

    public PHTVSettings Normalize()
    {
        InputMethod normalizedMethod =
            Enum.IsDefined(InputMethod) ? InputMethod : InputMethod.Telex;

        ApplicationRule[] normalizedRules = ApplicationRules
            .Where(rule => !string.IsNullOrWhiteSpace(rule.ExecutableIdentity))
            .Select(rule => rule with
            {
                ExecutableIdentity = rule.ExecutableIdentity.Trim().ToLowerInvariant(),
                PackageFamilyName = string.IsNullOrWhiteSpace(rule.PackageFamilyName)
                    ? null
                    : rule.PackageFamilyName.Trim().ToLowerInvariant(),
                Rule = Enum.IsDefined(rule.Rule)
                    ? rule.Rule
                    : ApplicationLanguageRule.Inherit,
            })
            .DistinctBy(rule => (rule.ExecutableIdentity, rule.PackageFamilyName))
            .OrderBy(rule => rule.ExecutableIdentity, StringComparer.Ordinal)
            .ToArray();

        return this with
        {
            SchemaVersion = CurrentSchemaVersion,
            InputMethod = normalizedMethod,
            ApplicationRules = normalizedRules,
        };
    }
}
