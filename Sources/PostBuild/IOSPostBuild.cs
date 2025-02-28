#if UNITY_IOS
using UnityEditor;
using UnityEditor.Callbacks;
using UnityEditor.iOS.Xcode;
using System.IO;
using UnityEngine;

public class IOSPostBuild
{
    [PostProcessBuild]
    public static void OnPostprocessBuild(BuildTarget buildTarget, string path)
    {
        if (buildTarget == BuildTarget.iOS)
        {
            Debug.Log("Starting iOS post-build process...");
            
            // Get the Xcode project
            string projPath = PBXProject.GetPBXProjectPath(path);
            PBXProject proj = new PBXProject();
            proj.ReadFromFile(projPath);
            
            // Get the target GUID
            string targetGuid = proj.GetUnityMainTargetGuid();
            
            // Source model file in your Unity project
            string modelSourcePath = Path.Combine(Application.dataPath, "Plugins/iOS/MerlinML/Merlin.mlpackage");
            Debug.Log($"Looking for model at: {modelSourcePath}");
            
            // Destination in Xcode project
            string modelDestPath = Path.Combine(path, "Merlin.mlpackage");
            
            // Copy the model
            if (Directory.Exists(modelSourcePath))
            {
                Debug.Log($"Copying directory from {modelSourcePath} to {modelDestPath}");
                CopyDirectory(modelSourcePath, modelDestPath);
            }
            else if (File.Exists(modelSourcePath))
            {
                Debug.Log($"Copying file from {modelSourcePath} to {modelDestPath}");
                File.Copy(modelSourcePath, modelDestPath, true);
            }
            else
            {
                Debug.LogError($"Could not find model at {modelSourcePath}");
                return;
            }
            
            // Add to Xcode project and build phase
            string fileGuid = proj.AddFile("Merlin.mlpackage", "Merlin.mlpackage");
            proj.AddFileToBuild(targetGuid, fileGuid);
            Debug.Log("Added model to Xcode project build phase");
            
            // Save the changes
            proj.WriteToFile(projPath);
            Debug.Log("iOS post-build process completed successfully");
        }
    }
    
    private static void CopyDirectory(string sourceDir, string destDir)
    {
        Directory.CreateDirectory(destDir);
        
        foreach (string file in Directory.GetFiles(sourceDir))
        {
            string dest = Path.Combine(destDir, Path.GetFileName(file));
            File.Copy(file, dest, true);
        }
        
        foreach (string dir in Directory.GetDirectories(sourceDir))
        {
            string dest = Path.Combine(destDir, Path.GetFileName(dir));
            CopyDirectory(dir, dest);
        }
    }
}
#endif
