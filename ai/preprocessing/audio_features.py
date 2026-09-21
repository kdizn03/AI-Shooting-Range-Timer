import librosa
import numpy as np
import soundfile as sf
import warnings
from pathlib import Path
from typing import List, Tuple, Optional

# Suppress librosa warnings for short audio files
warnings.filterwarnings('ignore', category=UserWarning)

def load_audio(path: str, sr: int = 16000) -> np.ndarray:
    """
    Load an audio file and resample it to the target sample rate.
    
    Args:
        path: Path to the audio file
        sr: Target sample rate
        
    Returns:
        Audio time series as a numpy array
    """
    audio, _ = librosa.load(path, sr=sr)
    return audio

def compute_log_mel_spectrogram(audio: np.ndarray, sr: int = 16000, 
                               n_mels: int = 40, n_fft: int = 512, 
                               hop_length: int = 160) -> np.ndarray:
    """
    Compute a log-Mel spectrogram from an audio signal.
    
    Args:
        audio: Audio time series
        sr: Sample rate
        n_mels: Number of Mel bands
        n_fft: FFT window size
        hop_length: Number of samples between successive frames
        
    Returns:
        Log-Mel spectrogram of shape (n_mels, t)
    """
    mel_spec = librosa.feature.melspectrogram(
        y=audio, sr=sr, n_fft=n_fft, hop_length=hop_length, n_mels=n_mels
    )
    log_mel_spec = librosa.power_to_db(mel_spec, ref=np.max)
    return log_mel_spec

def segment_audio(audio: np.ndarray, sr: int = 16000, 
                 segment_duration: float = 0.25) -> List[np.ndarray]:
    """
    Split audio into fixed-duration segments.
    
    Args:
        audio: Audio time series
        sr: Sample rate
        segment_duration: Duration of each segment in seconds
        
    Returns:
        List of audio segments
    """
    segment_length = int(sr * segment_duration)
    segments = []
    
    # Pad if shorter than one segment
    if len(audio) < segment_length:
        pad_width = segment_length - len(audio)
        audio = np.pad(audio, (0, pad_width), mode='constant')
        segments.append(audio)
        return segments
        
    for i in range(0, len(audio) - segment_length + 1, segment_length):
        segments.append(audio[i:i + segment_length])
        
    return segments

def augment_audio(audio: np.ndarray, sr: int = 16000) -> np.ndarray:
    """
    Apply random augmentations to the audio signal.
    
    Args:
        audio: Audio time series
        sr: Sample rate
        
    Returns:
        Augmented audio
    """
    aug_audio = audio.copy()
    
    # Random choice of augmentation
    aug_type = np.random.choice(['noise', 'time_shift', 'pitch_shift', 'volume', 'none'])
    
    if aug_type == 'noise':
        noise_amp = 0.005 * np.random.uniform() * np.amax(aug_audio)
        aug_audio = aug_audio + noise_amp * np.random.normal(size=aug_audio.shape[0])
    
    elif aug_type == 'time_shift':
        shift_max = sr // 10  # max 100ms
        shift = np.random.randint(-shift_max, shift_max)
        aug_audio = np.roll(aug_audio, shift)
        if shift > 0:
            aug_audio[:shift] = 0
        else:
            aug_audio[shift:] = 0
            
    elif aug_type == 'pitch_shift':
        # Librosa pitch shift is slow, use simple resampling for speed if needed, 
        # but librosa is standard.
        n_steps = np.random.uniform(-2, 2)
        aug_audio = librosa.effects.pitch_shift(aug_audio, sr=sr, n_steps=n_steps)
        
    elif aug_type == 'volume':
        gain = np.random.uniform(0.5, 1.5)
        aug_audio = aug_audio * gain
        
    return aug_audio

def normalize_features(features: np.ndarray) -> np.ndarray:
    """
    Normalize features to have zero mean and unit variance.
    
    Args:
        features: Input features (e.g., spectrogram)
        
    Returns:
        Normalized features
    """
    mean = np.mean(features)
    std = np.std(features)
    if std > 0:
        return (features - mean) / std
    return features

def preprocess_file(path: str, sr: int = 16000, 
                   augment: bool = False) -> List[Tuple[np.ndarray, dict]]:
    """
    Process an audio file into a list of spectrograms and metadata.
    
    Args:
        path: Path to the audio file
        sr: Target sample rate
        augment: Whether to apply augmentations
        
    Returns:
        List of tuples containing (spectrogram, metadata)
    """
    audio = load_audio(path, sr)
    segments = segment_audio(audio, sr=sr, segment_duration=0.25)
    
    results = []
    file_name = Path(path).name
    
    for i, segment in enumerate(segments):
        if augment:
            segment = augment_audio(segment, sr=sr)
            
        spec = compute_log_mel_spectrogram(segment, sr=sr)
        spec = normalize_features(spec)
        
        metadata = {
            'file': file_name,
            'segment_index': i,
            'original_length': len(segment)
        }
        
        results.append((spec, metadata))
        
    return results
