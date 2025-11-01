# Структура проекта CashGuard

```
cash_guard/
│
├── lib/
│   │
│   ├── main.dart                                 [Точка входа]
│   │   └── CashGuardApp → LockScreen
│   │
│   ├── models/                                   [Модели данных]
│   │   └── user_model.dart
│   │       ├── class User
│   │       │   ├── name: String
│   │       │   ├── cashInHand: double
│   │       │   ├── bankCards: List<BankCard>
│   │       │   └── totalBalance: double (computed)
│   │       │
│   │       └── class BankCard
│   │           ├── cardName: String
│   │           ├── cardNumber: String
│   │           ├── balance: double
│   │           ├── bankName: String?
│   │           └── maskedCardNumber: String (computed)
│   │
│   ├── services/                                 [Бизнес-логика]
│   │   │
│   │   ├── secure_storage_service.dart
│   │   │   └── class SecureStorageService
│   │   │       ├── setPassword(String)
│   │   │       ├── verifyPassword(String) → bool
│   │   │       ├── isPasswordSet() → bool
│   │   │       ├── deletePassword()
│   │   │       ├── saveUserData(User)
│   │   │       ├── getUserData() → User?
│   │   │       ├── isUserDataSet() → bool
│   │   │       └── clearAllData()
│   │   │
│   │   └── biometric_auth_service.dart
│   │       └── class BiometricAuthService
│   │           ├── canUseBiometrics() → bool
│   │           ├── getAvailableBiometrics() → List<BiometricType>
│   │           ├── authenticate() → bool
│   │           └── getBiometricErrorMessage() → String?
│   │
│   └── screens/                                  [UI экраны]
│       │
│       ├── lock_screen.dart
│       │   └── class LockScreen (StatefulWidget)
│       │       ├── Проверка пароля
│       │       ├── Создание нового пароля
│       │       ├── Биометрическая аутентификация
│       │       └── Навигация → UserSetupScreen | HomeScreen
│       │
│       ├── user_setup_screen.dart
│       │   └── class UserSetupScreen (StatefulWidget)
│       │       ├── Ввод имени
│       │       ├── Ввод суммы наличных
│       │       ├── Добавление банковских карт
│       │       │   └── class BankCardInput
│       │       │       ├── nameController
│       │       │       ├── numberController
│       │       │       ├── balanceController
│       │       │       └── bankController
│       │       └── Навигация → HomeScreen
│       │
│       └── home_screen.dart
│           └── class HomeScreen (StatefulWidget)
│               ├── Отображение общего баланса
│               ├── Отображение наличных
│               ├── Список банковских карт
│               ├── _BalanceCard (Widget)
│               ├── _BankCardItem (Widget)
│               └── Действия:
│                   ├── Редактировать профиль → UserSetupScreen
│                   └── Сбросить пароль → LockScreen
│
├── pubspec.yaml                                  [Зависимости]
│   ├── flutter
│   ├── local_auth: ^2.1.7
│   ├── flutter_secure_storage: ^9.0.0
│   └── crypto: ^3.0.3
│
└── README.md                                     [Документация]


═══════════════════════════════════════════════════════════════

НАВИГАЦИЯ ПРИЛОЖЕНИЯ:

┌─────────────────┐
│   LockScreen    │  ← Старт приложения
└────────┬────────┘
         │
         ├─ Пароль не установлен → Создать пароль
         └─ Пароль установлен → Ввод пароля / Биометрия
                │
                ├─ Успешная аутентификация
                │        │
                │        ├─ Данные пользователя есть
                │        │        │
                │        │        ┌────────────────┐
                │        │        │   HomeScreen   │
                │        │        └────────────────┘
                │        │
                │        └─ Данных пользователя нет
                │                 │
                │                 ┌──────────────────────┐
                │                 │ UserSetupScreen      │
                │                 └───────────┬──────────┘
                │                             │
                │                             │ Сохранить
                │                             ↓
                │                   ┌────────────────┐
                │                   │   HomeScreen   │
                │                   └────────────────┘
                │
                └─ Ошибка аутентификации → Повторить попытку


═══════════════════════════════════════════════════════════════

ХРАНЕНИЕ ДАННЫХ (Flutter Secure Storage):

┌─────────────────────────────────────────┐
│  Ключ            │  Значение            │
├─────────────────────────────────────────┤
│  'user_password' │  SHA-256 хеш пароля  │
│  'user_data'     │  JSON данные User    │
└─────────────────────────────────────────┘

Все данные зашифрованы AES-256