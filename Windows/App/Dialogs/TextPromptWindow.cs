using Avalonia;
using Avalonia.Controls;
using Avalonia.Layout;
using System.Threading.Tasks;

namespace PHTV.Windows.Dialogs;

public sealed class TextPromptWindow : Window {
    private readonly TextBox _input;
    private readonly bool _isMultiline;

    public TextPromptWindow(
        string title,
        string description,
        string initialValue = "",
        string watermark = "",
        bool isMultiline = false) {
        _isMultiline = isMultiline;

        Title = title;
        Width = 500;
        Height = isMultiline ? 330 : 210;
        MinWidth = 420;
        MinHeight = isMultiline ? 300 : 200;
        WindowStartupLocation = WindowStartupLocation.CenterOwner;
        CanResize = isMultiline;

        _input = new TextBox {
            Text = initialValue,
            Watermark = watermark,
            AcceptsReturn = isMultiline,
            TextWrapping = isMultiline ? Avalonia.Media.TextWrapping.Wrap : Avalonia.Media.TextWrapping.NoWrap,
            Height = isMultiline ? 170 : double.NaN,
            VerticalContentAlignment = isMultiline ? VerticalAlignment.Top : VerticalAlignment.Center
        };

        var okButton = new Button {
            Content = "Xác nhận",
            MinWidth = 96,
            IsDefault = true
        };
        okButton.Click += (_, _) => Close(CreateResult());

        var cancelButton = new Button {
            Content = "Hủy",
            MinWidth = 96,
            IsCancel = true
        };
        cancelButton.Click += (_, _) => Close(null);

        Content = new Border {
            Padding = new Thickness(16),
            Child = new StackPanel {
                Spacing = 12,
                Children = {
                    new TextBlock {
                        Text = description,
                        TextWrapping = Avalonia.Media.TextWrapping.Wrap
                    },
                    _input,
                    new StackPanel {
                        Orientation = Orientation.Horizontal,
                        Spacing = 8,
                        HorizontalAlignment = HorizontalAlignment.Right,
                        Children = { cancelButton, okButton }
                    }
                }
            }
        };
    }

    public static async Task<string?> ShowAsync(
        Window owner,
        string title,
        string description,
        string initialValue = "",
        string watermark = "",
        bool isMultiline = false) {
        var dialog = new TextPromptWindow(title, description, initialValue, watermark, isMultiline);
        return await dialog.ShowDialog<string?>(owner);
    }

    private string? CreateResult() {
        var text = _input.Text ?? string.Empty;
        if (!_isMultiline) {
            text = text.Trim();
        }

        return string.IsNullOrWhiteSpace(text) ? null : text;
    }
}
