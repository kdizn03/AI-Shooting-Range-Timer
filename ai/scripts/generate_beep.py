import numpy as np
from scipy.io import wavfile
import os
from pathlib import Path

def generate_beep(freq=1000.0, duration=0.3, sr=16000, volume=0.8):
    """
    Generate a sine wave beep.
    
    Args:
        freq: Frequency in Hz (default 1000Hz)
        duration: Duration in seconds (default 0.3s)
        sr: Sample rate
        volume: Amplitude multiplier (0.0 to 1.0)
        
    Returns:
        numpy array of audio
    """
    t = np.linspace(0, duration, int(sr * duration), False)
    # Generate sine wave
    audio = np.sin(freq * 2 * np.pi * t)
    # Apply volume and convert to 16-bit PCM
    audio = (audio * volume * 32767).astype(np.int16)
    return audio

def main():
    sr = 16000
    beep_audio = generate_beep(sr=sr)
    
    # 1. Save to assets/sounds/ (for Flutter app)
    # The assets directory might be at the root level.
    # We are in ai/scripts/, so root is ../../
    root_dir = Path(__file__).parent.parent.parent
    assets_dir = root_dir / 'assets' / 'sounds'
    assets_dir.mkdir(parents=True, exist_ok=True)
    
    assets_path = assets_dir / 'beep.wav'
    wavfile.write(str(assets_path), sr, beep_audio)
    print(f"Saved app beep to: {assets_path}")
    
    # 2. Save to ai/dataset/beep/ (for training data)
    dataset_dir = Path(__file__).parent.parent / 'dataset' / 'beep'
    dataset_dir.mkdir(parents=True, exist_ok=True)
    
    dataset_path = dataset_dir / 'generated_beep.wav'
    wavfile.write(str(dataset_path), sr, beep_audio)
    print(f"Saved training beep to: {dataset_path}")

if __name__ == '__main__':
    main()
