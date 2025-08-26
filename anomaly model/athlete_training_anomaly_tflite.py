import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score, roc_auc_score
import joblib
import os

print("TensorFlow version:", tf.__version__)

class AthleteAnomalyDetectorTFLite:
    def __init__(self):
        self.model = None
        self.scaler = StandardScaler()
        self.activity_encoder = LabelEncoder()
        self.feature_names = ['HeartRate', 'OxygenLevel', 'FatigueScore', 'tmp', 'Activity']
        self.tflite_model = None
        self.interpreter = None
        
    def load_and_preprocess_data(self, filepath):
        """Load and preprocess the dataset"""
        print("Loading data...")
        self.data = pd.read_csv(filepath)
        
        print("Dataset Info:")
        print(self.data.info())
        print("\nDataset Description:")
        print(self.data.describe())
        print("\nAnomaly Distribution:")
        print(self.data['Anomaly'].value_counts())
        
        return self.data
    
    def prepare_features(self, data):
        """Prepare features for training"""
        # Separate features and target
        X = data.drop('Anomaly', axis=1).copy()
        y = data['Anomaly'].values
        
        # Encode categorical variable
        X['Activity_encoded'] = self.activity_encoder.fit_transform(X['Activity'])
        
        # Select numerical features
        feature_columns = ['HeartRate', 'OxygenLevel', 'FatigueScore', 'tmp', 'Activity_encoded']
        X_processed = X[feature_columns].values
        
        # Scale features
        X_scaled = self.scaler.fit_transform(X_processed)
        
        return X_scaled, y
    
    def build_model(self, input_shape):
        """Build neural network model"""
        model = keras.Sequential([
            layers.Dense(64, activation='relu', input_shape=(input_shape,)),
            layers.Dropout(0.3),
            layers.Dense(32, activation='relu'),
            layers.Dropout(0.2),
            layers.Dense(16, activation='relu'),
            layers.Dense(1, activation='sigmoid')
        ])
        
        model.compile(
            optimizer='adam',
            loss='binary_crossentropy',
            metrics=['accuracy', 'precision', 'recall']
        )
        
        return model
    
    def train_model(self, X_train, y_train, X_val, y_val, epochs=100, batch_size=32):
        """Train the neural network"""
        print("Training model...")
        
        # Build model
        self.model = self.build_model(X_train.shape[1])
        
        print("Model Architecture:")
        self.model.summary()
        
        # Callbacks
        early_stopping = keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=15,
            restore_best_weights=True
        )
        
        reduce_lr = keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.2,
            patience=10,
            min_lr=0.001
        )
        
        # Calculate class weights for imbalanced dataset
        class_weight = {
            0: 1.0,
            1: len(y_train[y_train == 0]) / len(y_train[y_train == 1])
        }
        
        # Train model
        history = self.model.fit(
            X_train, y_train,
            epochs=epochs,
            batch_size=batch_size,
            validation_data=(X_val, y_val),
            callbacks=[early_stopping, reduce_lr],
            class_weight=class_weight,
            verbose=1
        )
        
        return history
    
    def convert_to_tflite(self, model_save_path="athlete_model.tflite"):
        """Convert trained model to TensorFlow Lite"""
        print("Converting model to TensorFlow Lite...")
        
        # Convert to TensorFlow Lite
        converter = tf.lite.TFLiteConverter.from_keras_model(self.model)
        
        # Optimize the model
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        
        # Convert
        self.tflite_model = converter.convert()
        
        # Save the model
        with open(model_save_path, 'wb') as f:
            f.write(self.tflite_model)
        
        print(f"TFLite model saved to {model_save_path}")
        
        # Initialize interpreter
        self.interpreter = tf.lite.Interpreter(model_content=self.tflite_model)
        self.interpreter.allocate_tensors()
        
        return model_save_path
    
    def predict_with_tflite(self, input_data):
        """Make predictions using TFLite model"""
        if self.interpreter is None:
            raise ValueError("TFLite model not loaded. Please convert model first.")
        
        # Get input and output tensors
        input_details = self.interpreter.get_input_details()
        output_details = self.interpreter.get_output_details()
        
        # Prepare input data
        input_data = np.array(input_data, dtype=np.float32)
        if len(input_data.shape) == 1:
            input_data = input_data.reshape(1, -1)
        
        # Set input tensor
        self.interpreter.set_tensor(input_details[0]['index'], input_data)
        
        # Run inference
        self.interpreter.invoke()
        
        # Get output
        output_data = self.interpreter.get_tensor(output_details[0]['index'])
        
        return output_data
    
    def evaluate_model(self, X_test, y_test):
        """Evaluate the model performance"""
        print("Evaluating model...")
        
        # Regular model predictions
        y_pred_prob = self.model.predict(X_test)
        y_pred = (y_pred_prob > 0.5).astype(int).flatten()
        y_pred_prob = y_pred_prob.flatten()
        
        # TFLite model predictions
        y_pred_tflite_prob = []
        for i in range(len(X_test)):
            pred = self.predict_with_tflite(X_test[i:i+1])
            y_pred_tflite_prob.append(pred[0][0])
        
        y_pred_tflite_prob = np.array(y_pred_tflite_prob)
        y_pred_tflite = (y_pred_tflite_prob > 0.5).astype(int)
        
        # Calculate metrics
        accuracy_keras = accuracy_score(y_test, y_pred)
        accuracy_tflite = accuracy_score(y_test, y_pred_tflite)
        roc_auc_keras = roc_auc_score(y_test, y_pred_prob)
        roc_auc_tflite = roc_auc_score(y_test, y_pred_tflite_prob)
        
        print("\n=== MODEL COMPARISON ===")
        print(f"Keras Model - Accuracy: {accuracy_keras:.4f}, ROC AUC: {roc_auc_keras:.4f}")
        print(f"TFLite Model - Accuracy: {accuracy_tflite:.4f}, ROC AUC: {roc_auc_tflite:.4f}")
        
        print("\n=== KERAS MODEL REPORT ===")
        print(classification_report(y_test, y_pred))
        
        print("\n=== TFLITE MODEL REPORT ===")
        print(classification_report(y_test, y_pred_tflite))
        
        return {
            'keras': {'accuracy': accuracy_keras, 'roc_auc': roc_auc_keras},
            'tflite': {'accuracy': accuracy_tflite, 'roc_auc': roc_auc_tflite}
        }
    
    def preprocess_single_sample(self, sample_data):
        """Preprocess a single sample for prediction"""
        if isinstance(sample_data, dict):
            # Convert dict to the required format
            activity_encoded = self.activity_encoder.transform([sample_data['Activity']])[0]
            features = [
                sample_data['HeartRate'],
                sample_data['OxygenLevel'], 
                sample_data['FatigueScore'],
                sample_data['tmp'],
                activity_encoded
            ]
        else:
            features = sample_data
        
        # Scale the features
        features_array = np.array(features).reshape(1, -1)
        features_scaled = self.scaler.transform(features_array)
        
        return features_scaled
    
    def predict_anomaly(self, sample_data, use_tflite=True):
        """Predict if a sample is an anomaly"""
        # Preprocess the sample
        processed_sample = self.preprocess_single_sample(sample_data)
        
        if use_tflite and self.interpreter is not None:
            # Use TFLite model
            probability = self.predict_with_tflite(processed_sample)[0][0]
        else:
            # Use Keras model
            probability = self.model.predict(processed_sample, verbose=0)[0][0]
        
        prediction = 1 if probability > 0.5 else 0
        
        return prediction, float(probability)
    
    def get_anomaly_feedback(self, prediction, probability, sample):
        """Generate detailed feedback for the prediction"""
        feedback = {
            'decision': 'Normal' if prediction == 0 else 'Anomalie',
            'confidence': probability if prediction == 1 else 1 - probability,
            'risk_level': None,
            'key_factors': [],
            'recommendations': []
        }
        
        # Define thresholds
        thresholds = {
            'HeartRate': {'low': 50, 'high': 160},
            'OxygenLevel': {'low': 90, 'high': 100},
            'FatigueScore': {'low': 1, 'high': 7},
            'tmp': {'low': 36.0, 'high': 38.0}
        }
        
        # Analyze metrics
        for metric in thresholds:
            if metric in sample:
                value = sample[metric]
                if value < thresholds[metric]['low']:
                    feedback['key_factors'].append(f"{metric} très bas ({value})")
                elif value > thresholds[metric]['high']:
                    feedback['key_factors'].append(f"{metric} très élevé ({value})")
        
        # Risk level based on probability
        if probability < 0.05:
            feedback['risk_level'] = 'Négligeable'
        elif probability < 0.2:
            feedback['risk_level'] = 'Très faible'
        elif probability < 0.5:
            feedback['risk_level'] = 'Modéré'
        else:
            feedback['risk_level'] = 'Élevé'
        
        # Recommendations
        if not feedback['key_factors']:
            feedback['key_factors'].append('Tous les paramètres dans les normes')
            
        if prediction == 0:
            feedback['recommendations'].append('Continuer le monitoring standard')
            if probability > 0.3:
                feedback['recommendations'].append('Surveiller l\'évolution')
        else:
            feedback['recommendations'].append('Arrêt immédiat recommandé')
            feedback['recommendations'].append('Consultation médicale urgente')
        
        return feedback
    
    def save_preprocessing_objects(self, scaler_path="scaler.pkl", encoder_path="activity_encoder.pkl"):
        """Save preprocessing objects"""
        joblib.dump(self.scaler, scaler_path)
        joblib.dump(self.activity_encoder, encoder_path)
        print(f"Preprocessing objects saved: {scaler_path}, {encoder_path}")
    
    def load_preprocessing_objects(self, scaler_path="scaler.pkl", encoder_path="activity_encoder.pkl"):
        """Load preprocessing objects"""
        self.scaler = joblib.load(scaler_path)
        self.activity_encoder = joblib.load(encoder_path)
        print("Preprocessing objects loaded successfully")
    
    def load_tflite_model(self, model_path="athlete_model.tflite"):
        """Load TFLite model for inference"""
        with open(model_path, 'rb') as f:
            self.tflite_model = f.read()
        
        self.interpreter = tf.lite.Interpreter(model_content=self.tflite_model)
        self.interpreter.allocate_tensors()
        print(f"TFLite model loaded from {model_path}")

def main():
    # Initialize detector
    detector = AthleteAnomalyDetectorTFLite()
    
    # Load and preprocess data
    data = detector.load_and_preprocess_data("AthleteTraining_anomaly.csv")
    
    # Visualize data distribution
    plt.figure(figsize=(10, 6))
    plt.subplot(1, 2, 1)
    sns.countplot(x='Anomaly', data=data)
    plt.title('Distribution des Anomalies')
    
    plt.subplot(1, 2, 2)
    sns.boxplot(x='Anomaly', y='HeartRate', data=data)
    plt.title('HeartRate par Anomalie')
    plt.tight_layout()
    plt.show()
    
    # Prepare features
    X, y = detector.prepare_features(data)
    
    # Split data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.3, random_state=42, stratify=y
    )
    
    X_train, X_val, y_train, y_val = train_test_split(
        X_train, y_train, test_size=0.2, random_state=42, stratify=y_train
    )
    
    print(f"Training set: {X_train.shape}")
    print(f"Validation set: {X_val.shape}")
    print(f"Test set: {X_test.shape}")
    
    # Train model
    history = detector.train_model(X_train, y_train, X_val, y_val, epochs=100)
    
    # Plot training history
    plt.figure(figsize=(12, 4))
    
    plt.subplot(1, 2, 1)
    plt.plot(history.history['loss'], label='Training Loss')
    plt.plot(history.history['val_loss'], label='Validation Loss')
    plt.title('Model Loss')
    plt.xlabel('Epoch')
    plt.ylabel('Loss')
    plt.legend()
    
    plt.subplot(1, 2, 2)
    plt.plot(history.history['accuracy'], label='Training Accuracy')
    plt.plot(history.history['val_accuracy'], label='Validation Accuracy')
    plt.title('Model Accuracy')
    plt.xlabel('Epoch')
    plt.ylabel('Accuracy')
    plt.legend()
    
    plt.tight_layout()
    plt.show()
    
    # Convert to TFLite
    tflite_model_path = detector.convert_to_tflite()
    
    # Evaluate models
    results = detector.evaluate_model(X_test, y_test)
    
    # Save preprocessing objects
    detector.save_preprocessing_objects()
    
    # Test with sample data
    sample_data = {
        'HeartRate': 140.0,
        'OxygenLevel': 95.0,
        'FatigueScore': 5.0,
        'Activity': 'Running',
        'tmp': 37.4
    }
    
    print("\n=== SAMPLE PREDICTION ===")
    
    # Test with Keras model
    pred_keras, prob_keras = detector.predict_anomaly(sample_data, use_tflite=False)
    print(f"Keras Model - Prediction: {'Anomalie' if pred_keras == 1 else 'Normal'}, Probability: {prob_keras:.4f}")
    
    # Test with TFLite model
    pred_tflite, prob_tflite = detector.predict_anomaly(sample_data, use_tflite=True)
    print(f"TFLite Model - Prediction: {'Anomalie' if pred_tflite == 1 else 'Normal'}, Probability: {prob_tflite:.4f}")
    
    # Get detailed feedback
    feedback = detector.get_anomaly_feedback(pred_tflite, prob_tflite, sample_data)
    
    print("\n=== FEEDBACK DÉTAILLÉ ===")
    print(f"Résultat: {feedback['decision']}")
    print(f"Confiance: {feedback['confidence']:.1%}")
    print(f"Niveau de risque: {feedback['risk_level']}")
    print("\nFacteurs influents:")
    for factor in feedback['key_factors']:
        print(f"- {factor}")
    print("\nRecommandations:")
    for rec in feedback['recommendations']:
        print(f"- {rec}")
    
    # Model size comparison
    keras_size = os.path.getsize("athlete_model.h5") if os.path.exists("athlete_model.h5") else 0
    tflite_size = os.path.getsize(tflite_model_path)
    
    print(f"\n=== MODEL SIZE COMPARISON ===")
    print(f"TFLite Model Size: {tflite_size / 1024:.2f} KB")
    if keras_size > 0:
        print(f"Size reduction: {(1 - tflite_size/keras_size)*100:.1f}%")

if __name__ == "__main__":
    main() 