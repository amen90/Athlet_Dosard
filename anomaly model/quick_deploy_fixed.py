import numpy as np
import tensorflow as tf
import joblib
import time

class QuickAthleteDetector:
    def __init__(self):
        # Load the quick-trained model
        self.load_model("quick_athlete_model.tflite")
        self.load_preprocessing("quick_scaler.pkl", "quick_activity_encoder.pkl")
        
        print("✅ Quick deployment model loaded!")
        print(f"🏃‍♂️ Supported activities: {list(self.activity_encoder.classes_)}")
        
    def load_model(self, model_path):
        """Load TFLite model"""
        with open(model_path, 'rb') as f:
            tflite_model = f.read()
        
        self.interpreter = tf.lite.Interpreter(model_content=tflite_model)
        self.interpreter.allocate_tensors()
        
        self.input_details = self.interpreter.get_input_details()
        self.output_details = self.interpreter.get_output_details()
        
    def load_preprocessing(self, scaler_path, encoder_path):
        """Load preprocessing objects"""
        self.scaler = joblib.load(scaler_path)
        self.activity_encoder = joblib.load(encoder_path)
        
    def predict(self, sample_data):
        """Make prediction"""
        start_time = time.perf_counter()
        
        # Handle unknown activities gracefully
        activity = sample_data['Activity']
        if activity not in self.activity_encoder.classes_:
            print(f"⚠️ Unknown activity '{activity}', using default (first available)")
            activity_encoded = 0  # Use first class as default
        else:
            activity_encoded = self.activity_encoder.transform([activity])[0]
        
        features = np.array([[
            sample_data['HeartRate'],
            sample_data['OxygenLevel'],
            sample_data['FatigueScore'],
            sample_data['tmp'],
            activity_encoded
        ]], dtype=np.float32)
        
        features_scaled = self.scaler.transform(features).astype(np.float32)
        
        # Predict
        self.interpreter.set_tensor(self.input_details[0]['index'], features_scaled)
        self.interpreter.invoke()
        output = self.interpreter.get_tensor(self.output_details[0]['index'])
        
        probability = float(output[0][0])
        prediction = 1 if probability > 0.5 else 0
        inference_time = (time.perf_counter() - start_time) * 1000
        
        return prediction, probability, inference_time
    
    def assess_risk(self, prediction, probability, sample_data):
        """Risk assessment"""
        if probability < 0.1:
            risk = "🟢 Very Low"
        elif probability < 0.3:
            risk = "🟡 Low" 
        elif probability < 0.5:
            risk = "🟠 Moderate"
        else:
            risk = "🔴 High"
            
        status = "🚨 ANOMALY" if prediction == 1 else "✅ NORMAL"
        
        # Add alerts based on values
        alerts = []
        if sample_data['HeartRate'] > 180:
            alerts.append("⚠️ Very high heart rate")
        elif sample_data['HeartRate'] < 50:
            alerts.append("⚠️ Very low heart rate")
            
        if sample_data['OxygenLevel'] < 90:
            alerts.append("⚠️ Low oxygen saturation")
            
        if sample_data['FatigueScore'] > 8:
            alerts.append("⚠️ High fatigue level")
            
        if sample_data['tmp'] > 38.5:
            alerts.append("⚠️ High body temperature")
        elif sample_data['tmp'] < 36:
            alerts.append("⚠️ Low body temperature")
        
        return {
            'status': status,
            'risk': risk,
            'probability': probability,
            'confidence': (1-probability) if prediction == 0 else probability,
            'alerts': alerts
        }

def demo():
    print("🚀 Quick Athlete Anomaly Detection Demo")
    print("=" * 40)
    
    detector = QuickAthleteDetector()
    
    # Test cases using activities from the training data
    test_cases = [
        {
            'name': 'Normal Running',
            'data': {
                'HeartRate': 140.0,
                'OxygenLevel': 96.0,
                'FatigueScore': 4.0,
                'Activity': 'Running',  # This should be in training data
                'tmp': 37.2
            }
        },
        {
            'name': 'High Intensity Cycling',
            'data': {
                'HeartRate': 175.0,
                'OxygenLevel': 93.0,
                'FatigueScore': 7.5,
                'Activity': 'Cycling',  # This should be in training data
                'tmp': 38.2
            }
        },
        {
            'name': 'Swimming Session',
            'data': {
                'HeartRate': 150.0,
                'OxygenLevel': 95.0,
                'FatigueScore': 5.0,
                'Activity': 'Swimming',  # This should be in training data
                'tmp': 37.5
            }
        },
        {
            'name': 'Extreme Case (Potential Anomaly)',
            'data': {
                'HeartRate': 195.0,
                'OxygenLevel': 88.0,
                'FatigueScore': 9.5,
                'Activity': 'Running',
                'tmp': 39.2
            }
        },
        {
            'name': 'Unknown Activity Test',
            'data': {
                'HeartRate': 80.0,
                'OxygenLevel': 98.0,
                'FatigueScore': 2.0,
                'Activity': 'Walking',  # This might not be in training data
                'tmp': 36.8
            }
        }
    ]
    
    for test in test_cases:
        print(f"\n📊 Testing: {test['name']}")
        print(f"Input: {test['data']}")
        
        pred, prob, time_ms = detector.predict(test['data'])
        assessment = detector.assess_risk(pred, prob, test['data'])
        
        print(f"Result: {assessment['status']}")
        print(f"Risk Level: {assessment['risk']}")
        print(f"Confidence: {assessment['confidence']:.1%}")
        print(f"Probability: {assessment['probability']:.3f}")
        print(f"Inference Time: {time_ms:.2f}ms")
        
        if assessment['alerts']:
            print("🚨 Alerts:")
            for alert in assessment['alerts']:
                print(f"   {alert}")

def interactive_test():
    """Interactive testing function"""
    print("\n🎮 Interactive Testing Mode")
    print("=" * 30)
    
    detector = QuickAthleteDetector()
    
    while True:
        try:
            print("\nEnter athlete data (or 'quit' to exit):")
            
            heart_rate = input("Heart Rate (BPM): ")
            if heart_rate.lower() == 'quit':
                break
            heart_rate = float(heart_rate)
            
            oxygen_level = float(input("Oxygen Level (%): "))
            fatigue_score = float(input("Fatigue Score (1-10): "))
            activity = input("Activity (Running/Cycling/Swimming): ")
            temperature = float(input("Body Temperature (°C): "))
            
            sample_data = {
                'HeartRate': heart_rate,
                'OxygenLevel': oxygen_level,
                'FatigueScore': fatigue_score,
                'Activity': activity,
                'tmp': temperature
            }
            
            pred, prob, time_ms = detector.predict(sample_data)
            assessment = detector.assess_risk(pred, prob, sample_data)
            
            print(f"\n🔍 ANALYSIS RESULT:")
            print(f"Status: {assessment['status']}")
            print(f"Risk Level: {assessment['risk']}")
            print(f"Confidence: {assessment['confidence']:.1%}")
            print(f"Processing Time: {time_ms:.2f}ms")
            
            if assessment['alerts']:
                print("\n🚨 ALERTS:")
                for alert in assessment['alerts']:
                    print(f"  {alert}")
            
            if pred == 1:
                print("\n🆘 RECOMMENDATION: Stop activity immediately and seek medical attention!")
            else:
                print("\n✅ RECOMMENDATION: Continue monitoring. Stay hydrated!")
                
        except ValueError:
            print("❌ Please enter valid numbers")
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"❌ Error: {e}")

if __name__ == "__main__":
    demo()
    
    # Uncomment the line below to enable interactive testing
    # interactive_test() 