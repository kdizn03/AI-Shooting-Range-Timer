import torch
from torch.utils.data import Dataset, DataLoader
import numpy as np
from pathlib import Path
import json
from sklearn.model_selection import train_test_split
try:
    from .audio_features import load_audio, segment_audio, compute_log_mel_spectrogram, normalize_features, augment_audio
except (ImportError, ValueError):
    from preprocessing.audio_features import load_audio, segment_audio, compute_log_mel_spectrogram, normalize_features, augment_audio

CLASS_NAMES = ['gunshot', 'background_noise', 'voice', 'other_loud_sound', 'beep']
CLASS_TO_IDX = {name: idx for idx, name in enumerate(CLASS_NAMES)}

class AudioDataset(Dataset):
    """Dataset for audio classification."""
    
    def __init__(self, data_list, sr=16000, augment=False):
        """
        Args:
            data_list: List of dicts with 'path' and 'label'
            sr: Sample rate
            augment: Whether to apply augmentations
        """
        self.data_list = data_list
        self.sr = sr
        self.augment = augment
        
    def __len__(self):
        return len(self.data_list)
        
    def __getitem__(self, idx):
        item = self.data_list[idx]
        path = item['path']
        label = item['label']
        
        audio = load_audio(path, self.sr)
        
        # Take first 0.25s segment or pad
        segments = segment_audio(audio, sr=self.sr, segment_duration=0.25)
        segment = segments[0] if segments else np.zeros(int(self.sr * 0.25))
        
        if self.augment:
            segment = augment_audio(segment, sr=self.sr)
            
        spec = compute_log_mel_spectrogram(segment, sr=self.sr)
        spec = normalize_features(spec)
        
        # Add channel dimension
        spec = np.expand_dims(spec, axis=0)
        
        return torch.FloatTensor(spec), torch.tensor(label, dtype=torch.long)

def build_dataset_from_directory(root_dir: str):
    """Scan directory and build dataset list."""
    root_path = Path(root_dir)
    data_list = []
    
    for class_name in CLASS_NAMES:
        class_dir = root_path / class_name
        if not class_dir.exists():
            print(f"Warning: Directory {class_dir} does not exist.")
            continue
            
        for ext in ['*.wav', '*.mp3', '*.flac']:
            for file_path in class_dir.glob(ext):
                data_list.append({
                    'path': str(file_path),
                    'label': CLASS_TO_IDX[class_name]
                })
                
    return data_list

def split_dataset(data_list, train_ratio=0.7, val_ratio=0.15, test_ratio=0.15):
    """Split dataset into train, val, and test sets."""
    # Ensure ratios sum to 1
    assert abs((train_ratio + val_ratio + test_ratio) - 1.0) < 1e-5
    
    paths = [d['path'] for d in data_list]
    labels = [d['label'] for d in data_list]
    
    # First split: train vs (val + test)
    val_test_ratio = val_ratio + test_ratio
    try:
        from sklearn.model_selection import train_test_split
        train_list, val_test_list = train_test_split(
            data_list, test_size=val_test_ratio, stratify=labels, random_state=42
        )
        
        # Second split: val vs test
        val_labels = [d['label'] for d in val_test_list]
        test_ratio_relative = test_ratio / val_test_ratio
        
        val_list, test_list = train_test_split(
            val_test_list, test_size=test_ratio_relative, stratify=val_labels, random_state=42
        )
    except:
        # Fallback if stratify fails due to single sample classes
        print("Warning: Stratified split failed, using random split.")
        np.random.shuffle(data_list)
        n = len(data_list)
        n_train = int(n * train_ratio)
        n_val = int(n * val_ratio)
        
        train_list = data_list[:n_train]
        val_list = data_list[n_train:n_train+n_val]
        test_list = data_list[n_train+n_val:]
        
    return train_list, val_list, test_list

def get_dataloaders(root_dir, batch_size=32, num_workers=4):
    """Create dataloaders from directory."""
    data_list = build_dataset_from_directory(root_dir)
    
    if not data_list:
        raise ValueError(f"No audio files found in {root_dir}")
        
    train_list, val_list, test_list = split_dataset(data_list)
    
    # Calculate class weights for imbalance
    labels = [d['label'] for d in train_list]
    class_counts = np.bincount(labels, minlength=len(CLASS_NAMES))
    
    # Handle zero counts
    class_counts[class_counts == 0] = 1
    weights = 1. / torch.tensor(class_counts, dtype=torch.float)
    samples_weights = weights[labels]
    
    sampler = torch.utils.data.WeightedRandomSampler(
        weights=samples_weights,
        num_samples=len(samples_weights),
        replacement=True
    )
    
    train_dataset = AudioDataset(train_list, augment=True)
    val_dataset = AudioDataset(val_list, augment=False)
    test_dataset = AudioDataset(test_list, augment=False)
    
    train_loader = DataLoader(
        train_dataset, batch_size=batch_size, sampler=sampler,
        num_workers=num_workers, pin_memory=True
    )
    
    val_loader = DataLoader(
        val_dataset, batch_size=batch_size, shuffle=False,
        num_workers=num_workers, pin_memory=True
    )
    
    test_loader = DataLoader(
        test_dataset, batch_size=batch_size, shuffle=False,
        num_workers=num_workers, pin_memory=True
    )
    
    return train_loader, val_loader, test_loader, weights
