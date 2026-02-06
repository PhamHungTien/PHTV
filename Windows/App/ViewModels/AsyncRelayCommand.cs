using System;
using System.Threading.Tasks;
using System.Windows.Input;

namespace PHTV.Windows.ViewModels;

public sealed class AsyncRelayCommand : ICommand {
    private readonly Func<Task> _execute;
    private readonly Func<bool>? _canExecute;
    private bool _isExecuting;

    public AsyncRelayCommand(Func<Task> execute, Func<bool>? canExecute = null) {
        _execute = execute;
        _canExecute = canExecute;
    }

    public bool CanExecute(object? parameter) {
        return !_isExecuting && (_canExecute?.Invoke() ?? true);
    }

    public async void Execute(object? parameter) {
        if (!CanExecute(parameter)) {
            return;
        }

        try {
            _isExecuting = true;
            RaiseCanExecuteChanged();
            await _execute();
        } finally {
            _isExecuting = false;
            RaiseCanExecuteChanged();
        }
    }

    public event EventHandler? CanExecuteChanged;

    public void RaiseCanExecuteChanged() => CanExecuteChanged?.Invoke(this, EventArgs.Empty);
}
