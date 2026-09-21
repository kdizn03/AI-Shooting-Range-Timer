import argparse
import os
import torch
import numpy as np
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from training.model import AudioClassifierNet, print_model_summary
from preprocessing.dataset_builder import CLASS_NAMES

def parse_args():
    parser = argparse.ArgumentParser(description="Export PyTorch model to TFLite")
    parser.add_argument('--model_path', type=str, required=True, help='Path to trained .pth model')
    parser.add_argument('--output_dir', type=str, default='models', help='Directory to save exported models')
    return parser.parse_args()

def main():
    args = parse_args()
    Path(args.output_dir).mkdir(parents=True, exist_ok=True)
    
    # 1. Load PyTorch model
    print("Loading PyTorch model...")
    model = AudioClassifierNet(num_classes=len(CLASS_NAMES))
    model.load_state_dict(torch.load(args.model_path, map_location='cpu'))
    model.eval()
    
    # Ensure input shape matches Phase 5 spec: [batch, 1, 40, 26] approx
    dummy_input = torch.randn(1, 1, 40, 26)
    
    # 2. Export to ONNX
    onnx_path = os.path.join(args.output_dir, 'model.onnx')
    print(f"Exporting to ONNX: {onnx_path}")
    torch.onnx.export(
        model, dummy_input, onnx_path,
        export_params=True,
        opset_version=13,
        do_constant_folding=True,
        input_names=['input'],
        output_names=['output'],
        dynamic_axes={'input': {0: 'batch_size'}, 'output': {0: 'batch_size'}}
    )
    
    # 3. Convert ONNX to TF SavedModel
    print("Converting ONNX to TensorFlow SavedModel...")
    try:
        import onnx
        from onnx_tf.backend import prepare
    except ImportError:
        print("Error: onnx and onnx-tf are required. Please pip install onnx onnx-tf.")
        return
        
    onnx_model = onnx.load(onnx_path)
    tf_rep = prepare(onnx_model)
    
    tf_model_dir = os.path.join(args.output_dir, 'tf_saved_model')
    tf_rep.export_graph(tf_model_dir)
    
    # 4. Convert to TFLite
    print("Converting to TensorFlow Lite...")
    try:
        import tensorflow as tf
    except ImportError:
        print("Error: tensorflow is required.")
        return
        
    converter = tf.lite.TFLiteConverter.from_saved_model(tf_model_dir)
    
    # Enable Float16 Quantization
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    
    tflite_model = converter.convert()
    
    tflite_path = os.path.join(args.output_dir, 'shot_timer_model.tflite')
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
        
    print(f"TFLite model saved to {tflite_path}")
    
    # Compare sizes
    pth_size = os.path.getsize(args.model_path) / 1024
    tflite_size = os.path.getsize(tflite_path) / 1024
    
    print("\nModel Size Comparison:")
    print(f"PyTorch (.pth): {pth_size:.2f} KB")
    print(f"TFLite (FP16):  {tflite_size:.2f} KB")
    print("Export complete.")

if __name__ == '__main__':
    main()
