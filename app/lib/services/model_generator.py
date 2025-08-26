import pandas as pd
import numpy as np
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
import os

# Get absolute path to the dataset
DATASET_PATH = os.path.join(os.path.dirname(__file__), '..', 'assets', 'dataset', 'heart_rate_extended_with_feedback.csv')
MODEL_OUTPUT_PATH = os.path.join(os.path.dirname(__file__), '..', 'assets', 'models', 'heart_rate_model.tflite')

def clean_feedback(feedback):
    # Extract only the main zone part without warnings
    zone = feedback.split('.')[0]
    return zone

def load_and_preprocess_data():
    # Read the CSV file
    print(f"Loading data from: {DATASET_PATH}")
    df = pd.read_csv(DATASET_PATH, skipinitialspace=True)
    
    # Convert gender to binary (M=1, F=0)
    df['Gender'] = (df['Gender'] == 'M').astype(int)
    
    # Clean feedback data
    df['Feedback'] = df['Feedback'].apply(clean_feedback)
    
    # Remove rows with NaN values
    df = df.dropna()
    
    print("\nData after cleaning:")
    print(df.head())
    print("\nShape after cleaning:", df.shape)
    
    # Extract features
    X = df[['Gender', 'Age', 'hr', 'Temp']].values
    
    # Convert feedback to numerical labels
    label_encoder = LabelEncoder()
    y = label_encoder.fit_transform(df['Feedback'])
    
    # Save label mapping for later use
    label_mapping = dict(zip(label_encoder.classes_, range(len(label_encoder.classes_))))
    print("\nLabel mapping:", label_mapping)
    
    return X, y, label_mapping

def create_model(num_classes):
    model = tf.keras.Sequential([
        # Input layer
        tf.keras.layers.Input(shape=(4,)),
        
        # Hidden layers with regularization and batch normalization
        tf.keras.layers.Dense(32, activation='relu'),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.2),
        
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.2),
        
        tf.keras.layers.Dense(32, activation='relu'),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.2),
        
        # Output layer
        tf.keras.layers.Dense(num_classes, activation='softmax')
    ])
    
    return model

def train_model():
    # Load and preprocess data
    X, y, label_mapping = load_and_preprocess_data()
    num_classes = len(np.unique(y))
    
    # Split the data
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    # Create and compile model
    model = create_model(num_classes)
    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    # Train the model
    print("\nTraining model...")
    history = model.fit(
        X_train, y_train,
        validation_data=(X_test, y_test),
        epochs=50,
        batch_size=32,
        verbose=1
    )
    
    # Evaluate the model
    test_loss, test_accuracy = model.evaluate(X_test, y_test)
    print(f"\nTest accuracy: {test_accuracy:.2%}")
    
    # Convert to TFLite
    print("\nConverting to TFLite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    
    # Save the TFLite model
    os.makedirs(os.path.dirname(MODEL_OUTPUT_PATH), exist_ok=True)
    with open(MODEL_OUTPUT_PATH, 'wb') as f:
        f.write(tflite_model)
    print(f"\nTFLite model saved to: {MODEL_OUTPUT_PATH}")
    
    return label_mapping

def main():
    label_mapping = train_model()
    print("\nModel training completed!")
    print("Label mapping for reference:", label_mapping)

if __name__ == "__main__":
    main() 