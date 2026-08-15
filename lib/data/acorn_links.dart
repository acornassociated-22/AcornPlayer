/// Contact, social and donate URLs shared with Acorn Video Downloader.
abstract final class AcornLinks {
  static const infoEmail = 'Info@acornassociated.org';
  static const salesEmail = 'Sales@acornassociated.org';
  static const supportEmail = 'Support@acornassociated.org';
  static const paypalEmail = 'acornassociatedorg@gmail.com';
  static const repo = 'https://github.com/acornassociated-22/AcornPlayer';
  static const site = 'https://www.Acornik.com';

  static const social = <({String id, String label, String href})>[
    (
      id: 'facebook',
      label: 'Facebook',
      href: 'https://www.facebook.com/share/1BHdij74U4/',
    ),
    (id: 'x', label: 'X', href: 'https://x.com/Acornassociate2'),
    (
      id: 'instagram',
      label: 'Instagram',
      href: 'https://www.instagram.com/acornassociated',
    ),
    (
      id: 'youtube',
      label: 'YouTube',
      href: 'https://youtube.com/@acornassociated',
    ),
    (id: 'telegram', label: 'Telegram', href: 'https://t.me/acornassociated'),
    (
      id: 'linkedin',
      label: 'LinkedIn',
      href: 'https://www.linkedin.com/in/acorn-associated-4715b4424',
    ),
    (
      id: 'github',
      label: 'GitHub',
      href: 'https://github.com/acornassociated-22',
    ),
    (id: 'medium', label: 'Medium', href: 'https://medium.com/@social_3025'),
    (
      id: 'reddit',
      label: 'Reddit',
      href: 'https://www.reddit.com/user/Acorn_Associated',
    ),
    (id: 'pinterest', label: 'Pinterest', href: 'https://pin.it/6aHftNn8p'),
  ];

  static const stripe5 =
      'https://donate.stripe.com/test_6oU6oH2ac2dpaOl9uRfQI00';
  static const stripe10 =
      'https://donate.stripe.com/test_5kQ28r168dW71dLgXjfQI01';
  static const stripe100 =
      'https://donate.stripe.com/test_14A6oH6qs7xJbSp9uRfQI03';
  static const stripeOther =
      'https://donate.stripe.com/test_3cI4gzg1219lcWtfTffQI02';

  /// PayPal Send Money URL for a preset amount, or no amount for Other.
  static String paypalSend([int? amount]) {
    final params = {
      'recipient': paypalEmail,
      'currencyCode': 'USD',
      'note': 'Acorn Associated support',
      if (amount != null) 'amount': '$amount',
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'https://www.paypal.com/myaccount/transfer/send/?$query';
  }
}
