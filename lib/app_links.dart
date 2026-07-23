class AppLinks {
  static final Uri instagram = Uri.parse(
    'https://www.instagram.com/emr.core?igsh=amtrcmhtNWhsa291',
  );

  static final Uri privacyPolicy = Uri.parse(
    'https://emrcore.com/santiye-privacy/',
  );

  static final Uri termsOfUse = Uri.parse(
    'https://emrcore.com/kullanim-sartlari/',
  );

  static final Uri supportEmail = Uri(
    scheme: 'mailto',
    path: 'info@emrcore.com',
    queryParameters: {
      'subject': 'Santiye Puantaj Defteri Destek',
    },
  );
}
