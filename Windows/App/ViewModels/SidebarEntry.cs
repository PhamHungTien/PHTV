namespace PHTV.Windows.ViewModels;

public abstract class SidebarEntry : ObservableObject {
}

public sealed class SidebarSectionEntry : SidebarEntry {
    public SidebarSectionEntry(string title) {
        Title = title;
    }

    public string Title { get; }
}

public sealed class SidebarTabEntry : SidebarEntry {
    private bool _isSelected;

    public SidebarTabEntry(SettingsTabId tabId, string title, string iconGlyph, string section, params string[] keywords) {
        TabId = tabId;
        Title = title;
        IconGlyph = iconGlyph;
        Section = section;
        Keywords = keywords;
    }

    public SettingsTabId TabId { get; }
    public string Title { get; }
    public string IconGlyph { get; }
    public string Section { get; }
    public string[] Keywords { get; }
    public bool IsSelected { get => _isSelected; set => SetProperty(ref _isSelected, value); }
}
