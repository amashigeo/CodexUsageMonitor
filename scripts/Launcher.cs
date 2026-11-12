using System;
using System.IO;
using System.IO.Compression;
using System.Diagnostics;
using System.Reflection;
using System.Threading;
using System.Windows.Forms;
class Launcher {
 [STAThread] static int Main(string[] args) {
  try {
   bool extractOnly=args.Length==2 && args[0]=="--extract-only";
   string root=extractOnly?Path.GetFullPath(args[1]):Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"CodexUsageMonitor","app-1.7.0");
   Directory.CreateDirectory(root);
   string settings=Path.Combine(root,"widget-settings.json");
   string prior=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"CodexUsageMonitor","app-1.6.0","widget-settings.json");
   if(!extractOnly && !File.Exists(settings) && File.Exists(prior))File.Copy(prior,settings);
   string previousCache=Path.Combine(Path.GetDirectoryName(prior),"reset-credits-cache.json");
   string cache=Path.Combine(root,"reset-credits-cache.json");
   if(!extractOnly&&!File.Exists(cache)&&File.Exists(previousCache))File.Copy(previousCache,cache);
   using(var mutex=new Mutex(false,"Local\\CodexUsageExtract170")) {
    if(!mutex.WaitOne(30000)) throw new Exception("Another launch is still extracting files.");
    try {
     if(!File.Exists(Path.Combine(root,".ready"))) {
      using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("Payload"))
      using(var archive=new ZipArchive(stream,ZipArchiveMode.Read)) {
       foreach(var entry in archive.Entries) {
        string target=Path.GetFullPath(Path.Combine(root,entry.FullName));
        if(!target.StartsWith(root+Path.DirectorySeparatorChar,StringComparison.OrdinalIgnoreCase))throw new Exception("Invalid package path.");
        if(entry.FullName.EndsWith("/")){Directory.CreateDirectory(target);continue;}
        Directory.CreateDirectory(Path.GetDirectoryName(target));
        using(var input=entry.Open())using(var output=File.Create(target))input.CopyTo(output);
       }
      }
      File.WriteAllText(Path.Combine(root,".ready"),"1.7.0");
     }
    } finally {mutex.ReleaseMutex();}
   }
   if(extractOnly)return 0;
   var start=new ProcessStartInfo("powershell.exe","-NoProfile -ExecutionPolicy Bypass -File \""+Path.Combine(root,"launch.ps1")+"\"");
   start.WorkingDirectory=root;start.UseShellExecute=false;start.CreateNoWindow=true;start.WindowStyle=ProcessWindowStyle.Hidden;
   Process.Start(start);return 0;
  } catch(Exception e) {MessageBox.Show(e.Message,"Codex Usage Monitor",MessageBoxButtons.OK,MessageBoxIcon.Error);return 1;}
 }
}
