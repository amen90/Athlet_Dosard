
// Android/Java preprocessing code for Firebase ML
public class AthleteAnomalyPreprocessor {
    
    // Scaler parameters (from training)
    private static final float[] SCALER_MEAN = {130.10256991987998, 95.09956383382, 4.976967278282001, 37.82234, 1.522};
    private static final float[] SCALER_SCALE = {14.704072545919214, 2.94924470225052, 1.9172122073361932, 0.3356687718570199, 1.1178175164131219};
    
    // Activity encoding mapping
    private static final Map<String, Integer> ACTIVITY_MAPPING = new HashMap<String, Integer>() {{
        put("Cycling", 0);
        put("Running", 1);
        put("Treadmill", 2);
        put("Weightlifting", 3);
    }};
    
    public static float[] preprocessInput(float heartRate, float oxygenLevel, 
                                        float fatigueScore, float temperature, 
                                        String activity) {
        
        // Encode activity
        int activityCode = ACTIVITY_MAPPING.getOrDefault(activity, 0);
        
        // Create feature array
        float[] features = {heartRate, oxygenLevel, fatigueScore, temperature, activityCode};
        
        // Apply scaling: (x - mean) / scale
        for (int i = 0; i < features.length; i++) {
            features[i] = (features[i] - SCALER_MEAN[i]) / SCALER_SCALE[i];
        }
        
        return features;
    }
    
    public static boolean isAnomaly(float probability) {
        return probability > 0.5f;
    }
    
    public static String getRiskLevel(float probability) {
        if (probability < 0.1f) return "Very Low";
        else if (probability < 0.3f) return "Low";
        else if (probability < 0.5f) return "Moderate";
        else return "High";
    }
}
