import torch
import torch.nn as nn

class AudioClassifierNet(nn.Module):
    """
    Lightweight CNN for mobile audio classification.
    Target params: < 500K.
    Input shape: [batch, 1, 40, 26] (approx for 250ms at 16kHz, hop=160, n_mels=40)
    """
    def __init__(self, num_classes=5):
        super(AudioClassifierNet, self).__init__()
        
        # Block 1
        self.conv1 = nn.Conv2d(1, 16, kernel_size=3, padding=1, bias=False)
        self.bn1 = nn.BatchNorm2d(16)
        self.relu1 = nn.ReLU(inplace=True)
        self.pool1 = nn.MaxPool2d(2)
        
        # Block 2
        self.conv2 = nn.Conv2d(16, 32, kernel_size=3, padding=1, bias=False)
        self.bn2 = nn.BatchNorm2d(32)
        self.relu2 = nn.ReLU(inplace=True)
        self.pool2 = nn.MaxPool2d(2)
        
        # Block 3
        self.conv3 = nn.Conv2d(32, 64, kernel_size=3, padding=1, bias=False)
        self.bn3 = nn.BatchNorm2d(64)
        self.relu3 = nn.ReLU(inplace=True)
        self.pool3 = nn.MaxPool2d(2)
        
        # Block 4
        self.conv4 = nn.Conv2d(64, 64, kernel_size=3, padding=1, bias=False)
        self.bn4 = nn.BatchNorm2d(64)
        self.relu4 = nn.ReLU(inplace=True)
        
        # Global Average Pooling
        self.gap = nn.AdaptiveAvgPool2d((1, 1))
        
        # Fully Connected Layer
        self.fc = nn.Sequential(
            nn.Dropout(0.3),
            nn.Linear(64, num_classes)
        )

    def forward(self, x):
        x = self.pool1(self.relu1(self.bn1(self.conv1(x))))
        x = self.pool2(self.relu2(self.bn2(self.conv2(x))))
        x = self.pool3(self.relu3(self.bn3(self.conv3(x))))
        x = self.relu4(self.bn4(self.conv4(x)))
        
        x = self.gap(x)
        x = torch.flatten(x, 1)
        x = self.fc(x)
        return x

def print_model_summary(model, input_size=(1, 40, 26)):
    """Print model summary and parameter count."""
    total_params = sum(p.numel() for p in model.parameters())
    trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    
    print("=" * 50)
    print("Model Architecture:")
    print(model)
    print("=" * 50)
    print(f"Total Parameters: {total_params:,}")
    print(f"Trainable Parameters: {trainable_params:,}")
    print("=" * 50)
    
    if total_params > 500000:
        print("WARNING: Model exceeds 500K parameters!")
    else:
        print("Model size is within mobile constraints (< 500K).")

if __name__ == '__main__':
    model = AudioClassifierNet(num_classes=5)
    print_model_summary(model)
