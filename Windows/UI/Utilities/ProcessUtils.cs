using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;

namespace PHTV.UI.Utilities
{
    internal static class ProcessUtils
    {
        public static List<string> GetRunningAppNames()
        {
            var names = new List<string>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            foreach (var proc in Process.GetProcesses())
            {
                try
                {
                    string name = string.Empty;
                    try
                    {
                        if (proc.MainModule != null && !string.IsNullOrEmpty(proc.MainModule.FileName))
                        {
                            name = Path.GetFileName(proc.MainModule.FileName);
                        }
                    }
                    catch
                    {
                        // Access denied for some system processes.
                    }

                    if (string.IsNullOrWhiteSpace(name) && !string.IsNullOrWhiteSpace(proc.ProcessName))
                    {
                        name = proc.ProcessName.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)
                            ? proc.ProcessName
                            : proc.ProcessName + ".exe";
                    }

                    if (!string.IsNullOrWhiteSpace(name) && seen.Add(name))
                    {
                        names.Add(name);
                    }
                }
                finally
                {
                    proc.Dispose();
                }
            }

            names.Sort(StringComparer.OrdinalIgnoreCase);
            return names;
        }
    }
}
