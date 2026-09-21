import argparse
import numpy as np
import tensorflow as tf
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from preprocessing.audio_features import load_audio, segment_audio, compute_log_mel_spectrogram, normalize_features
from preprocessing.dataset_builder import CLASS_NAMES

def parse_args():
    parser = argparse.ArgumentParser(description="Run inference using TFLite model")
    parser.add_argument('--model_path', type=str, required=True, help='Path to .tflite model')
    parser.add_argument('--audio_path', type=str, required=True, help='Path to audio file')
    return parser.parse_args()

def main():
    args = parse_args()
    
    # Load TFLite model and allocate tensors
    interpreter = tf.lite.Interpreter(model_path=args.model_path)
    interpreter.allocate_tensors()
    
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    # Preprocess audio
    print(f"Processing audio: {args.audio_path}")
    audio = load_audio(args.audio_path, sr=16000)
    segments = segment_audio(audio, sr=16000, segment_duration=0.25)
    
    if not segments:
        print("Audio too short or empty.")
        return
        
    segment = segments[0]  # Take first segment for simple test
    spec = compute_log_mel_spectrogram(segment, sr=16000)
    spec = normalize_features(spec)
    
    # Prepare input tensor: [1, 1, 40, 26] approx
    input_data = np.expand_dims(spec, axis=0)
    input_data = np.expand_dims(input_data, axis=0).astype(np.float32)
    
    # Check if shape matches
    expected_shape = input_details[0]['shape']
    if list(input_data.shape) != list(expected_shape):
        print(f"Warning: Input shape {input_data.shape} does not match expected {expected_shape}. Resizing...")
        interpreter.resize_tensor_input(input_details[0]['index'], input_data.shape)
        interpreter.allocate_tensors()
        
    # Run inference
    interpreter.set_tensor(input_details[0]['index'], input_data)
    interpreter.invoke()
    
    output_data = interpreter.get_tensor(output_details[0]['index'])
    
    # Softmax
    probs = tf.nn.softmax(output_data[0]).numpy()
    pred_idx = np.argmax(probs)
    
    print("\n--- Prediction Results ---")
    print(f"Predicted Class: {CLASS_NAMES[pred_idx]}")
    print("Confidence Scores:")
    for i, name in enumerate(CLASS_NAMES):
        print(f"  {name}: {probs[i]*100:.2f}%")

if __name__ == '__main__':
    main()
