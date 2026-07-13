/// Route paths and names for the app's GoRouter graph.
///
/// No navigation shell (decisions §2): the Daily Board is the hub, its header
/// chips/icons are the tap-targets into these routes. Onboarding is gated by a
/// persisted "seen" flag in the router redirect.
abstract final class AppRoutes {
  const AppRoutes._();

  static const onboarding = '/onboarding';
  static const onboardingName = 'onboarding';

  static const tutorial = '/tutorial';
  static const tutorialName = 'tutorial';

  static const daily = '/daily';
  static const dailyName = 'daily';

  static const share = 'share'; // child of /daily → /daily/share
  static const shareName = 'share';
  static const sharePath = '/daily/share';

  static const bonus = 'bonus'; // child of /daily → /daily/bonus (WS3)
  static const bonusName = 'bonus';
  static const bonusPath = '/daily/bonus';

  static const practice = '/practice';
  static const practiceName = 'practice';

  static const practicePlay = 'play'; // child → /practice/play
  static const practicePlayName = 'practice-play';
  static const practicePlayPath = '/practice/play';

  static const stats = '/stats';
  static const statsName = 'stats';

  static const shop = '/shop';
  static const shopName = 'shop';

  static const streak = '/streak';
  static const streakName = 'streak';

  static const settings = '/settings';
  static const settingsName = 'settings';

  static const attribution = '/attribution';
  static const attributionName = 'attribution';
}
