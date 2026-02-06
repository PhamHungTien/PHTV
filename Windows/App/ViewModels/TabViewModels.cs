namespace PHTV.Windows.ViewModels;

public abstract class SettingsTabViewModel : ObservableObject {
    protected SettingsTabViewModel(SettingsState state) {
        State = state;
    }

    public SettingsState State { get; }
    public abstract SettingsTabId Id { get; }
    public abstract string Title { get; }
    public abstract string Subtitle { get; }
    public abstract string IconGlyph { get; }
}

public sealed class TypingTabViewModel : SettingsTabViewModel {
    public TypingTabViewModel(SettingsState state) : base(state) { }
    public override SettingsTabId Id => SettingsTabId.Typing;
    public override string Title => "Bộ gõ tiếng Việt";
    public override string Subtitle => "Thiết lập phương pháp gõ, chính tả và các tối ưu để gõ nhanh, đúng.";
    public override string IconGlyph => "⌨";
}

public sealed class HotkeysTabViewModel : SettingsTabViewModel {
    public HotkeysTabViewModel(SettingsState state) : base(state) { }
    public override SettingsTabId Id => SettingsTabId.Hotkeys;
    public override string Title => "Phím tắt";
    public override string Subtitle => "Tùy chỉnh phím tắt để chuyển chế độ gõ và mở PHTV Picker nhanh.";
    public override string IconGlyph => "⌘";
}

public sealed class MacroTabViewModel : SettingsTabViewModel {
    public MacroTabViewModel(SettingsState state) : base(state) { }
    public override SettingsTabId Id => SettingsTabId.Macro;
    public override string Title => "Gõ tắt & Macro";
    public override string Subtitle => "Tạo từ viết tắt, quản lý danh mục và tăng tốc độ nhập liệu.";
    public override string IconGlyph => "✎";
}

public sealed class AppsTabViewModel : SettingsTabViewModel {
    public AppsTabViewModel(SettingsState state) : base(state) { }
    public override SettingsTabId Id => SettingsTabId.Apps;
    public override string Title => "Ứng dụng & Tương thích";
    public override string Subtitle => "Quản lý chuyển đổi theo từng ứng dụng và tối ưu khả năng tương thích.";
    public override string IconGlyph => "▦";
}

public sealed class SystemTabViewModel : SettingsTabViewModel {
    public SystemTabViewModel(SettingsState state) : base(state) { }
    public override SettingsTabId Id => SettingsTabId.System;
    public override string Title => "Hệ thống & Cập nhật";
    public override string Subtitle => "Quản lý giao diện, khởi động, cập nhật và sao lưu.";
    public override string IconGlyph => "⚙";
}

public sealed class BugReportTabViewModel : SettingsTabViewModel {
    public BugReportTabViewModel(SettingsState state) : base(state) { }
    public override SettingsTabId Id => SettingsTabId.BugReport;
    public override string Title => "Báo lỗi & Hỗ trợ";
    public override string Subtitle => "Gửi thông tin chi tiết để hỗ trợ nhanh và chính xác.";
    public override string IconGlyph => "🐞";
}

public sealed class AboutTabViewModel : SettingsTabViewModel {
    public AboutTabViewModel(SettingsState state) : base(state) { }
    public override SettingsTabId Id => SettingsTabId.About;
    public override string Title => "PHTV";
    public override string Subtitle => "Precision Hybrid Typing Vietnamese";
    public override string IconGlyph => "ⓘ";
}
