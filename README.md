# VWallet - Web3 Crypto Wallet

Ví tiền mã hóa đơn giản, an toàn và dễ sử dụng được xây dựng bằng Flutter.

## 🚀 Tính năng

### ✅ Đã hoàn thành (MVP)
- **Tạo ví mới** với 12 từ khôi phục (BIP39)
- **Nhập ví** từ cụm từ khôi phục hoặc private key
- **Hiển thị số dư** native token (ETH, BNB, MATIC, etc.)
- **Gửi crypto** với ước tính gas fee rõ ràng
- **Nhận crypto** với QR code
- **Multi-chain support**: Ethereum, BSC, Polygon, Arbitrum, Optimism, Avalanche
- **Bảo mật**: Encrypted storage cho private keys
- **UI/UX**: Thiết kế hiện đại, hỗ trợ dark/light mode

### 🔜 Sắp ra mắt
- [ ] Swap tokens (DEX aggregator)
- [ ] NFT gallery
- [ ] Transaction history
- [ ] Price charts
- [ ] Biometric authentication
- [ ] QR scanner
- [ ] Push notifications
- [ ] Fiat on-ramp integration

## 📁 Cấu trúc Project

```
lib/
├── main.dart                     # Entry point
├── core/
│   ├── constants/
│   │   └── app_theme.dart        # Theme, colors, constants
│   ├── models/
│   │   ├── network.dart          # Blockchain networks
│   │   ├── token.dart            # Token & balance
│   │   ├── transaction.dart      # Transaction model
│   │   └── wallet.dart           # Wallet model
│   ├── services/
│   │   ├── blockchain_service.dart   # RPC interactions
│   │   ├── secure_storage_service.dart   # Encrypted storage
│   │   └── wallet_service.dart   # Wallet generation/import
│   └── providers/
│       └── wallet_provider.dart  # State management
├── features/
│   ├── onboarding/
│   │   ├── onboarding_screen.dart
│   │   ├── create_wallet_screen.dart
│   │   └── import_wallet_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── send/
│   │   └── send_screen.dart
│   ├── receive/
│   │   └── receive_screen.dart
│   └── settings/
│       └── settings_screen.dart
└── shared/
    └── widgets/
        └── common_widgets.dart   # Reusable UI components
```

## 🛠 Tech Stack

- **Framework**: Flutter 3.x
- **State Management**: Riverpod
- **Crypto**: web3dart, bip39, bip32
- **Storage**: flutter_secure_storage, Hive
- **UI**: Material Design 3, Custom widgets

## 🚀 Cài đặt

### Prerequisites
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0

### Setup

```bash
# Clone repository
git clone <repo-url>
cd web3_wallet

# Install dependencies
flutter pub get

# Run app
flutter run
```

### Build

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## 🔐 Bảo mật

- Private keys được mã hóa và lưu trữ cục bộ bằng `flutter_secure_storage`
- Sử dụng Android Keystore / iOS Keychain
- Không có server backend - 100% non-custodial
- Mã nguồn có thể audit

## 📊 Kiến trúc

### Clean Architecture
```
┌─────────────────────────────────────────┐
│            Presentation Layer           │
│         (Screens, Widgets, UI)          │
├─────────────────────────────────────────┤
│            Business Logic               │
│         (Providers, State)              │
├─────────────────────────────────────────┤
│              Core Layer                 │
│       (Services, Models, Utils)         │
├─────────────────────────────────────────┤
│           External Services             │
│      (Blockchain RPC, Storage)          │
└─────────────────────────────────────────┘
```

### Data Flow
```
User Action → Provider → Service → Blockchain/Storage
                ↓
            State Update → UI Rebuild
```

## 🌐 Supported Networks

| Network | Chain ID | Symbol | Status |
|---------|----------|--------|--------|
| Ethereum | 1 | ETH | ✅ |
| BNB Smart Chain | 56 | BNB | ✅ |
| Polygon | 137 | MATIC | ✅ |
| Arbitrum One | 42161 | ETH | ✅ |
| Optimism | 10 | ETH | ✅ |
| Avalanche C-Chain | 43114 | AVAX | ✅ |

## 💰 Monetization (Planned)

1. **Swap fees**: 0.3-0.5% (thấp hơn thị trường)
2. **Referral links**: Binance, OKX, MEXC
3. **On-ramp commission**: MoonPay, Transak

## 📝 License

MIT License

## 🤝 Contributing

Contributions are welcome! Please read our contributing guidelines.

---

Made with ❤️ in Vietnam
