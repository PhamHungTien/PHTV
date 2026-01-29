using System;
using System.IO;

namespace PHTV.UI.Utilities
{
    internal static class PhtvPaths
    {
        public static string DataDirectory { get; private set; } = string.Empty;
        public static string MacroPath { get; private set; } = string.Empty;
        public static string AppMapPath { get; private set; } = string.Empty;
        public static string UpperExcludedPath { get; private set; } = string.Empty;

        public static void Initialize()
        {
            string appData = Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
            string phtvDir = Path.Combine(appData, "PHTV");
            Directory.CreateDirectory(phtvDir);

            DataDirectory = phtvDir;
            MacroPath = Path.Combine(phtvDir, "macros.dat");
            AppMapPath = Path.Combine(phtvDir, "apps.dat");
            UpperExcludedPath = Path.Combine(phtvDir, "upper_excluded.dat");
        }
    }
}
