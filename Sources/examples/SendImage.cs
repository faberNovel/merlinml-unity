using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;

public class SendImage : MonoBehaviour
{
    [DllImport("__Internal")]
    private static extern void MerlinML_loadModel();

    [DllImport("__Internal")]
    private static extern bool MerlinML_processImage(byte[] bytes, int length, [Out] float[] results);

    void Start() {
        // Try to load the model
        MerlinML_loadModel();
        
        // Test with a simple image
        StartCoroutine(TestImageProcessing());
    }

    IEnumerator TestImageProcessing() {
        // Create a simple test image
        Texture2D texture = new Texture2D(100, 100);
        for (int i = 0; i < 100; i++) {
            for (int j = 0; j < 100; j++) {
                texture.SetPixel(i, j, Color.red);
            }
        }
        texture.Apply();
        
        // Convert to JPG
        byte[] jpgData = texture.EncodeToJPG();
        
        // Prepare results array
        float[] results = new float[5];
        
        // Try to process
        bool success = MerlinML_processImage(jpgData, jpgData.Length, results);
        
        Debug.Log($"Image processing success: {success}");
        if (success) {
            Debug.Log($"Results: {string.Join(", ", results)}");
        }
        
        yield return null;
    }
}
