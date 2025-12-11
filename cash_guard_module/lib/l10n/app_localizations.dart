import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Tajik Material Localizations (based on Russian)
class TajikMaterialLocalizations extends DefaultMaterialLocalizations {
  const TajikMaterialLocalizations();

  @override
  String get okButtonLabel => 'ХУБ';

  @override
  String get cancelButtonLabel => 'БЕКОР';

  @override
  String get closeButtonLabel => 'ПӮШИДАН';

  @override
  String get continueButtonLabel => 'ИДОМА';

  @override
  String get copyButtonLabel => 'НУСХАБАРДОРӢ';

  @override
  String get cutButtonLabel => 'БУРИДАН';

  @override
  String get pasteButtonLabel => 'ГУЗОШТАН';

  @override
  String get selectAllButtonLabel => 'ҲАМАРО ИНТИХОБ КАРДАН';

  @override
  String get viewLicensesButtonLabel => 'ДИДАНИ ЛИТСЕНЗИЯҲО';

  @override
  String get searchFieldLabel => 'Ҷустуҷӯ';

  @override
  String get deleteButtonTooltip => 'Нест кардан';

  @override
  String get nextMonthTooltip => 'Моҳи оянда';

  @override
  String get previousMonthTooltip => 'Моҳи гузашта';

  @override
  String get nextPageTooltip => 'Саҳифаи оянда';

  @override
  String get previousPageTooltip => 'Саҳифаи гузашта';

  @override
  String get firstPageTooltip => 'Саҳифаи аввал';

  @override
  String get lastPageTooltip => 'Саҳифаи охирин';

  @override
  String get showMenuTooltip => 'Нишон додани меню';

  @override
  String get drawerLabel => 'Менюи навигатсия';

  @override
  String get popupMenuLabel => 'Менюи popup';

  @override
  String get dialogLabel => 'Диалог';

  @override
  String get alertDialogLabel => 'Огоҳӣ';

  @override
  String get licensesPageTitle => 'Литсензияҳо';

  @override
  String get saveButtonLabel => 'ЗАХИРА КАРДАН';

  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _TajikMaterialLocalizationsDelegate();
}

class _TajikMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _TajikMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tg';

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    return SynchronousFuture<MaterialLocalizations>(
      const TajikMaterialLocalizations(),
    );
  }

  @override
  bool shouldReload(_TajikMaterialLocalizationsDelegate old) => false;
}

// Tajik Cupertino Localizations
class TajikCupertinoLocalizations extends DefaultCupertinoLocalizations {
  const TajikCupertinoLocalizations();

  @override
  String get alertDialogLabel => 'Огоҳӣ';

  @override
  String get copyButtonLabel => 'Нусхабардорӣ';

  @override
  String get cutButtonLabel => 'Буридан';

  @override
  String get pasteButtonLabel => 'Гузоштан';

  @override
  String get selectAllButtonLabel => 'Ҳамаро интихоб кардан';

  @override
  String get searchTextFieldPlaceholderLabel => 'Ҷустуҷӯ';

  static const LocalizationsDelegate<CupertinoLocalizations> delegate =
      _TajikCupertinoLocalizationsDelegate();
}

class _TajikCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _TajikCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'tg';

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    return SynchronousFuture<CupertinoLocalizations>(
      const TajikCupertinoLocalizations(),
    );
  }

  @override
  bool shouldReload(_TajikCupertinoLocalizationsDelegate old) => false;
}

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('ru'), // Russian
    Locale('tg'), // Tajik
  ];

  static const Map<String, String> languageNames = {
    'en': 'English',
    'ru': 'Русский',
    'tg': 'Тоҷикӣ',
  };

  // Translations map
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Settings Screen
      'settings': 'Settings',
      'security': 'Security',
      'biometric_login': 'Biometric login',
      'biometric_unavailable': 'Biometrics unavailable on device',
      'biometric_not_enrolled': 'Biometrics not enrolled',
      'biometric_subtitle': 'Use fingerprint or Face ID to login',
      'appearance': 'Appearance',
      'light_theme': 'Light theme',
      'dark_theme': 'Dark theme',
      'system_theme': 'System theme',
      'data': 'Data',
      'backup_restore': 'Backup & Restore',
      'backup_subtitle': 'Backup your data',
      'danger_zone': 'Danger zone',
      'reset_all_data': 'Reset all data',
      'reset_subtitle': 'Delete password and all data',
      'version': 'Version',
      'protecting_finances': 'Protecting your finances',
      'language': 'Language',
      'select_language': 'Select language',

      // Dialogs
      'reset_password_title': 'Reset password?',
      'reset_password_message':
          'This will delete your current password and all financial data. Are you sure?',
      'cancel': 'Cancel',
      'reset': 'Reset',
      'enter_password': 'Enter password',
      'password': 'Password',
      'confirm': 'Confirm',
      'wrong_password': 'Wrong password',

      // Snackbar messages
      'biometric_enroll_first':
          'Please enroll biometric data in your device settings first.',
      'biometric_unavailable_msg': 'Biometrics unavailable on this device',
      'biometric_enabled': 'Biometrics enabled. You can now use it to login',
      'biometric_disabled': 'Biometrics disabled',

      // Lock Screen
      'enter_pin': 'Enter PIN',
      'create_pin': 'Create PIN',
      'confirm_pin': 'Confirm PIN',
      'pin_mismatch': 'PINs do not match',
      'use_biometrics': 'Use biometrics',
      'forgot_password': 'Forgot password?',

      // Home Screen
      'home': 'Home',
      'total_balance': 'Total Balance',
      'income': 'Income',
      'expenses': 'Expenses',
      'cash': 'Cash',
      'cards': 'Cards',
      'wallets': 'Wallets',
      'no_data': 'No data',

      // Transactions
      'transactions': 'Transactions',
      'add_transaction': 'Add transaction',
      'edit_transaction': 'Edit transaction',
      'amount': 'Amount',
      'description': 'Description',
      'category': 'Category',
      'date': 'Date',
      'type': 'Type',
      'income_type': 'Income',
      'expense_type': 'Expense',
      'save': 'Save',
      'delete': 'Delete',
      'no_transactions': 'No transactions yet',

      // Debts
      'debts': 'Debts',
      'add_debt': 'Add debt',
      'i_owe': 'I owe',
      'owe_me': 'Owe me',
      'person_name': 'Person name',
      'due_date': 'Due date',
      'mark_paid': 'Mark as paid',
      'no_debts': 'No debts',

      // Statistics
      'statistics': 'Statistics',
      'this_month': 'This month',
      'this_year': 'This year',
      'by_category': 'By category',
      'income_vs_expenses': 'Income vs Expenses',

      // Backup
      'create_backup': 'Create backup',
      'restore_backup': 'Restore backup',
      'backup_created': 'Backup created successfully',
      'backup_restored': 'Backup restored successfully',
      'backup_error': 'Backup error',

      // User Setup
      'setup_title': 'Setup your profile',
      'your_name': 'Your name',
      'initial_balance': 'Initial balance',
      'add_cash_location': 'Add cash location',
      'add_bank_card': 'Add bank card',
      'add_mobile_wallet': 'Add mobile wallet',
      'location_name': 'Location name',
      'card_name': 'Card name',
      'card_number': 'Card number (last 4 digits)',
      'wallet_name': 'Wallet name',
      'balance': 'Balance',
      'continue_btn': 'Continue',
      'skip': 'Skip',

      // Common
      'error': 'Error',
      'success': 'Success',
      'loading': 'Loading...',
      'retry': 'Retry',
      'close': 'Close',
      'edit': 'Edit',
      'add': 'Add',
      'remove': 'Remove',
      'yes': 'Yes',
      'no': 'No',
    },
    'ru': {
      // Settings Screen
      'settings': 'Настройки',
      'security': 'Безопасность',
      'biometric_login': 'Вход по биометрии',
      'biometric_unavailable': 'Биометрия недоступна на устройстве',
      'biometric_not_enrolled': 'Биометрия не зарегистрирована',
      'biometric_subtitle': 'Используйте отпечаток или Face ID для входа',
      'appearance': 'Внешний вид',
      'light_theme': 'Светлая тема',
      'dark_theme': 'Тёмная тема',
      'system_theme': 'Системная тема',
      'data': 'Данные',
      'backup_restore': 'Backup & Restore',
      'backup_subtitle': 'Резервное копирование',
      'danger_zone': 'Опасная зона',
      'reset_all_data': 'Сбросить все данные',
      'reset_subtitle': 'Удалить пароль и все данные',
      'version': 'Версия',
      'protecting_finances': 'Защита ваших финансов',
      'language': 'Язык',
      'select_language': 'Выберите язык',

      // Dialogs
      'reset_password_title': 'Сбросить пароль?',
      'reset_password_message':
          'Это удалит ваш текущий пароль и все финансовые данные. Вы уверены?',
      'cancel': 'Отмена',
      'reset': 'Сбросить',
      'enter_password': 'Введите пароль',
      'password': 'Пароль',
      'confirm': 'Подтвердить',
      'wrong_password': 'Неверный пароль',

      // Snackbar messages
      'biometric_enroll_first':
          'Сначала зарегистрируйте биометрические данные в настройках вашего устройства.',
      'biometric_unavailable_msg': 'Биометрия недоступна на этом устройстве',
      'biometric_enabled':
          'Биометрия включена. Теперь вы можете использовать её для входа',
      'biometric_disabled': 'Биометрия отключена',

      // Lock Screen
      'enter_pin': 'Введите PIN-код',
      'create_pin': 'Создайте PIN-код',
      'confirm_pin': 'Подтвердите PIN-код',
      'pin_mismatch': 'PIN-коды не совпадают',
      'use_biometrics': 'Использовать биометрию',
      'forgot_password': 'Забыли пароль?',

      // Home Screen
      'home': 'Главная',
      'total_balance': 'Общий баланс',
      'income': 'Доходы',
      'expenses': 'Расходы',
      'cash': 'Наличные',
      'cards': 'Карты',
      'wallets': 'Кошельки',
      'no_data': 'Нет данных',

      // Transactions
      'transactions': 'Транзакции',
      'add_transaction': 'Добавить транзакцию',
      'edit_transaction': 'Редактировать транзакцию',
      'amount': 'Сумма',
      'description': 'Описание',
      'category': 'Категория',
      'date': 'Дата',
      'type': 'Тип',
      'income_type': 'Доход',
      'expense_type': 'Расход',
      'save': 'Сохранить',
      'delete': 'Удалить',
      'no_transactions': 'Транзакций пока нет',

      // Debts
      'debts': 'Долги',
      'add_debt': 'Добавить долг',
      'i_owe': 'Я должен',
      'owe_me': 'Мне должны',
      'person_name': 'Имя человека',
      'due_date': 'Срок возврата',
      'mark_paid': 'Отметить оплаченным',
      'no_debts': 'Долгов нет',

      // Statistics
      'statistics': 'Статистика',
      'this_month': 'Этот месяц',
      'this_year': 'Этот год',
      'by_category': 'По категориям',
      'income_vs_expenses': 'Доходы vs Расходы',

      // Backup
      'create_backup': 'Создать резервную копию',
      'restore_backup': 'Восстановить из копии',
      'backup_created': 'Резервная копия создана успешно',
      'backup_restored': 'Данные восстановлены успешно',
      'backup_error': 'Ошибка резервного копирования',

      // User Setup
      'setup_title': 'Настройка профиля',
      'your_name': 'Ваше имя',
      'initial_balance': 'Начальный баланс',
      'add_cash_location': 'Добавить место хранения',
      'add_bank_card': 'Добавить банковскую карту',
      'add_mobile_wallet': 'Добавить мобильный кошелёк',
      'location_name': 'Название места',
      'card_name': 'Название карты',
      'card_number': 'Номер карты (последние 4 цифры)',
      'wallet_name': 'Название кошелька',
      'balance': 'Баланс',
      'continue_btn': 'Продолжить',
      'skip': 'Пропустить',

      // Common
      'error': 'Ошибка',
      'success': 'Успешно',
      'loading': 'Загрузка...',
      'retry': 'Повторить',
      'close': 'Закрыть',
      'edit': 'Редактировать',
      'add': 'Добавить',
      'remove': 'Удалить',
      'yes': 'Да',
      'no': 'Нет',
    },
    'tg': {
      // Settings Screen
      'settings': 'Танзимот',
      'security': 'Амният',
      'biometric_login': 'Воридшавӣ бо биометрия',
      'biometric_unavailable': 'Биометрия дар дастгоҳ дастрас нест',
      'biometric_not_enrolled': 'Биометрия сабт нашудааст',
      'biometric_subtitle':
          'Барои воридшавӣ нақши ангушт ё Face ID истифода баред',
      'appearance': 'Намуди зоҳирӣ',
      'light_theme': 'Мавзӯи равшан',
      'dark_theme': 'Мавзӯи торик',
      'system_theme': 'Мавзӯи система',
      'data': 'Маълумот',
      'backup_restore': 'Нусхаи эҳтиётӣ',
      'backup_subtitle': 'Нусхабардории маълумот',
      'danger_zone': 'Минтақаи хатарнок',
      'reset_all_data': 'Нест кардани ҳама маълумот',
      'reset_subtitle': 'Нест кардани рамз ва ҳама маълумот',
      'version': 'Версия',
      'protecting_finances': 'Ҳифзи молияи шумо',
      'language': 'Забон',
      'select_language': 'Забонро интихоб кунед',

      // Dialogs
      'reset_password_title': 'Рамзро нест кунед?',
      'reset_password_message':
          'Ин рамзи ҷориятон ва ҳама маълумоти молиявиро нест мекунад. Шумо боварӣ доред?',
      'cancel': 'Бекор кардан',
      'reset': 'Нест кардан',
      'enter_password': 'Рамзро ворид кунед',
      'password': 'Рамз',
      'confirm': 'Тасдиқ кардан',
      'wrong_password': 'Рамзи нодуруст',

      // Snackbar messages
      'biometric_enroll_first':
          'Аввал маълумоти биометрӣ дар танзимоти дастгоҳ сабт кунед.',
      'biometric_unavailable_msg': 'Биометрия дар ин дастгоҳ дастрас нест',
      'biometric_enabled':
          'Биометрия фаъол шуд. Акнун шумо метавонед онро барои воридшавӣ истифода баред',
      'biometric_disabled': 'Биометрия хомӯш карда шуд',

      // Lock Screen
      'enter_pin': 'PIN-кодро ворид кунед',
      'create_pin': 'PIN-код созед',
      'confirm_pin': 'PIN-кодро тасдиқ кунед',
      'pin_mismatch': 'PIN-кодҳо мувофиқат намекунанд',
      'use_biometrics': 'Истифодаи биометрия',
      'forgot_password': 'Рамзро фаромӯш кардед?',

      // Home Screen
      'home': 'Асосӣ',
      'total_balance': 'Баланси умумӣ',
      'income': 'Даромад',
      'expenses': 'Харҷҳо',
      'cash': 'Нақд',
      'cards': 'Кортҳо',
      'wallets': 'Ҳамёнҳо',
      'no_data': 'Маълумот нест',

      // Transactions
      'transactions': 'Амалиётҳо',
      'add_transaction': 'Илова кардани амалиёт',
      'edit_transaction': 'Таҳрир кардани амалиёт',
      'amount': 'Маблағ',
      'description': 'Тавсиф',
      'category': 'Категория',
      'date': 'Сана',
      'type': 'Намуд',
      'income_type': 'Даромад',
      'expense_type': 'Харҷ',
      'save': 'Захира кардан',
      'delete': 'Нест кардан',
      'no_transactions': 'Ҳоло амалиёт нест',

      // Debts
      'debts': 'Қарзҳо',
      'add_debt': 'Илова кардани қарз',
      'i_owe': 'Ман қарздорам',
      'owe_me': 'Ба ман қарздоранд',
      'person_name': 'Номи шахс',
      'due_date': 'Мӯҳлати баргардонидан',
      'mark_paid': 'Пардохт шуд',
      'no_debts': 'Қарз нест',

      // Statistics
      'statistics': 'Омор',
      'this_month': 'Ин моҳ',
      'this_year': 'Ин сол',
      'by_category': 'Аз рӯи категория',
      'income_vs_expenses': 'Даромад vs Харҷҳо',

      // Backup
      'create_backup': 'Сохтани нусхаи эҳтиётӣ',
      'restore_backup': 'Барқарор кардан аз нусха',
      'backup_created': 'Нусхаи эҳтиётӣ бомуваффақият сохта шуд',
      'backup_restored': 'Маълумот бомуваффақият барқарор карда шуд',
      'backup_error': 'Хатои нусхабардорӣ',

      // User Setup
      'setup_title': 'Танзими профил',
      'your_name': 'Номи шумо',
      'initial_balance': 'Баланси ибтидоӣ',
      'add_cash_location': 'Илова кардани ҷои нигоҳдорӣ',
      'add_bank_card': 'Илова кардани корти бонкӣ',
      'add_mobile_wallet': 'Илова кардани ҳамёни мобилӣ',
      'location_name': 'Номи ҷой',
      'card_name': 'Номи корт',
      'card_number': 'Рақами корт (4 рақами охирин)',
      'wallet_name': 'Номи ҳамён',
      'balance': 'Баланс',
      'continue_btn': 'Идома додан',
      'skip': 'Гузаштан',

      // Common
      'error': 'Хато',
      'success': 'Муваффақият',
      'loading': 'Боркунӣ...',
      'retry': 'Такрор кардан',
      'close': 'Пӯшидан',
      'edit': 'Таҳрир кардан',
      'add': 'Илова кардан',
      'remove': 'Нест кардан',
      'yes': 'Ҳа',
      'no': 'Не',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  // Convenience getters for common strings
  String get settings => translate('settings');
  String get security => translate('security');
  String get biometricLogin => translate('biometric_login');
  String get biometricUnavailable => translate('biometric_unavailable');
  String get biometricNotEnrolled => translate('biometric_not_enrolled');
  String get biometricSubtitle => translate('biometric_subtitle');
  String get appearance => translate('appearance');
  String get lightTheme => translate('light_theme');
  String get darkTheme => translate('dark_theme');
  String get systemTheme => translate('system_theme');
  String get data => translate('data');
  String get backupRestore => translate('backup_restore');
  String get backupSubtitle => translate('backup_subtitle');
  String get dangerZone => translate('danger_zone');
  String get resetAllData => translate('reset_all_data');
  String get resetSubtitle => translate('reset_subtitle');
  String get version => translate('version');
  String get protectingFinances => translate('protecting_finances');
  String get language => translate('language');
  String get selectLanguage => translate('select_language');
  String get resetPasswordTitle => translate('reset_password_title');
  String get resetPasswordMessage => translate('reset_password_message');
  String get cancel => translate('cancel');
  String get reset => translate('reset');
  String get enterPassword => translate('enter_password');
  String get password => translate('password');
  String get confirm => translate('confirm');
  String get wrongPassword => translate('wrong_password');
  String get biometricEnrollFirst => translate('biometric_enroll_first');
  String get biometricUnavailableMsg => translate('biometric_unavailable_msg');
  String get biometricEnabled => translate('biometric_enabled');
  String get biometricDisabled => translate('biometric_disabled');
  String get enterPin => translate('enter_pin');
  String get createPin => translate('create_pin');
  String get confirmPin => translate('confirm_pin');
  String get pinMismatch => translate('pin_mismatch');
  String get useBiometrics => translate('use_biometrics');
  String get forgotPassword => translate('forgot_password');
  String get home => translate('home');
  String get totalBalance => translate('total_balance');
  String get income => translate('income');
  String get expenses => translate('expenses');
  String get cash => translate('cash');
  String get cards => translate('cards');
  String get wallets => translate('wallets');
  String get noData => translate('no_data');
  String get transactions => translate('transactions');
  String get addTransaction => translate('add_transaction');
  String get editTransaction => translate('edit_transaction');
  String get amount => translate('amount');
  String get description => translate('description');
  String get category => translate('category');
  String get date => translate('date');
  String get type => translate('type');
  String get incomeType => translate('income_type');
  String get expenseType => translate('expense_type');
  String get save => translate('save');
  String get delete => translate('delete');
  String get noTransactions => translate('no_transactions');
  String get debts => translate('debts');
  String get addDebt => translate('add_debt');
  String get iOwe => translate('i_owe');
  String get oweMe => translate('owe_me');
  String get personName => translate('person_name');
  String get dueDate => translate('due_date');
  String get markPaid => translate('mark_paid');
  String get noDebts => translate('no_debts');
  String get statistics => translate('statistics');
  String get thisMonth => translate('this_month');
  String get thisYear => translate('this_year');
  String get byCategory => translate('by_category');
  String get incomeVsExpenses => translate('income_vs_expenses');
  String get createBackup => translate('create_backup');
  String get restoreBackup => translate('restore_backup');
  String get backupCreated => translate('backup_created');
  String get backupRestored => translate('backup_restored');
  String get backupError => translate('backup_error');
  String get setupTitle => translate('setup_title');
  String get yourName => translate('your_name');
  String get initialBalance => translate('initial_balance');
  String get addCashLocation => translate('add_cash_location');
  String get addBankCard => translate('add_bank_card');
  String get addMobileWallet => translate('add_mobile_wallet');
  String get locationName => translate('location_name');
  String get cardName => translate('card_name');
  String get cardNumber => translate('card_number');
  String get walletName => translate('wallet_name');
  String get balance => translate('balance');
  String get continueBtn => translate('continue_btn');
  String get skip => translate('skip');
  String get error => translate('error');
  String get success => translate('success');
  String get loading => translate('loading');
  String get retry => translate('retry');
  String get close => translate('close');
  String get edit => translate('edit');
  String get add => translate('add');
  String get remove => translate('remove');
  String get yes => translate('yes');
  String get no => translate('no');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ru', 'tg'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
