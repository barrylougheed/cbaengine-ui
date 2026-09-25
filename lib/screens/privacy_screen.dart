import 'package:flutter/material.dart';

import '../config/app_config.dart';

/// The privacy notice (GDPR Articles 12–14), linked from the home screen
/// and from the consent line above Review's "Continue" button.
///
/// Written to describe the service as it will run at go-live. A few
/// statements depend on work still on CBA/TODO.md — deleting message text
/// once sent, and the monitoring mailbox's move to Google Workspace with a
/// 60-day retention rule — and the contact address is a placeholder.
/// Review the whole notice against reality before launch.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = <(String, List<String>)>[
    (
      'Who is responsible',
      [
        'CBAEngine is responsible for your information (the "data controller"). For any question or '
            'request about your data, email $privacyContactEmail.',
      ],
    ),
    (
      'What happens when you send a message',
      [
        'Your message is sent from your own email account to each councillor for the area you chose, '
            'as a separate email to each one.',
        'You are copied on every email, and so is CBAEngine\'s monitoring mailbox. Councillors can see '
            'both addresses, and their replies go to both.',
        'We use the monitoring mailbox only to see whether and when councillors reply.',
      ],
    ),
    (
      'What we keep, and for how long',
      [
        'Your email address, the area and topic you chose, which councillors were emailed, when, and '
            'whether they replied: 400 days. After that we keep only anonymous totals, plus an archive copy '
            'without your message for 90 more days, which is then deleted.',
        'The subject and text of your message: deleted from our systems once it has been sent. Copies in '
            'the monitoring mailbox are deleted after 60 days.',
        'The copies you and the councillors receive stay in your and their own mailboxes, which we don\'t '
            'control.',
      ],
    ),
    (
      'Sensitive information',
      [
        'Messages about health, housing or other personal matters, and any political views you express, '
            'can be sensitive. By pressing "Continue" before sending, you give your explicit consent for us '
            'to process your message to send it and to track replies. Please include only the personal '
            'detail you need to.',
      ],
    ),
    (
      'Your email connection',
      [
        'When you connect your email, Google or Microsoft asks you to let CBAEngine send email on your '
            'behalf. That is the only permission we ask for: we cannot read your inbox. The connection is '
            'used to send this one message and expires after 5 minutes.',
      ],
    ),
    (
      'Why we are allowed to use your information',
      [
        'Sending your message: because you asked us to.',
        'Sensitive information in your message: your explicit consent.',
        'Limiting each email address to one message a day, and measuring how councillors respond: our '
            'legitimate interests in preventing abuse and in holding elected representatives to account.',
      ],
    ),
    (
      'Who else handles your information',
      [
        'Your email provider (Google or Microsoft), which sends your message.',
        'Google, which hosts our monitoring mailbox under a data processing agreement.',
        'Our hosting provider, which runs the CBAEngine service.',
      ],
    ),
    (
      'Councillors',
      [
        'We record which councillors reply to residents\' emails and how quickly, and we publish '
            'councillors\' response rates. They count only email replies that reach our monitoring mailbox, '
            'so a reply by phone or from a different address isn\'t counted.',
        'Councillors\' names, parties and official email addresses come from their councils\' public '
            'listings. Councillors can email $privacyContactEmail to query their figures or object.',
      ],
    ),
    (
      'Your device',
      [
        'While you connect your email, your draft and a one-time security code are saved in your browser, '
            'only so they survive the sign-in page. They are cleared once your message is sent.',
      ],
    ),
    (
      'Your rights',
      [
        'You can ask for a copy of the information we hold about you, ask us to correct or erase it, '
            'object to how we use it, or withdraw your consent, by emailing $privacyContactEmail. Erasing '
            'removes your email address and message from our records; anonymous totals are kept.',
        'You can also complain to Ireland\'s Data Protection Commission at www.dataprotection.ie.',
      ],
    ),
    ('Age', ['CBAEngine is for people aged 16 and over.']),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy notice')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              'CBAEngine helps you email your local councillors, and measures how often councillors reply. '
              'This notice explains what happens to your information.',
              style: textTheme.bodyLarge,
            ),
            for (final (heading, paragraphs) in _sections) ...[
              const SizedBox(height: 24),
              Text(heading, style: textTheme.titleMedium),
              for (final paragraph in paragraphs) ...[
                const SizedBox(height: 8),
                Text(paragraph, style: textTheme.bodyMedium),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
